import 'package:flutter/material.dart';

import 'package:carelink/core/app_colors.dart';
import 'package:carelink/core/carelink_palette.dart';
import 'package:carelink/services/doctor_service.dart';

import 'dashboard_screen.dart';
import 'doctor_ui_constants.dart';

class DoctorRateApprovalScreen extends StatefulWidget {
  const DoctorRateApprovalScreen({super.key, required this.doctorId});

  final String doctorId;

  @override
  State<DoctorRateApprovalScreen> createState() =>
      _DoctorRateApprovalScreenState();
}

class _DoctorRateApprovalScreenState extends State<DoctorRateApprovalScreen> {
  final DoctorService _doctorService = DoctorService();

  bool _isLoading = true;
  bool _isSubmitting = false;
  bool _openingDashboard = false;
  String? _errorMessage;
  Map<String, dynamic> _rateStatus = const <String, dynamic>{};

  String get _acceptanceStatus =>
      (_rateStatus['rateAcceptanceStatus'] ?? 'pending')
          .toString()
          .trim()
          .toLowerCase();

  double get _assignedRate {
    final value = _rateStatus['providerRate'];
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '') ?? 0;
  }

  bool get _hasAssignedRate => _assignedRate > 0;

  @override
  void initState() {
    super.initState();
    _loadRateStatus();
  }

  Future<void> _loadRateStatus() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final status = await _doctorService.getRateStatus(widget.doctorId);
      if (!mounted) return;
      _rateStatus = status;
      if (_acceptanceStatus == 'accepted') {
        _openDashboard();
        return;
      }
      setState(() => _isLoading = false);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = error.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  Future<void> _submitDecision(String decision) async {
    if (_isSubmitting || !_hasAssignedRate) return;
    setState(() => _isSubmitting = true);

    try {
      final status = await _doctorService.decideRate(widget.doctorId, decision);
      if (!mounted) return;
      _rateStatus = status;

      if (decision == 'accepted' && _acceptanceStatus == 'accepted') {
        _openDashboard();
        return;
      }

      setState(() => _isSubmitting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Rate rejected. Please wait for the administrator to review or update it.',
          ),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      setState(() => _isSubmitting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error.toString().replaceFirst('Exception: ', '')),
          backgroundColor: Colors.red.shade700,
        ),
      );
    }
  }

  void _openDashboard() {
    if (!mounted || _openingDashboard) return;
    _openingDashboard = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute<void>(builder: (_) => const DoctorDashboardScreen()),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final palette = CarelinkPalette.of(context);

    return DoctorTypographyScope(
      child: PopScope(
        canPop: false,
        child: Scaffold(
          backgroundColor: DoctorUiConstants.doctorBackground,
          appBar: AppBar(
            automaticallyImplyLeading: false,
            title: const Text('Hourly Rate Approval'),
            centerTitle: true,
            backgroundColor: DoctorUiConstants.doctorBackground,
            foregroundColor: palette.inkDark,
            elevation: 0,
          ),
          body: _isLoading
              ? const Center(
                  child: CircularProgressIndicator(color: AppColors.primary),
                )
              : _errorMessage != null
              ? _buildErrorState(palette)
              : _buildApprovalContent(palette),
        ),
      ),
    );
  }

  Widget _buildApprovalContent(CarelinkPalette palette) {
    final rejected = _acceptanceStatus == 'rejected';

    return SafeArea(
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 620),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: palette.surface,
                borderRadius: BorderRadius.circular(22),
                border: Border.all(color: palette.stroke),
                boxShadow: [
                  BoxShadow(
                    color: palette.cardShadowColor(0.07),
                    blurRadius: 22,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.11),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.notifications_active_outlined,
                      color: AppColors.primary,
                      size: 32,
                    ),
                  ),
                  const SizedBox(height: 18),
                  Text(
                    'Hourly Rate Approval',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: palette.inkDark,
                      fontSize: 23,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    _hasAssignedRate
                        ? 'The administrator has assigned your service rate. Please review and accept it before continuing.'
                        : 'Your hourly rate has not been assigned yet. Please wait for the administrator to update your account.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: palette.inkMuted,
                      fontSize: 15,
                      height: 1.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 22),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 18,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.09),
                      borderRadius: BorderRadius.circular(17),
                    ),
                    child: Column(
                      children: [
                        Text(
                          'Admin Assigned Rate',
                          style: TextStyle(
                            color: palette.inkMuted,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          _hasAssignedRate
                              ? '${_formatRate(_assignedRate)} ILS/hour'
                              : 'Waiting for rate',
                          style: const TextStyle(
                            color: AppColors.primary,
                            fontSize: 26,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (rejected) ...[
                    const SizedBox(height: 16),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.red.withValues(alpha: 0.07),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Text(
                        'You need to accept the hourly rate before using your doctor account.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.red.shade700,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed:
                              !_hasAssignedRate || _isSubmitting || rejected
                              ? null
                              : () => _submitDecision('rejected'),
                          icon: const Icon(Icons.close_rounded),
                          label: const Text('Reject'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.red.shade700,
                            side: BorderSide(color: Colors.red.shade300),
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        flex: 2,
                        child: FilledButton.icon(
                          onPressed: !_hasAssignedRate || _isSubmitting
                              ? null
                              : () => _submitDecision('accepted'),
                          icon: _isSubmitting
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Icon(Icons.check_rounded),
                          label: const Text('Accept Rate'),
                          style: FilledButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (!_hasAssignedRate) ...[
                    const SizedBox(height: 14),
                    TextButton.icon(
                      onPressed: _isLoading ? null : _loadRateStatus,
                      icon: const Icon(Icons.refresh_rounded),
                      label: const Text('Check Again'),
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

  Widget _buildErrorState(CarelinkPalette palette) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.error_outline_rounded,
              color: Colors.redAccent,
              size: 52,
            ),
            const SizedBox(height: 14),
            Text(
              _errorMessage!,
              textAlign: TextAlign.center,
              style: TextStyle(color: palette.inkMuted),
            ),
            const SizedBox(height: 18),
            FilledButton.icon(
              onPressed: _loadRateStatus,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Try Again'),
            ),
          ],
        ),
      ),
    );
  }

  String _formatRate(double rate) {
    return rate == rate.roundToDouble()
        ? rate.toStringAsFixed(0)
        : rate.toStringAsFixed(2);
  }
}
