import 'dart:async';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;

import 'package:carelink/core/carelink_palette.dart';
import 'package:carelink/core/app_colors.dart';
import 'package:carelink/shared/widgets/carelink_theme_toggle.dart';
import 'package:carelink/core/locale_controller.dart';
import 'package:carelink/core/theme_controller.dart';
import 'package:carelink/features/ai/recommendation/ai_recommendation_engine.dart';
import 'package:carelink/features/ai/recommendation/ai_recommendation_repository.dart';
import 'package:carelink/features/ai/recommendation/mock_ai_data.dart';
import 'package:carelink/features/ai/recommendation/models/recommendation_models.dart';
import 'package:carelink/features/ai/recommendation/recommendation_request_parser.dart';
import 'package:carelink/features/ai/widgets/ai_provider_recommendation_card.dart';
import 'package:carelink/features/ai/widgets/ai_recommendation_loader.dart';
import 'package:carelink/shared/models/provider_model.dart';
import 'package:carelink/shared/services/api_service.dart';
import 'package:carelink/shared/services/location_service.dart';

/// Patient AI assistant entry, analysis, and ranked provider results.
class FindProviderScreen extends StatefulWidget {
  const FindProviderScreen({super.key, this.userId});

  final String? userId;

  @override
  State<FindProviderScreen> createState() => _FindProviderScreenState();
}

class _FindProviderScreenState extends State<FindProviderScreen> {
  final _caseController = TextEditingController();
  final _speech = stt.SpeechToText();
  final _api = ApiService();
  late final AiProviderRepository _providerRepo;
  late final PatientRecommendationProfileRepository _profileRepo;

  List<ProviderModel>? _providers;
  PatientRecommendationProfile _patient = MockAiData.newPatient('guest');
  List<AIRecommendationResult> _results = [];
  bool _loadingList = false;
  bool _fetchError = false;
  bool _isTimeout = false;
  bool _aiRunning = false;
  bool _showResults = false;
  bool _listening = false;
  double? _patLat;
  double? _patLng;
  String? _selectedCategoryKey;
  String? _activeUserId;
  bool _bootstrapped = false;

  bool get _ar => Directionality.of(context) == TextDirection.rtl;

  static const _categoryKeys = [
    'homeNurse',
    'elderly',
    'afterSurgery',
    'physio',
    'mental',
  ];

  @override
  void initState() {
    super.initState();
    _providerRepo = AiProviderRepository(_api);
    _profileRepo = PatientRecommendationProfileRepository(_api);
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    // Safely extract from multiple inputs to protect against direct named-route URL entries
    String resolvedId = widget.userId ?? '';
    String resolvedName = 'Patient';
    if (mounted) {
      final routeArgs =
          ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
      if (resolvedId.isEmpty) {
        resolvedId = routeArgs?['userId']?.toString() ?? '';
      }
      resolvedName = routeArgs?['displayName']?.toString() ?? 'Patient';
    }
    if (resolvedId.isEmpty) {
      final prefs = await SharedPreferences.getInstance();
      resolvedId = prefs.getString('session_user_id') ?? '';
      if (resolvedName == 'Patient') {
        resolvedName = prefs.getString('session_display_name') ?? 'Patient';
      }
    }

    if (mounted) {
      setState(() {
        _activeUserId = resolvedId;
        _bootstrapped = true;
      });
    }

    await _loadLocation();
    await _reloadPatientOnly();
    await _loadProviders();
  }

  Future<void> _loadLocation() async {
    try {
      final pos = await LocationService().getCurrentPosition();
      if (!mounted) return;
      setState(() {
        _patLat = pos.latitude;
        _patLng = pos.longitude;
      });
    } catch (_) {}
  }

  Future<void> _reloadPatientOnly() async {
    final uid = _activeUserId ?? widget.userId ?? 'guest';
    final prefs = await SharedPreferences.getInstance();
    final returningDemo = prefs.getBool('ai_returning_demo_$uid') ?? false;
    final p = await _profileRepo.load(
      userId: uid,
      returningDemo: returningDemo,
    );
    if (!mounted) return;
    setState(() => _patient = p);
  }

  Future<void> _loadProviders() async {
    if (!mounted) return;
    setState(() {
      _loadingList = true;
      _fetchError = false;
    });
    try {
      final list = await _providerRepo.loadMergedProviders();
      if (!mounted) return;
      setState(() {
        _providers = list;
        _loadingList = false;
        _fetchError = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _providers = null;
        _loadingList = false;
        _fetchError = true;
      });
    }
  }

  Future<void> _toggleVoice() async {
    if (_listening) {
      await _speech.stop();
      if (mounted) setState(() => _listening = false);
      return;
    }

    final available = await _speech.initialize();
    if (!available) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(_t('voiceUnavailable'))));
      return;
    }

    setState(() => _listening = true);
    await _speech.listen(
      localeId: _ar ? 'ar' : 'en_US',
      listenOptions: stt.SpeechListenOptions(
        listenMode: stt.ListenMode.confirmation,
        partialResults: true,
      ),
      onResult: (result) {
        _caseController.text = result.recognizedWords;
        _caseController.selection = TextSelection.fromPosition(
          TextPosition(offset: _caseController.text.length),
        );
        if (result.finalResult && mounted) {
          setState(() => _listening = false);
        }
      },
    );
  }

  void _selectCategory(String key) {
    setState(() {
      _selectedCategoryKey = key;
    });
    final label = _t(key);
    _caseController.text = label;
    _caseController.selection = TextSelection.collapsed(
      offset: _caseController.text.length,
    );
  }

  Future<void> _analyzeCase() async {
    FocusScope.of(context).unfocus();

    setState(() {
      _aiRunning = true;
      _showResults = false;
      _isTimeout = false;
    });

    debugPrint('[AI_DEBUG] transition to analysis');

    if (_providers == null || _loadingList || _fetchError) {
      if ((_providers == null || _fetchError) && !_loadingList) {
        _loadProviders();
      }

      final startTime = DateTime.now();
      while (_loadingList && mounted) {
        final elapsed = DateTime.now().difference(startTime);
        if (elapsed.inSeconds >= 8) {
          setState(() {
            _isTimeout = true;
            _aiRunning = false;
          });
          return;
        }
        await Future<void>.delayed(const Duration(milliseconds: 100));
      }
    }

    if (!mounted) return;

    if (_fetchError || _isTimeout) {
      setState(() {
        _aiRunning = false;
      });
      return;
    }

    final currentProviders = _providers;
    if (currentProviders == null) {
      setState(() {
        _aiRunning = false;
      });
      return;
    }

    if (currentProviders.isEmpty) {
      setState(() {
        _aiRunning = false;
      });
      return;
    }

    await Future<void>.delayed(const Duration(milliseconds: 2000));
    if (!mounted || !_aiRunning) return;

    final uid = _activeUserId ?? widget.userId ?? '';
    List<AIRecommendationResult> ranked = [];

    // Try backend recommendations first; fall back to local engine on failure.
    if (uid.isNotEmpty) {
      try {
        final backendResults = await _api.getProviderRecommendations(
          uid,
          query: _caseController.text.trim(),
        );
        ranked = _mapBackendResults(backendResults, currentProviders);
      } catch (_) {}
    }

    if (ranked.isEmpty) {
      final req = RecommendationRequestParser.fromInputs(
        searchText: _caseController.text.trim(),
        categoryKey: null,
      );
      ranked = AiRecommendationEngine.recommendProviders(
        patient: _patient,
        request: req,
        providers: currentProviders,
        top: 10,
      );
    }

    if (!mounted || !_aiRunning) return;
    debugPrint('[AI_DEBUG] transition to results');
    setState(() {
      _results = ranked;
      _aiRunning = false;
      _showResults = true;
    });
  }

  /// Maps a backend `/providers/recommendations/:id` response to Flutter models.
  List<AIRecommendationResult> _mapBackendResults(
    List<dynamic> items,
    List<ProviderModel> localProviders,
  ) {
    final out = <AIRecommendationResult>[];
    final localById = {for (final p in localProviders) p.userId: p};

    for (final item in items) {
      if (item is! Map) continue;
      final map = Map<String, dynamic>.from(item);

      ProviderModel? provider;
      final raw = map['provider'];
      if (raw is Map) {
        try {
          provider = ProviderModel.fromJson(Map<String, dynamic>.from(raw));
        } catch (_) {}
      }
      provider ??= localById[map['providerId']?.toString() ?? ''];
      if (provider == null) continue;

      final finalScore = (map['finalScore'] as num?)?.toDouble() ?? 0.0;
      final matchPct = (map['matchPercentage'] as num?)?.round() ?? (finalScore * 100).round();
      final bd = map['scoreBreakdown'];
      final breakdown = ScoreBreakdown(
        location:             (bd is Map ? (bd['location']             as num?)?.toDouble() : null) ?? 0.5,
        specialization:       (bd is Map ? (bd['specialization']       as num?)?.toDouble() : null) ?? 0.5,
        availability:         (bd is Map ? (bd['availability']         as num?)?.toDouble() : null) ?? 0.5,
        rating:               (bd is Map ? (bd['rating']               as num?)?.toDouble() : null) ?? 0.5,
        experience:           (bd is Map ? (bd['experience']           as num?)?.toDouble() : null) ?? 0.5,
        medicalCompatibility: (bd is Map ? (bd['medicalCompatibility'] as num?)?.toDouble() : null) ?? 0.5,
        history:              (bd is Map ? (bd['history']              as num?)?.toDouble() : null) ?? 0.0,
      );

      final rawReasons = map['recommendationReasons'];
      final reasons = rawReasons is List
          ? rawReasons.map((r) => r.toString()).where((r) => r.trim().isNotEmpty).toList()
          : <String>[];

      final rawTags = map['matchedTags'] ?? map['medicalTags'];
      final tags = rawTags is List
          ? rawTags.map((t) => t.toString()).where((t) => t.isNotEmpty).toList()
          : <String>[];

      final aiReason = (map['displayReason'] ?? map['aiMatchReason'])?.toString();

      out.add(AIRecommendationResult(
        provider: provider,
        finalScore: finalScore,
        matchPercentage: matchPct.clamp(0, 99),
        breakdown: breakdown,
        weights: RecommendationWeights.coldStart,
        recommendationReasons: reasons,
        aiMatchReason: (aiReason?.trim().isNotEmpty == true) ? aiReason : null,
        matchedTags: tags,
        medicalMatchScore: (map['medicalMatchScore'] as num?)?.toDouble(),
      ));
    }

    out.sort((a, b) => b.finalScore.compareTo(a.finalScore));
    return out.take(10).toList();
  }

  Future<void> _openDetails(AIRecommendationResult r) async {
    await _rememberRecent(r.provider.userId);
    final dist = AiProviderRecommendationCard.distanceFrom(
      _patLat,
      _patLng,
      r.provider,
    );
    if (!mounted) return;
    await Navigator.pushNamed(
      context,
      '/ai-details',
      arguments: {
        'result': r,
        'selectedProvider': r.provider,
        'userId': _activeUserId ?? 'guest',
        'patientUserId': _activeUserId ?? 'guest',
        'distanceKm': dist,
        'caseReason': _caseController.text.trim(),
        'patientRequest': _caseController.text.trim(),
        'recommendedSpecialization': r.provider.specialization,
      },
    );
    await _reloadPatientOnly();
  }

  Future<void> _rememberRecent(String providerId) async {
    final prefs = await SharedPreferences.getInstance();
    final key = 'ai_recent_${_activeUserId ?? widget.userId ?? 'guest'}';
    final cur = prefs.getStringList(key) ?? <String>[];
    cur.remove(providerId);
    cur.insert(0, providerId);
    await prefs.setStringList(key, cur.take(8).toList());
  }

  void _handleBack() {
    if (_aiRunning) {
      setState(() {
        _aiRunning = false;
      });
    } else if (_showResults) {
      setState(() {
        _showResults = false;
      });
    } else {
      Navigator.of(context).pop();
    }
  }

  Widget _providersLoadingBody() {
    final p = CarelinkPalette.of(context);
    final themeColor = p.inkDark;
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const CircularProgressIndicator(color: AppColors.primary),
          const SizedBox(height: 16),
          Text(
            _t('loadingProvidersText'),
            style: TextStyle(fontWeight: FontWeight.bold, color: themeColor),
          ),
        ],
      ),
    );
  }

  Widget _providersErrorBody() {
    final p = CarelinkPalette.of(context);
    final themeColor = p.inkDark;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.cloud_off_rounded, size: 64, color: Colors.red),
            const SizedBox(height: 16),
            Text(
              _t('providersLoadError'),
              textAlign: TextAlign.center,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: themeColor,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: themeColor,
                    side: BorderSide(color: p.stroke),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 12,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  onPressed: () {
                    setState(() {
                      _fetchError = false;
                      _isTimeout = false;
                      _aiRunning = false;
                      _showResults = false;
                    });
                  },
                  child: Text(_t('backToInput')),
                ),
                const SizedBox(width: 12),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 12,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  onPressed: () {
                    setState(() {
                      _fetchError = false;
                      _isTimeout = false;
                    });
                    _analyzeCase();
                  },
                  child: Text(_t('retry')),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _providersEmptyBody() {
    final p = CarelinkPalette.of(context);
    final themeColor = p.inkDark;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.people_outline_rounded,
              size: 64,
              color: AppColors.primary,
            ),
            const SizedBox(height: 16),
            Text(
              _t('providersEmptyText'),
              textAlign: TextAlign.center,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: themeColor,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: themeColor,
                    side: BorderSide(color: p.stroke),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 12,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  onPressed: () {
                    Navigator.of(context).pop();
                  },
                  child: Text(_t('backToHome')),
                ),
                const SizedBox(width: 12),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 12,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  onPressed: () {
                    _loadProviders();
                  },
                  child: Text(_t('retry')),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomNav() {
    final p = CarelinkPalette.of(context);
    return Material(
      elevation: 18,
      shadowColor: Colors.black12,
      color: Colors.transparent,
      child: Container(
        margin: const EdgeInsets.fromLTRB(14, 0, 14, 14),
        decoration: BoxDecoration(
          color: p.navBackground,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: p.stroke),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: p.isDark ? 0.35 : 0.08),
              blurRadius: 24,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: SafeArea(
          top: false,
          child: BottomNavigationBar(
            currentIndex: 0,
            onTap: (index) {
              if (index == 0) {
                Navigator.of(context).pop();
              } else {
                Navigator.pushNamedAndRemoveUntil(
                  context,
                  '/patient-home',
                  (route) => false,
                  arguments: {
                    'userId': _activeUserId ?? '',
                    'initialTab': index,
                  },
                );
              }
            },
            selectedItemColor: AppColors.primary,
            unselectedItemColor: p.navUnselected,
            backgroundColor: Colors.transparent,
            elevation: 0,
            type: BottomNavigationBarType.fixed,
            selectedLabelStyle: const TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 11,
            ),
            unselectedLabelStyle: const TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 11,
            ),
            items: [
              BottomNavigationBarItem(
                icon: const Icon(Icons.home_rounded, size: 23),
                activeIcon: const Icon(
                  Icons.home_rounded,
                  size: 23,
                  color: AppColors.primary,
                ),
                label: _ar ? 'الرئيسية' : 'Home',
              ),
              BottomNavigationBarItem(
                icon: const Icon(Icons.calendar_month_rounded, size: 23),
                label: _ar ? 'حجوزاتي' : 'Bookings',
              ),
              BottomNavigationBarItem(
                icon: const Icon(Icons.favorite_border_rounded, size: 23),
                label: _ar ? 'رعايتي' : 'My care',
              ),
              BottomNavigationBarItem(
                icon: const Icon(Icons.folder_outlined, size: 23),
                label: _ar ? 'السجل الطبي' : 'Records',
              ),
              BottomNavigationBarItem(
                icon: const Icon(Icons.person_outline_rounded, size: 23),
                label: _ar ? 'الملف الشخصي' : 'Profile',
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _speech.cancel();
    _caseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([localeController, themeController]),
      builder: (context, _) {
        final p = CarelinkPalette.of(context);
        final themeColor = p.inkDark;

        final uid = _activeUserId;
        // Protective authentication state check to prevent blank screens/crashes
        if (_bootstrapped && (uid == null || uid.isEmpty)) {
          return Directionality(
            textDirection: localeController.isArabic
                ? TextDirection.rtl
                : TextDirection.ltr,
            child: Scaffold(
              backgroundColor: p.pageBg,
              appBar: PatientTopActions(
                showBack: true,
                onBack: _handleBack,
              ),
              body: SafeArea(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(
                      child: Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24.0),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(
                                Icons.error_outline_rounded,
                                size: 64,
                                color: Colors.red,
                              ),
                              const SizedBox(height: 16),
                              Text(
                                _t('sessionMissing'),
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: themeColor,
                                ),
                              ),
                              const SizedBox(height: 24),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  OutlinedButton(
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor: themeColor,
                                      side: BorderSide(color: p.stroke),
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 20,
                                        vertical: 12,
                                      ),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                    ),
                                    onPressed: () =>
                                        Navigator.of(context).pop(),
                                    child: Text(_t('backToHome')),
                                  ),
                                  const SizedBox(width: 12),
                                  ElevatedButton(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: AppColors.primary,
                                      foregroundColor: Colors.white,
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 24,
                                        vertical: 12,
                                      ),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                    ),
                                    onPressed: () {
                                      setState(() {
                                        _bootstrapped = false;
                                      });
                                      _bootstrap();
                                    },
                                    child: Text(_t('retry')),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }

        return Directionality(
          textDirection: localeController.isArabic
              ? TextDirection.rtl
              : TextDirection.ltr,
          child: PopScope(
            canPop: !_showResults && !_aiRunning,
            onPopInvokedWithResult: (didPop, result) {
              if (didPop) return;
              if (_aiRunning) {
                setState(() {
                  _aiRunning = false;
                });
              } else if (_showResults) {
                setState(() {
                  _showResults = false;
                });
              }
            },
            child: Scaffold(
              backgroundColor: p.pageBg,
              appBar: PatientTopActions(
                showBack: true,
                onBack: _handleBack,
              ),
              bottomNavigationBar: _buildBottomNav(),
              body: SafeArea(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(
                      child: _aiRunning
                          ? (_providers == null || _loadingList
                                ? _providersLoadingBody()
                                : AiRecommendationLoader(isArabic: _ar))
                          : _showResults
                          ? _resultsBody()
                          : (_fetchError || _isTimeout
                                ? _providersErrorBody()
                                : (_providers != null && _providers!.isEmpty
                                      ? _providersEmptyBody()
                                      : _inputBody())),
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

  Widget _inputBody() {
    final p = CarelinkPalette.of(context);
    final dark = p.isDark;
    final themeColor = p.inkDark;
    final helperColor = p.inkMuted;

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 22),
      children: [
        SizedBox(
          height: 188,
          child: Image.asset(
            'assets/images/ai_robot_illustration.png',
            fit: BoxFit.contain,
            errorBuilder: (context, error, stackTrace) {
              debugPrint(
                'Warning: Could not load assets/images/ai_robot_illustration.png',
              );
              return const Icon(
                Icons.smart_toy_outlined,
                size: 96,
                color: AppColors.primary,
              );
            },
          ),
        ),
        const SizedBox(height: 10),
        Text(
          _t('headline'),
          textAlign: TextAlign.center,
          style: TextStyle(
            color: dark ? Colors.blue[300] : AppColors.primary,
            fontSize: 22,
            fontWeight: FontWeight.w900,
            height: 1.15,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          _t('subtitle'),
          textAlign: TextAlign.center,
          style: TextStyle(
            color: themeColor,
            fontSize: 16,
            height: 1.45,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 22),
        TextField(
          controller: _caseController,
          minLines: 3,
          maxLines: 5,
          textInputAction: TextInputAction.newline,
          onChanged: (val) {
            if (_selectedCategoryKey != null) {
              final label = _t(_selectedCategoryKey!);
              if (val.trim() != label.trim()) {
                setState(() => _selectedCategoryKey = null);
              }
            }
          },
          style: TextStyle(color: themeColor),
          decoration: InputDecoration(
            hintText: _t('hint'),
            hintStyle: TextStyle(color: helperColor),
            helperText: _t('example'),
            helperStyle: TextStyle(color: helperColor),
            helperMaxLines: 2,
            filled: true,
            fillColor: p.surface,
            contentPadding: const EdgeInsets.all(16),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(color: p.stroke),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(color: p.stroke),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(
                color: AppColors.primary,
                width: 1.4,
              ),
            ),
          ),
        ),
        const SizedBox(height: 20),
        Text(
          _t('chooseType'),
          textAlign: TextAlign.center,
          style: TextStyle(
            color: themeColor,
            fontSize: 15,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          alignment: WrapAlignment.center,
          spacing: 10,
          runSpacing: 10,
          children: _categoryKeys
              .map(
                (key) => ChoiceChip(
                  selected: _selectedCategoryKey == key,
                  selectedColor: AppColors.primary.withValues(alpha: 0.15),
                  backgroundColor: p.surface,
                  side: BorderSide(
                    color: _selectedCategoryKey == key
                        ? AppColors.primary
                        : p.stroke,
                  ),
                  avatar: Icon(
                    _categoryIcon(key),
                    color: AppColors.primary,
                    size: 20,
                  ),
                  label: Text(
                    _t(key),
                    style: TextStyle(
                      color: _selectedCategoryKey == key
                          ? AppColors.primary
                          : themeColor,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  onSelected: (selected) {
                    if (selected) {
                      _selectCategory(key);
                    } else {
                      setState(() {
                        _selectedCategoryKey = null;
                        _caseController.clear();
                      });
                    }
                  },
                ),
              )
              .toList(),
        ),
        const SizedBox(height: 22),
        Center(
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: _toggleVoice,
            child: Container(
              width: 82,
              height: 82,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.primary,
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.28),
                    blurRadius: 18,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Icon(
                _listening ? Icons.stop_rounded : Icons.mic_rounded,
                color: Colors.white,
                size: 38,
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          _listening ? _t('listening') : _t('tapToSpeak'),
          textAlign: TextAlign.center,
          style: TextStyle(
            color: themeColor,
            fontSize: 13,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 18),
        SizedBox(
          height: 56,
          width: double.infinity,
          child: FilledButton.icon(
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.primary,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            onPressed: _aiRunning ? null : _analyzeCase,
            icon: const Icon(Icons.auto_awesome_rounded),
            label: Text(
              _t('analyze'),
              style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18),
            ),
          ),
        ),
      ],
    );
  }

  Widget _resultsBody() {
    final p = CarelinkPalette.of(context);
    final dark = p.isDark;
    final helperColor = p.inkMuted;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 110),
      children: [
        Text(
          _t('resultsHeadline'),
          textAlign: TextAlign.center,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: dark ? Colors.blue[300] : AppColors.primary,
            fontSize: 18,
            fontWeight: FontWeight.bold,
            height: 1.25,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          _t('resultsSubtitle'),
          textAlign: TextAlign.center,
          style: TextStyle(
            color: helperColor,
            fontSize: 13,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 16),
        if (_results.isEmpty)
          Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              _t('empty'),
              textAlign: TextAlign.center,
              style: TextStyle(color: p.inkMuted, fontWeight: FontWeight.w700),
            ),
          )
        else
          ..._results.asMap().entries.map(
            (entry) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: AiProviderRecommendationCard(
                rank: entry.key + 1,
                result: entry.value,
                distanceKm: AiProviderRecommendationCard.distanceFrom(
                  _patLat,
                  _patLng,
                  entry.value.provider,
                ),
                onTap: () => _openDetails(entry.value),
                isArabic: _ar,
              ),
            ),
          ),
      ],
    );
  }

  IconData _categoryIcon(String key) {
    switch (key) {
      case 'homeNurse':
        return Icons.home_work_outlined;
      case 'elderly':
        return Icons.elderly_rounded;
      case 'afterSurgery':
        return Icons.health_and_safety_outlined;
      case 'physio':
        return Icons.accessibility_new_rounded;
      case 'mental':
        return Icons.psychology_alt_outlined;
      default:
        return Icons.medical_services_outlined;
    }
  }

  String _t(String key) {
    final strings = _ar ? _arStrings : _enStrings;
    return strings[key] ?? _enStrings[key] ?? key;
  }
}

const _enStrings = <String, String>{
  'title': 'CareLink AI Assistant',
  'analysisTitle': 'Analyzing your case',
  'resultsTitle': 'Best matches for you',
  'headline': 'How can I help you today?',
  'subtitle':
      'Write or speak about your case and I will recommend the most suitable care provider.',
  'hint': 'Write your case here...',
  'example': 'Example: I need a nurse for my father after surgery',
  'chooseType': 'Or choose care type',
  'homeNurse': 'Home Nursing',
  'elderly': 'Elderly Care',
  'afterSurgery': 'Post-Surgery Care',
  'physio': 'Physiotherapy',
  'mental': 'Mental Health Support',
  'tapToSpeak': 'Tap to speak',
  'listening': 'Listening...',
  'analyze': 'Analyze Condition',
  'resultsHeadline':
      'We found the best care providers based on your case and location.',
  'resultsSubtitle': 'Results are ranked by compatibility match',
  'empty': 'No suitable providers found yet.',
  'voiceUnavailable': 'Voice input is not available on this device.',
  'providersLoading': 'Provider list is still loading. Try again shortly.',
  'language': 'Change language',
  'theme': 'Change theme',
  'authRequired':
      'Authentication Required\nPlease log in to search care providers.',
  'goToLogin': 'Go to Login',
  'sessionMissing':
      'Unable to open AI assistant because patient session data is missing.',
  'backToHome': 'Back to Home',
  'retry': 'Retry',
  'loadingProvidersText': 'Loading care providers...',
  'providersLoadError': 'Could not load care providers. Please try again.',
  'providersEmptyText': 'No care providers are available right now.',
  'backToInput': 'Back to Input',
};

const _arStrings = <String, String>{
  'title': 'مساعد كيرلينك الذكي',
  'analysisTitle': 'جاري تحليل حالتك',
  'resultsTitle': 'أفضل المطابقات لك',
  'headline': 'كيف يمكنني مساعدتك اليوم؟',
  'subtitle': 'اكتب أو تحدث عن حالتك وسأرشح لك مقدم الرعاية الأنسب',
  'hint': 'اكتب حالتك هنا...',
  'example': 'مثال: أحتاج ممرضة لرعاية والدي بعد العملية',
  'chooseType': 'أو اختر نوع الرعاية',
  'homeNurse': 'رعاية تمريضية منزلية',
  'elderly': 'رعاية كبار السن',
  'afterSurgery': 'رعاية ما بعد الجراحة',
  'physio': 'علاج طبيعي',
  'mental': 'دعم الصحة النفسية',
  'tapToSpeak': 'اضغط للتحدث',
  'listening': 'جاري الاستماع...',
  'analyze': 'تحليل الحالة',
  'resultsHeadline': 'وجدنا أفضل مقدمي الرعاية بناءً على حالتك وموقعك',
  'resultsSubtitle': 'تم ترتيب النتائج حسب نسبة التوافق',
  'empty': 'لم يتم العثور على مقدم رعاية مناسب حتى الآن.',
  'voiceUnavailable': 'الإدخال الصوتي غير متاح على هذا الجهاز.',
  'providersLoading': 'قائمة مقدمي الرعاية ما زالت قيد التحميل. حاول بعد قليل.',
  'language': 'تغيير اللغة',
  'theme': 'تغيير المظهر',
  'authRequired': 'تسجيل الدخول مطلوب\nيرجى تسجيل الدخول للبحث عن مقدمي رعاية.',
  'goToLogin': 'الذهاب لتسجيل الدخول',
  'sessionMissing':
      'Unable to open AI assistant because patient session data is missing.',
  'backToHome': 'العودة للرئيسية',
  'retry': 'إعادة المحاولة',
  'loadingProvidersText': 'جاري تحميل مقدمي الرعاية...',
  'providersLoadError': 'تعذر تحميل مقدمي الرعاية. حاول مرة أخرى.',
  'providersEmptyText': 'لا يوجد مقدمو رعاية متاحون حالياً',
  'backToInput': 'العودة للإدخال',
};
