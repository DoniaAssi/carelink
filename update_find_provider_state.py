import os
import re

filepath = r'lib/features/ai/screens/find_provider_screen.dart'

with open(filepath, 'r', encoding='utf-8') as f:
    content = f.read()

# Add _isButtonLoading boolean
if 'bool _isButtonLoading = false;' not in content:
    content = content.replace('bool _aiRunning = false;', 'bool _aiRunning = false;\n  bool _isButtonLoading = false;')

# Update _analyzeCase method to set _isButtonLoading
analyze_match = re.search(r'Future<void> _analyzeCase\(\) async \{([\s\S]*?)setState\(\(\) \{\n\s*_aiRunning = true;\n\s*\}\);', content)
if analyze_match:
    new_analyze = """Future<void> _analyzeCase() async {
    FocusScope.of(context).unfocus();
    final q = _controller.text.trim();
    if (q.isEmpty) return;

    setState(() {
      _isButtonLoading = true;
    });
    
    // Simulate slight delay for button loading animation
    await Future.delayed(const Duration(milliseconds: 600));

    if (!mounted) return;
    setState(() {
      _isButtonLoading = false;
      _aiRunning = true;
    });"""
    content = content.replace(analyze_match.group(0), new_analyze)

# Replace the Expanded child logic
# The easiest way is to use regex to find the `Expanded( child: _aiRunning ? ... : _inputBody() ),` block.
expanded_pattern = r'Expanded\(\s*child:\s*_aiRunning[\s\S]*?_inputBody\(\)\)\)\),\s*\),'
new_expanded = """Expanded(
                      child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 600),
                        switchInCurve: Curves.easeOutCubic,
                        switchOutCurve: Curves.easeIn,
                        transitionBuilder: (Widget child, Animation<double> animation) {
                          if (child.key == const ValueKey('results')) {
                            return SlideTransition(
                              position: Tween<Offset>(begin: const Offset(0, 0.1), end: Offset.zero).animate(animation),
                              child: FadeTransition(opacity: animation, child: child),
                            );
                          }
                          return FadeTransition(opacity: animation, child: child);
                        },
                        child: _aiRunning
                            ? (_providers == null || _loadingList
                                ? KeyedSubtree(key: const ValueKey('loading_list'), child: _providersLoadingBody())
                                : KeyedSubtree(key: const ValueKey('ai_loader'), child: AiRecommendationLoader(isArabic: _ar)))
                            : _showResults
                                ? KeyedSubtree(key: const ValueKey('results'), child: _resultsBody())
                                : (_fetchError || _isTimeout
                                    ? KeyedSubtree(key: const ValueKey('error'), child: _providersErrorBody())
                                    : (_providers != null && _providers!.isEmpty
                                        ? KeyedSubtree(key: const ValueKey('empty'), child: _providersEmptyBody())
                                        : KeyedSubtree(key: const ValueKey('input'), child: _inputBody()))),
                      ),
                    ),"""

content = re.sub(expanded_pattern, new_expanded, content)

with open(filepath, 'w', encoding='utf-8') as f:
    f.write(content)
print("Updated find_provider_screen state and transitions")
