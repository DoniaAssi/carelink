import os
import re

filepath = r'lib/features/ai/screens/find_provider_screen.dart'

with open(filepath, 'r', encoding='utf-8') as f:
    content = f.read()

# Let's replace _inputBody completely.
input_body_match = re.search(r'Widget _inputBody\(\) \{([\s\S]*?)Widget _resultsBody\(\) \{', content)
if input_body_match:
    new_input = """Widget _inputBody() {
    final p = CarelinkPalette.of(context);
    final dark = p.isDark;
    
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Hero Robot
          Center(
            child: SizedBox(
              height: 160,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Container(
                    width: 140,
                    height: 140,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppColors.primary.withValues(alpha: 0.05),
                    ),
                  ),
                  Image.asset(
                    'assets/images/ai_robot_illustration.png',
                    height: 120,
                    errorBuilder: (_, __, ___) => const Icon(Icons.smart_toy_rounded, size: 80, color: AppColors.primary),
                  ),
                  // Floating Icons (simplified)
                  Positioned(top: 20, left: 0, child: Icon(Icons.favorite_rounded, color: AppColors.primary.withValues(alpha: 0.6), size: 24)),
                  Positioned(bottom: 40, right: 0, child: Icon(Icons.medication_rounded, color: AppColors.primary.withValues(alpha: 0.6), size: 24)),
                  Positioned(top: 40, right: 20, child: Icon(Icons.psychology_rounded, color: AppColors.primary.withValues(alpha: 0.6), size: 24)),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          
          // Greeting
          Text(
            _ar ? 'مرحباً 👋 كيف أقدر أساعدك اليوم؟' : 'Hello 👋 How can I help you today?',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w900,
              color: p.inkDark,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _ar 
              ? 'اكتبي حالتك أو اختاري مثال سريع وسنرشح لك أفضل مقدم رعاية مناسب.' 
              : 'Type your case or pick a quick example and we will recommend the best care provider.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: p.inkMuted,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 32),
          
          // Input Card
          Container(
            decoration: BoxDecoration(
              color: p.surface,
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 24,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  TextField(
                    controller: _controller,
                    maxLines: 4,
                    minLines: 3,
                    style: TextStyle(color: p.inkDark, fontSize: 15, fontWeight: FontWeight.w600),
                    decoration: InputDecoration(
                      hintText: _ar ? 'اكتبي حالتك هنا...' : 'Type your case here...',
                      hintStyle: TextStyle(color: p.inkMuted, fontSize: 15),
                      border: InputBorder.none,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Mic Button & Counter
                      Row(
                        children: [
                          IconButton(
                            onPressed: _toggleListening,
                            icon: Icon(
                              _isListening ? Icons.mic_rounded : Icons.mic_none_rounded,
                              color: _isListening ? Colors.red : AppColors.primary,
                            ),
                            style: IconButton.styleFrom(
                              backgroundColor: AppColors.primary.withValues(alpha: 0.1),
                              shape: const CircleBorder(),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            '${_controller.text.length}/500',
                            style: TextStyle(color: p.inkMuted, fontSize: 12, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                      // Send Button
                      GestureDetector(
                        onTap: _isButtonLoading ? null : _analyzeCase,
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 300),
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            color: AppColors.primary,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.primary.withValues(alpha: 0.3),
                                blurRadius: 12,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Center(
                            child: _isButtonLoading
                                ? const SizedBox(
                                    width: 24,
                                    height: 24,
                                    child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
                                  )
                                : const Icon(Icons.send_rounded, color: Colors.white, size: 20),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 32),
          
          // Quick Suggestions
          Text(
            _ar ? 'أمثلة سريعة' : 'Quick Examples',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w800,
              color: p.inkDark,
            ),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 12,
            alignment: WrapAlignment.center,
            children: [
              _buildSuggestionChip('رعاية جروح', '🩹'),
              _buildSuggestionChip('حقن منزلية', '💉'),
              _buildSuggestionChip('كبار السن', '👵'),
              _buildSuggestionChip('القلب', '❤️'),
              _buildSuggestionChip('حرارة', '🤒'),
              _buildSuggestionChip('إعطاء أدوية', '💊'),
            ],
          ),
          const SizedBox(height: 40),
          
          // Privacy
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.shield_rounded, color: AppColors.primary.withValues(alpha: 0.7), size: 16),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  _ar ? 'الذكاء الاصطناعي يحلل حالتك بدقة لاختيار أفضل مقدم رعاية لك' : 'AI accurately analyzes your case to select the best care provider',
                  style: TextStyle(
                    color: p.inkMuted,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSuggestionChip(String label, String emoji) {
    return ActionChip(
      backgroundColor: Theme.of(context).colorScheme.surface,
      side: BorderSide(color: AppColors.primary.withValues(alpha: 0.2)),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      label: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(emoji, style: const TextStyle(fontSize: 14)),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(
              color: AppColors.primary,
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
      onPressed: () {
        _controller.text = label;
        _analyzeCase();
      },
    );
  }

  Widget _resultsBody() {"""
    content = content.replace(input_body_match.group(0), new_input)
    with open(filepath, 'w', encoding='utf-8') as f:
        f.write(content)
    print("Updated _inputBody")
else:
    print("Could not find _inputBody")
