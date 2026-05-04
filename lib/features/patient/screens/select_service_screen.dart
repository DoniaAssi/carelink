import 'package:flutter/material.dart';

import 'package:carelink/core/app_colors.dart';
import 'package:carelink/core/carelink_palette.dart';
import 'package:carelink/shared/widgets/carelink_brand_logo.dart';
import 'package:carelink/shared/widgets/carelink_theme_toggle.dart';
import 'package:carelink/shared/models/booking_request_model.dart';
import 'booking_screen.dart';
import 'package:carelink/features/patient/widgets/booking_step_indicator.dart';

const double _kCardRadius = 14.0;

/// [value] = stored on [BookingRequestModel.serviceType].
class _ServiceOption {
  const _ServiceOption({
    required this.value,
    required this.title,
    required this.description,
    required this.icon,
  });

  final String value;
  final String title;
  final String description;
  final IconData icon;
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
      title: 'Home nursing',
      description: 'Skilled care at your residence with nursing support.',
      icon: Icons.home_filled,
    ),
    _ServiceOption(
      value: 'Wound Care',
      title: 'Wound care',
      description: 'Professional dressing and wound management.',
      icon: Icons.healing_rounded,
    ),
    _ServiceOption(
      value: 'Injection',
      title: 'Injection',
      description: 'Medication administration by a qualified nurse.',
      icon: Icons.vaccines_rounded,
    ),
    _ServiceOption(
      value: 'Elderly Care',
      title: 'Elderly care',
      description: 'Respectful support for daily health and comfort.',
      icon: Icons.elderly_rounded,
    ),
    _ServiceOption(
      value: 'Doctor Consultation',
      title: 'Doctor consultation',
      description: 'Virtual or in-person visit with a physician.',
      icon: Icons.medical_services_rounded,
    ),
    _ServiceOption(
      value: 'Follow-up Visit',
      title: 'Follow-up visit',
      description: 'Continuity of care and progress check.',
      icon: Icons.assignment_turned_in_rounded,
    ),
  ];

  String? _selectedValue;

  @override
  void initState() {
    super.initState();
    _selectedValue = _matchInitialService(widget.request.serviceType);
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

  @override
  Widget build(BuildContext context) {
    final p = CarelinkPalette.of(context);
    final canContinue = _selectedValue != null;
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
                            ),
                          ),
                        ),
                      );
                    }
                  : null,
              child: const Row(
                children: [
                  SizedBox(width: 24),
                  Expanded(
                    child: Center(
                      child: Text(
                        'Continue',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 16.5,
                          letterSpacing: 0.2,
                        ),
                      ),
                    ),
                  ),
                  Icon(Icons.arrow_forward_rounded, size: 22),
                ],
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
                        'What type of service do you need?',
                        style: TextStyle(
                          color: p.inkDark,
                          fontWeight: FontWeight.w800,
                          fontSize: 15,
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        'Choose the service that best fits your needs.',
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
                    'You can review and confirm all details in the next steps.',
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
              'Select Service',
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
                onTap: () =>
                    setState(() => _selectedValue = _services[i].value),
              ),
            ),
            const SizedBox(width: gap),
            Expanded(
              child: i + 1 < _services.length
                  ? _ServiceGridCard(
                      option: _services[i + 1],
                      selected: _selectedValue == _services[i + 1].value,
                      onTap: () => setState(
                        () => _selectedValue = _services[i + 1].value,
                      ),
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
                            option.title,
                            style: TextStyle(
                              color: p.inkDark,
                              fontWeight: FontWeight.w800,
                              fontSize: 13.5,
                              height: 1.2,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            option.description,
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
