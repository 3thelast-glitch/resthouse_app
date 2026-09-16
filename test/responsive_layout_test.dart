import 'dart:io';
import 'dart:ui' as ui;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:resthouse_app/database_helper.dart';
import 'package:resthouse_app/main.dart';
import 'package:resthouse_app/pages/booking_manager_page.dart';
import 'package:resthouse_app/pages/finance_page.dart';
import 'package:resthouse_app/pages/settings_page.dart';
import 'package:resthouse_app/theme/app_theme.dart';
import 'package:resthouse_app/widgets/adaptive_content.dart';
import 'package:resthouse_app/widgets/responsive_bar_chart.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:table_calendar/table_calendar.dart';

const captureKey = ValueKey('layout-capture');
const longName = 'عبدالله عبدالرحمن محمد العتيبي صاحب الحجز العائلي';
const widths = [
  320.0,
  360.0,
  390.0,
  412.0,
  480.0,
  600.0,
  768.0,
  1024.0,
  1280.0,
];

Widget app(Widget home) => RepaintBoundary(
  key: captureKey,
  child: MaterialApp(
    debugShowCheckedModeBanner: false,
    theme: AppTheme.light,
    locale: const Locale('ar', 'SA'),
    supportedLocales: const [Locale('ar', 'SA')],
    localizationsDelegates: const [
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    home: home,
  ),
);

Future<void> viewport(
  WidgetTester tester,
  double width,
  double scale, {
  double height = 844,
}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = Size(width, height);
  tester.platformDispatcher.textScaleFactorTestValue = scale;
  await tester.pump();
}

Future<void> ready(WidgetTester tester) async {
  final deadline = DateTime.now().add(const Duration(seconds: 8));
  do {
    await Future<void>.delayed(const Duration(milliseconds: 20));
    await tester.pump(const Duration(milliseconds: 80));
  } while ((find.byType(CircularProgressIndicator).evaluate().isNotEmpty ||
          find.byType(LinearProgressIndicator).evaluate().isNotEmpty) &&
      DateTime.now().isBefore(deadline));
  expect(
    find.byType(CircularProgressIndicator),
    findsNothing,
    reason: 'Data loading did not finish',
  );
  expect(find.byType(LinearProgressIndicator), findsNothing);
  await tester.pump(const Duration(milliseconds: 300));
}

void geometry(WidgetTester tester, String scenario) {
  expect(tester.takeException(), isNull, reason: scenario);
  final screen =
      Offset.zero & (tester.view.physicalSize / tester.view.devicePixelRatio);
  for (final element in find.byType(RichText).evaluate()) {
    final render = element.renderObject;
    if (render is! RenderParagraph || !render.attached || !render.hasSize) {
      continue;
    }
    final rect = render.localToGlobal(Offset.zero) & render.size;
    if (!rect.overlaps(screen)) {
      continue;
    }
    final text = render.text.toPlainText();
    expect(
      rect.left,
      greaterThanOrEqualTo(-1),
      reason: '$scenario: text outside left edge: $text',
    );
    expect(
      rect.right,
      lessThanOrEqualTo(screen.width + 1),
      reason: '$scenario: text outside right edge: $text',
    );
    expect(
      render.didExceedMaxLines,
      isFalse,
      reason: '$scenario: clipped text: $text',
    );
    final tokens = RegExp(
      r'الإيرادات|المصاريف|الأرباح|الحجوزات|المستأجرين|\d[\d,.-]*\d',
    );
    for (final match in tokens.allMatches(text)) {
      final boxes = render.getBoxesForSelection(
        TextSelection(baseOffset: match.start, extentOffset: match.end),
      );
      if (boxes.isEmpty) {
        continue;
      }
      final top = boxes.first.top;
      expect(
        boxes.every((box) => (box.top - top).abs() < 1),
        isTrue,
        reason: '$scenario: word/number split across lines: ${match.group(0)}',
      );
      expect(
        boxes.every(
          (box) => box.left >= -1 && box.right <= render.size.width + 1,
        ),
        isTrue,
        reason:
            '$scenario: number/word wider than its text box: ${match.group(0)}',
      );
    }
  }
}

Future<void> capture(WidgetTester tester, String name) async {
  if (Platform.environment['CAPTURE_LAYOUT'] != '1') {
    return;
  }
  await tester.pump();
  final boundary = tester.renderObject<RenderRepaintBoundary>(
    find.byKey(captureKey),
  );
  final image = await boundary.toImage(pixelRatio: 1);
  final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
  final directory = Directory('build/layout-captures')
    ..createSync(recursive: true);
  await File(
    '${directory.path}/$name.png',
  ).writeAsBytes(bytes!.buffer.asUint8List());
  image.dispose();
}

Future<void> walk(
  WidgetTester tester,
  Finder scrollView,
  String scenario, {
  String? bottomCapture,
}) async {
  final scrollable = find
      .descendant(of: scrollView, matching: find.byType(Scrollable))
      .first;
  final state = tester.state<ScrollableState>(scrollable);
  state.position.jumpTo(0);
  await ready(tester);
  geometry(tester, '$scenario top');
  var steps = 0;
  while (state.position.pixels < state.position.maxScrollExtent - 1 &&
      steps++ < 150) {
    state.position.jumpTo(
      (state.position.pixels + 350).clamp(0, state.position.maxScrollExtent),
    );
    await ready(tester);
    geometry(tester, '$scenario scroll $steps');
  }
  expect(
    state.position.extentAfter,
    lessThan(1),
    reason: '$scenario end is unreachable',
  );
  if (bottomCapture != null) {
    await capture(tester, bottomCapture);
  }
}

void main() {
  final db = DatabaseHelper.instance;
  late Directory directory;
  late int bookingId;

  setUpAll(() async {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    final loader = FontLoader(AppTheme.fontFamily);
    for (final weight in ['Regular', 'Medium', 'SemiBold', 'Bold']) {
      loader.addFont(
        rootBundle.load('assets/fonts/IBMPlexSansArabic-$weight.ttf'),
      );
    }
    await loader.load();
    final icons = FontLoader('MaterialIcons');
    icons.addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'));
    await icons.load();
  });
  setUp(() async {
    directory = await Directory.systemTemp.createTemp('resthouse_layout_');
    await db.configureDatabasePathForTesting('${directory.path}/layout.db');
    await db.insertRenter({
      'phone': '0500000001',
      'full_name': longName,
      'rating': 5,
    });
    final today = DateTime.now();
    final date =
        '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';
    bookingId = await db.insertBooking({
      'phone': '0500000001',
      'start_date': date,
      'end_date': date,
      'total_price': 55.0,
      'security_deposit': 0.0,
    });
    await db.insertExpense({
      'description':
          'صيانة المسبح وتنظيف مرافق الاستراحة وتجهيزها لاستقبال الضيوف',
      'date': date,
      'amount': 100.0,
      'category': 'مصاريف تشغيلية أخرى',
    });
  });
  tearDown(() async {
    await db.clearTestingDatabase();
    await directory.delete(recursive: true);
  });

  testWidgets(
    'metric words and amounts fit widths, column boundaries and all text scales',
    (tester) async {
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      await tester.runAsync(() async {
        for (final scale in [1.0, 1.3, 1.5, 2.0]) {
          for (final width in [
            ...widths,
            359.0,
            361.0,
            463.0,
            464.0,
            465.0,
            685.0,
            686.0,
            687.0,
          ]) {
            await viewport(tester, width, scale);
            await tester.pumpWidget(
              app(
                const Scaffold(
                  body: SingleChildScrollView(
                    key: ValueKey('metrics-scroll'),
                    padding: EdgeInsets.all(16),
                    child: AdaptiveItems(
                      minItemWidth: 210,
                      children: [
                        MetricCard(
                          title: 'إجمالي الإيرادات',
                          value: 1234567.89,
                          icon: Icons.money,
                          color: AppColors.primary,
                        ),
                        MetricCard(
                          title: 'إجمالي المصاريف',
                          value: 0,
                          icon: Icons.money,
                          color: AppColors.errorText,
                        ),
                        MetricCard(
                          title: 'صافي الأرباح',
                          value: -1234567.89,
                          icon: Icons.money,
                          color: AppColors.primary,
                        ),
                        MetricCard(
                          title: 'الحجوزات النشطة حالياً',
                          value: 12345,
                          icon: Icons.event,
                          color: AppColors.primary,
                          isMoney: false,
                          unit: 'حجز نشط',
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
            await walk(
              tester,
              find.byKey(const ValueKey('metrics-scroll')),
              'metrics $width/$scale',
            );
          }
        }
        await tester.pumpWidget(const SizedBox.shrink());
      });
    },
    timeout: const Timeout(Duration(minutes: 4)),
  );

  testWidgets(
    'populated app dashboard scrolls safely across navigation breakpoints',
    (tester) async {
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      await tester.runAsync(() async {
        await viewport(tester, 390, 1);
        await tester.pumpWidget(
          const RepaintBoundary(key: captureKey, child: ResthouseApp()),
        );
        await ready(tester);
        await capture(tester, 'dashboard-phone-top');
        for (final width in [...widths, 799.0, 800.0, 801.0, 1023.0, 1025.0]) {
          await viewport(tester, width, 1);
          await walk(
            tester,
            find.byKey(const PageStorageKey('dashboard-scroll')),
            'dashboard $width/1',
            bottomCapture: width == 390 ? 'dashboard-phone-bottom' : null,
          );
        }
        for (final size in [
          const Size(320, 700),
          const Size(390, 844),
          const Size(800, 400),
        ]) {
          await viewport(tester, size.width, 2, height: size.height);
          await walk(
            tester,
            find.byKey(const PageStorageKey('dashboard-scroll')),
            'dashboard $size/2',
            bottomCapture: size.width == 390 ? 'dashboard-large-text' : null,
          );
        }
        await viewport(tester, 1280, 1);
        final state = tester.state<ScrollableState>(
          find
              .descendant(
                of: find.byKey(const PageStorageKey('dashboard-scroll')),
                matching: find.byType(Scrollable),
              )
              .first,
        );
        state.position.jumpTo(0);
        await ready(tester);
        await capture(tester, 'dashboard-wide');
        await tester.pumpWidget(const SizedBox.shrink());
      });
    },
    timeout: const Timeout(Duration(minutes: 4)),
  );

  testWidgets(
    'booking calendar, receipt cards and search survive resizing',
    (tester) async {
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      await tester.runAsync(() async {
        await viewport(tester, 390, 1);
        await tester.pumpWidget(app(const BookingManagerPage()));
        await ready(tester);
        await capture(tester, 'bookings-phone-top');
        for (final sample in [
          (320.0, 1.0),
          (390.0, 1.0),
          (600.0, 1.3),
          (768.0, 1.5),
          (1023.0, 1.0),
          (1024.0, 1.0),
          (1025.0, 1.0),
          (1280.0, 1.0),
          (390.0, 2.0),
        ]) {
          await viewport(tester, sample.$1, sample.$2);
          await ready(tester);
          if (sample.$1 >= 1024 && sample.$2 == 1) {
            await walk(
              tester,
              find.byKey(const PageStorageKey('booking-directory-wide')),
              'directory $sample',
            );
            await walk(
              tester,
              find.byKey(const PageStorageKey('booking-calendar-wide')),
              'calendar $sample',
            );
          } else {
            await walk(
              tester,
              find.byKey(const PageStorageKey('booking-page-scroll')),
              'bookings $sample',
              bottomCapture: sample == (390.0, 1.0)
                  ? 'booking-card-phone'
                  : null,
            );
          }
        }
        await viewport(tester, 390, 1);
        await ready(tester);
        await tester.ensureVisible(
          find.byKey(const ValueKey('booking-search')),
        );
        await tester.enterText(
          find.byKey(const ValueKey('booking-search')),
          'عبدالله',
        );
        final selected =
            (tester.widget(find.byKey(const ValueKey('booking-calendar')))
                    as dynamic)
                .focusedDay;
        await viewport(tester, 1280, 1);
        await ready(tester);
        expect(
          tester
              .widget<TextField>(find.byKey(const ValueKey('booking-search')))
              .controller!
              .text,
          'عبدالله',
        );
        expect(
          (tester.widget(find.byKey(const ValueKey('booking-calendar')))
                  as dynamic)
              .focusedDay,
          selected,
        );
        await capture(tester, 'bookings-wide');
        await tester.pumpWidget(const SizedBox.shrink());
      });
    },
    timeout: const Timeout(Duration(minutes: 4)),
  );

  testWidgets(
    'finance reports, comparison and expense actions fit large text',
    (tester) async {
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      await tester.runAsync(() async {
        await viewport(tester, 390, 1);
        await tester.pumpWidget(app(const FinancePage()));
        await ready(tester);
        for (final sample in [
          (320.0, 1.0),
          (390.0, 1.0),
          (768.0, 1.3),
          (1280.0, 1.0),
          (390.0, 2.0),
        ]) {
          await viewport(tester, sample.$1, sample.$2);
          await walk(
            tester,
            find.byKey(const PageStorageKey('finance-scroll')),
            'finance $sample',
            bottomCapture: sample == (390.0, 1.0) ? 'finance-phone' : null,
          );
        }
        await tester.ensureVisible(
          find.byKey(const ValueKey('finance-comparison-tab')),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const ValueKey('finance-comparison-tab')));
        await ready(tester);
        await walk(
          tester,
          find.byKey(const PageStorageKey('finance-scroll')),
          'comparison 390/2',
        );
        await tester.pumpWidget(const SizedBox.shrink());
      });
    },
    timeout: const Timeout(Duration(minutes: 3)),
  );

  testWidgets(
    'booking form and keyboard leave save reachable without resetting input',
    (tester) async {
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetViewInsets);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      await tester.runAsync(() async {
        await viewport(tester, 390, 2, height: 700);
        await tester.pumpWidget(app(const BookingManagerPage()));
        await ready(tester);
        await tester.tap(find.byKey(const ValueKey('add-booking')));
        await ready(tester);
        geometry(tester, 'booking dialog 390/2');
        final price = find.widgetWithText(
          TextField,
          'سعر الحجز الإجمالي (ر.س)',
        );
        await tester.ensureVisible(price);
        await tester.enterText(price, '55.00');
        tester.view.viewInsets = const FakeViewPadding(bottom: 260);
        await ready(tester);
        await tester.ensureVisible(price);
        await tester.pump();
        geometry(tester, 'booking dialog with keyboard');
        await capture(tester, 'booking-keyboard');
        final save = find.widgetWithText(ElevatedButton, 'حفظ الحجز');
        expect(save.hitTestable(), findsOneWidget);
        expect(tester.getRect(save).bottom, lessThanOrEqualTo(440));
        await viewport(tester, 700, 1.3, height: 390);
        await ready(tester);
        expect(tester.widget<TextField>(price).controller!.text, '55.00');
        geometry(tester, 'booking dialog landscape with keyboard');
        expect(save.hitTestable(), findsOneWidget);
        expect(tester.getRect(save).bottom, lessThanOrEqualTo(130));
        tester.view.resetViewInsets();
        await ready(tester);
        await tester.pumpWidget(const SizedBox.shrink());
        expect((await db.queryPaymentSummary(bookingId))['total'], 55);
      });
    },
  );

  testWidgets('six-week calendar and shell preserve date, filter and tab', (
    tester,
  ) async {
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await tester.runAsync(() async {
      await viewport(tester, 390, 1);
      await tester.pumpWidget(
        const RepaintBoundary(key: captureKey, child: ResthouseApp()),
      );
      await ready(tester);
      await tester.tap(find.text('الحجوزات'));
      await ready(tester);
      final calendar = find.byKey(const ValueKey('booking-calendar'));
      var focused = tester.widget<TableCalendar>(calendar).focusedDay;
      for (var i = 0; i < 12; i++) {
        final first = DateTime(focused.year, focused.month);
        final days = DateTime(focused.year, focused.month + 1, 0).day;
        if (first.weekday % 7 + days > 35) {
          break;
        }
        await tester.ensureVisible(find.byTooltip('الشهر التالي'));
        await tester.tap(find.byTooltip('الشهر التالي'));
        await ready(tester);
        focused = tester.widget<TableCalendar>(calendar).focusedDay;
      }
      expect(
        DateTime(focused.year, focused.month).weekday % 7 +
            DateTime(focused.year, focused.month + 1, 0).day,
        greaterThan(35),
      );
      final selected = DateTime(focused.year, focused.month, 15);
      tester.widget<TableCalendar>(calendar).onDaySelected!(selected, selected);
      await ready(tester);
      await viewport(tester, 320, 2);
      await walk(
        tester,
        find.byKey(const PageStorageKey('booking-page-scroll')),
        'six-week calendar 320/2',
      );
      await viewport(tester, 390, 1);
      await ready(tester);
      final filter = find.byKey(const ValueKey('filter-archived'));
      await tester.ensureVisible(filter);
      await ready(tester);
      expect(filter.hitTestable(), findsOneWidget);
      await tester.tap(filter);
      await ready(tester);
      expect(tester.widget<ChoiceChip>(filter).selected, isTrue);
      await tester.enterText(
        find.byKey(const ValueKey('booking-search')),
        'عبدالله',
      );
      for (final width in [799.0, 800.0, 801.0, 1280.0, 390.0]) {
        await viewport(tester, width, 1);
        await ready(tester);
        expect(tester.widget<ChoiceChip>(filter).selected, isTrue);
        expect(
          tester.widget<TableCalendar>(calendar).selectedDayPredicate!(selected),
          isTrue,
        );
        expect(
          tester.widget<TextField>(find.byType(TextField).first).controller!.text,
          'عبدالله',
        );
        geometry(tester, 'shell state $width');
      }
      final renters = find.widgetWithText(ChoiceChip, 'قائمة المستأجرين (1)');
      await tester.ensureVisible(renters);
      await ready(tester);
      expect(renters.hitTestable(), findsOneWidget);
      await tester.tap(renters);
      await viewport(tester, 1280, 1);
      await ready(tester);
      expect(tester.widget<ChoiceChip>(renters).selected, isTrue);
      await tester.pumpWidget(const SizedBox.shrink());
    });
  });

  testWidgets('booking create, edit, collect and cancel delete work on phone', (
    tester,
  ) async {
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetViewInsets);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await tester.runAsync(() async {
      await db.deleteBooking(bookingId);
      await viewport(tester, 390, 2, height: 700);
      await tester.pumpWidget(app(const BookingManagerPage()));
      await ready(tester);
      await tester.tap(find.byKey(const ValueKey('add-booking')));
      await ready(tester);
      await tester.tap(find.byType(DropdownButtonFormField<String>));
      await ready(tester);
      await tester.tap(find.text('$longName (0500000001)').last);
      await ready(tester);
      final price = find.widgetWithText(TextField, 'سعر الحجز الإجمالي (ر.س)');
      await tester.ensureVisible(price);
      await tester.enterText(price, '55.00');
      tester.view.viewInsets = const FakeViewPadding(bottom: 260);
      await ready(tester);
      geometry(tester, 'create populated booking with keyboard');
      final saveBooking = find.widgetWithText(ElevatedButton, 'حفظ الحجز');
      expect(saveBooking.hitTestable(), findsOneWidget);
      await tester.tap(saveBooking);
      await ready(tester);
      expect(find.byType(AlertDialog), findsNothing);
      final created = (await db.queryAllBookings()).single;
      final id = created['id'] as int;
      expect(created['total_price'], 55);
      tester.view.resetViewInsets();
      await viewport(tester, 390, 1.5);
      await walk(
        tester,
        find.byKey(const PageStorageKey('booking-page-scroll')),
        'new booking list',
      );
      final card = find.byKey(ValueKey('directory-booking-$id'));
      Finder action(String text) => find.descendant(
        of: card,
        matching: find.widgetWithText(TextButton, text),
      );
      await tester.ensureVisible(action('الدفعات'));
      await tester.tap(action('الدفعات'));
      await ready(tester);
      await tester.tap(find.text('تسجيل دفعة'));
      await ready(tester);
      geometry(tester, 'payment dialog 390/1.5');
      await tester.enterText(
        find.widgetWithText(TextField, 'قيمة الدفعة (ر.س)'),
        '20',
      );
      tester.view.viewInsets = const FakeViewPadding(bottom: 260);
      await ready(tester);
      final savePayment = find.widgetWithText(ElevatedButton, 'حفظ الدفعة');
      expect(savePayment.hitTestable(), findsOneWidget);
      await tester.tap(savePayment);
      await ready(tester);
      expect((await db.queryPaymentSummary(id))['remaining'], 35);
      tester.view.resetViewInsets();
      await ready(tester);
      await tester.ensureVisible(action('تعديل'));
      await tester.tap(action('تعديل'));
      await ready(tester);
      await tester.ensureVisible(price);
      await tester.enterText(price, '75.00');
      geometry(tester, 'edit booking 390/1.5');
      await tester.tap(find.widgetWithText(ElevatedButton, 'حفظ'));
      await ready(tester);
      final summary = await db.queryPaymentSummary(id);
      expect(summary['total'], 75);
      expect(summary['paid'], 20);
      expect(summary['remaining'], 55);
      await tester.ensureVisible(action('حذف'));
      await tester.tap(action('حذف'));
      await ready(tester);
      geometry(tester, 'delete confirmation 390/1.5');
      await tester.tap(find.widgetWithText(TextButton, 'إلغاء'));
      await ready(tester);
      expect((await db.queryAllBookings()).length, 1);
      await tester.pumpWidget(const SizedBox.shrink());
    });
  });

  testWidgets('quick client and expense save above the keyboard at 200%', (
    tester,
  ) async {
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetViewInsets);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await tester.runAsync(() async {
      await viewport(tester, 390, 2, height: 700);
      await tester.pumpWidget(
        const RepaintBoundary(key: captureKey, child: ResthouseApp()),
      );
      await ready(tester);
      await tester.tap(find.text('عميل جديد'));
      await ready(tester);
      await tester.enterText(
        find.widgetWithText(TextFormField, 'الاسم الكامل'),
        'عميل اختبار جديد',
      );
      final phone = find.widgetWithText(TextFormField, 'رقم الهاتف');
      await tester.ensureVisible(phone);
      await tester.enterText(phone, '0500000002');
      tester.view.viewInsets = const FakeViewPadding(bottom: 260);
      await ready(tester);
      geometry(tester, 'client form 390/2 keyboard');
      final saveClient = find.widgetWithText(ElevatedButton, 'إضافة');
      expect(saveClient.hitTestable(), findsOneWidget);
      await tester.tap(saveClient);
      await ready(tester);
      expect((await db.queryAllRenters()).length, 2);
      tester.view.resetViewInsets();
      await ready(tester);
      final expense = find.text('تسجيل مصروف سريع');
      await tester.ensureVisible(expense);
      await tester.tap(expense);
      await ready(tester);
      await tester.enterText(
        find.widgetWithText(TextField, 'وصف المصروف'),
        'مصاريف اختبار مستقلة',
      );
      final amount = find.widgetWithText(TextField, 'المبلغ');
      await tester.ensureVisible(amount);
      await tester.enterText(amount, '1234567.89');
      tester.view.viewInsets = const FakeViewPadding(bottom: 260);
      await ready(tester);
      geometry(tester, 'expense form 390/2 keyboard');
      final saveExpense = find.widgetWithText(ElevatedButton, 'حفظ');
      expect(saveExpense.hitTestable(), findsOneWidget);
      await tester.tap(saveExpense);
      await ready(tester);
      expect(
        (await db.queryAllExpenses()).any((e) => e['amount'] == 1234567.89),
        isTrue,
      );
      await tester.pumpWidget(const SizedBox.shrink());
    });
  });

  testWidgets('long expense list keeps its final action reachable', (
    tester,
  ) async {
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await tester.runAsync(() async {
      final now = DateTime.now();
      final month = '${now.year}-${now.month.toString().padLeft(2, '0')}';
      for (var i = 0; i < 30; i++) {
        await db.insertExpense({
          'description': 'مصروف اختبار طويل رقم $i',
          'date': '$month-10',
          'amount': 55.0,
        });
      }
      await db.insertExpense({
        'description': 'المصروف الأخير للاختبار',
        'date': '$month-01',
        'amount': 1234567.89,
      });
      await viewport(tester, 320, 2);
      await tester.pumpWidget(app(const FinancePage()));
      await ready(tester);
      await walk(
        tester,
        find.byKey(const PageStorageKey('finance-scroll')),
        'long expenses 320/2',
      );
      final last = find.ancestor(
        of: find.text('المصروف الأخير للاختبار'),
        matching: find.byType(Card),
      );
      final edit = find.descendant(
        of: last,
        matching: find.widgetWithText(TextButton, 'تعديل'),
      );
      await tester.ensureVisible(edit);
      expect(edit.hitTestable(), findsOneWidget);
      await tester.tap(edit);
      await ready(tester);
      expect(find.byType(AlertDialog), findsOneWidget);
      geometry(tester, 'last expense edit 320/2');
      await tester.pumpWidget(const SizedBox.shrink());
    });
  });

  testWidgets('chart retains all zero, equal and signed values on phone', (
    tester,
  ) async {
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await tester.runAsync(() async {
      await viewport(tester, 320, 2);
      for (final values in [
        <double>[],
        [0.0, 0.0, 0.0],
        [55.0, 55.0, 55.0],
        [-1234567.89, 0.0, 1234567.89],
      ]) {
        await tester.pumpWidget(
          app(
            Scaffold(
              body: Padding(
                padding: const EdgeInsets.all(16),
                child: ResponsiveBarChart(
                  groups: [
                    for (var i = 0; i < values.length; i++)
                      BarChartGroupData(
                        x: i,
                        barRods: [BarChartRodData(toY: values[i])],
                      ),
                  ],
                  labels: {
                    for (var i = 0; i < values.length; i++) i: '2026-09-15',
                  },
                ),
              ),
            ),
          ),
        );
        await ready(tester);
        geometry(tester, 'chart $values at 320/2');
        final data = tester.widget<BarChart>(find.byType(BarChart)).data;
        expect(data.minY.isFinite && data.maxY.isFinite, isTrue);
        expect(data.maxY, greaterThan(data.minY));
        expect(data.barGroups.map((g) => g.barRods.single.toY), values);
      }
      await tester.pumpWidget(const SizedBox.shrink());
    });
  });

  testWidgets('settings is scrollable with 200% text on a short screen', (
    tester,
  ) async {
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await tester.runAsync(() async {
      await viewport(tester, 320, 2, height: 400);
      await tester.pumpWidget(app(SettingsPage(onDatabaseRestored: () {})));
      await ready(tester);
      await walk(
        tester,
        find.byType(SingleChildScrollView).first,
        'settings 320/2',
      );
      await tester.pumpWidget(const SizedBox.shrink());
    });
  });
}
