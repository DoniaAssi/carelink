import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:pinput/pinput.dart';

import 'package:carelink/core/app_colors.dart';
import 'package:carelink/core/app_localizations.dart';
import 'package:carelink/core/app_nav.dart';
import 'package:carelink/core/carelink_palette.dart';
import 'package:carelink/core/post_auth_navigation.dart';
import 'package:carelink/features/auth/registration/getx/carelink_registration_controller.dart';
import 'package:carelink/features/auth/registration/getx/carelink_registration_models.dart';
import 'package:carelink/features/auth/registration/getx/signup_location_picker_screen.dart';
import 'package:carelink/features/auth/registration/getx/widgets/custom_text_field.dart';
import 'package:carelink/features/auth/registration/getx/widgets/step_progress_indicator.dart';
import 'package:carelink/features/auth/registration/getx/widgets/role_selector.dart';
import 'package:carelink/features/auth/widgets/carelink_auth_branded_shell.dart';
import 'package:carelink/shared/widgets/carelink_trust_footer_bar.dart';
import 'package:carelink/shared/widgets/carelink_brand_logo.dart';

/// Same shell + card layout as [LoginScreen]: backdrop, back row, single form card.
class CarelinkRegistrationFlowScreen extends StatefulWidget {
  const CarelinkRegistrationFlowScreen({super.key});

  @override
  State<CarelinkRegistrationFlowScreen> createState() =>
      _CarelinkRegistrationFlowScreenState();
}

class _CarelinkRegistrationFlowScreenState
    extends State<CarelinkRegistrationFlowScreen> {
  final _formKey = GlobalKey<FormState>();

  void _snack(String text, {bool error = false}) {
    final m = appScaffoldMessengerKey.currentState;
    if (m == null) return;
    m.hideCurrentSnackBar();
    m.showSnackBar(
      SnackBar(
        content: Text(text),
        backgroundColor: error ? Colors.red.shade700 : const Color(0xFF1F2933),
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  Widget _registerFormCard(CarelinkPalette p, {required bool compact}) {
    final c = Get.find<CarelinkRegistrationController>();

    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 20 : 26,
        vertical: compact ? 22 : 26,
      ),
      decoration: BoxDecoration(
        color: p.surface.withValues(alpha: p.isDark ? 0.96 : 1),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: p.isDark
              ? Colors.white.withValues(alpha: 0.08)
              : AppColors.border.withValues(alpha: 0.65),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: p.isDark ? 0.35 : 0.07),
            blurRadius: 40,
            offset: const Offset(0, 18),
          ),
        ],
      ),
      child: Obx(() {
        final step = c.stepIndex.value;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            _registerHeader(context, p, c, step),
            SizedBox(height: compact ? 22 : 26),
            if (step == 0)
              Form(
                key: _formKey,
                child: _Step1Fields(
                  formKey: _formKey,
                  onAfterSend: () {
                    final err = c.errorText.value;
                    if (err != null && err.isNotEmpty) {
                      _snack(err, error: true);
                    } else {
                      _snack(context.tr('auth.verificationCodeSentPhone'));
                    }
                  },
                ),
              )
            else
              _Step2OtpBody(
                onAfterVerify: () {
                  final err = c.errorText.value;
                  if (err != null) _snack(err, error: true);
                },
              ),
          ],
        );
      }),
    );
  }

  Widget _registerHeader(
    BuildContext context,
    CarelinkPalette p,
    CarelinkRegistrationController c,
    int step,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Center(
          child: CarelinkBrandLogo(
            height: 36,
            fallbackTextColor: p.inkDark,
            forceDarkLogo: p.isDark,
          ),
        ),
        const SizedBox(height: 18),
        Text(
          step == 0
              ? context.tr('auth.signUp')
              : context.tr('auth.phoneVerificationTitle'),
          textAlign: TextAlign.center,
          style: GoogleFonts.inter(
            fontSize: 24,
            fontWeight: FontWeight.w800,
            color: p.inkDark,
            letterSpacing: -0.4,
          ),
        ),
        const SizedBox(height: 8),
        if (step == 0)
          Text(
            context.tr('auth.registerSubtitle'),
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              color: p.inkMuted,
              fontSize: 13.5,
              height: 1.45,
              fontWeight: FontWeight.w400,
            ),
          )
        else
          Text(
            context.tr(
              'auth.codeSentToPhone',
              args: {'phone': c.formattedPhoneDisplay()},
            ),
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              color: p.inkMuted,
              fontSize: 13.5,
              height: 1.45,
              fontWeight: FontWeight.w400,
            ),
          ),
        const SizedBox(height: 14),
        StepProgressIndicator(currentStepIndex: step),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = CarelinkPalette.of(context);
    final viewInsets = MediaQuery.viewInsetsOf(context).bottom;

    return Scaffold(
      backgroundColor: p.pageBg,
      resizeToAvoidBottomInset: true,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: CarelinkAuthBrandedShell(
              child: SafeArea(
                bottom: false,
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final w = constraints.maxWidth;
                    const horizontalPad = 20.0;
                    final maxCardW = w < 520 ? double.infinity : 440.0;

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        SizedBox(
                          height: 48,
                          child: Align(
                            alignment: AlignmentDirectional.centerStart,
                            child: Padding(
                              padding:
                                  const EdgeInsetsDirectional.only(start: 6),
                              child: IconButton(
                                onPressed: () {
                                  final c =
                                      Get.find<CarelinkRegistrationController>();
                                  if (c.stepIndex.value == 1) {
                                    c.goBackToStep1();
                                  } else {
                                    Get.back<void>();
                                  }
                                },
                                icon: const Icon(Icons.arrow_back_rounded),
                                color: p.inkDark,
                                iconSize: 24,
                                visualDensity: VisualDensity.compact,
                                constraints: const BoxConstraints.tightFor(
                                  width: 42,
                                  height: 42,
                                ),
                                padding: EdgeInsets.zero,
                              ),
                            ),
                          ),
                        ),
                        Expanded(
                          child: Center(
                            child: SingleChildScrollView(
                              padding: EdgeInsets.fromLTRB(
                                horizontalPad,
                                0,
                                horizontalPad,
                                16 + viewInsets,
                              ),
                              physics: const BouncingScrollPhysics(
                                parent: AlwaysScrollableScrollPhysics(),
                              ),
                              child: Align(
                                alignment: Alignment.topCenter,
                                child: ConstrainedBox(
                                  constraints:
                                      BoxConstraints(maxWidth: maxCardW),
                                  child:
                                      _registerFormCard(p, compact: w < 600),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ),
          ),
          const SafeArea(top: false, child: CarelinkTrustFooterBar()),
        ],
      ),
    );
  }
}

class _CarelinkPrimaryGradientButton extends StatelessWidget {
  const _CarelinkPrimaryGradientButton({
    required this.loading,
    required this.onPressed,
    required this.label,
    this.showTrailingArrow = false,
  });

  final bool loading;
  final VoidCallback? onPressed;
  final String label;
  final bool showTrailingArrow;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 50,
      width: double.infinity,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(999),
          gradient: LinearGradient(
            colors: loading
                ? [
                    AppColors.primary.withValues(alpha: 0.55),
                    AppColors.primaryDark.withValues(alpha: 0.55),
                  ]
                : const [AppColors.primary, AppColors.primaryDark],
          ),
          boxShadow: [
            BoxShadow(
              color: AppColors.primary.withValues(alpha: 0.28),
              blurRadius: 16,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onPressed,
            borderRadius: BorderRadius.circular(999),
            splashColor: Colors.white24,
            child: Center(
              child: loading
                  ? const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2.5,
                      ),
                    )
                  : Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          label,
                          style: GoogleFonts.inter(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                        if (showTrailingArrow) ...[
                          const SizedBox(width: 8),
                          const Icon(
                            Icons.arrow_forward_rounded,
                            color: Colors.white,
                            size: 20,
                          ),
                        ],
                      ],
                    ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Step1Fields extends StatefulWidget {
  const _Step1Fields({required this.formKey, required this.onAfterSend});

  final GlobalKey<FormState> formKey;
  final VoidCallback onAfterSend;

  @override
  State<_Step1Fields> createState() => _Step1FieldsState();
}

class _Step1FieldsState extends State<_Step1Fields> {
  bool _obscure = true;

  @override
  Widget build(BuildContext context) {
    final p = CarelinkPalette.of(context);
    final c = Get.find<CarelinkRegistrationController>();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        CustomTextField(
          controller: c.fullName,
          hintText: context.tr('auth.fullName'),
          icon: Icons.person_outline_rounded,
          textInputAction: TextInputAction.next,
          autofillHints: const [AutofillHints.name],
          validator: (v) =>
              (v ?? '').trim().length < 2 ? context.tr('auth.checkForm') : null,
        ),
        const SizedBox(height: 14),
        CustomTextField(
          controller: c.email,
          hintText: context.tr('auth.email'),
          helperBelow: context.tr('auth.emailOptionalHint'),
          icon: Icons.email_outlined,
          keyboardType: TextInputType.emailAddress,
          textInputAction: TextInputAction.next,
          autofillHints: const [AutofillHints.email],
          validator: (v) {
            final t = (v ?? '').trim();
            if (t.isEmpty) return null;
            if (!RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(t)) {
              return context.tr('auth.enterValidEmail');
            }
            return null;
          },
        ),
        const SizedBox(height: 14),
        CustomTextField(
          controller: c.phone,
          hintText: context.tr('auth.enterPhone'),
          icon: Icons.phone_iphone_rounded,
          keyboardType: TextInputType.phone,
          textInputAction: TextInputAction.next,
          autofillHints: const [AutofillHints.telephoneNumber],
          validator: (v) =>
              CarelinkRegistrationController.digitsOnly(v).length < 8
              ? context.tr('auth.invalidPhone')
              : null,
        ),
        const SizedBox(height: 14),
        CustomTextField(
          controller: c.password,
          hintText: context.tr('auth.password'),
          icon: Icons.lock_outline_rounded,
          obscureText: _obscure,
          autocorrect: false,
          enableSuggestions: false,
          textInputAction: TextInputAction.done,
          autofillHints: const [AutofillHints.newPassword],
          suffix: PasswordVisibilityIcon(
            obscure: _obscure,
            onToggle: () => setState(() => _obscure = !_obscure),
          ),
          validator: (v) =>
              (v ?? '').length < 8 ? context.tr('auth.passwordRequired') : null,
        ),
        const SizedBox(height: 18),
        GetBuilder<CarelinkRegistrationController>(
          builder: (ctrl) =>
              RoleSelector(value: ctrl.role, onChanged: ctrl.setRole),
        ),
        const SizedBox(height: 14),
        GetBuilder<CarelinkRegistrationController>(
          builder: (ctrl) {
            if (ctrl.role == CarelinkRegistrationRole.patient) {
              return _PatientSignupFields(controller: ctrl);
            }
            return _ProfessionalSignupFields(controller: ctrl);
          },
        ),
        Obx(() {
          final err = c.errorText.value;
          if (err == null || err.isEmpty) return const SizedBox.shrink();
          return Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Text(
              err,
              style: GoogleFonts.inter(
                color: Colors.red.shade700,
                fontSize: 13,
              ),
            ),
          );
        }),
        const SizedBox(height: 12),
        Obx(() {
          final busy = c.isBusy.value;
          return _CarelinkPrimaryGradientButton(
            loading: busy,
            showTrailingArrow: true,
            label: context.tr('auth.sendCode'),
            onPressed: busy
                ? null
                : () async {
                    if (!widget.formKey.currentState!.validate()) {
                      if (!context.mounted) return;
                      final m = appScaffoldMessengerKey.currentState;
                      m?.hideCurrentSnackBar();
                      m?.showSnackBar(
                        SnackBar(
                          content: Text(context.tr('auth.checkForm')),
                          backgroundColor: Colors.red.shade700,
                          behavior: SnackBarBehavior.floating,
                          margin: const EdgeInsets.all(16),
                        ),
                      );
                      return;
                    }
                    await c.submitSendOtp();
                    if (context.mounted) widget.onAfterSend();
                  },
          );
        }),
        const SizedBox(height: 22),
        Obx(() {
          final busy = c.isBusy.value;
          return Center(
            child: Wrap(
              crossAxisAlignment: WrapCrossAlignment.center,
              alignment: WrapAlignment.center,
              children: [
                Text(
                  context.tr('auth.haveAccount'),
                  style: GoogleFonts.inter(color: p.inkMuted, fontSize: 13.5),
                ),
                InkWell(
                  onTap: busy ? null : () => Get.back<void>(),
                  child: Text(
                    context.tr('auth.signIn'),
                    style: GoogleFonts.inter(
                      color: AppColors.primary,
                      fontWeight: FontWeight.w800,
                      fontSize: 13.5,
                    ),
                  ),
                ),
              ],
            ),
          );
        }),
      ],
    );
  }
}

class _PatientSignupFields extends StatelessWidget {
  const _PatientSignupFields({required this.controller});

  final CarelinkRegistrationController controller;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        CustomTextField(
          controller: controller.addressText,
          hintText: 'Address from map',
          icon: Icons.location_on_outlined,
          textInputAction: TextInputAction.next,
          autofillHints: const [AutofillHints.fullStreetAddress],
          readOnly: true,
          suffix: _MapPickerSuffix(controller: controller),
          validator: (v) {
            if ((v ?? '').trim().length < 3) return 'Address is required';
            return null;
          },
        ),
        const SizedBox(height: 14),
        CustomTextField(
          controller: controller.dateOfBirth,
          hintText: 'Date of birth (YYYY-MM-DD)',
          icon: Icons.calendar_today_outlined,
          keyboardType: TextInputType.datetime,
          textInputAction: TextInputAction.next,
          validator: (v) {
            final t = (v ?? '').trim();
            if (t.isEmpty) return null;
            if (!RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(t)) {
              return 'Use YYYY-MM-DD';
            }
            return null;
          },
        ),
        const SizedBox(height: 14),
        _CarelinkDropdownField(
          value: controller.gender,
          icon: Icons.wc_outlined,
          items: const {
            'prefer_not_to_say': 'Prefer not to say',
            'female': 'Female',
            'male': 'Male',
            'other': 'Other',
          },
          onChanged: controller.setGender,
        ),
        const SizedBox(height: 14),
        CustomTextField(
          controller: controller.chronicDiseases,
          hintText: 'Chronic diseases (optional)',
          icon: Icons.medical_information_outlined,
          textInputAction: TextInputAction.next,
        ),
        const SizedBox(height: 14),
        CustomTextField(
          controller: controller.allergies,
          hintText: 'Allergies (optional)',
          icon: Icons.warning_amber_rounded,
          textInputAction: TextInputAction.next,
        ),
        const SizedBox(height: 14),
        CustomTextField(
          controller: controller.currentMedications,
          hintText: 'Current medications (optional)',
          icon: Icons.medication_outlined,
          textInputAction: TextInputAction.next,
        ),
      ],
    );
  }
}

class _ProfessionalSignupFields extends StatelessWidget {
  const _ProfessionalSignupFields({required this.controller});

  final CarelinkRegistrationController controller;

  @override
  Widget build(BuildContext context) {
    final isNurse = controller.role == CarelinkRegistrationRole.nurse;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        CustomTextField(
          controller: controller.specialization,
          hintText: isNurse
              ? 'Nursing specialization'
              : 'Medical specialization',
          icon: Icons.health_and_safety_outlined,
          textInputAction: TextInputAction.next,
          validator: (v) {
            if ((v ?? '').trim().length < 2) {
              return 'Specialization is required';
            }
            return null;
          },
        ),
        const SizedBox(height: 14),
        CustomTextField(
          controller: controller.licenseNumber,
          hintText: 'License number',
          icon: Icons.badge_outlined,
          textInputAction: TextInputAction.next,
          validator: (v) {
            if ((v ?? '').trim().length < 3) {
              return 'License number is required';
            }
            return null;
          },
        ),
        const SizedBox(height: 14),
        CustomTextField(
          controller: controller.experienceYears,
          hintText: 'Experience years',
          icon: Icons.timeline_outlined,
          keyboardType: TextInputType.number,
          textInputAction: TextInputAction.next,
          validator: (v) {
            final t = (v ?? '').trim();
            if (t.isEmpty) return null;
            final n = int.tryParse(t);
            if (n == null || n < 0 || n > 80) {
              return 'Enter 0 to 80';
            }
            return null;
          },
        ),
        const SizedBox(height: 14),
        CustomTextField(
          controller: controller.serviceType,
          hintText: 'Service type (home care, clinic, emergency...)',
          icon: Icons.volunteer_activism_outlined,
          textInputAction: TextInputAction.next,
        ),
        const SizedBox(height: 14),
        CustomTextField(
          controller: controller.addressText,
          hintText: 'Provider address from map',
          icon: Icons.location_on_outlined,
          textInputAction: TextInputAction.next,
          autofillHints: const [AutofillHints.fullStreetAddress],
          readOnly: true,
          suffix: _MapPickerSuffix(controller: controller),
        ),
      ],
    );
  }
}

class _MapPickerSuffix extends StatelessWidget {
  const _MapPickerSuffix({required this.controller});

  final CarelinkRegistrationController controller;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: 'Choose on map',
      icon: const Icon(Icons.map_outlined),
      onPressed: () async {
        final result = await Navigator.push<SignupLocationResult>(
          context,
          MaterialPageRoute(
            builder: (_) => SignupLocationPickerScreen(
              initialAddress: controller.addressText.text.trim(),
              initialLatitude: controller.gpsLat,
              initialLongitude: controller.gpsLng,
            ),
          ),
        );
        if (result == null) return;
        controller.setLocation(
          address: result.address,
          latitude: result.latitude,
          longitude: result.longitude,
        );
      },
    );
  }
}

class _CarelinkDropdownField extends StatelessWidget {
  const _CarelinkDropdownField({
    required this.value,
    required this.items,
    required this.onChanged,
    required this.icon,
  });

  final String value;
  final Map<String, String> items;
  final ValueChanged<String> onChanged;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final p = CarelinkPalette.of(context);
    return DropdownButtonFormField<String>(
      value: value,
      isExpanded: true,
      icon: Icon(Icons.expand_more_rounded, color: p.inkMuted),
      decoration: InputDecoration(
        filled: true,
        fillColor: p.isDark
            ? const Color(0xFF123640).withValues(alpha: 0.55)
            : Colors.white,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 14,
        ),
        prefixIcon: Icon(icon, color: p.inkMuted, size: 22),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(
            color: AppColors.border.withValues(alpha: 0.9),
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(
            color: AppColors.border.withValues(alpha: 0.9),
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
        ),
      ),
      items: items.entries
          .map(
            (e) => DropdownMenuItem<String>(
              value: e.key,
              child: Text(
                e.value,
                style: GoogleFonts.inter(fontSize: 15, color: p.inkDark),
              ),
            ),
          )
          .toList(),
      onChanged: (v) {
        if (v != null) onChanged(v);
      },
    );
  }
}

class _Step2OtpBody extends StatelessWidget {
  const _Step2OtpBody({required this.onAfterVerify});

  final VoidCallback onAfterVerify;

  @override
  Widget build(BuildContext context) {
    final p = CarelinkPalette.of(context);
    final c = Get.find<CarelinkRegistrationController>();

    final fill = p.isDark
        ? const Color(0xFF123640).withValues(alpha: 0.55)
        : Colors.white;

    final pinTheme = PinTheme(
      width: 46,
      height: 52,
      textStyle: GoogleFonts.inter(
        fontSize: 20,
        fontWeight: FontWeight.w700,
        color: p.inkDark,
      ),
      decoration: BoxDecoration(
        color: fill,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border.withValues(alpha: 0.9)),
      ),
    );

    final focusedPinTheme = PinTheme(
      width: 46,
      height: 52,
      textStyle: GoogleFonts.inter(
        fontSize: 20,
        fontWeight: FontWeight.w700,
        color: p.inkDark,
      ),
      decoration: BoxDecoration(
        color: fill,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.primary, width: 1.5),
      ),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Pinput(
          length: 6,
          controller: c.pinController,
          defaultPinTheme: pinTheme,
          focusedPinTheme: focusedPinTheme,
          submittedPinTheme: pinTheme,
          keyboardType: TextInputType.number,
          pinAnimationType: PinAnimationType.scale,
          onCompleted: (_) => FocusScope.of(context).unfocus(),
        ),
        const SizedBox(height: 14),
        Center(
          child: Obx(() {
            final sec = c.resendSeconds.value;
            if (sec > 0) {
              return Text(
                context.tr('auth.resendIn', args: {'seconds': '$sec'}),
                style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.primary,
                ),
              );
            }
            return Obx(() {
              final busy = c.isBusy.value;
              return TextButton(
                onPressed: busy ? null : () => c.resendOtp(),
                child: Text(
                  context.tr('auth.resendCode'),
                  style: GoogleFonts.inter(
                    fontWeight: FontWeight.w700,
                    color: AppColors.primary,
                  ),
                ),
              );
            });
          }),
        ),
        Obx(() {
          final err = c.errorText.value;
          if (err == null || err.isEmpty) return const SizedBox.shrink();
          return Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              err,
              style: GoogleFonts.inter(
                color: Colors.red.shade700,
                fontSize: 13,
              ),
            ),
          );
        }),
        const SizedBox(height: 12),
        Obx(() {
          final busy = c.isBusy.value;
          return _CarelinkPrimaryGradientButton(
            loading: busy,
            showTrailingArrow: false,
            label: context.tr('auth.verifyCreateAccount'),
            onPressed: busy
                ? null
                : () async {
                    final user = await c.submitRegister();
                    if (!context.mounted) return;
                    if (user == null) {
                      onAfterVerify();
                      return;
                    }
                    final r = user.role.toLowerCase();
                    if (r == 'patient') {
                      Navigator.pushReplacementNamed(
                        context,
                        '/patient-home',
                        arguments: {
                          'userId': user.carelinkUserId,
                          'displayName': user.fullName.isNotEmpty
                              ? user.fullName
                              : 'User',
                        },
                      );
                    } else if (r == 'nurse' || r == 'doctor') {
                      navigateCarelinkHomeForUserMap(user.toJson());
                    } else {
                      Navigator.pushReplacementNamed(
                        context,
                        '/patient-home',
                        arguments: {
                          'userId': user.carelinkUserId,
                          'displayName': user.fullName,
                        },
                      );
                    }
                  },
          );
        }),
        const SizedBox(height: 8),
        Center(
          child: TextButton(
            onPressed: () => c.goBackToStep1(),
            child: Text(
              context.tr('auth.editAccount'),
              style: GoogleFonts.inter(
                fontWeight: FontWeight.w600,
                color: AppColors.primary,
                fontSize: 13.5,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
