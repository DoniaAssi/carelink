import 'package:flutter_test/flutter_test.dart';

import 'package:carelink/features/ai/ai_slot_utils.dart';
import 'package:carelink/features/ai/recommendation/ai_recommendation_engine.dart';
import 'package:carelink/features/ai/recommendation/models/recommendation_models.dart';
import 'package:carelink/shared/models/provider_model.dart';

void main() {
  const patient = PatientRecommendationProfile(
    id: 'patient-1',
    fullName: 'Patient',
  );
  const request = RecommendationRequest(rawQuery: 'general care');

  ProviderModel provider({
    required String id,
    required bool isAvailable,
    required List<AvailabilitySlot> slots,
    bool isActive = true,
    bool isProfileComplete = true,
    String serviceType = 'General care',
    double? price = 100,
  }) {
    return ProviderModel(
      userId: id,
      fullName: id,
      specialization: 'General',
      serviceType: serviceType,
      overallRating: 4.5,
      role: 'doctor',
      isAvailable: isAvailable,
      isActive: isActive,
      isProfileComplete: isProfileComplete,
      consultationFee: price,
      availableSlots: slots,
    );
  }

  test('recommendations score only providers with free slots', () {
    final available = provider(
      id: 'available',
      isAvailable: true,
      slots: const [
        AvailabilitySlot(
          day: 'Monday',
          date: '2030-01-07',
          startTime: '09:00',
          endTime: '10:00',
        ),
      ],
    );
    final noSlots = provider(
      id: 'no-slots',
      isAvailable: true,
      slots: const [],
    );
    final disabled = provider(
      id: 'disabled',
      isAvailable: false,
      slots: available.availableSlots,
    );

    final results = AiRecommendationEngine.recommendProviders(
      patient: patient,
      request: request,
      providers: [noSlots, disabled, available],
    );

    expect(results.map((result) => result.provider.userId), ['available']);
  });

  test('recommendations reject providers that cannot enter booking flow', () {
    const slot = AvailabilitySlot(
      day: 'Monday',
      date: '2030-01-07',
      startTime: '09:00',
      endTime: '10:00',
    );
    final valid = provider(id: 'valid', isAvailable: true, slots: const [slot]);

    final results = AiRecommendationEngine.recommendProviders(
      patient: patient,
      request: request,
      providers: [
        provider(
          id: 'inactive',
          isAvailable: true,
          isActive: false,
          slots: const [slot],
        ),
        provider(
          id: 'incomplete',
          isAvailable: true,
          isProfileComplete: false,
          slots: const [slot],
        ),
        provider(
          id: 'no-service',
          isAvailable: true,
          serviceType: '',
          slots: const [slot],
        ),
        provider(
          id: 'no-price',
          isAvailable: true,
          price: null,
          slots: const [slot],
        ),
        provider(
          id: 'invalid-slot',
          isAvailable: true,
          slots: const [
            AvailabilitySlot(
              day: 'Monday',
              date: '2030-01-07',
              startTime: '',
              endTime: '10:00',
            ),
          ],
        ),
        valid,
      ],
    );

    expect(results.map((result) => result.provider.userId), ['valid']);
  });

  test('date-specific slots are sorted chronologically', () {
    const later = AvailabilitySlot(
      day: 'Tuesday',
      date: '2030-01-08',
      startTime: '09:00',
      endTime: '10:00',
    );
    const earlier = AvailabilitySlot(
      day: 'Monday',
      date: '2030-01-07',
      startTime: '11:00',
      endTime: '12:00',
    );

    expect(AiSlotUtils.sortedSlots([later, earlier]), [earlier, later]);
  });
}
