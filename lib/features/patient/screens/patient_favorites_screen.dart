import 'package:flutter/material.dart';
import 'package:carelink/core/app_colors.dart';
import 'package:carelink/core/carelink_palette.dart';
import 'package:carelink/core/locale_controller.dart';
import 'package:carelink/shared/services/patient_favorites_service.dart';
import 'package:carelink/shared/services/api_service.dart';

import 'package:carelink/features/patient/screens/provider_details_screen.dart';
import 'package:carelink/features/patient/screens/select_service_screen.dart';
import 'package:carelink/shared/models/provider_model.dart';
import 'package:carelink/shared/models/booking_request_model.dart';
import 'package:carelink/features/patient/widgets/patient_shared_widgets.dart';

class PatientFavoritesScreen extends StatefulWidget {
  final String patientUserId;
  const PatientFavoritesScreen({super.key, required this.patientUserId});

  @override
  State<PatientFavoritesScreen> createState() => _PatientFavoritesScreenState();
}

class _PatientFavoritesScreenState extends State<PatientFavoritesScreen>
    with SingleTickerProviderStateMixin {
  List<Map<String, dynamic>> _favorites = [];
  bool _isLoading = true;
  late AnimationController _fadeCtrl;

  bool get _isArabic => localeController.isArabic;
  String _t(String en, String ar) => _isArabic ? ar : en;

  @override
  void initState() {
    super.initState();
    _fadeCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 420),
    );
    _loadFavorites();
  }

  @override
  void dispose() {
    _fadeCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadFavorites() async {
    if (mounted) setState(() => _isLoading = true);
    final favs = await PatientFavoritesService.getFavorites(
      widget.patientUserId,
    );
    final enriched = await Future.wait(
      favs.map((favorite) async {
        final copy = Map<String, dynamic>.from(favorite);
        final providerId = copy['providerId']?.toString() ?? '';
        try {
          final data = await ApiService().getProviderById(providerId);
          final provider = ProviderModel.fromJson(data);
          copy['hasAvailableSlots'] = provider.availableSlots.isNotEmpty;
          copy['availableSlots'] = data['availableSlots'];
          copy['serviceType'] = provider.serviceType;
        } catch (_) {
          copy['hasAvailableSlots'] = false;
        }
        return copy;
      }),
    );
    if (mounted) {
      setState(() {
        _favorites = enriched;
        _isLoading = false;
      });
      _fadeCtrl.forward(from: 0);
    }
  }

  Future<void> _removeFavorite(String providerId) async {
    await PatientFavoritesService.removeFavorite(
      widget.patientUserId,
      providerId,
    );
    _loadFavorites();
  }

  // ──────────────────────────────────────────────────────────────────────────
  // Build
  // ──────────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final p = CarelinkPalette.of(context);

    return Directionality(
      textDirection: _isArabic ? TextDirection.rtl : TextDirection.ltr,
      child: Scaffold(
        backgroundColor: p.pageBg,
        appBar: PatientAppBar(title: _t('Favorites', 'المفضلة')),
        body: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: _isLoading
                    ? _buildLoader(p)
                    : _favorites.isEmpty
                    ? _buildEmptyState(p)
                    : _buildList(p),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ──────────────────────────────────────────────────────────────────────────
  // Header
  // ──────────────────────────────────────────────────────────────────────────

  // ──────────────────────────────────────────────────────────────────────────
  // Loading
  // ──────────────────────────────────────────────────────────────────────────

  Widget _buildLoader(CarelinkPalette p) {
    return const Center(
      child: CircularProgressIndicator(color: AppColors.primary),
    );
  }

  // ──────────────────────────────────────────────────────────────────────────
  // Empty State
  // ──────────────────────────────────────────────────────────────────────────

  Widget _buildEmptyState(CarelinkPalette p) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 36),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 88,
              height: 88,
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(
                  alpha: p.isDark ? 0.15 : 0.08,
                ),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.favorite_border_rounded,
                color: AppColors.primary,
                size: 40,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              _t('No favorite providers yet', 'لا يوجد مقدمو رعاية في المفضلة'),
              textAlign: TextAlign.center,
              style: TextStyle(
                color: p.inkDark,
                fontSize: 18,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _t(
                'Save providers you trust for faster access later.',
                'احفظ مقدمي الرعاية الذين تثق بهم للوصول السريع لاحقاً.',
              ),
              textAlign: TextAlign.center,
              style: TextStyle(color: p.inkMuted, fontSize: 14, height: 1.5),
            ),
            const SizedBox(height: 28),
            FilledButton.icon(
              onPressed: () => Navigator.of(context).maybePop(),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 28,
                  vertical: 14,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              icon: const Icon(Icons.search_rounded, size: 18),
              label: Text(
                _t('Find Providers', 'ابحث عن مقدمي رعاية'),
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 14.5,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ──────────────────────────────────────────────────────────────────────────
  // List
  // ──────────────────────────────────────────────────────────────────────────

  Widget _buildList(CarelinkPalette p) {
    return FadeTransition(
      opacity: _fadeCtrl,
      child: RefreshIndicator(
        onRefresh: _loadFavorites,
        color: AppColors.primary,
        child: ListView.separated(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
          itemCount: _favorites.length,
          separatorBuilder: (ctx, idx) => const SizedBox(height: 14),
          itemBuilder: (context, index) {
            final prov = _favorites[index];
            final canBook = prov['hasAvailableSlots'] == true;
            return _FavoriteCard(
              data: prov,
              patientUserId: widget.patientUserId,
              isArabic: _isArabic,
              palette: p,
              onRemove: () =>
                  _removeFavorite(prov['providerId']?.toString() ?? ''),
              onViewProfile: () => _openProfile(prov),
              canBook: canBook,
              onBook: canBook ? () => _openBooking(prov) : null,
            );
          },
        ),
      ),
    );
  }

  // ──────────────────────────────────────────────────────────────────────────
  // Navigation helpers
  // ──────────────────────────────────────────────────────────────────────────

  ProviderModel _toProviderModel(Map<String, dynamic> prov) {
    final providerId = prov['providerId']?.toString() ?? '';
    final name = prov['displayName']?.toString() ?? '';
    final specialty =
        prov['specialty']?.toString() ??
        prov['specialization']?.toString() ??
        '';
    final imageUrl =
        prov['profilePictureUrl']?.toString() ??
        prov['profileImageUrl']?.toString();
    final rating = double.tryParse(prov['rating']?.toString() ?? '0') ?? 0.0;
    final isAvailable =
        prov['isAvailable'] == true ||
        prov['isAvailable'] == 1 ||
        prov['isAvailable']?.toString() == '1';
    final role = prov['role']?.toString() ?? 'doctor';
    final fee = double.tryParse(
      prov['consultationFee']?.toString() ??
          prov['hourlyRate']?.toString() ??
          '',
    );

    return ProviderModel(
      userId: providerId,
      fullName: name,
      specialization: specialty,
      serviceType: '',
      overallRating: rating,
      profileImageUrl: imageUrl,
      role: role,
      isAvailable: isAvailable,
      consultationFee: fee,
    );
  }

  void _openProfile(Map<String, dynamic> prov) {
    final provider = _toProviderModel(prov);
    // Extract AI recommendation data if present
    final recommendation = prov['recommendation'] is Map<String, dynamic>
        ? prov['recommendation'] as Map<String, dynamic>
        : null;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ProviderDetailsScreen(
          provider: provider,
          patientUserId: widget.patientUserId,
          recommendation: recommendation,
        ),
      ),
    ).then((_) => _loadFavorites());
  }

  Future<void> _openBooking(Map<String, dynamic> prov) async {
    var provider = _toProviderModel(prov);
    try {
      final data = await ApiService().getProviderById(provider.userId);
      provider = ProviderModel.fromJson(data);
    } catch (_) {}
    if (!mounted) return;
    if (provider.availableSlots.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _isArabic
                ? 'لا توجد مواعيد متاحة لهذا مقدم الرعاية.'
                : 'No available slots for this provider.',
          ),
        ),
      );
      return;
    }
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => SelectServiceScreen(
          request: BookingRequestModel(
            patientId: widget.patientUserId,
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
}

// ────────────────────────────────────────────────────────────────────────────
// Favorite Card Widget
// ────────────────────────────────────────────────────────────────────────────

class _FavoriteCard extends StatelessWidget {
  const _FavoriteCard({
    required this.data,
    required this.patientUserId,
    required this.isArabic,
    required this.palette,
    required this.onRemove,
    required this.onViewProfile,
    required this.canBook,
    required this.onBook,
  });

  final Map<String, dynamic> data;
  final String patientUserId;
  final bool isArabic;
  final CarelinkPalette palette;
  final VoidCallback onRemove;
  final VoidCallback onViewProfile;
  final bool canBook;
  final VoidCallback? onBook;

  String _t(String en, String ar) => isArabic ? ar : en;

  // ── Parsed fields ──────────────────────────────────────────────────────────

  String get _name => data['displayName']?.toString() ?? '';

  String get _specialty =>
      data['specialty']?.toString() ?? data['specialization']?.toString() ?? '';

  double get _rating =>
      double.tryParse(data['rating']?.toString() ?? '0') ?? 0.0;

  bool get _isAvailable =>
      data['isAvailable'] == true ||
      data['isAvailable'] == 1 ||
      data['isAvailable']?.toString() == '1';

  String? get _imageUrl {
    final raw =
        data['profilePictureUrl']?.toString() ??
        data['profileImageUrl']?.toString();
    if (raw == null || raw.isEmpty || raw.toLowerCase() == 'null') return null;
    if (raw.startsWith('http://') || raw.startsWith('https://')) return raw;
    if (raw.startsWith('/')) return '${ApiService.baseUrl}$raw';
    return '${ApiService.baseUrl}/$raw';
  }

  // AI recommendation data
  int? get _matchPercent {
    final rec = data['recommendation'];
    if (rec is! Map) return null;
    final raw = rec['matchPercentage'];
    if (raw is num) return raw.round().clamp(0, 99);
    final rawMedical = rec['medicalMatchScore'];
    if (rawMedical is num) {
      return (rawMedical.toDouble() * 100).round().clamp(0, 99);
    }
    return null;
  }

  String get _aiReason {
    final rec = data['recommendation'];
    if (rec is! Map) return '';
    final rawReasons = rec['medicalReasons'];
    if (rawReasons is List) {
      final reasons = rawReasons
          .map((e) => e.toString().trim())
          .where((e) => e.isNotEmpty)
          .take(2)
          .toList();
      if (reasons.isNotEmpty && !isArabic) {
        return 'Matched for ${reasons.join(' and ')}.';
      }
    }
    return '';
  }

  String? get _distanceLabel {
    final dist = data['distanceKm'];
    if (dist == null) return null;
    final d = double.tryParse(dist.toString());
    if (d == null) return null;
    if (d < 1) return '${(d * 1000).round()} m';
    return '${d.toStringAsFixed(1)} km';
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final p = palette;
    final matchPct = _matchPercent;
    final aiReason = _aiReason;
    final distLabel = _distanceLabel;

    return Container(
      decoration: BoxDecoration(
        color: p.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: p.stroke.withValues(alpha: 0.85)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: p.isDark ? 0.20 : 0.05),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── Top section ─────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Avatar
                _buildAvatar(p),
                const SizedBox(width: 12),
                // Info column
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Name + favorite badge
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Expanded(
                            child: Text(
                              _name.isNotEmpty
                                  ? _name
                                  : _t('Care Provider', 'مقدم رعاية'),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: p.inkDark,
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                                letterSpacing: -0.2,
                              ),
                            ),
                          ),
                          // Favorite remove button – integrated as small badge
                          GestureDetector(
                            onTap: onRemove,
                            child: Padding(
                              padding: const EdgeInsetsDirectional.only(
                                start: 6,
                              ),
                              child: Icon(
                                Icons.favorite_rounded,
                                color: const Color(0xFFE85D75),
                                size: 20,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 3),
                      // Specialty
                      if (_specialty.isNotEmpty)
                        Text(
                          _specialty,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: AppColors.primary,
                            fontSize: 12.5,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      const SizedBox(height: 8),
                      // Rating + distance row
                      Row(
                        children: [
                          _metric(
                            p,
                            Icons.star_rounded,
                            _rating.toStringAsFixed(1),
                            iconColor: const Color(0xFFFFB020),
                          ),
                          if (distLabel != null) ...[
                            const SizedBox(width: 10),
                            _metric(p, Icons.location_on_outlined, distLabel),
                          ],
                        ],
                      ),
                      const SizedBox(height: 8),
                      // Availability badge
                      _availabilityBadge(p),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // ── AI Match section ─────────────────────────────────────────────
          if (matchPct != null || aiReason.isNotEmpty)
            _buildAiSection(p, matchPct, aiReason),

          // ── Divider ──────────────────────────────────────────────────────
          Divider(
            height: 1,
            thickness: 1,
            color: p.stroke.withValues(alpha: 0.6),
          ),

          // ── Action buttons ───────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
            child: Row(
              children: [
                Expanded(
                  child: _actionBtn(
                    context,
                    p,
                    label: _t('View Profile', 'عرض الملف الشخصي'),
                    icon: Icons.person_outline_rounded,
                    isPrimary: false,
                    onTap: onViewProfile,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _actionBtn(
                    context,
                    p,
                    label: canBook
                        ? _t('Book Appointment', 'حجز موعد')
                        : _t('No slots available', 'لا توجد مواعيد'),
                    icon: Icons.calendar_month_rounded,
                    isPrimary: true,
                    onTap: onBook,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Avatar ─────────────────────────────────────────────────────────────────

  Widget _buildAvatar(CarelinkPalette p) {
    final url = _imageUrl;
    final fallback = Container(
      color: AppColors.primary.withValues(alpha: p.isDark ? 0.22 : 0.10),
      alignment: Alignment.center,
      child: const Icon(
        Icons.medical_services_outlined,
        color: AppColors.primary,
        size: 28,
      ),
    );
    return Container(
      width: 68,
      height: 68,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: AppColors.primary.withValues(alpha: 0.22),
          width: 2,
        ),
      ),
      child: ClipOval(
        child: url == null
            ? fallback
            : Image.network(
                url,
                fit: BoxFit.cover,
                errorBuilder: (ctx, err, stack) => fallback,
              ),
      ),
    );
  }

  // ── AI Match section ───────────────────────────────────────────────────────

  Widget _buildAiSection(CarelinkPalette p, int? matchPct, String aiReason) {
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: p.isDark ? 0.14 : 0.07),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppColors.primary.withValues(alpha: p.isDark ? 0.28 : 0.16),
        ),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.auto_awesome_rounded,
            color: AppColors.primary,
            size: 16,
          ),
          const SizedBox(width: 7),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (matchPct != null)
                  Text(
                    '$matchPct% ${_t('Match', 'توافق')}',
                    style: const TextStyle(
                      color: AppColors.primary,
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                if (aiReason.isNotEmpty)
                  Text(
                    aiReason,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: p.inkMuted,
                      fontSize: 11.5,
                      fontWeight: FontWeight.w500,
                    ),
                  )
                else if (matchPct != null)
                  Text(
                    _t('Recommended for you', 'موصى به لك'),
                    style: TextStyle(
                      color: p.inkMuted,
                      fontSize: 11.5,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Helpers ────────────────────────────────────────────────────────────────

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
          style: TextStyle(
            fontSize: 12,
            color: p.inkMuted,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }

  Widget _availabilityBadge(CarelinkPalette p) {
    final available = _isAvailable;
    final color = available ? AppColors.primary : p.inkMuted;
    final label = available
        ? _t('Available Today', 'متاح اليوم')
        : _t('Unavailable', 'غير متاح');
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
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
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 11,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }

  Widget _actionBtn(
    BuildContext context,
    CarelinkPalette p, {
    required String label,
    required IconData icon,
    required bool isPrimary,
    required VoidCallback? onTap,
  }) {
    final enabled = onTap != null;
    return Material(
      color: !enabled
          ? p.surfaceSoft
          : isPrimary
          ? AppColors.primary
          : p.surface,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 11),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: isPrimary || !enabled
                ? null
                : Border.all(color: AppColors.primary.withValues(alpha: 0.40)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 16,
                color: !enabled
                    ? p.inkMuted
                    : isPrimary
                    ? Colors.white
                    : AppColors.primary,
              ),
              const SizedBox(width: 5),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: !enabled
                        ? p.inkMuted
                        : isPrimary
                        ? Colors.white
                        : AppColors.primary,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
