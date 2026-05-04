import 'package:flutter/material.dart';

import 'package:carelink/core/app_colors.dart';
import 'package:carelink/core/carelink_palette.dart';
import 'package:carelink/shared/models/provider_model.dart';
import 'package:carelink/shared/widgets/carelink_brand_logo.dart';
import 'package:carelink/shared/widgets/carelink_theme_toggle.dart';
import 'package:carelink/shared/widgets/secure_payment_notice.dart';
import 'package:carelink/shared/services/api_service.dart';
import 'package:carelink/features/patient/payment/payment_screen.dart';

class PaymentConfirmationScreen extends StatefulWidget {
  final String patientUserId;
  final ProviderModel provider;
  final String date;
  final String time;
  final String notes;
  final double amount;
  final double consultationFee;
  final double adminFee;
  final double discount;
  final String? visitAddress;
  final String? locationNote;
  final String? serviceType;
  final bool isUrgent;
  final double? visitLatitude;
  final double? visitLongitude;

  const PaymentConfirmationScreen({
    super.key,
    required this.patientUserId,
    required this.provider,
    required this.date,
    required this.time,
    required this.notes,
    required this.amount,
    required this.consultationFee,
    required this.adminFee,
    required this.discount,
    this.visitAddress,
    this.locationNote,
    this.serviceType,
    this.isUrgent = false,
    this.visitLatitude,
    this.visitLongitude,
  });

  @override
  State<PaymentConfirmationScreen> createState() =>
      _PaymentConfirmationScreenState();
}

class _PaymentConfirmationScreenState extends State<PaymentConfirmationScreen> {
  bool isLoading = false;

  String get _displayReason => widget.notes.trim().isEmpty
      ? 'General consultation'
      : widget.notes.trim();

  Future<void> _confirm() async {
    setState(() => isLoading = true);
    try {
      final booking = await ApiService().createBooking(
        patientId: widget.patientUserId,
        providerId: widget.provider.userId,
        date: widget.date,
        time: widget.time,
        notes: _displayReason,
        serviceType: widget.serviceType,
        visitAddress: widget.visitAddress,
        visitLatitude: widget.visitLatitude,
        visitLongitude: widget.visitLongitude,
        locationNote: widget.locationNote,
        symptoms: widget.notes.trim(),
        isUrgent: widget.isUrgent,
        urgencyLevel: widget.isUrgent ? 'urgent' : 'routine',
        additionalNotes: widget.locationNote,
        paymentMethod: '',
        paymentStatus: 'unpaid',
      );

      final appointmentId = (booking['appointmentId'] ?? '').toString();
      if (appointmentId.isEmpty) {
        throw Exception('Booking created but appointment id is missing');
      }

      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => PaymentScreen(
            appointmentId: appointmentId,
            patientId: widget.patientUserId,
            providerId: widget.provider.userId,
            providerName: widget.provider.fullName,
            providerRole: widget.provider.role,
            appointmentDate: widget.date,
            appointmentTime: widget.time,
            amount: widget.amount,
            serviceType: widget.serviceType,
            location: widget.visitAddress,
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
      );
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = CarelinkPalette.of(context);
    final specialization = widget.provider.specialization.trim().isEmpty
        ? (widget.provider.role.toLowerCase() == 'doctor'
              ? 'General Medical Care'
              : 'Home Nursing Care')
        : widget.provider.specialization;

    return Scaffold(
      backgroundColor: p.pageBg,
      appBar: AppBar(
        centerTitle: true,
        title: const CarelinkAppBarTitle('Appointment'),
        actions: carelinkAppBarActions(),
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 14),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  'Total\n\$ ${widget.amount.toStringAsFixed(2)}',
                  style: const TextStyle(
                    color: AppColors.textDark,
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                    height: 1.2,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: SizedBox(
                  height: 46,
                  child: ElevatedButton(
                    onPressed: isLoading ? null : _confirm,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(24),
                      ),
                    ),
                    child: isLoading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.4,
                              color: Colors.white,
                            ),
                          )
                        : const Text(
                            'Book & pay',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                              fontSize: 15,
                            ),
                          ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFE0E7EA)),
              ),
              child: Row(
                children: [
                  Container(
                    width: 78,
                    height: 78,
                    decoration: BoxDecoration(
                      color: const Color(0xFFEAF3F0),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      widget.provider.role.toLowerCase() == 'doctor'
                          ? Icons.medical_services_rounded
                          : Icons.local_hospital_rounded,
                      color: AppColors.primary,
                      size: 35,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.provider.fullName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 20,
                            color: AppColors.textDark,
                          ),
                        ),
                        Text(
                          specialization,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Color(0xFF7B8C95),
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(height: 7),
                        Row(
                          children: [
                            const Icon(
                              Icons.star_rounded,
                              size: 14,
                              color: AppColors.primary,
                            ),
                            const SizedBox(width: 3),
                            Text(
                              widget.provider.overallRating.toStringAsFixed(1),
                              style: const TextStyle(
                                fontSize: 12,
                                color: Color(0xFF4D6774),
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            _sectionHeader('Date', action: 'Change'),
            const SizedBox(height: 6),
            _lineRow(
              icon: Icons.calendar_month_outlined,
              text: '${widget.date} | ${widget.time}',
            ),
            const SizedBox(height: 14),
            _sectionHeader('Reason', action: 'Change'),
            const SizedBox(height: 6),
            _lineRow(icon: Icons.edit_note_rounded, text: _displayReason),
            if ((widget.visitAddress ?? '').trim().isNotEmpty) ...[
              const SizedBox(height: 14),
              _sectionHeader('Visit Location'),
              const SizedBox(height: 6),
              _lineRow(
                icon: Icons.location_on_outlined,
                text: widget.visitAddress!.trim(),
              ),
              if ((widget.locationNote ?? '').trim().isNotEmpty) ...[
                const SizedBox(height: 6),
                _lineRow(
                  icon: Icons.pin_drop_outlined,
                  text: widget.locationNote!.trim(),
                ),
              ],
            ],
            if ((widget.serviceType ?? '').trim().isNotEmpty ||
                widget.isUrgent) ...[
              const SizedBox(height: 14),
              _sectionHeader('Request Info'),
              const SizedBox(height: 6),
              if ((widget.serviceType ?? '').trim().isNotEmpty)
                _lineRow(
                  icon: Icons.medical_services_outlined,
                  text: widget.serviceType!.trim(),
                ),
              if (widget.isUrgent)
                _lineRow(
                  icon: Icons.priority_high_rounded,
                  text: 'Urgent case',
                ),
            ],
            const SizedBox(height: 14),
            const Text(
              'Payment Detail',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: AppColors.textDark,
              ),
            ),
            const SizedBox(height: 8),
            _paymentLine(
              'Consultation',
              '\$${widget.consultationFee.toStringAsFixed(2)}',
            ),
            _paymentLine(
              'Admin Fee',
              '\$${widget.adminFee.toStringAsFixed(2)}',
            ),
            _paymentLine(
              'Additional Discount',
              widget.discount == 0
                  ? '-'
                  : '\$${widget.discount.toStringAsFixed(2)}',
            ),
            const Divider(height: 20, color: Color(0xFFE1E8EB)),
            _paymentLine(
              'Total',
              '\$${widget.amount.toStringAsFixed(2)}',
              valueColor: AppColors.primary,
              bold: true,
            ),
            const SizedBox(height: 14),
            const Text(
              'Next, choose how you pay (cash, card, or wallet).',
              style: TextStyle(
                color: Color(0xFF74858E),
                fontSize: 13.5,
                height: 1.35,
              ),
            ),
            const SizedBox(height: 14),
            const SecurePaymentNotice(),
          ],
        ),
      ),
    );
  }

  Widget _sectionHeader(String title, {String? action}) {
    return Row(
      children: [
        Text(
          title,
          style: const TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 16,
            color: AppColors.textDark,
          ),
        ),
        const Spacer(),
        if (action != null)
          Text(
            action,
            style: const TextStyle(
              color: Color(0xFF8FA0A8),
              fontWeight: FontWeight.w600,
              fontSize: 12,
            ),
          ),
      ],
    );
  }

  Widget _lineRow({required IconData icon, required String text}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(11),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE0E7EA)),
      ),
      child: Row(
        children: [
          Icon(icon, color: AppColors.primary, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                color: Color(0xFF435A66),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _paymentLine(
    String label,
    String value, {
    Color valueColor = AppColors.textDark,
    bool bold = false,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Text(
            label,
            style: TextStyle(
              color: const Color(0xFF74858E),
              fontWeight: bold ? FontWeight.w700 : FontWeight.w500,
            ),
          ),
          const Spacer(),
          Text(
            value,
            style: TextStyle(color: valueColor, fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}