import 'package:carelink/features/ai/recommendation/models/recommendation_models.dart';
import 'package:carelink/features/patient/services/patient_care_summary.dart';
import 'package:carelink/shared/models/provider_model.dart';

/// 8+ rich demo providers so the explainable recommender always has a diverse pool.
abstract final class MockAiData {
  static List<ProviderModel> demoProviders() =>
      _raw.map((m) => ProviderModel.fromJson(m)).toList();

  /// Synthetic “logged-out / cold” patient near Amman coordinates (tweak freely).
  static PatientRecommendationProfile newPatient(String id) {
    return PatientRecommendationProfile(
      id: id,
      fullName: 'Demo Patient',
      age: 28,
      gender: 'female',
      locationLatitude: 31.9539,
      locationLongitude: 35.9106,
      chronicDiseases: const [],
      allergies: const [],
      medications: const [],
      previousSurgeries: const [],
      careSummary: PatientCareSummary.empty,
      specializationRatingAffinity: const {},
      hasHistoryForWeighting: false,
    );
  }

  /// Returning user: heart history + great cardiologist visit => cardiologists float up.
  static PatientRecommendationProfile returningPatient(String id) {
    final summary = PatientCareSummary.mergeText(
      PatientCareSummary.mergeText(
        PatientCareSummary.fromText(
          'chronic heart disease congestive follow-up chest pain',
        ),
        'prior visit: cardiology consultation — five star experience',
        label: 'history',
      ),
      'visit report: chest pain follow-up advised — continue cardiology care',
      label: 'report',
    );

    return PatientRecommendationProfile(
      id: id,
      fullName: 'Sara Al-Masri',
      age: 54,
      gender: 'female',
      locationLatitude: 31.9539,
      locationLongitude: 35.9106,
      chronicDiseases: const ['Ischemic heart disease'],
      allergies: const ['Penicillin'],
      medications: const ['Aspirin', 'Metoprolol'],
      previousSurgeries: const ['Stent placement (2019)'],
      careSummary: summary,
      previousProviderRatings: const {'prov_cardio_001': 5.0},
      specializationRatingAffinity: const {'Cardiology': 5.0},
      successfulVisitProviderIds: const ['prov_cardio_001'],
      visitReportTexts: const [
        'Patient reports chest tightness on exertion — follow-up with cardiology advised.',
      ],
      followUpHints: const ['cardiology', 'follow-up'],
      hasHistoryForWeighting: true,
    );
  }

  static const List<Map<String, dynamic>> _raw = [
    {
      'userId': 'prov_cardio_001',
      'fullName': 'Dr. Marcus Horizon',
      'specialization': 'Cardiology',
      'serviceType': 'Home visit,Telehealth',
      'overallRating': 4.8,
      'role': 'doctor',
      'isAvailable': true,
      'consultationFee': 85,
      'experienceYears': 12,
      'gpsLat': 31.9543,
      'gpsLng': 35.9089,
      'availableSlots': [
        {
          'day': 'wednesday',
          'startTime': '13:00',
          'endTime': '17:00',
        },
        {
          'day': 'thursday',
          'startTime': '10:00',
          'endTime': '14:00',
        },
      ],
    },
    {
      'userId': 'prov_pulmo_002',
      'fullName': 'Dr. Lina Khoury',
      'specialization': 'Pulmonology',
      'serviceType': 'Home nursing,Respiratory care',
      'overallRating': 4.6,
      'role': 'doctor',
      'isAvailable': true,
      'consultationFee': 75,
      'experienceYears': 9,
      'gpsLat': 31.9510,
      'gpsLng': 35.9150,
      'availableSlots': [
        {'day': 'wednesday', 'startTime': '09:00', 'endTime': '12:00'},
        {'day': 'friday', 'startTime': '15:00', 'endTime': '18:00'},
      ],
    },
    {
      'userId': 'prov_dental_003',
      'fullName': 'Dr. Omar Naser',
      'specialization': 'Dentistry',
      'serviceType': 'Dental emergency',
      'overallRating': 4.4,
      'role': 'doctor',
      'isAvailable': false,
      'consultationFee': 60,
      'experienceYears': 6,
      'gpsLat': 31.9600,
      'gpsLng': 35.9000,
      'availableSlots': [
        {'day': 'saturday', 'startTime': '10:00', 'endTime': '13:00'},
      ],
    },
    {
      'userId': 'prov_psych_004',
      'fullName': 'Dr. Yasmeen Radi',
      'specialization': 'Psychiatry',
      'serviceType': 'Telehealth,Counseling',
      'overallRating': 4.7,
      'role': 'doctor',
      'isAvailable': true,
      'consultationFee': 70,
      'experienceYears': 11,
      'gpsLat': 31.9480,
      'gpsLng': 35.9220,
      'availableSlots': [
        {'day': 'monday', 'startTime': '11:00', 'endTime': '16:00'},
      ],
    },
    {
      'userId': 'prov_nurse_005',
      'fullName': 'Nurse Dana Salim',
      'specialization': 'Home Nursing',
      'serviceType': 'Wound care,Post-surgery',
      'overallRating': 4.9,
      'role': 'nurse',
      'isAvailable': true,
      'consultationFee': 45,
      'experienceYears': 10,
      'gpsLat': 31.9565,
      'gpsLng': 35.9070,
      'availableSlots': [
        {'day': 'wednesday', 'startTime': '08:00', 'endTime': '20:00'},
        {'day': 'thursday', 'startTime': '08:00', 'endTime': '20:00'},
      ],
    },
    {
      'userId': 'prov_general_006',
      'fullName': 'Dr. Kareem Fakhoury',
      'specialization': 'General Practice',
      'serviceType': 'Home visit',
      'overallRating': 4.3,
      'role': 'doctor',
      'isAvailable': true,
      'consultationFee': 55,
      'experienceYears': 4,
      'gpsLat': 31.9525,
      'gpsLng': 35.9185,
      'availableSlots': [
        {'day': 'tuesday', 'startTime': '12:00', 'endTime': '18:00'},
      ],
    },
    {
      'userId': 'prov_surgeon_007',
      'fullName': 'Dr. Hanna Mikhael',
      'specialization': 'General Surgery',
      'serviceType': 'Follow-up dressing',
      'overallRating': 4.5,
      'role': 'doctor',
      'isAvailable': true,
      'consultationFee': 120,
      'experienceYears': 15,
      'gpsLat': 31.9460,
      'gpsLng': 35.9250,
      'availableSlots': [
        {'day': 'sunday', 'startTime': '09:00', 'endTime': '11:00'},
      ],
    },
    {
      'userId': 'prov_covid_008',
      'fullName': 'Dr. Rami Saad',
      'specialization': 'Internal Medicine',
      'serviceType': 'Covid-19 monitoring',
      'overallRating': 4.2,
      'role': 'doctor',
      'isAvailable': true,
      'consultationFee': 50,
      'experienceYears': 7,
      'gpsLat': 31.9588,
      'gpsLng': 35.8995,
      'availableSlots': [
        {'day': 'wednesday', 'startTime': '14:00', 'endTime': '18:00'},
      ],
    },
  ];
}
