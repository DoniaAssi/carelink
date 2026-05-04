import 'package:flutter/material.dart';

import 'package:carelink/core/app_colors.dart';
import 'package:carelink/core/app_nav.dart';
import 'package:carelink/core/carelink_palette.dart';
import 'package:carelink/shared/widgets/carelink_brand_logo.dart';
import 'package:carelink/shared/widgets/carelink_theme_toggle.dart';
import 'package:carelink/shared/widgets/secure_payment_notice.dart';
import 'package:carelink/shared/services/payment_service.dart';
import 'payment_success_screen.dart';

/// Checkout step after a booking is created. [appointmentId] is the backend UUID.
class PaymentScreen extends StatefulWidget {
  const PaymentScreen({
    super.key,
    required this.appointmentId,
    required this.patientId,
    required this.providerId,
    required this.providerName,
    required this.providerRole,
    required this.appointmentDate,
    required this.appointmentTime,
    required this.amount,
    this.serviceType,
    this.location,
  });

  final String appointmentId;
  final String patientId;
  final String providerId;
  final String providerName;
  final String providerRole;
  final String appointmentDate;
  final String appointmentTime;
  final double amount;
  final String? serviceType;
  final String? location;

  @override
  State<PaymentScreen> createState() => _PaymentScreenState();
}

class _PaymentScreenState extends State<PaymentScreen> {
  final PaymentService _paymentService = PaymentService();
  String? _method;
  bool _submitting = false;

  static const _methods = [
    _PayOption('cash', 'Cash', 'Pay in person when you visit', Icons.payments_outlined),
    _PayOption('card', 'Card', 'Simulated — no real charge', Icons.credit_card_rounded),
    _PayOption('wallet', 'Wallet', 'Simulated — no real charge', Icons.account_balance_wallet_outlined),
  ];

  Future<void> _pay() async {
    final method = _method;
    if (method == null) {
      _toast('Please choose how you want to pay.');
      return;
    }

    setState(() => _submitting = true);
    try {
      final result = await _paymentService.createPayment(
        appointmentId: widget.appointmentId,
        patientId: widget.patientId,
        providerId: widget.providerId,
        amount: widget.amount,
        method: method,
      );

      final ok = result['success'] == true;
      if (!ok) {
        throw Exception(result['error']?.toString() ?? 'Payment was not accepted');
      }

      final status = (result['status'] ?? '').toString();

      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => PaymentSuccessScreen(
            patientUserId: widget.patientId,
            providerName: widget.providerName,
            providerRole: widget.providerRole,
            serviceType: widget.serviceType,
            appointmentDate: widget.appointmentDate,
            appointmentTime: widget.appointmentTime,
            location: widget.location,
            paymentMethod: method,
            paymentStatus: status,
            amount: widget.amount,
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      final msg = e.toString().replaceFirst('Exception: ', '');
      _toast(msg.isEmpty ? 'Something went wrong.' : msg);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  void _toast(String message) {
    final messenger = appScaffoldMessengerKey.currentState;
    if (messenger != null) {
      messenger.showSnackBar(
        SnackBar(
          content: Text(message),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = CarelinkPalette.of(context);

    return Scaffold(
      backgroundColor: p.pageBg,
      appBar: AppBar(
        title: const CarelinkAppBarTitle('Payment'),
        actions: carelinkAppBarActions(),
      ),
      body: Stack(
        children: [
          ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 120),
            children: [
              const CarelinkBrandLogo(height: 36),
              const SizedBox(height: 16),
              Text(
                'Complete payment',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: p.inkDark,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Choose a method. Card and wallet are simulated until a gateway is connected.',
                style: TextStyle(color: p.inkMuted, fontSize: 13.5, height: 1.35),
              ),
              const SizedBox(height: 20),
              _SummaryCard(
                palette: p,
                providerName: widget.providerName,
                providerRole: widget.providerRole,
                date: widget.appointmentDate,
                time: widget.appointmentTime,
                amount: widget.amount,
                serviceType: widget.serviceType,
              ),
              const SizedBox(height: 20),
              Text(
                'Payment method',
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 15,
                  color: p.inkDark,
                ),
              ),
              const SizedBox(height: 10),
              ..._methods.map(
                (o) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _MethodTile(
                    palette: p,
                    option: o,
                    selected: _method == o.id,
                    onTap: _submitting ? null : () => setState(() => _method = o.id),
                  ),
                ),
              ),
              const SecurePaymentNotice(),
            ],
          ),
          if (_submitting)
            Container(
              color: Colors.black26,
              child: const Center(
                child: Card(
                  child: Padding(
                    padding: EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CircularProgressIndicator(color: AppColors.primary),
                        SizedBox(height: 14),
                        Text('Processing…'),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: FilledButton(
            onPressed: _submitting ? null : _pay,
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.primary,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            child: Text(
              'Pay \$${widget.amount.toStringAsFixed(2)}',
              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
            ),
          ),
        ),
      ),
    );
  }
}

class _PayOption {
  const _PayOption(this.id, this.title, this.subtitle, this.icon);
  final String id;
  final String title;
  final String subtitle;
  final IconData icon;
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({
    required this.palette,
    required this.providerName,
    required this.providerRole,
    required this.date,
    required this.time,
    required this.amount,
    this.serviceType,
  });

  final CarelinkPalette palette;
  final String providerName;
  final String providerRole;
  final String date;
  final String time;
  final double amount;
  final String? serviceType;

  @override
  Widget build(BuildContext context) {
    final p = palette;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: p.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: p.stroke),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: p.isDark ? 0.2 : 0.06),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                backgroundColor: AppColors.primary.withValues(alpha: 0.15),
                child: const Icon(Icons.person_rounded, color: AppColors.primary),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      providerName,
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 17,
                        color: p.inkDark,
                      ),
                    ),
                    Text(
                      providerRole,
                      style: TextStyle(color: p.inkMuted, fontSize: 13),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if ((serviceType ?? '').trim().isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              serviceType!.trim(),
              style: TextStyle(
                color: AppColors.primary,
                fontWeight: FontWeight.w700,
                fontSize: 13,
              ),
            ),
          ],
          const Divider(height: 22),
          _row('Date', date, p),
          _row('Time', time, p),
          const SizedBox(height: 6),
          Row(
            children: [
              Text(
                'Total',
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  color: p.inkDark,
                  fontSize: 15,
                ),
              ),
              const Spacer(),
              Text(
                '\$${amount.toStringAsFixed(2)}',
                style: const TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 18,
                  color: AppColors.primary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  static Widget _row(String label, String value, CarelinkPalette p) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          SizedBox(
            width: 56,
            child: Text(
              label,
              style: TextStyle(color: p.inkMuted, fontWeight: FontWeight.w600, fontSize: 13),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(color: p.inkDark, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}

class _MethodTile extends StatelessWidget {
  const _MethodTile({
    required this.palette,
    required this.option,
    required this.selected,
    required this.onTap,
  });

  final CarelinkPalette palette;
  final _PayOption option;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final p = palette;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Ink(
          decoration: BoxDecoration(
            color: p.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: selected ? AppColors.primary : p.stroke,
              width: selected ? 2 : 1,
            ),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          child: Row(
            children: [
              Icon(
                option.icon,
                color: selected ? AppColors.primary : p.inkMuted,
                size: 26,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      option.title,
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        color: p.inkDark,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      option.subtitle,
                      style: TextStyle(color: p.inkMuted, fontSize: 12.5),
                    ),
                  ],
                ),
              ),
              Icon(
                selected ? Icons.radio_button_checked : Icons.radio_button_off,
                color: selected ? AppColors.primary : p.inkMuted,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
