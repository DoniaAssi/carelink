import 'dart:async';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;

import 'package:carelink/core/app_localizations.dart';
import 'package:carelink/core/carelink_palette.dart';
import 'package:carelink/core/app_colors.dart';
import 'package:carelink/shared/widgets/carelink_theme_toggle.dart';
import 'package:carelink/core/locale_controller.dart';
import 'package:carelink/core/profile_avatar.dart' show profileImageProvider;
import 'package:carelink/core/theme_controller.dart';
import 'package:carelink/features/ai/provider_booking_eligibility.dart';
import 'package:carelink/features/ai/recommendation/ai_recommendation_repository.dart';
import 'package:carelink/features/ai/recommendation/models/recommendation_models.dart';
import 'package:carelink/features/ai/screens/ai_provider_details_screen.dart';
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

  List<ProviderModel>? _providers;
  List<AIRecommendationResult> _results = [];
  bool _loadingList = false;
  bool _fetchError = false;
  bool _isTimeout = false;
  bool _aiRunning = false;
  Map<String, dynamic>? _aiAnalysis;
  bool _showResults = false;
  bool _listening = false;
  String _speechPrefix = '';
  double? _patLat;
  double? _patLng;
  String? _activeUserId;
  bool _bootstrapped = false;

  bool get _ar => Directionality.of(context) == TextDirection.rtl;

  Map<String, dynamic>? _routeArgs;
  bool _depsChanged = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_depsChanged) {
      _routeArgs =
          ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
      _depsChanged = true;
    }
  }

  @override
  void initState() {
    super.initState();
    _providerRepo = AiProviderRepository(_api);
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    // Route args are now extracted in didChangeDependencies
    String resolvedId = widget.userId ?? '';
    String resolvedName = 'Patient';

    if (resolvedId.isEmpty && _routeArgs != null) {
      resolvedId = _routeArgs!['userId']?.toString() ?? '';
      resolvedName = _routeArgs!['displayName']?.toString() ?? 'Patient';
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

    final available = await _speech.initialize(
      onStatus: (status) {
        if (!mounted) return;
        if (status == 'done' || status == 'notListening') {
          setState(() => _listening = false);
        }
      },
      onError: (_) {
        if (mounted) setState(() => _listening = false);
      },
    );
    if (!available) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(_t('voiceUnavailable'))));
      return;
    }

    _speechPrefix = _caseController.text.trimRight();
    setState(() => _listening = true);
    await _speech.listen(
      localeId: _ar ? 'ar' : 'en_US',
      listenOptions: stt.SpeechListenOptions(
        listenMode: stt.ListenMode.confirmation,
        partialResults: true,
      ),
      onResult: (result) {
        if (!mounted) return;
        final recognized = result.recognizedWords.trim();
        final separator = _speechPrefix.isEmpty || recognized.isEmpty
            ? ''
            : ' ';
        final combined = '$_speechPrefix$separator$recognized';
        final text = combined.length > 500
            ? combined.substring(0, 500)
            : combined;
        setState(() {
          _caseController.text = text;
          _caseController.selection = TextSelection.collapsed(
            offset: _caseController.text.length,
          );
          if (result.finalResult) _listening = false;
        });
      },
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

    await Future<void>.delayed(const Duration(milliseconds: 2000));
    if (!mounted || !_aiRunning) return;

    final uid = _activeUserId ?? widget.userId ?? '';
    List<AIRecommendationResult> ranked = [];
    if (uid.isNotEmpty) {
      try {
        final payload = await _api.getProviderRecommendationsWithAnalysis(
          uid,
          query: _caseController.text.trim(),
        );
        _aiAnalysis = payload['aiAnalysis'] as Map<String, dynamic>?;
        final backendResults =
            payload['recommendations'] as List<dynamic>? ?? [];
        ranked = _mapBackendResults(backendResults);
      } catch (_) {
        if (!mounted) return;
        setState(() {
          _fetchError = true;
          _aiRunning = false;
        });
        return;
      }
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
  List<AIRecommendationResult> _mapBackendResults(List<dynamic> items) {
    final out = <AIRecommendationResult>[];

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
      if (provider == null) continue;
      if (!ProviderBookingEligibility.canBook(provider)) continue;

      final finalScore = (map['finalScore'] as num?)?.toDouble() ?? 0.0;
      final matchPct =
          (map['matchPercentage'] as num?)?.round() ??
          (finalScore * 100).round();
      final bd = map['scoreBreakdown'];
      final breakdown = ScoreBreakdown(
        location:
            (bd is Map ? (bd['location'] as num?)?.toDouble() : null) ?? 0.5,
        specialization:
            (bd is Map ? (bd['specialization'] as num?)?.toDouble() : null) ??
            0.5,
        availability:
            (bd is Map ? (bd['availability'] as num?)?.toDouble() : null) ??
            0.5,
        rating: (bd is Map ? (bd['rating'] as num?)?.toDouble() : null) ?? 0.5,
        experience:
            (bd is Map ? (bd['experience'] as num?)?.toDouble() : null) ?? 0.5,
        medicalCompatibility:
            (bd is Map
                ? (bd['medicalCompatibility'] as num?)?.toDouble()
                : null) ??
            0.5,
        history:
            (bd is Map ? (bd['history'] as num?)?.toDouble() : null) ?? 0.0,
      );

      final rawReasons = map['recommendationReasons'];
      final reasons = rawReasons is List
          ? rawReasons
                .map((r) => r.toString())
                .where((r) => r.trim().isNotEmpty)
                .toList()
          : <String>[];

      final rawTags = map['matchedTags'] ?? map['medicalTags'];
      final tags = rawTags is List
          ? rawTags.map((t) => t.toString()).where((t) => t.isNotEmpty).toList()
          : <String>[];

      final aiReason = (map['displayReason'] ?? map['aiMatchReason'])
          ?.toString();

      out.add(
        AIRecommendationResult(
          provider: provider,
          finalScore: finalScore,
          matchPercentage: matchPct.clamp(0, 99),
          breakdown: breakdown,
          weights: RecommendationWeights.coldStart,
          recommendationReasons: reasons,
          aiMatchReason: (aiReason?.trim().isNotEmpty == true)
              ? aiReason
              : null,
          matchedTags: tags,
          medicalMatchScore: (map['medicalMatchScore'] as num?)?.toDouble(),
          recommendationId: map['recommendationId']?.toString(),
        ),
      );
    }

    out.sort((a, b) => b.finalScore.compareTo(a.finalScore));
    return out.take(10).toList();
  }

  Future<void> _openDetails(AIRecommendationResult r) async {
    if (!ProviderBookingEligibility.canBook(r.provider)) return;
    debugPrint('AI provider selected: ${r.provider.fullName}');
    final recommendationId = r.recommendationId?.trim() ?? '';
    if (recommendationId.isNotEmpty) {
      ApiService().selectProviderRecommendation(recommendationId).catchError((
        error,
      ) {
        debugPrint('[AIRecommendations] failed to mark selected: $error');
      });
    }

    final dist = AiProviderRecommendationCard.distanceFrom(
      _patLat,
      _patLng,
      r.provider,
    );
    if (!mounted) return;
    _rememberRecent(r.provider.userId).catchError((_) {});
    final becameUnavailable = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => AiProviderDetailsScreen(
          result: r,
          patientUserId:
              (_activeUserId?.isNotEmpty == true && _activeUserId != 'guest')
              ? _activeUserId
              : null,
          distanceKm: dist,
          caseReason: _caseController.text.trim(),
        ),
      ),
    );
    if (becameUnavailable == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('هذا الموعد لم يعد متاحاً، الرجاء اختيار وقت آخر.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      await _loadProviders();
      if (mounted) await _analyzeCase();
    }
  }

  Future<void> _rememberRecent(String providerId) async {
    final prefs = await SharedPreferences.getInstance();
    final key = 'ai_recent_${_activeUserId ?? widget.userId ?? 'guest'}';
    final cur = prefs.getStringList(key) ?? <String>[];
    cur.remove(providerId);
    cur.insert(0, providerId);
    await prefs.setStringList(key, cur.take(8).toList());
  }

  void _safePopOrHome() {
    final route = ModalRoute.of(context);
    if (route?.canPop == true) {
      Navigator.of(context).pop();
      return;
    }

    Navigator.pushNamedAndRemoveUntil(
      context,
      '/patient-home',
      (route) => false,
      arguments: {'userId': _activeUserId ?? '', 'initialTab': 0},
    );
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
      _safePopOrHome();
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
                    _safePopOrHome();
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
                _safePopOrHome();
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

  PreferredSizeWidget _buildResultsAppBar() {
    final p = CarelinkPalette.of(context);
    return PreferredSize(
      preferredSize: const Size.fromHeight(116),
      child: ColoredBox(
        color: p.pageBg,
        child: SafeArea(
          bottom: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 10),
            child: Row(
              children: [
                _roundIconButton(
                  icon: Icons.arrow_back_ios_new_rounded,
                  onTap: _handleBack,
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Find Providers',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: p.inkDark,
                          fontSize: 30,
                          fontWeight: FontWeight.w900,
                          height: 1,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Find the best care for your needs',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: p.inkMuted,
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
                _roundIconButton(
                  icon: Icons.language_rounded,
                  onTap: localeController.toggle,
                ),
                const SizedBox(width: 10),
                _roundIconButton(
                  icon: p.isDark
                      ? Icons.light_mode_rounded
                      : Icons.dark_mode_rounded,
                  onTap: themeController.toggle,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _roundIconButton({required IconData icon, VoidCallback? onTap}) {
    final p = CarelinkPalette.of(context);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(22),
        onTap: onTap,
        child: Container(
          width: 52,
          height: 52,
          decoration: BoxDecoration(
            color: p.surface,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: p.stroke),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: p.isDark ? 0.20 : 0.05),
                blurRadius: 18,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Icon(icon, color: AppColors.primary, size: 24),
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
              appBar: _showResults
                  ? _buildResultsAppBar()
                  : PatientTopActions(showBack: true, onBack: _handleBack),
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
                                    onPressed: _safePopOrHome,
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
            canPop: false,
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
              } else {
                _safePopOrHome();
              }
            },
            child: Scaffold(
              backgroundColor: p.pageBg,
              appBar: _showResults
                  ? _buildResultsAppBar()
                  : PatientTopActions(showBack: true, onBack: _handleBack),
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

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Hero Robot
          Center(
            child: SizedBox(
              height: 160,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Container(
                    width: 140,
                    height: 140,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppColors.primary.withValues(alpha: 0.05),
                    ),
                  ),
                  Image.asset(
                    'assets/images/ai_robot_illustration.png',
                    height: 120,
                    errorBuilder: (_, error, stackTrace) =>
                        const SizedBox.shrink(),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),

          // Greeting
          Text(
            _ar
                ? 'مرحباً، كيف أقدر أساعدك اليوم؟'
                : 'Hello, how can I help you today?',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w900,
              color: p.inkDark,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _ar
                ? 'اكتبي حالتك أو اختاري مثال سريع وسنرشح لك أفضل مقدم رعاية مناسب.'
                : 'Type your case or pick a quick example and we will recommend the best care provider.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: p.inkMuted,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 32),

          // Input Card
          Container(
            decoration: BoxDecoration(
              color: p.surface,
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 24,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  TextField(
                    controller: _caseController,
                    onChanged: (_) => setState(() {}),
                    maxLines: 4,
                    minLines: 3,
                    style: TextStyle(
                      color: p.inkDark,
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                    decoration: InputDecoration(
                      hintText: _ar
                          ? 'اكتبي حالتك هنا...'
                          : 'Type your case here...',
                      hintStyle: TextStyle(color: p.inkMuted, fontSize: 15),
                      border: InputBorder.none,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _VoiceInputButton(
                        listening: _listening,
                        onPressed: _toggleVoice,
                        semanticLabel: _listening
                            ? (_ar ? 'إيقاف التسجيل' : 'Stop recording')
                            : (_ar
                                  ? 'بدء الإدخال الصوتي'
                                  : 'Start voice input'),
                      ),
                      Expanded(
                        child: Text(
                          '${_caseController.text.length}/500',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: p.inkMuted,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      Semantics(
                        button: true,
                        label: _ar ? 'تحليل الحالة' : 'Analyze case',
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: _analyzeCase,
                            customBorder: const CircleBorder(),
                            child: Ink(
                              width: 42,
                              height: 42,
                              decoration: BoxDecoration(
                                color: AppColors.primary,
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: AppColors.primary.withValues(
                                      alpha: 0.24,
                                    ),
                                    blurRadius: 12,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: const Icon(
                                Icons.arrow_upward_rounded,
                                color: Colors.white,
                                size: 21,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 32),

          // Quick Suggestions
          Text(
            _ar ? 'أمثلة سريعة' : 'Quick Examples',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w800,
              color: p.inkDark,
            ),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 12,
            alignment: WrapAlignment.center,
            children: [
              _buildSuggestionChip(context.tr('ai.quickExample.woundCare')),
              _buildSuggestionChip(
                context.tr('ai.quickExample.homeInjection'),
              ),
              _buildSuggestionChip(context.tr('ai.quickExample.elderlyCare')),
              _buildSuggestionChip(context.tr('ai.quickExample.heartProblem')),
              _buildSuggestionChip(context.tr('ai.quickExample.fever')),
              _buildSuggestionChip(
                context.tr('ai.quickExample.medicationAdministration'),
              ),
            ],
          ),
          const SizedBox(height: 40),

          // Privacy
          Text(
            _ar
                ? 'الذكاء الاصطناعي يحلل حالتك بدقة لاختيار أفضل مقدم رعاية لك'
                : 'AI accurately analyzes your case to select the best care provider',
            style: TextStyle(
              color: p.inkMuted,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildSuggestionChip(String label) {
    return ActionChip(
      backgroundColor: Theme.of(context).colorScheme.surface,
      side: BorderSide(color: AppColors.primary.withValues(alpha: 0.2)),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      label: Text(
        label,
        style: const TextStyle(
          color: AppColors.primary,
          fontSize: 13,
          fontWeight: FontWeight.w700,
        ),
      ),
      onPressed: () {
        _caseController.text = label;
        _analyzeCase();
      },
    );
  }

  Widget _resultsBody() {
    final p = CarelinkPalette.of(context);
    final isEmergency = _analysisValue('isEmergency') == 'true';

    return CustomScrollView(
      slivers: [
        if (isEmergency)
          SliverToBoxAdapter(
            child: Container(
              margin: const EdgeInsets.fromLTRB(20, 12, 20, 4),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.red.withValues(alpha: p.isDark ? 0.14 : 0.08),
                border: Border.all(color: Colors.red.withValues(alpha: 0.32)),
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: EdgeInsets.only(top: 1),
                    child: Icon(
                      Icons.emergency_rounded,
                      color: Colors.red,
                      size: 20,
                    ),
                  ),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'This appears to be an emergency. Please call emergency services immediately.',
                      style: TextStyle(
                        color: Colors.red,
                        fontSize: 12.5,
                        fontWeight: FontWeight.w800,
                        height: 1.45,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 10),
            child: Row(
              children: [
                Expanded(child: _searchBox()),
                const SizedBox(width: 12),
                _filterButton(),
              ],
            ),
          ),
        ),
        SliverToBoxAdapter(
          child: SizedBox(
            height: 54,
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              scrollDirection: Axis.horizontal,
              children: [
                _filterChip(
                  icon: Icons.auto_awesome_rounded,
                  label: 'Smart match',
                  selected: true,
                ),
                const SizedBox(width: 10),
                _filterChip(icon: Icons.location_on_outlined, label: 'Nearest'),
                const SizedBox(width: 10),
                _filterChip(
                  icon: Icons.star_border_rounded,
                  label: 'Top rated',
                ),
                const SizedBox(width: 10),
                _filterChip(icon: Icons.bolt_rounded, label: 'Available now'),
                const SizedBox(width: 10),
                _filterChip(icon: Icons.expand_more_rounded, label: 'More'),
              ],
            ),
          ),
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 16),
            child: _providersHeroBanner(_results.length),
          ),
        ),
        if (_results.isEmpty)
          SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.fromLTRB(
                32,
                48,
                32,
                120 + MediaQuery.paddingOf(context).bottom,
              ),
              child: Column(
                children: [
                  Container(
                    width: 72,
                    height: 6,
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.18),
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'We could not find a suitable care provider right now.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: p.inkDark,
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: OutlinedButton(
                      onPressed: _handleBack,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.primary,
                        side: BorderSide(
                          color: AppColors.primary.withValues(alpha: 0.45),
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: const Text(
                        'View all care providers',
                        style: TextStyle(fontWeight: FontWeight.w800),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          )
        else ...[
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            sliver: SliverList.separated(
              itemBuilder: (context, index) =>
                  _providerListCard(_results[index], index),
              separatorBuilder: (_, _) => const SizedBox(height: 14),
              itemCount: _results.length,
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.fromLTRB(
                20,
                16,
                20,
                120 + MediaQuery.paddingOf(context).bottom,
              ),
              child: _trustFooter(),
            ),
          ),
        ],
      ],
    );
  }

  Widget _filterButton() {
    return SizedBox(
      width: 70,
      height: 58,
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF009879), Color(0xFF006F61)],
          ),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: AppColors.primary.withValues(alpha: 0.22),
              blurRadius: 22,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: const Icon(Icons.tune_rounded, color: Colors.white, size: 30),
      ),
    );
  }

  Widget _searchBox() {
    final p = CarelinkPalette.of(context);
    return TextField(
      controller: _caseController,
      textInputAction: TextInputAction.search,
      onSubmitted: (_) => _analyzeCase(),
      style: TextStyle(
        color: p.inkDark,
        fontSize: 16,
        fontWeight: FontWeight.w700,
      ),
      decoration: InputDecoration(
        hintText: 'Search by name, specialty, or service',
        hintStyle: TextStyle(color: p.inkMuted, fontWeight: FontWeight.w600),
        prefixIcon: const Icon(Icons.search_rounded, color: AppColors.primary),
        filled: true,
        fillColor: p.surface,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 18,
          vertical: 18,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(22),
          borderSide: BorderSide(color: p.stroke),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(22),
          borderSide: BorderSide(color: p.stroke),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(22),
          borderSide: const BorderSide(color: AppColors.primary, width: 1.4),
        ),
      ),
    );
  }

  Widget _filterChip({
    required IconData icon,
    required String label,
    bool selected = false,
  }) {
    final p = CarelinkPalette.of(context);
    return Container(
      height: 44,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: selected ? AppColors.primary : p.surface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: selected ? AppColors.primary : p.stroke,
          width: 1.1,
        ),
        boxShadow: selected
            ? [
                BoxShadow(
                  color: AppColors.primary.withValues(alpha: 0.20),
                  blurRadius: 16,
                  offset: const Offset(0, 8),
                ),
              ]
            : null,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 18,
            color: selected ? Colors.white : AppColors.primary,
          ),
          const SizedBox(width: 8),
          Text(
            label,
            style: TextStyle(
              color: selected ? Colors.white : p.inkDark,
              fontSize: 14,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }

  Widget _providersHeroBanner(int count) {
    final p = CarelinkPalette.of(context);
    return Container(
      height: 116,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: [
            AppColors.primary.withValues(alpha: p.isDark ? 0.20 : 0.08),
            const Color(0xFFBAEBDD).withValues(alpha: p.isDark ? 0.16 : 0.42),
          ],
        ),
        borderRadius: BorderRadius.circular(22),
      ),
      child: Stack(
        children: [
          Positioned(
            right: 18,
            bottom: 0,
            child: Icon(
              Icons.health_and_safety_rounded,
              color: AppColors.primary.withValues(alpha: 0.34),
              size: 92,
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(22),
            child: Row(
              children: [
                Container(
                  width: 62,
                  height: 62,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(
                      alpha: p.isDark ? 0.10 : 0.42,
                    ),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.medical_services_outlined,
                    color: AppColors.primary,
                    size: 30,
                  ),
                ),
                const SizedBox(width: 18),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '$count care providers available',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: p.inkDark,
                          fontSize: 20,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Choose the right provider for your care needs',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: p.inkMuted,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _providerListCard(AIRecommendationResult result, int index) {
    final p = CarelinkPalette.of(context);
    final provider = result.provider;
    final distance = AiProviderRecommendationCard.distanceFrom(
      _patLat,
      _patLng,
      provider,
    );
    final fee = provider.consultationFee;
    final canBook = ProviderBookingEligibility.canBook(provider);
    final imageProvider = profileImageProvider(provider.profileImageUrl);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(22),
        onTap: canBook ? () => _openDetails(result) : null,
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: _providerCardDecoration(p),
          child: Column(
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Stack(
                    clipBehavior: Clip.none,
                    children: [
                      CircleAvatar(
                        radius: 39,
                        backgroundColor: AppColors.primary.withValues(
                          alpha: 0.08,
                        ),
                        backgroundImage: imageProvider,
                        child: imageProvider == null
                            ? Text(
                                _initials(provider.fullName),
                                style: const TextStyle(
                                  color: AppColors.primary,
                                  fontSize: 20,
                                  fontWeight: FontWeight.w900,
                                ),
                              )
                            : null,
                      ),
                      Positioned(
                        right: -2,
                        bottom: 4,
                        child: Container(
                          width: 24,
                          height: 24,
                          decoration: BoxDecoration(
                            color: canBook ? AppColors.primary : Colors.grey,
                            shape: BoxShape.circle,
                            border: Border.all(color: p.surface, width: 3),
                          ),
                          child: Icon(
                            canBook ? Icons.check_rounded : Icons.close_rounded,
                            color: Colors.white,
                            size: 14,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(width: 18),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                provider.fullName.isEmpty
                                    ? 'Care Provider'
                                    : provider.fullName,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: p.inkDark,
                                  fontSize: 20,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ),
                            Icon(
                              index == 1
                                  ? Icons.favorite_rounded
                                  : Icons.favorite_border_rounded,
                              color: index == 1
                                  ? const Color(0xFFE84E72)
                                  : p.inkMuted,
                              size: 27,
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          provider.serviceType.trim().isNotEmpty
                              ? provider.serviceType
                              : 'Consultation',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: AppColors.primary,
                            fontSize: 17,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            _miniPill(
                              Icons.star_rounded,
                              provider.overallRating > 0
                                  ? provider.overallRating.toStringAsFixed(1)
                                  : '${result.matchPercentage}%',
                              const Color(0xFFFFB300),
                            ),
                            _miniPill(
                              Icons.location_on_outlined,
                              distance == null
                                  ? 'Nearby'
                                  : '${distance.toStringAsFixed(1)} km',
                              const Color(0xFF39536D),
                            ),
                            _miniPill(
                              Icons.circle,
                              canBook ? 'Available' : 'Busy',
                              canBook ? const Color(0xFF08A657) : Colors.grey,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: Container(
                      height: 58,
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(
                          alpha: p.isDark ? 0.13 : 0.07,
                        ),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 38,
                            height: 38,
                            decoration: BoxDecoration(
                              color: p.surface.withValues(alpha: 0.74),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.credit_card_rounded,
                              color: AppColors.primary,
                              size: 22,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  fee == null
                                      ? 'Fee'
                                      : '${fee.toStringAsFixed(fee.truncateToDouble() == fee ? 0 : 1)} ILS',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: AppColors.primary,
                                    fontSize: 19,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                                Text(
                                  'per visit',
                                  style: TextStyle(
                                    color: p.inkMuted,
                                    fontSize: 12,
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
                  const SizedBox(width: 14),
                  Expanded(
                    child: SizedBox(
                      height: 58,
                      child: ElevatedButton(
                        onPressed: canBook ? () => _openDetails(result) : null,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          disabledBackgroundColor: Colors.grey.shade300,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          elevation: 0,
                        ),
                        child: const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Flexible(
                              child: Text(
                                'View details',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ),
                            SizedBox(width: 10),
                            Icon(Icons.chevron_right_rounded, size: 26),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  BoxDecoration _providerCardDecoration(CarelinkPalette p) {
    return BoxDecoration(
      color: p.surface,
      borderRadius: BorderRadius.circular(22),
      border: Border.all(
        color: p.isDark
            ? const Color(0xFF7CCFC6).withValues(alpha: 0.72)
            : const Color(0xFF7CCFC6),
        width: 1.4,
      ),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: p.isDark ? 0.16 : 0.035),
          blurRadius: 12,
          offset: const Offset(0, 6),
        ),
      ],
    );
  }

  Widget _miniPill(IconData icon, String label, Color color) {
    final p = CarelinkPalette.of(context);
    return Container(
      height: 32,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: p.isDark
            ? Colors.white.withValues(alpha: 0.06)
            : const Color(0xFFF2F6F8),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: icon == Icons.circle ? 10 : 18, color: color),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              color: p.inkDark,
              fontSize: 13,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }

  Widget _trustFooter() {
    final items = [
      (Icons.verified_user_outlined, 'Verified', 'Trusted providers'),
      (Icons.schedule_rounded, 'Fast Booking', 'Instant confirmation'),
      (Icons.lock_outline_rounded, 'Secure', 'Your data is safe'),
      (Icons.support_agent_rounded, '24/7 Support', 'We are here to help'),
    ];
    final p = CarelinkPalette.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 10),
      decoration: BoxDecoration(
        color: p.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: p.stroke),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: p.isDark ? 0.16 : 0.045),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          for (var i = 0; i < items.length; i++) ...[
            Expanded(
              child: Column(
                children: [
                  Icon(items[i].$1, color: AppColors.primary, size: 26),
                  const SizedBox(height: 8),
                  Text(
                    items[i].$2,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: p.inkDark,
                      fontSize: 12,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    items[i].$3,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: p.inkMuted,
                      fontSize: 10.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            if (i != items.length - 1)
              Container(width: 1, height: 42, color: p.stroke),
          ],
        ],
      ),
    );
  }

  String _initials(String value) {
    final parts = value
        .trim()
        .split(RegExp(r'\s+'))
        .where((part) => part.isNotEmpty)
        .toList();
    if (parts.isEmpty) return 'CL';
    final first = parts.first.characters.first;
    final second = parts.length > 1 ? parts.last.characters.first : '';
    return '$first$second'.toUpperCase();
  }

  String _t(String key) {
    final strings = _ar ? _arStrings : _enStrings;
    return strings[key] ?? _enStrings[key] ?? key;
  }

  String? _analysisValue(String key) {
    final value = _aiAnalysis?[key]?.toString().trim();
    if (value == null || value.isEmpty || value.toLowerCase() == 'null') {
      return null;
    }
    return value;
  }
}

class _VoiceInputButton extends StatefulWidget {
  const _VoiceInputButton({
    required this.listening,
    required this.onPressed,
    required this.semanticLabel,
  });

  final bool listening;
  final VoidCallback onPressed;
  final String semanticLabel;

  @override
  State<_VoiceInputButton> createState() => _VoiceInputButtonState();
}

class _VoiceInputButtonState extends State<_VoiceInputButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 880),
    );
    if (widget.listening) _controller.repeat();
  }

  @override
  void didUpdateWidget(covariant _VoiceInputButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.listening == oldWidget.listening) return;
    if (widget.listening) {
      _controller.repeat();
    } else {
      _controller
        ..stop()
        ..value = 0;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: widget.semanticLabel,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: widget.onPressed,
          customBorder: const CircleBorder(),
          child: AnimatedBuilder(
            animation: _controller,
            builder: (context, child) {
              final phase = _controller.value;
              final pulse = widget.listening
                  ? 1 + (0.055 * (1 - ((phase * 2) - 1).abs()))
                  : 1.0;
              return Transform.scale(
                scale: pulse,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(
                      alpha: widget.listening ? 1 : 0.86,
                    ),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.primary.withValues(
                          alpha: widget.listening ? 0.34 : 0.18,
                        ),
                        blurRadius: widget.listening ? 16 : 10,
                        spreadRadius: widget.listening ? 2 : 0,
                      ),
                    ],
                  ),
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 180),
                    switchInCurve: Curves.easeOutBack,
                    switchOutCurve: Curves.easeInCubic,
                    child: widget.listening
                        ? _buildWaveform(phase)
                        : const Icon(
                            Icons.mic_rounded,
                            key: ValueKey('microphone'),
                            color: Colors.white,
                            size: 21,
                          ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildWaveform(double phase) {
    return Row(
      key: const ValueKey('waveform'),
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(4, (index) {
        final shifted = (phase + (index * 0.17)) % 1;
        final amplitude = 1 - ((shifted * 2) - 1).abs();
        return AnimatedContainer(
          duration: const Duration(milliseconds: 70),
          width: 2.5,
          height: 7 + (amplitude * 13),
          margin: const EdgeInsets.symmetric(horizontal: 1.25),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(99),
          ),
        );
      }),
    );
  }
}

const _enStrings = <String, String>{
  'title': 'AI Care Match',
  'analysisTitle': 'Analyzing your case',
  'resultsTitle': 'Best matches for you',
  'headline': 'AI Care Match',
  'subtitle':
      'Describe your health need and CareLink will recommend suitable providers based on service, availability, rating, location, and medical compatibility.',
  'hint': 'Describe your case, e.g. My mother needs home nursing after surgery',
  'example': 'Example: My mother needs home nursing after surgery',
  'tapToSpeak': 'Tap to speak',
  'listening': 'Listening...',
  'analyze': 'Analyze',
  'resultsHeadline': 'AI Care Match',
  'resultsSubtitle':
      'Recommended using service fit, real availability, rating, location, and medical compatibility.',
  'emptyTitle': 'No suitable providers found',
  'empty':
      'Please describe a supported healthcare need such as home nursing, elderly care, physiotherapy, or post-surgery care.',
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
  'tapToSpeak': 'اضغط للتحدث',
  'listening': 'جاري الاستماع...',
  'analyze': 'تحليل الحالة',
  'resultsHeadline': 'وجدنا أفضل مقدمي الرعاية بناءً على حالتك وموقعك',
  'resultsSubtitle': 'تم ترتيب النتائج حسب نسبة التوافق',
  'empty':
      'لا يتوفر مقدمو رعاية موصى بهم حالياً. يرجى تجربة خدمة أو تاريخ آخر.',
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
