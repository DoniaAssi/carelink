import 'dart:async';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:carelink/features/ai/recommendation/ai_recommendation_engine.dart';
import 'package:carelink/features/ai/recommendation/ai_recommendation_repository.dart';
import 'package:carelink/features/ai/recommendation/mock_ai_data.dart';
import 'package:carelink/features/ai/recommendation/models/recommendation_models.dart';
import 'package:carelink/features/ai/recommendation/recommendation_request_parser.dart';
import 'package:carelink/features/ai/screens/ai_provider_details_screen.dart';
import 'package:carelink/features/ai/screens/patient_ai_medical_record_screen.dart';
import 'package:carelink/features/ai/widgets/ai_flow_theme.dart';
import 'package:carelink/features/ai/widgets/ai_provider_recommendation_card.dart';
import 'package:carelink/features/ai/widgets/ai_recommendation_loader.dart';
import 'package:carelink/features/patient/screens/patient_home_screen.dart';
import 'package:carelink/shared/models/provider_model.dart';
import 'package:carelink/shared/services/api_service.dart';
import 'package:carelink/shared/services/location_service.dart';

/// CareLink “Find Doctors / Providers” with explainable hybrid scoring + loader.
class FindProviderScreen extends StatefulWidget {
  const FindProviderScreen({super.key, this.userId});

  final String? userId;

  @override
  State<FindProviderScreen> createState() => _FindProviderScreenState();
}

class _FindProviderScreenState extends State<FindProviderScreen> {
  final _searchController = TextEditingController();
  final _api = ApiService();
  late final AiProviderRepository _providerRepo;
  late final PatientRecommendationProfileRepository _profileRepo;

  List<ProviderModel> _providers = [];
  PatientRecommendationProfile _patient = MockAiData.newPatient('guest');
  List<AIRecommendationResult> _results = [];
  bool _loadingList = true;
  bool _aiRunning = false;
  bool _returningDemo = false;
  String _searchText = '';
  String? _activeCategory;
  double? _patLat;
  double? _patLng;

  static const _categories = <(String key, String label, IconData icon)>[
    ('general', 'General', Icons.local_hospital_outlined),
    ('lungs', 'Lungs', Icons.air_rounded),
    ('dentist', 'Dentist', Icons.medical_services_outlined),
    ('psychiatrist', 'Psychiatrist', Icons.psychology_outlined),
    ('covid', 'Covid-19', Icons.coronavirus_outlined),
    ('surgeon', 'Surgeon', Icons.content_cut_rounded),
    ('cardiology', 'Cardiologist', Icons.favorite_outline_rounded),
  ];

  @override
  void initState() {
    super.initState();
    _providerRepo = AiProviderRepository(_api);
    _profileRepo = PatientRecommendationProfileRepository(_api);
    _hydratePrefs();
    _bootstrap();
  }

  Future<void> _hydratePrefs() async {
    final prefs = await SharedPreferences.getInstance();
    final key = 'ai_returning_demo_${widget.userId ?? 'guest'}';
    final v = prefs.getBool(key) ?? false;
    if (mounted) setState(() => _returningDemo = v);
  }

  Future<void> _setReturningDemo(bool v) async {
    setState(() => _returningDemo = v);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(
      'ai_returning_demo_${widget.userId ?? 'guest'}',
      v,
    );
    await _reloadPatientOnly();
    await _runRecommendation(showOverlay: true);
  }

  Future<void> _bootstrap() async {
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
    final p = await _profileRepo.load(
      userId: widget.userId,
      returningDemo: _returningDemo,
    );
    if (!mounted) return;
    setState(() => _patient = p);
  }

  Future<void> _loadProviders() async {
    setState(() => _loadingList = true);
    try {
      final list = await _providerRepo.loadMergedProviders();
      if (!mounted) return;
      setState(() => _providers = list);
    } finally {
      if (mounted) setState(() => _loadingList = false);
    }
    await _runRecommendation(showOverlay: false);
  }

  Future<void> _runRecommendation({bool showOverlay = true}) async {
    if (_providers.isEmpty) return;

    if (showOverlay) {
      setState(() => _aiRunning = true);
      await Future<void>.delayed(const Duration(milliseconds: 1700));
    }

    final req = RecommendationRequestParser.fromInputs(
      searchText: _searchText,
      categoryKey: _activeCategory,
    );

    final ranked = AiRecommendationEngine.recommendProviders(
      patient: _patient,
      request: req,
      providers: _providers,
      top: 16,
    );

    if (!mounted) return;
    setState(() {
      _results = ranked;
      _aiRunning = false;
    });
  }

  Future<void> _onSearch() async {
    _searchText = _searchController.text.trim();
    await _runRecommendation(showOverlay: true);
  }

  Future<void> _onCategory(String? key) async {
    setState(() => _activeCategory = key);
    await _runRecommendation(showOverlay: true);
  }

  Future<void> _openDetails(AIRecommendationResult r) async {
    await _rememberRecent(r.provider.userId);
    final dist = AiProviderRecommendationCard.distanceFrom(
      _patLat,
      _patLng,
      r.provider,
    );
    if (!mounted) return;
    await Navigator.push<void>(
      context,
      MaterialPageRoute(
        builder: (_) => AiProviderDetailsScreen(
          patientUserId: widget.userId,
          result: r,
          distanceKm: dist,
        ),
      ),
    );
    await _reloadPatientOnly();
  }

  Future<void> _rememberRecent(String providerId) async {
    final prefs = await SharedPreferences.getInstance();
    final key = 'ai_recent_${widget.userId ?? 'guest'}';
    final cur = prefs.getStringList(key) ?? <String>[];
    cur.remove(providerId);
    cur.insert(0, providerId);
    await prefs.setStringList(key, cur.take(8).toList());
  }

  Future<List<ProviderModel>> _recentProviders() async {
    final prefs = await SharedPreferences.getInstance();
    final ids =
        prefs.getStringList('ai_recent_${widget.userId ?? 'guest'}') ??
        const [];
    final map = {for (final p in _providers) p.userId: p};
    return ids.map((id) => map[id]).whereType<ProviderModel>().toList();
  }

  AIRecommendationResult? _resultForProviderId(String id) {
    for (final r in _results) {
      if (r.provider.userId == id) return r;
    }
    return null;
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AiFlowTheme.pageBg,
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: AiFlowTheme.ink,
        elevation: 0,
        title: const Text(
          'Find providers',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.folder_shared_outlined),
            onPressed: () {
              final id = widget.userId?.trim() ?? '';
              if (id.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Sign in to view your structured record.'),
                  ),
                );
                return;
              }
              Navigator.push<void>(
                context,
                MaterialPageRoute(
                  builder: (_) => PatientAiMedicalRecordScreen(userId: id),
                ),
              );
            },
          ),
          TextButton(
            onPressed: () {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute<void>(
                  builder: (_) => PatientHomeScreen(
                    userId: widget.userId,
                  ),
                ),
              );
            },
            child: const Text('Home'),
          ),
        ],
      ),
      body: Stack(
        children: [
          ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
            children: [
              _searchBar(),
              const SizedBox(height: 12),
              _demoToggle(),
              const SizedBox(height: 8),
              _aiInfoCard(),
              const SizedBox(height: 16),
              _categoryRow(),
              const SizedBox(height: 18),
              _sectionTitle('Recommended for you'),
              const SizedBox(height: 8),
              _resultsList(),
              const SizedBox(height: 20),
              _sectionTitle('Recent providers'),
              const SizedBox(height: 8),
              _recentRow(),
            ],
          ),
          if (_aiRunning) const AiRecommendationLoader(),
        ],
      ),
    );
  }

  Widget _searchBar() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AiFlowTheme.cardStroke),
      ),
      child: TextField(
        controller: _searchController,
        textInputAction: TextInputAction.search,
        onSubmitted: (_) => _onSearch(),
        decoration: InputDecoration(
          hintText:
              'e.g. “2 PM Wednesday” or “book cardiology follow-up”',
          prefixIcon: const Icon(Icons.search, color: AiFlowTheme.primaryBlue),
          suffixIcon: IconButton(
            icon: const Icon(Icons.tune_rounded),
            color: AiFlowTheme.primaryBlue,
            onPressed: _onSearch,
          ),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 14,
          ),
        ),
      ),
    );
  }

  Widget _demoToggle() {
    return SwitchListTile(
      contentPadding: EdgeInsets.zero,
      title: const Text(
        'Graduation demo: returning heart patient',
        style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
      ),
      subtitle: const Text(
        'Adds chronic heart history + prior cardiologist rating for hybrid personalization.',
        style: TextStyle(fontSize: 11),
      ),
      value: _returningDemo,
      activeThumbColor: Colors.white,
      activeTrackColor: AiFlowTheme.primaryBlue,
      onChanged: _setReturningDemo,
    );
  }

  Widget _aiInfoCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFEFF6FF),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AiFlowTheme.primaryBlue.withValues(alpha: 0.15),
        ),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.auto_awesome_rounded,
                color: AiFlowTheme.primaryBlue,
                size: 20,
              ),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'AI matched these providers using your location, condition, availability, and medical history.',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                    height: 1.3,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 8),
          Text(
            'This recommendation is based on location, specialty, availability, rating, experience, and medical compatibility. For returning patients, previous visit reports also adjust the ranking.',
            style: TextStyle(fontSize: 11.5, height: 1.35),
          ),
        ],
      ),
    );
  }

  Widget _categoryRow() {
    return SizedBox(
      height: 104,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: _categories.length + 1,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, i) {
          if (i == 0) {
            final sel = _activeCategory == null;
            return _catChip(
              label: 'All',
              icon: Icons.grid_view_rounded,
              selected: sel,
              onTap: () => _onCategory(null),
            );
          }
          final c = _categories[i - 1];
          final selected = _activeCategory == c.$1;
          return _catChip(
            label: c.$2,
            icon: c.$3,
            selected: selected,
            onTap: () => _onCategory(c.$1),
          );
        },
      ),
    );
  }

  Widget _catChip({
    required String label,
    required IconData icon,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        width: 86,
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: selected
              ? AiFlowTheme.primaryBlue.withValues(alpha: 0.1)
              : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected ? AiFlowTheme.primaryBlue : AiFlowTheme.cardStroke,
            width: selected ? 1.4 : 1,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              color: selected ? AiFlowTheme.primaryBlue : AiFlowTheme.inkMuted,
            ),
            const SizedBox(height: 6),
            Text(
              label,
              maxLines: 2,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w800,
                color: selected ? AiFlowTheme.ink : AiFlowTheme.inkMuted,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _sectionTitle(String t) {
    return Text(
      t,
      style: const TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w800,
        color: AiFlowTheme.ink,
      ),
    );
  }

  Widget _resultsList() {
    if (_loadingList) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: CircularProgressIndicator(color: AiFlowTheme.primaryBlue),
        ),
      );
    }
    if (_results.isEmpty) {
      return const Text('No providers to display yet.');
    }
    return Column(
      children: _results
          .map(
            (r) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: AiProviderRecommendationCard(
                result: r,
                distanceKm: AiProviderRecommendationCard.distanceFrom(
                  _patLat,
                  _patLng,
                  r.provider,
                ),
                onTap: () => _openDetails(r),
              ),
            ),
          )
          .toList(),
    );
  }

  Widget _recentRow() {
    return FutureBuilder<List<ProviderModel>>(
      future: _recentProviders(),
      builder: (context, snap) {
        final list = snap.data ?? const <ProviderModel>[];
        if (list.isEmpty) {
          return const Text(
            'Visit a provider to populate recents.',
            style: TextStyle(color: AiFlowTheme.inkMuted, fontSize: 12),
          );
        }
        return SizedBox(
          height: 110,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: list.length,
            separatorBuilder: (context, index) => const SizedBox(width: 10),
            itemBuilder: (context, i) {
              final p = list[i];
              return InkWell(
                onTap: () async {
                  var hit = _resultForProviderId(p.userId);
                  hit ??= () {
                    final one = AiRecommendationEngine.recommendProviders(
                      patient: _patient,
                      request: RecommendationRequestParser.fromInputs(
                        searchText: '',
                        categoryKey: null,
                      ),
                      providers: [p],
                      top: 1,
                    );
                    return one.isEmpty ? null : one.first;
                  }();
                  if (hit != null) await _openDetails(hit);
                },
                child: Container(
                  width: 160,
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AiFlowTheme.cardStroke),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        p.fullName,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 13,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        p.specialization.isEmpty
                            ? p.role
                            : p.specialization,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 11,
                          color: AiFlowTheme.primaryBlue,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }
}
