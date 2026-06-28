import os

filepath = r'lib/features/ai/screens/find_provider_screen.dart'

with open(filepath, 'r', encoding='utf-8') as f:
    content = f.read()

start_marker = "Widget _resultsBody() {"
end_marker = "  String _t(String key) {"

if start_marker in content and end_marker in content:
    start_index = content.find(start_marker)
    end_index = content.find(end_marker)
    
    new_results_body = """Widget _resultsBody() {
    final p = CarelinkPalette.of(context);
    final dark = p.isDark;
    
    final isEmergency = _aiAnalysis?['isEmergency'] == true || _analysisValue('isEmergency') == 'true';

    if (_results.isEmpty) {
      return CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 60, 24, 24),
              child: Column(
                children: [
                  Image.asset(
                    'assets/images/ai_robot_illustration.png',
                    height: 120,
                    errorBuilder: (_, __, ___) => const Icon(Icons.search_off_rounded, size: 80, color: AppColors.primary),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    _ar ? 'لم يتم العثور على تطابق طبي' : 'No medical match found',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: p.inkDark,
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    _ar ? 'لم نتمكن من إيجاد مقدم رعاية مناسب لحالتك حالياً. يرجى تصفح جميع مقدمي الرعاية.' : 'We couldn\\'t find a suitable care provider for your case right now. Please browse all providers.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: p.inkMuted,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 32),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                    onPressed: () => Navigator.of(context).pop(),
                    child: Text(_ar ? 'عرض جميع مقدمي الرعاية' : 'Search all providers', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  ),
                ],
              ),
            ),
          ),
        ],
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        return CustomScrollView(
          slivers: [
            // Header
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
              sliver: SliverToBoxAdapter(
                child: Column(
                  children: [
                    Text(
                      _ar ? 'وجدنا أفضل مقدم رعاية لحالتك' : 'We found the best care provider for you',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: dark ? p.inkDark : AppColors.primary,
                        fontSize: 24,
                        fontWeight: FontWeight.w900,
                        height: 1.2,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _ar ? 'تم ترتيب النتائج حسب مدى توافقها مع احتياجك.' : 'Results are ranked based on their compatibility with your needs.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: p.inkMuted,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            
            // Emergency Card
            if (isEmergency)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 24),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.red.shade50,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.red.shade200, width: 2),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.emergency_rounded, color: Colors.red.shade700, size: 32),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _ar ? 'تحذير طارئ' : 'Emergency Warning',
                                style: TextStyle(color: Colors.red.shade800, fontWeight: FontWeight.w900, fontSize: 16),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                _t('emergencyWarningText'),
                                style: TextStyle(color: Colors.red.shade900, fontSize: 13, fontWeight: FontWeight.w700),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

            // AI Summary Card
            if (_hasVisibleAiAnalysis)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 24),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: isEmergency ? Colors.red.shade50.withValues(alpha: 0.5) : p.surface,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: isEmergency ? Colors.red.withValues(alpha: 0.3) : AppColors.primary.withValues(alpha: 0.15)),
                      boxShadow: [
                        BoxShadow(
                          color: (isEmergency ? Colors.red : AppColors.primary).withValues(alpha: 0.05),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Text('🤖', style: TextStyle(fontSize: 16)),
                            const SizedBox(width: 8),
                            Text(
                              'AI Analysis',
                              style: TextStyle(
                                fontSize: 15, 
                                fontWeight: FontWeight.w900, 
                                color: isEmergency ? Colors.red.shade800 : p.inkDark
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            if (_analysisValue('service') != null)
                              _buildInfoChip(Icons.medical_services_rounded, _analysisValue('service')!, isEmergency ? Colors.red : AppColors.primary),
                            if (_analysisValue('need') != null)
                              _buildInfoChip(Icons.healing_rounded, _analysisValue('need')!, isEmergency ? Colors.red : AppColors.primary),
                            if (_analysisValue('priority') != null)
                              _buildInfoChip(Icons.flag_rounded, _analysisValue('priority')!, isEmergency ? Colors.red : Colors.green.shade600),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),

            // Best Provider (index 0)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
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
            
            // Other Providers header
            if (_results.length > 1)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(24, 32, 24, 16),
                  child: Text(
                    _ar ? 'مقدمو رعاية آخرون' : 'Other Care Providers',
                    style: TextStyle(
                      color: p.inkDark,
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ),

            // Other Providers list
            if (_results.length > 1)
              SliverPadding(
                padding: EdgeInsets.fromLTRB(24, 0, 24, 148 + MediaQuery.paddingOf(context).bottom),
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
        );
      },
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
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

"""
    updated_content = content[:start_index] + new_results_body + content[end_index:]
    with open(filepath, 'w', encoding='utf-8') as f:
        f.write(updated_content)
    print("Successfully replaced _resultsBody")
else:
    print("Could not find start or end markers")
