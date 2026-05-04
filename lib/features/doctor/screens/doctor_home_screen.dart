import 'package:flutter/material.dart';

import 'package:carelink/core/app_colors.dart';
import 'package:carelink/core/app_nav.dart';
import 'package:carelink/shared/models/user.dart';

/// Doctor role home — consultations, requests, and medical records integrate here.
class DoctorHomeScreen extends StatelessWidget {
  const DoctorHomeScreen({super.key, required this.user});

  final User user;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('CareLink — Doctor'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        actions: [
          TextButton(
            onPressed: () {
              appNavigatorKey.currentState?.pushNamedAndRemoveUntil(
                '/login',
                (route) => false,
              );
            },
            child: const Text('Sign out', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Text(
            'Welcome, ${user.fullName}',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: AppColors.textDark,
                ),
          ),
          const SizedBox(height: 12),
          Text(
            'Doctor workspace: review specialty-matched requests, accept or '
            'decline visits, file medical reports, and access patient records '
            '(aligned with the CareLink care provider flow).',
            style: TextStyle(color: Colors.grey.shade700, height: 1.4),
          ),
          const SizedBox(height: 24),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Next integration steps',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    '• List and filter /providers appointments by doctor role\n'
                    '• Visit reports via /medical-records/visit-report\n'
                    '• Patient chart: /patient/medical-record/:id',
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
