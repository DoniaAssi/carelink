import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:carelink/core/app_nav.dart';
import 'package:carelink/features/admin/screens/admin_home_screen.dart';
import 'package:carelink/features/nurse/screens/nurse_dashboard.dart';
import 'package:carelink/features/doctors/doctor/dashboard_screen.dart';
import 'package:carelink/shared/models/user.dart';

/// Same routing as [LoginScreen] after a successful auth response (`user` map).
void navigateCarelinkHomeForUserMap(Map<String, dynamic> rawUser) async {
  final userMap = Map<String, dynamic>.from(rawUser);
  if (userMap['id'] == null && userMap['userId'] != null) {
    userMap['id'] = userMap['userId'];
  }
  if (userMap['fullName'] == null && userMap['name'] != null) {
    userMap['fullName'] = userMap['name'];
  }
  if (userMap['role'] == null && userMap['userRole'] != null) {
    userMap['role'] = userMap['userRole'];
  }

  final user = User.fromJson(userMap);
  final role = user.role.toLowerCase();
  final userId = user.carelinkUserId;
  final userName = user.fullName.isNotEmpty ? user.fullName : 'User';

  final prefs = await SharedPreferences.getInstance();
  await prefs.setString('session_user_id', userId);
  await prefs.setString('session_display_name', userName);

  final nav = appNavigatorKey.currentState;
  if (nav == null) return;

  switch (role) {
    case 'patient':
      nav.pushNamedAndRemoveUntil(
        '/patient-home',
        (route) => false,
        arguments: {'userId': userId, 'displayName': userName},
      );
      break;
    case 'nurse':
      nav.pushReplacement(
        MaterialPageRoute<void>(builder: (_) => NurseDashboard(user: user)),
      );
      break;
    case 'doctor':
      // Save doctor info to SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('doctor_token', userId);
      await prefs.setString('doctor_userId', userId);
      await prefs.setString('doctor_fullName', userName);
      await prefs.setString(
        'doctor_email',
        (userMap['email'] ?? '').toString(),
      );
      await prefs.setString('doctor_role', role);

      nav.pushReplacement(
        MaterialPageRoute<void>(builder: (_) => const DoctorDashboardScreen()),
      );
      break;
    case 'admin':
      nav.pushReplacement(
        MaterialPageRoute<void>(
          builder: (_) => AdminHomeScreen(user: user),
        ),
      );
      break;
    default:
      nav.pushNamedAndRemoveUntil(
        '/patient-home',
        (route) => false,
        arguments: {'userId': userId, 'displayName': userName},
      );
  }
}
