import 'package:flutter/material.dart';

import 'package:carelink/core/app_nav.dart';
import 'package:carelink/features/admin/screens/admin_home_screen.dart';
import 'package:carelink/features/doctor/screens/doctor_home_screen.dart';
import 'package:carelink/features/nurse/screens/nurse_dashboard.dart';
import 'package:carelink/shared/models/user.dart';

/// Same routing as [LoginScreen] after a successful auth response (`user` map).
void navigateCarelinkHomeForUserMap(Map<String, dynamic> rawUser) {
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

  final nav = appNavigatorKey.currentState;
  if (nav == null) return;

  switch (role) {
    case 'patient':
      nav.pushReplacementNamed(
        '/patient-home',
        arguments: {'userId': userId, 'displayName': userName},
      );
      break;
    case 'nurse':
      nav.pushReplacement(
        MaterialPageRoute<void>(
          builder: (_) => NurseDashboard(user: user),
        ),
      );
      break;
    case 'doctor':
      nav.pushReplacement(
        MaterialPageRoute<void>(
          builder: (_) => DoctorHomeScreen(user: user),
        ),
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
      nav.pushReplacementNamed(
        '/patient-home',
        arguments: {'userId': userId, 'displayName': userName},
      );
  }
}
