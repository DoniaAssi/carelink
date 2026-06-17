import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:carelink/features/ai/recommendation/models/recommendation_models.dart';
import 'package:carelink/features/ai/widgets/ai_provider_recommendation_card.dart';
import 'package:carelink/shared/models/provider_model.dart';

void main() {
  final provider = ProviderModel(
    userId: 'provider-1',
    fullName: 'Available Provider',
    specialization: 'General Care',
    serviceType: 'General Doctor',
    overallRating: 4.7,
    role: 'doctor',
    isAvailable: true,
    consultationFee: 100,
    availableSlots: const [
      AvailabilitySlot(
        day: 'Monday',
        date: '2030-01-07',
        startTime: '09:00',
        endTime: '10:00',
      ),
    ],
  );
  final result = AIRecommendationResult(
    provider: provider,
    finalScore: 0.9,
    matchPercentage: 90,
    breakdown: const ScoreBreakdown(
      location: 1,
      specialization: 1,
      availability: 1,
      rating: 1,
      experience: 1,
      medicalCompatibility: 1,
      history: 0,
    ),
    weights: RecommendationWeights.coldStart,
    recommendationReasons: const ['Available match'],
  );

  testWidgets('card body and arrow both invoke provider navigation', (
    tester,
  ) async {
    var taps = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 220,
              height: 184,
              child: AiProviderRecommendationCard(
                result: result,
                distanceKm: null,
                onTap: () => taps += 1,
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Available Provider'));
    expect(taps, 1);

    await tester.tap(find.byIcon(Icons.arrow_forward_rounded));
    expect(taps, 2);
  });
}
