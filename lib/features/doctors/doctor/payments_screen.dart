import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../services/doctor_service.dart';
import '../../../core/app_colors.dart';

class DoctorPaymentsScreen extends StatefulWidget {
  const DoctorPaymentsScreen({super.key});

  @override
  State<DoctorPaymentsScreen> createState() => _DoctorPaymentsScreenState();
}

class _DoctorPaymentsScreenState extends State<DoctorPaymentsScreen> {
  final _doctorService = DoctorService();

  bool _isLoading = true;
  Map<String, dynamic> _paymentsData = {};
  String _doctorId = '';

  @override
  void initState() {
    super.initState();
    _loadPayments();
  }

  Future<void> _loadPayments() async {
    setState(() => _isLoading = true);

    try {
      final prefs = await SharedPreferences.getInstance();
      _doctorId = prefs.getString('doctor_userId') ?? '';

      final data = await _doctorService.getPayments(_doctorId);
      setState(() {
        _paymentsData = data;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error loading payments: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final payments = _paymentsData['payments'] as List? ?? [];
    final summary = _paymentsData['summary'] ?? {};
    final totalPaid = _toMoney(summary['totalPaid']);
    final totalUnpaid = _toMoney(summary['totalUnpaid']);
    final totalRefunded = _toMoney(summary['totalRefunded']);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Payment History'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadPayments,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Summary Cards
                    Row(
                      children: [
                        Expanded(
                          child: _buildSummaryCard(
                            'Total Paid',
                            '\$${totalPaid.toStringAsFixed(2)}',
                            Icons.check_circle,
                            AppColors.success,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildSummaryCard(
                            'Pending',
                            '\$${totalUnpaid.toStringAsFixed(2)}',
                            Icons.pending,
                            AppColors.warning,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: _buildSummaryCard(
                            'Refunded',
                            '\$${totalRefunded.toStringAsFixed(2)}',
                            Icons.replay,
                            AppColors.info,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildSummaryCard(
                            'Total',
                            '${summary['totalPayments'] ?? 0}',
                            Icons.receipt_long,
                            AppColors.primary,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    // Payments List
                    const Text(
                      'Transaction History',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                      ),
                    ),
                    const SizedBox(height: 16),
                    if (payments.isEmpty)
                      Center(
                        child: Padding(
                          padding: const EdgeInsets.all(32),
                          child: Column(
                            children: [
                              Icon(
                                Icons.payment,
                                size: 60,
                                color: Colors.grey[400],
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'No payments yet',
                                style: TextStyle(color: Colors.grey[600]),
                              ),
                            ],
                          ),
                        ),
                      )
                    else
                      ...payments.map((payment) => _buildPaymentCard(payment)),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildSummaryCard(
    String title,
    String value,
    IconData icon,
    Color color,
  ) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 12,
                  ),
                ),
                Icon(icon, color: color, size: 20),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              value,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPaymentCard(dynamic payment) {
    final item = payment is Map ? payment : <String, dynamic>{};
    final amount = _toMoney(item['amount']);
    final paymentStatus = (item['paymentStatus'] ?? 'unpaid').toString();
    final patientName = (item['patientName'] ?? 'Unknown').toString();
    final serviceType = (item['serviceType'] ?? '').toString();
    final scheduledAt = item['scheduledAt'];
    final createdAt = item['createdAt'];

    Color statusColor;
    String statusText;
    switch (paymentStatus) {
      case 'paid':
        statusColor = AppColors.success;
        statusText = 'PAID';
        break;
      case 'unpaid':
        statusColor = AppColors.warning;
        statusText = 'PENDING';
        break;
      case 'refunded':
        statusColor = AppColors.info;
        statusText = 'REFUNDED';
        break;
      case 'failed':
        statusColor = Colors.red;
        statusText = 'FAILED';
        break;
      default:
        statusColor = Colors.grey;
        statusText = paymentStatus.toUpperCase();
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        patientName,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      if (serviceType.isNotEmpty)
                        Text(
                          serviceType,
                          style: const TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 12,
                          ),
                        ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    statusText,
                    style: TextStyle(
                      color: statusColor,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const Divider(height: 24),
            // Details
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Amount',
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                    Text(
                      '\$${amount.toStringAsFixed(2)}',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    const Text(
                      'Date',
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                    Text(
                      scheduledAt != null
                          ? _formatDate(scheduledAt.toString())
                          : (createdAt != null
                                ? _formatDate(createdAt.toString())
                                : 'N/A'),
                      style: const TextStyle(fontSize: 14),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  double _toMoney(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '') ?? 0.0;
  }

  String _formatDate(String dateStr) {
    try {
      final date = DateTime.parse(dateStr);
      return '${date.day}/${date.month}/${date.year}';
    } catch (e) {
      return dateStr;
    }
  }
}
