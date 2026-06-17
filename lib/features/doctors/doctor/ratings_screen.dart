import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/app_colors.dart';
import '../../../services/doctor_service.dart';

class DoctorRatingsScreen extends StatefulWidget {
  const DoctorRatingsScreen({super.key});

  @override
  State<DoctorRatingsScreen> createState() => _DoctorRatingsScreenState();
}

class _DoctorRatingsScreenState extends State<DoctorRatingsScreen> {
  final _doctorService = DoctorService();

  bool _isLoading = true;
  Map<String, dynamic> _ratingsData = {};
  String _doctorId = '';
  int? _selectedRating;

  @override
  void initState() {
    super.initState();
    _loadRatings();
  }

  Future<void> _loadRatings() async {
    setState(() => _isLoading = true);

    try {
      final prefs = await SharedPreferences.getInstance();
      _doctorId = prefs.getString('doctor_userId') ?? '';

      final data = await _doctorService.getRatings(_doctorId);
      setState(() {
        _ratingsData = data;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error loading ratings: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final summary = _mapOf(_ratingsData['summary']);
    final reviews = _listOf(_ratingsData['reviews']);
    final filteredReviews = _filteredReviews(reviews);
    final averageRating = _toDouble(summary['averageRating']);
    final totalReviews = _toInt(summary['totalReviews']);

    return Scaffold(
      backgroundColor: _pageColor,
      appBar: AppBar(
        backgroundColor: _pageColor,
        surfaceTintColor: _pageColor,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          onPressed: () => Navigator.maybePop(context),
          icon: const Icon(Icons.arrow_back_rounded),
          color: AppColors.primary,
        ),
        title: Text(
          'Ratings & Reviews',
          style: TextStyle(
            color: _primaryText,
            fontSize: 24,
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadRatings,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(22, 16, 22, 28),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 760),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _buildSummaryCard(
                          averageRating: averageRating,
                          totalReviews: totalReviews,
                          distribution: _listOf(summary['distribution']),
                        ),
                        const SizedBox(height: 22),
                        _buildFilters(reviews, totalReviews),
                        const SizedBox(height: 18),
                        if (filteredReviews.isEmpty)
                          _buildEmptyState()
                        else
                          ...filteredReviews.map(_buildReviewCard),
                        const SizedBox(height: 10),
                        _buildPrivacyCard(),
                      ],
                    ),
                  ),
                ),
              ),
            ),
    );
  }

  bool get _isDark => Theme.of(context).brightness == Brightness.dark;

  Color get _pageColor =>
      _isDark ? const Color(0xFF101716) : const Color(0xFFF5F5F5);

  Color get _cardColor => _isDark ? const Color(0xFF182321) : Colors.white;

  Color get _primaryText => _isDark ? const Color(0xFFF4FAF8) : Colors.black;

  Color get _secondaryText =>
      _isDark ? const Color(0xFFB9C8C4) : const Color(0xFF626A78);

  BoxShadow _softShadow({double opacity = 0.055}) {
    return BoxShadow(
      color: Colors.black.withValues(alpha: _isDark ? 0.24 : opacity),
      blurRadius: 24,
      spreadRadius: -8,
      offset: const Offset(0, 12),
    );
  }

  Widget _buildSummaryCard({
    required double averageRating,
    required int totalReviews,
    required List<dynamic> distribution,
  }) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: _cardColor,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [_softShadow()],
        border: Border.all(
          color: _isDark
              ? Colors.white.withValues(alpha: 0.06)
              : const Color(0xFFEAEDEF),
        ),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final narrow = constraints.maxWidth < 520;
          final left = _summaryScore(
            averageRating: averageRating,
            totalReviews: totalReviews,
          );
          final right = _buildRatingDistribution(distribution);

          if (narrow) {
            return Column(
              children: [
                left,
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 18),
                  child: Divider(color: _borderColor),
                ),
                right,
              ],
            );
          }

          return Row(
            children: [
              Expanded(child: left),
              Container(width: 1, height: 184, color: _borderColor),
              const SizedBox(width: 24),
              Expanded(child: right),
            ],
          );
        },
      ),
    );
  }

  Widget _summaryScore({
    required double averageRating,
    required int totalReviews,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          averageRating.toStringAsFixed(1),
          style: const TextStyle(
            color: AppColors.primary,
            fontSize: 68,
            height: 1,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 18),
        _stars(averageRating, size: 32),
        const SizedBox(height: 14),
        Text(
          '($totalReviews reviews)',
          style: TextStyle(
            color: _secondaryText,
            fontSize: 16,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
          decoration: BoxDecoration(
            color: _isDark
                ? AppColors.primary.withValues(alpha: 0.16)
                : const Color(0xFFE8F5F2),
            borderRadius: BorderRadius.circular(10),
          ),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.verified_user_rounded,
                color: AppColors.primary,
                size: 19,
              ),
              SizedBox(width: 8),
              Text(
                'Verified Reviews',
                style: TextStyle(
                  color: AppColors.primary,
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildRatingDistribution(List<dynamic> distribution) {
    final distributionMap = _distributionMap(distribution);
    final maxCount = distributionMap.values.fold<int>(
      0,
      (max, count) => count > max ? count : max,
    );

    return Column(
      children: List.generate(5, (index) {
        final rating = 5 - index;
        final count = distributionMap[rating] ?? 0;
        final percentage = maxCount > 0 ? count / maxCount : 0.0;

        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 7),
          child: Row(
            children: [
              SizedBox(
                width: 18,
                child: Text(
                  '$rating',
                  style: TextStyle(
                    color: _primaryText,
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const SizedBox(width: 7),
              const Icon(
                Icons.star_rounded,
                color: AppColors.warning,
                size: 20,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(999),
                  child: LinearProgressIndicator(
                    value: percentage,
                    minHeight: 10,
                    backgroundColor: _isDark
                        ? Colors.white.withValues(alpha: 0.08)
                        : const Color(0xFFEFF1F3),
                    valueColor: const AlwaysStoppedAnimation<Color>(
                      AppColors.primary,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 14),
              SizedBox(
                width: 34,
                child: Text(
                  '$count',
                  textAlign: TextAlign.right,
                  style: TextStyle(
                    color: _primaryText,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        );
      }),
    );
  }

  Widget _buildFilters(List<dynamic> reviews, int totalReviews) {
    final counts = <int, int>{
      for (var rating = 1; rating <= 5; rating++)
        rating: reviews
            .where((review) => _toInt(_mapOf(review)['rating']) == rating)
            .length,
    };

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          _filterChip(label: 'All ($totalReviews)', rating: null),
          for (var rating = 5; rating >= 1; rating--)
            _filterChip(
              label: '$rating Stars (${counts[rating] ?? 0})',
              rating: rating,
            ),
          Container(
            margin: const EdgeInsetsDirectional.only(start: 10),
            decoration: BoxDecoration(
              color: _cardColor,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: _borderColor),
              boxShadow: [_softShadow(opacity: 0.025)],
            ),
            child: IconButton(
              onPressed: () => _showFilterSheet(counts, totalReviews),
              icon: const Icon(Icons.filter_alt_outlined),
              color: _primaryText,
            ),
          ),
        ],
      ),
    );
  }

  Widget _filterChip({required String label, required int? rating}) {
    final selected = _selectedRating == rating;

    return Padding(
      padding: const EdgeInsetsDirectional.only(end: 10),
      child: ChoiceChip(
        selected: selected,
        showCheckmark: false,
        label: Text(label),
        onSelected: (_) => setState(() => _selectedRating = rating),
        selectedColor: AppColors.primary,
        backgroundColor: _cardColor,
        side: BorderSide(color: selected ? AppColors.primary : _borderColor),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        labelStyle: TextStyle(
          color: selected ? Colors.white : _primaryText,
          fontSize: 15,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }

  Widget _buildReviewCard(dynamic rawReview) {
    final review = _mapOf(rawReview);
    final rating = _toDouble(review['rating']);
    final patientName = _displayPatientName(review['patientName']);
    final reviewText = _cleanText(review['reviewText']);
    final reasonForVisit = _cleanText(review['reasonForVisit']);
    final createdAt = _cleanText(review['createdAt']);

    return Container(
      margin: const EdgeInsets.only(bottom: 18),
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: _cardColor,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [_softShadow(opacity: 0.045)],
        border: Border.all(color: _borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _patientAvatar(patientName),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            patientName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: _primaryText,
                              fontSize: 18,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        const Icon(
                          Icons.verified_rounded,
                          color: AppColors.primary,
                          size: 20,
                        ),
                      ],
                    ),
                    const SizedBox(height: 7),
                    Text(
                      createdAt == null ? '' : _formatDate(createdAt),
                      style: TextStyle(
                        color: _secondaryText,
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              PopupMenuButton<String>(
                icon: Icon(Icons.more_horiz_rounded, color: _secondaryText),
                tooltip: 'Review options',
                itemBuilder: (context) => const [
                  PopupMenuItem(value: 'details', child: Text('Details')),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          _stars(rating, size: 27),
          if (reviewText != null) ...[
            const SizedBox(height: 18),
            Text(
              reviewText,
              style: TextStyle(
                color: _primaryText.withValues(alpha: _isDark ? 0.92 : 0.78),
                fontSize: 17,
                height: 1.55,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
          if (reasonForVisit != null) ...[
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: _isDark
                    ? Colors.white.withValues(alpha: 0.06)
                    : const Color(0xFFF4F7F7),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                reasonForVisit,
                style: TextStyle(
                  color: _secondaryText,
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _patientAvatar(String patientName) {
    final initial = patientName.trim().isEmpty
        ? 'P'
        : patientName.trim().characters.first.toUpperCase();

    return Container(
      width: 68,
      height: 68,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: _isDark
            ? AppColors.primary.withValues(alpha: 0.18)
            : const Color(0xFFDDF3EE),
      ),
      alignment: Alignment.center,
      child: Text(
        initial,
        style: const TextStyle(
          color: AppColors.primary,
          fontSize: 26,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Container(
      margin: const EdgeInsets.only(bottom: 18),
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 34),
      decoration: BoxDecoration(
        color: _cardColor,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [_softShadow(opacity: 0.04)],
        border: Border.all(color: _borderColor),
      ),
      child: Column(
        children: [
          Container(
            width: 70,
            height: 70,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.primary.withValues(alpha: 0.10),
            ),
            child: const Icon(
              Icons.rate_review_outlined,
              color: AppColors.primary,
              size: 34,
            ),
          ),
          const SizedBox(height: 18),
          Text(
            'No reviews yet',
            style: TextStyle(
              color: _primaryText,
              fontSize: 20,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _selectedRating == null
                ? 'Verified patient reviews will appear here after visits are rated.'
                : 'No verified reviews match this rating filter.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: _secondaryText,
              fontSize: 15,
              height: 1.35,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPrivacyCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _isDark ? const Color(0xFF15211F) : const Color(0xFFF6FBFA),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: _borderColor),
        boxShadow: [_softShadow(opacity: 0.035)],
      ),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.10),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.privacy_tip_outlined,
              color: AppColors.primary,
              size: 26,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Privacy Protected',
                  style: TextStyle(
                    color: AppColors.primary,
                    fontSize: 17,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Patient identities are kept private to ensure a trusted healthcare experience.',
                  style: TextStyle(
                    color: _secondaryText,
                    fontSize: 14,
                    height: 1.35,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          const Icon(Icons.lock_rounded, color: AppColors.primary, size: 34),
        ],
      ),
    );
  }

  Widget _stars(double rating, {required double size}) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(5, (index) {
        final position = index + 1;
        final icon = rating >= position
            ? Icons.star_rounded
            : rating >= position - 0.5
            ? Icons.star_half_rounded
            : Icons.star_border_rounded;

        return Icon(icon, color: AppColors.warning, size: size);
      }),
    );
  }

  void _showFilterSheet(Map<int, int> counts, int totalReviews) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: _cardColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 42,
                  height: 4,
                  decoration: BoxDecoration(
                    color: _borderColor,
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
                const SizedBox(height: 18),
                Text(
                  'Filter reviews',
                  style: TextStyle(
                    color: _primaryText,
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 12),
                _filterSheetTile('All reviews', totalReviews, null),
                for (var rating = 5; rating >= 1; rating--)
                  _filterSheetTile(
                    '$rating star reviews',
                    counts[rating] ?? 0,
                    rating,
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _filterSheetTile(String label, int count, int? rating) {
    final selected = _selectedRating == rating;

    return ListTile(
      onTap: () {
        setState(() => _selectedRating = rating);
        Navigator.pop(context);
      },
      leading: Icon(
        selected ? Icons.radio_button_checked : Icons.radio_button_off,
        color: selected ? AppColors.primary : _secondaryText,
      ),
      title: Text(label),
      trailing: Text('$count'),
      textColor: selected ? AppColors.primary : _primaryText,
      iconColor: selected ? AppColors.primary : _secondaryText,
    );
  }

  Color get _borderColor =>
      _isDark ? Colors.white.withValues(alpha: 0.08) : const Color(0xFFE9ECEF);

  List<dynamic> _filteredReviews(List<dynamic> reviews) {
    final rating = _selectedRating;
    if (rating == null) return reviews;
    return reviews
        .where((review) => _toInt(_mapOf(review)['rating']) == rating)
        .toList();
  }

  Map<int, int> _distributionMap(List<dynamic> distribution) {
    final values = <int, int>{};
    for (final item in distribution) {
      final row = _mapOf(item);
      final rating = _toInt(row['rating']);
      if (rating < 1 || rating > 5) continue;
      values[rating] = _toInt(row['count']);
    }
    return values;
  }

  Map<String, dynamic> _mapOf(dynamic value) {
    return value is Map
        ? Map<String, dynamic>.from(value)
        : <String, dynamic>{};
  }

  List<dynamic> _listOf(dynamic value) {
    return value is List ? value : const <dynamic>[];
  }

  int _toInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  double _toDouble(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '') ?? 0.0;
  }

  String? _cleanText(dynamic value) {
    final text = value?.toString().trim() ?? '';
    return text.isEmpty ? null : text;
  }

  String _displayPatientName(dynamic value) {
    return _cleanText(value) ?? 'Verified Patient';
  }

  String _formatDate(String dateStr) {
    try {
      final date = DateTime.parse(dateStr).toLocal();
      const months = [
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
      return '${months[date.month - 1]} ${date.day}, ${date.year}';
    } catch (e) {
      return dateStr;
    }
  }
}
