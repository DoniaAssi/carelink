import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'package:carelink/core/app_colors.dart';
import 'package:carelink/core/carelink_app_theme.dart';
import 'package:carelink/core/carelink_palette.dart';
import 'package:carelink/shared/services/api_service.dart';

class NurseUi {
  static final ValueNotifier<bool> isDarkMode = ValueNotifier(false);
  static final ValueNotifier<bool> isArabic = ValueNotifier(false);
  static const _darkModeKey = 'nurse_ui_dark_mode';
  static const _languageKey = 'nurse_ui_language';

  static CarelinkPalette get palette =>
      isDarkMode.value ? CarelinkPalette.dark() : CarelinkPalette.light();

  static Color get background => palette.pageBg;
  static Color get surface => palette.surface;
  static Color get text => palette.inkDark;
  static Color get muted => palette.inkMuted;
  static Color get border => palette.stroke;
  static Color get softSurface => palette.surfaceSoft;
  static Color get primary => AppColors.primary;
  static Color get primaryDark => AppColors.primaryDark;

  static const double cardRadius = 22;
  static const double controlRadius = 16;
  static const double buttonRadius = 12;
  static const double buttonHeight = 48;

  static List<BoxShadow> get softShadow => [
    BoxShadow(
      color: palette.cardShadowColor(isDarkMode.value ? 0.22 : 0.04),
      blurRadius: 14,
      offset: const Offset(0, 6),
    ),
  ];

  static BoxDecoration cardDecoration({
    double radius = cardRadius,
    Color? color,
    Color? borderColor,
    bool shadow = true,
  }) {
    return BoxDecoration(
      color: color ?? surface,
      borderRadius: BorderRadius.circular(radius),
      border: Border.all(color: borderColor ?? border),
      boxShadow: shadow ? softShadow : null,
    );
  }

  static BoxDecoration chipDecoration({required bool selected}) {
    return BoxDecoration(
      color: selected ? primary : surface,
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: selected ? primary : border),
      boxShadow: selected ? softShadow : null,
    );
  }

  static InputDecoration inputDecoration(String hint, {IconData? prefixIcon}) {
    return InputDecoration(
      hintText: hint,
      prefixIcon: prefixIcon == null
          ? null
          : Icon(prefixIcon, color: primary, size: 20),
    );
  }

  static ButtonStyle get primaryButtonStyle => FilledButton.styleFrom(
    backgroundColor: primary,
    foregroundColor: Colors.white,
    disabledBackgroundColor: primary.withValues(alpha: 0.5),
    minimumSize: const Size.fromHeight(buttonHeight),
    padding: const EdgeInsets.symmetric(horizontal: 16),
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(buttonRadius),
    ),
    textStyle: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
  );

  static ButtonStyle get elevatedPrimaryButtonStyle => ElevatedButton.styleFrom(
    backgroundColor: primary,
    foregroundColor: Colors.white,
    disabledBackgroundColor: primary.withValues(alpha: 0.5),
    elevation: 0,
    minimumSize: const Size.fromHeight(buttonHeight),
    padding: const EdgeInsets.symmetric(horizontal: 16),
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(buttonRadius),
    ),
    textStyle: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
  );

  static ButtonStyle get secondaryButtonStyle => OutlinedButton.styleFrom(
    foregroundColor: primary,
    backgroundColor: surface,
    side: const BorderSide(color: AppColors.primary, width: 1.5),
    minimumSize: const Size.fromHeight(buttonHeight),
    padding: const EdgeInsets.symmetric(horizontal: 16),
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(buttonRadius),
    ),
    textStyle: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
  );

  static ButtonStyle get dangerButtonStyle => FilledButton.styleFrom(
    backgroundColor: const Color(0xFFE53935),
    foregroundColor: Colors.white,
    minimumSize: const Size.fromHeight(buttonHeight),
    padding: const EdgeInsets.symmetric(horizontal: 16),
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(buttonRadius),
    ),
    textStyle: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
  );

  static TextDirection get direction =>
      isArabic.value ? TextDirection.rtl : TextDirection.ltr;

  static String label(String english, String arabic) {
    return isArabic.value ? arabic : english;
  }

  static String t(String english) {
    if (!isArabic.value) return english;
    return _arabicLabels[english] ?? english;
  }

  static const Map<String, String> _arabicLabels = {
    'Home': 'الرئيسية',
    'Sessions': 'الجلسات',
    'Patients': 'المرضى',
    'Earnings': 'الأرباح',
    'Notifications': 'الإشعارات',
    'Alerts': 'التنبيهات',
    'Profile': 'الملف',
    'Nurse': 'ممرضة',
    'Settings': 'الإعدادات',
    'Account': 'الحساب',
    'Privacy': 'الخصوصية',
    'App Settings': 'إعدادات التطبيق',
    'Language': 'اللغة',
    'Dark Mode': 'الوضع الداكن',
    'My Patients': 'مرضاي',
    'Search patients...': 'ابحثي عن المرضى...',
    'No patients yet': 'لا يوجد مرضى بعد',
    'Retry': 'إعادة المحاولة',
    'Messages': 'الرسائل',
    'All': 'الكل',
    'Requests': 'الطلبات',
    'Visits': 'الزيارات',
    'System': 'النظام',
    'Earnings & Payments': 'الأرباح والمدفوعات',
    'Quick Actions': 'إجراءات سريعة',
    'Summary by Service': 'ملخص حسب الخدمة',
    'Overall Summary': 'الملخص العام',
    'Request Details': 'تفاصيل الطلب',
    'Payment Method': 'طريقة الدفع',
    'Accept Rate': 'قبول السعر',
    'Reject Rate': 'رفض السعر',
    'Accept your admin-set hourly rate before requesting payouts.':
        'اقبلي السعر المحدد من الأدمن قبل طلب الدفعات.',
    'Failed to load dashboard data': 'فشل تحميل بيانات لوحة التحكم',
    'No upcoming visits today': 'لا توجد زيارات قادمة اليوم',
    'Upcoming Visits': 'الزيارات القادمة',
    'View All': 'عرض الكل',
    'All Requests': 'كل الطلبات',
    'My Schedule': 'جدولي',
    'Reports': 'التقارير',
    'Hourly Rate Approval': 'اعتماد سعر الساعة',
    'Reject': 'رفض',
    'You are Available': 'أنت متاحة',
    'Set Availability': 'تحديد التوفر',
    'Add Time Slot': 'إضافة وقت',
    'My Availability': 'توفري',
    'Visit Tracking': 'تتبع الزيارة',
    'Medical Records': 'السجل الطبي',
    'Nurse Profile': 'ملف الممرضة',
    'Start Time': 'وقت البداية',
    'End Time': 'وقت النهاية',
    'Review Report': 'مراجعة التقرير',
    'Change Password': 'تغيير كلمة المرور',
    'Account Verification': 'التحقق من الحساب',
    'Select Language': 'اختيار اللغة',
    'Help & Support': 'المساعدة والدعم',
    'Deactivate Account': 'تعطيل الحساب',
    'Assign Time Slot': 'تحديد وقت',
    'Appointment Confirmed': 'تم تأكيد الموعد',
    'Reject request': 'رفض الطلب',
    'Time Slot Details': 'تفاصيل الوقت',
    'Visit Dashboard': 'لوحة الزيارة',
    'Visit In Progress': 'الزيارة قيد التنفيذ',
    'Create Report': 'إنشاء تقرير',
    'Follow-up Date': 'تاريخ المتابعة',
    'Choose from gallery': 'اختيار من المعرض',
    'Take a photo': 'التقاط صورة',
    'Report Submitted': 'تم إرسال التقرير',
    'Visit Report': 'تقرير الزيارة',
    'Delete Payment Method': 'حذف طريقة الدفع',
    'Save changes': 'حفظ التغييرات',
    'Open file': 'فتح الملف',
    'Logout': 'تسجيل الخروج',
    'Cancel': 'إلغاء',
  };

  static Future<void> loadSettings(String userId) async {
    final prefs = await SharedPreferences.getInstance();
    isDarkMode.value = prefs.getBool(_darkModeKey) ?? isDarkMode.value;
    final localLanguage = prefs.getString(_languageKey);
    if (localLanguage != null) {
      isArabic.value = localLanguage == 'Arabic';
    }

    if (userId.trim().isEmpty) return;
    try {
      final response = await http.get(
        Uri.parse('${ApiService.baseUrl}/nurse/settings/$userId'),
      );
      if (response.statusCode < 200 || response.statusCode >= 300) return;
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      isDarkMode.value = data['darkMode'] == true;
      isArabic.value = data['language'] == 'Arabic';
      await persistSettings(userId);
    } catch (_) {}
  }

  static Future<void> persistSettings(String? userId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_darkModeKey, isDarkMode.value);
    await prefs.setString(_languageKey, isArabic.value ? 'Arabic' : 'English');

    final id = userId?.trim() ?? '';
    if (id.isEmpty) return;
    try {
      await http.put(
        Uri.parse('${ApiService.baseUrl}/nurse/settings/$id'),
        headers: const <String, String>{'Content-Type': 'application/json'},
        body: jsonEncode({
          'darkMode': isDarkMode.value,
          'language': isArabic.value ? 'Arabic' : 'English',
        }),
      );
    } catch (_) {}
  }

  static Widget reactive(Widget Function(BuildContext context) builder) {
    return ValueListenableBuilder<bool>(
      valueListenable: isDarkMode,
      builder: (context, _, child) {
        return ValueListenableBuilder<bool>(
          valueListenable: isArabic,
          builder: (context, _, child) {
            final baseTheme = isDarkMode.value
                ? CarelinkAppTheme.dark
                : CarelinkAppTheme.light;
            return Theme(
              data: baseTheme.copyWith(
                scaffoldBackgroundColor: background,
                cardColor: surface,
                colorScheme: baseTheme.colorScheme.copyWith(
                  primary: primary,
                  secondary: primaryDark,
                  surface: surface,
                  onSurface: text,
                  error: const Color(0xFFE53935),
                ),
                appBarTheme: baseTheme.appBarTheme.copyWith(
                  backgroundColor: background,
                  foregroundColor: text,
                  elevation: 0,
                  surfaceTintColor: Colors.transparent,
                  centerTitle: true,
                  iconTheme: IconThemeData(color: text, size: 22),
                  actionsIconTheme: IconThemeData(color: text, size: 22),
                ),
                cardTheme: CardThemeData(
                  color: surface,
                  elevation: 0,
                  margin: EdgeInsets.zero,
                  clipBehavior: Clip.antiAlias,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(cardRadius),
                    side: BorderSide(color: border),
                  ),
                ),
                dialogTheme: DialogThemeData(
                  backgroundColor: surface,
                  surfaceTintColor: Colors.transparent,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(22),
                  ),
                  titleTextStyle: TextStyle(
                    color: text,
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                  contentTextStyle: TextStyle(
                    color: muted,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                bottomSheetTheme: BottomSheetThemeData(
                  backgroundColor: surface,
                  surfaceTintColor: Colors.transparent,
                  modalBackgroundColor: surface,
                  shape: const RoundedRectangleBorder(
                    borderRadius: BorderRadius.vertical(
                      top: Radius.circular(24),
                    ),
                  ),
                  clipBehavior: Clip.antiAlias,
                ),
                snackBarTheme: SnackBarThemeData(
                  behavior: SnackBarBehavior.floating,
                  backgroundColor: primary,
                  contentTextStyle: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  actionTextColor: Colors.white,
                ),
                bottomNavigationBarTheme: baseTheme.bottomNavigationBarTheme
                    .copyWith(
                      backgroundColor: surface,
                      selectedItemColor: primaryDark,
                      unselectedItemColor: muted,
                      elevation: 0,
                      type: BottomNavigationBarType.fixed,
                    ),
                inputDecorationTheme: baseTheme.inputDecorationTheme.copyWith(
                  filled: true,
                  fillColor: softSurface,
                  labelStyle: TextStyle(color: muted),
                  hintStyle: TextStyle(color: muted),
                  prefixIconColor: primary,
                  suffixIconColor: muted,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 14,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(controlRadius),
                    borderSide: BorderSide(color: border),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(controlRadius),
                    borderSide: BorderSide(color: border),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(controlRadius),
                    borderSide: const BorderSide(
                      color: AppColors.primary,
                      width: 1.5,
                    ),
                  ),
                  errorBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(controlRadius),
                    borderSide: const BorderSide(color: Color(0xFFE53935)),
                  ),
                  focusedErrorBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(controlRadius),
                    borderSide: const BorderSide(
                      color: Color(0xFFE53935),
                      width: 1.5,
                    ),
                  ),
                ),
                filledButtonTheme: FilledButtonThemeData(
                  style: primaryButtonStyle,
                ),
                elevatedButtonTheme: ElevatedButtonThemeData(
                  style: elevatedPrimaryButtonStyle,
                ),
                outlinedButtonTheme: OutlinedButtonThemeData(
                  style: secondaryButtonStyle,
                ),
                textButtonTheme: TextButtonThemeData(
                  style: TextButton.styleFrom(
                    foregroundColor: primary,
                    textStyle: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 14,
                    ),
                  ),
                ),
                chipTheme: ChipThemeData(
                  backgroundColor: softSurface,
                  selectedColor: primary,
                  disabledColor: softSurface.withValues(alpha: 0.55),
                  secondarySelectedColor: primary,
                  labelStyle: TextStyle(
                    color: muted,
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  ),
                  secondaryLabelStyle: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 13,
                  ),
                  side: BorderSide(color: border),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 8,
                  ),
                ),
                dividerColor: border,
                iconTheme: IconThemeData(color: text, size: 22),
                listTileTheme: ListTileThemeData(
                  iconColor: primary,
                  textColor: text,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18),
                  ),
                ),
              ),
              child: Directionality(
                textDirection: direction,
                child: builder(context),
              ),
            );
          },
        );
      },
    );
  }
}

class NurseModeControls extends StatelessWidget {
  final VoidCallback? onChanged;
  final String? providerUserId;

  const NurseModeControls({super.key, this.onChanged, this.providerUserId});

  Future<void> _persistIfPossible() async {
    await NurseUi.persistSettings(providerUserId);
  }

  void _handleChanged() {
    onChanged?.call();
    _persistIfPossible();
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: NurseUi.isDarkMode,
      builder: (context, isDark, _) {
        return ValueListenableBuilder<bool>(
          valueListenable: NurseUi.isArabic,
          builder: (context, isArabic, _) {
            return Padding(
              padding: const EdgeInsetsDirectional.only(end: 8),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Tooltip(
                    message: NurseUi.label(
                      'Dark mode',
                      '\u0627\u0644\u0648\u0636\u0639 \u0627\u0644\u062f\u0627\u0643\u0646',
                    ),
                    child: Transform.scale(
                      scale: 0.78,
                      child: Switch(
                        value: isDark,
                        onChanged: (value) {
                          NurseUi.isDarkMode.value = value;
                          _handleChanged();
                        },
                        activeThumbColor: Colors.white,
                        activeTrackColor: AppColors.primaryDark,
                        inactiveThumbColor: const Color(0xFF1E293B),
                        inactiveTrackColor: const Color(0xFFE2E8F0),
                      ),
                    ),
                  ),
                  Tooltip(
                    message: NurseUi.label(
                      'Change language',
                      '\u062a\u063a\u064a\u064a\u0631 \u0627\u0644\u0644\u063a\u0629',
                    ),
                    child: IconButton(
                      visualDensity: VisualDensity.compact,
                      icon: Icon(
                        Icons.language_rounded,
                        color: isArabic
                            ? AppColors.primaryDark
                            : Colors.lightBlue,
                      ),
                      onPressed: () {
                        NurseUi.isArabic.value = !isArabic;
                        _handleChanged();
                      },
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}
