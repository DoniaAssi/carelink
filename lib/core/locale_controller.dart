import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Persists app UI language ([en] ↔ [ar]) and drives [MaterialApp.locale] + RTL.
class LocaleController extends ChangeNotifier {
  static const _key = 'carelink_locale_code';

  Locale _locale = const Locale('en');

  Locale get locale => _locale;

  bool get isArabic => _locale.languageCode == 'ar';

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final code = prefs.getString(_key);
    if (code == 'ar') {
      _locale = const Locale('ar');
    } else if (code == 'en') {
      _locale = const Locale('en');
    } else {
      final device =
          WidgetsBinding.instance.platformDispatcher.locale.languageCode;
      _locale = device == 'ar' ? const Locale('ar') : const Locale('en');
    }
    notifyListeners();
  }

  Future<void> setLocale(Locale locale) async {
    final code = locale.languageCode;
    if (code != 'ar' && code != 'en') return;
    final next = Locale(code);
    if (_locale == next) return;
    _locale = next;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, code);
  }

  Future<void> toggle() async {
    await setLocale(_locale.languageCode == 'ar' ? const Locale('en') : const Locale('ar'));
  }
}

/// Global instance loaded in [main] before [runApp].
final localeController = LocaleController();
