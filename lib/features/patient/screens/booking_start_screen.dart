import 'package:flutter/material.dart';

import 'package:carelink/core/app_colors.dart';
import 'package:carelink/core/app_localizations.dart';
import 'package:carelink/core/carelink_palette.dart';
import 'package:carelink/core/profile_avatar.dart'
    show profileAvatarOrPlaceholder;
import 'package:carelink/features/patient/widgets/patient_shared_widgets.dart';
import 'package:carelink/shared/models/booking_request_model.dart';
import 'package:carelink/shared/models/provider_model.dart';
import 'package:carelink/shared/services/api_service.dart';

import 'package:carelink/features/patient/widgets/booking_step_indicator.dart';
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
  List<ProviderModel> _allProviders = const [];
  List<ProviderModel> _filteredProviders = const [];
  final TextEditingController _searchController = TextEditingController();
  String _roleFilter = 'all';

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
<<<<<<< HEAD
      final rows = await ApiService().getProviders();
=======
      final rows = await ApiService().getProviders(realAvailability: true);
>>>>>>> d65865e (My latest changes)
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

  Future<void> _selectProvider(ProviderModel provider) async {
    final result = await Navigator.push(
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
          returnWhenUnavailable: true,
        ),
      ),
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
    return Scaffold(
      backgroundColor: p.pageBg,
      appBar: PatientAppBar(
        title: _isArabic ? 'احجز موعد' : 'Book Appointment',
      ),
      body: RefreshIndicator(
        color: AppColors.primary,
        onRefresh: _loadProviders,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
          children: [
            const BookingStepIndicator(currentStep: BookingFlowStep.provider),
            const SizedBox(height: 20),
            Text(
              _isArabic ? 'اختر مقدم الرعاية' : 'Choose Provider',
              style: TextStyle(
                color: p.inkDark,
                fontSize: 20,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 5),
            Text(
              _isArabic
                  ? 'اختر مقدم الرعاية المناسب لاحتياجاتك'
                  : 'Choose the care provider that fits your needs.',
              style: TextStyle(color: p.inkMuted, height: 1.4),
            ),
            const SizedBox(height: 18),
            TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: _isArabic
                    ? 'ابحث عن مقدم رعاية أو تخصص'
                    : 'Search provider or specialty',
                hintStyle: TextStyle(color: p.inkMuted.withValues(alpha: 0.7)),
                prefixIcon: Icon(Icons.search_rounded, color: p.inkMuted),
                filled: true,
                fillColor: p.surface,
                contentPadding: const EdgeInsets.symmetric(vertical: 0),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: p.stroke),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: p.stroke),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: AppColors.primary),
                ),
              ),
            ),
            const SizedBox(height: 12),
            _ProviderRoleFilter(
              palette: p,
              isArabic: _isArabic,
              selected: _roleFilter,
              onChanged: _setRoleFilter,
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
            else if (_filteredProviders.isEmpty)
              _MessageCard(
                palette: p,
                icon: Icons.search_off_rounded,
                message: _isArabic
                    ? 'لم يتم العثور على مقدمي رعاية.'
                    : 'No providers found.',
              )
            else
              for (final provider in _filteredProviders) ...[
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

class _ProviderRoleFilter extends StatelessWidget {
  const _ProviderRoleFilter({
    required this.palette,
    required this.isArabic,
    required this.selected,
    required this.onChanged,
  });

  final CarelinkPalette palette;
  final bool isArabic;
  final String selected;
  final ValueChanged<String> onChanged;

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
            onTap: () => onChanged('nurse'),
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
  });

  final CarelinkPalette palette;
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return PatientPressable(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        height: 38,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        decoration: BoxDecoration(
          color: selected ? AppColors.primary : palette.surface,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: selected
                ? AppColors.primary
                : AppColors.primary.withValues(alpha: 0.22),
          ),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.18),
                    blurRadius: 12,
                    offset: const Offset(0, 5),
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
              size: 16,
              color: selected ? Colors.white : AppColors.primary,
            ),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: selected ? Colors.white : palette.inkDark,
                  fontSize: 12,
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
    required this.onTap,
  });

  final ProviderModel provider;
  final CarelinkPalette palette;
  final bool isArabic;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final detail = provider.specialization.trim().isNotEmpty
        ? provider.specialization
        : provider.serviceType;
    final slotsLabel = isArabic
        ? '${provider.availableSlots.length} مواعيد متاحة'
        : '${provider.availableSlots.length} available slots';
    final ratingLabel = provider.overallRating > 0
        ? provider.overallRating.toStringAsFixed(1)
        : (isArabic ? 'جديد' : 'New');

    return PatientPressable(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: palette.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: palette.stroke),
        ),
        child: Row(
          children: [
            Container(
              width: 60,
              height: 60,
              clipBehavior: Clip.antiAlias,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.primary.withValues(alpha: 0.12),
              ),
              child: profileAvatarOrPlaceholder(
                imageUrl: provider.profileImageUrl,
                size: 60,
                placeholderColor: AppColors.primary,
                placeholderIcon: Icons.medical_services_outlined,
                iconSize: 26,
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
                      fontWeight: FontWeight.w800,
                      fontSize: 15,
                    ),
                  ),
                  if (detail.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      detail,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: palette.inkMuted, fontSize: 12),
                    ),
                  ],
                  const SizedBox(height: 6),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.calendar_today_rounded,
                        color: AppColors.primary,
                        size: 14,
                      ),
                      const SizedBox(width: 4),
                      Flexible(
                        child: Text(
                          slotsLabel,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: AppColors.primary,
                            fontWeight: FontWeight.w700,
                            fontSize: 11,
                          ),
                        ),
                      ),
                      Text(
                        ' • ',
                        style: TextStyle(
                          color: palette.inkMuted,
                          fontWeight: FontWeight.w700,
                          fontSize: 11,
                        ),
                      ),
                      const Icon(
                        Icons.star_rounded,
                        color: Color(0xFFFACC15),
                        size: 14,
                      ),
                      const SizedBox(width: 3),
                      Text(
                        ratingLabel,
                        style: TextStyle(
                          color: palette.inkMuted,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Icon(
              isArabic
                  ? Icons.chevron_left_rounded
                  : Icons.chevron_right_rounded,
              color: AppColors.primary,
              size: 24,
            ),
          ],
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
