import re
import os

filepath = r'lib/features/ai/screens/find_provider_screen.dart'

with open(filepath, 'r', encoding='utf-8') as f:
    content = f.read()

# 1. Add TickerProviderStateMixin if not there
if 'with TickerProviderStateMixin' not in content:
    content = content.replace(
        'class _FindProviderScreenState extends State<FindProviderScreen> {',
        'class _FindProviderScreenState extends State<FindProviderScreen> with TickerProviderStateMixin {'
    )

# 2. Inject Animation controllers
init_state_idx = content.find('void initState() {')
if 'AnimationController _robotBreathingController;' not in content:
    injection = '''
  late AnimationController _robotBreathingController;
  late AnimationController _robotFloatingController;
  late AnimationController _buttonShimmerController;

'''
    content = content[:init_state_idx] + injection + content[init_state_idx:]

init_state_super_idx = content.find('super.initState();', init_state_idx)
if '_robotBreathingController = AnimationController(' not in content:
    injection = '''
    _robotBreathingController = AnimationController(vsync: this, duration: const Duration(milliseconds: 2000))..repeat(reverse: true);
    _robotFloatingController = AnimationController(vsync: this, duration: const Duration(milliseconds: 3000))..repeat(reverse: true);
    _buttonShimmerController = AnimationController(vsync: this, duration: const Duration(milliseconds: 1500))..repeat();
'''
    content = content[:init_state_super_idx + 18] + injection + content[init_state_super_idx + 18:]

dispose_idx = content.find('void dispose() {')
if dispose_idx != -1 and '_robotBreathingController.dispose();' not in content:
    dispose_super_idx = content.find('super.dispose();', dispose_idx)
    injection = '''
    _robotBreathingController.dispose();
    _robotFloatingController.dispose();
    _buttonShimmerController.dispose();
'''
    content = content[:dispose_super_idx] + injection + content[dispose_super_idx:]
elif dispose_idx == -1:
    # Need to add dispose
    build_idx = content.find('Widget build(BuildContext context)')
    injection = '''
  @override
  void dispose() {
    _robotBreathingController.dispose();
    _robotFloatingController.dispose();
    _buttonShimmerController.dispose();
    _caseController.dispose();
    super.dispose();
  }

'''
    content = content[:build_idx] + injection + content[build_idx:]


# 3. Replace _inputBody() and _robotHero() completely
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
      {'ar': 'حقن ومحاليل', 'en': 'Injections & IVs', 'icon': '💉'},
      {'ar': 'رعاية جروح', 'en': 'Wound Care', 'icon': '🩹'},
      {'ar': 'كبار السن', 'en': 'Elderly Care', 'icon': '👵'},
      {'ar': 'إعطاء أدوية', 'en': 'Medication', 'icon': '💊'},
      {'ar': 'رعاية أمومة وطفل', 'en': 'Mother & Child', 'icon': '👶'},
      {'ar': 'أمراض مزمنة', 'en': 'Chronic Diseases', 'icon': '❤️'},
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Premium Header
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back_rounded, color: AppColors.primary),
                onPressed: _handleBack,
              ),
              Row(
                children: [
                  CarelinkThemeToggle(isDark: dark, onToggle: ThemeController().toggleTheme),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: Icon(Icons.language, color: p.inkMuted),
                    onPressed: LocaleController().toggleLocale,
                  ),
                ],
              ),
            ],
          ),
        ),
        
        Expanded(
          child: ListView(
            padding: EdgeInsets.fromLTRB(20, 0, 20, 38 + MediaQuery.paddingOf(context).bottom),
            children: [
              // Robot Section
              _robotHero(p),
              
              const SizedBox(height: 24),
              
              // Title
              Text(
                _ar ? 'الذكاء الاصطناعي للرعاية' : 'AI Care Assistant',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: AppColors.primary,
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _ar ? 'صف حالتك أو احتياجك الطبي\\nوسنرشح لك أفضل مقدم رعاية.' : 'Describe your condition or medical need\\nand we will recommend the best care provider.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: themeColor,
                  fontSize: 15,
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
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                      child: Row(
                        children: [
                          Icon(Icons.chat_bubble_outline_rounded, color: AppColors.primary, size: 20),
                          const SizedBox(width: 8),
                          Text(
                            _ar ? 'اكتب حالتك أو احتياجك الطبي' : 'Write your condition or medical need',
                            style: TextStyle(
                              color: themeColor,
                              fontWeight: FontWeight.w800,
                              fontSize: 15,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Container(
                        decoration: BoxDecoration(
                          color: p.pageBg.withValues(alpha: 0.5),
                          borderRadius: BorderRadius.circular(16),
                        ),
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
                                hintText: _ar ? 'اكتب هنا وصف حالتك أو ما تحتاجه من رعاية...' : 'Type your condition or care needs here...',
                                hintStyle: TextStyle(
                                  color: helperColor,
                                  fontSize: 14,
                                  height: 1.5,
                                  fontWeight: FontWeight.w500,
                                ),
                                filled: false,
                                counterText: '',
                                contentPadding: const EdgeInsets.all(16),
                                border: InputBorder.none,
                              ),
                            ),
                            PositionedDirectional(
                              bottom: 8,
                              end: 8,
                              child: _voiceInputButton(p),
                            ),
                            PositionedDirectional(
                              bottom: 12,
                              start: 16,
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
                    ),
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Text(
                        _ar ? 'مثال:\\n"والدتي تحتاج تغيير ضماد بعد العملية مرتين أسبوعياً."' : 'Example:\\n"My mother needs wound dressing after surgery twice a week."',
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

              const SizedBox(height: 28),

              // Quick Examples
              Row(
                children: [
                  Icon(Icons.bolt_rounded, color: AppColors.primary, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    _ar ? 'أمثلة سريعة' : 'Quick Examples',
                    style: TextStyle(
                      color: themeColor,
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
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

              const SizedBox(height: 36),

              // Primary CTA
              AnimatedScale(
                scale: _aiRunning ? 0.95 : 1.0,
                duration: const Duration(milliseconds: 150),
                child: Container(
                  height: 56,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.primary.withValues(alpha: 0.3),
                        blurRadius: 20,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
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
                              const Icon(Icons.auto_awesome_rounded, size: 22),
                            ],
                          ),
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // Privacy Footer
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.lock_outline_rounded, color: helperColor, size: 14),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      _ar ? 'بياناتك آمنة وسرية ولن تتم مشاركتها مع أي جهة أخرى.' : 'Your data is secure, confidential, and will not be shared.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: helperColor,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _robotHero(CarelinkPalette p) {
    return AnimatedBuilder(
      animation: Listenable.merge([_robotBreathingController, _robotFloatingController]),
      builder: (context, child) {
        final floatOffset = Math.sin(_robotFloatingController.value * 2 * Math.pi) * 10;
        final scale = 1.0 + (_robotBreathingController.value * 0.05);

        return SizedBox(
          height: MediaQuery.of(context).size.height * 0.25,
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Soft Glow Background
              Container(
                width: 200,
                height: 200,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      AppColors.primary.withValues(alpha: 0.15),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
              
              // Floating medical icons
              _buildFloatingIcon(Icons.favorite_rounded, -60, -80, 0),
              _buildFloatingIcon(Icons.medical_services_rounded, 60, -70, 0.3),
              _buildFloatingIcon(Icons.healing_rounded, -80, 20, 0.6),
              _buildFloatingIcon(Icons.psychology_rounded, 80, 30, 0.9),

              // Robot Image
              Transform.translate(
                offset: Offset(0, floatOffset),
                child: Transform.scale(
                  scale: scale,
                  child: Image.asset(
                    'assets/images/ai_robot_illustration.png',
                    fit: BoxFit.contain,
                    height: 180,
                    errorBuilder: (context, error, stackTrace) => const Icon(
                      Icons.smart_toy_rounded,
                      size: 100,
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
    final floatOffset = Math.sin((_robotFloatingController.value + delayOffset) * 2 * Math.pi) * 15;
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

# We need to import dart:math
if "import 'dart:math' as Math;" not in content:
    content = content.replace("import 'package:flutter/material.dart';", "import 'package:flutter/material.dart';\nimport 'dart:math' as Math;")

# One last thing: PatientScaffold in _FindProviderScreenState build method
# We need to remove the default appBar so our custom header works well.
appbar_idx = content.find('appBar: PatientTopActions(showBack: true, onBack: _handleBack),')
if appbar_idx != -1:
    # Instead of removing the app bar entirely, we only remove it if _showResults is false and _aiRunning is false
    # Actually, we can just remove it from PatientScaffold entirely since our new _inputBody has a header, 
    # but the results and loading screens might need an appbar.
    # Let's see: `appBar: (!_showResults && !_aiRunning) ? null : PatientTopActions(showBack: true, onBack: _handleBack),`
    content = content.replace(
        'appBar: PatientTopActions(showBack: true, onBack: _handleBack),',
        'appBar: (!_showResults && !_aiRunning && !(_providers == null || _loadingList || _fetchError)) ? null : PatientTopActions(showBack: true, onBack: _handleBack),'
    )

with open(filepath, 'w', encoding='utf-8') as f:
    f.write(content)

print("UI updated successfully.")
