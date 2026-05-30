import 'dart:math' as math;

import 'package:flutter/foundation.dart';

/// نتيجة تحليل نص بسيط (بدون خادم AI): يطابق التخصصات الموجودة فعلياً في التطبيق.
@immutable
class CareIntentResult {
  const CareIntentResult({
    required this.specialtyChip,
    this.restrictToAvailable = false,
    this.matchedLabel = '',
  });

  /// قيمة من قائمة التخصصات: `All` أو نفس نص `specialization` عند مقدمي الخدمة.
  final String specialtyChip;

  /// إذا نص المستخدم أشار للتوفر الفوري.
  final bool restrictToAvailable;

  /// لعرضه للمستخدم (عربي/إنجليزي مختصر).
  final String matchedLabel;

  static const CareIntentResult none = CareIntentResult(
    specialtyChip: 'All',
    matchedLabel: '',
  );
}

/// يحلل [query] ويطابق أحد [availableSpecialtyChips] (يتضمّن عادة `All` أولاً).
CareIntentResult parseCareIntent(
  String rawQuery,
  List<String> availableSpecialtyChips,
) {
  final q = _normalize(rawQuery);
  if (q.isEmpty) return CareIntentResult.none;

  final restrictToAvailable = _wantsNow(q);

  // 1) تطابق مباشر باسم التخصص الظاهر في الشريط
  for (final spec in availableSpecialtyChips) {
    if (spec == 'All') continue;
    final s = _normalize(spec);
    if (q.contains(s) ||
        s.split(' ').any((w) => w.length > 2 && q.contains(w))) {
      return CareIntentResult(
        specialtyChip: spec,
        restrictToAvailable: restrictToAvailable,
        matchedLabel: spec,
      );
    }
  }

  final intentSpec = _bestIntentSpec(q, availableSpecialtyChips);
  if (intentSpec != null) {
    return CareIntentResult(
      specialtyChip: intentSpec,
      restrictToAvailable: restrictToAvailable,
      matchedLabel: intentSpec,
    );
  }

  // 2) مرادفات شائعة → تطبيع جزئي مع أسماء التخصصات في القائمة
  for (final spec in availableSpecialtyChips) {
    if (spec == 'All') continue;
    if (_keywordMapsToSpec(q, spec)) {
      return CareIntentResult(
        specialtyChip: spec,
        restrictToAvailable: restrictToAvailable,
        matchedLabel: spec,
      );
    }
  }

  // 3) لا تطابق: أبقِ الكل واشرح للواجهة
  if (restrictToAvailable) {
    return const CareIntentResult(
      specialtyChip: 'All',
      restrictToAvailable: true,
      matchedLabel: 'available only',
    );
  }

  return CareIntentResult.none;
}

bool _wantsNow(String q) {
  final lower = _normalize(q);
  if (lower.contains('free now')) return true;
  if (RegExp(r'\b(available|now|today)\b').hasMatch(lower)) return true;
  const arabic = ['متوفر', 'فوري', 'الآن', 'اليوم'];
  for (final k in arabic) {
    if (q.contains(k)) return true;
  }
  return false;
}

String? _bestIntentSpec(String q, List<String> specs) {
  if (_hasAnyTerm(q, _childCareTerms)) {
    return _firstSpec(
          specs,
          (s) => s.contains('pediatr') || s.contains('child'),
        ) ??
        _firstSpec(
          specs,
          (s) => s.contains('nurs') || s.contains('home care'),
        ) ??
        _firstSpec(specs, (s) => s.contains('general') || s.contains('family'));
  }
  if (_hasAnyTerm(q, _dentalCareTerms)) {
    return _firstSpec(specs, (s) => s.contains('dental') || s.contains('dent'));
  }
  if (_hasAnyTerm(q, _heartCareTerms)) {
    return _firstSpec(
      specs,
      (s) => s.contains('cardio') || s.contains('heart'),
    );
  }
  if (_hasAnyTerm(q, _nursingCareTerms)) {
    return _firstSpec(
      specs,
      (s) => s.contains('nurs') || s.contains('home care'),
    );
  }
  return null;
}

String? _firstSpec(List<String> specs, bool Function(String normalized) match) {
  for (final spec in specs) {
    if (spec == 'All') continue;
    if (match(_normalize(spec))) return spec;
  }
  return null;
}

bool _keywordMapsToSpec(String q, String spec) {
  final s = _normalize(spec);
  if (s.contains('cardio') || s.contains('heart') || s.contains('القلب')) {
    if (_hasAnyTerm(q, _heartCareTerms)) {
      return true;
    }
  }
  if (s.contains('neuro') || s.contains('brain')) {
    if (_hasAnyTerm(q, const [
      'neuro',
      'neurolog',
      'brain',
      'stroke',
      'دماغ',
      'اعصاب',
      'أعصاب',
    ])) {
      return true;
    }
  }
  if (s.contains('pediatr') || s.contains('child')) {
    if (_hasAnyTerm(q, _childCareTerms)) {
      return true;
    }
  }
  if (s.contains('dental') || s.contains('dent')) {
    if (_hasAnyTerm(q, _dentalCareTerms)) {
      return true;
    }
  }
  if (s.contains('nurs') || s.contains('home care')) {
    if (_hasAnyTerm(q, _nursingCareTerms)) {
      return true;
    }
  }
  if (s.contains('derma') || s.contains('skin')) {
    if (_hasAnyTerm(q, const ['derma', 'skin', 'جلد'])) {
      return true;
    }
  }
  if (s.contains('ortho') || s.contains('bone') || s.contains('joint')) {
    if (_hasAnyTerm(q, const ['ortho', 'bone', 'joint', 'عظام', 'ركبة'])) {
      return true;
    }
  }
  if (s.contains('gp') || s.contains('general')) {
    if (_hasAnyTerm(q, const [
      'gp',
      'general',
      'family doctor',
      'عام',
      'طبيب عام',
    ])) {
      return true;
    }
  }
  return false;
}

const _heartCareTerms = [
  'cardio',
  'cardiologist',
  'cardiology',
  'heart',
  'قلب',
];

const _childCareTerms = [
  'pediatr',
  'paediatr',
  'pediatric',
  'paediatric',
  'child',
  'children',
  'childreen',
  'kid',
  'kids',
  'baby',
  'babies',
  'infant',
  'newborn',
  'toddler',
  'أطفال',
  'طفل',
  'اطفال',
  'ولاد',
  'رضيع',
];

const _dentalCareTerms = [
  'dental',
  'dentist',
  'teeth',
  'tooth',
  'أسنان',
  'اسنان',
  'سن',
  'سنان',
];

const _nursingCareTerms = [
  'nurs',
  'nurse',
  'nursing',
  'home care',
  'homecare',
  'visit',
  'ممرض',
  'ممرضة',
  'تمريض',
  'رعاية منزلية',
];

bool _hasAnyTerm(String q, List<String> terms) {
  final normalizedQuery = _normalize(q);
  final queryTokens = _tokens(normalizedQuery);
  for (final term in terms) {
    final normalizedTerm = _normalize(term);
    if (normalizedTerm.isEmpty) continue;
    if (normalizedQuery.contains(normalizedTerm)) return true;
    final termTokens = _tokens(normalizedTerm);
    if (termTokens.isEmpty) continue;
    final allClose = termTokens.every(
      (termToken) => queryTokens.any((token) => _closeToken(token, termToken)),
    );
    if (allClose) return true;
  }
  return false;
}

List<String> _tokens(String value) => value
    .split(RegExp(r'[^a-z0-9\u0600-\u06FF]+'))
    .where((token) => token.length > 1)
    .toList();

bool _closeToken(String a, String b) {
  if (a == b || a.contains(b) || b.contains(a)) return true;
  final maxLen = math.max(a.length, b.length);
  if (maxLen < 4) return false;
  final allowed = maxLen <= 6 ? 1 : 2;
  return _levenshteinAtMost(a, b, allowed);
}

bool _levenshteinAtMost(String a, String b, int maxDistance) {
  if ((a.length - b.length).abs() > maxDistance) return false;
  var previous = List<int>.generate(b.length + 1, (i) => i);
  for (var i = 0; i < a.length; i++) {
    final current = List<int>.filled(b.length + 1, 0);
    current[0] = i + 1;
    var rowMin = current[0];
    for (var j = 0; j < b.length; j++) {
      final cost = a.codeUnitAt(i) == b.codeUnitAt(j) ? 0 : 1;
      current[j + 1] = math.min(
        math.min(current[j] + 1, previous[j + 1] + 1),
        previous[j] + cost,
      );
      rowMin = math.min(rowMin, current[j + 1]);
    }
    if (rowMin > maxDistance) return false;
    previous = current;
  }
  return previous.last <= maxDistance;
}

String _normalize(String value) {
  return value
      .toLowerCase()
      .replaceAll(RegExp(r'[\u064B-\u065F\u0670]'), '')
      .replaceAll('أ', 'ا')
      .replaceAll('إ', 'ا')
      .replaceAll('آ', 'ا')
      .replaceAll('ى', 'ي')
      .replaceAll('ة', 'ه')
      .trim();
}
