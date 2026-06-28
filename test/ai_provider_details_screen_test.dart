import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:carelink/features/ai/recommendation/models/recommendation_models.dart';
import 'package:carelink/features/ai/screens/ai_provider_details_screen.dart';
import 'package:carelink/shared/models/provider_model.dart';

void main() {
  testWidgets('AI provider details follows the compact mobile profile layout', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final provider = ProviderModel(
      userId: 'provider-1',
      fullName: 'Fatima Mahmoud',
      specialization: 'Home Nursing',
      serviceType: 'Wound Care',
      overallRating: 4.8,
      ratingsCount: 128,
      role: 'nurse',
      isAvailable: true,
      experienceYears: 6,
      consultationFee: 100,
      availableSlots: const [
        AvailabilitySlot(
          day: 'Monday',
          date: '2030-01-07',
          startTime: '10:00',
          endTime: '11:00',
        ),
      ],
    );
    final result = AIRecommendationResult(
      provider: provider,
      finalScore: 0.87,
      matchPercentage: 87,
      breakdown: const ScoreBreakdown(
        location: 0.9,
        specialization: 0.95,
        availability: 1,
        rating: 0.96,
        experience: 0.9,
        medicalCompatibility: 0.95,
        history: 0,
      ),
      weights: RecommendationWeights.coldStart,
      recommendationReasons: const ['Strong medical match'],
    );

    await tester.pumpWidget(
      MaterialApp(
        home: AiProviderDetailsScreen(
          result: result,
          patientUserId: '',
          distanceKm: 2.3,
        ),
      ),
    );
    await tester.pump();

    expect(find.text('Care Provider Details'), findsOneWidget);
    expect(find.text('Fatima Mahmoud'), findsOneWidget);
    expect(find.text('About the provider'), findsOneWidget);
    expect(
      find.text(
        'Specialty: Home Nursing • Service: Wound Care • Years of experience: 6',
      ),
      findsOneWidget,
    );
    expect(find.text('Wound Care'), findsOneWidget);
    expect(find.text('Medication'), findsNothing);
    expect(find.text('Book appointment'), findsOneWidget);
    expect(find.text('Chat'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.scrollUntilVisible(
      find.text('Ratings'),
      220,
      scrollable: find.byType(Scrollable),
    );
    expect(find.text('Ratings'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
