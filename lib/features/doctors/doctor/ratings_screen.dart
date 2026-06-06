import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../services/doctor_service.dart';
import '../../../core/app_colors.dart';

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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading ratings: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final summary = _ratingsData['summary'] ?? {};
    final reviews = _ratingsData['reviews'] as List? ?? [];
    final averageRating = summary['averageRating'] ?? 0.0;
    final totalReviews = summary['totalReviews'] ?? 0;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Ratings & Feedback'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadRatings,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Rating Summary Card
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          children: [
                            // Average Rating
                            Text(
                              averageRating.toStringAsFixed(1),
                              style: const TextStyle(
                                fontSize: 48,
                                fontWeight: FontWeight.bold,
                                color: AppColors.primary,
                              ),
                            ),
                            // Stars
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: List.generate(5, (index) {
                                if (index < averageRating.floor()) {
                                  return const Icon(Icons.star, color: AppColors.warning, size: 28);
                                } else if (index < averageRating) {
                                  return const Icon(Icons.star_half, color: AppColors.warning, size: 28);
                                } else {
                                  return const Icon(Icons.star_border, color: AppColors.warning, size: 28);
                                }
                              }),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              '$totalReviews reviews',
                              style: const TextStyle(
                                color: AppColors.textSecondary,
                                fontSize: 14,
                              ),
                            ),
                            const SizedBox(height: 24),
                            // Rating Distribution
                            _buildRatingDistribution(summary['distribution'] as List? ?? []),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    // Reviews List
                    const Text(
                      'Recent Reviews',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                      ),
                    ),
                    const SizedBox(height: 16),
                    if (reviews.isEmpty)
                      Center(
                        child: Padding(
                          padding: const EdgeInsets.all(32),
                          child: Column(
                            children: [
                              Icon(Icons.rate_review_outlined, size: 60, color: Colors.grey[400]),
                              const SizedBox(height: 16),
                              Text(
                                'No reviews yet',
                                style: TextStyle(color: Colors.grey[600]),
                              ),
                            ],
                          ),
                        ),
                      )
                    else
                      ...reviews.map((review) => _buildReviewCard(review)),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildRatingDistribution(List distribution) {
    final Map<int, int> distributionMap = {};
    for (var d in distribution) {
      distributionMap[d['rating'] ?? 0] = d['count'] ?? 0;
    }

    return Column(
      children: List.generate(5, (index) {
        final rating = 5 - index;
        final count = distributionMap[rating] ?? 0;
        final maxCount = distribution.fold<int>(0, (max, d) => (d['count'] ?? 0) > max ? d['count'] ?? 0 : max);
        final percentage = maxCount > 0 ? count / maxCount : 0.0;

        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(
            children: [
              SizedBox(
                width: 20,
                child: Text(
                  '$rating',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
              const Icon(Icons.star, color: AppColors.warning, size: 16),
              const SizedBox(width: 8),
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: percentage,
                    backgroundColor: Colors.grey[200],
                    valueColor: const AlwaysStoppedAnimation<Color>(AppColors.warning),
                    minHeight: 8,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(
                width: 30,
                child: Text(
                  '$count',
                  textAlign: TextAlign.right,
                  style: const TextStyle(color: AppColors.textSecondary),
                ),
              ),
            ],
          ),
        );
      }),
    );
  }

  Widget _buildReviewCard(dynamic review) {
    final rating = review['rating'] ?? 0;
    final patientName = review['patientName'] ?? 'Anonymous';
    final reviewText = review['reviewText'] ?? '';
    final reasonForVisit = review['reasonForVisit'] ?? '';
    final createdAt = review['createdAt'];

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      backgroundColor: AppColors.primary.withOpacity(0.1),
                      child: Text(
                        patientName[0].toUpperCase(),
                        style: const TextStyle(
                          color: AppColors.primary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          patientName,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        if (reasonForVisit.isNotEmpty)
                          Text(
                            reasonForVisit,
                            style: const TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 12,
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
                // Rating Stars
                Row(
                  children: List.generate(5, (index) {
                    return Icon(
                      index < rating ? Icons.star : Icons.star_border,
                      color: AppColors.warning,
                      size: 18,
                    );
                  }),
                ),
              ],
            ),
            if (reviewText.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(reviewText),
            ],
            if (createdAt != null) ...[
              const SizedBox(height: 8),
              Text(
                _formatDate(createdAt),
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 12,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _formatDate(String dateStr) {
    try {
      final date = DateTime.parse(dateStr);
      return '${date.day}/${date.month}/${date.year}';
    } catch (e) {
      return dateStr;
    }
  }
}