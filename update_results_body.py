import os
import re

filepath = r'lib/features/ai/screens/find_provider_screen.dart'

with open(filepath, 'r', encoding='utf-8') as f:
    content = f.read()

# Replace _resultsBody up until _analysisRow
# We will use regex to find _resultsBody and everything up to the end of the class.

start_marker = "Widget _resultsBody() {"
end_marker = "  String _t(String key) {"

if start_marker in content and end_marker in content:
    start_idx = content.find(start_marker)
    end_idx = content.find(end_marker)
    
    new_results_body = """Widget _resultsBody() {
    final p = CarelinkPalette.of(context);
    final isEmergency = _analysisValue('isEmergency') == 'true';

    return CustomScrollView(
      slivers: [
        // Small Hero
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.check_circle_rounded, color: AppColors.primary, size: 28),
                ),
                const SizedBox(height: 12),
                Text(
                  _ar ? 'تم تحليل حالتك بنجاح' : 'Case analyzed successfully',
                  style: TextStyle(color: p.inkDark, fontSize: 18, fontWeight: FontWeight.w900),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 4),
                Text(
                  _ar ? 'وجدنا أفضل مقدم رعاية يناسب احتياجك.' : 'We found the best care provider for your needs.',
                  style: TextStyle(color: p.inkMuted, fontSize: 13, fontWeight: FontWeight.w600),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),

        // Emergency Banner
        if (isEmergency)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.red.withValues(alpha: 0.1),
                  border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.warning_rounded, color: Colors.red, size: 28),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        _t('emergencyWarningText'),
                        style: const TextStyle(color: Colors.red, fontSize: 12, fontWeight: FontWeight.w800, height: 1.4),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

        // AI Summary Card
        if (_hasAnalysis())
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: p.surface,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 12, offset: const Offset(0, 4))],
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: p.surfaceContainerHighest,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.smart_toy_rounded, color: AppColors.primary, size: 20),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          if (_analysisValue('serviceCategory') != null)
                            _buildInfoChip(Icons.local_hospital_rounded, _analysisValue('serviceCategory')!, AppColors.primary),
                          if (_analysisValue('need') != null)
                            _buildInfoChip(Icons.medical_services_rounded, _analysisValue('need')!, Colors.blue.shade600),
                          if (_analysisValue('priority') != null)
                            _buildInfoChip(Icons.flag_rounded, _analysisValue('priority')!, isEmergency ? Colors.red : Colors.green.shade600),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

        // Results
        if (_results.isEmpty)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(40),
              child: Column(
                children: [
                  Icon(Icons.search_off_rounded, size: 64, color: p.inkMuted.withValues(alpha: 0.5)),
                  const SizedBox(height: 16),
                  Text(_t('emptyTitle'), style: TextStyle(color: p.inkDark, fontSize: 18, fontWeight: FontWeight.w900)),
                  const SizedBox(height: 8),
                  Text(_t('empty'), textAlign: TextAlign.center, style: TextStyle(color: p.inkMuted, fontSize: 14)),
                ],
              ),
            ),
          )
        else ...[
          // Best Provider
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              child: AiProviderRecommendationCard(
                rank: 1,
                result: _results[0],
                highlighted: true,
                distanceKm: AiProviderRecommendationCard.distanceFrom(_patLat, _patLng, _results[0].provider),
                onTap: () => _openDetails(_results[0]),
                isArabic: _ar,
              ),
            ),
          ),

          // Other Providers
          if (_results.length > 1)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 16, 24, 12),
                child: Text(
                  _ar ? 'مقدمو رعاية آخرون' : 'Other Care Providers',
                  style: TextStyle(color: p.inkDark, fontSize: 16, fontWeight: FontWeight.w800),
                ),
              ),
            ),

          if (_results.length > 1)
            SliverPadding(
              padding: EdgeInsets.fromLTRB(24, 0, 24, 120 + MediaQuery.paddingOf(context).bottom),
              sliver: SliverList.separated(
                itemBuilder: (context, index) {
                  final result = _results[index + 1];
                  return AiProviderRecommendationCard(
                    rank: index + 2,
                    result: result,
                    highlighted: false,
                    distanceKm: AiProviderRecommendationCard.distanceFrom(_patLat, _patLng, result.provider),
                    onTap: () => _openDetails(result),
                    isArabic: _ar,
                  );
                },
                separatorBuilder: (_, _) => const SizedBox(height: 12),
                itemCount: _results.length - 1,
              ),
            ),
        ],
      ],
    );
  }

  Widget _buildInfoChip(IconData icon, String label, Color color) {
    if (label.isEmpty) return const SizedBox();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: color),
          ),
        ],
      ),
    );
  }

  bool _hasAnalysis() {
    return [
      'serviceCategory',
      'possibleSpecialty',
      'need',
      'priority',
      'note',
      'isEmergency',
    ].any((key) => _analysisValue(key) != null);
  }

"""
    
    updated_content = content[:start_idx] + new_results_body + content[end_idx:]
    with open(filepath, 'w', encoding='utf-8') as f:
        f.write(updated_content)
    print("Updated _resultsBody successfully")
else:
    print("Could not find markers")
