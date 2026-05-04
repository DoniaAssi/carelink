import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;

import 'package:carelink/core/app_colors.dart';
import 'package:carelink/core/app_localizations.dart';
import 'package:carelink/core/patient_home_palette.dart';
import 'package:carelink/core/profile_avatar.dart'
    show profileAvatarOrPlaceholder, profileImageUrlFromMap;
import 'package:carelink/core/theme_controller.dart';
import 'package:carelink/shared/models/appointment_model.dart';
import 'package:carelink/shared/models/provider_model.dart';
import 'package:carelink/shared/services/api_service.dart';
import 'package:carelink/features/patient/services/favorite_providers_service.dart';
import 'package:carelink/shared/services/location_service.dart';
import 'package:carelink/features/ai/care_intent_parser.dart';
import 'package:carelink/shared/services/medical_record_service.dart';
import 'package:carelink/features/patient/services/patient_care_summary.dart';
import 'package:carelink/features/ai/provider_smart_match.dart';
import 'booking_details_screen.dart';
import 'messages_screen.dart';
import 'package:carelink/features/notifications/notifications_screen.dart';
import 'edit_profile_screen.dart';
import 'profile_screen.dart';
import 'provider_details_screen.dart';
import 'providers_screen.dart';
import 'patient_care_hub_screen.dart';
import 'package:carelink/shared/widgets/carelink_brand_logo.dart';

class PatientHomeScreen extends StatefulWidget {
  final String? userId;
  final String? displayName;

  const PatientHomeScreen({super.key, this.userId, this.displayName});

  @override
  State<PatientHomeScreen> createState() => _PatientHomeScreenState();
}

class _PatientHomeScreenState extends State<PatientHomeScreen>
    with SingleTickerProviderStateMixin {
  PatientHomePalette get _p => PatientHomePalette.of(context);

  int currentIndex = 0;
  String selectedSpecialty = 'All';
  String _availabilityFilter = 'All';
  String sortMode = 'Smart match';
  bool isLoading = true;
  bool isProfileLoading = true;
  bool _loadingUpcoming = false;
  String userName = 'Patient';
  String? errorMessage;
  List<ProviderModel> providers = [];
  AppointmentModel? _upcomingAppointment;
  double? _patientLat;
  double? _patientLng;
  Set<String> _favoriteProviderIds = {};
  Map<String, dynamic>? _patientProfile;
  PatientCareSummary _careSummary = PatientCareSummary.empty;
  final LocationService _locationService = LocationService();
  final TextEditingController _careSearchController = TextEditingController();
  late final AnimationController _aiAnimationController;
  final stt.SpeechToText _speech = stt.SpeechToText();
  Timer? _careSearchDebounce;

  /// Mirrors the field text â€” on Flutter web, reading [TextEditingController.text]
  /// in callbacks can throw if the engine value is not ready; we use this for logic.
  String _careSearchQuery = '';
  String? _lastCareSearchSummary;
  String? _aiRecommendationReason;
  String? _aiTopProviderName;
  String? _aiMatchedProviderId;
  String _activeCaseQuery = '';
  bool _isAiMatching = false;
  int _aiScanStep = 0;
  bool _speechReady = false;
  bool _isListening = false;
  bool _checkingSpeech = false;

  String _lowerText(Object? value) => (value ?? '').toString().toLowerCase();

  /// Same rules as [_applyCareSearch] so the list under â€œRecommendedâ€‌ matches the AI match.
  bool _providerMatchesSpecialtyChip(ProviderModel provider, String chip) {
    if (chip == 'All') return true;
    final c = _lowerText(chip);
    return _lowerText(provider.specialization).contains(c) ||
        _lowerText(provider.serviceType).contains(c);
  }

  static const Map<String, IconData> _specialtyIconMap = {
    'cardiology': Icons.favorite_outline_rounded,
    'neurology': Icons.psychology_alt_outlined,
    'dentistry': Icons.medical_information_outlined,
    'pediatrics': Icons.child_care_outlined,
    'pediatric': Icons.child_care_outlined,
    'nursing': Icons.health_and_safety_outlined,
    'home nursing': Icons.health_and_safety_outlined,
    'general': Icons.local_hospital_outlined,
  };

  IconData _iconForSpecialty(String title) {
    final key = title.trim().toLowerCase();
    for (final entry in _specialtyIconMap.entries) {
      if (key.contains(entry.key)) return entry.value;
    }
    return Icons.medical_services_outlined;
  }

  PatientCareSummary get _recommendationSummary {
    return _summaryForCase(_activeCaseQuery);
  }

  PatientCareSummary _summaryForCase(String currentCase) {
    if (currentCase.trim().isEmpty) return _careSummary;
    return PatientCareSummary.mergeText(
      _careSummary,
      currentCase,
      label: 'current case',
    );
  }

  String _chipLabel(String title) {
    if (title == 'All') return context.tr('patient.allProviders');
    return title;
  }

  List<String> get _specialtyItems {
    final set = <String>{};
    for (final provider in providers) {
      final spec = provider.specialization.trim();
      if (spec.isNotEmpty) set.add(spec);
    }
    final items = set.toList()..sort((a, b) => a.compareTo(b));
    return ['All', ...items];
  }

  @override
  void initState() {
    super.initState();
    _aiAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 6800),
    )..repeat();
    _fetchProviders();
    _loadPatientProfile();
    _loadPatientLocation();
    _fetchUpcomingAppointment();
    _loadFavorites();
    _loadMedicalSummary();
  }

  @override
  void dispose() {
    _careSearchDebounce?.cancel();
    _speech.stop();
    _aiAnimationController.dispose();
    _careSearchController.dispose();
    super.dispose();
  }

  Future<void> _toggleVoiceSearch() async {
    if (_isListening) {
      await _speech.stop();
      if (mounted) setState(() => _isListening = false);
      _applyCareSearch();
      return;
    }

    setState(() => _checkingSpeech = true);
    try {
      final ready =
          _speechReady ||
          await _speech.initialize(
            onStatus: (status) {
              if (!mounted) return;
              if (status == 'done' || status == 'notListening') {
                setState(() => _isListening = false);
              }
            },
            onError: (_) {
              if (!mounted) return;
              setState(() => _isListening = false);
            },
          );

      if (!ready) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.tr('patient.voiceUnavailable'))),
        );
        return;
      }

      _speechReady = true;
      if (!mounted) return;
      setState(() => _isListening = true);
      await _speech.listen(
        listenOptions: stt.SpeechListenOptions(
          listenMode: stt.ListenMode.confirmation,
          partialResults: true,
        ),
        onResult: (result) {
          final words = result.recognizedWords.trim();
          if (words.isEmpty || !mounted) return;
          setState(() {
            _careSearchQuery = words;
            _careSearchController.text = words;
            _careSearchController.selection = TextSelection.collapsed(
              offset: words.length,
            );
          });
          if (result.finalResult) {
            setState(() => _isListening = false);
            _applyCareSearch();
          } else {
            _queueCareSearch(words);
          }
        },
      );
    } finally {
      if (mounted) setState(() => _checkingSpeech = false);
    }
  }

  ProviderModel? _topSmartProvider(
    List<ProviderModel> list,
    String selectedChip,
    PatientCareSummary summary,
  ) {
    if (list.isEmpty) return null;
    return ProviderSmartMatch.sortCopy(
      list,
      selectedSpecialty: selectedChip,
      locationService: _locationService,
      patientLat: _patientLat,
      patientLng: _patientLng,
      careSummary: summary,
    ).first;
  }

  String _recommendationReason(
    ProviderModel provider,
    String chip, {
    required PatientCareSummary summary,
    required String currentCase,
  }) {
    final reasons = <String>[];
    if (chip != 'All') {
      reasons.add('specialization match');
    }
    final distance = _distanceKmLabel(provider);
    if (distance != null) reasons.add(distance);
    if (provider.isAvailable) reasons.add('available now');
    if (provider.overallRating > 0) {
      reasons.add('${provider.overallRating.toStringAsFixed(1)} rating');
    }
    final years = provider.experienceYears;
    if (years != null && years > 0) reasons.add('$years years experience');
    final recommendationSummary = summary;
    final hasCurrentCase = currentCase.trim().isNotEmpty;
    if (recommendationSummary.hasStructuredData) {
      final fit = ProviderSmartMatch.medicalFitRatio(
        provider,
        recommendationSummary,
      );
      if (fit >= 0.55) {
        reasons.add(
          hasCurrentCase
              ? 'strong fit with your current case'
              : 'strong fit with your saved medical file',
        );
      } else if (fit >= 0.32) {
        reasons.add(
          hasCurrentCase
              ? 'reasonable fit with your current case'
              : 'reasonable fit with your medical file',
        );
      }
    }
    final score = ProviderSmartMatch.score(
      provider,
      selectedSpecialty: chip,
      locationService: _locationService,
      patientLat: _patientLat,
      patientLng: _patientLng,
      careSummary: recommendationSummary,
    ).round();
    if (reasons.isEmpty) {
      return 'AI score $score/100 using the project recommendation weights.';
    }
    return 'AI score $score/100 based on ${reasons.join(', ')}.';
  }

  void _queueCareSearch(String value) {
    _careSearchQuery = value;
    _careSearchDebounce?.cancel();

    final text = value.trim();
    if (text.isEmpty) {
      setState(() {
        _isAiMatching = false;
        _activeCaseQuery = '';
        _aiTopProviderName = null;
        _aiMatchedProviderId = null;
        _aiRecommendationReason = null;
        _lastCareSearchSummary = null;
      });
      return;
    }

    setState(() {
      _isAiMatching = true;
      _aiScanStep++;
      _activeCaseQuery = text;
      _aiTopProviderName = null;
      _aiMatchedProviderId = null;
      _aiRecommendationReason = null;
      _lastCareSearchSummary = 'Scanning providers for "$text"...';
    });

    _careSearchDebounce = Timer(const Duration(milliseconds: 1150), () {
      if (!mounted) return;
      _resolveCareSearch(showSnackBar: false);
    });
  }

  void _applyCareSearch() {
    _careSearchDebounce?.cancel();
    _resolveCareSearch(showSnackBar: true);
  }

  void _resolveCareSearch({required bool showSnackBar}) {
    final text = _careSearchQuery.trim();
    if (text.isEmpty) {
      setState(() => _isAiMatching = false);
      if (showSnackBar) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.tr('patient.typeCareNeed'))),
        );
      }
      return;
    }

    if (providers.isEmpty) {
      setState(() => _isAiMatching = false);
      if (showSnackBar) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.tr('patient.providersLoading'))),
        );
      }
      return;
    }

    final chips = _specialtyItems;
    final result = parseCareIntent(text, chips);
    var chip = result.specialtyChip;
    if (!chips.contains(chip)) {
      chip = 'All';
    }

    final matchedProviders = chip == 'All'
        ? List<ProviderModel>.from(providers)
        : providers
              .where((p) => _providerMatchesSpecialtyChip(p, chip))
              .toList();
    if (result.restrictToAvailable) {
      matchedProviders.removeWhere((p) => !p.isAvailable);
    }
    final currentCaseSummary = _summaryForCase(text);
    final topProvider = _topSmartProvider(
      matchedProviders,
      chip,
      currentCaseSummary,
    );

    setState(() {
      selectedSpecialty = chip;
      sortMode = 'Smart match';
      if (result.restrictToAvailable) {
        _availabilityFilter = 'Available Now';
      }
      _activeCaseQuery = text;
      _isAiMatching = false;
      _aiTopProviderName = topProvider?.fullName;
      _aiMatchedProviderId = topProvider?.userId;
      _aiRecommendationReason = topProvider == null
          ? 'No provider matched this request yet. Try a broader specialty.'
          : _recommendationReason(
              topProvider,
              chip,
              summary: currentCaseSummary,
              currentCase: text,
            );
      _lastCareSearchSummary =
          result.specialtyChip == 'All' && !result.restrictToAvailable
          ? 'AI did not find a clear specialty. Showing all providers by smart score.'
          : 'AI matched $chip${result.restrictToAvailable ? ' - available now' : ''}.';
    });

    if (!mounted) return;
    if (!showSnackBar) return;
    final msg = chip == 'All' && !result.restrictToAvailable
        ? 'No clear specialty - showing all by smart score.'
        : 'Updated: ${chip == 'All' ? 'filters' : chip}'
              '${result.restrictToAvailable ? ' - available now' : ''}';
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), behavior: SnackBarBehavior.floating),
    );
  }

  Future<void> _loadFavorites() async {
    try {
      final ids = await FavoriteProvidersService.getIds(widget.userId);
      if (!mounted) return;
      setState(() => _favoriteProviderIds = ids);
    } catch (_) {}
  }

  List<ProviderModel> get _favoriteProviders {
    if (_favoriteProviderIds.isEmpty) return const [];
    return providers
        .where((p) => _favoriteProviderIds.contains(p.userId))
        .toList();
  }

  Future<void> _loadPatientLocation() async {
    try {
      final pos = await LocationService().getCurrentPosition();
      if (!mounted) return;
      setState(() {
        _patientLat = pos.latitude;
        _patientLng = pos.longitude;
      });
    } catch (_) {}
  }

  Future<void> _fetchUpcomingAppointment() async {
    final id = widget.userId?.trim();
    if (id == null || id.isEmpty) return;
    setState(() => _loadingUpcoming = true);
    try {
      final raw = await ApiService().getUpcomingAppointments(id);
      if (!mounted) return;
      AppointmentModel? next;
      DateTime? best;
      final now = DateTime.now();
      for (final item in raw) {
        if (item is! Map<String, dynamic>) continue;
        final a = AppointmentModel.fromJson(item);
        final t = a.scheduledAt;
        if (t == null) continue;
        if (t.isBefore(now)) continue;
        if (best == null || t.isBefore(best)) {
          best = t;
          next = a;
        }
      }
      setState(() => _upcomingAppointment = next);
    } catch (_) {
      if (mounted) setState(() => _upcomingAppointment = null);
    } finally {
      if (mounted) setState(() => _loadingUpcoming = false);
    }
  }

  String get _firstName {
    final n = userName.trim();
    if (n.isEmpty) return 'there';
    return n.split(RegExp(r'\s+')).first;
  }

  String _formatAppointmentDate(DateTime? dt) {
    if (dt == null) return 'â€”';
    const months = [
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December',
    ];
    const days = [
      'Monday',
      'Tuesday',
      'Wednesday',
      'Thursday',
      'Friday',
      'Saturday',
      'Sunday',
    ];
    return '${dt.day} ${months[dt.month - 1]}, ${days[dt.weekday - 1]}';
  }

  String _formatAppointmentTime(DateTime? dt) {
    if (dt == null) return 'â€”';
    var h = dt.hour;
    final m = dt.minute;
    final period = h >= 12 ? 'PM' : 'AM';
    if (h > 12) h -= 12;
    if (h == 0) h = 12;
    return '${h.toString()}:${m.toString().padLeft(2, '0')} $period';
  }

  double? _distanceKmValue(ProviderModel p) {
    if (_patientLat == null ||
        _patientLng == null ||
        p.gpsLat == null ||
        p.gpsLng == null) {
      return null;
    }
    final meters = _locationService.distanceInMeters(
      fromLat: _patientLat,
      fromLng: _patientLng,
      toLat: p.gpsLat,
      toLng: p.gpsLng,
    );
    if (meters == null) return null;
    return meters / 1000.0;
  }

  String? _distanceKmLabel(ProviderModel p) {
    final km = _distanceKmValue(p);
    if (km == null) return null;
    return '${km.toStringAsFixed(1)} km away';
  }

  Future<void> _fetchProviders() async {
    try {
      final data = await ApiService().getProviders();
      if (!mounted) return;

      setState(() {
        providers = data.map((e) => ProviderModel.fromJson(e)).toList();
        isLoading = false;
        errorMessage = null;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        isLoading = false;
        errorMessage = 'Unable to load providers. Please try again.';
      });
    }
  }

  Future<void> _loadMedicalSummary() async {
    final id = widget.userId?.trim();
    if (id == null || id.isEmpty) {
      if (mounted) setState(() => _careSummary = PatientCareSummary.empty);
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
      });
    } catch (_) {
      if (mounted) setState(() => _careSummary = PatientCareSummary.empty);
    }
  }

  Future<void> _loadPatientProfile() async {
    if (widget.userId == null || widget.userId!.isEmpty) {
      setState(() {
        userName = widget.displayName ?? 'Patient';
        _patientProfile = null;
        isProfileLoading = false;
      });
      return;
    }

    try {
      final profile = await ApiService().getPatientProfile(widget.userId!);
      if (!mounted) return;

      setState(() {
        _patientProfile = profile;
        userName = profile['fullName'] ?? widget.displayName ?? 'Patient';
        isProfileLoading = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _patientProfile = null;
        userName = widget.displayName ?? 'Patient';
        isProfileLoading = false;
      });
    }
  }

  Future<void> _openEditFromHero() async {
    final id = widget.userId?.trim();
    if (id == null || id.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.tr('patient.signInEditProfile'))),
      );
      return;
    }

    Map<String, dynamic> data = Map<String, dynamic>.from(
      _patientProfile ?? <String, dynamic>{},
    );
    if (data.isEmpty) {
      try {
        data = await ApiService().getPatientProfile(id);
      } catch (_) {
        data = {'fullName': userName, 'email': '', 'phone': ''};
      }
    }
    if (!mounted) return;

    final updated = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => EditProfileScreen(userId: id, userData: data),
      ),
    );
    if (updated == true && mounted) {
      await _loadPatientProfile();
    }
  }

  void _openproviders() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => ProvidersScreen(userId: widget.userId)),
    );
  }

  void _openSchedule() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) =>
            PatientCareHubScreen(patientUserId: widget.userId ?? ''),
      ),
    );
  }

  void _openMessages() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => MessagesScreen(userId: widget.userId ?? ''),
      ),
    );
  }

  void _openProfile() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ProfileScreen(userId: widget.userId ?? ''),
      ),
    );
  }

  void _openNotifications() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => NotificationsScreen(userId: widget.userId),
      ),
    );
  }

  void _onBottomNavTap(int value) {
    if (value == currentIndex) return;

    setState(() => currentIndex = value);

    switch (value) {
      case 0:
        break;
      case 1:
        _openSchedule();
        break;
      case 2:
        _openMessages();
        break;
      case 3:
        _openProfile();
        break;
    }
  }

  String get _greeting {
    final hour = DateTime.now().hour;
    if (hour < 12) return context.tr('patient.goodMorning');
    if (hour < 17) return context.tr('patient.goodAfternoon');
    return context.tr('patient.goodEvening');
  }

  @override
  Widget build(BuildContext context) {
    final specialtyMatched = selectedSpecialty == 'All'
        ? List<ProviderModel>.from(providers)
        : providers
              .where((p) => _providerMatchesSpecialtyChip(p, selectedSpecialty))
              .toList();
    var filteredProviders = List<ProviderModel>.from(specialtyMatched);
    if (_availabilityFilter == 'Available Now') {
      filteredProviders.removeWhere((p) => !p.isAvailable);
    }

    final List<ProviderModel> displayProviders;
    if (sortMode == 'Smart match') {
      displayProviders = ProviderSmartMatch.sortCopy(
        filteredProviders,
        selectedSpecialty: selectedSpecialty,
        locationService: _locationService,
        patientLat: _patientLat,
        patientLng: _patientLng,
        careSummary: _recommendationSummary,
      );
    } else {
      final copy = List<ProviderModel>.from(filteredProviders);
      copy.sort((a, b) {
        if (sortMode == 'A-Z') {
          return a.fullName.toLowerCase().compareTo(b.fullName.toLowerCase());
        }
        return b.overallRating.compareTo(a.overallRating);
      });
      displayProviders = copy;
    }

    return Scaffold(
      backgroundColor: _p.pageBg,
      body: SafeArea(
        child: RefreshIndicator(
          color: AppColors.primary,
          onRefresh: () async {
            await _fetchProviders();
            await _loadPatientProfile();
            await _fetchUpcomingAppointment();
            await _loadPatientLocation();
            await _loadFavorites();
            await _loadMedicalSummary();
          },
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.only(bottom: 118),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
                  child: _buildHeroHeader(),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                  child: _buildSmartSearchCard(),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 18, 16, 0),
                  child: _buildUpcomingAppointmentCard(),
                ),
                if (_favoriteProviders.isNotEmpty) ...[
                  const SizedBox(height: 20),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: _buildSectionHeader(
                      title: 'Favorites',
                      actionText: 'See all >',
                      onActionTap: _openproviders,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: _buildFavoritesRow(),
                  ),
                ],
                const SizedBox(height: 20),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: _buildSectionHeader(
                    title: 'Provider Specialty',
                    actionText: 'See all >',
                    onActionTap: _openproviders,
                  ),
                ),
                const SizedBox(height: 12),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: _buildSpecialtyChips(),
                ),
                const SizedBox(height: 20),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: _buildSectionHeader(
                    title: sortMode == 'Smart match'
                        ? context.tr('patient.recommendedForYou')
                        : 'Popular Providers',
                    subtitle: sortMode == 'Smart match'
                        ? _recommendationSummary.hasStructuredData
                              ? 'Smart match uses your current case, medical file, specialty, distance, availability, ratings & experience.'
                              : 'Add a medical record or describe your care need for stronger matches.'
                        : null,
                    actionText: 'See all >',
                    onActionTap: _openproviders,
                  ),
                ),
                const SizedBox(height: 12),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: _buildProviderFilters(),
                ),
                const SizedBox(height: 12),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: isLoading
                      ? const Padding(
                          padding: EdgeInsets.symmetric(vertical: 24),
                          child: Center(child: CircularProgressIndicator()),
                        )
                      : displayProviders.isEmpty
                      ? _buildNoProvidersCard()
                      : Column(
                          children: displayProviders
                              .take(8)
                              .toList()
                              .asMap()
                              .entries
                              .map(
                                (e) => Padding(
                                  padding: const EdgeInsets.only(bottom: 12),
                                  child: _buildDoctorListCard(
                                    e.value,
                                    showRecommendedBadge:
                                        sortMode == 'Smart match' && e.key < 3,
                                    isAiMatched:
                                        e.value.userId == _aiMatchedProviderId,
                                  ),
                                ),
                              )
                              .toList(),
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
      bottomNavigationBar: _buildFloatingBottomNav(),
    );
  }

  Widget _buildSmartSearchCard() {
    final topProvider = _aiTopProviderName;
    final reason = _aiRecommendationReason;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      decoration: BoxDecoration(
        color: _p.surface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: _p.stroke),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(
                Icons.psychology_alt_outlined,
                color: AppColors.primary,
                size: 22,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'AI care match',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: _p.inkDark,
                  ),
                ),
              ),
              _AiListeningBadge(isListening: _isListening),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            _careSummary.hasStructuredData
                ? 'Your saved medical file is included in the score (conditions & allergies vs provider role/specialty), plus distance, availability, ratings & experience.'
                : context.tr('patient.typeOrSpeak'),
            style: TextStyle(fontSize: 12, color: _p.inkMuted, height: 1.35),
          ),
          const SizedBox(height: 12),
          _AiMatchAnimation(
            controller: _aiAnimationController,
            isListening: _isListening,
            isMatching: _isAiMatching,
            scanStep: _aiScanStep,
            hasRecommendation: reason != null,
            recommendationTitle: topProvider == null
                ? (_lastCareSearchSummary ?? 'AI smart match')
                : context.tr(
                    'patient.recommended',
                    args: {'provider': topProvider},
                  ),
            recommendationReason: reason ?? _lastCareSearchSummary ?? '',
            surface: _p.filterSurface,
            stroke: _p.stroke,
            muted: _p.inkMuted,
            text: _p.inkDark,
          ),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: TextField(
                  controller: _careSearchController,
                  textInputAction: TextInputAction.search,
                  onChanged: _queueCareSearch,
                  onSubmitted: (_) => _applyCareSearch(),
                  style: TextStyle(color: _p.inkDark, fontSize: 15),
                  decoration: InputDecoration(
                    isDense: true,
                    hintText:
                        'e.g. diabetes follow-up, ط·ط¨ظٹط¨ ط£ط·ظپط§ظ„, cardiology, available now',
                    hintStyle: TextStyle(color: _p.inkMuted),
                    filled: true,
                    fillColor: _p.filterSurface,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 12,
                    ),
                    prefixIcon: Icon(
                      _isListening ? Icons.graphic_eq_rounded : Icons.search,
                      color: AppColors.primary,
                      size: 20,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide(color: _p.stroke),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide(color: _p.stroke),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: const BorderSide(
                        color: AppColors.primary,
                        width: 1.2,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              _buildVoiceButton(),
              const SizedBox(width: 8),
              FilledButton(
                onPressed: _applyCareSearch,
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                ),
                child: Text(context.tr('patient.find')),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildVoiceButton() {
    return Tooltip(
      message: context.tr(
        _isListening ? 'patient.stopVoice' : 'patient.speakNeed',
      ),
      child: InkWell(
        onTap: _checkingSpeech ? null : _toggleVoiceSearch,
        borderRadius: BorderRadius.circular(14),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          width: 46,
          height: 46,
          decoration: BoxDecoration(
            color: _isListening
                ? AppColors.primary
                : AppColors.primary.withValues(alpha: _p.isDark ? 0.16 : 0.10),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: AppColors.primary.withValues(
                alpha: _isListening ? 0.9 : 0.28,
              ),
            ),
          ),
          child: _checkingSpeech
              ? const Padding(
                  padding: EdgeInsets.all(13),
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: AppColors.primary,
                  ),
                )
              : Icon(
                  _isListening ? Icons.stop_rounded : Icons.mic_none_rounded,
                  color: _isListening ? Colors.white : AppColors.primary,
                  size: 22,
                ),
        ),
      ),
    );
  }

  Widget _buildNoProvidersCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: _p.surface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: _p.stroke),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Text(
        'No providers match your filters.',
        style: TextStyle(color: _p.inkMuted, fontWeight: FontWeight.w600),
      ),
    );
  }

  Widget _buildHeroHeader() {
    return SizedBox(
      height: 122,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(
            right: 0,
            top: 30,
            child: SizedBox(
              width: 136,
              height: 58,
              child: CustomPaint(
                painter: _HeaderEkgDecorationPainter(
                  lineColor: AppColors.primary.withValues(
                    alpha: _p.isDark ? 0.23 : 0.11,
                  ),
                  glow: _p.isDark,
                ),
              ),
            ),
          ),
          Positioned(
            right: 78,
            top: 33,
            child: Icon(
              Icons.health_and_safety_outlined,
              size: 60,
              color: AppColors.primary.withValues(
                alpha: _p.isDark ? 0.15 : 0.08,
              ),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  CarelinkBrandLogo(
                    height: 30,
                    fallbackTextColor: _p.inkDark,
                    forceDarkLogo: _p.isDark,
                  ),
                  const Spacer(),
                  InkWell(
                    onTap: () => themeController.toggle(),
                    borderRadius: BorderRadius.circular(18),
                    child: Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: _p.surface,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: _p.stroke),
                      ),
                      child: Icon(
                        _p.isDark
                            ? Icons.light_mode_rounded
                            : Icons.dark_mode_rounded,
                        color: _p.inkDark,
                        size: 21,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  InkWell(
                    onTap: _openNotifications,
                    borderRadius: BorderRadius.circular(18),
                    child: Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: _p.surface,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: _p.stroke),
                      ),
                      child: Stack(
                        clipBehavior: Clip.none,
                        children: [
                          Center(
                            child: Icon(
                              Icons.notifications_none_rounded,
                              color: _p.inkDark,
                              size: 22,
                            ),
                          ),
                          Positioned(
                            right: 10,
                            top: 10,
                            child: Container(
                              width: 7,
                              height: 7,
                              decoration: const BoxDecoration(
                                color: Color(0xFFFF6B6B),
                                shape: BoxShape.circle,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: _openEditFromHero,
                      borderRadius: BorderRadius.circular(32),
                      child: Container(
                        width: 58,
                        height: 58,
                        decoration: BoxDecoration(
                          color: _p.surface,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.12),
                              blurRadius: 14,
                              offset: const Offset(0, 6),
                            ),
                          ],
                        ),
                        child: ClipOval(
                          child: profileAvatarOrPlaceholder(
                            imageUrl: profileImageUrlFromMap(_patientProfile),
                            size: 58,
                            placeholderColor: AppColors.primary.withValues(
                              alpha: 0.85,
                            ),
                            placeholderIcon: Icons.person_rounded,
                            iconSize: 28,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          isProfileLoading
                              ? context.tr('patient.hiLoading')
                              : context.tr(
                                  'patient.hiName',
                                  args: {'name': _firstName},
                                ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: _p.inkDark,
                            fontSize: 19,
                            fontWeight: FontWeight.w800,
                            height: 1.15,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          '$_greeting, welcome back!',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: _p.inkMuted,
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            height: 1.2,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _openUpcomingDetails() {
    final apt = _upcomingAppointment;
    final uid = widget.userId?.trim();
    if (apt != null && uid != null && uid.isNotEmpty) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => BookingDetailsScreen(
            appointmentId: apt.appointmentId,
            patientUserId: uid,
          ),
        ),
      );
    } else {
      _openSchedule();
    }
  }

  Widget _buildUpcomingAppointmentCard() {
    final apt = _upcomingAppointment;
    final name = apt?.providerName.trim().isNotEmpty == true
        ? apt!.providerName
        : context.tr('patient.bookNextVisit');
    final sub = apt == null
        ? 'Browse popular providers below'
        : (apt.specialization.trim().isNotEmpty
              ? apt.specialization
              : (_lowerText(apt.providerRole) == 'nurse'
                    ? context.tr('patient.homeNursingCare')
                    : 'Consultation'));
    final dateLabel = apt != null
        ? _formatAppointmentDate(apt.scheduledAt)
        : '-';
    final timeLabel = apt != null
        ? _formatAppointmentTime(apt.scheduledAt)
        : '-';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
      decoration: BoxDecoration(
        color: _p.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _p.stroke),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: _p.isDark ? 0.28 : 0.05),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'Upcoming Appointment',
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 13,
                  color: _p.inkDark,
                ),
              ),
              const Spacer(),
              InkWell(
                onTap: _openUpcomingDetails,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'View details >',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 11,
                        color: AppColors.primary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (_loadingUpcoming) ...[
            const SizedBox(height: 16),
            const LinearProgressIndicator(
              minHeight: 3,
              color: AppColors.primary,
            ),
          ] else ...[
            const SizedBox(height: 12),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: _p.upcomingIconGradient,
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      Icon(
                        Icons.medical_services_rounded,
                        color: AppColors.primary.withValues(alpha: 0.9),
                        size: 25,
                      ),
                      Positioned(
                        right: 4,
                        bottom: 4,
                        child: Container(
                          padding: const EdgeInsets.all(2),
                          decoration: BoxDecoration(
                            color: _p.surface,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.add_rounded,
                            size: 10,
                            color: AppColors.primary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 13,
                          color: _p.inkDark,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        sub,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 11,
                          color: apt == null ? _p.inkMuted : AppColors.primary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 14,
                        runSpacing: 8,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.calendar_today_outlined,
                                size: 16,
                                color: _p.inkMuted,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                dateLabel,
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                  color: _p.inkDark,
                                ),
                              ),
                            ],
                          ),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.access_time_rounded,
                                size: 16,
                                color: _p.inkMuted,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                timeLabel,
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                  color: _p.inkDark,
                                ),
                              ),
                            ],
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
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _openSchedule,
                    icon: const Icon(Icons.calendar_today_outlined, size: 15),
                    label: const Text('Reschedule'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.primary,
                      side: const BorderSide(
                        color: AppColors.primary,
                        width: 1.4,
                      ),
                      backgroundColor: _p.surfaceSoft,
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: SizedBox(
                    height: 40,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(10),
                        gradient: LinearGradient(
                          colors: _p.isDark
                              ? const [Color(0xFF40C4B4), Color(0xFF2DD4E8)]
                              : const [
                                  AppColors.primary,
                                  AppColors.primaryDark,
                                ],
                        ),
                      ),
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(10),
                          onTap: _openMessages,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(
                                Icons.videocam_rounded,
                                size: 16,
                                color: Colors.white,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'Join Now',
                                style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSpecialtyChips() {
    final items = _specialtyItems;
    return SizedBox(
      height: 96,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemBuilder: (context, index) {
          final title = items[index];
          final icon = _iconForSpecialty(title);
          final selected = title == selectedSpecialty;
          final isAll = title == 'All';
          final baseBg = _p.specialtyCardBackground(title);
          final cardBg = selected ? baseBg : baseBg.withValues(alpha: 0.72);
          final accent = _p.specialtyIconColor(title);

          final bool allTealLight = selected && isAll && !_p.isDark;
          final bool allDarkGlow = selected && isAll && _p.isDark;

          final Color fillColor;
          final Color borderColor;
          final List<BoxShadow>? cardShadows;
          final Color circleFill;
          final Color iconForeground;
          final Color labelColor;

          if (allTealLight) {
            fillColor = AppColors.primary;
            borderColor = Colors.white.withValues(alpha: 0.22);
            cardShadows = [
              BoxShadow(
                color: AppColors.primary.withValues(alpha: 0.32),
                blurRadius: 18,
                offset: const Offset(0, 8),
              ),
            ];
            circleFill = Colors.white.withValues(alpha: 0.22);
            iconForeground = Colors.white;
            labelColor = Colors.white;
          } else if (allDarkGlow) {
            fillColor = _p.surface;
            borderColor = AppColors.primary.withValues(alpha: 0.5);
            cardShadows = [
              BoxShadow(
                color: AppColors.primary.withValues(alpha: 0.25),
                blurRadius: 20,
                offset: const Offset(0, 6),
              ),
            ];
            circleFill = AppColors.primary.withValues(alpha: 0.2);
            iconForeground = AppColors.primary;
            labelColor = _p.inkDark;
          } else if (selected) {
            fillColor = _p.surface;
            borderColor = AppColors.primary.withValues(alpha: 0.2);
            cardShadows = [
              BoxShadow(
                color: AppColors.primary.withValues(alpha: 0.1),
                blurRadius: 16,
                offset: const Offset(0, 8),
              ),
            ];
            circleFill = accent.withValues(alpha: 0.16);
            iconForeground = accent;
            labelColor = _p.inkDark;
          } else {
            fillColor = cardBg;
            borderColor = _p.stroke;
            cardShadows = null;
            circleFill = accent.withValues(alpha: 0.16);
            iconForeground = accent;
            labelColor = _p.inkDark;
          }

          return InkWell(
            onTap: () {
              if (selectedSpecialty == title) return;
              setState(() => selectedSpecialty = title);
            },
            borderRadius: BorderRadius.circular(18),
            child: SizedBox(
              width: 82,
              child: Stack(
                children: [
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    width: 82,
                    padding: const EdgeInsets.fromLTRB(8, 8, 8, 10),
                    decoration: BoxDecoration(
                      color: fillColor,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: borderColor),
                      boxShadow: cardShadows,
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.start,
                      children: [
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: circleFill,
                          ),
                          alignment: Alignment.center,
                          child: Icon(icon, size: 22, color: iconForeground),
                        ),
                        const SizedBox(height: 6),
                        Expanded(
                          child: Center(
                            child: Text(
                              _chipLabel(title),
                              textAlign: TextAlign.center,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 10,
                                height: 1.2,
                                color: labelColor,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (selected && (!isAll || _p.isDark))
                    Positioned(
                      left: 2,
                      right: 2,
                      bottom: 0,
                      child: Container(
                        height: allDarkGlow ? 4 : 3,
                        decoration: BoxDecoration(
                          color: AppColors.primary,
                          borderRadius: BorderRadius.circular(99),
                          boxShadow: allDarkGlow
                              ? [
                                  BoxShadow(
                                    color: AppColors.primary.withValues(
                                      alpha: 0.55,
                                    ),
                                    blurRadius: 10,
                                    spreadRadius: 0.5,
                                  ),
                                ]
                              : null,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          );
        },
        separatorBuilder: (_, _) => const SizedBox(width: 10),
        itemCount: items.length,
      ),
    );
  }

  Widget _buildProviderFilters() {
    Widget dropdownShell({required Widget child}) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10),
        decoration: BoxDecoration(
          color: _p.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: _p.stroke),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: child,
      );
    }

    return Row(
      children: [
        Expanded(
          child: dropdownShell(
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                isExpanded: true,
                value:
                    (const [
                      'Smart match',
                      'Top Rated',
                      'A-Z',
                    ].contains(sortMode))
                    ? sortMode
                    : 'Smart match',
                dropdownColor: _p.surface,
                icon: Icon(Icons.expand_more_rounded, color: _p.inkMuted),
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: _p.inkDark,
                ),
                items: const [
                  DropdownMenuItem(
                    value: 'Smart match',
                    child: Text('Smart match'),
                  ),
                  DropdownMenuItem(
                    value: 'Top Rated',
                    child: Text('Top Rated'),
                  ),
                  DropdownMenuItem(value: 'A-Z', child: Text('A-Z')),
                ],
                onChanged: (value) {
                  if (value == null) return;
                  setState(() => sortMode = value);
                },
              ),
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: dropdownShell(
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                isExpanded: true,
                value: _availabilityFilter,
                dropdownColor: _p.surface,
                icon: Icon(Icons.expand_more_rounded, color: _p.inkMuted),
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: _p.inkDark,
                ),
                items: [
                  const DropdownMenuItem(value: 'All', child: Text('All')),
                  DropdownMenuItem(
                    value: 'Available Now',
                    child: Row(
                      children: [
                        Container(
                          width: 7,
                          height: 7,
                          margin: const EdgeInsets.only(right: 8),
                          decoration: const BoxDecoration(
                            color: Color(0xFF1CAE62),
                            shape: BoxShape.circle,
                          ),
                        ),
                        const Text('Available Now'),
                      ],
                    ),
                  ),
                ],
                onChanged: (value) {
                  if (value == null) return;
                  setState(() => _availabilityFilter = value);
                },
              ),
            ),
          ),
        ),
      ],
    );
  }

  void _bookProvider(ProviderModel provider) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ProviderDetailsScreen(
          provider: provider,
          patientUserId: widget.userId,
          distanceKm: _distanceKmValue(provider),
        ),
      ),
    ).then((_) {
      if (mounted) _loadFavorites();
    });
  }

  Widget _buildFavoritesRow() {
    final list = _favoriteProviders;
    return SizedBox(
      height: 100,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: list.length,
        separatorBuilder: (_, _) => const SizedBox(width: 10),
        itemBuilder: (context, index) {
          final p = list[index];
          final isDoctor = _lowerText(p.role) == 'doctor';
          return Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: () => _bookProvider(p),
              child: Container(
                width: 200,
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: _p.surface,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: _p.stroke),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.04),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 24,
                      backgroundColor: AppColors.primary.withValues(
                        alpha: 0.12,
                      ),
                      child: Icon(
                        isDoctor
                            ? Icons.medical_services_rounded
                            : Icons.local_hospital_rounded,
                        color: AppColors.primary,
                        size: 26,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            p.fullName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 14,
                              color: _p.inkDark,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            p.specialization.trim().isEmpty
                                ? 'Care provider'
                                : p.specialization,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(fontSize: 12, color: _p.inkMuted),
                          ),
                        ],
                      ),
                    ),
                    const Icon(
                      Icons.favorite_rounded,
                      color: Color(0xFFE53935),
                      size: 18,
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildDoctorListCard(
    ProviderModel provider, {
    bool showRecommendedBadge = false,
    bool isAiMatched = false,
  }) {
    final isDoctor = _lowerText(provider.role) == 'doctor';
    final dist = _distanceKmLabel(provider);
    var specLine = provider.specialization.trim();
    if (specLine.isEmpty) {
      for (final part in provider.serviceType.split(',')) {
        final t = part.trim();
        if (t.isNotEmpty) {
          specLine = t;
          break;
        }
      }
    }
    if (specLine.isEmpty) specLine = 'Care provider';

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _bookProvider(provider),
        borderRadius: BorderRadius.circular(16),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 360),
          curve: Curves.easeOutCubic,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          decoration: BoxDecoration(
            color: isAiMatched
                ? AppColors.primary.withValues(alpha: _p.isDark ? 0.16 : 0.07)
                : _p.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isAiMatched
                  ? AppColors.primary.withValues(alpha: 0.55)
                  : _p.stroke,
              width: isAiMatched ? 1.4 : 1,
            ),
            boxShadow: [
              BoxShadow(
                color: isAiMatched
                    ? AppColors.primary.withValues(
                        alpha: _p.isDark ? 0.24 : 0.18,
                      )
                    : Colors.black.withValues(alpha: 0.05),
                blurRadius: isAiMatched ? 24 : 16,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Row(
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  Container(
                    width: 58,
                    height: 58,
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: Image.asset(
                      isDoctor
                          ? 'assets/images/doctorportrait.jpg'
                          : 'assets/images/nursemedical.jpg',
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) => Icon(
                        isDoctor
                            ? Icons.medical_services_rounded
                            : Icons.local_hospital_rounded,
                        color: AppColors.primary,
                        size: 30,
                      ),
                    ),
                  ),
                  Positioned(
                    right: 1,
                    bottom: 2,
                    child: Container(
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(
                        color: provider.isAvailable
                            ? const Color(0xFF1DCE77)
                            : _p.inkMuted,
                        shape: BoxShape.circle,
                        border: Border.all(color: _p.surface, width: 2),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        if (showRecommendedBadge) ...[
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.primary.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(
                                color: AppColors.primary.withValues(
                                  alpha: 0.35,
                                ),
                              ),
                            ),
                            child: Text(
                              'ظ…ظˆطµظ‰ ط¨ظ‡',
                              style: TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.w800,
                                color: AppColors.primary,
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                        ],
                        Expanded(
                          child: Text(
                            provider.fullName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 13,
                              color: _p.inkDark,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      specLine,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 11,
                        color: AppColors.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        const Icon(
                          Icons.star_rounded,
                          size: 17,
                          color: AppColors.star,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          provider.overallRating > 0
                              ? provider.overallRating.toStringAsFixed(1)
                              : 'â€”',
                          style: TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 11,
                            color: _p.inkDark,
                          ),
                        ),
                        Text(
                          '  آ·  ',
                          style: TextStyle(
                            fontSize: 11,
                            color: _p.inkMuted,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Icon(
                          Icons.people_alt_outlined,
                          size: 14,
                          color: _p.inkMuted,
                        ),
                        const SizedBox(width: 4),
                        Flexible(
                          child: Text(
                            context.tr('patient.trustedCare'),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: _p.inkMuted,
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (dist != null) ...[
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Icon(
                            Icons.location_on_outlined,
                            size: 14,
                            color: _p.inkMuted,
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              dist,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                                color: _p.inkMuted,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 8),
              InkWell(
                onTap: () => _bookProvider(provider),
                borderRadius: BorderRadius.circular(14),
                child: Container(
                  width: 48,
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(
                      alpha: _p.isDark ? 0.14 : 0.10,
                    ),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: AppColors.primary.withValues(
                        alpha: _p.isDark ? 0.34 : 0.12,
                      ),
                    ),
                  ),
                  child: Column(
                    children: [
                      const Icon(
                        Icons.calendar_month_rounded,
                        color: AppColors.primary,
                        size: 20,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        context.tr('patient.book'),
                        style: const TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w800,
                          color: AppColors.primary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionHeader({
    required String title,
    String? subtitle,
    String? actionText,
    VoidCallback? onActionTap,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: _p.inkDark,
                ),
              ),
              if (subtitle != null && subtitle.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: TextStyle(fontSize: 13, color: _p.inkMuted),
                ),
              ],
            ],
          ),
        ),
        if (actionText != null && onActionTap != null)
          InkWell(
            onTap: onActionTap,
            borderRadius: BorderRadius.circular(8),
            child: Padding(
              padding: const EdgeInsets.only(top: 2, left: 8),
              child: Text(
                actionText,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: AppColors.primary,
                ),
              ),
            ),
          ),
      ],
    );
  }

  /// ط£ظٹظ‚ظˆظ†ط© طھط¨ظˆظٹط¨ ط§ظ„ظ…ظ„ظپ: طµظˆط±ط© ط§ظ„ظ…ط±ظٹط¶ ط¥ظ† ظˆظڈط¬ط¯طھطŒ ظˆط¥ظ„ط§ ط£ظٹظ‚ظˆظ†ط© ط´ط®طµ.
  Widget _buildProfileTabIcon() {
    const size = 24.0;
    if (isProfileLoading) {
      return SizedBox(
        width: size,
        height: size,
        child: const Center(
          child: SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: AppColors.primary,
            ),
          ),
        ),
      );
    }
    final url = profileImageUrlFromMap(_patientProfile);
    if (url == null || url.isEmpty) {
      return const Icon(Icons.person_outline_rounded, size: size);
    }
    return SizedBox(
      width: size,
      height: size,
      child: ClipOval(
        child: profileAvatarOrPlaceholder(
          imageUrl: url,
          size: size,
          placeholderColor: AppColors.primary,
          placeholderIcon: Icons.person_outline_rounded,
          iconSize: 16,
        ),
      ),
    );
  }

  Widget _buildFloatingBottomNav() {
    return Material(
      elevation: 18,
      shadowColor: Colors.black12,
      color: Colors.transparent,
      child: Container(
        margin: const EdgeInsets.fromLTRB(14, 0, 14, 14),
        decoration: BoxDecoration(
          color: _p.navBackground,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: _p.stroke),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: _p.isDark ? 0.35 : 0.08),
              blurRadius: 24,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: SafeArea(
          top: false,
          child: BottomNavigationBar(
            currentIndex: currentIndex,
            onTap: _onBottomNavTap,
            selectedItemColor: AppColors.primary,
            unselectedItemColor: _p.navUnselected,
            backgroundColor: Colors.transparent,
            elevation: 0,
            type: BottomNavigationBarType.fixed,
            selectedLabelStyle: const TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 11,
            ),
            unselectedLabelStyle: const TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 11,
            ),
            items: [
              BottomNavigationBarItem(
                icon: const Icon(Icons.home_rounded, size: 24),
                label: context.tr('patient.navHome'),
              ),
              BottomNavigationBarItem(
                icon: const Icon(Icons.healing_outlined, size: 24),
                label: context.tr('patient.navCare'),
              ),
              BottomNavigationBarItem(
                icon: const Icon(Icons.chat_bubble_outline_rounded, size: 24),
                label: context.tr('patient.navChat'),
              ),
              BottomNavigationBarItem(
                icon: _buildProfileTabIcon(),
                label: context.tr('patient.navProfile'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AiListeningBadge extends StatelessWidget {
  const _AiListeningBadge({required this.isListening});

  final bool isListening;

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 180),
      child: isListening
          ? Container(
              key: const ValueKey('listening'),
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(999),
                border: Border.all(
                  color: AppColors.primary.withValues(alpha: 0.28),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.graphic_eq_rounded,
                    size: 13,
                    color: AppColors.primary,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    context.tr('patient.listening'),
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: AppColors.primary,
                    ),
                  ),
                ],
              ),
            )
          : const SizedBox(key: ValueKey('idle'), width: 0, height: 0),
    );
  }
}

class _AiMatchAnimation extends StatelessWidget {
  const _AiMatchAnimation({
    required this.controller,
    this.isListening = false,
    this.isMatching = false,
    this.scanStep = 0,
    this.hasRecommendation = false,
    required this.recommendationTitle,
    required this.recommendationReason,
    required this.surface,
    required this.stroke,
    required this.muted,
    required this.text,
  });

  final AnimationController controller;
  final bool? isListening;
  final bool? isMatching;
  final int? scanStep;
  final bool? hasRecommendation;
  final String recommendationTitle;
  final String recommendationReason;
  final Color surface;
  final Color stroke;
  final Color muted;
  final Color text;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        final listening = isListening == true;
        final matching = isMatching == true;
        final recommended = hasRecommendation == true;
        final currentScanStep = scanStep ?? 0;
        final rawPhase = controller.value;
        final phase = rawPhase.isFinite ? rawPhase.clamp(0.0, 1.0) : 0.0;
        final robotFloat = _finiteDouble(7 * math.sin(phase * math.pi * 2));
        final robotDrift = _finiteDouble(5 * math.sin(phase * math.pi * 1.15));
        final robotWave = _finiteDouble(math.sin(phase * math.pi * 8));
        final pulse = listening
            ? _finiteDouble(0.92 + 0.08 * math.sin(phase * math.pi * 4).abs())
            : 1.0;
        final bubbleIn = _finiteDouble(
          Curves.easeOutBack.transform(((phase - 0.10) / 0.28).clamp(0.0, 1.0)),
          fallback: 0.0,
        ).clamp(0.0, 1.0);
        final shimmer = _finiteDouble(
          0.12 + 0.06 * math.sin(phase * math.pi * 2).abs(),
        );
        final active = listening || matching || !recommended;
        final scanningTitle = listening
            ? context.tr('patient.listeningRequest')
            : 'Finding the best care provider';
        final scanningBody = [
          'Reading your request',
          'Checking specialty fit',
          'Comparing availability',
          'Ranking nearby providers',
        ][currentScanStep % 4];

        return Container(
          height: 228,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: stroke),
          ),
          child: Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.center,
            children: [
              Positioned(
                top: 12,
                left: 54,
                right: 54,
                child: Opacity(
                  opacity: shimmer,
                  child: _AiGhostCard(height: 38, color: muted),
                ),
              ),
              Positioned(
                bottom: 58,
                left: 42,
                right: 42,
                child: Opacity(
                  opacity: shimmer * 0.85,
                  child: _AiGhostCard(height: 42, color: muted),
                ),
              ),
              Positioned(
                top: 54 - (8 * bubbleIn),
                left: 18,
                right: 18,
                child: Opacity(
                  opacity: (0.45 + 0.55 * bubbleIn).clamp(0.0, 1.0),
                  child: Transform.scale(
                    scale: 0.92 + 0.08 * bubbleIn,
                    child: _AiMessageBubble(
                      title: recommended
                          ? recommendationTitle
                          : active
                          ? scanningTitle
                          : context.tr('patient.askAi'),
                      body: recommended
                          ? recommendationReason
                          : active
                          ? scanningBody
                          : context.tr('patient.sayOrType'),
                    ),
                  ),
                ),
              ),
              Positioned(
                bottom: 24 + robotFloat,
                child: Transform.translate(
                  offset: Offset(robotDrift, 0),
                  child: Transform.scale(
                    scale: pulse,
                    child: CustomPaint(
                      size: const Size(68, 58),
                      painter: _PatientAiRobotPainter(
                        color: AppColors.primary,
                        muted: muted,
                        wave: robotWave,
                      ),
                    ),
                  ),
                ),
              ),
              Positioned(
                bottom: 12,
                child: _AiTypingDots(progress: phase, active: active),
              ),
            ],
          ),
        );
      },
    );
  }
}

double _finiteDouble(double value, {double fallback = 0.0}) {
  return value.isFinite ? value : fallback;
}

class _AiMessageBubble extends StatelessWidget {
  const _AiMessageBubble({required this.title, required this.body});

  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minHeight: 76),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF626B70),
        borderRadius: BorderRadius.circular(5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.18),
            blurRadius: 14,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              const CircleAvatar(
                radius: 10,
                backgroundColor: Colors.white,
                child: Icon(
                  Icons.auto_awesome_rounded,
                  size: 12,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const Icon(Icons.star_rounded, size: 12, color: Colors.white),
              const Icon(Icons.star_rounded, size: 12, color: Colors.white),
              const Icon(Icons.star_rounded, size: 12, color: Colors.white),
            ],
          ),
          const SizedBox(height: 9),
          Text(
            body,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.78),
              fontSize: 11,
              fontWeight: FontWeight.w600,
              height: 1.25,
            ),
          ),
        ],
      ),
    );
  }
}

class _AiGhostCard extends StatelessWidget {
  const _AiGhostCard({required this.height, required this.color});

  final double height;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(4),
      ),
    );
  }
}

class _AiTypingDots extends StatelessWidget {
  const _AiTypingDots({required this.progress, required this.active});

  final double progress;
  final bool active;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(4, (i) {
        final selected = active && ((progress * 8).floor() % 4 == i);
        return AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          margin: const EdgeInsets.symmetric(horizontal: 2),
          width: selected ? 6 : 4,
          height: selected ? 6 : 4,
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: selected ? 0.95 : 0.4),
            shape: BoxShape.circle,
          ),
        );
      }),
    );
  }
}

class _PatientAiRobotPainter extends CustomPainter {
  _PatientAiRobotPainter({
    required this.color,
    required this.muted,
    required this.wave,
  });

  final Color color;
  final Color muted;
  final double wave;

  @override
  void paint(Canvas canvas, Size size) {
    final safeWave = wave.isFinite ? wave.clamp(-1.0, 1.0) : 0.0;
    final paint = Paint()..isAntiAlias = true;
    paint.color = muted.withValues(alpha: 0.22);
    canvas.drawCircle(
      Offset(size.width * 0.5, size.height * 0.54),
      size.width * 0.46,
      paint,
    );

    final body = RRect.fromRectAndRadius(
      Rect.fromCenter(
        center: Offset(size.width * 0.5, size.height * 0.54),
        width: size.width * 0.56,
        height: size.height * 0.44,
      ),
      const Radius.circular(12),
    );

    paint.color = Colors.white.withValues(alpha: 0.92);
    canvas.drawRRect(body, paint);
    paint
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6
      ..color = color.withValues(alpha: 0.34);
    canvas.drawRRect(body, paint);

    paint.style = PaintingStyle.fill;
    paint.color = color;
    canvas.drawCircle(
      Offset(size.width * 0.41, size.height * 0.50),
      2.7,
      paint,
    );
    canvas.drawCircle(
      Offset(size.width * 0.59, size.height * 0.50),
      2.7,
      paint,
    );

    paint
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(
      Rect.fromCenter(
        center: Offset(size.width * 0.5, size.height * 0.59),
        width: 13,
        height: 8,
      ),
      0,
      3.14,
      false,
      paint,
    );
    canvas.drawLine(
      Offset(size.width * 0.5, size.height * 0.32),
      Offset(size.width * 0.5, size.height * 0.17),
      paint,
    );
    paint.style = PaintingStyle.fill;
    canvas.drawCircle(Offset(size.width * 0.5, size.height * 0.15), 3.4, paint);
    canvas.drawCircle(
      Offset(size.width * 0.18, size.height * (0.54 - 0.06 * safeWave)),
      4,
      paint,
    );
    canvas.drawCircle(Offset(size.width * 0.82, size.height * 0.54), 4, paint);
  }

  @override
  bool shouldRepaint(covariant _PatientAiRobotPainter oldDelegate) {
    return oldDelegate.color != color ||
        oldDelegate.muted != muted ||
        oldDelegate.wave != wave;
  }
}

/// Subtle EKG + shield cross motif behind the home header (reference art).
class _HeaderEkgDecorationPainter extends CustomPainter {
  _HeaderEkgDecorationPainter({required this.lineColor, this.glow = false});

  final Color lineColor;
  final bool glow;

  @override
  void paint(Canvas canvas, Size size) {
    final p = Path();
    double x = 0;
    double y = size.height * 0.45;
    p.moveTo(x, y);
    while (x < size.width + 40) {
      x += 18;
      p.lineTo(x, y);
      x += 10;
      y = size.height * 0.38;
      p.lineTo(x, y);
      x += 10;
      y = size.height * 0.52;
      p.lineTo(x, y);
      x += 6;
      y = size.height * 0.45;
      p.lineTo(x, y);
    }
    final ekg = Paint()
      ..color = lineColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = glow ? 1.6 : 1.1
      ..strokeCap = StrokeCap.round;
    if (glow) {
      canvas.drawPath(
        p,
        Paint()
          ..color = lineColor.withValues(alpha: 0.45)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3.2
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2),
      );
    }
    canvas.drawPath(p, ekg);

    final cx = size.width * 0.78;
    final cy = size.height * 0.22;
    final r = RRect.fromRectAndRadius(
      Rect.fromCenter(center: Offset(cx, cy), width: 36, height: 42),
      const Radius.circular(10),
    );
    final sh = Paint()
      ..color = lineColor.withValues(alpha: glow ? 0.5 : 0.35)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;
    canvas.drawRRect(r, sh);
    final cross = Paint()
      ..color = lineColor.withValues(alpha: glow ? 0.85 : 0.65)
      ..strokeWidth = 1.4
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(Offset(cx - 6, cy), Offset(cx + 6, cy), cross);
    canvas.drawLine(Offset(cx, cy - 8), Offset(cx, cy + 8), cross);
  }

  @override
  bool shouldRepaint(covariant _HeaderEkgDecorationPainter oldDelegate) {
    return oldDelegate.lineColor != lineColor || oldDelegate.glow != glow;
  }
}
