import 'package:flutter/material.dart';
import '../../../core/doctor_session.dart';
import '../../../services/doctor_service.dart';
import '../../../core/app_colors.dart';
import 'doctor_ui_constants.dart';

class PendingApprovalScreen extends StatefulWidget {
  final String userId;
  final String fullName;
  final String email;

  const PendingApprovalScreen({
    super.key,
    required this.userId,
    required this.fullName,
    required this.email,
  });

  @override
  State<PendingApprovalScreen> createState() => _PendingApprovalScreenState();
}

class _PendingApprovalScreenState extends State<PendingApprovalScreen> {
  final _doctorService = DoctorService();
  bool _isLoading = false;
  String _status = 'pending';

  @override
  void initState() {
    super.initState();
    _checkApprovalStatus();
  }

  Future<void> _checkApprovalStatus() async {
    setState(() => _isLoading = true);

    try {
      final response = await _doctorService.checkApprovalStatus(widget.userId);
      setState(() {
        _status = response['status'] ?? 'pending';
      });
    } catch (e) {
      // Keep pending status on error
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: DoctorUiConstants.doctorBackground,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Spacer(),
              // Icon
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: AppColors.warning.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  _status == 'approved'
                      ? Icons.check_circle
                      : Icons.hourglass_empty,
                  size: 80,
                  color: _status == 'approved'
                      ? AppColors.success
                      : AppColors.warning,
                ),
              ),
              const SizedBox(height: 32),
              // Title
              Text(
                _status == 'approved'
                    ? 'Account Approved!'
                    : 'Pending Approval',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: _status == 'approved'
                      ? AppColors.success
                      : AppColors.warning,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              // Message
              Text(
                _status == 'approved'
                    ? 'Your doctor account has been approved. You can now access the system.'
                    : 'Your doctor account is pending approval from the administrator. Please check back later.',
                style: Theme.of(
                  context,
                ).textTheme.bodyLarge?.copyWith(color: AppColors.textSecondary),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              // User Info Card
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildInfoRow('Name', widget.fullName),
                      const Divider(),
                      _buildInfoRow('Email', widget.email),
                      const Divider(),
                      _buildInfoRow(
                        'Status',
                        _status == 'approved' ? 'Approved' : 'Pending',
                      ),
                    ],
                  ),
                ),
              ),
              const Spacer(),
              // Refresh Button
              if (_status != 'approved')
                SizedBox(
                  height: 50,
                  child: ElevatedButton.icon(
                    onPressed: _isLoading ? null : _checkApprovalStatus,
                    icon: _isLoading
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                Colors.white,
                              ),
                            ),
                          )
                        : const Icon(Icons.refresh),
                    label: Text(_isLoading ? 'Checking...' : 'Check Status'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
              const SizedBox(height: 16),
              // Logout Button
              TextButton(
                onPressed: () => logoutDoctorToLogin(context),
                child: const Text('Logout'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontWeight: FontWeight.w500,
              color: AppColors.textSecondary,
            ),
          ),
          Text(value, style: const TextStyle(fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}
