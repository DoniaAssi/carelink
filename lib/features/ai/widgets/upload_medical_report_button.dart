import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:carelink/features/ai/recommendation/models/recommendation_models.dart';
import 'package:carelink/features/ai/recommendation/ai_recommendation_repository.dart';
import 'package:carelink/features/ai/widgets/ai_flow_theme.dart';

class UploadMedicalReportButton extends StatelessWidget {
  const UploadMedicalReportButton({
    super.key,
    required this.patientId,
    required this.onUploaded,
  });

  final String patientId;
  final VoidCallback onUploaded;

  Future<void> _pick(BuildContext context) async {
    final picker = ImagePicker();
    final file = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 72,
    );
    if (file == null) return;

    final store = AiMedicalRecordLocalStore();
    final entry = MedicalRecordEntry(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      patientId: patientId,
      uploadedBy: 'patient',
      type: MedicalRecordEntryType.oldReport,
      title: 'Uploaded medical file',
      description: file.name,
      attachments: [file.path],
      createdAt: DateTime.now(),
      usedByAi: true,
      privateLabel: true,
      uploadedAfterVisit: false,
    );
    await store.add(patientId, entry);
    await store.appendProfileBoost(
      patientId,
      'uploaded clinical file reference ${file.name}',
    );
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Document saved. The recommender will use summarized medical cues.',
          ),
        ),
      );
      onUploaded();
    }
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        style: OutlinedButton.styleFrom(
          foregroundColor: AiFlowTheme.primaryBlue,
          side: const BorderSide(color: AiFlowTheme.primaryBlue),
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
        onPressed: () => _pick(context),
        icon: const Icon(Icons.upload_file_rounded),
        label: const Text(
          'Upload previous report / image (optional)',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
    );
  }
}
