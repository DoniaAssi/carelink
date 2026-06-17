import 'package:carelink/shared/models/provider_model.dart';

class AiSlotUtils {
  static List<AvailabilitySlot> sortedSlots(List<AvailabilitySlot> slots) {
    final sorted = List<AvailabilitySlot>.from(slots);
    sorted.sort((a, b) {
      final aDate = dateFor(a);
      final bDate = dateFor(b);
      final dateCompare = aDate.compareTo(bDate);
      if (dateCompare != 0) return dateCompare;
      return a.startTime.compareTo(b.startTime);
    });
    return sorted;
  }

  static DateTime dateFor(AvailabilitySlot slot) {
    final concrete = DateTime.tryParse(slot.date);
    if (concrete != null) return concrete;
    return nextOccurrence(slot.day);
  }

  static DateTime nextOccurrence(Object? day) {
    const weekdays = {
      'monday': DateTime.monday,
      'tuesday': DateTime.tuesday,
      'wednesday': DateTime.wednesday,
      'thursday': DateTime.thursday,
      'friday': DateTime.friday,
      'saturday': DateTime.saturday,
      'sunday': DateTime.sunday,
    };
    final now = DateTime.now();
    final target = weekdays[day?.toString().trim().toLowerCase()];
    if (target == null) return DateTime(now.year, now.month, now.day);
    final offset = (target - now.weekday + 7) % 7;
    return DateTime(now.year, now.month, now.day).add(Duration(days: offset));
  }

  static String formatReadable(DateTime d) => d.toIso8601String();
}
