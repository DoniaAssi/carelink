class PhoneNumberUtils {
  static final RegExp _palestineMobile = RegExp(r'^(?:59|56)\d{7}$');

  static String digitsOnly(Object? value) {
    return (value?.toString() ?? '').replaceAll(RegExp(r'\D'), '');
  }

  static String? normalizePalestine(String input) {
    var digits = digitsOnly(input);
    if (digits.startsWith('00972')) {
      digits = digits.substring(2);
    }
    if (digits.startsWith('972')) {
      digits = digits.substring(3);
    }
    if (digits.startsWith('0')) {
      digits = digits.substring(1);
    }
    if (!_palestineMobile.hasMatch(digits)) return null;
    return '+972$digits';
  }

  static String? normalizeForCountry({
    required String input,
    required String countryCode,
    required String dialCode,
  }) {
    if (countryCode == 'PS') return normalizePalestine(input);

    var digits = digitsOnly(input);
    final dialDigits = digitsOnly(dialCode);
    if (digits.startsWith(dialDigits)) {
      digits = digits.substring(dialDigits.length);
    }
    if (digits.startsWith('0')) {
      digits = digits.substring(1);
    }
    if (digits.length < 7 || digits.length > 12) return null;
    return '+$dialDigits$digits';
  }
}
