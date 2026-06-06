import 'package:flutter/material.dart';

import 'package:carelink/core/app_colors.dart';
import 'package:carelink/core/app_localizations.dart';
import 'package:carelink/core/carelink_palette.dart';
import 'package:carelink/shared/models/booking_request_model.dart';
import 'package:carelink/shared/models/provider_model.dart';
import 'package:carelink/shared/services/api_service.dart';
import 'package:carelink/shared/services/location_service.dart';
import 'package:carelink/shared/services/medical_record_service.dart';
import 'package:carelink/features/patient/services/patient_care_summary.dart';
import 'package:carelink/features/ai/provider_smart_match.dart';
import 'package:carelink/shared/services/patient_favorites_service.dart';
import 'package:carelink/features/patient/widgets/patient_shared_widgets.dart';
import 'provider_details_screen.dart';
import 'select_service_screen.dart';

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
      List<dynamic> data;
      final backendRecommendations = <String, Map<String, dynamic>>{};
      try {
        final patientId = widget.userId?.trim() ?? '';
        if (patientId.isEmpty) {
          data = await ApiService().getProviders();
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
          data = ranked
              .whereType<Map>()
              .map((item) => item['provider'])
              .whereType<Map>()
              .map((item) => Map<String, dynamic>.from(item))
              .toList();
        }
      } catch (_) {
        data = await ApiService().getProviders();
      }
      final fetched = data.map((e) => ProviderModel.fromJson(e)).toList();
      if (!mounted) return;

      _providers = fetched;
      _backendRecommendations = backendRecommendations;
      _applyFiltersAndSort();
      setState(() => _isLoading = false);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = 'Failed to load providers.';
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
                        _copy('Filter Providers', 'تصفية مقدمي الرعاية'),
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          color: p.inkDark,
                        ),
                      ),
                      const SizedBox(height: 14),
                      _dropdownField(
                        p: p,
                        label: _copy('Provider Type', 'نوع مقدم الرعاية'),
                        value: tempRole,
                        items: const ['all', 'doctor', 'nurse'],
                        onChanged: (v) => setSheetState(() => tempRole = v),
                      ),
                      const SizedBox(height: 10),
                      _dropdownField(
                        p: p,
                        label: _copy('Specialization', 'التخصص'),
                        value: tempSpecialization,
                        items: ['all', ..._specializations],
                        onChanged: (v) =>
                            setSheetState(() => tempSpecialization = v),
                      ),
                      const SizedBox(height: 10),
                      _dropdownField(
                        p: p,
                        label: _copy('Service Type', 'نوع الخدمة'),
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
                          _copy('Available now only', 'المتاحون الآن فقط'),
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
                        '${_copy('Min rating', 'الحد الأدنى للتقييم')}: ${tempMinRating.toStringAsFixed(1)}',
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
                        _copy('Max distance', 'أقصى مسافة'),
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
                              ? _copy('Any', 'الكل')
                              : '${km.toInt()} km';
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
                        _copy('Max price (if available)', 'أقصى سعر (إن توفر)'),
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
                              ? _copy('Any', 'الكل')
                              : '${price.toInt()} ILS';
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
                              child: Text(_copy('Reset', 'إعادة ضبط')),
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
                              child: Text(_copy('Apply', 'تطبيق')),
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
                    e == 'all' ? _copy('All', 'الكل') : e,
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
      appBar: PatientAppBar(title: context.tr('patient.title.findProviders')),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _fetchProviders,
          color: AppColors.primary,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: EdgeInsets.fromLTRB(
              16,
              6,
              16,
              100 + MediaQuery.paddingOf(context).bottom,
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
                const SizedBox(height: 12),
                _sortRow(p),
                const SizedBox(height: 14),
                _statusRow(p),
                const SizedBox(height: 12),
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
        color: p.surface,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: p.stroke.withValues(alpha: 0.8)),
        boxShadow: [
          BoxShadow(
            color: p.cardShadowColor(0.05),
            blurRadius: 14,
            offset: const Offset(0, 5),
          ),
        ],
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
          hintText: context.tr('providers.searchHint'),
          hintStyle: TextStyle(
            color: p.inkMuted,
            fontSize: 13.5,
            fontWeight: FontWeight.w500,
          ),
          prefixIcon: const Icon(
            Icons.search_rounded,
            color: AppColors.primary,
            size: 21,
          ),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 11,
          ),
        ),
      ),
    );
  }

  Widget _filterButton(CarelinkPalette p) {
    return InkWell(
      onTap: _openFilters,
      borderRadius: BorderRadius.circular(15),
      child: Container(
        width: 46,
        height: 46,
        decoration: BoxDecoration(
          color: AppColors.primary,
          borderRadius: BorderRadius.circular(15),
          boxShadow: [
            BoxShadow(
              color: AppColors.primary.withValues(alpha: 0.22),
              blurRadius: 12,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: const Icon(Icons.tune_rounded, color: Colors.white, size: 21),
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
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
            labelPadding: EdgeInsets.zero,
            label: Text(
              _sortLabel(option),
              style: TextStyle(
                color: selected ? Colors.white : p.inkDark,
                fontWeight: FontWeight.w700,
                fontSize: 12,
              ),
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
    return Text(
      context.tr(
        'providers.results',
        args: {'count': '${_visibleProviders.length}'},
      ),
      style: TextStyle(
        fontSize: 12.5,
        color: p.inkMuted,
        fontWeight: FontWeight.w700,
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
      return _errorCard(p, context.tr('providers.noMatch'));
    }

    final bestRated = _visibleProviders.reduce(
      (a, b) => a.overallRating >= b.overallRating ? a : b,
    );
    final nearest = _visibleProviders.reduce(
      (a, b) => _distanceFor(a) <= _distanceFor(b) ? a : b,
    );
    final availableNow = _visibleProviders.where((p) => p.isAvailable).length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              _infoChip(
                p,
                Icons.near_me_outlined,
                '${context.tr('providers.closest')}: ${nearest.fullName.split(' ').first}',
              ),
              const SizedBox(width: 7),
              _infoChip(
                p,
                Icons.star_outline_rounded,
                '${context.tr('providers.topRated')}: ${bestRated.overallRating.toStringAsFixed(1)}',
              ),
              const SizedBox(width: 7),
              _infoChip(
                p,
                Icons.bolt_rounded,
                '${context.tr('providers.availableNow')}: $availableNow',
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        ..._visibleProviders.map((e) => _providerCard(p, e)),
      ],
    );
  }

  Widget _infoChip(CarelinkPalette p, IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: p.surface,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: p.stroke),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: AppColors.primary),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
              color: p.inkDark,
            ),
          ),
        ],
      ),
    );
  }

  Widget _providerCard(CarelinkPalette p, ProviderModel provider) {
    final isDoctor = provider.role.toLowerCase() == 'doctor';
    final distance = _distanceFor(provider);
    final matchPercentage = _matchPercentageFor(provider);
    final reason = _shortReasonFor(provider);
    return InkWell(
      onTap: () => _openProvider(provider),
      borderRadius: BorderRadius.circular(18),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: p.surface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: p.stroke.withValues(alpha: 0.85)),
          boxShadow: [
            BoxShadow(
              color: p.cardShadowColor(0.06),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _providerAvatar(p, provider, isDoctor),
                const SizedBox(width: 11),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Row(
                              children: [
                                Flexible(
                                  child: Text(
                                    provider.fullName,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: 15.5,
                                      fontWeight: FontWeight.w800,
                                      color: p.inkDark,
                                      letterSpacing: -0.15,
                                    ),
                                  ),
                                ),
                                if (_favoriteIds.contains(provider.userId)) ...[
                                  const SizedBox(width: 4),
                                  const Icon(
                                    Icons.favorite_rounded,
                                    color: Color(0xFFFF6B6B),
                                    size: 15,
                                  ),
                                ],
                              ],
                            ),
                          ),
                          if (matchPercentage != null)
                            _matchBadge(p, matchPercentage),
                        ],
                      ),
                      const SizedBox(height: 3),
                      Text(
                        provider.specialization.isEmpty
                            ? context.tr(
                                isDoctor
                                    ? 'providers.doctor'
                                    : 'providers.nurse',
                              )
                            : provider.specialization,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: p.inkMuted,
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 7),
                      Row(
                        children: [
                          _metric(
                            p,
                            Icons.star_rounded,
                            provider.overallRating.toStringAsFixed(1),
                            iconColor: const Color(0xFFFFB020),
                          ),
                          const SizedBox(width: 10),
                          _metric(
                            p,
                            Icons.location_on_outlined,
                            _distanceLabel(distance),
                          ),
                          if (provider.consultationFee != null) ...[
                            const SizedBox(width: 10),
                            _metric(
                              p,
                              Icons.payments_outlined,
                              '${provider.consultationFee!.toStringAsFixed(0)} ILS',
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                _availabilityBadge(p, provider.isAvailable),
                if (reason.isNotEmpty) ...[
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      reason,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textDirection: context.l10n.isArabic
                          ? TextDirection.rtl
                          : TextDirection.ltr,
                      style: TextStyle(
                        color: p.inkMuted,
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 11),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => _openProvider(provider),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.primary,
                      side: BorderSide(
                        color: AppColors.primary.withValues(alpha: 0.45),
                      ),
                      visualDensity: VisualDensity.compact,
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(11),
                      ),
                    ),
                    child: Text(
                      context.tr('providers.viewDetails'),
                      style: const TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: FilledButton(
                    onPressed:
                        (widget.userId?.trim().isNotEmpty ?? false) &&
                            provider.availableSlots.isNotEmpty
                        ? () => _bookProvider(provider)
                        : null,
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      visualDensity: VisualDensity.compact,
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(11),
                      ),
                    ),
                    child: Text(
                      provider.availableSlots.isEmpty
                          ? (context.l10n.isArabic
                                ? 'لا توجد مواعيد'
                                : 'No slots available')
                          : context.tr('providers.book'),
                      style: const TextStyle(
                        fontSize: 12.5,
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

  void _bookProvider(ProviderModel provider) {
    final patientId = widget.userId?.trim() ?? '';
    if (patientId.isEmpty) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => SelectServiceScreen(
          request: BookingRequestModel(
            patientId: patientId,
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
            extraFees: 0,
            paymentMethod: '',
            paymentStatus: '',
            bookingStatus: 'pending',
          ),
        ),
      ),
    );
  }

  Widget _providerAvatar(
    CarelinkPalette p,
    ProviderModel provider,
    bool isDoctor,
  ) {
    final imageUrl = _providerImageUrl(provider.profileImageUrl);
    final fallback = Container(
      color: AppColors.primary.withValues(alpha: p.isDark ? 0.22 : 0.10),
      alignment: Alignment.center,
      child: Icon(
        isDoctor
            ? Icons.medical_services_outlined
            : Icons.local_hospital_outlined,
        color: AppColors.primary,
        size: 24,
      ),
    );

    return Container(
      width: 56,
      height: 56,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: AppColors.primary.withValues(alpha: 0.22),
          width: 1.5,
        ),
      ),
      child: ClipOval(
        child: imageUrl == null
            ? fallback
            : Image.network(
                imageUrl,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => fallback,
              ),
      ),
    );
  }

  String? _providerImageUrl(String? raw) {
    final value = raw?.trim() ?? '';
    if (value.isEmpty || value.toLowerCase() == 'null') return null;
    if (value.startsWith('http://') || value.startsWith('https://')) {
      return value;
    }
    if (value.startsWith('/')) return '${ApiService.baseUrl}$value';
    return '${ApiService.baseUrl}/$value';
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

  String _shortReasonFor(ProviderModel provider) {
    if (_sortOption != ProviderSortOption.smartMatch) return '';
    if (context.l10n.isArabic) {
      return context.tr('providers.aiReasonFallback');
    }

    final recommendation = _backendRecommendations[provider.userId];
    final rawReasons = recommendation?['medicalReasons'];
    if (rawReasons is List) {
      final reasons = rawReasons
          .map((e) => e.toString().trim())
          .where((e) => e.isNotEmpty)
          .take(2)
          .map((e) => e.toLowerCase())
          .toList();
      if (reasons.isNotEmpty) {
        return 'Matched for ${reasons.join(' and ')}.';
      }
    }

    if (_careSummary.hasStructuredData) {
      return ProviderSmartMatch.recommendationReason(
        recommendation ?? provider,
        _careSummary,
      );
    }
    return context.tr('providers.aiReasonFallback');
  }

  String _distanceLabel(int meters) {
    if (meters < 1000) return '$meters m';
    return '${(meters / 1000).toStringAsFixed(1)} km';
  }

  Widget _matchBadge(CarelinkPalette p, int percentage) {
    return Container(
      margin: const EdgeInsetsDirectional.only(start: 6),
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: p.isDark ? 0.22 : 0.10),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        '$percentage% ${context.tr('providers.match')}',
        style: const TextStyle(
          color: AppColors.primary,
          fontSize: 10.5,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }

  Widget _availabilityBadge(CarelinkPalette p, bool available) {
    final color = available ? AppColors.primary : p.inkMuted;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: p.isDark ? 0.18 : 0.09),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 4),
          Text(
            context.tr(available ? 'providers.available' : 'providers.busy'),
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

  Widget _metric(
    CarelinkPalette p,
    IconData icon,
    String value, {
    Color iconColor = AppColors.primary,
  }) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: iconColor),
        const SizedBox(width: 3),
        Text(
          value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: 11.5,
            color: p.inkMuted,
            fontWeight: FontWeight.w700,
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
              child: Text(_copy('Try Again', 'حاول مرة أخرى')),
            ),
          ],
        ],
      ),
    );
  }
}
