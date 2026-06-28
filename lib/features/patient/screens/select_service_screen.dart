import 'package:flutter/material.dart';
import 'package:carelink/shared/widgets/carelink_background.dart';

import 'package:carelink/core/app_colors.dart';
import 'package:carelink/core/app_localizations.dart';
import 'package:carelink/core/carelink_palette.dart';
import 'package:carelink/features/ai/provider_booking_eligibility.dart';
import 'package:carelink/shared/models/booking_request_model.dart';
import 'package:carelink/shared/models/provider_model.dart';
import 'package:carelink/shared/services/api_service.dart';
import 'package:carelink/features/patient/widgets/booking_step_indicator.dart';
import 'package:carelink/features/patient/widgets/patient_shared_widgets.dart';
import 'booking_screen.dart';

class SelectServiceScreen extends StatefulWidget {
  const SelectServiceScreen({
    super.key,
    required this.request,
    this.returnWhenUnavailable = false,
  });

  final BookingRequestModel request;
  final bool returnWhenUnavailable;

  @override
  State<SelectServiceScreen> createState() => _SelectServiceScreenState();
}

class _SelectServiceScreenState extends State<SelectServiceScreen> {
  static const _services = <_ServiceOption>[
    _ServiceOption(
      'Home Nursing Care',
      'booking.service.homeNursing',
      'booking.service.homeNursing.desc',
      Icons.home_filled,
      80,
    ),
    _ServiceOption(
      'General Doctor',
      'booking.service.generalDoctor',
      'booking.service.generalDoctor.desc',
      Icons.medical_services_rounded,
      150,
    ),
    _ServiceOption(
      'Elderly Care',
      'booking.service.elderlyCare',
      'booking.service.elderlyCare.desc',
      Icons.elderly_rounded,
      100,
    ),
    _ServiceOption(
      'Post-Surgery Care',
      'booking.service.postSurgery',
      'booking.service.postSurgery.desc',
      Icons.healing_rounded,
      120,
    ),
    _ServiceOption(
      'Physiotherapy',
      'booking.service.physiotherapy',
      'booking.service.physiotherapy.desc',
      Icons.accessibility_new_rounded,
      130,
    ),
    _ServiceOption(
      'Mental Health Support',
      'booking.service.mentalSupport',
      'booking.service.mentalSupport.desc',
      Icons.psychology_rounded,
      120,
    ),
  ];

  ProviderModel? _provider;
  String? _selectedService;
  bool _loading = true;
  bool _checkingAvailability = false;

  @override
  void initState() {
    super.initState();
    _selectedService = _matchService(widget.request.serviceType);
    _loadProvider();
  }

  String? _matchService(String value) {
    final normalized = value.trim().toLowerCase();
    if (normalized.isEmpty) return null;
    for (final service in _services) {
      if (service.name.toLowerCase() == normalized) return service.name;
    }
    return value.trim();
  }

  Future<void> _loadProvider() async {
    try {
      final data = await ApiService().getProviderById(
        widget.request.providerId,
        realAvailability: true,
      );
      final provider = ProviderModel.fromJson(data);
      if (!mounted) return;
      setState(() {
        _provider = provider;
        _selectedService ??= provider.serviceType.trim().isEmpty
            ? null
            : provider.serviceType.trim();
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  double _priceFor(String service) {
    for (final option in _services) {
      if (option.name == service) return option.price;
    }
    return widget.request.price > 0 ? widget.request.price : 80;
  }

  Future<void> _continue() async {
    final service = _selectedService;
    final provider = _provider;
    if (service == null ||
        provider == null ||
        !ProviderBookingEligibility.canBook(provider) ||
        _checkingAvailability) {
      return;
    }

    setState(() => _checkingAvailability = true);
    try {
      final freshProvider = ProviderModel.fromJson(
        await ApiService().getProviderById(
          provider.userId,
          realAvailability: true,
        ),
      );
      if (!ProviderBookingEligibility.canBook(freshProvider)) {
        if (!mounted) return;
        if (widget.returnWhenUnavailable) {
          Navigator.pop(context, true);
        } else {
          setState(() => _provider = freshProvider);
        }
        return;
      }
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            context.l10n.isArabic
                ? 'تعذر التحقق من توفر مقدم الرعاية. حاول مرة أخرى.'
                : 'Unable to verify provider availability. Please try again.',
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    } finally {
      if (mounted) setState(() => _checkingAvailability = false);
    }

    if (!mounted) return;
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => BookingScreen(
          request: widget.request.copyWith(
            providerId: provider.userId,
            providerName: provider.fullName,
            providerRole: provider.role,
            providerImageUrl: provider.profileImageUrl ?? '',
            specialization: provider.specialization,
            serviceType: service,
            appointmentType: 'home',
            price: _priceFor(service),
            appointmentDate: '',
            appointmentTime: '',
          ),
        ),
      ),
    );

    if (result == true) {
      if (!mounted) return;
      if (widget.returnWhenUnavailable) {
        Navigator.pop(context, true);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = CarelinkPalette.of(context);
    final provider = _provider;
    final hasSlots =
        provider != null && ProviderBookingEligibility.canBook(provider);
    final canContinue =
        !_loading &&
        !_checkingAvailability &&
        hasSlots &&
        _selectedService != null;
    return PatientScaffold(
      backgroundColor: p.pageBg,
      appBar: PatientAppBar(
        title: context.l10n.isArabic
            ? 'اختر الخدمة'
            : context.tr('booking.selectService.title'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        children: [
          const SizedBox(height: 12),
          const BookingStepIndicator(currentStep: BookingFlowStep.provider),
          const SizedBox(height: 24),
          Text(
            context.l10n.isArabic
                ? 'ما الخدمة المطلوبة؟'
                : context.tr('booking.selectService.prompt'),
            style: TextStyle(
              color: p.inkDark,
              fontSize: 20,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            context.tr('booking.selectService.promptSubtitle'),
            style: TextStyle(color: p.inkMuted, height: 1.4),
          ),
          const SizedBox(height: 16),
          if (_loading)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(28),
                child: CircularProgressIndicator(color: AppColors.primary),
              ),
            )
          else ...[
            for (final service in _services)
              _ServiceCard(
                option: service,
                selected: _selectedService == service.name,
                palette: p,
                onTap: () => setState(() => _selectedService = service.name),
              ),
            if (!hasSlots)
              Container(
                margin: const EdgeInsets.only(top: 8),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.red.withValues(alpha: p.isDark ? 0.14 : 0.07),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: Colors.red.withValues(alpha: 0.25)),
                ),
                child: Text(
                  context.tr('booking.noSlots'),
                  style: TextStyle(
                    color: p.inkDark,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
          ],
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: PatientPrimaryButton(
            onPressed: canContinue ? _continue : null,
            isLoading: _checkingAvailability,
            icon: Icons.arrow_forward_rounded,
            label: context.tr('booking.continue'),
          ),
        ),
      ),
    );
  }
}

class _ServiceOption {
  const _ServiceOption(
    this.name,
    this.titleKey,
    this.descKey,
    this.icon,
    this.price,
  );

  final String name;
  final String titleKey;
  final String descKey;
  final IconData icon;
  final double price;
}

class _ServiceCard extends StatelessWidget {
  const _ServiceCard({
    required this.option,
    required this.selected,
    required this.palette,
    required this.onTap,
  });

  final _ServiceOption option;
  final bool selected;
  final CarelinkPalette palette;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: PatientPressable(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: selected
                ? AppColors.primary.withValues(
                    alpha: palette.isDark ? 0.18 : 0.05,
                  )
                : palette.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: selected ? AppColors.primary : palette.stroke,
              width: selected ? 1.5 : 1,
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                selected
                    ? Icons.check_circle_rounded
                    : Icons.radio_button_unchecked_rounded,
                color: selected ? AppColors.primary : palette.inkMuted,
                size: 22,
              ),
              const SizedBox(width: 14),
              CircleAvatar(
                radius: 22,
                backgroundColor: AppColors.primary.withValues(alpha: 0.12),
                child: Icon(option.icon, color: AppColors.primary, size: 20),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      context.tr(option.titleKey),
                      style: TextStyle(
                        color: palette.inkDark,
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      context.tr(option.descKey),
                      style: TextStyle(
                        color: palette.inkMuted,
                        fontSize: 12,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${option.price.toStringAsFixed(0)} ILS',
                      style: const TextStyle(
                        color: AppColors.primary,
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
