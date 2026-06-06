import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import 'package:carelink/core/app_colors.dart';
import 'package:carelink/shared/models/user.dart';
import 'package:carelink/shared/services/api_service.dart';
import 'nurse_ui.dart';

class NurseRecommendations extends StatefulWidget {
  final User user;

  const NurseRecommendations({super.key, required this.user});

  @override
  State<NurseRecommendations> createState() => _NurseRecommendationsState();
}

class _NurseRecommendationsState extends State<NurseRecommendations> {
  bool isLoading = true;
  List<Map<String, dynamic>> recommendations = [];

  @override
  void initState() {
    super.initState();
    _loadRecommendations();
  }

  Future<void> _loadRecommendations() async {
    setState(() => isLoading = true);
    try {
      final response = await http.get(
        Uri.parse(
          '${ApiService.baseUrl}/nurse/recommendations/${widget.user.userId}',
        ),
      );
      if (response.statusCode >= 200 && response.statusCode < 300) {
        final data = jsonDecode(response.body);
        if (data is List && mounted) {
          setState(() {
            recommendations =
                data.map((item) => Map<String, dynamic>.from(item)).toList();
          });
        }
      }
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  Future<void> _acceptRecommendation(Map<String, dynamic> item) async {
    final id = item['recommendationId']?.toString() ?? '';
    if (id.isEmpty) return;

    final response = await http.post(
      Uri.parse(
        '${ApiService.baseUrl}/nurse/recommendations/${widget.user.userId}/$id/accept',
      ),
    );
    final success = response.statusCode >= 200 && response.statusCode < 300;
    if (success) await _loadRecommendations();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          success ? 'Recommendation accepted' : 'Failed to accept recommendation',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return NurseUi.reactive((context) => Scaffold(
      backgroundColor: NurseUi.background,
      appBar: AppBar(
        title: Text(NurseUi.label('Recommendations', '\u0627\u0644\u062a\u0648\u0635\u064a\u0627\u062a')),
        backgroundColor: NurseUi.background,
        foregroundColor: NurseUi.text,
        elevation: 0,
        actions: [
          NurseModeControls(providerUserId: widget.user.userId),
        ],
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : recommendations.isEmpty
              ? const Center(child: Text('No recommendations right now'))
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: recommendations.length,
                  itemBuilder: (context, index) {
                    final item = recommendations[index];
                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: NurseUi.surface,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: NurseUi.border.withOpacity(0.8),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item['patientName']?.toString() ?? 'Patient',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            item['recommendationReason']?.toString() ??
                                item['addressText']?.toString() ??
                                'Nearby patient recommendation',
                            style: const TextStyle(color: AppColors.textLight),
                          ),
                          const SizedBox(height: 12),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              onPressed: () => _acceptRecommendation(item),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.primary,
                                foregroundColor: Colors.white,
                              ),
                              child: const Text('Accept'),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
    ));
  }
}
