import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:carelink/core/app_colors.dart';
import 'package:carelink/core/patient_home_palette.dart';
import 'package:carelink/core/profile_avatar.dart'
    show profileAvatarOrPlaceholder;
import 'package:carelink/shared/models/appointment_model.dart';

class VisitRatingDialog extends StatefulWidget {
  const VisitRatingDialog({
    super.key,
    required this.appointment,
    required this.isArabic,
    required this.isSubmitting,
    required this.onLater,
    required this.onSubmit,
  });
  final AppointmentModel appointment;
  final bool isArabic, isSubmitting;
  final VoidCallback onLater;
  final Future<void> Function(int, String) onSubmit;
  @override
  State<VisitRatingDialog> createState() => _VisitRatingDialogState();
}

class _VisitRatingDialogState extends State<VisitRatingDialog> {
  static const gold = Color(0xFFF6A800);
  final comment = TextEditingController();
  int stars = 0;
  bool recommend = false;
  String t(String en, String ar) => widget.isArabic ? ar : en;
  String get label => [
    '',
    t('Poor', 'سيئة'),
    t('Fair', 'مقبولة'),
    t('Good', 'جيدة'),
    t('Very Good', 'جيدة جدًا'),
    t('Excellent', 'ممتازة'),
  ][stars];
  @override
  void dispose() {
    comment.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = PatientHomePalette.of(context), theme = Theme.of(context);
    final keyboard = MediaQuery.viewInsetsOf(context).bottom;
    final dialogWidth = (MediaQuery.sizeOf(context).width * .88).clamp(
      0.0,
      520.0,
    );
    return Positioned.fill(
      child: Directionality(
        textDirection: widget.isArabic ? TextDirection.rtl : TextDirection.ltr,
        child: Stack(
          children: [
            Positioned.fill(
              child: GestureDetector(
                onTap: widget.isSubmitting ? null : widget.onLater,
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 6, sigmaY: 6),
                  child: ColoredBox(
                    color: Colors.black.withValues(alpha: p.isDark ? .62 : .48),
                  ),
                ),
              ),
            ),
            Center(
              child: AnimatedPadding(
                duration: const Duration(milliseconds: 180),
                padding: EdgeInsets.fromLTRB(16, 16, 16, 16 + keyboard),
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    minWidth: dialogWidth,
                    maxWidth: dialogWidth,
                    maxHeight:
                        MediaQuery.sizeOf(context).height - keyboard - 32,
                  ),
                  child: Material(
                    color: p.surface,
                    borderRadius: BorderRadius.circular(28),
                    clipBehavior: Clip.antiAlias,
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _success(),
                          const SizedBox(height: 6),
                          Text(
                            t('Visit Completed', 'تمت الزيارة بنجاح'),
                            textAlign: TextAlign.center,
                            style: theme.textTheme.headlineSmall?.copyWith(
                              color: p.inkDark,
                              fontSize: 22,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            t(
                              'How was your experience with your care provider?',
                              'كيف كانت تجربتك مع مقدم الرعاية؟',
                            ),
                            textAlign: TextAlign.center,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: p.inkMuted,
                            ),
                          ),
                          const SizedBox(height: 10),
                          _provider(p, theme),
                          const SizedBox(height: 8),
                          _stars(),
                          AnimatedSwitcher(
                            duration: const Duration(milliseconds: 180),
                            child: stars == 0
                                ? const SizedBox(height: 22)
                                : Container(
                                    key: ValueKey(stars),
                                    margin: const EdgeInsets.only(top: 3),
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 20,
                                      vertical: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      color: gold.withValues(alpha: .11),
                                      borderRadius: BorderRadius.circular(99),
                                    ),
                                    child: Text(
                                      label,
                                      style: const TextStyle(
                                        color: gold,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                  ),
                          ),
                          const SizedBox(height: 8),
                          Align(
                            alignment: AlignmentDirectional.centerStart,
                            child: Text(
                              t(
                                'Write a comment (optional)',
                                'اكتب تعليقاً (اختياري)',
                              ),
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: p.inkDark,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                          const SizedBox(height: 5),
                          TextField(
                            controller: comment,
                            enabled: !widget.isSubmitting,
                            minLines: 1,
                            maxLines: 2,
                            decoration: InputDecoration(
                              hintText: t(
                                'Share your feedback about this visit...',
                                'شاركنا رأيك عن هذه الزيارة...',
                              ),
                              hintStyle: TextStyle(color: p.inkMuted),
                              prefixIcon: Icon(
                                Icons.edit_note_rounded,
                                color: p.inkMuted,
                              ),
                              filled: true,
                              fillColor: p.isDark
                                  ? p.pageBg.withValues(alpha: .55)
                                  : p.surface,
                              border: border(p.stroke),
                              enabledBorder: border(p.stroke),
                              focusedBorder: border(AppColors.primary),
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 10,
                              ),
                            ),
                          ),
                          const SizedBox(height: 2),
                          CheckboxListTile(
                            value: recommend,
                            enabled: !widget.isSubmitting,
                            onChanged: (v) =>
                                setState(() => recommend = v ?? false),
                            controlAffinity: ListTileControlAffinity.leading,
                            activeColor: AppColors.primary,
                            contentPadding: EdgeInsets.zero,
                            visualDensity: VisualDensity.compact,
                            title: Text(
                              t(
                                'I recommend this provider to other patients',
                                'أوصي بهذا المقدم للمرضى الآخرين',
                              ),
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: p.inkDark,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          const SizedBox(height: 4),
                          _buttons(),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  OutlineInputBorder border(Color c) => OutlineInputBorder(
    borderRadius: BorderRadius.circular(16),
    borderSide: BorderSide(color: c),
  );
  Widget _success() => SizedBox(
    width: 100,
    height: 58,
    child: Stack(
      alignment: Alignment.center,
      children: [
        Container(
          width: 58,
          height: 58,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: const Color(0xFF38C99A).withValues(alpha: .16),
          ),
          child: const Icon(
            Icons.check_rounded,
            color: Color(0xFF31BD8D),
            size: 34,
          ),
        ),
        const Positioned(
          left: 5,
          top: 8,
          child: Icon(Icons.auto_awesome, color: gold, size: 14),
        ),
        const Positioned(
          right: 3,
          top: 18,
          child: Icon(Icons.auto_awesome, color: Color(0xFF49C8B1), size: 13),
        ),
        const Positioned(
          left: 14,
          bottom: 4,
          child: Icon(Icons.circle, color: Color(0xFF49C8B1), size: 7),
        ),
        const Positioned(
          right: 13,
          bottom: 3,
          child: Icon(Icons.auto_awesome, color: gold, size: 11),
        ),
      ],
    ),
  );
  Widget _provider(PatientHomePalette p, ThemeData theme) {
    final name = widget.appointment.providerName.trim().isEmpty
        ? t('Care Provider', 'مقدم الرعاية')
        : widget.appointment.providerName.trim();
    final specialty = widget.appointment.specialization.trim().isNotEmpty
        ? widget.appointment.specialization.trim()
        : widget.appointment.providerRole.trim();
    return Column(
      children: [
        Container(
          width: 66,
          height: 66,
          padding: const EdgeInsets.all(3),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: AppColors.primary.withValues(alpha: .24),
              width: 3,
            ),
          ),
          child: ClipOval(
            child: profileAvatarOrPlaceholder(
              imageUrl: widget.appointment.providerImageUrl,
              size: 60,
              placeholderColor: AppColors.primary,
              placeholderIcon: Icons.medical_services_outlined,
              iconSize: 27,
            ),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          name,
          textAlign: TextAlign.center,
          style: theme.textTheme.titleMedium?.copyWith(
            color: p.inkDark,
            fontWeight: FontWeight.w900,
          ),
        ),
        if (specialty.isNotEmpty)
          Text(
            specialty,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(color: p.inkMuted),
          ),
      ],
    );
  }

  Widget _stars() => Directionality(
    textDirection: TextDirection.ltr,
    child: FittedBox(
      child: Row(
        children: List.generate(5, (i) {
          final value = i + 1, selected = value <= stars;
          return IconButton(
            constraints: const BoxConstraints(minWidth: 43, minHeight: 43),
            padding: const EdgeInsets.symmetric(horizontal: 2),
            onPressed: widget.isSubmitting
                ? null
                : () => setState(() => stars = value),
            icon: AnimatedScale(
              scale: selected ? 1.08 : 1,
              duration: const Duration(milliseconds: 180),
              curve: Curves.easeOutBack,
              child: Icon(
                selected ? Icons.star_rounded : Icons.star_border_rounded,
                size: 37,
                color: gold,
              ),
            ),
          );
        }),
      ),
    ),
  );
  Widget _buttons() => Row(
    children: [
      Expanded(
        child: OutlinedButton(
          onPressed: widget.isSubmitting ? null : widget.onLater,
          style: OutlinedButton.styleFrom(
            minimumSize: const Size.fromHeight(48),
            foregroundColor: AppColors.primary,
            side: const BorderSide(color: AppColors.primary),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
          ),
          child: Text(t('Later', 'ليس الآن')),
        ),
      ),
      const SizedBox(width: 12),
      Expanded(
        child: FilledButton(
          onPressed: stars == 0 || widget.isSubmitting
              ? null
              : () => widget.onSubmit(stars, comment.text.trim()),
          style: FilledButton.styleFrom(
            minimumSize: const Size.fromHeight(48),
            backgroundColor: AppColors.primary,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
          ),
          child: widget.isSubmitting
              ? const SizedBox.square(
                  dimension: 22,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.4,
                    color: Colors.white,
                  ),
                )
              : Text(
                  t('Submit Rating', 'إرسال التقييم'),
                  textAlign: TextAlign.center,
                ),
        ),
      ),
    ],
  );
}
