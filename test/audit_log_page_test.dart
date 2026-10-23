import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:resthouse_app/pages/audit_log_page.dart';

void main() {
  test('تترجم تسميات الكيانات والإجراءات للعربية', () {
    expect(auditEntityLabel('booking'), 'حجز');
    expect(auditEntityLabel('payment'), 'دفعة');
    expect(auditActionLabel('created'), 'إنشاء');
    expect(auditActionLabel('voided'), 'إلغاء');
    expect(auditActionLabel('returned'), 'إرجاع التأمين');
    // Unknown values fall back to the stored string.
    expect(auditEntityLabel('something_new'), 'something_new');
  });

  testWidgets('يعرض الأحداث بعناوين عربية والتفاصيل والوقت', (tester) async {
    final events = <Map<String, dynamic>>[
      {
        'id': 2,
        'entity_type': 'payment',
        'entity_id': '7',
        'action': 'voided',
        'details': 'booking_id=3; amount=250.0',
        'created_at': '2026-08-10T09:30:00.000Z',
      },
      {
        'id': 1,
        'entity_type': 'booking',
        'entity_id': '3',
        'action': 'created',
        'details': null,
        'created_at': '2026-08-09T08:00:00.000Z',
      },
    ];

    await tester.pumpWidget(
      MaterialApp(home: Scaffold(body: AuditEventList(events: events))),
    );

    expect(find.text('دفعة #7 — إلغاء'), findsOneWidget);
    expect(find.text('حجز #3 — إنشاء'), findsOneWidget);
    expect(find.text('booking_id=3; amount=250.0'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('يعرض حالة فراغ عند عدم وجود أحداث', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: AuditEventList(events: []))),
    );

    expect(find.text('لا توجد أحداث مسجلة بعد'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
