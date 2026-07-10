// ignore_for_file: unused_element, deprecated_member_use, use_build_context_synchronously

import 'package:flutter/material.dart';
import 'package:carelink/core/app_colors.dart';
import 'package:carelink/shared/models/user.dart';
import 'package:carelink/shared/services/payment_service.dart';
import 'nurse_ui.dart';

class NursePayments extends StatefulWidget {
  final User user;

  const NursePayments({super.key, required this.user});

  @override
  State<NursePayments> createState() => _NursePaymentsState();
}

class _NursePaymentsState extends State<NursePayments> {
  bool isLoading = false;

  List<Map<String, dynamic>> paymentHistory = [];
  List<Map<String, dynamic>> paymentMethods = [];
  double thisMonthEarnings = 0;
  double thisWeekEarnings = 0;
  double todayEarnings = 0;

  @override
  void initState() {
    super.initState();
    _loadPayments();
  }

  Future<void> _loadPayments() async {
    setState(() => isLoading = true);
    final methods = await PaymentService.getPaymentMethods(widget.user.userId);
    final history = await PaymentService.getPaymentHistory(widget.user.userId);
    final summary = await PaymentService.getPaymentSummary(widget.user.userId);
    if (!mounted) return;
    setState(() {
      paymentMethods = methods.map((method) => method.toJson()).toList();
      paymentHistory = history
          .map(
            (item) => {
              'id': item.id,
              'date': item.date,
              'service': item.service,
              'patient': item.patientName,
              'amount': item.amount,
              'status': item.status,
              'paymentMethod': item.paymentMethod,
            },
          )
          .toList();
      thisMonthEarnings = summary['thisMonth'] ?? 0;
      thisWeekEarnings = summary['thisWeek'] ?? 0;
      todayEarnings = summary['today'] ?? 0;
      isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return NurseUi.reactive(
      (context) => Scaffold(
        backgroundColor: NurseUi.background,
        appBar: AppBar(
          title: Text(NurseUi.t('Earnings & Payments')),
          backgroundColor: NurseUi.background,
          foregroundColor: NurseUi.text,
          elevation: 0,
          actions: [NurseModeControls(providerUserId: widget.user.userId)],
        ),
        body: isLoading
            ? const Center(child: CircularProgressIndicator())
            : SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 110),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(18),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.045),
                            blurRadius: 18,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Total Earnings',
                                  style: TextStyle(
                                    color: Color(0xFF78909C),
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                const SizedBox(height: 10),
                                Text(
                                  '${thisMonthEarnings.toStringAsFixed(0)} ILS',
                                  style: const TextStyle(
                                    color: AppColors.primaryDark,
                                    fontSize: 26,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                const Text(
                                  'This Month',
                                  style: TextStyle(
                                    color: Color(0xFF78909C),
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Container(
                            width: 64,
                            height: 64,
                            decoration: BoxDecoration(
                              color: const Color(0xFFDDF2EF),
                              borderRadius: BorderRadius.circular(18),
                            ),
                            child: const Icon(
                              Icons.account_balance_wallet_outlined,
                              color: AppColors.primaryDark,
                              size: 32,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),

                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: const [
                        Text(
                          'Recent Transactions',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        Text(
                          'View all',
                          style: TextStyle(
                            color: AppColors.primaryDark,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    if (paymentHistory.isEmpty)
                      _emptyPayments()
                    else
                      ...paymentHistory.map(_buildPaymentHistoryCard),
                  ],
                ),
              ),
      ),
    );
  }

  Widget _emptyPayments() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: const Center(
        child: Text(
          'No transactions yet',
          style: TextStyle(
            color: Color(0xFF78909C),
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }

  Widget _buildEarningStat(String label, String amount) {
    return Column(
      children: [
        Text(
          amount,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: const TextStyle(color: Colors.white70, fontSize: 12),
        ),
      ],
    );
  }

  Widget _buildPaymentMethodCard(Map<String, dynamic> method) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: NurseUi.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: NurseUi.border.withOpacity(0.8)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Icon(
                method['type'] == 'Bank Transfer'
                    ? Icons.account_balance
                    : Icons.payment,
                color: AppColors.primaryDark,
                size: 24,
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    method['type'],
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    method['details'],
                    style: TextStyle(color: Colors.grey[600], fontSize: 12),
                  ),
                ],
              ),
            ],
          ),
          Row(
            children: [
              if (method['isDefault'])
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  margin: const EdgeInsets.only(right: 8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF28a745),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Text(
                    'Default',
                    style: TextStyle(color: Colors.white, fontSize: 10),
                  ),
                ),
              PopupMenuButton<String>(
                onSelected: (value) =>
                    _handlePaymentMethodAction(value, method),
                itemBuilder: (context) => [
                  const PopupMenuItem(
                    value: 'set_default',
                    child: Text('Set as Default'),
                  ),
                  const PopupMenuItem(value: 'edit', child: Text('Edit')),
                  const PopupMenuItem(value: 'delete', child: Text('Delete')),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentHistoryCard(Map<String, dynamic> payment) {
    final status = payment['status']?.toString().toLowerCase() ?? '';
    final statusColor = status == 'completed' || status == 'paid'
        ? const Color(0xFF28a745)
        : status == 'pending'
        ? const Color(0xFFffc107)
        : const Color(0xFFdc3545);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: NurseUi.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: NurseUi.border.withOpacity(0.8)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      payment['service'],
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Patient: ${payment['patient']}',
                      style: TextStyle(color: Colors.grey[600], fontSize: 12),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '\$${payment['amount'].toStringAsFixed(2)}',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppColors.primaryDark,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: statusColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      status.toUpperCase(),
                      style: TextStyle(
                        color: statusColor,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(
                    Icons.calendar_today,
                    size: 14,
                    color: Colors.grey,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    _formatDate(payment['date']),
                    style: TextStyle(color: Colors.grey[600], fontSize: 12),
                  ),
                ],
              ),
              Row(
                children: [
                  Icon(
                    payment['paymentMethod'] == 'Bank Transfer'
                        ? Icons.account_balance
                        : Icons.payment,
                    size: 14,
                    color: Colors.grey,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    payment['paymentMethod'],
                    style: TextStyle(color: Colors.grey[600], fontSize: 12),
                  ),
                ],
              ),
            ],
          ),
          if (status == 'pending') ...[
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              height: 35,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF28a745),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                onPressed: () => _requestPayment(payment),
                child: const Text(
                  'Request Payment',
                  style: TextStyle(color: Colors.white, fontSize: 12),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  void _handlePaymentMethodAction(String action, Map<String, dynamic> method) {
    switch (action) {
      case 'set_default':
        setState(() {
          for (var m in paymentMethods) {
            m['isDefault'] = false;
          }
          method['isDefault'] = true;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${method['type']} set as default payment method'),
          ),
        );
        break;
      case 'edit':
        _editPaymentMethod(method);
        break;
      case 'delete':
        _deletePaymentMethod(method);
        break;
    }
  }

  void _addPaymentMethod() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => AddPaymentMethodForm(
        providerUserId: widget.user.userId,
        onSaved: _loadPayments,
      ),
    );
  }

  void _editPaymentMethod(Map<String, dynamic> method) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => EditPaymentMethodForm(
        providerUserId: widget.user.userId,
        method: method,
        onSaved: _loadPayments,
      ),
    );
  }

  void _deletePaymentMethod(Map<String, dynamic> method) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(NurseUi.t('Delete Payment Method')),
        content: Text('Are you sure you want to delete ${method['type']}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              final success = await PaymentService.deletePaymentMethod(
                widget.user.userId,
                method['id'].toString(),
              );
              Navigator.pop(context);
              if (success) _loadPayments();
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    success
                        ? 'Payment method deleted'
                        : 'Failed to delete payment method',
                  ),
                ),
              );
            },
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  Future<void> _requestPayment(Map<String, dynamic> payment) async {
    final success = await PaymentService.requestPayment(
      widget.user.userId,
      payment['id'].toString(),
    );
    if (success) _loadPayments();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          success ? 'Payment marked as paid' : 'Failed to update payment',
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }

  String _formatCurrency(double amount) {
    return '\$${amount.toStringAsFixed(0)}';
  }
}

class AddPaymentMethodForm extends StatefulWidget {
  final String providerUserId;
  final Future<void> Function() onSaved;

  const AddPaymentMethodForm({
    super.key,
    required this.providerUserId,
    required this.onSaved,
  });

  @override
  State<AddPaymentMethodForm> createState() => _AddPaymentMethodFormState();
}

class _AddPaymentMethodFormState extends State<AddPaymentMethodForm> {
  final accountNumberController = TextEditingController();
  final routingNumberController = TextEditingController();
  final paypalEmailController = TextEditingController();

  String selectedType = 'Bank Transfer';

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Add Payment Method',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 20),

          // Payment Type Selection
          const Text(
            'Payment Type',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            initialValue: selectedType,
            decoration: InputDecoration(
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 12,
              ),
            ),
            items: ['Bank Transfer', 'PayPal'].map((type) {
              return DropdownMenuItem<String>(value: type, child: Text(type));
            }).toList(),
            onChanged: (value) {
              setState(() => selectedType = value!);
            },
          ),
          const SizedBox(height: 16),

          if (selectedType == 'Bank Transfer') ...[
            // Bank Account Details
            const Text(
              'Account Number',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: accountNumberController,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                hintText: 'Enter account number',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                contentPadding: const EdgeInsets.all(16),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Routing Number',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: routingNumberController,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                hintText: 'Enter routing number',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                contentPadding: const EdgeInsets.all(16),
              ),
            ),
          ] else ...[
            // PayPal Email
            const Text(
              'PayPal Email',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: paypalEmailController,
              keyboardType: TextInputType.emailAddress,
              decoration: InputDecoration(
                hintText: 'Enter PayPal email',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                contentPadding: const EdgeInsets.all(16),
              ),
            ),
          ],

          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onPressed: _addPaymentMethod,
              child: const Text(
                'Add Payment Method',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _addPaymentMethod() async {
    final details = selectedType == 'Bank Transfer'
        ? 'Account: ${accountNumberController.text.trim()}, Routing: ${routingNumberController.text.trim()}'
        : paypalEmailController.text.trim();
    final success = await PaymentService.addPaymentMethod(
      widget.providerUserId,
      selectedType,
      details,
      false,
    );
    if (success) await widget.onSaved();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          success
              ? 'Payment method added successfully'
              : 'Failed to add payment method',
        ),
      ),
    );
    if (success) Navigator.pop(context);
  }
}

class EditPaymentMethodForm extends StatefulWidget {
  final String providerUserId;
  final Map<String, dynamic> method;
  final Future<void> Function() onSaved;

  const EditPaymentMethodForm({
    super.key,
    required this.providerUserId,
    required this.method,
    required this.onSaved,
  });

  @override
  State<EditPaymentMethodForm> createState() => _EditPaymentMethodFormState();
}

class _EditPaymentMethodFormState extends State<EditPaymentMethodForm> {
  late TextEditingController controller;

  @override
  void initState() {
    super.initState();
    controller = TextEditingController(text: widget.method['details']);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Edit ${widget.method['type']}',
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 20),
          TextField(
            controller: controller,
            decoration: InputDecoration(
              labelText: widget.method['type'] == 'Bank Transfer'
                  ? 'Account Number'
                  : 'PayPal Email',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              contentPadding: const EdgeInsets.all(16),
            ),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onPressed: _updatePaymentMethod,
              child: const Text(
                'Update Payment Method',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _updatePaymentMethod() async {
    final success = await PaymentService.updatePaymentMethod(
      widget.providerUserId,
      widget.method['id'].toString(),
      widget.method['type'].toString(),
      controller.text.trim(),
      widget.method['isDefault'] == true,
    );
    if (success) await widget.onSaved();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          success
              ? 'Payment method updated successfully'
              : 'Failed to update payment method',
        ),
      ),
    );
    if (success) Navigator.pop(context);
  }
}

