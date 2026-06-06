import re

with open(r'd:\carelink-main\lib\features\patient\screens\schedule_screen.dart', 'r', encoding='utf-8') as f:
    content = f.read()

# Add imports
imports = """import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'package:carelink/core/app_colors.dart';
import 'package:carelink/core/app_localizations.dart';
import 'package:carelink/core/carelink_palette.dart';
import 'package:carelink/shared/services/api_service.dart';
import 'package:carelink/shared/widgets/carelink_brand_logo.dart';
import 'package:carelink/shared/widgets/carelink_theme_toggle.dart';
import 'package:carelink/shared/models/booking_request_model.dart';
import 'package:carelink/features/patient/screens/select_service_screen.dart';
import 'booking_details_screen.dart';"""

content = re.sub(r'import.*?booking_details_screen\.dart\';', imports, content, flags=re.DOTALL)

# Fix enum
content = content.replace('enum _ScheduleFilter { pending, upcoming, completed, cancelled }', 'enum _ScheduleFilter { upcoming, pending, completed, cancelled }')
content = content.replace('_ScheduleFilter currentFilter = _ScheduleFilter.pending;', '_ScheduleFilter currentFilter = _ScheduleFilter.upcoming;')

# Update _buildFilterTabs
filter_tabs = """  Widget _buildFilterTabs() {
    final isAr = context.l10n.isArabic;
    return Row(
      children: [
        Expanded(
          child: _filterChip(
            label: isAr ? 'القادمة' : 'Upcoming',
            filter: _ScheduleFilter.upcoming,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _filterChip(
            label: isAr ? 'بانتظار الرد' : 'Waiting',
            filter: _ScheduleFilter.pending,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _filterChip(
            label: isAr ? 'المكتملة' : 'Completed',
            filter: _ScheduleFilter.completed,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _filterChip(
            label: isAr ? 'الملغاة' : 'Cancelled',
            filter: _ScheduleFilter.cancelled,
          ),
        ),
      ],
    );
  }"""

content = re.sub(r'  Widget _buildFilterTabs\(\) \{.*?(?=  Widget _filterChip)', filter_tabs + '\n\n', content, flags=re.DOTALL)

# We will write the new _buildBody and card rendering logic.
new_body = """  Widget _buildBody() {
    if (isLoading) {
      return const Padding(
        padding: EdgeInsets.only(top: 40),
        child: Center(child: CircularProgressIndicator()),
      );
    }

    if (errorMessage != null) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          children: [
            const Icon(Icons.error_outline_rounded, color: Colors.red, size: 34),
            const SizedBox(height: 12),
            Text(errorMessage!, textAlign: TextAlign.center, style: const TextStyle(color: AppColors.textDark, fontSize: 14)),
            const SizedBox(height: 14),
            ElevatedButton(
              onPressed: fetchAppointments,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              child: const Text('Try Again'),
            ),
          ],
        ),
      );
    }

    if (filteredAppointments.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(28),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(color: AppColors.primary.withValues(alpha: 0.10), borderRadius: BorderRadius.circular(22)),
              child: const Icon(Icons.event_busy_rounded, color: AppColors.primaryDark, size: 34),
            ),
            const SizedBox(height: 16),
            Text(
              context.l10n.isArabic ? 'لا توجد مواعيد' : 'No appointments found',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.textDark),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return Column(
      children: filteredAppointments.map((item) => _buildBookingCard(item)).toList(),
    );
  }

  Widget _buildBookingCard(Map<String, dynamic> item) {
    final scheduledAt = _parseScheduledAt(item['scheduledAt']);
    final rawStatusDisp = (_rawStatusFromItem(item) ?? '—').toString().trim();
    final status = _normalizedStatus(rawStatusDisp);
    final appointmentId = (item['appointmentId'] ?? item['requestId'] ?? '').toString().trim();
    final providerLabel = (item['providerName'] ?? item['doctorName'] ?? '').toString().trim();
    final providerId = (item['doctorUserId'] ?? item['providerUserId'] ?? '').toString().trim();
    final serviceRaw = (item['serviceType'] ?? '').toString().trim();
    final paymentRaw = (item['paymentStatus'] ?? '').toString().trim();
    final appointmentType = (item['appointmentType'] ?? '').toString().trim();
    final address = (item['visitAddress'] ?? item['location'] ?? '').toString().trim();
    
    var amountText = '—';
    if (item['amount'] != null) {
      amountText = '${double.tryParse(item['amount'].toString())?.toStringAsFixed(2) ?? item['amount']} ILS';
    } else if (item['price'] != null) {
      amountText = '${double.tryParse(item['price'].toString())?.toStringAsFixed(2) ?? item['price']} ILS';
    }

    final isAr = context.l10n.isArabic;

    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        child: InkWell(
          borderRadius: BorderRadius.circular(24),
          onTap: appointmentId.isEmpty ? null : () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => BookingDetailsScreen(appointmentId: appointmentId, patientUserId: widget.patientUserId)),
            );
          },
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: AppColors.border),
              boxShadow: [
                BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 16, offset: const Offset(0, 8)),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    CircleAvatar(
                      radius: 26,
                      backgroundColor: AppColors.primary.withValues(alpha: 0.12),
                      child: const Icon(Icons.person, color: AppColors.primaryDark, size: 28),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            providerLabel.isNotEmpty ? providerLabel : 'Provider',
                            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: AppColors.textDark),
                          ),
                          Text(
                            '${_providerRoleLabel(item)} · ${item['specialization'] ?? 'Specialty'}',
                            style: const TextStyle(color: AppColors.textLight, fontSize: 13),
                          ),
                          if (appointmentId.length >= 4)
                            Text(
                              'Ref: ...${appointmentId.substring(appointmentId.length - 4)}',
                              style: const TextStyle(color: AppColors.textLight, fontSize: 11),
                            ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: _statusColor(status).withValues(alpha: 0.10),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        _statusLabel(status),
                        style: TextStyle(color: _statusColor(status), fontWeight: FontWeight.w700, fontSize: 11),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                _cardRow(Icons.medical_services_outlined, isAr ? 'الخدمة' : 'Service', serviceRaw.isEmpty ? '—' : serviceRaw),
                if (appointmentType.isNotEmpty)
                  _cardRow(Icons.videocam_outlined, isAr ? 'النوع' : 'Type', appointmentType),
                _cardRow(Icons.calendar_today_outlined, isAr ? 'التاريخ والوقت' : 'Date & Time', '${_formatDate(scheduledAt)} · ${_formatTime(scheduledAt)}'),
                if (address.isNotEmpty)
                  _cardRow(Icons.location_on_outlined, isAr ? 'العنوان' : 'Address', address),
                _cardRow(Icons.payments_outlined, isAr ? 'المبلغ' : 'Total Paid', amountText),
                _cardRow(Icons.flag_outlined, isAr ? 'حالة الدفع' : 'Payment', paymentRaw.isEmpty ? '—' : paymentRaw),
                
                const SizedBox(height: 14),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    if (status == 'pending' || status == 'upcoming') ...[
                      TextButton(
                        onPressed: () => _cancelBooking(appointmentId),
                        style: TextButton.styleFrom(foregroundColor: Colors.red),
                        child: Text(isAr ? 'إلغاء الحجز' : 'Cancel'),
                      ),
                      const SizedBox(width: 8),
                    ],
                    if (status == 'pending') ...[
                      FilledButton(
                        onPressed: () => _editBooking(item),
                        style: FilledButton.styleFrom(backgroundColor: AppColors.primary),
                        child: Text(isAr ? 'تعديل' : 'Edit'),
                      ),
                    ],
                    if (status == 'cancelled' || status == 'completed') ...[
                      FilledButton(
                        onPressed: () => _bookAgain(item),
                        style: FilledButton.styleFrom(backgroundColor: AppColors.primary),
                        child: Text(isAr ? 'حجز مجدداً' : 'Book Again'),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _cardRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: AppColors.textLight),
          const SizedBox(width: 8),
          SizedBox(
            width: 80,
            child: Text(label, style: const TextStyle(fontSize: 12, color: AppColors.textLight, fontWeight: FontWeight.w600)),
          ),
          Expanded(
            child: Text(value, style: const TextStyle(fontSize: 12, color: AppColors.textDark, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  Future<void> _cancelBooking(String appointmentId) async {
    final isAr = context.l10n.isArabic;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(isAr ? 'تأكيد الإلغاء' : 'Cancel Booking'),
        content: Text(isAr ? 'هل أنت متأكد من إلغاء هذا الحجز؟' : 'Are you sure you want to cancel this booking?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(isAr ? 'تراجع' : 'No')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: Text(isAr ? 'نعم، إلغاء' : 'Yes, Cancel', style: const TextStyle(color: Colors.red))),
        ],
      ),
    );

    if (confirm != true) return;
    
    setState(() => isLoading = true);
    try {
      await _api.updateBookingStatus(appointmentId, 'cancelled');
      await fetchAppointments();
    } catch (e) {
      if (mounted) {
        setState(() => isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
      }
    }
  }

  Future<void> _editBooking(Map<String, dynamic> item) async {
    final isAr = context.l10n.isArabic;
    final appointmentId = item['appointmentId'] ?? item['requestId'];
    
    final current = _parseScheduledAt(item['scheduledAt']) ?? DateTime.now();
    final date = await showDatePicker(
      context: context,
      initialDate: current,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 90)),
    );
    if (date == null || !mounted) return;
    
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(current),
    );
    if (time == null || !mounted) return;
    
    final dt = DateTime(date.year, date.month, date.day, time.hour, time.minute);
    
    setState(() => isLoading = true);
    try {
      await _api.putJson('/api/patient/bookings/$appointmentId', {
        'scheduledAt': dt.toIso8601String(),
        'date': '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}',
        'time': '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}',
      });
      await fetchAppointments();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(isAr ? 'تم التعديل' : 'Updated successfully')));
      }
    } catch (e) {
      if (mounted) {
        setState(() => isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
      }
    }
  }

  void _bookAgain(Map<String, dynamic> item) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => SelectServiceScreen(
          request: BookingRequestModel(
            patientId: widget.patientUserId,
            providerId: (item['doctorUserId'] ?? item['providerUserId'] ?? '').toString(),
            providerName: (item['providerName'] ?? item['doctorName'] ?? '').toString(),
            providerRole: (item['providerRole'] ?? 'Doctor').toString(),
            specialization: (item['specialization'] ?? '').toString(),
            serviceType: (item['serviceType'] ?? '').toString(),
            appointmentDate: '',
            appointmentTime: '',
            visitLatitude: 0,
            visitLongitude: 0,
            visitAddress: '',
            locationNote: '',
            patientReason: '',
            symptoms: '',
            isUrgent: false,
            additionalNotes: '',
            price: double.tryParse((item['price'] ?? item['amount'] ?? '0').toString()) ?? 0,
            paymentMethod: '',
            paymentStatus: '',
            bookingStatus: 'pending',
          ),
        ),
      ),
    );
  }
"""

content = re.sub(r'  Widget _buildBody\(\) \{.*?(?=  String _filterToStatus)', new_body + '\n\n', content, flags=re.DOTALL)

with open(r'd:\carelink-main\lib\features\patient\screens\schedule_screen.dart', 'w', encoding='utf-8') as f:
    f.write(content)
