import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:resthouse_app/widgets/renter_badges.dart';

void main() {
  Future<void> pumpBadges(
    WidgetTester tester,
    Map<String, dynamic> renter,
  ) async {
    await tester.pumpWidget(
      MaterialApp(home: Scaffold(body: RenterBadges(renter: renter))),
    );
  }

  testWidgets('يعرض شارة الملاحظات عند وجود ملاحظات فقط', (tester) async {
    await pumpBadges(tester, {'notes': 'يدفع متأخراً', 'rating': 2});
    expect(find.byIcon(Icons.warning_amber_rounded), findsOneWidget);
    expect(find.byIcon(Icons.verified), findsNothing);
  });

  testWidgets('يعرض شارة العميل المميز بالتقييم أو عدد الحجوزات', (
    tester,
  ) async {
    await pumpBadges(tester, {'rating': 5});
    expect(find.byIcon(Icons.verified), findsOneWidget);

    await pumpBadges(tester, {'rental_count': 3});
    expect(find.byIcon(Icons.verified), findsOneWidget);

    await pumpBadges(tester, {'rating': 3, 'rental_count': 2});
    expect(find.byIcon(Icons.verified), findsNothing);
  });

  testWidgets('لا يعرض شيئاً لمستأجر عادي بلا ملاحظات', (tester) async {
    await pumpBadges(tester, {'full_name': 'عادي'});
    expect(find.byIcon(Icons.warning_amber_rounded), findsNothing);
    expect(find.byIcon(Icons.verified), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
