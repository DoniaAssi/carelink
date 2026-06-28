import 'package:flutter/material.dart';
import 'package:carelink/shared/widgets/carelink_background.dart';

import 'package:carelink/core/app_colors.dart';
import 'package:carelink/core/app_localizations.dart';
import 'package:carelink/core/carelink_palette.dart';
import 'package:carelink/core/profile_avatar.dart'
    show profileAvatarOrPlaceholder;
import 'package:carelink/shared/models/provider_model.dart';
import 'package:carelink/features/patient/screens/booking_screen.dart';
import 'package:carelink/features/patient/utils/booking_service_helper.dart';
import 'package:carelink/shared/services/api_service.dart';
import 'package:carelink/shared/services/location_service.dart';

import 'package:carelink/features/patient/widgets/patient_shared_widgets.dart';

class BookingStartScreen extends StatefulWidget {
  const BookingStartScreen({super.key, required this.patientUserId});

  final String patientUserId;

  @override
  State<BookingStartScreen> createState() => _BookingStartScreenState();
}

class _BookingStartScreenState extends State<BookingStartScreen> {
  bool _loading = true;
  bool _isNewPatient = false;
  String? _error;
  List<ProviderModel> _allProviders = const [];
  List<ProviderModel> _filteredProviders = const [];
  final TextEditingController _searchController = TextEditingController();
  String _roleFilter = 'all';
  double? _patientLat;
  double? _patientLng;

  bool get _isArabic => context.l10n.isArabic;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);
    _loadProviders();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged() => _applyFilters();

  void _setRoleFilter(String value) {
    if (_roleFilter == value) return;
    setState(() => _roleFilter = value);
    _applyFilters();
  }

  void _applyFilters() {
    final query = _searchController.text.trim().toLowerCase();
    setState(() {
      _filteredProviders = _allProviders.where((p) {
        final role = p.role.trim().toLowerCase();
        final matchesRole =
            _roleFilter == 'all' ||
            role == _roleFilter ||
            (_roleFilter == 'doctor' && role.contains('doctor')) ||
            (_roleFilter == 'nurse' && role.contains('nurse'));
        final matchesQuery =
            query.isEmpty ||
            p.fullName.toLowerCase().contains(query) ||
            p.specialization.toLowerCase().contains(query) ||
            p.serviceType.toLowerCase().contains(query);
        return matchesRole && matchesQuery;
      }).toList();
    });
  }

  Future<void> _loadProviders() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final rows = await ApiService().getProviders(
        realAvailability: true,
        patientId: widget.patientUserId,
      );
      final profile = await ApiService().getPatientProfile(
        widget.patientUserId,
      );
      final isNew = profile['isNewPatient'] == true;
      final patientLat = double.tryParse((profile['gpsLat'] ?? '').toString());
      final patientLng = double.tryParse((profile['gpsLng'] ?? '').toString());
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
        _isNewPatient = isNew;
        _patientLat = patientLat;
        _patientLng = patientLng;
        _allProviders = providers;
        _filteredProviders = providers;
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

  double? _distanceKm(ProviderModel provider) {
    final meters = LocationService().distanceInMeters(
      fromLat: _patientLat,
      fromLng: _patientLng,
      toLat: provider.gpsLat,
      toLng: provider.gpsLng,
    );
    return meters == null ? null : meters / 1000;
  }

  Future<void> _selectProvider(ProviderModel provider) async {
    final request = BookingServiceHelper.createRequestForProvider(
      provider: provider,
      patientId: widget.patientUserId,
    );
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => BookingScreen(request: request)),
    );

    if (result == true) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _isArabic
                ? 'لم تعد هناك مواعيد متاحة لهذا مقدم الرعاية. الرجاء اختيار مقدم آخر.'
                : 'There are no more available appointments for this provider. Please select another.',
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
      _loadProviders();
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = CarelinkPalette.of(context);
    return PatientScaffold(
      backgroundColor: p.pageBg,
      appBar: PatientAppBar(
        titleWidget: Text(
          _isArabic ? 'احجز موعد' : 'Book Appointment',
          style: const TextStyle(
            color: Color(0xFF0B7A75),
            fontSize: 23,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.3,
          ),
        ),
      ),
      body: RefreshIndicator(
        color: AppColors.primary,
        onRefresh: _loadProviders,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: EdgeInsets.fromLTRB(
            16,
            8,
            16,
            112 + MediaQuery.paddingOf(context).bottom,
          ),
          children: [
            _PremiumBookingStepper(palette: p, isArabic: _isArabic),
            const SizedBox(height: 28),
            Text(
              _isArabic ? 'اختر مقدم الرعاية' : 'Choose Provider',
              style: TextStyle(
                color: p.inkDark,
                fontSize: 30,
                height: 1.15,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _isArabic
                  ? 'اختر مقدم الرعاية المناسب لاحتياجاتك'
                  : 'Choose the care provider that fits your needs.',
              style: TextStyle(
                color: p.inkMuted,
                height: 1.4,
                fontSize: 13.5,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 24),
            Container(
              height: 52,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: p.cardShadowColor(0.045),
                    blurRadius: 18,
                    offset: const Offset(0, 7),
                  ),
                ],
              ),
              child: TextField(
                controller: _searchController,
                cursorColor: AppColors.primary,
                style: TextStyle(
                  color: p.inkDark,
                  fontSize: 13.5,
                  fontWeight: FontWeight.w600,
                ),
                decoration: InputDecoration(
                  hintText: _isArabic
                      ? 'ابحث عن مقدم رعاية أو تخصص'
                      : 'Search provider or specialty',
                  hintStyle: TextStyle(
                    color: p.inkMuted.withValues(alpha: 0.78),
                    fontSize: 12.5,
                    fontWeight: FontWeight.w500,
                  ),
                  prefixIcon: const Icon(
                    Icons.search_rounded,
                    color: AppColors.primary,
                    size: 22,
                  ),
                  filled: true,
                  fillColor: p.surface,
                  contentPadding: const EdgeInsets.symmetric(vertical: 0),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(20),
                    borderSide: BorderSide(color: p.stroke),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(20),
                    borderSide: BorderSide(
                      color: p.stroke.withValues(alpha: 0.75),
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(20),
                    borderSide: const BorderSide(
                      color: AppColors.primary,
                      width: 1.2,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            _ProviderRoleFilter(
              palette: p,
              isArabic: _isArabic,
              selected: _roleFilter,
              isNewPatient: _isNewPatient,
              onChanged: _setRoleFilter,
            ),
            if (_isNewPatient)
              Container(
                margin: const EdgeInsets.only(top: 16),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.info_outline, color: AppColors.primary),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        _isArabic
                            ? 'لموعدك الأول، يرجى البدء مع طبيب للتقييم الأولي.'
                            : 'For your first appointment, please start with a doctor for initial assessment.',
                        style: const TextStyle(
                          color: AppColors.primary,
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 24),
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
            else if (_filteredProviders.isEmpty)
              _MessageCard(
                palette: p,
                icon: Icons.search_off_rounded,
                message: _isArabic
                    ? 'لم يتم العثور على مقدمي رعاية.'
                    : 'No providers found.',
              )
            else
              for (
                var index = 0;
                index < _filteredProviders.length;
                index++
              ) ...[
                TweenAnimationBuilder<double>(
                  key: ValueKey(_filteredProviders[index].userId),
                  tween: Tween(begin: 0, end: 1),
                  duration: Duration(
                    milliseconds: 220 + (index.clamp(0, 4) * 30),
                  ),
                  curve: Curves.easeOutCubic,
                  builder: (context, value, child) => Opacity(
                    opacity: value,
                    child: Transform.translate(
                      offset: Offset(0, 14 * (1 - value)),
                      child: child,
                    ),
                  ),
                  child: _ProviderChoiceCard(
                    provider: _filteredProviders[index],
                    palette: p,
                    isArabic: _isArabic,
                    distanceKm: _distanceKm(_filteredProviders[index]),
                    onTap: () => _selectProvider(_filteredProviders[index]),
                  ),
                ),
                const SizedBox(height: 16),
              ],
          ],
        ),
      ),
    );
  }
}

class _PremiumBookingStepper extends StatelessWidget {
  const _PremiumBookingStepper({required this.palette, required this.isArabic});

  final CarelinkPalette palette;
  final bool isArabic;

  @override
  Widget build(BuildContext context) {
    final labels = isArabic
        ? const ['مقدم الرعاية', 'التاريخ والوقت', 'الموقع', 'المراجعة']
        : const ['Provider', 'Date & time', 'Location', 'Review'];
    return Column(
      children: [
        Row(
          children: List.generate(7, (index) {
            if (index.isOdd) {
              return Expanded(
                child: Container(
                  height: 2,
                  color: palette.stroke.withValues(alpha: 0.85),
                ),
              );
            }
            final step = index ~/ 2;
            final current = step == 0;
            return AnimatedContainer(
              duration: const Duration(milliseconds: 240),
              width: 32,
              height: 32,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: current ? const Color(0xFF0B7A75) : palette.surface,
                shape: BoxShape.circle,
                border: Border.all(
                  color: current ? const Color(0xFF0B7A75) : palette.stroke,
                  width: 1.4,
                ),
                boxShadow: current
                    ? [
                        BoxShadow(
                          color: AppColors.primary.withValues(alpha: 0.2),
                          blurRadius: 12,
                          offset: const Offset(0, 5),
                        ),
                      ]
                    : null,
              ),
              child: Text(
                '${step + 1}',
                style: TextStyle(
                  color: current ? Colors.white : palette.inkMuted,
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                ),
              ),
            );
          }),
        ),
        const SizedBox(height: 8),
        Row(
          children: List.generate(labels.length, (index) {
            return Expanded(
              child: Text(
                labels[index],
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: index == 0 ? AppColors.primary : palette.inkMuted,
                  fontSize: 10,
                  fontWeight: index == 0 ? FontWeight.w800 : FontWeight.w600,
                ),
              ),
            );
          }),
        ),
      ],
    );
  }
}

class _ProviderRoleFilter extends StatelessWidget {
  const _ProviderRoleFilter({
    required this.palette,
    required this.isArabic,
    required this.selected,
    required this.onChanged,
    this.isNewPatient = false,
  });

  final CarelinkPalette palette;
  final bool isArabic;
  final String selected;
  final ValueChanged<String> onChanged;
  final bool isNewPatient;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _ProviderRoleChip(
            palette: palette,
            icon: Icons.groups_2_outlined,
            label: isArabic ? 'الكل' : 'All',
            selected: selected == 'all',
            onTap: () => onChanged('all'),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _ProviderRoleChip(
            palette: palette,
            icon: Icons.medical_services_outlined,
            label: isArabic ? 'طبيب' : 'Doctor',
            selected: selected == 'doctor',
            onTap: () => onChanged('doctor'),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _ProviderRoleChip(
            palette: palette,
            icon: Icons.local_hospital_outlined,
            label: isArabic ? 'ممرض' : 'Nurse',
            selected: selected == 'nurse',
            disabled: isNewPatient,
            onTap: () {
              if (isNewPatient) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      isArabic
                          ? 'متابعة التمريض تصبح متاحة بعد موعدك الأول مع الطبيب.'
                          : 'Nurse follow-up becomes available after your first doctor appointment.',
                    ),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              } else {
                onChanged('nurse');
              }
            },
          ),
        ),
      ],
    );
  }
}

class _ProviderRoleChip extends StatelessWidget {
  const _ProviderRoleChip({
    required this.palette,
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
    this.disabled = false,
  });

  final CarelinkPalette palette;
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final bool disabled;

  @override
  Widget build(BuildContext context) {
    return PatientPressable(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
        height: 44,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: selected
              ? AppColors.primary
              : (disabled
                    ? palette.surface.withValues(alpha: 0.5)
                    : palette.surface),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: selected
                ? AppColors.primary
                : (disabled
                      ? palette.stroke.withValues(alpha: 0.5)
                      : AppColors.primary.withValues(alpha: 0.22)),
          ),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.18),
                    blurRadius: 15,
                    offset: const Offset(0, 6),
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 17,
              color: selected
                  ? Colors.white
                  : (disabled
                        ? palette.inkMuted.withValues(alpha: 0.5)
                        : AppColors.primary),
            ),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: selected
                      ? Colors.white
                      : (disabled
                            ? palette.inkMuted.withValues(alpha: 0.5)
                            : palette.inkDark),
                  fontSize: 12.5,
                  fontWeight: FontWeight.w800,
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
    required this.palette,
    required this.isArabic,
    required this.distanceKm,
    required this.onTap,
  });

  final ProviderModel provider;
  final CarelinkPalette palette;
  final bool isArabic;
  final double? distanceKm;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final detail = provider.serviceType.trim().isNotEmpty
        ? provider.serviceType
        : provider.specialization;
    final ratingLabel = provider.overallRating > 0
        ? provider.overallRating.toStringAsFixed(1)
        : (isArabic ? 'جديد' : 'New');
    final distanceLabel = distanceKm == null
        ? '—'
        : '${distanceKm!.toStringAsFixed(1)} ${isArabic ? 'كم' : 'km'}';

    return PatientPressable(
      onTap: onTap,
      borderRadius: BorderRadius.circular(24),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: palette.surface,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: palette.stroke.withValues(alpha: 0.65)),
          boxShadow: [
            BoxShadow(
              color: palette.cardShadowColor(0.055),
              blurRadius: 24,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Hero(
                  tag: 'provider-avatar-${provider.userId}',
                  child: SizedBox(
                    width: 84,
                    height: 84,
                    child: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        Positioned.fill(
                          child: Container(
                            clipBehavior: Clip.antiAlias,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: AppColors.primary.withValues(alpha: 0.1),
                              border: Border.all(
                                color: AppColors.primary.withValues(
                                  alpha: 0.16,
                                ),
                              ),
                            ),
                            child: profileAvatarOrPlaceholder(
                              imageUrl: provider.profileImageUrl,
                              size: 84,
                              placeholderColor: AppColors.primary,
                              placeholderIcon: Icons.person_outline_rounded,
                              iconSize: 34,
                            ),
                          ),
                        ),
                        PositionedDirectional(
                          end: -1,
                          bottom: 3,
                          child: Container(
                            width: 25,
                            height: 25,
                            decoration: BoxDecoration(
                              color: const Color(0xFF16A34A),
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: palette.surface,
                                width: 2.5,
                              ),
                            ),
                            child: const Icon(
                              Icons.check_rounded,
                              color: Colors.white,
                              size: 15,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 14),
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
                          fontWeight: FontWeight.w900,
                          fontSize: 19.5,
                          height: 1.15,
                        ),
                      ),
                      if (detail.isNotEmpty) ...[
                        const SizedBox(height: 5),
                        Text(
                          detail,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: palette.inkMuted,
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                      if (provider.isActive && provider.isProfileComplete) ...[
                        const SizedBox(height: 9),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 9,
                            vertical: 5,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withValues(alpha: 0.09),
                            borderRadius: BorderRadius.circular(99),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.shield_outlined,
                                color: AppColors.primary,
                                size: 14,
                              ),
                              const SizedBox(width: 5),
                              Flexible(
                                child: Text(
                                  isArabic
                                      ? 'موثّق من CareLink'
                                      : 'Verified by CareLink',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: AppColors.primary,
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.09),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    isArabic
                        ? Icons.chevron_left_rounded
                        : Icons.chevron_right_rounded,
                    color: AppColors.primary,
                    size: 28,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Divider(height: 1, color: palette.stroke.withValues(alpha: 0.68)),
            const SizedBox(height: 16),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: _ProviderInfoMetric(
                    palette: palette,
                    icon: Icons.star_rounded,
                    iconColor: const Color(0xFFFFB020),
                    value: ratingLabel,
                    subtitle: provider.ratingsCount > 0
                        ? (isArabic
                              ? '${provider.ratingsCount} تقييم'
                              : '${provider.ratingsCount} reviews')
                        : (isArabic ? 'التقييم' : 'Rating'),
                  ),
                ),
                _ProviderMetricDivider(palette: palette),
                Expanded(
                  child: _ProviderInfoMetric(
                    palette: palette,
                    icon: Icons.location_on_outlined,
                    value: distanceLabel,
                    subtitle: isArabic ? 'المسافة' : 'Distance',
                  ),
                ),
                _ProviderMetricDivider(palette: palette),
                Expanded(
                  child: _ProviderInfoMetric(
                    palette: palette,
                    icon: Icons.schedule_rounded,
                    value: isArabic ? 'متاح الآن' : 'Available',
                    subtitle: isArabic ? 'جاهز للحجز' : 'Ready to book',
                    showAvailabilityDot: true,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ProviderMetricDivider extends StatelessWidget {
  const _ProviderMetricDivider({required this.palette});

  final CarelinkPalette palette;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 1,
      height: 68,
      margin: const EdgeInsets.symmetric(horizontal: 7),
      color: palette.stroke.withValues(alpha: 0.75),
    );
  }
}

class _ProviderInfoMetric extends StatelessWidget {
  const _ProviderInfoMetric({
    required this.palette,
    required this.icon,
    required this.value,
    required this.subtitle,
    this.iconColor = AppColors.primary,
    this.showAvailabilityDot = false,
  });

  final CarelinkPalette palette;
  final IconData icon;
  final Color iconColor;
  final String value;
  final String subtitle;
  final bool showAvailabilityDot;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: iconColor.withValues(alpha: 0.09),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: iconColor, size: 19),
        ),
        const SizedBox(height: 7),
        Text(
          value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: palette.inkDark,
            fontSize: 12.5,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 4),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (showAvailabilityDot) ...[
              Container(
                width: 6,
                height: 6,
                decoration: const BoxDecoration(
                  color: Color(0xFF16A34A),
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 4),
            ],
            Flexible(
              child: Text(
                subtitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: palette.inkMuted,
                  fontSize: 9.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ],
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
