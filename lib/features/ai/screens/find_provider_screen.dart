import 'dart:async';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;

import 'package:carelink/core/carelink_palette.dart';
import 'package:carelink/core/app_colors.dart';
import 'package:carelink/shared/widgets/carelink_theme_toggle.dart';
import 'package:carelink/core/locale_controller.dart';
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
              appBar: PatientTopActions(showBack: true, onBack: _handleBack),
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
              appBar: PatientTopActions(showBack: true, onBack: _handleBack),
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
      padding: EdgeInsets.fromLTRB(
        20,
        8,
        20,
        38 + MediaQuery.paddingOf(context).bottom,
      ),
      children: [
        _robotHero(p),
        const SizedBox(height: 14),
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
        const SizedBox(height: 18),
        Container(
          padding: const EdgeInsets.fromLTRB(16, 14, 10, 10),
          decoration: BoxDecoration(
            color: p.surface,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: p.stroke),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: p.isDark ? 0.18 : 0.05),
                blurRadius: 18,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: TextField(
            controller: _caseController,
            minLines: 4,
            maxLines: 6,
            textInputAction: TextInputAction.newline,
            style: TextStyle(
              color: themeColor,
              fontSize: 14.5,
              height: 1.35,
              fontWeight: FontWeight.w600,
            ),
            decoration: InputDecoration(
              hintText: _t('hint'),
              hintStyle: TextStyle(
                color: helperColor,
                fontSize: 14,
                height: 1.35,
                fontWeight: FontWeight.w500,
              ),
              suffixIcon: _voiceInputButton(p),
              suffixIconConstraints: const BoxConstraints(
                minWidth: 68,
                minHeight: 64,
              ),
              filled: false,
              contentPadding: EdgeInsets.zero,
              border: InputBorder.none,
            ),
          ),
        ),
        const SizedBox(height: 7),
        Padding(
          padding: const EdgeInsetsDirectional.only(start: 12),
          child: Text(
            _listening ? _t('listening') : _t('example'),
            style: TextStyle(
              color: _listening ? AppColors.primary : helperColor,
              fontSize: 11.5,
              fontWeight: _listening ? FontWeight.w800 : FontWeight.w500,
            ),
          ),
        ),
        const SizedBox(height: 18),
        Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 340, minWidth: 240),
            child: SizedBox(
              height: 46,
              child: FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 18),
                  iconSize: 18,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: _aiRunning ? null : _analyzeCase,
                icon: const Icon(Icons.psychology_alt_rounded),
                label: Text(
                  _t('analyze'),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 15.5,
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _robotHero(CarelinkPalette p) {
    final robot = Image.asset(
      'assets/images/ai_robot_illustration.png',
      fit: BoxFit.contain,
      filterQuality: FilterQuality.high,
      errorBuilder: (context, error, stackTrace) {
        debugPrint(
          'Warning: Could not load assets/images/ai_robot_illustration.png',
        );
        return const Icon(
          Icons.smart_toy_outlined,
          size: 90,
          color: AppColors.primary,
        );
      },
    );

    return Container(
      height: 194,
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: p.isDark ? 0.08 : 0.045),
        borderRadius: BorderRadius.circular(32),
        border: Border.all(
          color: AppColors.primary.withValues(alpha: p.isDark ? 0.18 : 0.07),
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        alignment: Alignment.center,
        children: [
          PositionedDirectional(
            top: -38,
            end: -28,
            child: Container(
              width: 118,
              height: 118,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.primary.withValues(alpha: 0.06),
              ),
            ),
          ),
          PositionedDirectional(
            bottom: -42,
            start: -20,
            child: Container(
              width: 126,
              height: 126,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.primary.withValues(alpha: 0.045),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 38, vertical: 2),
            child: robot,
          ),
        ],
      ),
    );
  }

  Widget _voiceInputButton(CarelinkPalette p) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(width: 1, height: 48, color: p.stroke.withValues(alpha: 0.9)),
        const SizedBox(width: 10),
        Padding(
          padding: const EdgeInsetsDirectional.only(end: 8),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: _listening
                  ? AppColors.primary
                  : AppColors.primary.withValues(alpha: 0.1),
              boxShadow: _listening
                  ? [
                      BoxShadow(
                        color: AppColors.primary.withValues(alpha: 0.25),
                        blurRadius: 12,
                      ),
                    ]
                  : null,
            ),
            child: IconButton(
              tooltip: _listening ? _t('listening') : _t('tapToSpeak'),
              onPressed: _toggleVoice,
              padding: EdgeInsets.zero,
              icon: Icon(
                _listening ? Icons.stop_rounded : Icons.mic_rounded,
                color: _listening ? Colors.white : AppColors.primary,
                size: 22,
              ),
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

    return LayoutBuilder(
      builder: (context, constraints) {
        return CustomScrollView(
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
              sliver: SliverToBoxAdapter(
                child: Column(
                  children: [
                    Text(
                      _t('resultsHeadline'),
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: dark ? p.inkDark : AppColors.primary,
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                        height: 1.2,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      _t('resultsSubtitle'),
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: helperColor,
                        fontSize: 12.5,
                        height: 1.35,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                ),
              ),
            ),
            if (_hasVisibleAiAnalysis)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: dark
                          ? AppColors.primary.withValues(alpha: 0.12)
                          : Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: dark
                            ? AppColors.primary.withValues(alpha: 0.3)
                            : AppColors.primary.withValues(alpha: 0.16),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(
                            alpha: dark ? 0.22 : 0.055,
                          ),
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
                            const Icon(
                              Icons.analytics_rounded,
                              color: AppColors.primary,
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'AI Analysis',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w900,
                                color: dark ? Colors.white : p.inkDark,
                              ),
                            ),
                          ],
                        ),
                        if (_analysisValue('service') != null) ...[
                          const SizedBox(height: 12),
                          _analysisRow(
                            'Detected Service:',
                            _analysisValue('service')!,
                          ),
                        ],
                        if (_analysisValue('need') != null) ...[
                          const SizedBox(height: 4),
                          _analysisRow('Care Need:', _analysisValue('need')!),
                        ],
                        if (_analysisValue('priority') != null) ...[
                          const SizedBox(height: 4),
                          _analysisRow(
                            'Priority:',
                            _analysisValue('priority')!,
                          ),
                        ],
                        if (_analysisValue('note') != null) ...[
                          const SizedBox(height: 8),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Icon(Icons.info_outline, color: AppColors.primary, size: 16),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  _analysisValue('note')!,
                                  style: const TextStyle(
                                    fontSize: 13,
                                    color: AppColors.primary,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            if (_results.isEmpty)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(24, 42, 24, 24),
                  child: Column(
                    children: [
                      Container(
                        width: 74,
                        height: 74,
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(
                            alpha: p.isDark ? 0.16 : 0.08,
                          ),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.manage_search_rounded,
                          color: AppColors.primary,
                          size: 36,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        _t('emptyTitle'),
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: p.inkDark,
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _t('empty'),
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: p.inkMuted,
                          fontSize: 13.5,
                          height: 1.45,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              )
            else
              SliverPadding(
                padding: EdgeInsets.fromLTRB(
                  16,
                  0,
                  16,
                  148 + MediaQuery.paddingOf(context).bottom,
                ),
                sliver: SliverList.separated(
                  itemBuilder: (context, index) {
                    final result = _results[index];
                    return AiProviderRecommendationCard(
                      rank: index + 1,
                      result: result,
                      highlighted: index == 0,
                      distanceKm: AiProviderRecommendationCard.distanceFrom(
                        _patLat,
                        _patLng,
                        result.provider,
                      ),
                      onTap: () => _openDetails(result),
                      isArabic: _ar,
                    );
                  },
                  separatorBuilder: (_, _) => const SizedBox(height: 12),
                  itemCount: _results.length,
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _analysisRow(String label, String value) {
    final dark = CarelinkPalette.of(context).isDark;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 118,
          child: Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: dark ? Colors.white70 : Colors.black54,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: dark ? Colors.white : Colors.black87,
            ),
          ),
        ),
      ],
    );
  }

  String _t(String key) {
    final strings = _ar ? _arStrings : _enStrings;
    return strings[key] ?? _enStrings[key] ?? key;
  }

  bool get _hasVisibleAiAnalysis {
    final analysis = _aiAnalysis;
    if (analysis == null || _results.isEmpty) return false;
    return [
      'service',
      'need',
      'priority',
      'note',
    ].any((key) => _analysisValue(key) != null);
  }

  String? _analysisValue(String key) {
    final value = _aiAnalysis?[key]?.toString().trim();
    if (value == null || value.isEmpty || value.toLowerCase() == 'null') {
      return null;
    }
    return value;
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
