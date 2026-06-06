import 'package:carelink/features/ai/recommendation/models/recommendation_models.dart';

class RecommendationRequestParser {
  static RecommendationRequest fromInputs({
    required String searchText,
    String? categoryKey,
    DateTime? requestedDateTime,
    bool isUrgent = false,
    bool isComplexCase = false,
    String requestedServiceKeyword = '',
  }) {
    final q = searchText.trim().toLowerCase();

    // Auto-detect urgency
    final urgent = isUrgent ||
        q.contains('urgent') ||
        q.contains('emergency') ||
        q.contains('chest pain') ||
        q.contains('عاجل') ||
        q.contains('طارئ');

    // Derive keyword from categoryKey or free text
    String keyword = requestedServiceKeyword;
    if (keyword.isEmpty && categoryKey != null) {
      const keyMap = {
        'homeNurse': 'home nursing',
        'elderly': 'elderly care',
        'afterSurgery': 'post-surgery',
        'physio': 'physiotherapy',
        'mental': 'psychiatry',
        'cardiology': 'cardiology',
        'dental': 'dental',
        'general': 'general',
      };
      keyword = keyMap[categoryKey] ?? categoryKey;
    }

    return RecommendationRequest(
      rawQuery: searchText,
      categoryKey: categoryKey,
      requestedDateTime: requestedDateTime,
      isUrgent: urgent,
      isComplexCase: isComplexCase,
      requestedServiceKeyword: keyword,
    );
  }
}
