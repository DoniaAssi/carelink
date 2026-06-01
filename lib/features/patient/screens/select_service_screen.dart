import 'package:flutter/material.dart';

import 'package:carelink/core/app_colors.dart';
import 'package:carelink/core/app_localizations.dart';
import 'package:carelink/core/carelink_palette.dart';
import 'package:carelink/shared/widgets/carelink_brand_logo.dart';
import 'package:carelink/shared/widgets/carelink_theme_toggle.dart';
import 'package:carelink/shared/models/booking_request_model.dart';
import 'package:carelink/shared/models/provider_model.dart';
import 'package:carelink/shared/services/api_service.dart';
import 'booking_screen.dart';
import 'package:carelink/features/patient/widgets/booking_step_indicator.dart';

const double _kCardRadius = 14.0;

/// [value] = stored on [BookingRequestModel.serviceType].
class _ServiceOption {
  const _ServiceOption({
    required this.value,
    required this.titleKey,
    required this.descriptionKey,
    required this.icon,
    required this.terms,
  });

  final String value;
  final String titleKey;
  final String descriptionKey;
  final IconData icon;
  final List<String> terms;
}

class SelectServiceScreen extends StatefulWidget {
  final BookingRequestModel request;

  const SelectServiceScreen({super.key, required this.request});

  @override
  State<SelectServiceScreen> createState() => _SelectServiceScreenState();
}

class _SelectServiceScreenState extends State<SelectServiceScreen> {
  static const List<_ServiceOption> _services = [
    _ServiceOption(
      value: 'Home Nursing Care',
      titleKey: 'booking.service.homeNursing',
      descriptionKey: 'booking.service.homeNursing.desc',
      icon: Icons.home_filled,
      terms: ['home nursing', 'nursing', 'nurse', 'تمريض'],
    ),
    _ServiceOption(
      value: 'General Doctor',
      titleKey: 'booking.service.generalDoctor',
      descriptionKey: 'booking.service.generalDoctor.desc',
      icon: Icons.medical_services_rounded,
      terms: ['general doctor', 'doctor', 'physician', 'طبيب'],
    ),
    _ServiceOption(
      value: 'Post-surgery Care',
      titleKey: 'booking.service.postSurgery',
      descriptionKey: 'booking.service.postSurgery.desc',
      icon: Icons.healing_rounded,
      terms: ['post-surgery', 'post surgery', 'surgery', 'after surgery'],
    ),
    _ServiceOption(
      value: 'Elderly Care',
      titleKey: 'booking.service.elderlyCare',
      descriptionKey: 'booking.service.elderlyCare.desc',
      icon: Icons.elderly_rounded,
      terms: ['elderly', 'senior', 'كبار'],
    ),
    _ServiceOption(
      value: 'Physiotherapy',
      titleKey: 'booking.service.physiotherapy',
      descriptionKey: 'booking.service.physiotherapy.desc',
      icon: Icons.accessibility_new_rounded,
      terms: ['physiotherapy', 'physical therapy', 'therapy', 'علاج طبيعي'],
    ),
    _ServiceOption(
      value: 'Mental Support',
      titleKey: 'booking.service.mentalSupport',
      descriptionKey: 'booking.service.mentalSupport.desc',
      icon: Icons.psychology_rounded,
      terms: ['mental', 'psychology', 'support', 'نفسي'],
    ),
  ];

  String? _selectedValue;
  String _appointmentType = 'home';
  bool _loadingProviders = true;
  String? _providerError;
  List<ProviderModel> _providers = const [];
  ProviderModel? _selectedProvider;

  @override
  void initState() {
    super.initState();
    _selectedValue = _matchInitialService(widget.request.serviceType);
    _appointmentType = widget.request.appointmentType.trim().isEmpty
        ? 'home'
        : widget.request.appointmentType.trim();
    _loadProviders();
  }

  String? _matchInitialService(String raw) {
    final t = raw.trim();
    if (t.isEmpty) return null;
    for (final s in _services) {
      if (s.value == t) return s.value;
    }
    final lower = t.toLowerCase();
    for (final s in _services) {
      if (s.value.toLowerCase() == lower) return s.value;
    }
    return null;
  }

  Future<void> _loadProviders({bool restoreRequestProvider = true}) async {
    setState(() {
      _loadingProviders = true;
      _providerError = null;
    });
    try {
      final data = await ApiService().getProviders();
      final providers = data
          .whereType<Map>()
          .map((e) => ProviderModel.fromJson(Map<String, dynamic>.from(e)))
          .toList();
      if (!mounted) return;
      setState(() {
        _providers = providers;
        _selectedProvider = restoreRequestProvider
            ? _providerFromRequest(providers)
            : null;
      });
    } catch (_) {
      if (!mounted) return;
      setState(
        () => _providerError = context.tr('booking.noProvidersForService'),
      );
    } finally {
      if (mounted) setState(() => _loadingProviders = false);
    }
  }

  ProviderModel? _providerFromRequest(List<ProviderModel> providers) {
    final id = widget.request.providerId.trim();
    if (id.isEmpty) return null;
    for (final provider in providers) {
      if (provider.userId == id) return provider;
    }
    if (widget.request.providerName.trim().isEmpty) return null;
    return ProviderModel(
      userId: id,
      fullName: widget.request.providerName,
      specialization: widget.request.specialization,
      serviceType: widget.request.serviceType,
      overallRating: 0,
      role: widget.request.providerRole,
      isAvailable: true,
      consultationFee: widget.request.price,
    );
  }

  List<ProviderModel> get _filteredProviders {
    final service = _selectedService;
    if (service == null) return const [];
    return _providers
        .where((provider) => _matchesService(provider, service))
        .toList();
  }

  _ServiceOption? get _selectedService {
    final value = _selectedValue;
    if (value == null) return null;
    for (final service in _services) {
      if (service.value == value) return service;
    }
    return null;
  }

  bool _matchesService(ProviderModel provider, _ServiceOption service) {
    final haystack = [
      provider.serviceType,
      provider.specialization,
      provider.role,
    ].join(' ').toLowerCase();
    return service.terms.any((term) => haystack.contains(term.toLowerCase()));
  }

  void _selectService(String value) {
    var changed = false;
    setState(() {
      if (_selectedValue != value) {
        _selectedValue = value;
        _selectedProvider = null;
        changed = true;
      }
    });
    if (changed) {
      _loadProviders(restoreRequestProvider: false);
    }
  }

  String _localizedProviderRole(ProviderModel provider) {
    final role = provider.role.toLowerCase();
    if (role.contains('doctor')) {
      return context.l10n.isArabic ? 'طبيب' : 'Doctor';
    }
    if (role.contains('nurse')) {
      return context.l10n.isArabic ? 'ممرض' : 'Nurse';
    }
    return provider.role.trim().isEmpty ? '-' : provider.role.trim();
  }

  double _getServicePrice(String? serviceType) {
    switch (serviceType) {
      case 'Home Nursing Care':
        return 80.0;
      case 'General Doctor':
        return 150.0;
      case 'Elderly Care':
        return 100.0;
      case 'Post-surgery Care':
        return 120.0;
      case 'Physiotherapy':
        return 130.0;
      case 'Mental Support':
        return 120.0;
      default:
        return _selectedProvider?.consultationFee ?? widget.request.price;
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = CarelinkPalette.of(context);
    final canContinue = _selectedValue != null && _selectedProvider != null;
    return Scaffold(
      backgroundColor: p.pageBg,
      bottomNavigationBar: SafeArea(
        top: false,
        child: Container(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          decoration: BoxDecoration(
            color: p.pageBg,
            border: Border(top: BorderSide(color: p.stroke)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: p.isDark ? 0.28 : 0.08),
                blurRadius: 18,
                offset: const Offset(0, -6),
              ),
            ],
          ),
          child: SizedBox(
            height: 52,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: canContinue
                    ? AppColors.primary
                    : p.surfaceSoft,
                foregroundColor: canContinue ? Colors.white : p.inkMuted,
                disabledBackgroundColor: p.surfaceSoft,
                elevation: canContinue ? 2 : 0,
                shadowColor: canContinue
                    ? AppColors.primary.withValues(alpha: 0.35)
                    : null,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(_kCardRadius + 1),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 20),
              ),
              onPressed: canContinue
                  ? () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => BookingScreen(
                            request: widget.request.copyWith(
                              serviceType: _selectedValue!,
                              appointmentType: _appointmentType,
                              providerId: _selectedProvider!.userId,
                              providerName: _selectedProvider!.fullName,
                              providerRole: _selectedProvider!.role,
                              specialization: _selectedProvider!.specialization,
                              price: _getServicePrice(_selectedValue),
                              appointmentDate: '',
                              appointmentTime: '',
                            ),
                          ),
                        ),
                      );
                    }
                  : null,
              child: Center(
                child: Text(
                  context.tr('booking.continue'),
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 16.5,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        children: [
          _buildHeader(p),
          const SizedBox(height: 16),
          const BookingStepIndicator(currentStep: BookingFlowStep.service),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: p.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: p.stroke),
              boxShadow: [_cardShadow(p)],
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const _InfoDot(icon: Icons.medical_services_outlined),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        context.tr('booking.selectService.prompt'),
                        style: TextStyle(
                          color: p.inkDark,
                          fontWeight: FontWeight.w800,
                          fontSize: 15,
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        context.tr('booking.selectService.promptSubtitle'),
                        style: TextStyle(
                          color: p.inkMuted,
                          fontWeight: FontWeight.w500,
                          fontSize: 12.5,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          ..._buildServiceGrid(),
          const SizedBox(height: 18),
          _buildAppointmentTypeCard(p),
          const SizedBox(height: 18),
          _buildProviderSection(p),
          const SizedBox(height: 18),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            decoration: BoxDecoration(
              color: p.surfaceSoft,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: p.stroke),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.info_outline_rounded,
                  color: AppColors.primary,
                  size: 20,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    context.tr('booking.review.nextPayment'),
                    style: TextStyle(
                      color: p.isDark ? p.inkDark : AppColors.primary,
                      fontSize: 12.5,
                      fontWeight: FontWeight.w500,
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(CarelinkPalette p) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
      decoration: BoxDecoration(
        color: p.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: p.stroke),
        boxShadow: [_cardShadow(p)],
      ),
      child: Row(
        children: [
          _HeaderIconButton(
            icon: Icons.arrow_back_ios_new_rounded,
            color: p.inkDark,
            background: p.surfaceSoft,
            border: p.stroke,
            onTap: () => Navigator.maybePop(context),
          ),
          const SizedBox(width: 10),
          CarelinkBrandLogo(
            height: 28,
            fallbackTextColor: p.inkDark,
            forceDarkLogo: p.isDark,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              context.tr('booking.selectService.title'),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: p.inkDark,
                fontSize: 20,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: p.surfaceSoft,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: p.stroke),
            ),
            child: CarelinkThemeIconButton(color: p.inkDark),
          ),
        ],
      ),
    );
  }

  BoxShadow _cardShadow(CarelinkPalette p) {
    return BoxShadow(
      color: Colors.black.withValues(alpha: p.isDark ? 0.22 : 0.045),
      blurRadius: 16,
      offset: const Offset(0, 8),
    );
  }

  List<Widget> _buildServiceGrid() {
    const gap = 10.0;
    final out = <Widget>[];
    for (var i = 0; i < _services.length; i += 2) {
      out.add(
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: _ServiceGridCard(
                option: _services[i],
                selected: _selectedValue == _services[i].value,
                onTap: () => _selectService(_services[i].value),
              ),
            ),
            const SizedBox(width: gap),
            Expanded(
              child: i + 1 < _services.length
                  ? _ServiceGridCard(
                      option: _services[i + 1],
                      selected: _selectedValue == _services[i + 1].value,
                      onTap: () => _selectService(_services[i + 1].value),
                    )
                  : const SizedBox.shrink(),
            ),
          ],
        ),
      );
      if (i + 2 < _services.length) {
        out.add(const SizedBox(height: gap));
      }
    }
    return out;
  }

  Widget _buildAppointmentTypeCard(CarelinkPalette p) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: p.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: p.stroke),
        boxShadow: [_cardShadow(p)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            context.tr('booking.appointmentType'),
            style: TextStyle(
              color: p.inkDark,
              fontWeight: FontWeight.w800,
              fontSize: 15,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _AppointmentTypeButton(
                  icon: Icons.home_filled,
                  label: context.tr('booking.homeVisit'),
                  selected: _appointmentType == 'home',
                  onTap: () => setState(() => _appointmentType = 'home'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _AppointmentTypeButton(
                  icon: Icons.videocam_rounded,
                  label: context.tr('booking.remoteConsultation'),
                  selected: _appointmentType == 'remote',
                  onTap: () => setState(() => _appointmentType = 'remote'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildProviderSection(CarelinkPalette p) {
    final providers = _filteredProviders;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: p.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: p.stroke),
        boxShadow: [_cardShadow(p)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            context.tr('booking.chooseProvider'),
            style: TextStyle(
              color: p.inkDark,
              fontWeight: FontWeight.w800,
              fontSize: 15,
            ),
          ),
          const SizedBox(height: 12),
          if (_loadingProviders)
            Row(
              children: [
                const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    context.tr('booking.loadingProviders'),
                    style: TextStyle(color: p.inkMuted),
                  ),
                ),
              ],
            )
          else if (_providerError != null)
            _ProviderMessage(
              text: _providerError!,
              actionLabel: context.tr('booking.tryAgain'),
              onPressed: _loadProviders,
            )
          else if (_selectedValue == null || providers.isEmpty)
            _ProviderMessage(text: context.tr('booking.noProvidersForService'))
          else
            ...providers.map(
              (provider) => _ProviderChoiceCard(
                provider: provider,
                role: _localizedProviderRole(provider),
                selected: _selectedProvider?.userId == provider.userId,
                onTap: () => setState(() => _selectedProvider = provider),
              ),
            ),
        ],
      ),
    );
  }
}

class _AppointmentTypeButton extends StatelessWidget {
  const _AppointmentTypeButton({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = CarelinkPalette.of(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(13),
      child: Container(
        constraints: const BoxConstraints(minHeight: 48),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        decoration: BoxDecoration(
          color: selected ? AppColors.primary : p.surfaceSoft,
          borderRadius: BorderRadius.circular(13),
          border: Border.all(color: selected ? AppColors.primary : p.stroke),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 18, color: selected ? Colors.white : p.inkDark),
            const SizedBox(width: 7),
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: selected ? Colors.white : p.inkDark,
                  fontWeight: FontWeight.w800,
                  fontSize: 12.5,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProviderChoiceCard extends StatelessWidget {
  const _ProviderChoiceCard({
    required this.provider,
    required this.role,
    required this.selected,
    required this.onTap,
  });

  final ProviderModel provider;
  final String role;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = CarelinkPalette.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: selected
                ? AppColors.primary.withValues(alpha: 0.08)
                : p.surfaceSoft,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: selected ? AppColors.primary : p.stroke,
              width: selected ? 1.5 : 1,
            ),
          ),
          child: Row(
            children: [
              CircleAvatar(
                radius: 22,
                backgroundColor: AppColors.primary.withValues(alpha: 0.14),
                child: Icon(
                  role == (context.l10n.isArabic ? 'طبيب' : 'Doctor')
                      ? Icons.medical_services_rounded
                      : Icons.local_hospital_rounded,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      provider.fullName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: p.inkDark,
                        fontWeight: FontWeight.w800,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      [
                        role,
                        if (provider.specialization.trim().isNotEmpty)
                          provider.specialization.trim(),
                      ].join(' · '),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: p.inkMuted,
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              if (selected)
                const Icon(
                  Icons.check_circle_rounded,
                  color: AppColors.primary,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ProviderMessage extends StatelessWidget {
  const _ProviderMessage({
    required this.text,
    this.actionLabel,
    this.onPressed,
  });

  final String text;
  final String? actionLabel;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final p = CarelinkPalette.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: p.surfaceSoft,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: p.stroke),
      ),
      child: Column(
        children: [
          Text(
            text,
            textAlign: TextAlign.center,
            style: TextStyle(color: p.inkMuted, fontWeight: FontWeight.w600),
          ),
          if (actionLabel != null && onPressed != null) ...[
            const SizedBox(height: 8),
            TextButton(onPressed: onPressed, child: Text(actionLabel!)),
          ],
        ],
      ),
    );
  }
}

class _ServiceGridCard extends StatelessWidget {
  const _ServiceGridCard({
    required this.option,
    required this.selected,
    required this.onTap,
  });

  final _ServiceOption option;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = CarelinkPalette.of(context);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(_kCardRadius),
        child: Ink(
          padding: const EdgeInsets.fromLTRB(10, 10, 10, 12),
          decoration: BoxDecoration(
            color: p.surface,
            borderRadius: BorderRadius.circular(_kCardRadius),
            border: Border.all(
              color: selected ? AppColors.primary : p.stroke,
              width: selected ? 2 : 1,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: p.isDark ? 0.18 : 0.04),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 2, right: 28),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.12),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        option.icon,
                        color: AppColors.primaryDark,
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            context.tr(option.titleKey),
                            style: TextStyle(
                              color: p.inkDark,
                              fontWeight: FontWeight.w800,
                              fontSize: 13.5,
                              height: 1.2,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            context.tr(option.descriptionKey),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: p.inkMuted,
                              fontWeight: FontWeight.w500,
                              fontSize: 11.5,
                              height: 1.3,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              Positioned(
                top: 0,
                right: 0,
                child: _SelectionPip(selected: selected),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SelectionPip extends StatelessWidget {
  const _SelectionPip({required this.selected});

  final bool selected;

  @override
  Widget build(BuildContext context) {
    final p = CarelinkPalette.of(context);
    if (selected) {
      return Container(
        width: 22,
        height: 22,
        decoration: const BoxDecoration(
          color: AppColors.primary,
          shape: BoxShape.circle,
        ),
        child: const Icon(Icons.check, size: 14, color: Colors.white),
      );
    }
    return Container(
      width: 22,
      height: 22,
      decoration: BoxDecoration(
        color: p.surface,
        shape: BoxShape.circle,
        border: Border.all(
          color: p.inkMuted.withValues(alpha: 0.55),
          width: 1.5,
        ),
      ),
    );
  }
}

class _InfoDot extends StatelessWidget {
  const _InfoDot({required this.icon});

  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final p = CarelinkPalette.of(context);
    return Container(
      width: 46,
      height: 46,
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: p.isDark ? 0.16 : 0.1),
        shape: BoxShape.circle,
      ),
      child: Icon(icon, color: AppColors.primary, size: 25),
    );
  }
}

class _HeaderIconButton extends StatelessWidget {
  const _HeaderIconButton({
    required this.icon,
    required this.color,
    required this.background,
    required this.border,
    required this.onTap,
  });

  final IconData icon;
  final Color color;
  final Color background;
  final Color border;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: border),
        ),
        child: Icon(icon, size: 18, color: color),
      ),
    );
  }
}
