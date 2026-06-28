import re
import os

filepath = r'lib/features/ai/screens/find_provider_screen.dart'

with open(filepath, 'r', encoding='utf-8') as f:
    content = f.read()

# Replace the appBar logic in _FindProviderScreenState.build
# Currently it is: appBar: (!_showResults && !_aiRunning && !(_providers == null || _loadingList || _fetchError)) ? null : PatientTopActions(showBack: true, onBack: _handleBack),
appbar_target = "appBar: (!_showResults && !_aiRunning && !(_providers == null || _loadingList || _fetchError)) ? null : PatientTopActions(showBack: true, onBack: _handleBack),"
new_appbar = "appBar: _buildAppBar(),"
if appbar_target in content:
    content = content.replace(appbar_target, new_appbar)
else:
    # try another match
    appbar_target2 = "appBar: PatientTopActions(showBack: true, onBack: _handleBack),"
    if appbar_target2 in content:
        content = content.replace(appbar_target2, new_appbar)

# Find where to inject _buildAppBar
if "PreferredSizeWidget _buildAppBar()" not in content:
    build_method_idx = content.find("Widget build(BuildContext context) {")
    appbar_injection = '''
  PreferredSizeWidget _buildAppBar() {
    final p = CarelinkPalette.of(context);
    return AppBar(
      backgroundColor: Colors.transparent,
      elevation: 0,
      centerTitle: true,
      leading: IconButton(
        icon: Icon(
          _ar ? Icons.arrow_forward_rounded : Icons.arrow_back_rounded,
          color: AppColors.primary,
        ),
        onPressed: _handleBack,
      ),
      title: Text(
        _ar ? 'الذكاء الاصطناعي للرعاية' : 'AI Care Assistant',
        style: TextStyle(
          color: p.inkDark,
          fontSize: 18,
          fontWeight: FontWeight.w800,
        ),
      ),
      actions: [
        CarelinkThemeToggle(isDark: p.isDark, onToggle: ThemeController().toggleTheme),
        IconButton(
          icon: Icon(Icons.language, color: p.inkMuted),
          onPressed: LocaleController().toggleLocale,
        ),
        const SizedBox(width: 8),
      ],
    );
  }

'''
    content = content[:build_method_idx] + appbar_injection + content[build_method_idx:]


# Replace _inputBody and _robotHero with the refined version
input_body_start = content.find('Widget _inputBody() {')
robot_hero_start = content.find('Widget _robotHero(CarelinkPalette p) {')
robot_hero_end = content.find('Widget _providersLoadingBody() {', robot_hero_start)

if input_body_start != -1 and robot_hero_end != -1:
    new_input_body = '''
  Widget _inputBody() {
    final p = CarelinkPalette.of(context);
    final dark = p.isDark;
    final themeColor = p.inkDark;
    final helperColor = p.inkMuted;

    final chips = [
      {'ar': 'حقن', 'en': 'Injections', 'icon': '💉'},
      {'ar': 'رعاية جروح', 'en': 'Wound Care', 'icon': '🩹'},
      {'ar': 'كبار السن', 'en': 'Elderly Care', 'icon': '👵'},
      {'ar': 'إعطاء أدوية', 'en': 'Medication', 'icon': '💊'},
      {'ar': 'حرارة', 'en': 'Fever', 'icon': '🤒'},
      {'ar': 'القلب', 'en': 'Heart', 'icon': '❤️'},
    ];

    return ListView(
      padding: EdgeInsets.fromLTRB(24, 0, 24, 48 + MediaQuery.paddingOf(context).bottom),
      children: [
        // Compact Hero Section (Max Height 180px)
        _robotHero(p),
        
        const SizedBox(height: 16),
        
        // Title
        Text(
          _ar ? 'كيف يمكنني مساعدتك اليوم؟' : 'How can I help you today?',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: AppColors.primary,
            fontSize: 30,
            fontWeight: FontWeight.w900,
            height: 1.1,
          ),
        ),
        const SizedBox(height: 12),
        Text(
          _ar ? 'اكتب أو تحدث عن حالتك وسأرشح لك أفضل مقدم رعاية مناسب.' : 'Write or speak about your condition and I will recommend the best care provider.',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: themeColor,
            fontSize: 16,
            height: 1.5,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 24),

        // Input Card
        Container(
          decoration: BoxDecoration(
            color: p.surface,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: p.stroke.withValues(alpha: 0.5)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: p.isDark ? 0.2 : 0.04),
                blurRadius: 24,
                offset: const Offset(0, 12),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Stack(
                  children: [
                    TextField(
                      controller: _caseController,
                      minLines: 4,
                      maxLines: 4,
                      maxLength: 500,
                      onChanged: (_) => setState(() {}),
                      textInputAction: TextInputAction.newline,
                      style: TextStyle(
                        color: themeColor,
                        fontSize: 15,
                        height: 1.5,
                        fontWeight: FontWeight.w600,
                      ),
                      decoration: InputDecoration(
                        hintText: _ar ? 'اكتب حالتك هنا...' : 'Write your condition here...',
                        hintStyle: TextStyle(
                          color: helperColor,
                          fontSize: 14,
                          height: 1.5,
                          fontWeight: FontWeight.w500,
                        ),
                        filled: false,
                        counterText: '',
                        contentPadding: const EdgeInsets.only(top: 16, bottom: 42, left: 0, right: 0),
                        border: InputBorder.none,
                      ),
                    ),
                    PositionedDirectional(
                      bottom: 8,
                      end: 0,
                      child: _voiceInputButton(p),
                    ),
                    PositionedDirectional(
                      bottom: 18,
                      start: 0,
                      child: Text(
                        '${_caseController.text.length} / 500',
                        style: TextStyle(
                          color: helperColor,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: Text(
                  _ar ? 'مثال:\\nأحتاج ممرضاً لرعاية والدي بعد العملية.' : 'Example:\\nI need a nurse to care for my father after surgery.',
                  style: TextStyle(
                    color: helperColor,
                    fontSize: 13,
                    height: 1.5,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 24),

        // Quick Examples
        Row(
          children: [
            Icon(Icons.bolt_rounded, color: AppColors.primary, size: 20),
            const SizedBox(width: 8),
            Text(
              _ar ? 'أمثلة سريعة' : 'Quick Examples',
              style: TextStyle(
                color: themeColor,
                fontSize: 18,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: chips.map((chip) {
            return InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () {
                setState(() {
                  _caseController.text = _ar ? chip['ar']! : chip['en']!;
                  _caseController.selection = TextSelection.fromPosition(TextPosition(offset: _caseController.text.length));
                });
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: p.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: p.stroke),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: p.isDark ? 0.1 : 0.02),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(chip['icon']!, style: const TextStyle(fontSize: 14)),
                    const SizedBox(width: 8),
                    Text(
                      _ar ? chip['ar']! : chip['en']!,
                      style: TextStyle(
                        color: themeColor,
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
        ),

        const SizedBox(height: 32),

        // Primary CTA
        AnimatedScale(
          scale: _aiRunning ? 0.96 : 1.0,
          duration: const Duration(milliseconds: 150),
          child: Container(
            height: 56,
            width: double.infinity,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              gradient: LinearGradient(
                colors: [
                  AppColors.primary,
                  AppColors.primaryDark,
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              boxShadow: [
                BoxShadow(
                  color: AppColors.primary.withValues(alpha: 0.35),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.transparent,
                shadowColor: Colors.transparent,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
              onPressed: _aiRunning ? null : _analyzeCase,
              child: _aiRunning 
                  ? const SizedBox(
                      width: 24, height: 24,
                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
                    )
                  : Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          _ar ? 'تحليل الحالة' : 'Analyze Case',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(width: 12),
                        const Text('✨', style: TextStyle(fontSize: 18)),
                      ],
                    ),
            ),
          ),
        ),

        const SizedBox(height: 24),

        // Privacy Footer
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.lock_rounded, color: helperColor, size: 14),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                _ar ? 'بياناتك آمنة ولن تتم مشاركتها مع أي جهة أخرى.' : 'Your data is secure and will not be shared.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: helperColor,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _robotHero(CarelinkPalette p) {
    return AnimatedBuilder(
      animation: Listenable.merge([_robotBreathingController, _robotFloatingController]),
      builder: (context, child) {
        final floatOffset = math.sin(_robotFloatingController.value * 2 * math.pi) * 8;
        final scale = 1.0 + (_robotBreathingController.value * 0.03);

        return SizedBox(
          height: 180,
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Soft Glow Background
              Container(
                width: 160,
                height: 160,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.primary.withValues(alpha: 0.05),
                  border: Border.all(color: AppColors.primary.withValues(alpha: 0.1)),
                ),
              ),
              
              // Floating medical icons
              _buildFloatingIcon(Icons.favorite_rounded, -70, -50, 0),
              _buildFloatingIcon(Icons.medical_services_rounded, 70, -40, 0.3),
              _buildFloatingIcon(Icons.healing_rounded, -60, 40, 0.6),
              _buildFloatingIcon(Icons.psychology_rounded, 60, 50, 0.9),

              // Robot Image
              Transform.translate(
                offset: Offset(0, floatOffset),
                child: Transform.scale(
                  scale: scale,
                  child: Image.asset(
                    'assets/images/ai_robot_illustration.png',
                    fit: BoxFit.contain,
                    height: 140,
                    errorBuilder: (context, error, stackTrace) => const Icon(
                      Icons.smart_toy_rounded,
                      size: 90,
                      color: AppColors.primary,
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildFloatingIcon(IconData icon, double x, double y, double delayOffset) {
    final floatOffset = math.sin((_robotFloatingController.value + delayOffset) * 2 * math.pi) * 12;
    return Transform.translate(
      offset: Offset(x, y + floatOffset),
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: AppColors.primary.withValues(alpha: 0.1),
          shape: BoxShape.circle,
          border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
        ),
        child: Icon(icon, color: AppColors.primary.withValues(alpha: 0.6), size: 20),
      ),
    );
  }
'''
    content = content[:input_body_start] + new_input_body + content[robot_hero_end:]


# We also need to fix _voiceInputButton so it fits perfectly inside the field without a harsh vertical line if possible
voice_btn_start = content.find('Widget _voiceInputButton(CarelinkPalette p) {')
voice_btn_end = content.find('Widget _resultsBody() {', voice_btn_start)

if voice_btn_start != -1 and voice_btn_end != -1:
    new_voice_btn = '''
  Widget _voiceInputButton(CarelinkPalette p) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: _listening
            ? LinearGradient(colors: [Colors.redAccent, Colors.deepOrangeAccent])
            : LinearGradient(colors: [AppColors.primary, AppColors.primaryDark]),
        boxShadow: _listening
            ? [BoxShadow(color: Colors.redAccent.withValues(alpha: 0.3), blurRadius: 12)]
            : [BoxShadow(color: AppColors.primary.withValues(alpha: 0.2), blurRadius: 8)],
      ),
      child: IconButton(
        tooltip: _listening ? _t('listening') : _t('tapToSpeak'),
        onPressed: _toggleVoice,
        padding: EdgeInsets.zero,
        icon: Icon(
          _listening ? Icons.stop_rounded : Icons.mic_rounded,
          color: Colors.white,
          size: 22,
        ),
      ),
    );
  }

'''
    content = content[:voice_btn_start] + new_voice_btn + content[voice_btn_end:]


with open(filepath, 'w', encoding='utf-8') as f:
    f.write(content)

print("UI updated successfully.")
