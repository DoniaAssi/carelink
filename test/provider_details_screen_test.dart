import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:carelink/features/patient/screens/provider_details_screen.dart';
import 'package:carelink/shared/models/provider_model.dart';

void main() {
  testWidgets('provider details renders the redesigned mobile layout', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.reset();
      return tester.binding.setSurfaceSize(null);
    });

    final provider = ProviderModel(
      userId: 'provider-1',
      fullName: 'Dr. Maya Shalabi',
      specialization: 'Endocrinology',
      serviceType: 'Diabetes Follow-up,General Consultation',
      overallRating: 4.8,
      ratingsCount: 128,
      role: 'doctor',
      isAvailable: true,
      consultationFee: 150,
      availableSlots: const [
        AvailabilitySlot(
          day: 'Monday',
          date: '2030-01-07',
          startTime: '10:00',
          endTime: '11:00',
        ),
        AvailabilitySlot(
          day: 'Monday',
          date: '2030-01-07',
          startTime: '11:00',
          endTime: '12:00',
        ),
      ],
    );

    await tester.pumpWidget(
      MaterialApp(
        home: ProviderDetailsScreen(
          provider: provider,
          patientUserId: 'patient-1',
          distanceKm: 47.6,
          recommendation: const {
            'matchPercentage': 62,
            'medicalMatchScore': 0.95,
          },
        ),
      ),
    );
    await tester.pump();

    expect(find.text('Dr. Maya Shalabi'), findsWidgets);
    expect(find.text('Book Now'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.scrollUntilVisible(
      find.text('Services'),
      220,
      scrollable: find.byType(Scrollable),
    );

    expect(find.text('Services'), findsOneWidget);
    expect(find.text('Message'), findsOneWidget);
    expect(find.text('Favorite'), findsOneWidget);
    expect(find.text('Why this doctor matches you'), findsNothing);
    expect(find.text('Available Times'), findsNothing);
    expect(find.text('Book Now'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
