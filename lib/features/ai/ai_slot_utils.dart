import 'package:carelink/shared/models/provider_model.dart';

abstract final class AiSlotUtils {
  static List<AvailabilitySlot> sortedSlots(List<AvailabilitySlot> slots) {
    final sorted = List<AvailabilitySlot>.from(slots);
    sorted.sort((a, b) {
      final da = nextOccurrence(a.day);
      final db = nextOccurrence(b.day);
      final c = da.compareTo(db);
      if (c != 0) return c;
      return a.startTime.compareTo(b.startTime);
    });
    return sorted;
  }

  static DateTime nextOccurrence(String dayName) {
    final weekdayMap = <String, int>{
      'monday': DateTime.monday,
      'tuesday': DateTime.tuesday,
      'wednesday': DateTime.wednesday,
      'thursday': DateTime.thursday,
      'friday': DateTime.friday,
      'saturday': DateTime.saturday,
      'sunday': DateTime.sunday,
    };

    final target = weekdayMap[dayName.trim().toLowerCase()];
    var cursor = DateTime.now();
    cursor = DateTime(cursor.year, cursor.month, cursor.day);
    if (target == null) return cursor;

    for (var i = 0; i < 14; i++) {
      if (cursor.weekday == target) return cursor;
      cursor = cursor.add(const Duration(days: 1));
    }
    return DateTime.now();
  }

  static String formatReadable(DateTime d) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return '${days[d.weekday - 1]}, ${d.day} ${months[d.month - 1]} ${d.year}';
  }
}
