import 'package:flutter/material.dart';

import 'package:carelink/core/app_colors.dart';
import 'package:carelink/core/app_localizations.dart';
import 'package:carelink/core/carelink_palette.dart';
import 'package:carelink/features/patient/widgets/patient_shared_widgets.dart';
import 'package:carelink/shared/models/booking_request_model.dart';
import 'package:carelink/shared/models/provider_model.dart';
import 'package:carelink/shared/services/api_service.dart';

import 'select_service_screen.dart';

class BookingStartScreen extends StatefulWidget {
  const BookingStartScreen({super.key, required this.patientUserId});

  final String patientUserId;

  @override
  State<BookingStartScreen> createState() => _BookingStartScreenState();
}

class _BookingStartScreenState extends State<BookingStartScreen> {
  bool _loading = true;
  String? _error;
  List<ProviderModel> _providers = const [];

  bool get _isArabic => context.l10n.isArabic;

  @override
  void initState() {
    super.initState();
    _loadProviders();
  }

  Future<void> _loadProviders() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final rows = await ApiService().getProviders();
      final providers =
          rows
              .whereType<Map>()
              .map(
                (row) => ProviderModel.fromJson(Map<String, dynamic>.from(row)),
              )
              .where((provider) => provider.availableSlots.isNotEmpty)
              .toList()
            ..sort((a, b) => b.overallRating.compareTo(a.overallRating));
      if (!mounted) return;
      setState(() {
        _providers = providers;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = _isArabic
            ? 'تعذر تحميل مقدمي الرعاية.'
            : 'Could not load care providers.';
        _loading = false;
      });
    }
  }

  void _selectProvider(ProviderModel provider) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => SelectServiceScreen(
          request: BookingRequestModel(
            patientId: widget.patientUserId,
            providerId: provider.userId,
            providerName: provider.fullName,
            providerRole: provider.role,
            providerImageUrl: provider.profileImageUrl ?? '',
            specialization: provider.specialization,
            serviceType: provider.serviceType,
            appointmentDate: '',
            appointmentTime: '',
            visitLatitude: provider.gpsLat ?? 0,
            visitLongitude: provider.gpsLng ?? 0,
            visitAddress: '',
            locationNote: '',
            patientReason: '',
            symptoms: '',
            isUrgent: false,
            additionalNotes: '',
            price: provider.consultationFee ?? 0,
            paymentMethod: '',
            paymentStatus: 'unpaid',
            bookingStatus: 'pending',
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = CarelinkPalette.of(context);
    return Scaffold(
      backgroundColor: p.pageBg,
      appBar: PatientAppBar(title: _isArabic ? 'ابدأ الحجز' : 'Start Booking'),
      body: RefreshIndicator(
        color: AppColors.primary,
        onRefresh: _loadProviders,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 28),
          children: [
            Text(
              _isArabic
                  ? 'اختر مقدم الرعاية للمتابعة'
                  : 'Choose a care provider to continue',
              style: TextStyle(
                color: p.inkDark,
                fontSize: 20,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 5),
            Text(
              _isArabic
                  ? 'نعرض فقط مقدمي الرعاية الذين لديهم مواعيد متاحة.'
                  : 'Only providers with available appointment slots are shown.',
              style: TextStyle(color: p.inkMuted, height: 1.4),
            ),
            const SizedBox(height: 18),
            if (_loading)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(36),
                  child: CircularProgressIndicator(color: AppColors.primary),
                ),
              )
            else if (_error != null)
              _MessageCard(
                palette: p,
                icon: Icons.error_outline_rounded,
                message: _error!,
                actionLabel: _isArabic ? 'إعادة المحاولة' : 'Try Again',
                onAction: _loadProviders,
              )
            else if (_providers.isEmpty)
              _MessageCard(
                palette: p,
                icon: Icons.event_busy_outlined,
                message: _isArabic
                    ? 'لا توجد مواعيد متاحة حالياً.'
                    : 'No appointment slots are currently available.',
              )
            else
              for (final provider in _providers) ...[
                _ProviderChoiceCard(
                  provider: provider,
                  palette: p,
                  isArabic: _isArabic,
                  onTap: () => _selectProvider(provider),
                ),
                const SizedBox(height: 10),
              ],
          ],
        ),
      ),
    );
  }
}

class _ProviderChoiceCard extends StatelessWidget {
  const _ProviderChoiceCard({
    required this.provider,
    required this.palette,
    required this.isArabic,
    required this.onTap,
  });

  final ProviderModel provider;
  final CarelinkPalette palette;
  final bool isArabic;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final image = provider.profileImageUrl?.trim() ?? '';
    final detail = provider.specialization.trim().isNotEmpty
        ? provider.specialization
        : provider.serviceType;
    return Material(
      color: palette.surface,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: palette.stroke),
          ),
          child: Row(
            children: [
              CircleAvatar(
                radius: 27,
                backgroundColor: AppColors.primary.withValues(alpha: 0.12),
                backgroundImage: image.isEmpty ? null : NetworkImage(image),
                child: image.isEmpty
                    ? const Icon(
                        Icons.medical_services_outlined,
                        color: AppColors.primary,
                      )
                    : null,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      provider.fullName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: palette.inkDark,
                        fontWeight: FontWeight.w800,
                        fontSize: 15,
                      ),
                    ),
                    if (detail.isNotEmpty) ...[
                      const SizedBox(height: 3),
                      Text(
                        detail,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: palette.inkMuted, fontSize: 12),
                      ),
                    ],
                    const SizedBox(height: 5),
                    Text(
                      isArabic
                          ? '${provider.availableSlots.length} مواعيد متاحة'
                          : '${provider.availableSlots.length} available slots',
                      style: const TextStyle(
                        color: AppColors.primary,
                        fontWeight: FontWeight.w700,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.arrow_forward_ios_rounded,
                color: AppColors.primary,
                size: 17,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MessageCard extends StatelessWidget {
  const _MessageCard({
    required this.palette,
    required this.icon,
    required this.message,
    this.actionLabel,
    this.onAction,
  });

  final CarelinkPalette palette;
  final IconData icon;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: palette.stroke),
      ),
      child: Column(
        children: [
          Icon(icon, color: AppColors.primary, size: 34),
          const SizedBox(height: 10),
          Text(
            message,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: palette.inkDark,
              fontWeight: FontWeight.w600,
            ),
          ),
          if (onAction != null && actionLabel != null) ...[
            const SizedBox(height: 12),
            TextButton(onPressed: onAction, child: Text(actionLabel!)),
          ],
        ],
      ),
    );
  }
}
