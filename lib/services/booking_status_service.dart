import '../database_helper.dart';

class BookingStatusService {
  const BookingStatusService._();

  static bool isActive(Map<String, dynamic> booking, String today) =>
      booking['status'] == DatabaseHelper.statusConfirmed &&
      booking['end_date'].toString().compareTo(today) >= 0;

  static bool occupiesDay(Map<String, dynamic> booking, String date) =>
      booking['status'] == DatabaseHelper.statusConfirmed &&
      date.compareTo(booking['start_date'].toString()) >= 0 &&
      date.compareTo(booking['end_date'].toString()) <= 0;
}
