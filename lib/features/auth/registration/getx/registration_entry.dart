import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

import 'package:carelink/core/app_colors.dart';
import 'package:carelink/core/app_theme.dart';
import 'package:carelink/features/auth/registration/getx/carelink_registration_controller.dart';
import 'package:carelink/features/auth/registration/getx/carelink_registration_flow_screen.dart';
import 'package:carelink/features/auth/registration/getx/carelink_registration_models.dart';

/// Pushes [CarelinkRegistrationFlowScreen] with a dedicated GetX controller lifecycle.
class CarelinkRegistrationEntry extends StatefulWidget {
  const CarelinkRegistrationEntry({super.key, this.initialRole});

  /// Optional: `patient`, `nurse`, or `doctor` (e.g. from deep link `/email-register`).
  final String? initialRole;

  @override
  State<CarelinkRegistrationEntry> createState() =>
      _CarelinkRegistrationEntryState();
}

class _CarelinkRegistrationEntryState extends State<CarelinkRegistrationEntry> {
  @override
  void initState() {
    super.initState();
    final c = Get.put(CarelinkRegistrationController());
    final r = (widget.initialRole ?? 'patient').toLowerCase();
    if (r == 'nurse') {
      c.setRole(CarelinkRegistrationRole.nurse);
    } else if (r == 'doctor') {
      c.setRole(CarelinkRegistrationRole.doctor);
    } else {
      c.setRole(CarelinkRegistrationRole.patient);
    }
  }

  @override
  void dispose() {
    if (Get.isRegistered<CarelinkRegistrationController>()) {
      Get.delete<CarelinkRegistrationController>();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
        statusBarBrightness: Brightness.light,
        systemNavigationBarColor: AppColors.background,
        systemNavigationBarIconBrightness: Brightness.dark,
      ),
      child: Theme(
        data: AppTheme.light,
        child: const CarelinkRegistrationFlowScreen(),
      ),
    );
  }
}
