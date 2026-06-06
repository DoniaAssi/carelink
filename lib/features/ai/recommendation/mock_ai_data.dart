import 'package:carelink/features/ai/recommendation/models/recommendation_models.dart'
    as recommendation_models;
import 'package:carelink/shared/models/provider_model.dart';

class MockAiData {
  static List<ProviderModel> demoProviders() => <ProviderModel>[];

  static recommendation_models.PatientRecommendationProfile newPatient(String id) =>
      recommendation_models.PatientRecommendationProfile(
        id: id,
        fullName: 'Guest',
      );

  static recommendation_models.PatientRecommendationProfile returningPatient(String id) =>
      recommendation_models.PatientRecommendationProfile(
        id: id,
        fullName: 'Guest',
      );
}
