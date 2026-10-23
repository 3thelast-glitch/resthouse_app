import 'package:flutter_test/flutter_test.dart';
import 'package:resthouse_app/services/booking_status_service.dart';

void main() {
  const today = '2026-08-10';

  Map<String, dynamic> booking({
    String status = 'confirmed',
    String start = '2026-08-08',
    String end = '2026-08-12',
  }) => {'status': status, 'start_date': start, 'end_date': end};

  test('الحجز الجاري: اليوم داخل فترة الإقامة وحدودها شاملة', () {
    expect(
      BookingStatusService.lifecycleOf(booking(), today),
      BookingLifecycle.current,
    );
    // يبدأ اليوم أو ينتهي اليوم = جارٍ
    expect(
      BookingStatusService.lifecycleOf(
        booking(start: '2026-08-10', end: '2026-08-12'),
        today,
      ),
      BookingLifecycle.current,
    );
    expect(
      BookingStatusService.lifecycleOf(
        booking(start: '2026-08-08', end: '2026-08-10'),
        today,
      ),
      BookingLifecycle.current,
    );
  });

  test('الحجز المستقبلي: يبدأ بعد اليوم', () {
    expect(
      BookingStatusService.lifecycleOf(
        booking(start: '2026-08-11', end: '2026-08-12'),
        today,
      ),
      BookingLifecycle.upcoming,
    );
  });

  test('الحجز المنتهي: انتهى قبل اليوم', () {
    expect(
      BookingStatusService.lifecycleOf(
        booking(start: '2026-08-05', end: '2026-08-09'),
        today,
      ),
      BookingLifecycle.ended,
    );
  });

  test('الملغي بلا دورة حياة، والمعلّق يصنف بتواريخه', () {
    expect(
      BookingStatusService.lifecycleOf(booking(status: 'cancelled'), today),
      isNull,
    );
    expect(
      BookingStatusService.lifecycleOf(
        booking(status: 'pending', start: '2026-08-20', end: '2026-08-21'),
        today,
      ),
      BookingLifecycle.upcoming,
    );
  });
}
