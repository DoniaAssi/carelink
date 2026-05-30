import 'package:flutter/material.dart';

import 'package:carelink/core/app_colors.dart';
import 'package:carelink/core/app_localizations.dart';
import 'package:carelink/core/carelink_palette.dart';
import 'package:carelink/core/locale_controller.dart';
import 'package:carelink/shared/models/provider_model.dart';
import 'package:carelink/shared/widgets/carelink_brand_logo.dart';
import 'package:carelink/features/patient/widgets/carelink_patient_app_bar.dart';
import 'package:carelink/shared/services/api_service.dart';
import 'package:carelink/shared/services/location_service.dart';
import 'package:carelink/shared/services/medical_record_service.dart';
import 'package:carelink/features/patient/services/patient_care_summary.dart';
import 'package:carelink/features/ai/provider_smart_match.dart';
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

  bool _isLoading = true;
  String? _errorMessage;
  double? _patientLat;
  double? _patientLng;
  PatientCareSummary _careSummary = PatientCareSummary.empty;

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
    } catch (_) {
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
      final data = await ApiService().getProviders();
      final fetched = data.map((e) => ProviderModel.fromJson(e)).toList();
      if (!mounted) return;

      _providers = fetched;
      _applyFiltersAndSort();
      setState(() => _isLoading = false);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage =
            CarelinkL10n(localeController.locale).t(
          'patient.providers.loadFailedShort',
        );
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
      final availabilityMatches = !_availableNowOnly || provider.isAvailable;
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
            if (a.isAvailable == b.isAvailable) {
              return b.overallRating.compareTo(a.overallRating);
            }
            return a.isAvailable ? -1 : 1;
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

  String _sortLabel(BuildContext c, ProviderSortOption option) {
    switch (option) {
      case ProviderSortOption.smartMatch:
        return c.tr('patient.sortSmart');
      case ProviderSortOption.nearest:
        return c.tr('patient.sortNearest');
      case ProviderSortOption.ratingHighToLow:
        return c.tr('patient.sortTopRated');
      case ProviderSortOption.availableNow:
        return c.tr('patient.filterAvailableNow');
      case ProviderSortOption.priceLowToHigh:
        return c.tr('patient.sortPriceLow');
    }
  }

  String _dropdownItemLabel(BuildContext c, String e) {
    if (e == 'all') return c.tr('patient.filterAll');
    final low = e.toLowerCase();
    if (low == 'doctor') return c.tr('patient.role.doctor');
    if (low == 'nurse') return c.tr('patient.role.nurse');
    return e;
  }

  Future<void> _openFilters() async {
    String tempRole = _selectedRole;
    String tempSpecialization = _selectedSpecialization;
    String tempServiceType = _selectedServiceType;
    bool tempAvailable = _availableNowOnly;
    double tempMinRating = _minRating;
    double? tempMaxDistance = _maxDistanceKm;
    double? tempMaxPrice = _maxPrice;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: CarelinkPalette.of(context).surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        final p = CarelinkPalette.of(context);
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return SafeArea(
              top: false,
              child: Padding(
                padding: EdgeInsets.fromLTRB(
                  18,
                  18,
                  18,
                  18 + MediaQuery.of(context).viewInsets.bottom,
                ),
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        context.tr('patient.providers.filterTitle'),
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          color: p.inkDark,
                        ),
                      ),
                      const SizedBox(height: 14),
                      _dropdownField(
                        context: context,
                        p: p,
                        label: context.tr('patient.providers.providerType'),
                        value: tempRole,
                        items: const ['all', 'doctor', 'nurse'],
                        onChanged: (v) => setSheetState(() => tempRole = v),
                      ),
                      const SizedBox(height: 10),
                      _dropdownField(
                        context: context,
                        p: p,
                        label: context.tr('patient.providers.specializationLabel'),
                        value: tempSpecialization,
                        items: ['all', ..._specializations],
                        onChanged: (v) =>
                            setSheetState(() => tempSpecialization = v),
                      ),
                      const SizedBox(height: 10),
                      _dropdownField(
                        context: context,
                        p: p,
                        label: context.tr('patient.providers.serviceTypeLabel'),
                        value: tempServiceType,
                        items: ['all', ..._serviceTypes],
                        onChanged: (v) =>
                            setSheetState(() => tempServiceType = v),
                      ),
                      const SizedBox(height: 10),
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        value: tempAvailable,
                        onChanged: (v) =>
                            setSheetState(() => tempAvailable = v),
                        title: Text(
                          context.tr('patient.providers.availableNowSwitch'),
                          style: TextStyle(
                            color: p.inkDark,
                            fontWeight: FontWeight.w500,
                            fontSize: 15,
                          ),
                        ),
                        activeTrackColor: AppColors.primary,
                        activeThumbColor: Colors.white,
                        inactiveTrackColor: p.stroke,
                        inactiveThumbColor: p.inkMuted,
                      ),
                      const SizedBox(height: 6),
                      Text(
                        context.tr(
                          'patient.providers.minRating',
                          args: {
                            'value': tempMinRating.toStringAsFixed(1),
                          },
                        ),
                        style: TextStyle(
                          color: p.inkDark,
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
                      SliderTheme(
                        data: SliderThemeData(
                          activeTrackColor: AppColors.primary,
                          inactiveTrackColor: p.stroke,
                          thumbColor: AppColors.primary,
                          overlayColor: AppColors.primary.withValues(
                            alpha: 0.18,
                          ),
                        ),
                        child: Slider(
                          value: tempMinRating,
                          min: 0,
                          max: 5,
                          divisions: 10,
                          label: tempMinRating.toStringAsFixed(1),
                          onChanged: (v) =>
                              setSheetState(() => tempMinRating = v),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        context.tr('patient.providers.maxDistance'),
                        style: TextStyle(
                          color: p.inkDark,
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Wrap(
                        spacing: 8,
                        runSpacing: 6,
                        children: [null, 2.0, 5.0, 10.0].map((km) {
                          final selected = tempMaxDistance == km;
                          final label = km == null
                              ? context.tr('patient.providers.pickAnyOption')
                              : context.tr(
                                  'patient.providers.kmOnly',
                                  args: {'n': '${km.toInt()}'},
                                );
                          return _filterChoiceChip(
                            p: p,
                            label: label,
                            selected: selected,
                            onSelected: () =>
                                setSheetState(() => tempMaxDistance = km),
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        context.tr('patient.providers.maxPrice'),
                        style: TextStyle(
                          color: p.inkDark,
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Wrap(
                        spacing: 8,
                        runSpacing: 6,
                        children: [null, 50.0, 100.0, 150.0].map((price) {
                          final selected = tempMaxPrice == price;
                          final label = price == null
                              ? context.tr('patient.providers.pickAnyOption')
                              : '\$${price.toInt()}';
                          return _filterChoiceChip(
                            p: p,
                            label: label,
                            selected: selected,
                            onSelected: () =>
                                setSheetState(() => tempMaxPrice = price),
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              style: OutlinedButton.styleFrom(
                                foregroundColor: AppColors.primary,
                                side: BorderSide(color: p.stroke),
                                padding: const EdgeInsets.symmetric(
                                  vertical: 14,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
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
                              child: Text(context.tr('patient.action.reset')),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.primary,
                                foregroundColor: Colors.white,
                                elevation: 0,
                                padding: const EdgeInsets.symmetric(
                                  vertical: 14,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
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
                              child: Text(context.tr('patient.action.apply')),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
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
          fontSize: 12.5,
        ),
      ),
      selected: selected,
      onSelected: (_) => onSelected(),
      selectedColor: AppColors.primary,
      backgroundColor: p.filterSurface,
      checkmarkColor: Colors.white,
      side: BorderSide(color: selected ? AppColors.primary : p.stroke),
    );
  }

  Widget _dropdownField({
    required BuildContext context,
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
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: p.stroke),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.primary, width: 1.2),
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: p.stroke),
        ),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: items.contains(value) ? value : items.first,
          isExpanded: true,
          style: TextStyle(
            color: p.inkDark,
            fontSize: 15,
            fontWeight: FontWeight.w500,
          ),
          dropdownColor: p.surface,
          iconEnabledColor: p.inkMuted,
          items: items
              .map(
                (e) => DropdownMenuItem(
                  value: e,
                  child: Text(
                    _dropdownItemLabel(context, e),
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
    return Scaffold(
      backgroundColor: p.pageBg,
      appBar: carelinkPatientAppBar(
        context,
        title: CarelinkAppBarTitle.forPatient(
            context,
            context.tr('patient.title.findProviders'),
          ),
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _fetchProviders,
          color: AppColors.primary,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(18, 10, 18, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(child: _buildSearchField(p)),
                    const SizedBox(width: 10),
                    _filterButton(p),
                  ],
                ),
                const SizedBox(height: 14),
                _sortRow(context, p),
                const SizedBox(height: 12),
                _statusRow(context, p),
                const SizedBox(height: 16),
                _buildBody(p),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSearchField(CarelinkPalette p) {
    return Container(
      decoration: BoxDecoration(
        color: p.filterSurface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: p.stroke),
      ),
      child: TextField(
        controller: _searchController,
        onChanged: (v) {
          _searchQuery = v;
          _applyFiltersAndSort();
        },
        style: TextStyle(color: p.inkDark, fontSize: 14),
        cursorColor: AppColors.primary,
        decoration: InputDecoration(
          hintText: context.tr('patient.providers.searchHint'),
          hintStyle: TextStyle(
            color: p.inkMuted,
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
          prefixIcon: Icon(Icons.search_rounded, color: p.inkMuted, size: 24),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 14,
            vertical: 13,
          ),
        ),
      ),
    );
  }

  Widget _filterButton(CarelinkPalette p) {
    return InkWell(
      onTap: _openFilters,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        width: 50,
        height: 50,
        decoration: BoxDecoration(
          color: AppColors.primary.withValues(alpha: p.isDark ? 0.2 : 0.12),
          border: Border.all(color: p.stroke),
          borderRadius: BorderRadius.circular(14),
        ),
        child: const Icon(Icons.tune_rounded, color: AppColors.primary),
      ),
    );
  }

  Widget _sortRow(BuildContext context, CarelinkPalette p) {
    return Wrap(
      spacing: 8,
      runSpacing: 6,
      children: ProviderSortOption.values.map((option) {
        final selected = _sortOption == option;
        return ChoiceChip(
          label: Text(
            _sortLabel(context, option),
            style: TextStyle(
              color: selected ? Colors.white : p.inkDark,
              fontWeight: FontWeight.w600,
              fontSize: 12.5,
            ),
          ),
          selected: selected,
          selectedColor: AppColors.primary,
          backgroundColor: p.filterSurface,
          checkmarkColor: Colors.white,
          side: BorderSide(color: selected ? AppColors.primary : p.stroke),
          onSelected: (_) {
            setState(() => _sortOption = option);
            _applyFiltersAndSort();
          },
        );
      }).toList(),
    );
  }

  Widget _statusRow(BuildContext context, CarelinkPalette p) {
    return Text(
      context.tr(
        'patient.providers.resultsLine',
        args: {'n': '${_visibleProviders.length}'},
      ),
      style: TextStyle(
        fontSize: 13,
        color: p.inkMuted,
        fontWeight: FontWeight.w600,
      ),
    );
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
      return _errorCard(
        p,
        context.tr('patient.providers.noMatchFilters'),
      );
    }

    final bestRated = _visibleProviders.reduce(
      (a, b) => a.overallRating >= b.overallRating ? a : b,
    );
    final nearest = _visibleProviders.reduce(
      (a, b) => _distanceFor(a) <= _distanceFor(b) ? a : b,
    );
    final availableNow = _visibleProviders.where((p) => p.isAvailable).length;

    return Column(
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: p.surfaceSoft,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: p.stroke),
            boxShadow: [
              BoxShadow(
                color: p.cardShadowColor(0.04),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _infoChip(
                p,
                context.tr(
                  'patient.providers.closestChip',
                  args: {'name': nearest.fullName.split(' ').first},
                ),
              ),
              _infoChip(
                p,
                context.tr(
                  'patient.providers.topRatedChip',
                  args: {
                    'rating': bestRated.overallRating.toStringAsFixed(1),
                  },
                ),
              ),
              _infoChip(
                p,
                context.tr(
                  'patient.providers.availableNowChip',
                  args: {'count': '$availableNow'},
                ),
              ),
            ],
          ),
        ),
        ..._visibleProviders.map((e) => _providerCard(p, e)),
      ],
    );
  }

  Widget _infoChip(CarelinkPalette p, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: p.filterSurface,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: p.stroke),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: p.inkDark,
        ),
      ),
    );
  }

  Widget _providerCard(CarelinkPalette p, ProviderModel provider) {
    final isDoctor = provider.role.toLowerCase() == 'doctor';
    final distance = _distanceFor(provider);
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ProviderDetailsScreen(
              provider: provider,
              patientUserId: widget.userId,
              distanceKm: _distanceFor(provider) / 1000.0,
            ),
          ),
        );
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: p.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: p.stroke),
          boxShadow: [
            BoxShadow(
              color: p.cardShadowColor(0.06),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 62,
              height: 62,
              decoration: BoxDecoration(
                color: p.isDark
                    ? AppColors.primary.withValues(alpha: 0.2)
                    : AppColors.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Icon(
                isDoctor
                    ? Icons.medical_services_rounded
                    : Icons.local_hospital_rounded,
                color: AppColors.primary,
                size: 30,
              ),
            ),
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
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: p.inkDark,
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: provider.isAvailable
                              ? AppColors.primary.withValues(
                                  alpha: p.isDark ? 0.28 : 0.18,
                                )
                              : p.inkMuted.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          provider.isAvailable
                              ? context.tr('patient.availability.available')
                              : context.tr('patient.availability.busy'),
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: provider.isAvailable
                                ? p.isDark
                                      ? Colors.white
                                      : AppColors.primaryDark
                                : p.inkMuted,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    provider.specialization.isEmpty
                        ? (isDoctor
                              ? context.tr('patient.role.doctor')
                              : context.tr('patient.role.nurse'))
                        : provider.specialization,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: p.inkMuted, fontSize: 12.5),
                  ),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    children: [
                      _metric(
                        p,
                        Icons.star_rounded,
                        provider.overallRating.toStringAsFixed(1),
                      ),
                      _metric(
                        p,
                        Icons.location_on_rounded,
                        context.tr(
                          'patient.distanceMeters',
                          args: {'m': '$distance'},
                        ),
                      ),
                      if (provider.consultationFee != null)
                        _metric(
                          p,
                          Icons.payments_outlined,
                          '\$${provider.consultationFee!.toStringAsFixed(0)}',
                        ),
                      if (provider.serviceType.trim().isNotEmpty)
                        _metric(
                          p,
                          Icons.medical_information_outlined,
                          provider.serviceType,
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _metric(CarelinkPalette p, IconData icon, String value) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 15, color: AppColors.primary),
        const SizedBox(width: 2),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 200),
          child: Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 12,
              color: p.inkMuted,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
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
              child: Text(context.tr('patient.action.tryAgain')),
            ),
          ],
        ],
      ),
    );
  }
}
