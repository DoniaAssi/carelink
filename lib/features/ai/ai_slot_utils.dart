class AiSlotUtils {
  static List<dynamic> sortedSlots(List<dynamic> slots) => List<dynamic>.from(slots);

  static DateTime nextOccurrence(Object? day) => DateTime.now();

  static String formatReadable(DateTime d) => d.toIso8601String();
}
