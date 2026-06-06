import 'package:flutter/material.dart';

import 'package:carelink/core/app_colors.dart';
import 'package:carelink/core/app_localizations.dart';
import 'package:carelink/core/carelink_palette.dart';
import 'package:carelink/features/patient/widgets/booking_provider_summary.dart';
import 'package:carelink/features/patient/widgets/booking_step_indicator.dart';
import 'package:carelink/features/patient/widgets/patient_shared_widgets.dart';
import 'package:carelink/shared/models/booking_request_model.dart';
import 'package:carelink/shared/models/provider_model.dart';
import 'package:carelink/shared/services/api_service.dart';

import 'booking_screen.dart';

class SelectServiceScreen extends StatefulWidget {
  const SelectServiceScreen({super.key, required this.request});

  final BookingRequestModel request;

  @override
  State<SelectServiceScreen> createState() => _SelectServiceScreenState();
}

class _SelectServiceScreenState extends State<SelectServiceScreen> {
  static const _services = <_ServiceOption>[
    _ServiceOption(
      'Home Nursing Care',
      'booking.service.homeNursing',
      Icons.home_filled,
      80,
    ),
    _ServiceOption(
      'General Doctor',
      'booking.service.generalDoctor',
      Icons.medical_services_rounded,
      150,
    ),
    _ServiceOption(
      'Elderly Care',
      'booking.service.elderlyCare',
      Icons.elderly_rounded,
      100,
    ),
    _ServiceOption(
      'Post-Surgery Care',
      'booking.service.postSurgery',
      Icons.healing_rounded,
      120,
    ),
    _ServiceOption(
      'Physiotherapy',
      'booking.service.physiotherapy',
      Icons.accessibility_new_rounded,
      130,
    ),
    _ServiceOption(
      'Mental Health Support',
      'booking.service.mentalSupport',
      Icons.psychology_rounded,
      120,
    ),
  ];

  ProviderModel? _provider;
  String? _selectedService;
  bool _loading = true;

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

  void _continue() {
    final service = _selectedService;
    final provider = _provider;
    if (service == null ||
        provider == null ||
        provider.availableSlots.isEmpty) {
      return;
    }
    Navigator.push(
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
  }

  @override
  Widget build(BuildContext context) {
    final p = CarelinkPalette.of(context);
    final provider = _provider;
    final hasSlots = provider != null && provider.availableSlots.isNotEmpty;
    final canContinue = !_loading && hasSlots && _selectedService != null;
    final summaryRequest = provider == null
        ? widget.request
        : widget.request.copyWith(
            providerName: provider.fullName,
            providerRole: provider.role,
            providerImageUrl: provider.profileImageUrl ?? '',
            specialization: provider.specialization,
            serviceType: _selectedService ?? provider.serviceType,
          );

    return Scaffold(
      backgroundColor: p.pageBg,
      appBar: PatientAppBar(title: context.tr('booking.selectService.title')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        children: [
          const BookingStepIndicator(currentStep: BookingFlowStep.service),
          const SizedBox(height: 16),
          BookingProviderSummary(request: summaryRequest),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: p.surface,
              borderRadius: BorderRadius.circular(15),
              border: Border.all(color: p.stroke),
            ),
            child: Row(
              children: [
                const Icon(Icons.home_work_outlined, color: AppColors.primary),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        context.tr('booking.appointmentType'),
                        style: TextStyle(
                          color: p.inkMuted,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        context.tr('booking.homeVisit'),
                        style: TextStyle(
                          color: p.inkDark,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          Text(
            context.tr('booking.selectService.prompt'),
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
            icon: Icons.arrow_forward_rounded,
            label: context.tr('booking.continue'),
          ),
        ),
      ),
    );
  }
}

class _ServiceOption {
  const _ServiceOption(this.name, this.titleKey, this.icon, this.price);

  final String name;
  final String titleKey;
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
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: selected
            ? AppColors.primary.withValues(alpha: palette.isDark ? 0.18 : 0.08)
            : palette.surface,
        borderRadius: BorderRadius.circular(15),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(15),
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(15),
              border: Border.all(
                color: selected ? AppColors.primary : palette.stroke,
                width: selected ? 1.5 : 1,
              ),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  backgroundColor: AppColors.primary.withValues(alpha: 0.12),
                  child: Icon(option.icon, color: AppColors.primary),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    context.tr(option.titleKey),
                    style: TextStyle(
                      color: palette.inkDark,
                      fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                    ),
                  ),
                ),
                Text(
                  '${option.price.toStringAsFixed(0)} ILS',
                  style: const TextStyle(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(width: 8),
                Icon(
                  selected
                      ? Icons.check_circle_rounded
                      : Icons.radio_button_unchecked_rounded,
                  color: selected ? AppColors.primary : palette.inkMuted,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
