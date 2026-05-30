import 'package:flutter/material.dart';

import 'package:carelink/core/app_colors.dart';
import 'package:carelink/core/carelink_palette.dart';
import 'package:carelink/shared/services/medical_record_service.dart';
import 'medical_record_details_screen.dart';

/// Read-only list of provider-filed visit reports.
class PatientMedicalRecordsScreen extends StatefulWidget {
  const PatientMedicalRecordsScreen({
    super.key,
    required this.userId,
    this.requesterRole = 'patient',
  });

  final String userId;
  final String requesterRole;

  @override
  State<PatientMedicalRecordsScreen> createState() =>
      _PatientMedicalRecordsScreenState();
}

class _PatientMedicalRecordsScreenState
    extends State<PatientMedicalRecordsScreen> {
  final _service = MedicalRecordService();
  List<Map<String, dynamic>> _rows = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final id = widget.userId.trim();
    if (id.isEmpty) {
      setState(() {
        _loading = false;
        _rows = [];
      });
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final list = await _service.listForPatient(
        id,
        requesterUserId: id,
        requesterRole: widget.requesterRole,
      );
      if (!mounted) return;
      setState(() {
        _rows = list;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = CarelinkPalette.of(context);

    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: p.surfaceSoft.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: p.stroke),
            ),
            child: Text(
              'These are official visit reports from your providers. '
              'Update chronic conditions and medications under the Profile tab.',
              style: TextStyle(color: p.inkMuted, height: 1.35),
            ),
          ),
          const SizedBox(height: 16),
          if (_error != null)
            Text(_error!, style: TextStyle(color: Colors.red.shade700))
          else if (_rows.isEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 48),
              child: Center(
                child: Text(
                  'No visit reports yet.',
                  style: TextStyle(color: p.inkMuted),
                ),
              ),
            )
          else
            ..._rows.map((r) => _Card(row: r, userId: widget.userId)),
        ],
      ),
    );
  }
}

class _Card extends StatelessWidget {
  const _Card({required this.row, required this.userId});

  final Map<String, dynamic> row;
  final String userId;

  @override
  Widget build(BuildContext context) {
    final p = CarelinkPalette.of(context);
    final id = (row['id'] ?? '').toString();
    final provider = (row['providerName'] ?? 'Provider').toString();
    final title = (row['title'] ?? row['diagnosis'] ?? 'Visit report')
        .toString();
    final date = (row['visit_date'] ?? row['created_at'] ?? '').toString();

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: p.surface,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: id.isEmpty
              ? null
              : () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => MedicalRecordDetailsScreen(
                        recordId: id,
                        patientUserId: userId,
                        requesterRole: 'patient',
                      ),
                    ),
                  );
                },
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: p.stroke),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  provider,
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    color: p.inkDark,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: p.inkMuted),
                ),
                if (date.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    date,
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
