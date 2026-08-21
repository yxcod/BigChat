import 'package:intl/intl.dart';

class ChatTimeFormatter {
  const ChatTimeFormatter._();

  /// Formats chat timestamps as HH:mm today, MM-dd HH:mm this year,
  /// and yyyy-MM-dd HH:mm for earlier years.
  static String format(int timestamp, {DateTime? referenceTime}) {
    if (timestamp <= 0) return '';

    final normalizedTimestamp = timestamp < 1000000000000
        ? timestamp * 1000
        : timestamp;
    final dateTime = DateTime.fromMillisecondsSinceEpoch(normalizedTimestamp);
    final now = referenceTime ?? DateTime.now();
    final isToday =
        dateTime.year == now.year &&
        dateTime.month == now.month &&
        dateTime.day == now.day;

    if (isToday) return DateFormat('HH:mm').format(dateTime);
    if (dateTime.year == now.year) {
      return DateFormat('MM-dd HH:mm').format(dateTime);
    }
    return DateFormat('yyyy-MM-dd HH:mm').format(dateTime);
  }
}
