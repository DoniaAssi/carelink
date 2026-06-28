import os
import re

filepath = r'lib/features/ai/screens/find_provider_screen.dart'

with open(filepath, 'r', encoding='utf-8') as f:
    content = f.read()

# Replace the Expanded child with AnimatedSwitcher
old_code = """                    Expanded(
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
                    ),"""

new_code = """                    Expanded(
                      child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 500),
                        transitionBuilder: (Widget child, Animation<double> animation) {
                          if (child.key == const ValueKey('results')) {
                            return SlideTransition(
                              position: Tween<Offset>(begin: const Offset(0, 0.1), end: Offset.zero).animate(
                                CurvedAnimation(parent: animation, curve: Curves.easeOutCubic),
                              ),
                              child: FadeTransition(opacity: animation, child: child),
                            );
                          }
                          return FadeTransition(
                            opacity: CurvedAnimation(parent: animation, curve: Curves.easeIn),
                            child: child,
                          );
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

if old_code in content:
    updated_content = content.replace(old_code, new_code)
    with open(filepath, 'w', encoding='utf-8') as f:
        f.write(updated_content)
    print("Successfully updated AnimatedSwitcher in build method.")
else:
    print("Could not find old code block.")
