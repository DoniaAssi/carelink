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

  testWidgets('collapsed card expands into premium recommendation details', (
    tester,
  ) async {
    var taps = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 320,
              height: 620,
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
    await tester.pump(const Duration(milliseconds: 200));

    await tester.tap(find.text('Available Provider'));
    await tester.pumpAndSettle();
    expect(taps, 0);
    expect(find.text('View details'), findsOneWidget);
    expect(find.byIcon(Icons.verified_rounded), findsOneWidget);
    expect(find.byIcon(Icons.check_circle_rounded), findsWidgets);

    await tester.tap(find.text('View details'));
    expect(taps, 1);
  });

  testWidgets('emergency hero card uses the dedicated urgent presentation', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 320,
              height: 620,
              child: AiProviderRecommendationCard(
                result: result,
                distanceKm: 2.3,
                onTap: () {},
                highlighted: true,
                emergency: true,
                isArabic: true,
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 200));

    expect(find.text('الأفضل للحالة الطارئة'), findsOneWidget);
    expect(find.text('عرض التفاصيل'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
