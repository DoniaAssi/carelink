import 'package:flutter/material.dart';

import 'package:carelink/features/ai/recommendation/ai_recommendation_repository.dart';
import 'package:carelink/features/ai/recommendation/models/recommendation_models.dart';
import 'package:carelink/features/ai/screens/find_provider_screen.dart';
import 'package:carelink/features/ai/screens/patient_ai_medical_record_screen.dart';
import 'package:carelink/features/ai/widgets/ai_flow_theme.dart';
import 'package:carelink/features/patient/screens/patient_home_screen.dart';
import 'package:carelink/shared/models/booking_request_model.dart';

/// Success step with navigation into the longitudinal medical record.
class AiBookingConfirmedScreen extends StatelessWidget {
  const AiBookingConfirmedScreen({
    super.key,
    required this.request,
    required this.appointmentId,
    required this.displayDate,
    required this.displayTime,
    required this.patientUserId,
  });

  final BookingRequestModel request;
  final String appointmentId;
  final String displayDate;
  final String displayTime;
  final String patientUserId;

  Future<void> _simulateVisitReport(BuildContext context) async {
    final store = AiMedicalRecordLocalStore();
    final entry = MedicalRecordEntry(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      patientId: patientUserId,
      appointmentId: appointmentId,
      uploadedBy: 'doctor',
      type: MedicalRecordEntryType.visitReport,
      title: 'Visit summary — ${request.providerName}',
      description: 'Home / telehealth encounter completed (demo).',
      diagnosis: 'Stable angina — continue cardiology follow-up',
      notes:
          'Vitals reviewed. Patient educated on symptoms. See attached ECG image in production.',
      prescription: 'Continue existing cardiac meds — no change today.',
      attachments: const [],
      createdAt: DateTime.now(),
      usedByAi: true,
      privateLabel: true,
      uploadedAfterVisit: true,
    );
    await store.add(patientUserId, entry);
    await store.appendProfileBoost(
      patientUserId,
      'follow-up cardiology chest pain stable visit report',
    );
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Visit report stored — future AI ranking will weigh this continuity.',
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final r = request;
    return Scaffold(
      backgroundColor: AiFlowTheme.pageBg,
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: AiFlowTheme.ink,
        title: const Text(
          'Booking confirmed',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const Icon(
            Icons.verified_rounded,
            size: 56,
            color: AiFlowTheme.primaryBlue,
          ),
          const SizedBox(height: 12),
          const Text(
            'Your appointment is confirmed',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w900,
              color: AiFlowTheme.ink,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Ref: $appointmentId',
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: AiFlowTheme.inkMuted,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AiFlowTheme.cardStroke),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _row('Provider', r.providerName),
                _row('Specialty', r.specialization),
                _row('When', '$displayDate · $displayTime'),
                _row('Location type', 'Home visit (CareLink demo)'),
                _row(
                  'Visit location',
                  r.visitAddress.trim().isEmpty
                      ? 'Address collected in production flow'
                      : r.visitAddress,
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          OutlinedButton(
            onPressed: () => _simulateVisitReport(context),
            style: OutlinedButton.styleFrom(
              foregroundColor: AiFlowTheme.primaryBlue,
              side: const BorderSide(color: AiFlowTheme.primaryBlue),
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
            child: const Text(
              'Simulate provider visit report (demo)',
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: 12),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: AiFlowTheme.primaryBlue,
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
            onPressed: () {
              Navigator.push<void>(
                context,
                MaterialPageRoute(
                  builder: (_) => PatientAiMedicalRecordScreen(
                    userId: patientUserId,
                  ),
                ),
              );
            },
            child: const Text('Go to medical record'),
          ),
          const SizedBox(height: 10),
          OutlinedButton(
            onPressed: () {
              Navigator.pushAndRemoveUntil<void>(
                context,
                MaterialPageRoute(
                  builder: (_) => PatientHomeScreen(userId: patientUserId),
                ),
                (_) => false,
              );
            },
            child: const Text('Back to home'),
          ),
          TextButton(
            onPressed: () {
              Navigator.push<void>(
                context,
                MaterialPageRoute(
                  builder: (_) =>
                      FindProviderScreen(userId: patientUserId),
                ),
              );
            },
            child: const Text('Find another provider'),
          ),
        ],
      ),
    );
  }

  Widget _row(String k, String v) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 118,
            child: Text(
              k,
              style: const TextStyle(
                color: AiFlowTheme.inkMuted,
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
            ),
          ),
          Expanded(
            child: Text(
              v,
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
          ),
        ],
      ),
    );
  }
}
