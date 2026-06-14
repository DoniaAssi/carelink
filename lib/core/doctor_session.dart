import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<void> clearDoctorSession() async {
  final prefs = await SharedPreferences.getInstance();
  await Future.wait([
    prefs.remove('doctor_token'),
    prefs.remove('doctor_userId'),
    prefs.remove('doctor_fullName'),
    prefs.remove('doctor_email'),
    prefs.remove('doctor_role'),
    prefs.remove('session_user_id'),
    prefs.remove('session_display_name'),
  ]);
}

Future<void> logoutDoctorToLogin(BuildContext context) async {
  await clearDoctorSession();
  if (!context.mounted) return;
  Navigator.of(context).pushNamedAndRemoveUntil('/login', (route) => false);
}
