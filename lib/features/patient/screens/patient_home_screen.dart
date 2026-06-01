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
import 'package:carelink/shared/models/booking_request_model.dart';
import 'package:carelink/shared/models/provider_model.dart';
import 'package:carelink/shared/services/api_service.dart';
import 'package:carelink/features/patient/services/favorite_providers_service.dart';
import 'package:carelink/shared/services/location_service.dart';
import 'package:carelink/features/ai/care_intent_parser.dart';

import 'package:carelink/shared/services/medical_record_service.dart';
import 'package:carelink/features/patient/widgets/patient_navigation_shell.dart';
import 'package:carelink/features/patient/services/patient_care_summary.dart';
import 'package:carelink/features/ai/provider_smart_match.dart';
import 'booking_details_screen.dart';
import 'messages_screen.dart';
import 'package:carelink/features/notifications/notifications_screen.dart';
import 'edit_profile_screen.dart';
import 'provider_details_screen.dart';
import 'providers_screen.dart';
import 'select_service_screen.dart';
import 'package:carelink/shared/widgets/carelink_theme_toggle.dart';

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
  AppointmentModel? _upcomingAppointment;
  int _medicalRecordsCount = 0;
  double? _patientLat;
  double? _patientLng;
  Set<String> _favoriteProviderIds = {};
  Map<String, dynamic>? _patientProfile;
  PatientCareSummary _careSummary = PatientCareSummary.empty;
  final LocationService _locationService = LocationService();
  final TextEditingController _careSearchController = TextEditingController();
  int _unreadNotifications = 0;
  List<Map<String, dynamic>> _latestNotifications = [];
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
        if (streetClean != null && streetClean.isNotEmpty)
          parts.add(streetClean);
        if (subLocalityClean != null && subLocalityClean.isNotEmpty)
          parts.add(subLocalityClean);
        if (localityClean != null && localityClean.isNotEmpty)
          parts.add(localityClean);
        if (subAdminAreaClean != null && subAdminAreaClean.isNotEmpty)
          parts.add(subAdminAreaClean);
        if (adminAreaClean != null && adminAreaClean.isNotEmpty)
          parts.add(adminAreaClean);
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
    _HomeQuickService(
      titleEn: 'Home nurse',
      titleAr: 'ممرض منزلي',
      serviceType: 'Home Nursing Care',
      icon: Icons.health_and_safety_outlined,
      terms: ['nurse', 'nursing', 'home nursing'],
    ),
    _HomeQuickService(
      titleEn: 'General doctor',
      titleAr: 'طبيب عام',
      serviceType: 'Doctor Consultation',
      icon: Icons.medical_services_outlined,
      terms: ['doctor', 'general', 'physician'],
    ),
    _HomeQuickService(
      titleEn: 'Elderly care',
      titleAr: 'رعاية كبار السن',
      serviceType: 'Elderly Care',
      icon: Icons.elderly_outlined,
      terms: ['elderly', 'senior', 'geriatric'],
    ),
    _HomeQuickService(
      titleEn: 'Post surgery care',
      titleAr: 'رعاية بعد العمليات',
      serviceType: 'Follow-up Visit',
      icon: Icons.healing_outlined,
      terms: ['post surgery', 'post operation', 'post-op', 'surgery', 'wound'],
    ),
    _HomeQuickService(
      titleEn: 'Physiotherapy',
      titleAr: 'علاج طبيعي',
      serviceType: 'Physiotherapy',
      icon: Icons.accessibility_new_rounded,
      terms: ['physio', 'physiotherapy', 'physical', 'therapy', 'rehab'],
    ),
    _HomeQuickService(
      titleEn: 'Mental support',
      titleAr: 'دعم نفسي',
      serviceType: 'Mental Health',
      icon: Icons.psychology_alt_outlined,
      terms: ['mental', 'psych', 'psychology', 'psychiatry'],
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
    _loadFavorites();
    _loadMedicalSummary();
    _loadNotificationCount();
  }

  @override
  void dispose() {
    _careSearchDebounce?.cancel();
    _speech.stop();
    _aiAnimationController.dispose();
    _careSearchController.dispose();
    super.dispose();
  }

  Future<void> _loadNotificationCount() async {
    final id = widget.userId?.trim();
    if (id == null || id.isEmpty) return;

    try {
      final raw = await ApiService().getNotifications(id);
      if (!mounted) return;

      var unread = 0;
      final items = <Map<String, dynamic>>[];
      for (final item in raw) {
        if (item is Map<String, dynamic> || item is Map) {
          items.add(Map<String, dynamic>.from(item as Map));
          final read = (item['isRead'] == true || item['read'] == true);
          if (!read) unread += 1;
        }
      }
      setState(() {
        _unreadNotifications = unread;
        _latestNotifications = items.take(3).toList();
      });
    } catch (_) {
      // Ignore notification count failures; leave badge hidden.
    }
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
        _medicalRecordsCount = clinical.length;
      });
    } catch (_) {
      if (mounted) {
        setState(() {
          _careSummary = PatientCareSummary.empty;
          _medicalRecordsCount = 0;
        });
      }
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
    PatientNavigationShell.switchTab(context, 2);
  }

  void _openBookings() {
    PatientNavigationShell.switchTab(context, 1);
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
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => SelectServiceScreen(
          request: BookingRequestModel(
            patientId: widget.userId ?? '',
            providerId: provider.userId,
            providerName: provider.fullName,
            providerRole: provider.role,
            specialization: provider.specialization,
            serviceType: service.serviceType,
            appointmentDate: '',
            appointmentTime: '',
            visitLatitude: 0,
            visitLongitude: 0,
            visitAddress: '',
            locationNote: '',
            patientReason: '',
            symptoms: '',
            isUrgent: false,
            additionalNotes: '',
            price: provider.consultationFee ?? 0,
            paymentMethod: 'cash',
            paymentStatus: 'pending',
            bookingStatus: 'pending',
          ),
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
    final recommended = ProviderSmartMatch.sortCopy(
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
                  physics: const AlwaysScrollableScrollPhysics(
                    parent: BouncingScrollPhysics(),
                  ),
                  padding: const EdgeInsets.fromLTRB(0, 12, 0, 90),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: _buildHeroHeader(),
                      ),
                      const SizedBox(height: 12),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: _buildCareHeroCard(),
                      ),
                      const SizedBox(height: 20),
                      _buildQuickServicesSection(),
                      const SizedBox(height: 20),
                      _buildUpcomingAppointmentCard(),
                      const SizedBox(height: 20),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: _buildHomeAiRecommendation(recommended),
                      ),
                      const SizedBox(height: 20),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: _buildRecordsAndNotificationsRow(),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

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
                    onPressed: _openproviders,
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
    final services = _quickServices;
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
        const SizedBox(height: 10),
        SizedBox(
          height: 118,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: services.length,
            separatorBuilder: (_, _) => const SizedBox(width: 12),
            itemBuilder: (context, index) {
              final service = services[index];
              return SizedBox(
                width: 98,
                child: _buildQuickServiceCard(service),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildQuickServiceCard(_HomeQuickService service) {
    return InkWell(
      onTap: () => _openQuickServiceBooking(service),
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
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
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(service.icon, color: AppColors.primary, size: 26),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: Center(
                child: Text(
                  _homeText(service.titleEn, service.titleAr),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: _p.inkDark,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    height: 1.2,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHomeAiRecommendation(List<ProviderModel> recommended) {
    final provider = recommended.isNotEmpty ? recommended.first : null;
    final name =
        provider?.fullName ??
        _homeText('Dr. Mohammad Mahmoud', 'د. محمد محمود');
    final specialty = provider?.specialization.trim().isNotEmpty == true
        ? provider!.specialization
        : _homeText('General medicine', 'طب عام');
    final rating = provider?.overallRating.toStringAsFixed(1) ?? '4.9';

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _p.isDark ? const Color(0xFF151C32) : const Color(0xFFFAF8FF),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: const Color(0xFF7C5CE7).withValues(alpha: 0.18),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: _p.isDark ? 0.18 : 0.045),
            blurRadius: 16,
            offset: const Offset(0, 7),
          ),
        ],
      ),
      child: Row(
        children: [
          SizedBox(
            width: 104,
            child: Column(
              children: [
                Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 9,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFF7C5CE7),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      _homeText('Best for you', 'الأفضل لك'),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                ClipOval(
                  child: Image.asset(
                    'assets/images/doctorportrait.jpg',
                    width: 68,
                    height: 68,
                    fit: BoxFit.cover,
                  ),
                ),
              ],
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
                const SizedBox(height: 4),
                Text(
                  specialty,
                  style: TextStyle(
                    color: _p.inkMuted,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Text(
                      rating,
                      style: TextStyle(
                        color: _p.inkDark,
                        fontSize: 12,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(width: 4),
                    const Icon(
                      Icons.star_rounded,
                      color: Color(0xFFFFB020),
                      size: 15,
                    ),
                    Text(
                      _homeText(' (128 reviews)', ' (128 تقييم)'),
                      style: TextStyle(color: _p.inkMuted, fontSize: 11),
                    ),
                  ],
                ),
                const SizedBox(height: 7),
                Row(
                  children: [
                    Container(
                      width: 7,
                      height: 7,
                      decoration: const BoxDecoration(
                        color: Color(0xFF21A35B),
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 5),
                    Text(
                      _homeText('Available today', 'متاح اليوم'),
                      style: const TextStyle(
                        color: Color(0xFF21A35B),
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Container(
            width: 1,
            height: 78,
            color: const Color(0xFF7C5CE7).withValues(alpha: 0.25),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  _homeText('Suggested for you', 'مقترح لك'),
                  style: TextStyle(
                    color: _p.inkDark,
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 9),
                Text(
                  _homeText(
                    'Recommended based on your health needs and medical file',
                    'تم ترشيحه بناءً على احتياجاتك الصحية وسجلك الطبي',
                  ),
                  textAlign: TextAlign.end,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: _p.inkMuted,
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                    height: 1.35,
                  ),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  height: 34,
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: provider == null
                        ? _openproviders
                        : () => _bookProvider(provider),
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF6D4DE6),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(9),
                      ),
                    ),
                    child: Text(
                      _homeText('View details', 'عرض التفاصيل'),
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

  Widget _buildRecordsAndNotificationsRow() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: _buildMedicalFilesCard()),
        const SizedBox(width: 12),
        Expanded(child: _buildNotificationsCard()),
      ],
    );
  }

  Widget _buildMedicalFilesCard() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: _homeCardDecoration(),
      child: Column(
        children: [
          Text(
            _homeText('My medical files', 'ملفاتي الطبية'),
            style: TextStyle(
              color: _p.inkDark,
              fontSize: 15,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 12),
          Container(
            width: 70,
            height: 70,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.10),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.folder_outlined,
              color: AppColors.primary,
              size: 36,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            _homeText(
              '$_medicalRecordsCount medical files',
              '$_medicalRecordsCount ملف طبي',
            ),
            style: TextStyle(
              color: _p.inkDark,
              fontSize: 14,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            _homeText('Last upload: yesterday', 'آخر رفع: أمس'),
            style: TextStyle(color: _p.inkMuted, fontSize: 11),
          ),
          const SizedBox(height: 14),
          SizedBox(
            height: 38,
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: _openMedicalRecords,
              icon: const Icon(Icons.cloud_upload_outlined, size: 16),
              label: Text(_homeText('Upload file', 'رفع ملف طبي')),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.primary.withValues(alpha: 0.10),
                foregroundColor: AppColors.primary,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                textStyle: const TextStyle(
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

  Widget _buildNotificationsCard() {
    final items = [
      (
        _homeText(
          'Your appointment with Dr. Ahmad was confirmed',
          'تم تأكيد موعدك مع د. أحمد علي',
        ),
        _homeText('10 minutes ago', 'منذ 10 دقائق'),
        Icons.check_circle_rounded,
        const Color(0xFF43A047),
      ),
      (
        _homeText('New test result uploaded', 'تم رفع نتيجة فحص جديد'),
        _homeText('1 day ago', 'منذ 1 يوم'),
        Icons.description_outlined,
        const Color(0xFF2196F3),
      ),
      (
        _homeText(
          'Do not forget your medicine today',
          'لا تنس تناول أدويتك اليوم',
        ),
        _homeText('2 days ago', 'منذ 2 يوم'),
        Icons.notifications_rounded,
        const Color(0xFF7C5CE7),
      ),
    ];

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: _homeCardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildSectionHeader(
            title: _homeText('Latest notifications', 'أحدث الإشعارات'),
            actionText: _homeText('View all', 'عرض الكل'),
            onActionTap: _openNotifications,
          ),
          const SizedBox(height: 8),
          ...List.generate(items.length, (index) {
            final item = items[index];
            return Padding(
              padding: EdgeInsets.only(
                bottom: index == items.length - 1 ? 0 : 8,
              ),
              child: Row(
                children: [
                  Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      color: item.$4.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(item.$3, color: item.$4, size: 18),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.$1,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: _p.inkDark,
                            fontSize: 11.5,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        Text(
                          item.$2,
                          style: TextStyle(color: _p.inkMuted, fontSize: 10.5),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
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
    final primaryColor = Theme.of(context).colorScheme.primary;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            CarelinkThemeIconButton(color: primaryColor),
            CarelinkLocaleIconButton(color: primaryColor),
            IconButton(
              icon: Icon(Icons.smart_toy_outlined, color: primaryColor),
              onPressed: _openAiAssistant,
            ),
            Stack(
              clipBehavior: Clip.none,
              children: [
                IconButton(
                  icon: Icon(
                    Icons.notifications_none_rounded,
                    color: primaryColor,
                  ),
                  onPressed: _openNotifications,
                ),
                if (_unreadNotifications > 0)
                  Positioned(
                    top: 4,
                    right: 4,
                    child: Container(
                      height: 16,
                      constraints: const BoxConstraints(minWidth: 16),
                      alignment: Alignment.center,
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE53935),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        _unreadNotifications > 9
                            ? '9+'
                            : '$_unreadNotifications',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ),
        const Spacer(),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Column(
              crossAxisAlignment: _ar
                  ? CrossAxisAlignment.start
                  : CrossAxisAlignment.end,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  isProfileLoading
                      ? context.tr('patient.hiLoading')
                      : _dynamicGreeting,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: _ar ? TextAlign.left : TextAlign.right,
                  style: TextStyle(
                    color: _p.inkDark,
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                    height: 1.15,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: _ar
                      ? [
                          Icon(
                            Icons.location_on_outlined,
                            color: primaryColor,
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
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ]
                      : [
                          Flexible(
                            child: Text(
                              _locationText,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: _p.inkMuted,
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          const SizedBox(width: 3),
                          Icon(
                            Icons.location_on_outlined,
                            color: primaryColor,
                            size: 14,
                          ),
                        ],
                ),
              ],
            ),
            const SizedBox(width: 10),
            InkWell(
              onTap: _openEditFromHero,
              customBorder: const CircleBorder(),
              child: Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: _p.surface,
                  shape: BoxShape.circle,
                  border: Border.all(color: _p.stroke, width: 2),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.08),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                clipBehavior: Clip.antiAlias,
                child: profileAvatarOrPlaceholder(
                  imageUrl: profileImageUrlFromMap(_patientProfile),
                  size: 48,
                  placeholderColor: AppColors.primary,
                  placeholderIcon: Icons.person_rounded,
                  iconSize: 22,
                ),
              ),
            ),
          ],
        ),
      ],
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
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
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
                    const SizedBox(height: 10),
                    SizedBox(
                      height: 28,
                      child: OutlinedButton(
                        onPressed: _openUpcomingDetails,
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.primary,
                          side: const BorderSide(color: AppColors.primary),
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: Text(
                          _homeText('Details', 'عرض التفاصيل'),
                          style: const TextStyle(
                            fontSize: 10.5,
                            fontWeight: FontWeight.bold,
                          ),
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
  });

  final String titleEn;
  final String titleAr;
  final String serviceType;
  final IconData icon;
  final List<String> terms;
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
