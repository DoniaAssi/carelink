// ignore_for_file: unused_element, unused_field, unused_element_parameter

import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:geocoding/geocoding.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;

import 'package:carelink/core/app_colors.dart';
import 'package:carelink/core/app_localizations.dart';
import 'package:carelink/core/locale_controller.dart';
import 'package:carelink/core/patient_home_palette.dart';
import 'package:carelink/core/profile_avatar.dart'
    show profileAvatarOrPlaceholder, profileImageUrlFromMap;
import 'package:carelink/core/theme_controller.dart';
import 'package:carelink/shared/models/appointment_model.dart';
import 'package:carelink/shared/models/provider_model.dart';
import 'package:carelink/shared/services/api_service.dart';
import 'package:carelink/shared/services/notification_center.dart';
import 'package:carelink/features/patient/screens/patient_favorites_screen.dart';
import 'package:carelink/shared/services/patient_favorites_service.dart';
import 'package:carelink/shared/services/location_service.dart';
import 'package:carelink/features/ai/care_intent_parser.dart';

import 'package:carelink/shared/services/medical_record_service.dart';
import 'package:carelink/features/patient/widgets/patient_navigation_shell.dart';
import 'package:carelink/features/patient/widgets/patient_shared_widgets.dart';
import 'package:carelink/features/patient/services/patient_care_summary.dart';
import 'package:carelink/features/ai/provider_smart_match.dart';
import 'booking_details_screen.dart';
import 'booking_start_screen.dart';
import 'messages_screen.dart';
import 'chat_screen.dart';
import 'package:carelink/features/notifications/notifications_screen.dart';
import 'edit_profile_screen.dart';
import 'provider_details_screen.dart';
import 'providers_screen.dart';
import 'package:carelink/features/patient/screens/booking_screen.dart';
import 'package:carelink/features/patient/utils/booking_service_helper.dart';
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
  bool get _ar => localeController.isArabic;
  String _homeText(String en, String ar) => _ar ? ar : en;

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
  Map<String, Map<String, dynamic>> _backendRecommendations = {};
  AppointmentModel? _upcomingAppointment;
  int _medicalRecordsCount = 0;
  int _processedRecordsCount = 0;
  List<Map<String, dynamic>> _recentRecords = [];
  double? _patientLat;
  double? _patientLng;
  List<Map<String, dynamic>> _myFavorites = [];
  Map<String, dynamic>? _patientProfile;
  PatientCareSummary _careSummary = PatientCareSummary.empty;
  final LocationService _locationService = LocationService();
  final TextEditingController _careSearchController = TextEditingController();
  int _unreadNotifications = 0;
  List<Map<String, dynamic>> _latestNotifications = [];
  AppointmentModel? _ratingPromptAppointment;
  bool _loadingRatingPrompt = false;
  bool _ratingBannerHiddenThisSession = false;
  bool _submittingPromptRating = false;
  int _promptRatingStars = 0;
  late final AnimationController _aiAnimationController;
  final stt.SpeechToText _speech = stt.SpeechToText();
  Timer? _careSearchDebounce;

  String? _resolvedGeocodeAddress;

  String _shortenAddress(String address) {
    if (address.isEmpty) return '';
    String cleaned = address
        .replaceAll(
          RegExp(r'Palestinian Territories', caseSensitive: false),
          'Palestine',
        )
        .replaceAll(
          RegExp(r'Palestinian Territory', caseSensitive: false),
          'Palestine',
        );
    cleaned = cleaned.replaceAll(
      RegExp(r'\bArea\s+[A-Z]\b', caseSensitive: false),
      '',
    );

    final parts = cleaned
        .split(',')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .fold<List<String>>([], (list, e) {
          if (!list.contains(e)) list.add(e);
          return list;
        });

    if (parts.isEmpty) return '';
    if (parts.length <= 2) {
      return parts.join(', ');
    }

    final filteredParts = parts.where((p) {
      if (RegExp(r'^\d+$').hasMatch(p)) return false;
      return true;
    }).toList();

    if (filteredParts.isEmpty) return parts.first;

    final first = filteredParts.first;
    final hasWestBank = filteredParts.any(
      (p) => p.toLowerCase() == 'west bank',
    );
    final hasPalestine = filteredParts.any(
      (p) => p.toLowerCase() == 'palestine',
    );

    if (hasWestBank) {
      if (first.toLowerCase() != 'west bank') {
        return '$first, West Bank';
      }
    }
    if (hasPalestine) {
      if (first.toLowerCase() != 'palestine') {
        return '$first, Palestine';
      }
    }
    if (filteredParts.length >= 2) {
      return '${filteredParts[0]}, ${filteredParts[1]}';
    }
    return first;
  }

  Future<void> _reverseGeocodeCoords(double lat, double lng) async {
    try {
      final placemarks = await placemarkFromCoordinates(
        lat,
        lng,
      ).timeout(const Duration(seconds: 4));
      if (placemarks.isNotEmpty) {
        final p = placemarks.first;
        final streetClean = (p.street ?? '').toLowerCase().contains('area ')
            ? null
            : p.street;
        final subLocalityClean =
            (p.subLocality ?? '').toLowerCase().contains('area ')
            ? null
            : p.subLocality;
        final localityClean = p.locality;
        final subAdminAreaClean =
            (p.subAdministrativeArea ?? '').toLowerCase().contains('area ')
            ? null
            : p.subAdministrativeArea;
        final adminAreaClean =
            (p.administrativeArea ?? '').toLowerCase().contains('area ')
            ? null
            : p.administrativeArea;

        var countryClean = p.country ?? '';
        if (countryClean.toLowerCase() == 'palestinian territories' ||
            countryClean.toLowerCase().contains('palestinian')) {
          countryClean = 'Palestine';
        }

        final parts = <String>[];
        if (streetClean != null && streetClean.isNotEmpty) {
          parts.add(streetClean);
        }
        if (subLocalityClean != null && subLocalityClean.isNotEmpty) {
          parts.add(subLocalityClean);
        }
        if (localityClean != null && localityClean.isNotEmpty) {
          parts.add(localityClean);
        }
        if (subAdminAreaClean != null && subAdminAreaClean.isNotEmpty) {
          parts.add(subAdminAreaClean);
        }
        if (adminAreaClean != null && adminAreaClean.isNotEmpty) {
          parts.add(adminAreaClean);
        }
        if (countryClean.isNotEmpty) parts.add(countryClean);

        final addressStr = parts.join(', ');
        if (addressStr.trim().isNotEmpty) {
          if (mounted) {
            setState(() {
              _resolvedGeocodeAddress = addressStr;
            });
          }
          return;
        }
      }
    } catch (_) {}

    try {
      final uri = Uri.parse(
        'https://nominatim.openstreetmap.org/reverse?format=jsonv2&lat=$lat&lon=$lng&zoom=18&addressdetails=1',
      );
      final response = await http
          .get(
            uri,
            headers: const <String, String>{
              'User-Agent': 'carelink.app/1.0 (reverse-geocoding-home)',
            },
          )
          .timeout(const Duration(seconds: 4));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data is Map<String, dynamic>) {
          final addressStr = (data['display_name'] ?? '').toString().trim();
          if (addressStr.isNotEmpty && mounted) {
            setState(() {
              _resolvedGeocodeAddress = addressStr;
            });
          }
        }
      }
    } catch (_) {}
  }

  String get _locationText {
    final profileAddress =
        _patientProfile?['addressText']?.toString() ??
        _patientProfile?['address']?.toString() ??
        '';
    if (profileAddress.trim().isNotEmpty) {
      return _shortenAddress(profileAddress);
    }
    if (_resolvedGeocodeAddress != null &&
        _resolvedGeocodeAddress!.trim().isNotEmpty) {
      return _shortenAddress(_resolvedGeocodeAddress!);
    }
    return _homeText('Location not set', 'لم يتم تحديد الموقع');
  }

  String get _dynamicGreeting {
    final hour = DateTime.now().hour;
    final name = _firstName;
    if (_ar) {
      final greeting = hour < 12 ? 'صباح الخير' : 'مساء الخير';
      return '$greeting، $name';
    } else {
      final String greeting;
      if (hour < 12) {
        greeting = 'Good morning';
      } else if (hour < 17) {
        greeting = 'Good afternoon';
      } else {
        greeting = 'Good evening';
      }
      return '$greeting, $name';
    }
  }

  String _weekdayLabel(int weekday) {
    const en = ['', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    const ar = [
      '',
      'الإثنين',
      'الثلاثاء',
      'الأربعاء',
      'الخميس',
      'الجمعة',
      'السبت',
      'الأحد',
    ];
    if (weekday < 1 || weekday > 7) return '';
    return _ar ? ar[weekday] : en[weekday];
  }

  Color _appointmentStatusColor(String status) {
    switch (status.toLowerCase().trim()) {
      case 'pending':
        return const Color(0xFFEF6C00);
      case 'completed':
        return const Color(0xFF2E7D32);
      case 'cancelled':
        return const Color(0xFFC62828);
      case 'upcoming':
      case 'confirmed':
      default:
        return const Color(0xFF21A35B);
    }
  }

  String _appointmentStatusText(String status) {
    final s = status.toLowerCase().trim();
    if (_ar) {
      switch (s) {
        case 'pending':
          return 'بانتظار الرد';
        case 'completed':
          return 'مكتمل';
        case 'cancelled':
          return 'ملغي';
        case 'upcoming':
        case 'confirmed':
        default:
          return 'مؤكد';
      }
    } else {
      switch (s) {
        case 'pending':
          return 'Pending';
        case 'completed':
          return 'Completed';
        case 'cancelled':
          return 'Cancelled';
        case 'upcoming':
        case 'confirmed':
        default:
          return 'Confirmed';
      }
    }
  }

  /// Mirrors the field text — on Flutter web, reading [TextEditingController.text]
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

  List<_HomeQuickService> get _quickServices => const [
    // Doctors
    _HomeQuickService(
      titleEn: 'General doctor',
      titleAr: 'طبيب عام',
      serviceType: 'Doctor Consultation',
      icon: Icons.medical_services_outlined,
      terms: ['doctor', 'general', 'physician'],
      category: 'doctors',
    ),
    _HomeQuickService(
      titleEn: 'Specialist doctor',
      titleAr: 'طبيب أخصائي',
      serviceType: 'Specialist Consultation',
      icon: Icons.medical_information_outlined,
      terms: ['specialist', 'cardiology', 'endocrin', 'consultant'],
      category: 'doctors',
    ),
    // Nursing
    _HomeQuickService(
      titleEn: 'Home nurse',
      titleAr: 'ممرض منزلي',
      serviceType: 'Home Nursing Care',
      icon: Icons.health_and_safety_outlined,
      terms: ['nurse', 'nursing', 'home nursing'],
      category: 'nursing',
    ),
    _HomeQuickService(
      titleEn: 'Elderly care',
      titleAr: 'رعاية كبار السن',
      serviceType: 'Elderly Care',
      icon: Icons.elderly_outlined,
      terms: ['elderly', 'senior', 'geriatric'],
      category: 'nursing',
    ),
    _HomeQuickService(
      titleEn: 'Post surgery care',
      titleAr: 'رعاية بعد العمليات',
      serviceType: 'Follow-up Visit',
      icon: Icons.healing_outlined,
      terms: ['post surgery', 'post operation', 'post-op', 'surgery', 'wound'],
      category: 'nursing',
    ),
    // Therapy
    _HomeQuickService(
      titleEn: 'Physiotherapy',
      titleAr: 'علاج طبيعي',
      serviceType: 'Physiotherapy',
      icon: Icons.accessibility_new_rounded,
      terms: ['physio', 'physiotherapy', 'physical', 'therapy', 'rehab'],
      category: 'therapy',
    ),
    _HomeQuickService(
      titleEn: 'Rehabilitation',
      titleAr: 'إعادة تأهيل',
      serviceType: 'Rehabilitation',
      icon: Icons.directions_walk_rounded,
      terms: ['rehab', 'rehabilitation', 'recovery', 'physical'],
      category: 'therapy',
    ),
    _HomeQuickService(
      titleEn: 'Mental support',
      titleAr: 'دعم نفسي',
      serviceType: 'Mental Health',
      icon: Icons.psychology_alt_outlined,
      terms: ['mental', 'psych', 'psychology', 'psychiatry'],
      category: 'therapy',
    ),
  ];

  static const List<({String key, String en, String ar, IconData icon})>
  _serviceCategories = [
    (
      key: 'doctors',
      en: 'Doctors',
      ar: 'الأطباء',
      icon: Icons.local_hospital_outlined,
    ),
    (
      key: 'nursing',
      en: 'Nursing',
      ar: 'التمريض',
      icon: Icons.health_and_safety_outlined,
    ),
    (
      key: 'therapy',
      en: 'Therapy',
      ar: 'العلاج',
      icon: Icons.accessibility_new_rounded,
    ),
  ];

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
    _loadRatingPrompt();
    _loadFavorites();
    _loadMedicalSummary();
    notificationCenter.addListener(_onNotificationsChanged);
    _loadNotificationCount();
  }

  @override
  void dispose() {
    _careSearchDebounce?.cancel();
    _speech.stop();
    _aiAnimationController.dispose();
    _careSearchController.dispose();
    notificationCenter.removeListener(_onNotificationsChanged);
    super.dispose();
  }

  Future<void> _loadNotificationCount() async {
    final id = widget.userId?.trim();
    if (id == null || id.isEmpty) return;
    await notificationCenter.load(id, force: true);
    _onNotificationsChanged();
  }

  void _onNotificationsChanged() {
    if (!mounted) return;
    setState(() {
      _unreadNotifications = notificationCenter.unreadCount;
      _latestNotifications = notificationCenter.items.take(3).toList();
    });
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
    if (_backendRecommendations.isNotEmpty) {
      final ids = list.map((p) => p.userId).toSet();
      for (final id in _backendRecommendations.keys) {
        if (ids.contains(id)) {
          return list.firstWhere((p) => p.userId == id);
        }
      }
    }
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
        _backendRecommendations[provider.userId] ?? provider,
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
    if (reasons.isEmpty) {
      final backend = _backendRecommendations[provider.userId];
      if (backend != null) {
        return ProviderSmartMatch.recommendationReason(backend, summary);
      }
      return ProviderSmartMatch.recommendationReason(
        provider,
        recommendationSummary,
      );
    }
    return 'Recommended based on your medical records and care needs: ${reasons.join(', ')}.';
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
    final id = widget.userId?.trim();
    if (id == null || id.isEmpty) return;
    try {
      final favs = await PatientFavoritesService.getFavorites(id);
      if (!mounted) return;
      setState(() => _myFavorites = favs);
    } catch (_) {}
  }

  Future<void> _loadPatientLocation() async {
    try {
      final pos = await LocationService().getCurrentPosition();
      if (!mounted) return;
      setState(() {
        _patientLat = pos.latitude;
        _patientLng = pos.longitude;
      });
      final profileAddress =
          _patientProfile?['addressText']?.toString() ??
          _patientProfile?['address']?.toString() ??
          '';
      if (profileAddress.trim().isEmpty) {
        _reverseGeocodeCoords(pos.latitude, pos.longitude);
      }
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

  bool _appointmentNeedsRating(AppointmentModel a) {
    final status = a.status.trim().toLowerCase();
    final rated = (a.patientRatingStars ?? 0) > 0;
    return status == 'completed' && !rated;
  }

  Future<void> _loadRatingPrompt() async {
    final id = widget.userId?.trim();
    if (id == null || id.isEmpty) return;
    if (mounted) setState(() => _loadingRatingPrompt = true);
    try {
      final raw = await ApiService().getAppointments(id, status: 'completed');
      AppointmentModel? latest;
      for (final item in raw) {
        if (item is! Map) continue;
        final appointment = AppointmentModel.fromJson(
          Map<String, dynamic>.from(item),
        );
        if (!_appointmentNeedsRating(appointment)) continue;
        final currentDate = appointment.scheduledAt ?? DateTime(1970);
        final latestDate = latest?.scheduledAt ?? DateTime(1970);
        if (latest == null || currentDate.isAfter(latestDate)) {
          latest = appointment;
        }
      }
      if (!mounted) return;
      setState(() {
        _ratingPromptAppointment = latest;
        _promptRatingStars = 0;
        _ratingBannerHiddenThisSession = false;
      });
    } catch (_) {
      if (mounted) setState(() => _ratingPromptAppointment = null);
    } finally {
      if (mounted) setState(() => _loadingRatingPrompt = false);
    }
  }

  void _hideRatingBannerTemporarily() {
    setState(() => _ratingBannerHiddenThisSession = true);
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

  String _monthLabel(int month) {
    const en = [
      '',
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    const ar = [
      '',
      'يناير',
      'فبراير',
      'مارس',
      'أبريل',
      'مايو',
      'يونيو',
      'يوليو',
      'أغسطس',
      'سبتمبر',
      'أكتوبر',
      'نوفمبر',
      'ديسمبر',
    ];
    if (month < 1 || month > 12) return '';
    return _ar ? ar[month] : en[month];
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

  Map<String, dynamic>? _backendRecommendationFor(ProviderModel? provider) {
    if (provider == null) return null;
    return _backendRecommendations[provider.userId];
  }

  int? _backendMatchPercent(Map<String, dynamic>? recommendation) {
    final raw = recommendation?['matchPercentage'];
    if (raw is num) return raw.round().clamp(0, 100);
    final finalScore = recommendation?['finalScore'];
    if (finalScore is num) return (finalScore * 100).round().clamp(0, 100);
    return null;
  }

  int? _backendMedicalMatchPercent(Map<String, dynamic>? recommendation) {
    final raw = recommendation?['medicalMatchScore'];
    if (raw is num) return (raw * 100).round().clamp(0, 100);
    final bd = recommendation?['scoreBreakdown'];
    if (bd is Map) {
      final mc = bd['medicalCompatibility'];
      if (mc is num) return (mc * 100).round().clamp(0, 100);
    }
    return null;
  }

  String? _backendDisplayReason(Map<String, dynamic>? recommendation) {
    final reason =
        recommendation?['displayReason'] ?? recommendation?['aiMatchReason'];
    final text = reason?.toString().trim() ?? '';
    if (text.isNotEmpty && text.toLowerCase() != 'null') return text;
    final reasons = recommendation?['recommendationReasons'];
    if (reasons is List && reasons.isNotEmpty) {
      final first = reasons.first.toString().trim();
      if (first.isNotEmpty) return first;
    }
    return null;
  }

  // Provider-specific matched tags (why THIS provider was recommended)
  List<String> _backendMatchedTags(Map<String, dynamic>? recommendation) {
    for (final key in ['matchedTags', 'matchedTagLabels']) {
      final raw = recommendation?[key];
      if (raw is List && raw.isNotEmpty) {
        return raw
            .map((e) => e.toString().trim())
            .where((e) => e.isNotEmpty && e.toLowerCase() != 'null')
            .take(4)
            .toList();
      }
    }
    return const [];
  }

  List<String> _backendMedicalReasons(Map<String, dynamic>? recommendation) {
    // Prefer provider-specific matchedTags, fall back to patient-level medicalReasons
    final matched = _backendMatchedTags(recommendation);
    if (matched.isNotEmpty) return matched.take(3).toList();
    final raw = recommendation?['medicalReasons'];
    if (raw is! List) return const [];
    return raw
        .map((e) => e.toString().trim())
        .where((e) => e.isNotEmpty && e.toLowerCase() != 'null')
        .take(3)
        .toList();
  }

  List<String> _backendMedicalTags(Map<String, dynamic>? recommendation) {
    // Use matchedTags (provider-specific) for display chips
    final matched = _backendMatchedTags(recommendation);
    if (matched.isNotEmpty) return matched.take(4).toList();
    final raw = recommendation?['medicalTags'];
    if (raw is! List) return const [];
    return raw
        .map((e) => e.toString().trim())
        .where((e) => e.isNotEmpty && e.toLowerCase() != 'null')
        .take(4)
        .toList();
  }

  bool get _hasProcessedMedicalRecords =>
      _processedRecordsCount > 0 ||
      (_backendRecommendations.isNotEmpty &&
          _backendRecommendations.values.any((r) {
            final tags = r['matchedTags'];
            return tags is List && tags.isNotEmpty;
          }));

  /// Convert a raw analysis tag OR already-friendly label into patient-friendly text.
  /// Never emits snake_case. Falls back to title-casing unknown values.
  String _friendlyReason(String tag) {
    final key = tag.toLowerCase().trim().replaceAll(' ', '_');
    const map = {
      'diabetes': 'Diabetes follow-up support',
      'hypertension': 'Blood pressure management',
      'cholesterol': 'Cholesterol management',
      'cardiovascular_risk': 'Heart health monitoring',
      'medication_followup': 'Medication monitoring',
      'home_nursing': 'Home nursing assistance',
      'blood_pressure_monitoring': 'Blood pressure monitoring',
      'wound_care': 'Wound care support',
      'post_surgery_care': 'Post-surgery recovery care',
      'elderly_care': 'Elderly care support',
      'cardiology': 'Heart health specialist',
      'endocrinology': 'Diabetes & hormone specialist',
    };
    final ar = {
      'diabetes': 'متابعة مرض السكري',
      'hypertension': 'إدارة ضغط الدم',
      'cholesterol': 'إدارة الكوليسترول',
      'cardiovascular_risk': 'مراقبة صحة القلب',
      'medication_followup': 'مراقبة الأدوية',
      'home_nursing': 'رعاية تمريضية منزلية',
      'blood_pressure_monitoring': 'مراقبة ضغط الدم',
      'wound_care': 'العناية بالجروح',
      'post_surgery_care': 'رعاية ما بعد الجراحة',
      'elderly_care': 'رعاية كبار السن',
      'cardiology': 'أخصائي صحة القلب',
      'endocrinology': 'أخصائي السكري والغدد',
    };
    if (_ar && ar.containsKey(key)) return ar[key]!;
    if (map.containsKey(key)) return map[key]!;
    // Already-friendly label (contains spaces / not a known tag) → use as-is.
    if (tag.contains(' ')) return tag;
    return key
        .split('_')
        .where((w) => w.isNotEmpty)
        .map((w) => '${w[0].toUpperCase()}${w.substring(1)}')
        .join(' ');
  }

  /// Patient-level tags shared across recommendations (medicalTags), de-duplicated.
  List<String> _patientLevelTags() {
    for (final rec in _backendRecommendations.values) {
      final raw = rec['medicalTags'] ?? rec['matchedTags'];
      if (raw is List && raw.isNotEmpty) {
        final seen = <String>{};
        final out = <String>[];
        for (final t in raw) {
          final s = t.toString().trim();
          if (s.isEmpty || s.toLowerCase() == 'null') continue;
          final k = s.toLowerCase();
          if (seen.add(k)) out.add(s);
        }
        if (out.isNotEmpty) return out;
      }
    }
    return const [];
  }

  /// Map tags → ranked patient-friendly specialty names for the specialties section.
  List<String> _specialtyFromTags() {
    final tags = _patientLevelTags().map((t) => t.toLowerCase()).toList();
    final out = <String>[];
    void add(String s) {
      if (!out.contains(s)) out.add(s);
    }

    bool has(String needle) => tags.any((t) => t.contains(needle));

    if (has('endocrin') || has('diabet')) {
      add(_homeText('Endocrinology', 'الغدد الصماء'));
    }
    if (has('cardio') ||
        has('hypertens') ||
        has('cholesterol') ||
        has('cardiovascular')) {
      add(_homeText('Cardiology', 'أمراض القلب'));
    }
    if (has('home_nursing') ||
        has('home nursing') ||
        has('blood_pressure_monitoring') ||
        has('blood pressure') ||
        has('medication')) {
      add(_homeText('Home Nursing', 'تمريض منزلي'));
    }
    if (has('wound') || has('post_surgery') || has('post-surgery')) {
      add(_homeText('Post-Surgery Care', 'رعاية ما بعد الجراحة'));
    }
    if (has('elderly')) {
      add(_homeText('Elderly Care', 'رعاية كبار السن'));
    }
    return out.take(3).toList();
  }

  /// Patient-friendly health insight lines from patient-level tags (max 3).
  List<String> _healthInsightLines() {
    final tags = _patientLevelTags();
    if (tags.isEmpty) return const [];
    final seen = <String>{};
    final out = <String>[];
    for (final t in tags) {
      final line = _friendlyReason(t);
      if (seen.add(line)) out.add(line);
      if (out.length == 3) break;
    }
    return out;
  }

  Future<void> _fetchProviders() async {
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
      if (!mounted) return;

      setState(() {
        providers = data.map((e) => ProviderModel.fromJson(e)).toList();
        _backendRecommendations = backendRecommendations;
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

      // Sort newest-first using whichever date field is available.
      final sorted = List<Map<String, dynamic>>.from(clinical)
        ..sort((a, b) {
          final at = _recordDate(a)?.millisecondsSinceEpoch ?? 0;
          final bt = _recordDate(b)?.millisecondsSinceEpoch ?? 0;
          return bt.compareTo(at);
        });
      final processed = sorted
          .where((r) => _recordStatus(r) == 'processed')
          .length;

      setState(() {
        final base = PatientCareSummary.mergeBaseline(
          PatientCareSummary.empty,
          profile,
        );
        _careSummary = PatientCareSummary.mergeClinical(base, clinical);
        _medicalRecordsCount = clinical.length;
        _processedRecordsCount = processed;
        _recentRecords = sorted.take(3).toList();
      });
    } catch (_) {
      if (mounted) {
        setState(() {
          _careSummary = PatientCareSummary.empty;
          _medicalRecordsCount = 0;
          _processedRecordsCount = 0;
          _recentRecords = [];
        });
      }
    }
  }

  /// Normalized AI status for a record map ('processed' | 'processing' | 'failed' | 'pending').
  String _recordStatus(Map<String, dynamic> r) {
    final raw =
        (r['aiStatus'] ??
                r['ai_status'] ??
                r['extracted_text_status'] ??
                r['extractedTextStatus'] ??
                '')
            .toString()
            .toLowerCase()
            .trim();
    if (raw == 'processed') return 'processed';
    if (raw == 'failed') return 'failed';
    if (raw == 'processing') return 'processing';
    return 'pending';
  }

  DateTime? _recordDate(Map<String, dynamic> r) {
    final raw =
        (r['created_at'] ??
                r['createdAt'] ??
                r['visit_date'] ??
                r['uploadDate'] ??
                '')
            .toString();
    return DateTime.tryParse(raw);
  }

  String _recordTitle(Map<String, dynamic> r) {
    final t = (r['title'] ?? r['file_name'] ?? r['fileName'] ?? '')
        .toString()
        .trim();
    return t.isNotEmpty ? t : _homeText('Medical record', 'سجل طبي');
  }

  String? _recordSummaryLine(Map<String, dynamic> r) {
    final s =
        (r['aiSummary'] ??
                r['ai_summary'] ??
                r['medical_summary'] ??
                r['medicalSummary'] ??
                '')
            .toString()
            .replaceAll(RegExp(r'\s+'), ' ')
            .trim();
    if (s.isEmpty || s.toLowerCase() == 'null') return null;
    return s;
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

  void _openBookingFlow() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => BookingStartScreen(patientUserId: widget.userId ?? ''),
      ),
    );
  }

  void _openSchedule() {
    PatientNavigationShell.switchTab(context, 2);
  }

  void _openBookings() {
    PatientNavigationShell.switchTab(context, 1);
  }

  void _openMessages() {
    final apt = _upcomingAppointment;
    if (apt != null && apt.providerUserId.isNotEmpty) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ChatScreen(
            name: apt.providerName.isNotEmpty
                ? apt.providerName
                : 'Care Provider',
            userId: widget.userId ?? '',
            doctorId: apt.providerUserId,
          ),
        ),
      );
    } else {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => MessagesScreen(userId: widget.userId ?? ''),
        ),
      );
    }
  }

  void _openProfile() {
    PatientNavigationShell.switchTab(context, 4);
  }

  void _openMedicalRecords() {
    PatientNavigationShell.switchTab(context, 3);
  }

  void _openNotifications() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => NotificationsScreen(userId: widget.userId),
      ),
    );
  }

  void _openAiAssistant() {
    Navigator.pushNamed(
      context,
      '/find-provider',
      arguments: {'userId': widget.userId ?? '', 'displayName': userName},
    );
  }

  void _openQuickServiceBooking(_HomeQuickService service) {
    final matched = providers.where((provider) {
      final role = _lowerText(provider.role);
      final specialization = _lowerText(provider.specialization);
      final serviceType = _lowerText(provider.serviceType);
      return service.terms.any(
        (term) =>
            role.contains(term) ||
            specialization.contains(term) ||
            serviceType.contains(term),
      );
    }).toList();

    final sorted = ProviderSmartMatch.sortCopy(
      matched,
      selectedSpecialty: service.serviceType,
      locationService: _locationService,
      patientLat: _patientLat,
      patientLng: _patientLng,
      careSummary: _recommendationSummary,
    );

    if (sorted.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _homeText(
              'No providers are available for this service right now.',
              'لا يوجد مزودون متاحون لهذه الخدمة حالياً.',
            ),
          ),
        ),
      );
      return;
    }

    final provider = sorted.first;
    final request = BookingServiceHelper.createRequestForProvider(
      provider: provider,
      patientId: widget.userId ?? '',
    );

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => BookingScreen(
          request: request,
        ),
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
        _openBookings();
        break;
      case 2:
        _openSchedule();
        break;
      case 3:
        _openMedicalRecords();
        break;
      case 4:
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
    final recommended = _backendRecommendations.isNotEmpty
        ? (List<ProviderModel>.from(providers)..sort((a, b) {
            final bs = _backendRecommendations[b.userId]?['finalScore'];
            final aRawScore = _backendRecommendations[a.userId]?['finalScore'];
            final bScore = bs is num ? bs.toDouble() : 0.0;
            final aScore = aRawScore is num ? aRawScore.toDouble() : 0.0;
            return bScore.compareTo(aScore);
          }))
        : ProviderSmartMatch.sortCopy(
            providers,
            selectedSpecialty: selectedSpecialty,
            locationService: _locationService,
            patientLat: _patientLat,
            patientLng: _patientLng,
            careSummary: _recommendationSummary,
          );

    return AnimatedBuilder(
      animation: Listenable.merge([localeController, themeController]),
      builder: (context, _) {
        return Directionality(
          textDirection: localeController.isArabic
              ? TextDirection.rtl
              : TextDirection.ltr,
          child: Scaffold(
            backgroundColor: _p.pageBg,
            body: SafeArea(
              child: Stack(
                children: [
                  RefreshIndicator(
                    color: AppColors.primary,
                    onRefresh: () async {
                      await _fetchProviders();
                      await _loadPatientProfile();
                      await _fetchUpcomingAppointment();
                      await _loadRatingPrompt();
                      await _loadPatientLocation();
                      await _loadFavorites();
                      await _loadMedicalSummary();
                    },
                    child: SingleChildScrollView(
                      physics: const AlwaysScrollableScrollPhysics(
                        parent: BouncingScrollPhysics(),
                      ),
                      padding: const EdgeInsets.fromLTRB(0, 16, 0, 90),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: _composeSections(recommended),
                      ),
                    ),
                  ),
                  if (_ratingPromptAppointment != null &&
                      !_ratingBannerHiddenThisSession)
                    _buildRatingBannerOverlay(_ratingPromptAppointment!),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  /// Section registry. Add a future section by inserting one entry here —
  /// no layout surgery, uniform spacing, empty sections auto-collapse.
  /// Section registry — new priority order per the approved redesign.
  /// To add a future section: insert one line here, no layout surgery needed.
  List<Widget> _composeSections(List<ProviderModel> recommended) {
    Widget padded(Widget child) => Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: child,
    );

    final sections = <Widget?>[
      padded(_buildCompactHeader()),
      padded(_buildRecommendationCarousel(recommended)),
      _buildNextAppointmentCard(),
      padded(_buildQuickActions()),
      _buildFavoritesSection(),
      if (_recentRecords.isNotEmpty) padded(_buildLatestRecordCard()),
      padded(_buildHealthInsightsSection()),
    ];

    final visible = sections.whereType<Widget>().toList();
    final out = <Widget>[const SizedBox(height: 4)];
    for (var i = 0; i < visible.length; i++) {
      if (i > 0) out.add(const SizedBox(height: 20));
      out.add(visible[i]);
    }
    return out;
  }

  String _ratingPromptDate(DateTime? date) {
    if (date == null) return _homeText('Completed visit', 'زيارة مكتملة');
    const enMonths = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    const arMonths = [
      'يناير',
      'فبراير',
      'مارس',
      'أبريل',
      'مايو',
      'يونيو',
      'يوليو',
      'أغسطس',
      'سبتمبر',
      'أكتوبر',
      'نوفمبر',
      'ديسمبر',
    ];
    final months = _ar ? arMonths : enMonths;
    return '${date.day} ${months[date.month - 1]} ${date.year}';
  }

  String _ratingServiceName(AppointmentModel a) {
    final specialty = a.specialization.trim();
    if (specialty.isNotEmpty) return specialty;
    final role = a.providerRole.trim();
    if (role.isNotEmpty) return role;
    return _homeText('Care visit', 'زيارة رعاية');
  }

  Widget _buildRatingBannerOverlay(AppointmentModel appointment) {
    final providerName = appointment.providerName.trim().isEmpty
        ? _homeText('Care Provider', 'مقدم الرعاية')
        : appointment.providerName.trim();
    final maxHeight = MediaQuery.sizeOf(context).height * 0.25;
    return Positioned(
      top: 10,
      left: 12,
      right: 12,
      child: AnimatedSlide(
        duration: const Duration(milliseconds: 260),
        curve: Curves.easeOutCubic,
        offset: Offset.zero,
        child: Material(
          color: Colors.transparent,
          elevation: 12,
          borderRadius: BorderRadius.circular(22),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: maxHeight.clamp(154.0, 210.0),
            ),
            child: Container(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
              decoration: BoxDecoration(
                color: _p.surface,
                borderRadius: BorderRadius.circular(22),
                border: Border.all(
                  color: AppColors.primary.withValues(alpha: 0.24),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(
                      alpha: _p.isDark ? 0.32 : 0.14,
                    ),
                    blurRadius: 24,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 42,
                        height: 42,
                        clipBehavior: Clip.antiAlias,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: AppColors.primary.withValues(alpha: 0.12),
                        ),
                        child: profileAvatarOrPlaceholder(
                          imageUrl: appointment.providerImageUrl,
                          size: 42,
                          placeholderColor: AppColors.primary,
                          placeholderIcon: Icons.medical_services_outlined,
                          iconSize: 21,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _homeText(
                                'Your visit with $providerName is completed',
                                'تم إكمال زيارتك مع $providerName',
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: _p.inkDark,
                                fontSize: 13.5,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              _homeText(
                                'How was your experience?',
                                'كيف كانت تجربتك؟',
                              ),
                              style: TextStyle(
                                color: _p.inkMuted,
                                fontSize: 12.5,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        tooltip: _homeText('Later', 'لاحقًا'),
                        onPressed: _hideRatingBannerTemporarily,
                        icon: Icon(
                          Icons.close_rounded,
                          color: _p.inkMuted,
                          size: 20,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Directionality(
                    textDirection: TextDirection.ltr,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(5, (index) {
                        final value = index + 1;
                        final selected = value <= _promptRatingStars;
                        return IconButton(
                          visualDensity: VisualDensity.compact,
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(
                            minWidth: 36,
                            minHeight: 32,
                          ),
                          onPressed: _submittingPromptRating
                              ? null
                              : () =>
                                    setState(() => _promptRatingStars = value),
                          icon: TweenAnimationBuilder<double>(
                            tween: Tween(begin: 0, end: selected ? 1 : 0),
                            duration: const Duration(milliseconds: 210),
                            curve: Curves.easeOutBack,
                            builder: (context, t, child) => Transform.scale(
                              scale: 1 + (0.18 * t),
                              child: child,
                            ),
                            child: Icon(
                              selected
                                  ? Icons.star_rounded
                                  : Icons.star_border_rounded,
                              color: const Color(0xFFFFB020),
                              size: 29,
                            ),
                          ),
                        );
                      }),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: _submittingPromptRating
                              ? null
                              : _hideRatingBannerTemporarily,
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.primary,
                            side: const BorderSide(color: AppColors.primary),
                            minimumSize: const Size.fromHeight(38),
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                          child: Text(_homeText('Later', 'لاحقًا')),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: PatientPrimaryButton(
                          height: 38,
                          icon: Icons.send_rounded,
                          isLoading: _submittingPromptRating,
                          label: _homeText('Submit Rating', 'إرسال التقييم'),
                          onPressed:
                              _promptRatingStars < 1 || _submittingPromptRating
                              ? null
                              : () => _submitPromptRating(
                                  appointment,
                                  _promptRatingStars,
                                ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _showRatingPromptSheet(AppointmentModel appointment) async {
    if (_submittingPromptRating) return;
    setState(() => _promptRatingStars = 0);
    await showModalBottomSheet<void>(
      context: context,
      useSafeArea: true,
      showDragHandle: true,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        var localStars = _promptRatingStars;
        return StatefulBuilder(
          builder: (context, setSheetState) {
            final p = PatientHomePalette.of(context);
            return Container(
              margin: const EdgeInsets.fromLTRB(14, 0, 14, 14),
              padding: const EdgeInsets.fromLTRB(18, 10, 18, 18),
              decoration: BoxDecoration(
                color: p.surface,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: p.stroke),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(
                      alpha: p.isDark ? 0.30 : 0.12,
                    ),
                    blurRadius: 24,
                    offset: const Offset(0, 12),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 58,
                    height: 58,
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.check_circle_rounded,
                      color: AppColors.primary,
                      size: 34,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    _homeText(
                      'Visit completed successfully',
                      'تم إكمال الزيارة بنجاح',
                    ),
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: p.inkDark,
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    _homeText('How was your experience?', 'كيف كانت تجربتك؟'),
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: p.inkMuted,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Directionality(
                    textDirection: TextDirection.ltr,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(5, (index) {
                        final value = index + 1;
                        final selected = value <= localStars;
                        return IconButton(
                          onPressed: _submittingPromptRating
                              ? null
                              : () {
                                  setState(() => _promptRatingStars = value);
                                  setSheetState(() => localStars = value);
                                },
                          icon: TweenAnimationBuilder<double>(
                            tween: Tween(begin: 0, end: selected ? 1 : 0),
                            duration: const Duration(milliseconds: 210),
                            curve: Curves.easeOutBack,
                            builder: (context, t, child) => Transform.scale(
                              scale: 1 + (0.18 * t),
                              child: child,
                            ),
                            child: Icon(
                              selected
                                  ? Icons.star_rounded
                                  : Icons.star_border_rounded,
                              color: const Color(0xFFFFB020),
                              size: 34,
                            ),
                          ),
                        );
                      }),
                    ),
                  ),
                  const SizedBox(height: 14),
                  PatientPrimaryButton(
                    height: 50,
                    icon: Icons.send_rounded,
                    isLoading: _submittingPromptRating,
                    label: _homeText('Submit Rating', 'إرسال التقييم'),
                    onPressed: localStars < 1 || _submittingPromptRating
                        ? null
                        : () async {
                            final navigator = Navigator.of(sheetContext);
                            await _submitPromptRating(appointment, localStars);
                            if (mounted && navigator.canPop()) {
                              navigator.pop();
                            }
                          },
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _submitPromptRating(
    AppointmentModel appointment,
    int stars,
  ) async {
    final id = widget.userId?.trim();
    if (id == null || id.isEmpty) return;
    setState(() => _submittingPromptRating = true);
    try {
      await ApiService().rateCompletedVisit(
        appointmentId: appointment.appointmentId,
        patientUserId: id,
        stars: stars,
      );
      if (!mounted) return;
      setState(() {
        _ratingPromptAppointment = null;
        _promptRatingStars = 0;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _homeText(
              'Thanks! Your rating was submitted.',
              'شكراً! تم إرسال تقييمك.',
            ),
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
      _loadRatingPrompt();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString().replaceFirst('Exception: ', '')),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) setState(() => _submittingPromptRating = false);
    }
  }

  // ────────────────── SECTION 1 · PROFILE HEADER ─────────────────────
  /// Real patient identity: DB profile image, full name, location, health
  /// status, plus a compact inline stat strip (merges the old overview card).
  Widget _buildProfileHeader() {
    final imageUrl = profileImageUrlFromMap(_patientProfile);
    final status = _healthStatus();
    final fullName = userName.trim().isEmpty
        ? _homeText('Patient', 'مريض')
        : userName.trim();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        // Neutral surface (not a green wash) for high contrast vs the page.
        color: _p.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _p.stroke),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: _p.isDark ? 0.22 : 0.05),
            blurRadius: 16,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Real profile image (DB). profileAvatarOrPlaceholder resolves
              // relative `/uploads/...` paths, base64 data URIs and http URLs,
              // and falls back to the person icon on error/empty.
              InkWell(
                onTap: _openEditFromHero,
                customBorder: const CircleBorder(),
                child: Container(
                  padding: const EdgeInsets.all(2.5),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _p.stroke,
                    border: Border.all(color: AppColors.primary, width: 2),
                  ),
                  child: ClipOval(
                    child: SizedBox(
                      width: 64,
                      height: 64,
                      child: profileAvatarOrPlaceholder(
                        imageUrl: imageUrl,
                        size: 64,
                        placeholderColor: AppColors.primary,
                        placeholderIcon: Icons.person,
                        iconSize: 34,
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
                          : fullName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: _p.inkDark,
                        fontSize: 19,
                        fontWeight: FontWeight.w900,
                        height: 1.1,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(
                          Icons.location_on_outlined,
                          color: AppColors.primary,
                          size: 14,
                        ),
                        const SizedBox(width: 3),
                        Flexible(
                          child: Text(
                            _locationText,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: _p.inkMuted,
                              fontSize: 12.5,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    // Health status pill.
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: status.color.withValues(alpha: 0.14),
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(
                          color: status.color.withValues(alpha: 0.3),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(status.icon, color: status.color, size: 13),
                          const SizedBox(width: 5),
                          Text(
                            status.label,
                            style: TextStyle(
                              color: status.color,
                              fontSize: 11.5,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              _heroMessages(),
              const SizedBox(width: 8),
              _heroBell(),
            ],
          ),
          // Stat strip removed — replaced by compact single-row header above
        ],
      ),
    );
  }

  Widget _headerStat(String value, String label) {
    return Expanded(
      child: Column(
        children: [
          Text(
            value,
            style: TextStyle(
              color: _p.inkDark,
              fontSize: 17,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 1),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: _p.inkMuted,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _headerStatDivider() {
    return Container(
      width: 1,
      height: 26,
      color: AppColors.primary.withValues(alpha: 0.18),
    );
  }

  /// Derive a quick health status from processed records / tags.
  ({String label, Color color, IconData icon}) _healthStatus() {
    if (_patientLevelTags().isNotEmpty) {
      return (
        label: _homeText('Needs Follow-up', 'يحتاج متابعة'),
        color: const Color(0xFFEF8C00),
        icon: Icons.timeline_rounded,
      );
    }
    if (_processedRecordsCount > 0) {
      return (
        label: _homeText('On Track', 'بحالة جيدة'),
        color: const Color(0xFF21A35B),
        icon: Icons.check_circle_outline_rounded,
      );
    }
    if (_medicalRecordsCount > 0) {
      return (
        label: _homeText('Under Review', 'قيد المراجعة'),
        color: const Color(0xFF2196F3),
        icon: Icons.hourglass_bottom_rounded,
      );
    }
    return (
      label: _homeText('Add your records', 'أضف سجلاتك'),
      color: _p.inkMuted,
      icon: Icons.upload_file_outlined,
    );
  }

  // ────────────────── SECTION 2 · PRIMARY ACTIONS ────────────────────
  /// The single navigation hub — large mobile tap targets, no duplicates.
  Widget _buildPrimaryActions() {
    return Row(
      children: [
        Expanded(
          child: _buildActionButton(
            Icons.add_circle_outline_rounded,
            _homeText('Book', 'احجز'),
            _openBookingFlow,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _buildActionButton(
            Icons.search_rounded,
            _homeText('Search', 'ابحث'),
            _openproviders,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _buildActionButton(
            Icons.folder_outlined,
            _homeText('Records', 'السجل'),
            _openMedicalRecords,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _buildActionButton(
            Icons.auto_awesome_rounded,
            _homeText('AI Assistant', 'المساعد'),
            _openAiAssistant,
          ),
        ),
      ],
    );
  }

  Widget _buildActionButton(IconData icon, String label, VoidCallback onTap) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 6),
          decoration: BoxDecoration(
            color: _p.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: _p.stroke),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: _p.isDark ? 0.15 : 0.04),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      AppColors.primary.withValues(
                        alpha: _p.isDark ? 0.22 : 0.15,
                      ),
                      AppColors.primary.withValues(
                        alpha: _p.isDark ? 0.16 : 0.10,
                      ),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, color: AppColors.primary, size: 22),
              ),
              const SizedBox(height: 8),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: _p.inkDark,
                  fontSize: 10.5,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _heroBell() {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        InkWell(
          onTap: _openNotifications,
          customBorder: const CircleBorder(),
          child: Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: _p.surface,
              shape: BoxShape.circle,
              border: Border.all(color: _p.stroke),
            ),
            child: Icon(
              Icons.notifications_none_rounded,
              color: _p.inkDark,
              size: 22,
            ),
          ),
        ),
        if (_unreadNotifications > 0)
          Positioned(
            top: -2,
            right: -2,
            child: Container(
              height: 18,
              constraints: const BoxConstraints(minWidth: 18),
              alignment: Alignment.center,
              padding: const EdgeInsets.symmetric(horizontal: 4),
              decoration: const BoxDecoration(
                color: Color(0xFFE53935),
                shape: BoxShape.circle,
              ),
              child: Text(
                _unreadNotifications > 9 ? '9+' : '$_unreadNotifications',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 9,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _heroMessages() {
    return InkWell(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => MessagesScreen(userId: widget.userId ?? ''),
          ),
        );
      },
      customBorder: const CircleBorder(),
      child: Container(
        width: 42,
        height: 42,
        decoration: BoxDecoration(
          color: _p.surface,
          shape: BoxShape.circle,
          border: Border.all(color: _p.stroke),
        ),
        child: Icon(
          Icons.chat_bubble_outline_rounded,
          color: _p.inkDark,
          size: 22,
        ),
      ),
    );
  }

  Widget _buildHeroChip(IconData icon, String label, VoidCallback onTap) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: _p.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: AppColors.primary.withValues(alpha: 0.20),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: AppColors.primary, size: 16),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  color: _p.inkDark,
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ──────────────────── SECTION 2 · MY CARE OVERVIEW ───────────────────
  Widget _buildCareOverviewSection() {
    final stats =
        <
          ({
            IconData icon,
            String label,
            String value,
            Color color,
            VoidCallback onTap,
          })
        >[
          (
            icon: Icons.event_available_rounded,
            label: _homeText('Appointments', 'المواعيد'),
            value: '${_upcomingAppointment != null ? 1 : 0}',
            color: const Color(0xFF21A35B),
            onTap: _openBookings,
          ),
          (
            icon: Icons.folder_copy_outlined,
            label: _homeText('Records', 'السجلات'),
            value: '$_medicalRecordsCount',
            color: AppColors.primary,
            onTap: _openMedicalRecords,
          ),
          (
            icon: Icons.verified_outlined,
            label: _homeText('Processed', 'تمت المعالجة'),
            value: '$_processedRecordsCount',
            color: AppColors.primary,
            onTap: _openMedicalRecords,
          ),
          (
            icon: Icons.favorite_border_rounded,
            label: _homeText('Favorites', 'المفضلة'),
            value: '${_myFavorites.length}',
            color: const Color(0xFFE5736A),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => PatientFavoritesScreen(
                    patientUserId: widget.userId ?? '',
                  ),
                ),
              ).then((_) => _loadFavorites());
            },
          ),
        ];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionHeader(
            title: _homeText('My care overview', 'نظرة عامة على رعايتي'),
          ),
          const SizedBox(height: 10),
          // GridView keeps cards responsive without hardcoded heights.
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 10,
            crossAxisSpacing: 10,
            childAspectRatio: 2.5,
            children: stats.map(_buildStatCard).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(
    ({
      IconData icon,
      String label,
      String value,
      Color color,
      VoidCallback onTap,
    })
    s,
  ) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: s.onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: _p.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: _p.stroke),
          ),
          child: Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: s.color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(11),
                ),
                child: Icon(s.icon, color: s.color, size: 20),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      s.value,
                      style: TextStyle(
                        color: _p.inkDark,
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    Text(
                      s.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: _p.inkMuted,
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
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

  // ══════════════════════════════════════════════════════════════════════
  //  NEW SECTION BUILDERS  (approved redesign – replaces old ones below)
  // ══════════════════════════════════════════════════════════════════════

  // ── 1 · COMPACT HEADER ──────────────────────────────────────────────
  Widget _buildCompactHeader() {
    final imageUrl = profileImageUrlFromMap(_patientProfile);
    final greeting = _dynamicGreeting;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // Avatar — tappable → edit profile
        InkWell(
          onTap: _openEditFromHero,
          customBorder: const CircleBorder(),
          child: Container(
            padding: const EdgeInsets.all(2),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: _p.stroke,
              border: Border.all(color: AppColors.primary, width: 1.8),
            ),
            child: ClipOval(
              child: SizedBox(
                width: 46,
                height: 46,
                child: profileAvatarOrPlaceholder(
                  imageUrl: imageUrl,
                  size: 46,
                  placeholderColor: AppColors.primary,
                  placeholderIcon: Icons.person,
                  iconSize: 24,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        // Name + greeting + location
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                isProfileLoading ? context.tr('patient.hiLoading') : greeting,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: _p.inkDark,
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                  height: 1.1,
                ),
              ),
              const SizedBox(height: 2),
              Row(
                children: [
                  Icon(
                    Icons.location_on_outlined,
                    color: AppColors.primary,
                    size: 12,
                  ),
                  const SizedBox(width: 3),
                  Flexible(
                    child: Text(
                      _locationText,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: _p.inkMuted,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        // Messages icon
        _heroMessages(),
        const SizedBox(width: 4),
        // Notification bell
        _heroBell(),
        const SizedBox(width: 4),
        // Language toggle
        _headerIconBtn(
          icon: Icons.language_rounded,
          onTap: () => localeController.toggle(),
        ),
        const SizedBox(width: 4),
        // Theme toggle
        ListenableBuilder(
          listenable: themeController,
          builder: (_, child) => _headerIconBtn(
            icon: themeController.isDark
                ? Icons.light_mode_rounded
                : Icons.dark_mode_rounded,
            onTap: () => themeController.toggle(),
          ),
        ),
      ],
    );
  }

  // Small icon button used in the compact header row
  Widget _headerIconBtn({required IconData icon, required VoidCallback onTap}) {
    return SizedBox(
      width: 34,
      height: 34,
      child: IconButton(
        onPressed: onTap,
        icon: Icon(icon),
        iconSize: 23,
        padding: EdgeInsets.zero,
        constraints: const BoxConstraints.tightFor(width: 34, height: 34),
        style: IconButton.styleFrom(
          foregroundColor: AppColors.primary,
          backgroundColor: Colors.transparent,
          shadowColor: Colors.transparent,
          surfaceTintColor: Colors.transparent,
          overlayColor: Colors.transparent,
        ),
      ),
    );
  }

  Widget _buildRecommendationCarousel(List<ProviderModel> recommended) {
    final cards = <Widget>[
      if (recommended.isNotEmpty)
        _providerRecommendationCarouselCard(
          provider: recommended.first,
          title: _homeText('Recommended provider', 'مقدم رعاية موصى به'),
          actionLabel: _homeText('View details', 'عرض التفاصيل'),
          onTap: () => _bookProvider(recommended.first),
        ),
      if (_quickServices.isNotEmpty)
        _recommendationCarouselCard(
          icon: Icons.medical_services_outlined,
          title: _homeText('Recommended service', 'خدمة مقترحة'),
          name: _homeText(_quickServices.first.serviceType, 'رعاية منزلية'),
          reason: _homeText(
            'Start a booking with available CareLink providers',
            'ابدأ حجزاً مع مقدمي رعاية متاحين',
          ),
          actionLabel: _homeText('View details', 'عرض التفاصيل'),
          onTap: () => _openQuickServiceBooking(_quickServices.first),
        ),
      _recommendationCarouselCard(
        icon: Icons.auto_awesome_rounded,
        title: _homeText(
          'AI recommended care',
          'رعاية موصى بها بالذكاء الاصطناعي',
        ),
        name: _homeText('Smart care matching', 'مطابقة الرعاية الذكية'),
        reason: _homeText(
          'Describe your case and get a suitable provider',
          'اكتب حالتك واحصل على مقدم مناسب',
        ),
        actionLabel: _homeText('View details', 'عرض التفاصيل'),
        onTap: _openAiAssistant,
      ),
    ];

    return SizedBox(
      height: 206,
      child: PageView.builder(
        controller: PageController(viewportFraction: 0.92),
        padEnds: false,
        itemCount: cards.length,
        itemBuilder: (context, index) => Padding(
          padding: EdgeInsetsDirectional.only(
            end: index == cards.length - 1 ? 0 : 10,
          ),
          child: cards[index],
        ),
      ),
    );
  }

  String _cleanHomeDisplay(Object? value) {
    final text = value?.toString().trim() ?? '';
    final normalized = text.toLowerCase();
    const invalid = {
      '',
      'null',
      'undefined',
      'user',
      'carid',
      'careid',
      'unknown',
      'n/a',
      '-',
    };
    return invalid.contains(normalized) ? '' : text;
  }

  Widget _providerRecommendationCarouselCard({
    required ProviderModel provider,
    required String title,
    required String actionLabel,
    required VoidCallback onTap,
  }) {
    final name = _cleanHomeDisplay(provider.fullName).isEmpty
        ? _homeText('Care Provider', 'مقدم رعاية')
        : _cleanHomeDisplay(provider.fullName);
    final service = _cleanHomeDisplay(provider.serviceType).isNotEmpty
        ? _cleanHomeDisplay(provider.serviceType)
        : _cleanHomeDisplay(provider.specialization).isNotEmpty
        ? _cleanHomeDisplay(provider.specialization)
        : _shortProviderReason(provider);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _p.surface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.18)),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: _p.isDark ? 0.12 : 0.08),
            blurRadius: 18,
            offset: const Offset(0, 7),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 100,
            height: 100,
            padding: const EdgeInsets.all(3),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.primary.withValues(alpha: 0.10),
              border: Border.all(
                color: AppColors.primary.withValues(alpha: 0.22),
                width: 1.2,
              ),
              boxShadow: [
                BoxShadow(
                  color: AppColors.primary.withValues(
                    alpha: _p.isDark ? 0.16 : 0.10,
                  ),
                  blurRadius: 16,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: ClipOval(
              child: profileAvatarOrPlaceholder(
                imageUrl: provider.profileImageUrl,
                size: 94,
                placeholderColor: AppColors.primary,
                placeholderIcon: Icons.medical_services_outlined,
                iconSize: 38,
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 9,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.10),
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(
                        color: AppColors.primary.withValues(alpha: 0.16),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.verified_user_outlined,
                          color: AppColors.primary,
                          size: 14,
                        ),
                        const SizedBox(width: 5),
                        Flexible(
                          child: Text(
                            title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: AppColors.primary,
                              fontSize: 11,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: _p.inkDark,
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  service,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: _p.inkMuted,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 6),
                Row(
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
                        color: _p.inkDark,
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Container(
                      width: 6,
                      height: 6,
                      decoration: const BoxDecoration(
                        color: Color(0xFF21A35B),
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      _homeText('Available today', 'متاح اليوم'),
                      style: const TextStyle(
                        color: Color(0xFF21A35B),
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 9),
                SizedBox(
                  height: 34,
                  child: FilledButton(
                    onPressed: onTap,
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      minimumSize: const Size(122, 34),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      visualDensity: VisualDensity.compact,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text(
                      actionLabel,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w900,
                      ),
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

  Widget _recommendationCarouselCard({
    required IconData icon,
    required String title,
    required String name,
    required String reason,
    required String actionLabel,
    required VoidCallback onTap,
  }) {
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: _p.surface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.18)),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: _p.isDark ? 0.12 : 0.08),
            blurRadius: 18,
            offset: const Offset(0, 7),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: AppColors.primary, size: 20),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.primary,
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: _p.inkDark,
              fontSize: 17,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            reason,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: _p.inkMuted,
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
            ),
          ),
          const Spacer(),
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: FilledButton(
              onPressed: onTap,
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                minimumSize: const Size(116, 36),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                visualDensity: VisualDensity.compact,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Text(
                actionLabel,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _shortProviderReason(ProviderModel provider) {
    final rec = _backendRecommendationFor(provider);
    final reasons = _backendMedicalReasons(rec).map(_friendlyReason).toList();
    if (reasons.isNotEmpty) return reasons.first;
    final specialty = _cleanHomeDisplay(provider.specialization);
    if (specialty.isNotEmpty) {
      return _homeText('Matches your care needs', 'يناسب احتياجاتك الصحية');
    }
    return _homeText('Available CareLink provider', 'مقدم رعاية متاح');
  }

  // ── 2 · AI PROVIDER CARD ────────────────────────────────────────────
  Widget _buildAiProviderCard(List<ProviderModel> recommended) {
    final provider = recommended.first;
    final name = provider.fullName;
    final specialty = provider.specialization.trim().isNotEmpty
        ? provider.specialization
        : _homeText('General medicine', 'General medicine');
    final rating = provider.overallRating;
    final rec = _backendRecommendationFor(provider);
    final medPct = _backendMedicalMatchPercent(rec);
    final ovPct = _backendMatchPercent(rec);
    final reasons = _backendMedicalReasons(
      rec,
    ).map(_friendlyReason).toSet().take(2).toList();
    final hasMed = medPct != null && medPct > 0;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _p.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: AppColors.primary.withValues(alpha: 0.28),
          width: 1.4,
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: _p.isDark ? 0.18 : 0.10),
            blurRadius: 18,
            offset: const Offset(0, 7),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Section label
          Row(
            children: [
              const Icon(
                Icons.auto_awesome_rounded,
                size: 14,
                color: AppColors.primary,
              ),
              const SizedBox(width: 5),
              Text(
                _homeText('Recommended for you', 'موصى به لك'),
                style: const TextStyle(
                  color: AppColors.primary,
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                ),
              ),
              if (hasMed) ...[
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 7,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    _homeText('Based on your records', 'بناءً على سجلاتك'),
                    style: const TextStyle(
                      color: AppColors.primary,
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 12),
          // Provider info
          Row(
            children: [
              ClipOval(
                child: SizedBox(
                  width: 54,
                  height: 54,
                  child: profileAvatarOrPlaceholder(
                    imageUrl: profileImageUrlFromMap(
                      (rec?['provider'] is Map
                              ? Map<String, dynamic>.from(
                                  rec!['provider'] as Map,
                                )
                              : rec) ??
                          {},
                    ),
                    size: 54,
                    placeholderColor: AppColors.primary,
                    placeholderIcon: Icons.person_rounded,
                    iconSize: 28,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: _p.inkDark,
                        fontSize: 15,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      specialty,
                      style: TextStyle(
                        color: _p.inkMuted,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Row(
                      children: [
                        const Icon(
                          Icons.star_rounded,
                          color: Color(0xFFFFB020),
                          size: 13,
                        ),
                        const SizedBox(width: 3),
                        Text(
                          rating.toStringAsFixed(1),
                          style: TextStyle(
                            color: _p.inkDark,
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        if (medPct != null) ...[
                          const SizedBox(width: 10),
                          Text(
                            _homeText(
                              'Medical Match: $medPct%',
                              'التوافق الطبي: $medPct%',
                            ),
                            style: const TextStyle(
                              color: AppColors.primary,
                              fontSize: 11.5,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                        if (ovPct != null) ...[
                          const SizedBox(width: 6),
                          Text(
                            _homeText('Overall: $ovPct%', 'إجمالي: $ovPct%'),
                            style: TextStyle(
                              color: const Color(0xFF2196F3),
                              fontSize: 11.5,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          // Reason — 1-line summary
          if (reasons.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              reasons.join(' · '),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: _p.inkMuted,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
          // Empty-state prompt if no medical context
          if (reasons.isEmpty && !hasMed) ...[
            const SizedBox(height: 10),
            Text(
              _homeText(
                'Upload a medical report to unlock personalised recommendations.',
                'ارفع تقريراً طبياً للحصول على توصيات مخصصة.',
              ),
              maxLines: 2,
              style: TextStyle(
                color: _p.inkMuted,
                fontSize: 12,
                fontWeight: FontWeight.w600,
                height: 1.3,
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              height: 36,
              child: OutlinedButton.icon(
                onPressed: _openMedicalRecords,
                icon: const Icon(Icons.upload_file_outlined, size: 16),
                label: Text(
                  _homeText('Upload Record', 'رفع سجل'),
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 12.5,
                  ),
                ),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.primary,
                  side: BorderSide(
                    color: AppColors.primary.withValues(alpha: 0.55),
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                ),
              ),
            ),
          ],
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            height: 38,
            child: FilledButton(
              onPressed: () => _bookProvider(provider),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Text(
                _homeText('View Provider', 'عرض المزود'),
                style: const TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 13,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── 3 · NEXT APPOINTMENT CARD ────────────────────────────────────────
  Widget _buildNextAppointmentCard() {
    final apt = _upcomingAppointment;
    final scheduled = apt?.scheduledAt?.toLocal();
    final name = apt?.providerName.trim().isNotEmpty == true
        ? apt!.providerName
        : _homeText('Dr. Ahmad Ali', 'د. أحمد علي');
    final specialty = apt?.specialization.trim().isNotEmpty == true
        ? apt!.specialization
        : _homeText('General doctor', 'طبيب عام');
    final day = scheduled?.day.toString() ?? '—';
    final month = scheduled != null ? _monthLabel(scheduled.month) : '—';
    final time = scheduled != null ? _formatAppointmentTime(scheduled) : '—';
    final isToday =
        scheduled != null &&
        scheduled.year == DateTime.now().year &&
        scheduled.month == DateTime.now().month &&
        scheduled.day == DateTime.now().day;
    final dateLabel = isToday
        ? _homeText('Today', 'اليوم')
        : (scheduled != null ? _weekdayLabel(scheduled.weekday) : '—');
    final statusColor = _appointmentStatusColor(apt?.status ?? 'confirmed');
    final statusText = _appointmentStatusText(apt?.status ?? 'confirmed');
    final isHome = (apt?.location ?? '').toLowerCase() != 'remote';

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildSectionHeader(
            title: _homeText('Next appointment', 'الموعد القادم'),
            actionText: apt != null ? _homeText('View all', 'عرض الكل') : null,
            onActionTap: _openBookings,
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: _p.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: _p.stroke),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(
                    alpha: _p.isDark ? 0.14 : 0.04,
                  ),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: apt == null
                // ── Empty state
                ? Row(
                    children: [
                      Icon(Icons.event_outlined, color: _p.inkMuted, size: 22),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          _homeText(
                            'No upcoming appointments',
                            'لا توجد مواعيد قادمة',
                          ),
                          style: TextStyle(
                            color: _p.inkMuted,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      TextButton(
                        onPressed: _openBookingFlow,
                        style: TextButton.styleFrom(
                          foregroundColor: AppColors.primary,
                          minimumSize: Size.zero,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 6,
                          ),
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        child: Text(
                          _homeText('Book Care', 'احجز'),
                          style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ],
                  )
                // ── Live appointment
                : Row(
                    children: [
                      Container(
                        width: 56,
                        padding: const EdgeInsets.symmetric(
                          vertical: 9,
                          horizontal: 5,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(13),
                          border: Border.all(
                            color: AppColors.primary.withValues(alpha: 0.15),
                          ),
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              dateLabel,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: AppColors.primary,
                                fontSize: 9.5,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              day,
                              style: TextStyle(
                                color: _p.inkDark,
                                fontSize: 21,
                                fontWeight: FontWeight.w900,
                                height: 1,
                              ),
                            ),
                            Text(
                              month,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: _p.inkDark,
                                fontSize: 9.5,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: _p.inkDark,
                                fontSize: 14.5,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              specialty,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: _p.inkMuted,
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Wrap(
                              spacing: 8,
                              runSpacing: 5,
                              children: [
                                _compactAppointmentMeta(
                                  Icons.access_time_rounded,
                                  time,
                                  AppColors.primary,
                                ),
                                _compactAppointmentMeta(
                                  isHome
                                      ? Icons.home_outlined
                                      : Icons.videocam_outlined,
                                  isHome
                                      ? _homeText('Home', 'منزلية')
                                      : _homeText('Remote', 'عن بعد'),
                                  _p.inkMuted,
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: statusColor.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(
                              statusText,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: statusColor,
                                fontSize: 9.5,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                          const SizedBox(height: 9),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              _aptBtn(
                                Icons.visibility_outlined,
                                _homeText('Details', 'التفاصيل'),
                                _openUpcomingDetails,
                                filled: true,
                              ),
                              const SizedBox(width: 6),
                              _aptBtn(
                                Icons.chat_bubble_outline_rounded,
                                _homeText('Contact', 'تواصل'),
                                _openMessages,
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
    );
  }

  Widget _compactAppointmentMeta(IconData icon, String label, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 12.5, color: color),
        const SizedBox(width: 3),
        Text(
          label,
          style: TextStyle(
            color: color,
            fontSize: 11,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }

  Widget _aptBtn(
    IconData icon,
    String label,
    VoidCallback onTap, {
    bool filled = false,
  }) {
    return SizedBox(
      height: 32,
      child: filled
          ? FilledButton.icon(
              onPressed: onTap,
              icon: Icon(icon, size: 13),
              label: Text(
                label,
                maxLines: 1,
                style: const TextStyle(fontSize: 11),
              ),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 8),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(9),
                ),
                textStyle: const TextStyle(fontWeight: FontWeight.w800),
              ),
            )
          : OutlinedButton.icon(
              onPressed: onTap,
              icon: Icon(icon, size: 13),
              label: Text(
                label,
                maxLines: 1,
                style: const TextStyle(fontSize: 11),
              ),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.primary,
                side: BorderSide(
                  color: AppColors.primary.withValues(alpha: 0.45),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 8),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(9),
                ),
                textStyle: const TextStyle(fontWeight: FontWeight.w800),
              ),
            ),
    );
  }

  // ── 4 · QUICK ACTIONS ───────────────────────────────────────────────
  Widget _buildQuickActions() {
    return Row(
      children: [
        Expanded(
          child: _buildActionButton(
            Icons.add_circle_outline_rounded,
            _homeText('Book', 'احجز'),
            _openBookingFlow,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _buildActionButton(
            Icons.search_rounded,
            _homeText('Search', 'ابحث'),
            _openproviders,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _buildActionButton(
            Icons.folder_outlined,
            _homeText('Records', 'السجل'),
            _openMedicalRecords,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _buildActionButton(
            Icons.auto_awesome_rounded,
            _homeText('AI', 'المساعد'),
            _openAiAssistant,
          ),
        ),
      ],
    );
  }

  // ── 5 · HEALTH INSIGHTS (2-3 lines max) ─────────────────────────────
  Widget _buildHealthInsightsSection() {
    final insights = <({IconData icon, String label})>[
      (
        icon: Icons.bloodtype_outlined,
        label: _homeText('Diabetes follow-up', 'متابعة السكري'),
      ),
      (
        icon: Icons.monitor_heart_outlined,
        label: _homeText('Blood pressure care', 'إدارة ضغط الدم'),
      ),
      (
        icon: Icons.favorite_border_rounded,
        label: _homeText('Cholesterol', 'الكوليسترول'),
      ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader(title: _homeText('Health Insights', 'رؤى صحية')),
        const SizedBox(height: 8),
        Row(
          children: [
            for (var i = 0; i < insights.length; i++) ...[
              Expanded(
                child: _healthInsightChip(
                  icon: insights[i].icon,
                  label: insights[i].label,
                ),
              ),
              if (i != insights.length - 1) const SizedBox(width: 8),
            ],
          ],
        ),
      ],
    );
  }

  Widget _healthInsightChip({required IconData icon, required String label}) {
    return Container(
      constraints: const BoxConstraints(minHeight: 78),
      padding: const EdgeInsets.all(11),
      decoration: BoxDecoration(
        color: _p.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.14)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: _p.isDark ? 0.10 : 0.035),
            blurRadius: 12,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: AppColors.primary, size: 20),
          const SizedBox(height: 14),
          Text(
            label,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: _p.inkDark,
              fontSize: 11.5,
              fontWeight: FontWeight.w900,
              height: 1.15,
            ),
          ),
        ],
      ),
    );
  }

  // ── 6 · LATEST MEDICAL RECORD (1 card) ──────────────────────────────
  Widget _buildLatestRecordCard() {
    final r = _recentRecords.first;
    final st = _recordStatusStyle(_recordStatus(r));
    final summary = _recordSummaryLine(r);
    final dt = _recordDate(r);
    final dateLabel = dt != null ? '${_monthLabel(dt.month)} ${dt.day}' : '';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader(
          title: _homeText('Latest record', 'آخر سجل'),
          actionText: _homeText('View all', 'عرض الكل'),
          onActionTap: _openMedicalRecords,
        ),
        const SizedBox(height: 8),
        InkWell(
          onTap: _openMedicalRecords,
          borderRadius: BorderRadius.circular(16),
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: _p.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: AppColors.primary.withValues(alpha: 0.18),
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.description_outlined,
                    color: AppColors.primary,
                    size: 20,
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
                              _recordTitle(r),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: _p.inkDark,
                                fontSize: 13.5,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          _statusBadge(st.label, st.color, st.icon),
                        ],
                      ),
                      if (summary != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          summary,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: _p.inkMuted,
                            fontSize: 12,
                            fontStyle: FontStyle.italic,
                            height: 1.3,
                          ),
                        ),
                      ],
                      if (dateLabel.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          dateLabel,
                          style: TextStyle(
                            color: _p.inkMuted,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Icon(Icons.chevron_right_rounded, color: _p.inkMuted, size: 20),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // ── 7 · SPECIALTY CHIPS ROW (compact) ───────────────────────────────
  Widget _buildSpecialtyChipsRow() {
    final specialties = _specialtyFromTags();
    if (specialties.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader(
          title: _homeText('Recommended specialists', 'التخصصات الموصى بها'),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: specialties.map((s) {
            return InkWell(
              onTap: _openproviders,
              borderRadius: BorderRadius.circular(999),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(
                    color: AppColors.primary.withValues(alpha: 0.22),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.local_hospital_outlined,
                      size: 14,
                      color: AppColors.primary,
                    ),
                    const SizedBox(width: 5),
                    Text(
                      s,
                      style: const TextStyle(
                        color: AppColors.primary,
                        fontSize: 12.5,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  // ── shared small prompt widget ───────────────────────────────────────
  Widget _buildSimplePrompt({
    required IconData icon,
    required String text,
    String? actionLabel,
    VoidCallback? onAction,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: _p.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _p.stroke),
      ),
      child: Row(
        children: [
          Icon(icon, color: AppColors.primary, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                color: _p.inkMuted,
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                height: 1.35,
              ),
            ),
          ),
          if (actionLabel != null && onAction != null) ...[
            const SizedBox(width: 8),
            TextButton(
              onPressed: onAction,
              style: TextButton.styleFrom(
                foregroundColor: AppColors.primary,
                minimumSize: Size.zero,
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: Text(
                actionLabel,
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 12.5,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════════════
  //  END NEW SECTION BUILDERS
  // ══════════════════════════════════════════════════════════════════════

  Widget _buildCareHeroCard() {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: _p.isDark ? const Color(0xFF0B2A2D) : const Color(0xFFE7F6F3),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.12)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: _p.isDark ? 0.20 : 0.05),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            flex: 5,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.asset(
                'assets/images/patientcare.jpg',
                height: 116,
                fit: BoxFit.cover,
                alignment: Alignment.center,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            flex: 7,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  _homeText(
                    'How can we help you today?',
                    'كيف يمكننا مساعدتك اليوم؟',
                  ),
                  textAlign: TextAlign.start,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: _p.inkDark,
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                    height: 1.15,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  _homeText(
                    'Home care and remote consultations made easy',
                    'رعاية منزلية واستشارات عن بعد بكل سهولة',
                  ),
                  textAlign: TextAlign.start,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: _p.inkMuted,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    height: 1.25,
                  ),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  height: 38,
                  child: FilledButton.icon(
                    onPressed: _openBookingFlow,
                    icon: const Icon(
                      Icons.add_circle_outline_rounded,
                      size: 16,
                    ),
                    label: Text(
                      _homeText('Request care now', 'اطلب رعاية الآن'),
                    ),
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      textStyle: const TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  height: 38,
                  child: OutlinedButton.icon(
                    onPressed: _openAiAssistant,
                    icon: const Icon(Icons.auto_awesome_rounded, size: 15),
                    label: Text(
                      _homeText('Ask AI assistant', 'اسأل المساعد الذكي'),
                    ),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.primary,
                      side: const BorderSide(color: AppColors.primary),
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      textStyle: const TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w900,
                      ),
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

  Widget _buildQuickServicesSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: _buildSectionHeader(
            title: _homeText('Quick services', 'الخدمات السريعة'),
            actionText: _homeText('View all', 'عرض الكل'),
            onActionTap: _openproviders,
          ),
        ),
        const SizedBox(height: 12),
        for (final cat in _serviceCategories) ...[
          _buildServiceCategory(cat),
          const SizedBox(height: 14),
        ],
      ],
    );
  }

  Widget _buildServiceCategory(
    ({String key, String en, String ar, IconData icon}) cat,
  ) {
    final services = _quickServices
        .where((s) => s.category == cat.key)
        .toList();
    if (services.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              Icon(cat.icon, size: 16, color: AppColors.primary),
              const SizedBox(width: 6),
              Text(
                _homeText(cat.en, cat.ar),
                style: TextStyle(
                  color: _p.inkDark,
                  fontSize: 13.5,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              for (int i = 0; i < services.length; i++) ...[
                if (i > 0) const SizedBox(width: 10),
                _buildQuickServiceCard(services[i]),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildQuickServiceCard(_HomeQuickService service) {
    return ConstrainedBox(
      constraints: const BoxConstraints(minWidth: 150, maxWidth: 200),
      child: PatientPressable(
        onTap: () => _openQuickServiceBooking(service),
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          decoration: BoxDecoration(
            color: _p.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: _p.stroke),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: _p.isDark ? 0.15 : 0.04),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(service.icon, color: AppColors.primary, size: 22),
              ),
              const SizedBox(width: 10),
              Flexible(
                child: Text(
                  _homeText(service.titleEn, service.titleAr),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: _p.inkDark,
                    fontSize: 12.5,
                    fontWeight: FontWeight.bold,
                    height: 1.2,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHomeAiRecommendation(
    List<ProviderModel> recommended, {
    bool featured = false,
  }) {
    final provider = recommended.isNotEmpty ? recommended.first : null;
    if (provider == null) return const SizedBox.shrink();

    final name = provider.fullName;
    final specialty = provider.specialization.trim().isNotEmpty
        ? provider.specialization
        : _homeText('General medicine', 'General medicine');
    final rating = provider.overallRating.toStringAsFixed(1);
    final backendRecommendation = _backendRecommendationFor(provider);
    final matchPercent = _backendMatchPercent(backendRecommendation);
    final medicalMatchPercent = _backendMedicalMatchPercent(
      backendRecommendation,
    );
    // Always route through _friendlyReason so no raw snake_case tag is shown.
    final medicalReasons = _backendMedicalReasons(
      backendRecommendation,
    ).map(_friendlyReason).toSet().take(3).toList();
    final medicalTags = _backendMedicalTags(backendRecommendation);
    final hasMedicalContext =
        medicalReasons.isNotEmpty || medicalTags.isNotEmpty;
    final imgSize = featured ? 72.0 : 58.0;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        // White surface + green-accented elevation makes the recommendation
        // feel premium and "special" without any off-brand color.
        color: _p.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: AppColors.primary.withValues(alpha: 0.30),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: _p.isDark ? 0.22 : 0.12),
            blurRadius: 22,
            offset: const Offset(0, 10),
          ),
          BoxShadow(
            color: Colors.black.withValues(alpha: _p.isDark ? 0.22 : 0.05),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header row: badge + title
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.auto_awesome_rounded,
                      color: Colors.white,
                      size: 11,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      _homeText('Best Match For You', 'الأفضل لك'),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
              ),
              if (hasMedicalContext) ...[
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 7,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFF21A35B).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(
                      color: const Color(0xFF21A35B).withValues(alpha: 0.3),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.medical_information_outlined,
                        color: Color(0xFF21A35B),
                        size: 11,
                      ),
                      const SizedBox(width: 3),
                      Text(
                        _homeText('Based on your records', 'بناءً على سجلاتك'),
                        style: const TextStyle(
                          color: Color(0xFF21A35B),
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 14),
          // Provider info row
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipOval(
                child: Image.asset(
                  'assets/images/doctorportrait.jpg',
                  width: imgSize,
                  height: imgSize,
                  fit: BoxFit.cover,
                  errorBuilder: (context2, e, _) => Container(
                    width: imgSize,
                    height: imgSize,
                    color: AppColors.primary.withValues(alpha: 0.12),
                    child: Icon(
                      Icons.person_rounded,
                      color: AppColors.primary,
                      size: imgSize * 0.5,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: _p.inkDark,
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      specialty,
                      style: TextStyle(
                        color: AppColors.primary,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        const Icon(
                          Icons.star_rounded,
                          color: Color(0xFFFFB020),
                          size: 14,
                        ),
                        const SizedBox(width: 3),
                        Text(
                          rating,
                          style: TextStyle(
                            color: _p.inkDark,
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Container(
                          width: 6,
                          height: 6,
                          decoration: const BoxDecoration(
                            color: Color(0xFF21A35B),
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          _homeText('Available', 'متاح'),
                          style: const TextStyle(
                            color: Color(0xFF21A35B),
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              // Match scores column
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  if (medicalMatchPercent != null) ...[
                    _matchScoreChip(
                      _homeText('Medical', 'طبي'),
                      medicalMatchPercent,
                      AppColors.primary,
                    ),
                    const SizedBox(height: 5),
                  ],
                  if (matchPercent != null)
                    _matchScoreChip(
                      _homeText('Overall', 'إجمالي'),
                      matchPercent,
                      const Color(0xFF2196F3), // info blue — secondary metric
                    ),
                ],
              ),
            ],
          ),
          // One short recommendation sentence — full reasoning lives on the
          // Provider Details screen.
          const SizedBox(height: 12),
          Text(
            _aiOneLineReason(medicalReasons, specialty),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: _p.inkMuted,
              fontSize: 12,
              fontWeight: FontWeight.w600,
              height: 1.3,
            ),
          ),
          const SizedBox(height: 12),
          // View Details button
          SizedBox(
            height: 38,
            width: double.infinity,
            child: FilledButton(
              onPressed: () => _bookProvider(provider),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: Text(
                _homeText('View Details', 'عرض التفاصيل'),
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Single patient-friendly sentence for the compact AI card.
  String _aiOneLineReason(List<String> reasons, String specialty) {
    if (reasons.isNotEmpty) {
      final first = reasons.first;
      if (reasons.length > 1) {
        return _homeText(
          'Recommended for $first and ${reasons.length - 1} more from your records.',
          'موصى به لـ $first و${reasons.length - 1} أخرى من سجلاتك.',
        );
      }
      return _homeText(
        'Recommended for $first based on your records.',
        'موصى به لـ $first بناءً على سجلاتك.',
      );
    }
    if (specialty.trim().isNotEmpty) {
      return _homeText(
        'A strong overall match in $specialty for your care needs.',
        'تطابق قوي في $specialty لاحتياجات رعايتك.',
      );
    }
    return _homeText(
      'A strong overall match for your care needs.',
      'تطابق قوي لاحتياجات رعايتك.',
    );
  }

  Widget _matchScoreChip(String label, int percent, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Column(
        children: [
          Text(
            '$percent%',
            style: TextStyle(
              color: color,
              fontSize: 14,
              fontWeight: FontWeight.w900,
            ),
          ),
          Text(
            label,
            style: TextStyle(
              color: color.withValues(alpha: 0.8),
              fontSize: 9.5,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _homeMatchPill(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFF21A35B).withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: const Color(0xFF21A35B).withValues(alpha: 0.28),
        ),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Color(0xFF16804A),
          fontSize: 10.5,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }

  Widget _homeMedicalBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFF6D4DE6).withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: const Color(0xFF6D4DE6).withValues(alpha: 0.25),
        ),
      ),
      child: const Text(
        'Based on Medical Records',
        style: TextStyle(
          color: Color(0xFF6D4DE6),
          fontSize: 10,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }

  // ─────────────── SECTION 5 · HEALTH OVERVIEW (merged) ───────────────
  /// One compact card merging Health Insights + Recommended Specialties +
  /// the latest record status. Gives a quick overview instead of 3 cards.
  Widget _buildHealthOverviewSection() {
    final insights = _healthInsightLines();
    final specialties = _specialtyFromTags();
    final lastRecord = _recentRecords.isNotEmpty ? _recentRecords.first : null;
    final hasContent = insights.isNotEmpty || specialties.isNotEmpty;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _p.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _p.stroke),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: _p.isDark ? 0.16 : 0.04),
            blurRadius: 14,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.health_and_safety_outlined,
                color: Color(0xFF21A35B),
                size: 18,
              ),
              const SizedBox(width: 7),
              Text(
                _homeText('Health Overview', 'نظرة صحية'),
                style: TextStyle(
                  color: _p.inkDark,
                  fontSize: 15.5,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const Spacer(),
              if (lastRecord != null)
                InkWell(
                  onTap: _openMedicalRecords,
                  child: Text(
                    _homeText('View all', 'عرض الكل'),
                    style: const TextStyle(
                      color: AppColors.primary,
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
            ],
          ),
          if (hasContent) ...[
            const SizedBox(height: 12),
            // Insight bullets.
            ...insights.map(
              (line) => Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Padding(
                      padding: EdgeInsets.only(top: 4),
                      child: Icon(
                        Icons.check_circle,
                        size: 13,
                        color: Color(0xFF21A35B),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        line,
                        style: TextStyle(
                          color: _p.inkDark,
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                          height: 1.3,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            // Recommended specialty chips.
            if (specialties.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                _homeText('Recommended specialists', 'التخصصات الموصى بها'),
                style: TextStyle(
                  color: _p.inkMuted,
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 6),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: specialties
                    .map(
                      (s) => InkWell(
                        onTap: _openproviders,
                        borderRadius: BorderRadius.circular(999),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 5,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(999),
                            border: Border.all(
                              color: AppColors.primary.withValues(alpha: 0.22),
                            ),
                          ),
                          child: Text(
                            s,
                            style: TextStyle(
                              color: AppColors.primary,
                              fontSize: 11.5,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ),
                    )
                    .toList(),
              ),
            ],
          ] else
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Text(
                _homeText(
                  'Upload a medical report to receive personalized health insights.',
                  'ارفع تقريراً طبياً للحصول على رؤى صحية مخصصة.',
                ),
                style: TextStyle(
                  color: _p.inkMuted,
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  height: 1.35,
                ),
              ),
            ),
          // Latest record status line (records-in-journey, compact).
          if (lastRecord != null) ...[
            const SizedBox(height: 12),
            Divider(color: _p.stroke, height: 1),
            const SizedBox(height: 12),
            _buildOverviewRecordRow(lastRecord),
          ],
        ],
      ),
    );
  }

  Widget _buildOverviewRecordRow(Map<String, dynamic> r) {
    final st = _recordStatusStyle(_recordStatus(r));
    final summary = _recordSummaryLine(r);
    return InkWell(
      onTap: _openMedicalRecords,
      borderRadius: BorderRadius.circular(12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(11),
            ),
            child: const Icon(
              Icons.description_outlined,
              color: AppColors.primary,
              size: 19,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        _recordTitle(r),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: _p.inkDark,
                          fontSize: 13,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    _statusBadge(st.label, st.color, st.icon),
                  ],
                ),
                if (summary != null) ...[
                  const SizedBox(height: 3),
                  Text(
                    summary,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: _p.inkMuted,
                      fontSize: 11.5,
                      height: 1.25,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ───────────────── SECTION 7 · RECOMMENDED SPECIALTIES ──────────────
  Widget _buildRecommendedSpecialtiesSection() {
    final specialties = _specialtyFromTags();
    if (specialties.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionHeader(
            title: _homeText('Recommended specialists', 'التخصصات الموصى بها'),
          ),
          const SizedBox(height: 10),
          for (int i = 0; i < specialties.length; i++) ...[
            if (i > 0) const SizedBox(height: 8),
            _buildSpecialtyRow(i + 1, specialties[i]),
          ],
        ],
      ),
    );
  }

  Widget _buildSpecialtyRow(int rank, String specialty) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: _openproviders,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: _p.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: _p.stroke),
          ),
          child: Row(
            children: [
              Container(
                width: 26,
                height: 26,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: Text(
                  '$rank',
                  style: const TextStyle(
                    color: Color(0xFF7C5CE7),
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  specialty,
                  style: TextStyle(
                    color: _p.inkDark,
                    fontSize: 13.5,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              Icon(Icons.chevron_right_rounded, color: _p.inkMuted, size: 20),
            ],
          ),
        ),
      ),
    );
  }

  // ────────────────── SECTION 8 · RECORDS PREVIEW ─────────────────────
  Widget _buildRecordsPreviewSection() {
    if (_recentRecords.isEmpty) return const SizedBox.shrink();
    final last = _recentRecords.first;
    final rest = _recentRecords.skip(1).toList();
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionHeader(
            title: _homeText('Recent records', 'أحدث السجلات'),
            actionText: _homeText('View all', 'عرض الكل'),
            onActionTap: _openMedicalRecords,
          ),
          const SizedBox(height: 10),
          _buildLastUploadCard(last),
          for (final r in rest) ...[
            const SizedBox(height: 8),
            _buildRecordRow(r),
          ],
        ],
      ),
    );
  }

  /// Journey card: last upload + status + 1-line AI summary + View Record.
  Widget _buildLastUploadCard(Map<String, dynamic> r) {
    final status = _recordStatus(r);
    final st = _recordStatusStyle(status);
    final summary = _recordSummaryLine(r);
    final date = _recordDate(r);
    final dateLabel = date != null
        ? '${_monthLabel(date.month)} ${date.day}'
        : '';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _p.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.18)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: _p.isDark ? 0.18 : 0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.description_outlined,
                color: AppColors.primary,
                size: 18,
              ),
              const SizedBox(width: 7),
              Text(
                _homeText('Last upload', 'آخر رفع'),
                style: TextStyle(
                  color: _p.inkMuted,
                  fontSize: 11.5,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const Spacer(),
              _statusBadge(st.label, st.color, st.icon),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: Text(
                  _recordTitle(r),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: _p.inkDark,
                    fontSize: 14.5,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              if (dateLabel.isNotEmpty)
                Text(
                  dateLabel,
                  style: TextStyle(color: _p.inkMuted, fontSize: 11),
                ),
            ],
          ),
          if (summary != null) ...[
            const SizedBox(height: 6),
            Text(
              summary,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: _p.inkMuted,
                fontSize: 12,
                height: 1.3,
                fontStyle: FontStyle.italic,
              ),
            ),
          ] else if (status == 'processing' || status == 'pending') ...[
            const SizedBox(height: 6),
            Text(
              _homeText(
                'AI is analyzing this record…',
                'يقوم الذكاء الاصطناعي بتحليل هذا السجل…',
              ),
              style: TextStyle(color: _p.inkMuted, fontSize: 12, height: 1.3),
            ),
          ],
          const SizedBox(height: 12),
          SizedBox(
            height: 36,
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _openMedicalRecords,
              icon: const Icon(Icons.visibility_outlined, size: 16),
              label: Text(_homeText('View Record', 'عرض السجل')),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.primary,
                side: BorderSide(
                  color: AppColors.primary.withValues(alpha: 0.5),
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                textStyle: const TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecordRow(Map<String, dynamic> r) {
    final status = _recordStatus(r);
    final st = _recordStatusStyle(status);
    final date = _recordDate(r);
    final dateLabel = date != null
        ? '${_monthLabel(date.month)} ${date.day}'
        : '';
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: _openMedicalRecords,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: _p.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: _p.stroke),
          ),
          child: Row(
            children: [
              Icon(
                Icons.insert_drive_file_outlined,
                color: AppColors.primary,
                size: 20,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _recordTitle(r),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: _p.inkDark,
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    if (dateLabel.isNotEmpty)
                      Text(
                        dateLabel,
                        style: TextStyle(color: _p.inkMuted, fontSize: 10.5),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              _statusBadge(st.label, st.color, st.icon),
            ],
          ),
        ),
      ),
    );
  }

  ({String label, Color color, IconData icon}) _recordStatusStyle(
    String status,
  ) {
    switch (status) {
      case 'processed':
        return (
          label: _homeText('Ready', 'جاهز'),
          color: const Color(0xFF21A35B),
          icon: Icons.check_circle_outline_rounded,
        );
      case 'failed':
        return (
          label: _homeText('Needs review', 'يحتاج مراجعة'),
          color: const Color(0xFFC62828),
          icon: Icons.error_outline_rounded,
        );
      default:
        return (
          label: _homeText('Processing', 'قيد المعالجة'),
          color: const Color(0xFF2196F3),
          icon: Icons.sync_rounded,
        );
    }
  }

  Widget _statusBadge(String label, Color color, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 10.5,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }

  // ─────────────── SECTION 9 · FAVORITES (header + reuse) ─────────────
  Widget _buildFavoritesSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: _buildSectionHeader(
            title: _homeText('Favorite providers', 'مقدمو الرعاية المفضلون'),
            actionText: _homeText('View all', 'عرض الكل'),
            onActionTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => PatientFavoritesScreen(
                    patientUserId: widget.userId ?? '',
                  ),
                ),
              ).then((_) => _loadFavorites());
            },
          ),
        ),
        const SizedBox(height: 10),
        if (_myFavorites.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
              decoration: BoxDecoration(
                color: _p.surface,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: _p.stroke),
              ),
              child: Row(
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.10),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.favorite_border_rounded,
                      color: AppColors.primary,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      _homeText('No favorites yet', 'لا يوجد مفضلون بعد'),
                      style: TextStyle(
                        color: _p.inkMuted,
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          )
        else
          _buildFavoritesRow(),
      ],
    );
  }

  // ──────────────── SECTION 10 · NOTIFICATIONS PREVIEW ────────────────
  Widget _buildNotificationsPreview() {
    if (_latestNotifications.isEmpty) return const SizedBox.shrink();
    final items = _latestNotifications.take(2).toList();
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildSectionHeader(
            title: _homeText('Notifications', 'الإشعارات'),
            actionText: _homeText('View all', 'عرض الكل'),
            onActionTap: _openNotifications,
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: _p.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: _p.stroke),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (int i = 0; i < items.length; i++) ...[
                  if (i > 0)
                    Padding(
                      padding: const EdgeInsets.only(top: 10),
                      child: Divider(height: 1, color: _p.stroke),
                    ),
                  if (i > 0) const SizedBox(height: 10),
                  _buildNotificationRow(items[i]),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNotificationRow(Map<String, dynamic> n) {
    final title =
        (n['title'] ??
                n['message'] ??
                n['body'] ??
                n['text'] ??
                _homeText('Notification', 'إشعار'))
            .toString();
    final time = (n['createdAt'] ?? n['created_at'] ?? n['time'] ?? '')
        .toString();
    final isRead = n['isRead'] == true || n['read'] == true;
    final color = isRead ? _p.inkMuted : AppColors.primary;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            shape: BoxShape.circle,
          ),
          child: Icon(
            isRead
                ? Icons.notifications_none_rounded
                : Icons.notifications_active_rounded,
            color: color,
            size: 18,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: _p.inkDark,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  height: 1.3,
                ),
              ),
              if (time.trim().isNotEmpty)
                Text(
                  _relativeTime(time),
                  style: TextStyle(color: _p.inkMuted, fontSize: 10.5),
                ),
            ],
          ),
        ),
      ],
    );
  }

  String _relativeTime(String raw) {
    final dt = DateTime.tryParse(raw);
    if (dt == null) return raw;
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return _homeText('Just now', 'الآن');
    if (diff.inMinutes < 60) {
      return _homeText('${diff.inMinutes}m ago', 'منذ ${diff.inMinutes} د');
    }
    if (diff.inHours < 24) {
      return _homeText('${diff.inHours}h ago', 'منذ ${diff.inHours} س');
    }
    return _homeText('${diff.inDays}d ago', 'منذ ${diff.inDays} ي');
  }

  BoxDecoration _homeCardDecoration() {
    return BoxDecoration(
      color: _p.surface,
      borderRadius: BorderRadius.circular(18),
      border: Border.all(color: _p.stroke),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: _p.isDark ? 0.20 : 0.045),
          blurRadius: 16,
          offset: const Offset(0, 7),
        ),
      ],
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
                        'e.g. diabetes follow-up, pediatrician, cardiology, available now',
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

  Widget _headerCircleButton({
    required IconData icon,
    required VoidCallback onTap,
    String? badge,
  }) {
    return InkWell(
      onTap: onTap,
      customBorder: const CircleBorder(),
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: _p.surface,
          shape: BoxShape.circle,
          border: Border.all(color: _p.stroke),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: _p.isDark ? 0.20 : 0.08),
              blurRadius: 14,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Stack(
          alignment: Alignment.center,
          clipBehavior: Clip.none,
          children: [
            Icon(icon, color: _p.inkDark, size: 22),
            if (badge != null)
              Positioned(
                top: -2,
                right: -2,
                child: Container(
                  height: 18,
                  constraints: const BoxConstraints(minWidth: 18),
                  alignment: Alignment.center,
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  decoration: const BoxDecoration(
                    color: Color(0xFFE53935),
                    shape: BoxShape.circle,
                  ),
                  child: Text(
                    badge,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ),
          ],
        ),
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
    final scheduled = apt?.scheduledAt?.toLocal();
    final day = scheduled?.day.toString() ?? '24';
    final month = scheduled == null
        ? _homeText('May', 'مايو')
        : _monthLabel(scheduled.month);
    final name = apt?.providerName.trim().isNotEmpty == true
        ? apt!.providerName
        : _homeText('Dr. Ahmad Ali', 'د. أحمد علي');
    final specialty = apt?.specialization.trim().isNotEmpty == true
        ? apt!.specialization
        : _homeText('General doctor', 'طبيب عام');
    final time = scheduled == null
        ? _homeText('03:30 PM', '03:30 مساءً')
        : _formatAppointmentTime(scheduled);

    final isToday =
        scheduled != null &&
        scheduled.year == DateTime.now().year &&
        scheduled.month == DateTime.now().month &&
        scheduled.day == DateTime.now().day;
    final dateLabel = isToday
        ? _homeText('Today', 'اليوم')
        : (scheduled != null
              ? _weekdayLabel(scheduled.weekday)
              : _homeText('Date', 'التاريخ'));

    final statusText = _appointmentStatusText(apt?.status ?? 'confirmed');
    final statusColor = _appointmentStatusColor(apt?.status ?? 'confirmed');
    final isHomeVisit = (apt?.location ?? '').toLowerCase() != 'remote';
    final visitTypeLabel = isHomeVisit
        ? _homeText('Home visit', 'زيارة منزلية')
        : _homeText('Remote', 'استشارة عن بعد');
    final visitIcon = isHomeVisit
        ? Icons.home_outlined
        : Icons.videocam_outlined;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildSectionHeader(
            title: _homeText('My next appointment', 'موعدي القادم'),
            actionText: _homeText('View all', 'عرض الكل'),
            onActionTap: _openBookings,
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: _p.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: _p.stroke),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(
                    alpha: _p.isDark ? 0.16 : 0.04,
                  ),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Container(
                  width: 58,
                  padding: const EdgeInsets.symmetric(
                    vertical: 8,
                    horizontal: 4,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: AppColors.primary.withValues(alpha: 0.15),
                    ),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        dateLabel,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: AppColors.primary,
                          fontSize: 10,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        day,
                        style: TextStyle(
                          color: _p.inkDark,
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                          height: 1.05,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        month,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: _p.inkDark,
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Row(
                    children: [
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: AppColors.primary.withValues(alpha: 0.15),
                            width: 1.5,
                          ),
                        ),
                        clipBehavior: Clip.antiAlias,
                        child: Image.asset(
                          'assets/images/doctorportrait.jpg',
                          width: 48,
                          height: 48,
                          fit: BoxFit.cover,
                          errorBuilder: (_, _, _) => Container(
                            color: AppColors.primary.withValues(alpha: 0.10),
                            child: const Icon(
                              Icons.medical_services_rounded,
                              color: AppColors.primary,
                              size: 24,
                            ),
                          ),
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
                                color: _p.inkDark,
                                fontSize: 14,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              specialty,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: _p.inkMuted,
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                Icon(
                                  Icons.access_time_rounded,
                                  size: 12,
                                  color: AppColors.primary,
                                ),
                                const SizedBox(width: 3),
                                Flexible(
                                  child: Text(
                                    time,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      color: AppColors.primary,
                                      fontSize: 10.5,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Icon(visitIcon, size: 12, color: _p.inkMuted),
                                const SizedBox(width: 3),
                                Flexible(
                                  child: Text(
                                    visitTypeLabel,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      color: _p.inkMuted,
                                      fontSize: 10.5,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    statusText,
                    style: TextStyle(
                      color: statusColor,
                      fontSize: 9.5,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          // Actions: Details + Contact only. Reschedule removed (routed to
          // same screen as Details — confirmed duplicate in audit).
          Row(
            children: [
              Expanded(
                child: _appointmentAction(
                  Icons.visibility_outlined,
                  _homeText('View Details', 'التفاصيل'),
                  _openUpcomingDetails,
                  filled: true,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _appointmentAction(
                  Icons.chat_bubble_outline_rounded,
                  _homeText('Contact', 'تواصل'),
                  _openMessages,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _appointmentAction(
    IconData icon,
    String label,
    VoidCallback onTap, {
    bool filled = false,
  }) {
    return SizedBox(
      height: 38,
      child: filled
          ? FilledButton.icon(
              onPressed: onTap,
              icon: Icon(icon, size: 15),
              label: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 6),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                textStyle: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                ),
              ),
            )
          : OutlinedButton.icon(
              onPressed: onTap,
              icon: Icon(icon, size: 15),
              label: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.primary,
                side: BorderSide(
                  color: AppColors.primary.withValues(alpha: 0.5),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 6),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                textStyle: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
    );
  }

  Widget _legacyUpcomingAppointmentCard() {
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
          recommendation: _backendRecommendationFor(provider),
        ),
      ),
    ).then((_) {
      if (mounted) _loadFavorites();
    });
  }

  /// Compact horizontal avatar+name bubbles for Favorites section.
  Widget _buildFavoritesRow() {
    final list = _myFavorites.take(6).toList();
    return SizedBox(
      height: 92,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: list.length,
        separatorBuilder: (_, index) => const SizedBox(width: 12),
        itemBuilder: (context, index) {
          final p = list[index];
          final providerId = (p['providerId'] ?? '').toString();
          final name = (p['displayName'] ?? '').toString();
          final firstName = name.trim().split(RegExp(r'\s+')).first;
          final specialty = (p['specialty'] ?? '').toString();
          final imageUrl = p['profilePictureUrl']?.toString();

          return GestureDetector(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => ProviderDetailsScreen(
                    provider: ProviderModel(
                      userId: providerId,
                      fullName: name,
                      specialization: specialty,
                      serviceType: '',
                      overallRating: 0.0,
                      profileImageUrl: imageUrl,
                      role: 'doctor',
                      isAvailable: true,
                    ),
                    patientUserId: widget.userId ?? '',
                  ),
                ),
              ).then((_) => _loadFavorites());
            },
            child: SizedBox(
              width: 64,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Container(
                        width: 54,
                        height: 54,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: AppColors.primary.withValues(alpha: 0.10),
                          border: Border.all(
                            color: AppColors.primary.withValues(alpha: 0.22),
                            width: 1.5,
                          ),
                        ),
                        clipBehavior: Clip.antiAlias,
                        child: profileAvatarOrPlaceholder(
                          imageUrl: imageUrl,
                          size: 54,
                          placeholderColor: AppColors.primary,
                          placeholderIcon: Icons.medical_services_rounded,
                          iconSize: 24,
                        ),
                      ),
                      Positioned(
                        bottom: 0,
                        right: 0,
                        child: Container(
                          width: 16,
                          height: 16,
                          decoration: const BoxDecoration(
                            color: Color(0xFFE53935),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.favorite_rounded,
                            color: Colors.white,
                            size: 9,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    firstName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: _p.inkDark,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
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
                              _homeText('Recommended', 'موصى به'),
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

  /// Profile tab icon: patient photo when available, otherwise a person icon.
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

class _HomeQuickService {
  const _HomeQuickService({
    required this.titleEn,
    required this.titleAr,
    required this.serviceType,
    required this.icon,
    required this.terms,
    required this.category,
  });

  final String titleEn;
  final String titleAr;
  final String serviceType;
  final IconData icon;
  final List<String> terms;

  /// One of: 'doctors', 'nursing', 'therapy'.
  final String category;
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
