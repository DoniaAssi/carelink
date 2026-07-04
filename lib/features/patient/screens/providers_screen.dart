import 'package:flutter/material.dart';

import 'package:carelink/core/app_colors.dart';
import 'package:carelink/core/app_localizations.dart';
import 'package:carelink/core/carelink_palette.dart';
import 'package:carelink/core/profile_avatar.dart'
    show profileAvatarOrPlaceholder;
import 'package:carelink/shared/models/provider_model.dart';
import 'package:carelink/shared/services/api_service.dart';
import 'package:carelink/shared/services/location_service.dart';
import 'package:carelink/shared/services/medical_record_service.dart';
import 'package:carelink/features/patient/services/patient_care_summary.dart';
import 'package:carelink/features/ai/provider_smart_match.dart';
import 'package:carelink/features/ai/provider_booking_eligibility.dart';
import 'package:carelink/shared/services/patient_favorites_service.dart';
import 'package:carelink/features/patient/widgets/patient_shared_widgets.dart';
import 'package:carelink/shared/widgets/carelink_responsive.dart';
import 'provider_details_screen.dart';

enum ProviderSortOption {
  smartMatch,
  nearest,
  ratingHighToLow,
  availableNow,
  priceLowToHigh,
}

class ProvidersScreen extends StatefulWidget {
  final String? userId;

  const ProvidersScreen({super.key, this.userId});

  @override
  State<ProvidersScreen> createState() => _ProvidersScreenState();
}

class _ProvidersScreenState extends State<ProvidersScreen> {
  final TextEditingController _searchController = TextEditingController();

  /// Mirrors the search field — avoids Flutter web failures reading `.text` on web.
  String _searchQuery = '';
  final LocationService _locationService = LocationService();

  List<ProviderModel> _providers = [];
  List<ProviderModel> _visibleProviders = [];
  Map<String, Map<String, dynamic>> _backendRecommendations = {};

  bool _isLoading = true;
  String? _errorMessage;
  double? _patientLat;
  double? _patientLng;
  PatientCareSummary _careSummary = PatientCareSummary.empty;
  Set<String> _favoriteIds = {};

  String _selectedRole = 'all';
  String _selectedSpecialization = 'all';
  String _selectedServiceType = 'all';
  bool _availableNowOnly = false;
  double _minRating = 0;
  double? _maxDistanceKm;
  double? _maxPrice;
  ProviderSortOption _sortOption = ProviderSortOption.smartMatch;

  @override
  void initState() {
    super.initState();
    _fetchProviders();
    _loadPatientLocation();
    _loadMedicalSummary();
    _loadFavorites();
  }

  Future<void> _loadFavorites() async {
    if (widget.userId == null) return;
    try {
      final favs = await PatientFavoritesService.getFavorites(widget.userId!);
      if (mounted) {
        setState(() {
          _favoriteIds = favs.map((e) => e['providerId'].toString()).toSet();
        });
      }
    } catch (_) {}
  }

  Future<void> _loadMedicalSummary() async {
    final id = widget.userId?.trim();
    if (id == null || id.isEmpty) {
      _careSummary = PatientCareSummary.empty;
      return;
    }
    try {
      Map<String, dynamic> profile = {};
      try {
        profile = await ApiService().getPatientProfile(id);
      } catch (_) {}
      var clinical = <Map<String, dynamic>>[];
      try {
        clinical = await MedicalRecordService().listForPatient(
          id,
          requesterUserId: id,
          requesterRole: 'patient',
        );
      } catch (_) {}
      if (!mounted) return;
      setState(() {
        final base = PatientCareSummary.mergeBaseline(
          PatientCareSummary.empty,
          profile,
        );
        _careSummary = PatientCareSummary.mergeClinical(base, clinical);
        _applyFiltersAndSort();
      });
    } catch (error) {
      if (mounted) {
        setState(() {
          _careSummary = PatientCareSummary.empty;
          _applyFiltersAndSort();
        });
      }
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _fetchProviders() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      List<dynamic> data;
      final backendRecommendations = <String, Map<String, dynamic>>{};
      try {
        final patientId = widget.userId?.trim() ?? '';
        if (patientId.isEmpty) {
          data = await ApiService().getProviders(realAvailability: true);
        } else {
          final ranked = await ApiService().getProviderRecommendations(
            patientId,
          );
          for (final item in ranked) {
            if (item is! Map) continue;
            final map = Map<String, dynamic>.from(item);
            final provider = map['provider'];
            if (provider is Map) {
              final providerMap = Map<String, dynamic>.from(provider);
              final id =
                  providerMap['userId']?.toString() ??
                  providerMap['id']?.toString() ??
                  '';
              if (id.isNotEmpty) backendRecommendations[id] = map;
            }
          }
          data = await ApiService().getProviders(
            realAvailability: true,
            patientId: patientId,
          );
        }
      } catch (_) {
        final patientId = widget.userId?.trim() ?? '';
        data = await ApiService().getProviders(
          realAvailability: true,
          patientId: patientId,
        );
      }
      final fetched = data
          .map((e) => ProviderModel.fromJson(e))
          .where(ProviderBookingEligibility.canBook)
          .toList();
      if (!mounted) return;

      _providers = fetched;
      _backendRecommendations = backendRecommendations;
      _applyFiltersAndSort();
      setState(() => _isLoading = false);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = context.l10n.userMessage(error);
      });
    }
  }

  Future<void> _loadPatientLocation() async {
    try {
      final position = await _locationService.getCurrentPosition();
      if (!mounted) return;
      setState(() {
        _patientLat = position.latitude;
        _patientLng = position.longitude;
      });

      if (widget.userId != null && widget.userId!.isNotEmpty) {
        await ApiService().updatePatientLocation(
          userId: widget.userId!,
          gpsLat: position.latitude,
          gpsLng: position.longitude,
        );
      }

      _applyFiltersAndSort();
    } catch (_) {
      // Keep searching/filtering even when GPS is unavailable.
    }
  }

  int _distanceFor(ProviderModel provider) {
    final realDistance = _locationService.distanceInMeters(
      fromLat: _patientLat,
      fromLng: _patientLng,
      toLat: provider.gpsLat,
      toLng: provider.gpsLng,
    );
    if (realDistance != null) return realDistance.round();

    final seed = provider.userId.codeUnits.fold<int>(0, (sum, c) => sum + c);
    return 500 + (seed % 700);
  }

  void _applyFiltersAndSort() {
    final query = _searchQuery.toLowerCase().trim();

    var list = _providers.where((provider) {
      final role = provider.role.toLowerCase();
      final specialization = provider.specialization.toLowerCase();
      final serviceType = provider.serviceType.toLowerCase();
      final fullName = provider.fullName.toLowerCase();

      final searchMatches =
          query.isEmpty ||
          fullName.contains(query) ||
          role.contains(query) ||
          specialization.contains(query) ||
          serviceType.contains(query);

      final roleMatches =
          _selectedRole == 'all' || role == _selectedRole.toLowerCase();
      final specializationMatches =
          _selectedSpecialization == 'all' ||
          provider.specialization.toLowerCase() ==
              _selectedSpecialization.toLowerCase();
      final serviceTypeMatches =
          _selectedServiceType == 'all' ||
          (provider.serviceType.isNotEmpty &&
              provider.serviceType.toLowerCase() ==
                  _selectedServiceType.toLowerCase());
      final availabilityMatches =
          !_availableNowOnly || ProviderBookingEligibility.canBook(provider);
      final ratingMatches = provider.overallRating >= _minRating;
      final distanceMatches =
          _maxDistanceKm == null ||
          (_distanceFor(provider) <= (_maxDistanceKm! * 1000));
      final priceMatches =
          _maxPrice == null ||
          (provider.consultationFee != null &&
              provider.consultationFee! <= _maxPrice!);

      return searchMatches &&
          roleMatches &&
          specializationMatches &&
          serviceTypeMatches &&
          availabilityMatches &&
          ratingMatches &&
          distanceMatches &&
          priceMatches;
    }).toList();

    if (_sortOption == ProviderSortOption.smartMatch) {
      if (_backendRecommendations.isNotEmpty) {
        list.sort((a, b) {
          final bs = _backendRecommendations[b.userId]?['finalScore'];
          final aRawScore = _backendRecommendations[a.userId]?['finalScore'];
          final bScore = bs is num ? bs.toDouble() : 0.0;
          final aScore = aRawScore is num ? aRawScore.toDouble() : 0.0;
          return bScore.compareTo(aScore);
        });
      } else {
        list = ProviderSmartMatch.sortCopy(
          list,
          selectedSpecialty: _selectedSpecialization == 'all'
              ? 'All'
              : _selectedSpecialization,
          locationService: _locationService,
          patientLat: _patientLat,
          patientLng: _patientLng,
          careSummary: _careSummary,
        );
      }
    } else {
      list.sort((a, b) {
        switch (_sortOption) {
          case ProviderSortOption.smartMatch:
            return a.fullName.toLowerCase().compareTo(b.fullName.toLowerCase());
          case ProviderSortOption.nearest:
            return _distanceFor(a).compareTo(_distanceFor(b));
          case ProviderSortOption.ratingHighToLow:
            return b.overallRating.compareTo(a.overallRating);
          case ProviderSortOption.availableNow:
            final aBookable = ProviderBookingEligibility.canBook(a);
            final bBookable = ProviderBookingEligibility.canBook(b);
            if (aBookable == bBookable) {
              return b.overallRating.compareTo(a.overallRating);
            }
            return aBookable ? -1 : 1;
          case ProviderSortOption.priceLowToHigh:
            final aFee = a.consultationFee ?? 999999;
            final bFee = b.consultationFee ?? 999999;
            return aFee.compareTo(bFee);
        }
      });
    }

    if (mounted) {
      setState(() => _visibleProviders = list);
    }
  }

  List<String> get _specializations {
    final values =
        _providers
            .map((e) => e.specialization.trim())
            .where((e) => e.isNotEmpty)
            .toSet()
            .toList()
          ..sort();
    return values;
  }

  List<String> get _serviceTypes {
    final values =
        _providers
            .map((e) => e.serviceType.trim())
            .where((e) => e.isNotEmpty)
            .toSet()
            .toList()
          ..sort();
    return values;
  }

  String _sortLabel(ProviderSortOption option) {
    switch (option) {
      case ProviderSortOption.smartMatch:
        return context.tr('providers.smartMatch');
      case ProviderSortOption.nearest:
        return context.tr('providers.nearest');
      case ProviderSortOption.ratingHighToLow:
        return context.tr('providers.topRated');
      case ProviderSortOption.availableNow:
        return context.tr('providers.availableNow');
      case ProviderSortOption.priceLowToHigh:
        return context.tr('providers.lowestPrice');
    }
  }

  String _copy(String english, String arabic) =>
      context.l10n.isArabic ? arabic : english;

  Future<void> _openFilters() async {
    String tempRole = _selectedRole;
    String tempSpecialization = _selectedSpecialization;
    String tempServiceType = _selectedServiceType;
    bool tempAvailable = _availableNowOnly;
    double tempMinRating = _minRating;
    double? tempMaxDistance = _maxDistanceKm;
    double? tempMaxPrice = _maxPrice;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        final p = CarelinkPalette.of(context);
        return Directionality(
          textDirection: context.l10n.isArabic
              ? TextDirection.rtl
              : TextDirection.ltr,
          child: StatefulBuilder(
            builder: (context, setSheetState) => FractionallySizedBox(
              heightFactor: 0.92,
              child: Container(
                decoration: BoxDecoration(
                  color: p.surface,
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(32),
                  ),
                ),
                child: Column(
                  children: [
                    const SizedBox(height: 10),
                    Container(
                      width: 46,
                      height: 5,
                      decoration: BoxDecoration(
                        color: p.stroke,
                        borderRadius: BorderRadius.circular(99),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              _copy(
                                'Filter care providers',
                                'تصفية مقدمي الرعاية',
                              ),
                              style: TextStyle(
                                color: p.inkDark,
                                fontSize: 21,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                          IconButton(
                            onPressed: () => Navigator.pop(context),
                            icon: const Icon(Icons.close_rounded),
                            color: p.inkMuted,
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            _filterSectionTitle(
                              p,
                              Icons.medical_services_outlined,
                              _copy('Provider type', 'نوع مقدم الرعاية'),
                            ),
                            const SizedBox(height: 8),
                            _dropdownField(
                              p: p,
                              label: _copy('Select type', 'اختر النوع'),
                              value: tempRole,
                              items: const ['all', 'doctor', 'nurse'],
                              onChanged: (value) =>
                                  setSheetState(() => tempRole = value),
                            ),
                            const SizedBox(height: 18),
                            _filterSectionTitle(
                              p,
                              Icons.health_and_safety_outlined,
                              _copy('Specialty', 'التخصص'),
                            ),
                            const SizedBox(height: 8),
                            _dropdownField(
                              p: p,
                              label: _copy('Select specialty', 'اختر التخصص'),
                              value: tempSpecialization,
                              items: ['all', ..._specializations],
                              onChanged: (value) => setSheetState(
                                () => tempSpecialization = value,
                              ),
                            ),
                            const SizedBox(height: 18),
                            _filterSectionTitle(
                              p,
                              Icons.volunteer_activism_outlined,
                              _copy('Service', 'الخدمة'),
                            ),
                            const SizedBox(height: 8),
                            _dropdownField(
                              p: p,
                              label: _copy('Select service', 'اختر الخدمة'),
                              value: tempServiceType,
                              items: ['all', ..._serviceTypes],
                              onChanged: (value) =>
                                  setSheetState(() => tempServiceType = value),
                            ),
                            const SizedBox(height: 16),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: p.filterSurface,
                                borderRadius: BorderRadius.circular(18),
                                border: Border.all(color: p.stroke),
                              ),
                              child: SwitchListTile.adaptive(
                                contentPadding: EdgeInsets.zero,
                                value: tempAvailable,
                                onChanged: (value) =>
                                    setSheetState(() => tempAvailable = value),
                                title: Text(
                                  _copy(
                                    'Available now only',
                                    'المتاحون الآن فقط',
                                  ),
                                  style: TextStyle(
                                    color: p.inkDark,
                                    fontSize: 13.5,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                secondary: const Icon(
                                  Icons.bolt_rounded,
                                  color: AppColors.primary,
                                ),
                                activeTrackColor: AppColors.primary,
                              ),
                            ),
                            const SizedBox(height: 18),
                            _filterSectionTitle(
                              p,
                              Icons.star_outline_rounded,
                              _copy('Minimum rating', 'الحد الأدنى للتقييم'),
                              trailing: tempMinRating.toStringAsFixed(1),
                            ),
                            SliderTheme(
                              data: SliderThemeData(
                                activeTrackColor: AppColors.primary,
                                inactiveTrackColor: p.stroke,
                                thumbColor: AppColors.primary,
                                overlayColor: AppColors.primary.withValues(
                                  alpha: 0.14,
                                ),
                                trackHeight: 4,
                              ),
                              child: Slider(
                                value: tempMinRating,
                                min: 0,
                                max: 5,
                                divisions: 10,
                                label: tempMinRating.toStringAsFixed(1),
                                onChanged: (value) =>
                                    setSheetState(() => tempMinRating = value),
                              ),
                            ),
                            const SizedBox(height: 10),
                            _filterSectionTitle(
                              p,
                              Icons.location_on_outlined,
                              _copy('Maximum distance', 'أقصى مسافة'),
                            ),
                            const SizedBox(height: 8),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [null, 2.0, 5.0, 10.0].map((km) {
                                return _filterChoiceChip(
                                  p: p,
                                  label: km == null
                                      ? _copy('All', 'الكل')
                                      : '${km.toInt()} ${_copy('km', 'كم')}',
                                  selected: tempMaxDistance == km,
                                  onSelected: () =>
                                      setSheetState(() => tempMaxDistance = km),
                                );
                              }).toList(),
                            ),
                            const SizedBox(height: 18),
                            _filterSectionTitle(
                              p,
                              Icons.payments_outlined,
                              _copy('Budget', 'الميزانية'),
                            ),
                            const SizedBox(height: 8),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [null, 50.0, 100.0, 150.0].map((price) {
                                return _filterChoiceChip(
                                  p: p,
                                  label: price == null
                                      ? _copy('All', 'الكل')
                                      : '${price.toInt()} ILS',
                                  selected: tempMaxPrice == price,
                                  onSelected: () =>
                                      setSheetState(() => tempMaxPrice = price),
                                );
                              }).toList(),
                            ),
                          ],
                        ),
                      ),
                    ),
                    Container(
                      padding: EdgeInsets.fromLTRB(
                        20,
                        12,
                        20,
                        12 + MediaQuery.paddingOf(context).bottom,
                      ),
                      decoration: BoxDecoration(
                        color: p.surface,
                        border: Border(top: BorderSide(color: p.stroke)),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () {
                                setState(() {
                                  _selectedRole = 'all';
                                  _selectedSpecialization = 'all';
                                  _selectedServiceType = 'all';
                                  _availableNowOnly = false;
                                  _minRating = 0;
                                  _maxDistanceKm = null;
                                  _maxPrice = null;
                                });
                                _applyFiltersAndSort();
                                Navigator.pop(context);
                              },
                              icon: const Icon(Icons.refresh_rounded, size: 18),
                              label: Text(_copy('Reset', 'إعادة ضبط')),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: AppColors.primary,
                                minimumSize: const Size.fromHeight(52),
                                side: const BorderSide(
                                  color: AppColors.primary,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            flex: 2,
                            child: FilledButton(
                              onPressed: () {
                                setState(() {
                                  _selectedRole = tempRole;
                                  _selectedSpecialization = tempSpecialization;
                                  _selectedServiceType = tempServiceType;
                                  _availableNowOnly = tempAvailable;
                                  _minRating = tempMinRating;
                                  _maxDistanceKm = tempMaxDistance;
                                  _maxPrice = tempMaxPrice;
                                });
                                _applyFiltersAndSort();
                                Navigator.pop(context);
                              },
                              style: FilledButton.styleFrom(
                                backgroundColor: AppColors.primary,
                                foregroundColor: Colors.white,
                                minimumSize: const Size.fromHeight(52),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                              ),
                              child: Text(
                                _copy('Apply filters', 'تطبيق الفلاتر'),
                                style: const TextStyle(
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _filterSectionTitle(
    CarelinkPalette p,
    IconData icon,
    String title, {
    String? trailing,
  }) {
    return Row(
      children: [
        Icon(icon, color: AppColors.primary, size: 20),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            title,
            style: TextStyle(
              color: p.inkDark,
              fontSize: 14,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        if (trailing != null)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.09),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              trailing,
              style: const TextStyle(
                color: AppColors.primary,
                fontSize: 12,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
      ],
    );
  }

  Widget _filterChoiceChip({
    required CarelinkPalette p,
    required String label,
    required bool selected,
    required VoidCallback onSelected,
  }) {
    return ChoiceChip(
      label: Text(
        label,
        style: TextStyle(
          color: selected ? Colors.white : p.inkDark,
          fontWeight: FontWeight.w600,
          fontSize: 11.5,
        ),
      ),
      selected: selected,
      onSelected: (_) => onSelected(),
      selectedColor: AppColors.primary,
      backgroundColor: p.filterSurface,
      checkmarkColor: Colors.white,
      side: BorderSide(color: selected ? AppColors.primary : p.stroke),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      showCheckmark: selected,
    );
  }

  Widget _dropdownField({
    required CarelinkPalette p,
    required String label,
    required String value,
    required List<String> items,
    required ValueChanged<String> onChanged,
  }) {
    return InputDecorator(
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: p.inkMuted, fontSize: 13),
        filled: true,
        fillColor: p.filterSurface,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 10,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: p.stroke),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: AppColors.primary, width: 1.2),
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: p.stroke),
        ),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: items.contains(value) ? value : items.first,
          isExpanded: true,
          style: TextStyle(
            color: p.inkDark,
            fontSize: 13,
            fontWeight: FontWeight.w500,
          ),
          dropdownColor: p.surface,
          iconEnabledColor: p.inkMuted,
          items: items
              .map(
                (e) => DropdownMenuItem(
                  value: e,
                  child: Text(
                    e == 'all'
                        ? _copy('All', 'الكل')
                        : e == 'doctor'
                        ? _copy('Doctor', 'طبيب')
                        : e == 'nurse'
                        ? _copy('Nurse', 'ممرض')
                        : e,
                    style: TextStyle(color: p.inkDark),
                  ),
                ),
              )
              .toList(),
          onChanged: (v) {
            if (v != null) onChanged(v);
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = CarelinkPalette.of(context);
    return CarelinkResponsiveScope(
      child: Scaffold(
        backgroundColor: p.isDark ? p.pageBg : const Color(0xFFF8FAFA),
        appBar: PatientAppBar(
          titleWidget: Text(
            _copy('Find Providers', 'البحث عن مزودين'),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Color(0xFF0F766E),
              fontSize: 24,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.4,
            ),
          ),
        ),
        body: SafeArea(
          child: RefreshIndicator(
            onRefresh: _fetchProviders,
            color: AppColors.primary,
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: EdgeInsets.fromLTRB(
                CarelinkResponsiveScope.horizontalPadding(context),
                8,
                CarelinkResponsiveScope.horizontalPadding(context),
                128 + MediaQuery.paddingOf(context).bottom,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(child: _buildSearchField(p)),
                      const SizedBox(width: 8),
                      _filterButton(p),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _sortRow(p),
                  const SizedBox(height: 16),
                  _statusRow(p),
                  const SizedBox(height: 16),
                  _buildBody(p),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSearchField(CarelinkPalette p) {
    final border = OutlineInputBorder(
      borderRadius: BorderRadius.circular(18),
      borderSide: BorderSide(color: p.stroke.withValues(alpha: 0.85)),
    );
    return SizedBox(
      height: 52,
      child: TextField(
        controller: _searchController,
        onChanged: (v) {
          _searchQuery = v;
          _applyFiltersAndSort();
        },
        style: TextStyle(
          color: p.inkDark,
          fontSize: 13.5,
          fontWeight: FontWeight.w600,
        ),
        cursorColor: AppColors.primary,
        decoration: InputDecoration(
          hintText: context.tr('providers.searchHint'),
          hintStyle: TextStyle(
            color: p.inkMuted,
            fontSize: 12.5,
            fontWeight: FontWeight.w500,
          ),
          prefixIcon: const Icon(
            Icons.search_rounded,
            color: AppColors.primary,
            size: 21,
          ),
          filled: true,
          fillColor: p.surface,
          isDense: true,
          border: border,
          enabledBorder: border,
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(18),
            borderSide: const BorderSide(color: AppColors.primary, width: 1.2),
          ),
          contentPadding: const EdgeInsets.symmetric(vertical: 12),
        ),
      ),
    );
  }

  Widget _filterButton(CarelinkPalette p) {
    return PatientPressable(
      onTap: _openFilters,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          color: AppColors.primary,
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: AppColors.primary.withValues(alpha: 0.22),
              blurRadius: 18,
              offset: const Offset(0, 7),
            ),
          ],
        ),
        child: const Icon(Icons.tune_rounded, color: Colors.white, size: 23),
      ),
    );
  }

  Widget _sortRow(CarelinkPalette p) {
    return SizedBox(
      height: 36,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: ProviderSortOption.values.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final option = ProviderSortOption.values[index];
          final selected = _sortOption == option;
          return ChoiceChip(
            showCheckmark: false,
            visualDensity: VisualDensity.compact,
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
            labelPadding: EdgeInsets.zero,
            label: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  _sortIcon(option),
                  size: 14,
                  color: selected ? Colors.white : AppColors.primary,
                ),
                const SizedBox(width: 5),
                Text(
                  _sortLabel(option),
                  style: TextStyle(
                    color: selected ? Colors.white : p.inkDark,
                    fontWeight: FontWeight.w700,
                    fontSize: 11.5,
                  ),
                ),
              ],
            ),
            selected: selected,
            selectedColor: AppColors.primary,
            backgroundColor: p.surface,
            side: BorderSide(color: selected ? AppColors.primary : p.stroke),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(999),
            ),
            onSelected: (_) {
              setState(() => _sortOption = option);
              _applyFiltersAndSort();
            },
          );
        },
      ),
    );
  }

  Widget _statusRow(CarelinkPalette p) {
    return Row(
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(14),
          ),
          child: const Icon(
            Icons.medical_services_outlined,
            color: AppColors.primary,
            size: 21,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _copy(
                  '${_visibleProviders.length} care providers available',
                  '${_visibleProviders.length} مقدم رعاية متاح',
                ),
                style: TextStyle(
                  fontSize: 14,
                  color: p.inkDark,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                _copy(
                  'Choose the right provider for your care needs',
                  'اختر مقدم الرعاية الأنسب لاحتياجاتك',
                ),
                style: TextStyle(
                  fontSize: 11.5,
                  color: p.inkMuted,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  IconData _sortIcon(ProviderSortOption option) {
    return switch (option) {
      ProviderSortOption.smartMatch => Icons.auto_awesome_rounded,
      ProviderSortOption.nearest => Icons.near_me_outlined,
      ProviderSortOption.ratingHighToLow => Icons.star_rounded,
      ProviderSortOption.availableNow => Icons.bolt_rounded,
      ProviderSortOption.priceLowToHigh => Icons.payments_outlined,
    };
  }

  void _resetFilters() {
    setState(() {
      _searchController.clear();
      _searchQuery = '';
      _selectedRole = 'all';
      _selectedSpecialization = 'all';
      _selectedServiceType = 'all';
      _availableNowOnly = false;
      _minRating = 0;
      _maxDistanceKm = null;
      _maxPrice = null;
      _sortOption = ProviderSortOption.smartMatch;
    });
    _applyFiltersAndSort();
  }

  Widget _buildBody(CarelinkPalette p) {
    if (_isLoading) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: 30),
          child: CircularProgressIndicator(color: AppColors.primary),
        ),
      );
    }

    if (_errorMessage != null) {
      return _errorCard(p, _errorMessage!);
    }

    if (_visibleProviders.isEmpty) {
      return _emptyProvidersState(p);
    }

    return Column(
      children: List.generate(_visibleProviders.length, (index) {
        final provider = _visibleProviders[index];
        return TweenAnimationBuilder<double>(
          key: ValueKey(provider.userId),
          duration: Duration(milliseconds: 220 + (index.clamp(0, 4) * 25)),
          curve: Curves.easeOutCubic,
          tween: Tween(begin: 0, end: 1),
          builder: (context, value, child) => Opacity(
            opacity: value,
            child: Transform.translate(
              offset: Offset(0, 14 * (1 - value)),
              child: child,
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _providerCard(
              p,
              provider,
              highlighted:
                  index == 0 && _sortOption == ProviderSortOption.smartMatch,
            ),
          ),
        );
      }),
    );
  }

  Widget _providerCard(
    CarelinkPalette p,
    ProviderModel provider, {
    required bool highlighted,
  }) {
    final isDoctor = provider.role.toLowerCase() == 'doctor';
    final matchPercentage = _matchPercentageFor(provider);

    final available = ProviderBookingEligibility.canBook(provider);
    final distanceKm = _distanceFor(provider) / 1000;
    final specialty = provider.serviceType.trim().isNotEmpty
        ? provider.serviceType.trim()
        : provider.specialization.trim().isNotEmpty
        ? provider.specialization.trim()
        : context.tr(isDoctor ? 'providers.doctor' : 'providers.nurse');
    final favorite = _favoriteIds.contains(provider.userId);

    return PatientPressable(
      onTap: () => _openProvider(provider),
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: p.isDark ? p.surface : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: highlighted
                ? AppColors.primary.withValues(alpha: 0.4)
                : p.stroke.withValues(alpha: 0.5),
            width: highlighted ? 1.2 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: p.cardShadowColor(0.04),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _compactProviderAvatar(p, provider, isDoctor, size: 60),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              provider.fullName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w800,
                                color: p.inkDark,
                              ),
                            ),
                          ),
                          const SizedBox(width: 4),
                          Icon(
                            favorite
                                ? Icons.favorite_rounded
                                : Icons.favorite_border_rounded,
                            color: favorite
                                ? const Color(0xFFE85D75)
                                : p.inkMuted,
                            size: 20,
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        specialty,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: p.inkMuted,
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Wrap(
                        crossAxisAlignment: WrapCrossAlignment.center,
                        spacing: 8,
                        runSpacing: 4,
                        children: [
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.star_rounded,
                                color: Color(0xFFFFB020),
                                size: 14,
                              ),
                              const SizedBox(width: 3),
                              Text(
                                provider.overallRating.toStringAsFixed(1),
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: p.inkDark,
                                ),
                              ),
                            ],
                          ),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.location_on_outlined,
                                color: Color(0xFF64748B),
                                size: 13,
                              ),
                              const SizedBox(width: 2),
                              Text(
                                '${distanceKm.toStringAsFixed(1)} ${_copy('km', 'كم')}',
                                style: TextStyle(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w600,
                                  color: p.inkMuted,
                                ),
                              ),
                            ],
                          ),
                          if (matchPercentage != null && matchPercentage >= 80)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 5,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.primary.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(
                                    Icons.auto_awesome_rounded,
                                    color: AppColors.primary,
                                    size: 10,
                                  ),
                                  const SizedBox(width: 3),
                                  Text(
                                    _copy('AI Match', 'تطابق'),
                                    style: const TextStyle(
                                      color: AppColors.primary,
                                      fontSize: 10,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          _providerPill(
                            icon: Icons.circle,
                            label: available
                                ? _copy('Available', 'متاح')
                                : _copy('Unavailable', 'غير متاح'),
                            color: available
                                ? const Color(0xFF16A34A)
                                : p.inkMuted,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        provider.consultationFee == null
                            ? _copy('TBD', 'يُحدد لاحقاً')
                            : '${provider.consultationFee!.toStringAsFixed(0)} ILS',
                        style: const TextStyle(
                          color: AppColors.primary,
                          fontSize: 15,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      if (provider.consultationFee != null)
                        Text(
                          _copy('per visit', 'للزيارة'),
                          style: TextStyle(
                            color: p.inkMuted,
                            fontSize: 10.5,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                    ],
                  ),
                ),
                SizedBox(
                  height: 38,
                  child: FilledButton(
                    onPressed: () => _openProvider(provider),
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text(
                      _copy('View details', 'عرض التفاصيل'),
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _providerPill({
    required IconData icon,
    required String label,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(99),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: icon == Icons.circle ? 7 : 13),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 10.5,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }

  Widget _emptyProvidersState(CarelinkPalette p) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 36),
      decoration: BoxDecoration(
        color: p.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: p.stroke.withValues(alpha: 0.65)),
      ),
      child: Column(
        children: [
          Container(
            width: 88,
            height: 88,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.08),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.person_search_rounded,
              size: 44,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            _copy('No care provider found', 'لم يتم العثور على مقدم رعاية'),
            textAlign: TextAlign.center,
            style: TextStyle(
              color: p.inkDark,
              fontSize: 16,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            _copy(
              'Try changing the filters or searching with another name.',
              'جرّب تغيير الفلاتر أو البحث باسم آخر.',
            ),
            textAlign: TextAlign.center,
            style: TextStyle(color: p.inkMuted, fontSize: 12.5, height: 1.4),
          ),
          const SizedBox(height: 18),
          OutlinedButton.icon(
            onPressed: _resetFilters,
            icon: const Icon(Icons.refresh_rounded, size: 18),
            label: Text(_copy('Reset filters', 'إعادة ضبط الفلاتر')),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.primary,
              side: const BorderSide(color: AppColors.primary),
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _compactProviderAvatar(
    CarelinkPalette p,
    ProviderModel provider,
    bool isDoctor, {
    double size = 80,
  }) {
    return Hero(
      tag: 'provider-avatar-${provider.userId}',
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: AppColors.primary.withValues(alpha: p.isDark ? 0.22 : 0.10),
          shape: BoxShape.circle,
          border: Border.all(
            color: AppColors.primary.withValues(alpha: 0.22),
            width: 1.25,
          ),
        ),
        child: ClipOval(
          child: profileAvatarOrPlaceholder(
            imageUrl: provider.profileImageUrl,
            size: size,
            placeholderColor: AppColors.primary,
            placeholderIcon: isDoctor
                ? Icons.medical_services_outlined
                : Icons.local_hospital_outlined,
            iconSize: size * 0.4,
          ),
        ),
      ),
    );
  }

  void _openProvider(ProviderModel provider) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ProviderDetailsScreen(
          provider: provider,
          patientUserId: widget.userId,
          distanceKm: _distanceFor(provider) / 1000.0,
          recommendation: _backendRecommendations[provider.userId],
        ),
      ),
    );
  }

  int? _matchPercentageFor(ProviderModel provider) {
    final recommendation = _backendRecommendations[provider.userId];
    final rawMatch = recommendation?['matchPercentage'];
    if (rawMatch is num) return rawMatch.round().clamp(0, 99);
    final rawMedical = recommendation?['medicalMatchScore'];
    if (rawMedical is num) {
      return (rawMedical.toDouble() * 100).round().clamp(0, 99);
    }
    return null;
  }

  Widget _errorCard(CarelinkPalette p, String text) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: p.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: p.stroke),
      ),
      child: Column(
        children: [
          Icon(Icons.search_off_rounded, size: 34, color: p.inkMuted),
          const SizedBox(height: 8),
          Text(
            text,
            textAlign: TextAlign.center,
            style: TextStyle(color: p.inkDark),
          ),
          if (_errorMessage != null) ...[
            const SizedBox(height: 10),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
              ),
              onPressed: _fetchProviders,
              child: Text(_copy('Try Again', 'حاول مرة أخرى')),
            ),
          ],
        ],
      ),
    );
  }
}
