import '../database_helper.dart';

/// Where a booking sits in its life relative to today. Cancelled
/// bookings have no lifecycle (they never run); pending bookings are
/// classified by their dates, since they still need tracking.
enum BookingLifecycle { current, upcoming, ended }

class BookingStatusService {
  const BookingStatusService._();

  /// Classifies [booking] against [today] ('yyyy-MM-dd'):
  /// - [BookingLifecycle.current]: today falls inside the stay.
  /// - [BookingLifecycle.upcoming]: the stay starts after today.
  /// - [BookingLifecycle.ended]: the stay ended before today.
  /// Returns null for cancelled bookings.
  static BookingLifecycle? lifecycleOf(
    Map<String, dynamic> booking,
    String today,
  ) {
    if (booking['status'] == DatabaseHelper.statusCancelled) return null;
    final start = booking['start_date'].toString();
    final end = booking['end_date'].toString();
    if (end.compareTo(today) < 0) return BookingLifecycle.ended;
    if (start.compareTo(today) > 0) return BookingLifecycle.upcoming;
    return BookingLifecycle.current;
  }

  static bool isActive(Map<String, dynamic> booking, String today) =>
      booking['status'] == DatabaseHelper.statusConfirmed &&
      booking['end_date'].toString().compareTo(today) >= 0;

  static bool occupiesDay(Map<String, dynamic> booking, String date) =>
      booking['status'] == DatabaseHelper.statusConfirmed &&
      date.compareTo(booking['start_date'].toString()) >= 0 &&
      date.compareTo(booking['end_date'].toString()) <= 0;
}
