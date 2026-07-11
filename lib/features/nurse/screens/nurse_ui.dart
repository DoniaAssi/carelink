import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'package:carelink/core/app_colors.dart';
import 'package:carelink/core/carelink_app_theme.dart';
import 'package:carelink/core/carelink_palette.dart';
import 'package:carelink/core/locale_controller.dart';
import 'package:carelink/core/theme_controller.dart';
import 'package:carelink/shared/services/api_service.dart';
import 'package:carelink/shared/widgets/carelink_theme_toggle.dart';

class _NurseThemeModeNotifier extends ValueNotifier<bool> {
  _NurseThemeModeNotifier() : super(themeController.isDark) {
    themeController.addListener(_syncFromController);
  }

  void _syncFromController() {
    super.value = themeController.isDark;
  }

  @override
  bool get value => themeController.isDark;

  @override
  set value(bool next) {
    if (next == themeController.isDark) return;
    themeController.setTheme(next ? ThemeMode.dark : ThemeMode.light);
  }
}

class _NurseLocaleNotifier extends ValueNotifier<bool> {
  _NurseLocaleNotifier() : super(localeController.isArabic) {
    localeController.addListener(_syncFromController);
  }

  void _syncFromController() {
    super.value = localeController.isArabic;
  }

  @override
  bool get value => localeController.isArabic;

  @override
  set value(bool next) {
    if (next == localeController.isArabic) return;
    localeController.setLocale(Locale(next ? 'ar' : 'en'));
  }
}

class NurseUi {
  static final ValueNotifier<bool> isDarkMode = _NurseThemeModeNotifier();
  static final ValueNotifier<bool> isArabic = _NurseLocaleNotifier();
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

  static TextStyle textStyle({
    required double fontSize,
    FontWeight fontWeight = FontWeight.w700,
    Color? color,
    double? height,
  }) {
    return GoogleFonts.inter(
      color: color ?? text,
      fontSize: fontSize,
      fontWeight: fontWeight,
      height: height,
      letterSpacing: 0,
    );
  }

  static TextStyle get pageTitleStyle =>
      textStyle(fontSize: 20, fontWeight: FontWeight.w900);
  static TextStyle get heroTitleStyle =>
      textStyle(fontSize: 24, fontWeight: FontWeight.w900);
  static TextStyle get sectionTitleStyle =>
      textStyle(fontSize: 15, fontWeight: FontWeight.w900);
  static TextStyle get bodyStyle =>
      textStyle(fontSize: 14, fontWeight: FontWeight.w700);
  static TextStyle get labelStyle =>
      textStyle(fontSize: 12, fontWeight: FontWeight.w700, color: muted);
  static TextStyle get captionStyle =>
      textStyle(fontSize: 12, fontWeight: FontWeight.w700, color: muted);

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

  static List<Widget> headerActions({
    String? providerUserId,
    List<Widget> before = const <Widget>[],
    VoidCallback? onChanged,
  }) {
    return [
      ...before,
      NurseModeControls(providerUserId: providerUserId, onChanged: onChanged),
    ];
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
    textStyle: GoogleFonts.inter(fontWeight: FontWeight.w800, fontSize: 14),
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
    textStyle: GoogleFonts.inter(fontWeight: FontWeight.w800, fontSize: 14),
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
    textStyle: GoogleFonts.inter(fontWeight: FontWeight.w800, fontSize: 14),
  );

  static ButtonStyle get dangerButtonStyle => FilledButton.styleFrom(
    backgroundColor: const Color(0xFFE53935),
    foregroundColor: Colors.white,
    minimumSize: const Size.fromHeight(buttonHeight),
    padding: const EdgeInsets.symmetric(horizontal: 16),
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(buttonRadius),
    ),
    textStyle: GoogleFonts.inter(fontWeight: FontWeight.w800, fontSize: 14),
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

  static String statusLabel(String raw) {
    final normalized = raw.trim().toLowerCase().replaceAll('_', ' ');
    switch (normalized) {
      case 'new':
      case 'pending':
      case 'pending provider approval':
        return t('Pending');
      case 'accepted':
      case 'assigned':
      case 'scheduled':
        return t('Accepted');
      case 'approved':
        return t('Approved');
      case 'confirmed':
        return t('Confirmed');
      case 'upcoming':
        return t('Upcoming');
      case 'in progress':
      case 'waiting report':
        return t('In Progress');
      case 'completed':
        return t('Completed');
      case 'cancelled':
      case 'canceled':
        return t('Cancelled');
      case 'rejected':
        return t('Rejected');
      case 'pending reschedule':
        return t('Pending Reschedule');
      case 'paid':
        return t('Paid');
      case 'pending payment':
      case 'payment pending':
        return t('Pending Payment');
      case 'ready':
        return t('Ready');
      case 'inactive':
        return t('Inactive');
      default:
        if (raw.trim().isEmpty) return t('Pending');
        return t(_titleCase(raw.trim().replaceAll('_', ' ')));
    }
  }

  static String serviceLabel(String raw) {
    final value = raw.trim();
    if (value.isEmpty) return t('Home Nursing Care');
    final normalized = value.toLowerCase().replaceAll('_', ' ');
    switch (normalized) {
      case 'home nursing care':
      case 'home nursing':
      case 'home visit':
        return t('Home Nursing Care');
      case 'consultation':
        return t('Consultation');
      case 'medication support':
      case 'medication':
        return t('Medication Support');
      case 'wound care':
        return t('Wound Care');
      case 'elderly care':
        return t('Elderly Care');
      default:
        return t(value);
    }
  }

  static String notSet() => t('Not set');

  static String ageLabel(int age) {
    if (age <= 0) return t('Age not set');
    return isArabic.value ? '$age ${t('years')}' : '$age years';
  }

  static String currency(num amount, {String code = 'ILS'}) {
    final value = amount % 1 == 0
        ? amount.toStringAsFixed(0)
        : amount.toStringAsFixed(2);
    return isArabic.value ? '$value $code' : '$value $code';
  }

  static String formatDate(DateTime date) {
    final months = isArabic.value
        ? const [
            'يناير',
            'فبراير',
            'مارس',
            'أبريل',
            'مايو',
            'يونيو',
            'يوليو',
            'أغسطس',
            'سبتمبر',
            'أكتوبر',
            'نوفمبر',
            'ديسمبر',
          ]
        : const [
            'Jan',
            'Feb',
            'Mar',
            'Apr',
            'May',
            'Jun',
            'Jul',
            'Aug',
            'Sep',
            'Oct',
            'Nov',
            'Dec',
          ];
    return isArabic.value
        ? '${date.day} ${months[date.month - 1]} ${date.year}'
        : '${months[date.month - 1]} ${date.day}, ${date.year}';
  }

  static String formatTime(DateTime date) {
    final minute = date.minute.toString().padLeft(2, '0');
    if (isArabic.value) return '${date.hour}:$minute';
    final hour = date.hour % 12 == 0 ? 12 : date.hour % 12;
    return '$hour:$minute ${date.hour >= 12 ? 'PM' : 'AM'}';
  }

  static String _titleCase(String text) {
    return text
        .split(RegExp(r'\s+'))
        .where((part) => part.isNotEmpty)
        .map((part) => part[0].toUpperCase() + part.substring(1).toLowerCase())
        .join(' ');
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
    'Upcoming': 'القادمة',
    'In Progress': 'قيد التنفيذ',
    'Completed': 'مكتملة',
    'Cancelled': 'ملغاة',
    'Pending': 'قيد الانتظار',
    'Accepted': 'مقبول',
    'Approved': 'موافق عليه',
    'Confirmed': 'مؤكد',
    'Rejected': 'مرفوض',
    'Pending Reschedule': 'بانتظار إعادة الجدولة',
    'Paid': 'مدفوع',
    'Pending Payment': 'بانتظار الدفع',
    'Ready': 'جاهز',
    'Inactive': 'غير نشط',
    'Today': 'اليوم',
    'appointment': 'موعد',
    'appointments': 'مواعيد',
    'No appointments for this day': 'لا توجد مواعيد لهذا اليوم',
    'Home Nursing Care': 'رعاية تمريضية منزلية',
    'Home nursing': 'رعاية تمريضية منزلية',
    'Consultation': 'استشارة',
    'Medication Support': 'دعم الأدوية',
    'Wound Care': 'العناية بالجروح',
    'Elderly Care': 'رعاية كبار السن',
    'Not set': 'غير محدد',
    'Age not set': 'العمر غير محدد',
    'years': 'سنة',
    'Location not set': 'الموقع غير محدد',
    'Not available': 'غير متاح',
    'Specialization': 'التخصص',
    'Approved Hourly Rate': 'سعر الساعة المعتمد',
    'Care session is currently in progress': 'جلسة الرعاية قيد التنفيذ حاليًا',
    'Your visit report has been submitted.': 'تم إرسال تقرير الزيارة.',
    'Working Days': 'أيام العمل',
    'Select days you are available': 'اختاري الأيام التي تكونين متاحة فيها',
    'Working Hours': 'ساعات العمل',
    'Set your daily available time slots': 'حددي أوقات التوفر اليومية',
    'Patients can book your available slots':
        'يمكن للمرضى حجز الأوقات المتاحة لديك',
    'This Week': 'هذا الأسبوع',
    'General Condition': 'الحالة العامة',
    'Requests': 'الطلبات',
    'Visits': 'الزيارات',
    'System': 'النظام',
    'Earnings & Payments': 'الأرباح والمدفوعات',
    'Quick Actions': 'إجراءات سريعة',
    'Summary by Service': 'ملخص حسب الخدمة',
    'Overall Summary': 'الملخص العام',
    'Request Details': 'تفاصيل الطلب',
    'Service Details': 'تفاصيل الخدمة',
    'Service': 'الخدمة',
    'Service Type': 'نوع الخدمة',
    'Appointment Type': 'نوع الموعد',
    'Address': 'العنوان',
    'Current Case': 'الحالة الحالية',
    'Reason': 'السبب',
    'GPS Location': 'موقع GPS',
    'No notes added': 'لا توجد ملاحظات',
    'No location note': 'لا توجد ملاحظة للموقع',
    'Visit Time': 'وقت الزيارة',
    'Date & Time': 'التاريخ والوقت',
    'Location': 'الموقع',
    'Notes': 'ملاحظات',
    'Location Note': 'ملاحظة الموقع',
    'Estimated Fee': 'الرسوم التقديرية',
    'Medical Information': 'المعلومات الطبية',
    'Cancelled request is read-only': 'الطلب الملغى للقراءة فقط',
    'The visit is completed. The patient can now rate the nurse and write feedback.':
        'اكتملت الزيارة. يمكن للمريض الآن تقييم الممرضة وكتابة ملاحظاته.',
    'No new service requests': 'لا توجد طلبات خدمة جديدة',
    'No assigned services yet': 'لا توجد خدمات مخصصة بعد',
    'Accepted requests will move to My Assigned Services.':
        'ستنتقل الطلبات المقبولة إلى خدماتي المخصصة.',
    'Accepted visits, active visits, and waiting reports appear here.':
        'تظهر هنا الزيارات المقبولة والنشطة والتقارير المنتظرة.',
    'Patient': 'المريض',
    'Home visit': 'زيارة منزلية',
    'Accept Confirmation': 'تأكيد القبول',
    'Request Accepted!': 'تم قبول الطلب!',
    'You have successfully accepted this request.': 'تم قبول هذا الطلب بنجاح.',
    'Add to Schedule': 'إضافة إلى الجدول',
    'Contact Patient': 'التواصل مع المريض',
    'Go to Visit': 'الذهاب إلى الزيارة',
    'Select Available Time': 'اختيار وقت متاح',
    'Duration': 'المدة',
    'Notes (Optional)': 'ملاحظات (اختياري)',
    'Add a note for the patient': 'أضيفي ملاحظة للمريض',
    'Confirm Appointment': 'تأكيد الموعد',
    'Appointment Confirmed!': 'تم تأكيد الموعد!',
    'The appointment has been scheduled successfully.':
        'تمت جدولة الموعد بنجاح.',
    'View Location': 'عرض الموقع',
    'Start Visit': 'بدء الزيارة',
    'Date': 'التاريخ',
    'Time': 'الوقت',
    'minutes': 'دقيقة',
    'Busy': 'مشغول',
    'Waiting Report': 'بانتظار التقرير',
    'Ratings': 'التقييمات',
    'All Time': 'كل الوقت',
    'Last Month': 'الشهر الماضي',
    'Last Week': 'الأسبوع الماضي',
    'Nursing service': 'خدمة تمريضية',
    'New Requests': 'طلبات جديدة',
    'Visit Status': 'حالة الزيارة',
    'New': 'جديد',
    'No notifications available': 'لا توجد إشعارات',
    'Just now': 'الآن',
    'min ago': 'دقيقة مضت',
    'hour ago': 'ساعة مضت',
    'hours ago': 'ساعات مضت',
    'day ago': 'يوم مضى',
    'days ago': 'أيام مضت',
    'New Service Request': 'طلب خدمة جديد',
    'You have a new home nursing request.':
        'لديك طلب رعاية تمريضية منزلية جديد.',
    'Arrival Verified': 'تم تأكيد الوصول',
    'You have arrived at the patient location.': 'وصلت إلى موقع المريض.',
    'Visit In Progress': 'الزيارة قيد التنفيذ',
    'The visit with the patient has started.': 'بدأت الزيارة مع المريض.',
    'Service Completed': 'اكتملت الخدمة',
    'You have completed the visit successfully.': 'أكملت الزيارة بنجاح.',
    'Report Submitted': 'تم إرسال التقرير',
    'New Message from Patient': 'رسالة جديدة من المريض',
    'You have a new message from the patient.': 'لديك رسالة جديدة من المريض.',
    'Upcoming Visit Reminder': 'تذكير بزيارة قادمة',
    'You have a visit scheduled soon.': 'لديك زيارة مجدولة قريباً.',
    'System Notification': 'إشعار النظام',
    'You have a new system update.': 'لديك تحديث جديد من النظام.',
    'Unable to load nurse profile': 'تعذر تحميل ملف الممرضة',
    'Edit profile': 'تعديل الملف',
    'Tap to change photo': 'اضغطي لتغيير الصورة',
    'Location not provided': 'الموقع غير متوفر',
    'Not provided': 'غير متوفر',
    'Full name': 'الاسم الكامل',
    'Email': 'البريد الإلكتروني',
    'Phone': 'الهاتف',
    'Approval status': 'حالة الموافقة',
    'Profile details': 'تفاصيل الملف',
    'Years of experience': 'سنوات الخبرة',
    'Location / Service area': 'الموقع / منطقة الخدمة',
    'Hourly rate': 'سعر الساعة',
    'Waiting for admin': 'بانتظار الإدارة',
    'Biography': 'نبذة',
    'No biography provided yet.': 'لا توجد نبذة بعد.',
    'Professional information': 'المعلومات المهنية',
    'Pending approval': 'بانتظار الموافقة',
    'Certificates & documents': 'الشهادات والمستندات',
    'Nursing License': 'رخصة التمريض',
    'Medical Certificate': 'الشهادة الطبية',
    'ID Card': 'بطاقة الهوية',
    'CV File': 'ملف السيرة الذاتية',
    'PDF / Image': 'PDF / صورة',
    'Not uploaded': 'لم يتم الرفع',
    'Verified certificates': 'الشهادات المعتمدة',
    'Account & Settings': 'الحساب والإعدادات',
    'Details not set': 'التفاصيل غير محددة',
    'Condition': 'الحالة',
    'Care Plan': 'خطة الرعاية',
    'Care Type': 'نوع الرعاية',
    'Next Visit': 'الزيارة التالية',
    'GPS': 'GPS',
    'Visit Date': 'تاريخ الزيارة',
    'Follow-up & Notes': 'المتابعة والملاحظات',
    'Report Details': 'تفاصيل التقرير',
    'Assessment & Care': 'التقييم والرعاية',
    'Review & Submit': 'المراجعة والإرسال',
    'Patient & Visit Information': 'معلومات المريض والزيارة',
    'Request ID': 'رقم الطلب',
    'Select Date': 'اختيار التاريخ',
    'Select Day': 'اختيار اليوم',
    'Save Slot': 'حفظ الوقت',
    'Add a note...': 'أضيفي ملاحظة...',
    'Add your available time so patients can see it.':
        'أضيفي وقتك المتاح ليظهر للمرضى.',
    'This time will be shown as available for patients, and you can edit or delete it anytime.':
        'سيتم عرض هذا الوقت كمتاح للمرضى، ويمكنك تعديله أو حذفه في أي وقت.',
    'Scheduled Time': 'الوقت المجدول',
    'Actual Start Time': 'وقت البدء الفعلي',
    'Known Condition': 'الحالة المعروفة',
    'Allergies': 'الحساسيات',
    'Patient Information': 'معلومات المريض',
    'Nurse Information': 'معلومات الممرضة',
    'Submitted By': 'تم الإرسال بواسطة',
    'Nurse ID': 'رقم الممرضة',
    'Visit Details': 'تفاصيل الزيارة',
    'Report Status': 'حالة التقرير',
    'Submitted': 'تم الإرسال',
    'Medical Report': 'التقرير الطبي',
    'Submitted Date': 'تاريخ الإرسال',
    'Nursing visit': 'زيارة تمريضية',
    'Select date': 'اختر التاريخ',
    'Follow-up Date (Optional)': 'تاريخ المتابعة (اختياري)',
    'Follow-up Notes': 'ملاحظات المتابعة',
    'Additional Notes (Optional)': 'ملاحظات إضافية (اختياري)',
    'e.g. Recheck after 5 days...': 'مثال: إعادة الفحص بعد 5 أيام...',
    'Any additional notes or recommendations...':
        'أي ملاحظات أو توصيات إضافية...',
    'Search reports...': 'ابحث في التقارير...',
    'Draft': 'مسودة',
    'No reports available': 'لا توجد تقارير متاحة',
    'Visit Information': 'معلومات الزيارة',
    'Visit Type': 'نوع الزيارة',
    'Started At': 'بدأت في',
    'Completed At': 'اكتملت في',
    'Summary': 'الملخص',
    'Care Provided': 'الرعاية المقدمة',
    'Medication\nAdministration': 'إعطاء\nالأدوية',
    'Vital Signs\nMonitoring': 'مراقبة\nالعلامات الحيوية',
    'Personal Care': 'العناية الشخصية',
    'Patient\nEducation': 'تثقيف\nالمريض',
    'IV Support': 'دعم وريدي',
    'Vital Signs': 'العلامات الحيوية',
    'Blood Pressure': 'ضغط الدم',
    'Heart Rate': 'معدل النبض',
    'Temperature': 'درجة الحرارة',
    'Oxygen Saturation': 'تشبع الأكسجين',
    'View Full Report': 'عرض التقرير الكامل',
    'Full Report': 'التقرير الكامل',
    'Medications': 'الأدوية',
    'Observations': 'الملاحظات',
    'Recommendations': 'التوصيات',
    'Not recorded': 'غير مسجل',
    'Nursing Care': 'رعاية تمريضية',
    'Location not recorded': 'الموقع غير مسجل',
    'hour': 'ساعة',
    'hours': 'ساعات',
    'Cancel': 'إلغاء',
    'Next: Review Report': 'التالي: مراجعة التقرير',
    'Payment Method': 'طريقة الدفع',
    'Accept Rate': 'قبول السعر',
    'Reject Rate': 'رفض السعر',
    'Accept your admin-set hourly rate before requesting payouts.':
        'اقبلي السعر المحدد من الأدمن قبل طلب الدفعات.',
    'Hourly rate set': 'تم تحديد سعر الساعة',
    'Hourly rate approval': 'اعتماد سعر الساعة',
    'Please accept the admin hourly rate before starting work.':
        'يرجى قبول سعر الساعة المحدد من الإدارة قبل بدء العمل.',
    'Admin set your hourly rate. Please accept it before starting work.':
        'حددت الإدارة سعر الساعة الخاص بك. يرجى قبوله قبل بدء العمل.',
    'Tap to accept or reject this hourly rate.':
        'اضغطي لقبول أو رفض سعر الساعة هذا.',
    'New booking request': 'طلب حجز جديد',
    'You have a new service request.': 'لديك طلب خدمة جديد.',
    'You have a new system alert.': 'لديك تنبيه جديد من النظام.',
    'Alert': 'تنبيه',
    'Message Alert': 'تنبيه رسالة',
    'You have a new patient message.': 'لديك رسالة جديدة من المريض.',
    'Completed Visit': 'زيارة مكتملة',
    'The visit has been completed.': 'تم إكمال الزيارة.',
    'Visit is currently in progress.': 'الزيارة قيد التنفيذ حالياً.',
    'You have arrived at patient location.': 'وصلت إلى موقع المريض.',
    'Hourly rate accepted. You can add slots and accept patients now.':
        'تم قبول سعر الساعة. يمكنك الآن إضافة الأوقات وقبول المرضى.',
    'Hourly rate rejected. Availability and patient requests stay locked.':
        'تم رفض سعر الساعة. سيبقى التوفر وطلبات المرضى مقفلة.',
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
    'Availability Status': 'حالة التوفر',
    'Set Availability': 'تحديد التوفر',
    'Add Time Slot': 'إضافة وقت',
    'Add time period': 'إضافة فترة زمنية',
    'Save Availability': 'حفظ التوفر',
    'Nursing': 'تمريض',
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
    'Create Report': 'إنشاء تقرير',
    'Follow-up Date': 'تاريخ المتابعة',
    'Choose from gallery': 'اختيار من المعرض',
    'Take a photo': 'التقاط صورة',
    'Visit Report': 'تقرير الزيارة',
    'Delete Payment Method': 'حذف طريقة الدفع',
    'Save changes': 'حفظ التغييرات',
    'Open file': 'فتح الملف',
    'Logout': 'تسجيل الخروج',
    // Earnings & payouts
    'Request Payout': 'طلب دفعة',
    'Payout request': 'طلب دفعة',
    'Created': 'تم الإنشاء',
    'Earnings History': 'سجل الأرباح',
    'My Services (Sessions)': 'خدماتي (الجلسات)',
    'Review completed and pending sessions': 'راجعي الجلسات المكتملة والمعلقة',
    'Grouped by service and admin pricing rules':
        'مجمعة حسب الخدمة وتسعير الأدمن',
    'No sessions found': 'لا توجد جلسات',
    'No earnings summary yet': 'لا يوجد ملخص أرباح بعد',
    'Available Balance (Pending)': 'الرصيد المتاح (قيد الانتظار)',
    'Points': 'نقاط',
    'Point': 'نقطة',
    'Total Sessions': 'إجمالي الجلسات',
    'Total Points': 'إجمالي النقاط',
    'Total Earnings': 'إجمالي الأرباح',
    'Total Earnings (To Withdraw)': 'إجمالي الأرباح (للسحب)',
    'Total': 'الإجمالي',
    'Admin Hourly Rate': 'سعر الساعة من الأدمن',
    'per hour': 'لكل ساعة',
    'Per Hour': 'لكل ساعة',
    'Waiting for admin rate': 'بانتظار تحديد السعر من الأدمن',
    'Your account is approved. Accept the hourly rate before accepting requests or starting sessions.':
        'تمت الموافقة على حسابك. اقبلي سعر الساعة قبل قبول الطلبات أو بدء الجلسات.',
    'Admin approval is required before accepting requests or starting sessions.':
        'موافقة الأدمن مطلوبة قبل قبول الطلبات أو بدء الجلسات.',
    'Accept your admin-set hourly rate to unlock earnings, sessions, payouts, and nurse services.':
        'اقبلي سعر الساعة المحدد من الأدمن لفتح الأرباح والجلسات والدفعات وخدمات التمريض.',
    'Hourly rate accepted. You can start working now.':
        'تم قبول سعر الساعة. يمكنك بدء العمل الآن.',
    'Hourly rate rejected. Your account remains inactive for work.':
        'تم رفض سعر الساعة. سيبقى حسابك غير مفعّل للعمل.',
    'Your request will be reviewed by admin. You will be notified once the payment is approved.':
        'ستتم مراجعة طلبك من الأدمن، وسيتم إشعارك عند اعتماد الدفعة.',
    'Submitting...': 'جارٍ الإرسال...',
    'Submit Request': 'إرسال الطلب',
    'Request Submitted!': 'تم إرسال الطلب!',
    'Your payout request of': 'طلب الدفعة بقيمة',
    'has been submitted successfully.': 'تم إرساله بنجاح.',
    'Request Status': 'حالة الطلب',
    'Pending Approval': 'بانتظار الموافقة',
    'View My Requests': 'عرض طلباتي',
    'My Payout Requests': 'طلبات الدفع الخاصة بي',
    'No payout requests yet': 'لا توجد طلبات دفع بعد',
    'View Payment Received': 'عرض الدفعة المستلمة',
    'Payment Received': 'تم استلام الدفعة',
    'Payment Received!': 'تم استلام الدفعة!',
    'has been transferred to you.': 'تم تحويلها إليك.',
    'Transaction ID': 'رقم العملية',
    'Amount': 'المبلغ',
    'Status': 'الحالة',
    'Not configured': 'غير محددة',
    'Payment method not configured': 'طريقة الدفع غير محددة',
    'Download Receipt': 'تحميل الإيصال',
    'reviews': 'تقييمات',
    'Request': 'طلب',
    'Rate / Hour': 'السعر / الساعة',
    'Duration not set': 'المدة غير محددة',
    'min': 'دقيقة',
    'Hours': 'ساعات',
    'ILS': 'شيكل',
    'PM': 'م',
    'AM': 'ص',
    // Common nurse specializations shown on earnings cards
    'Injections': 'الحقن',
    'Injection': 'حقنة',
    'Pediatric Care': 'رعاية الأطفال',
    'Bank Transfer': 'تحويل بنكي',
    'Cash': 'نقدًا',
  };

  static Future<void> loadSettings(String userId) async {
    final prefs = await SharedPreferences.getInstance();
    final localDark = prefs.getBool(_darkModeKey);
    if (localDark != null) isDarkMode.value = localDark;
    final localLanguage = prefs.getString(_languageKey);
    if (localLanguage != null) isArabic.value = localLanguage == 'Arabic';

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
    return ListenableBuilder(
      listenable: Listenable.merge([themeController, localeController]),
      builder: (context, child) {
        final baseTheme = isDarkMode.value
            ? CarelinkAppTheme.dark
            : CarelinkAppTheme.light;
        final nurseTextTheme = GoogleFonts.interTextTheme(baseTheme.textTheme)
            .copyWith(
              displayLarge: textStyle(
                fontSize: 24,
                fontWeight: FontWeight.w900,
              ),
              displayMedium: textStyle(
                fontSize: 22,
                fontWeight: FontWeight.w900,
              ),
              displaySmall: textStyle(
                fontSize: 20,
                fontWeight: FontWeight.w900,
              ),
              headlineLarge: heroTitleStyle,
              headlineMedium: pageTitleStyle,
              headlineSmall: sectionTitleStyle,
              titleLarge: pageTitleStyle,
              titleMedium: sectionTitleStyle,
              titleSmall: textStyle(fontSize: 14, fontWeight: FontWeight.w800),
              bodyLarge: bodyStyle,
              bodyMedium: bodyStyle,
              bodySmall: captionStyle,
              labelLarge: textStyle(fontSize: 14, fontWeight: FontWeight.w800),
              labelMedium: labelStyle,
              labelSmall: textStyle(fontSize: 11, fontWeight: FontWeight.w700),
            );
        return Theme(
          data: baseTheme.copyWith(
            textTheme: nurseTextTheme,
            primaryTextTheme: GoogleFonts.interTextTheme(
              baseTheme.primaryTextTheme,
            ),
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
              titleTextStyle: pageTitleStyle,
              toolbarTextStyle: bodyStyle,
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
              titleTextStyle: sectionTitleStyle.copyWith(fontSize: 18),
              contentTextStyle: bodyStyle.copyWith(color: muted),
            ),
            bottomSheetTheme: BottomSheetThemeData(
              backgroundColor: surface,
              surfaceTintColor: Colors.transparent,
              modalBackgroundColor: surface,
              shape: const RoundedRectangleBorder(
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              clipBehavior: Clip.antiAlias,
            ),
            snackBarTheme: SnackBarThemeData(
              behavior: SnackBarBehavior.floating,
              backgroundColor: primary,
              contentTextStyle: GoogleFonts.inter(
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
              labelStyle: labelStyle,
              hintStyle: labelStyle,
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
            filledButtonTheme: FilledButtonThemeData(style: primaryButtonStyle),
            elevatedButtonTheme: ElevatedButtonThemeData(
              style: elevatedPrimaryButtonStyle,
            ),
            outlinedButtonTheme: OutlinedButtonThemeData(
              style: secondaryButtonStyle,
            ),
            textButtonTheme: TextButtonThemeData(
              style: TextButton.styleFrom(
                foregroundColor: primary,
                textStyle: GoogleFonts.inter(
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
              labelStyle: labelStyle.copyWith(fontSize: 13),
              secondaryLabelStyle: GoogleFonts.inter(
                color: Colors.white,
                fontWeight: FontWeight.w800,
                fontSize: 13,
              ),
              side: BorderSide(color: border),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            ),
            dividerColor: border,
            iconTheme: IconThemeData(color: text, size: 22),
            listTileTheme: ListTileThemeData(
              iconColor: primary,
              textColor: text,
              titleTextStyle: bodyStyle,
              subtitleTextStyle: labelStyle,
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
  }
}

class NurseModeControls extends StatefulWidget {
  final VoidCallback? onChanged;
  final String? providerUserId;

  const NurseModeControls({super.key, this.onChanged, this.providerUserId});

  @override
  State<NurseModeControls> createState() => _NurseModeControlsState();
}

class _NurseModeControlsState extends State<NurseModeControls> {
  late bool _lastDark;
  late bool _lastArabic;

  @override
  void initState() {
    super.initState();
    _lastDark = themeController.isDark;
    _lastArabic = localeController.isArabic;
    themeController.addListener(_handleChanged);
    localeController.addListener(_handleChanged);
  }

  @override
  void dispose() {
    themeController.removeListener(_handleChanged);
    localeController.removeListener(_handleChanged);
    super.dispose();
  }

  void _handleChanged() {
    final changed =
        _lastDark != themeController.isDark ||
        _lastArabic != localeController.isArabic;
    if (!changed) return;
    _lastDark = themeController.isDark;
    _lastArabic = localeController.isArabic;
    widget.onChanged?.call();
    NurseUi.persistSettings(widget.providerUserId);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsetsDirectional.only(end: 8),
      child: PatientHeaderActions(color: AppColors.primary),
    );
  }
}
