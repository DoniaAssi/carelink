import 'package:carelink/features/ai/recommendation/models/recommendation_models.dart';

/// Maps UI category chips + free text into [RecommendationRequest] fields.
class RecommendationRequestParser {
  RecommendationRequestParser._();

  static const categoryKeys = [
    'general',
    'lungs',
    'dentist',
    'psychiatrist',
    'covid',
    'surgeon',
    'cardiology',
  ];

  static RecommendationRequest fromInputs({
    required String searchText,
    String? categoryKey,
  }) {
    final q = searchText.trim();
    final lower = q.toLowerCase();

    final urgent = _hasAny(lower, [
      'urgent',
      'emergency',
      'severe',
      'can\'t breathe',
      'cant breathe',
      'bleeding',
    ]);

    final complex = _hasAny(lower, [
      'chronic',
      'multiple',
      'complex',
      'post surgery',
      'post-surgery',
      'cancer',
      'transplant',
    ]) ||
        lower.split(RegExp(r'\s+')).length > 18;

    final dt = _extractDateTime(lower);
    final keyword = _keywordFromCategory(categoryKey) ??
        _keywordFromText(lower) ??
        '';

    return RecommendationRequest(
      rawQuery: q,
      categoryKey: categoryKey,
      requestedDateTime: dt,
      isUrgent: urgent,
      isComplexCase: complex && !urgent,
      requestedServiceKeyword: keyword,
    );
  }

  static bool _hasAny(String blob, List<String> needles) {
    for (final n in needles) {
      if (blob.contains(n)) return true;
    }
    return false;
  }

  static String? _keywordFromCategory(String? key) {
    if (key == null) return null;
    switch (key) {
      case 'general':
        return 'general';
      case 'lungs':
        return 'lung';
      case 'dentist':
        return 'dental';
      case 'psychiatrist':
        return 'psych';
      case 'covid':
        return 'covid';
      case 'surgeon':
        return 'surgery';
      case 'cardiology':
        return 'cardiology';
      default:
        return key;
    }
  }

  static String? _keywordFromText(String lower) {
    const pairs = <String, String>{
      'cardiology': 'cardiology',
      'cardio': 'cardiology',
      'heart': 'cardiology',
      'chest pain': 'cardiology',
      'lung': 'lung',
      'pulmon': 'lung',
      'respir': 'lung',
      'dentist': 'dental',
      'dental': 'dental',
      'tooth': 'dental',
      'psych': 'psych',
      'psychiat': 'psych',
      'covid': 'covid',
      'surgery': 'surgery',
      'surgeon': 'surgery',
      'general': 'general',
      'wednesday': '',
      'tuesday': '',
      'thursday': '',
      'friday': '',
      'monday': '',
    };

    for (final e in pairs.entries) {
      if (lower.contains(e.key)) {
        final v = e.value;
        if (v.isEmpty) continue;
        return v;
      }
    }
    return null;
  }

  /// Very small natural-time heuristic: detects weekday + "2 pm" / "14:00".
  static DateTime? _extractDateTime(String lower) {
    const days = {
      'monday': DateTime.monday,
      'tuesday': DateTime.tuesday,
      'wednesday': DateTime.wednesday,
      'thursday': DateTime.thursday,
      'friday': DateTime.friday,
      'saturday': DateTime.saturday,
      'sunday': DateTime.sunday,
    };

    int? wantWeekday;
    for (final e in days.entries) {
      if (lower.contains(e.key)) {
        wantWeekday = e.value;
        break;
      }
    }

    final hourMin = _extractClock(lower);
    if (wantWeekday == null && hourMin == null) return null;

    final now = DateTime.now();
    var cursor = DateTime(now.year, now.month, now.day);

    if (wantWeekday != null) {
      while (cursor.weekday != wantWeekday) {
        cursor = cursor.add(const Duration(days: 1));
        if (cursor.difference(DateTime(now.year, now.month, now.day)).inDays >
            14) {
          break;
        }
      }
    }

    final h = hourMin?.$1 ?? 14;
    final m = hourMin?.$2 ?? 0;
    return DateTime(cursor.year, cursor.month, cursor.day, h, m);
  }

  static (int, int)? _extractClock(String lower) {
    final am = RegExp(
      r'(\d{1,2})\s*(:\d{2})?\s*(am|pm)\b',
      caseSensitive: false,
    ).firstMatch(lower);
    if (am != null) {
      var hour = int.tryParse(am.group(1) ?? '') ?? 0;
      final minute = int.tryParse(
            am.group(2)?.replaceAll(':', '').trim() ?? '0',
          ) ??
          0;
      final isPm = (am.group(3) ?? '').toLowerCase() == 'pm';
      if (isPm && hour < 12) hour += 12;
      if (!isPm && hour == 12) hour = 0;
      return (hour, minute);
    }

    final twentyFour = RegExp(
      r'\b(\d{1,2}):(\d{2})\b',
    ).firstMatch(lower);
    if (twentyFour != null) {
      final hour = int.tryParse(twentyFour.group(1) ?? '') ?? 0;
      final minute = int.tryParse(twentyFour.group(2) ?? '') ?? 0;
      return (hour, minute);
    }

    final simple = RegExp(
      r'\b(\d{1,2})\s*pm\b',
      caseSensitive: false,
    ).firstMatch(lower);
    if (simple != null) {
      var hour = int.tryParse(simple.group(1) ?? '') ?? 0;
      if (hour < 12) hour += 12;
      return (hour, 0);
    }
    return null;
  }
}
