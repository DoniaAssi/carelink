import 'package:flutter/material.dart';

import 'package:carelink/core/app_colors.dart';
import 'package:carelink/core/app_localizations.dart';
import 'package:carelink/core/carelink_palette.dart';
import 'package:carelink/shared/models/booking_request_model.dart';
import 'package:carelink/shared/widgets/carelink_brand_logo.dart';
import 'package:carelink/shared/widgets/carelink_theme_toggle.dart'
    show carelinkLocaleThemeChipRow;
import 'booking_review_screen.dart';
import 'package:carelink/features/patient/widgets/booking_step_indicator.dart';

class PatientRequestDetailsScreen extends StatefulWidget {
  final BookingRequestModel request;

  const PatientRequestDetailsScreen({super.key, required this.request});

  @override
  State<PatientRequestDetailsScreen> createState() =>
      _PatientRequestDetailsScreenState();
}

class _PatientRequestDetailsScreenState
    extends State<PatientRequestDetailsScreen> {
  final TextEditingController _reasonController = TextEditingController();
  final TextEditingController _symptomsController = TextEditingController();
  final TextEditingController _additionalController = TextEditingController();
  bool _isUrgent = false;
  bool get _canContinue => _reasonController.text.trim().isNotEmpty;

  @override
  void initState() {
    super.initState();
    _reasonController.text = widget.request.patientReason;
    _symptomsController.text = widget.request.symptoms;
    _additionalController.text = widget.request.additionalNotes;
    _isUrgent = widget.request.isUrgent;
    _reasonController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _reasonController.dispose();
    _symptomsController.dispose();
    _additionalController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = CarelinkPalette.of(context);
    return Scaffold(
      backgroundColor: p.pageBg,
      bottomNavigationBar: SafeArea(
        top: false,
        child: Container(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          decoration: BoxDecoration(
            color: p.pageBg,
            border: Border(top: BorderSide(color: p.stroke)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: p.isDark ? 0.28 : 0.08),
                blurRadius: 18,
                offset: const Offset(0, -6),
              ),
            ],
          ),
          child: SizedBox(
            height: 54,
            child: ElevatedButton(
              onPressed: _canContinue
                  ? () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => BookingReviewScreen(
                            request: widget.request.copyWith(
                              patientReason: _reasonController.text.trim(),
                              symptoms: _symptomsController.text.trim(),
                              isUrgent: _isUrgent,
                              additionalNotes: _additionalController.text
                                  .trim(),
                            ),
                          ),
                        ),
                      );
                    }
                  : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: _canContinue
                    ? AppColors.primary
                    : p.surfaceSoft,
                foregroundColor: _canContinue ? Colors.white : p.inkMuted,
                elevation: _canContinue ? 2 : 0,
                shadowColor: AppColors.primary.withValues(alpha: 0.28),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    context.tr('patient.request.continueCta'),
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 18,
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Icon(Icons.arrow_forward_rounded),
                ],
              ),
            ),
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
        children: [
          _buildHeader(context, p),
          const SizedBox(height: 16),
          const BookingStepIndicator(currentStep: BookingFlowStep.details),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: p.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: p.stroke),
              boxShadow: [_cardShadow(p)],
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _circleIcon(Icons.psychology_alt_outlined),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        context.tr('patient.request.currentCase'),
                        style: TextStyle(
                          color: p.inkDark,
                          fontWeight: FontWeight.w800,
                          fontSize: 15,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        context.tr('patient.request.currentCaseBody'),
                        style: TextStyle(
                          color: p.inkMuted,
                          fontSize: 12.5,
                          height: 1.35,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          _fieldCard(
            icon: Icons.assignment_outlined,
            title: context.tr('patient.request.reasonVisit'),
            requiredMark: true,
            child: TextField(
              controller: _reasonController,
              cursorColor: AppColors.primary,
              style: TextStyle(color: p.inkDark, fontWeight: FontWeight.w600),
              minLines: 4,
              maxLines: 5,
              maxLength: 200,
              decoration: _inputDecoration(
                context.tr('patient.request.reasonPlaceholder'),
              ),
            ),
          ),
          const SizedBox(height: 10),
          _fieldCard(
            icon: Icons.monitor_heart_outlined,
            title: context.tr('patient.request.symptomsOptional'),
            child: TextField(
              controller: _symptomsController,
              cursorColor: AppColors.primary,
              style: TextStyle(color: p.inkDark, fontWeight: FontWeight.w600),
              minLines: 4,
              maxLines: 5,
              maxLength: 200,
              decoration: _inputDecoration(
                context.tr('patient.request.symptomsPlaceholder'),
              ),
            ),
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: p.surface,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: p.stroke),
              boxShadow: [_cardShadow(p)],
            ),
            child: Row(
              children: [
                _circleIcon(Icons.notifications_active_outlined),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        context.tr('patient.request.urgentTitle'),
                        style: TextStyle(
                          color: p.inkDark,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      SizedBox(height: 2),
                      Text(
                        context.tr('patient.request.urgentSub'),
                        style: TextStyle(color: p.inkMuted, fontSize: 12),
                      ),
                    ],
                  ),
                ),
                Switch(
                  value: _isUrgent,
                  activeThumbColor: AppColors.primary,
                  activeTrackColor: AppColors.primary.withValues(alpha: 0.28),
                  onChanged: (v) => setState(() => _isUrgent = v),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          _fieldCard(
            icon: Icons.notes_outlined,
            title: context.tr('patient.request.notesOptional'),
            child: TextField(
              controller: _additionalController,
              cursorColor: AppColors.primary,
              style: TextStyle(color: p.inkDark, fontWeight: FontWeight.w600),
              minLines: 4,
              maxLines: 5,
              maxLength: 200,
              decoration: _inputDecoration(
                context.tr('patient.request.additionalPlaceholder'),
              ),
            ),
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: p.surfaceSoft,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: p.stroke),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.info_outline_rounded,
                  color: AppColors.primary,
                  size: 18,
                ),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    context.tr('patient.request.infoStripDetailed'),
                    style: TextStyle(color: p.inkMuted, fontSize: 12),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.lock_outline_rounded, color: p.inkMuted, size: 14),
              const SizedBox(width: 6),
              Text(
                'Your information is kept confidential',
                style: TextStyle(color: p.inkMuted, fontSize: 11),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context, CarelinkPalette p) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
      decoration: BoxDecoration(
        color: p.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: p.stroke),
        boxShadow: [_cardShadow(p)],
      ),
      child: Row(
        children: [
          InkWell(
            onTap: () => Navigator.maybePop(context),
            borderRadius: BorderRadius.circular(14),
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: p.surfaceSoft,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: p.stroke),
              ),
              child: Icon(
                Icons.arrow_back_ios_new_rounded,
                size: 18,
                color: p.inkDark,
              ),
            ),
          ),
          const SizedBox(width: 10),
          CarelinkBrandLogo(
            height: 28,
            fallbackTextColor: p.inkDark,
            forceDarkLogo: p.isDark,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  context.tr('patient.request.detailsHeaderTitle'),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: p.inkDark,
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    height: 1.15,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  context.tr('patient.request.detailsSubtitle'),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: p.inkMuted,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
            decoration: BoxDecoration(
              color: p.surfaceSoft,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: p.stroke),
            ),
            child: carelinkLocaleThemeChipRow(iconColor: p.inkDark, gap: 4),
          ),
        ],
      ),
    );
  }

  BoxShadow _cardShadow(CarelinkPalette p) {
    return BoxShadow(
      color: Colors.black.withValues(alpha: p.isDark ? 0.22 : 0.045),
      blurRadius: 16,
      offset: const Offset(0, 8),
    );
  }

  Widget _fieldCard({
    required IconData icon,
    required String title,
    bool requiredMark = false,
    required Widget child,
  }) {
    final p = CarelinkPalette.of(context);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: p.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: p.stroke),
        boxShadow: [_cardShadow(p)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _circleIcon(icon),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  requiredMark ? '$title  *' : title,
                  style: TextStyle(
                    color: p.inkDark,
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          child,
        ],
      ),
    );
  }

  Widget _circleIcon(IconData icon) {
    final p = CarelinkPalette.of(context);
    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: p.isDark ? 0.16 : 0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Icon(icon, color: AppColors.primary, size: 20),
    );
  }

  InputDecoration _inputDecoration(String hint) {
    final p = CarelinkPalette.of(context);
    return InputDecoration(
      hintText: hint,
      counterText: '',
      filled: true,
      fillColor: p.filterSurface,
      hintStyle: TextStyle(color: p.inkMuted, fontWeight: FontWeight.w500),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: p.stroke),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.primary),
      ),
    );
  }
}
