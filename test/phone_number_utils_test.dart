import 'package:flutter_test/flutter_test.dart';

import 'package:carelink/core/phone_number_utils.dart';

void main() {
  group('Palestine phone normalization', () {
    test('normalizes local 059 and 056 formats', () {
      expect(
        PhoneNumberUtils.normalizePalestine('0599000000'),
        '+972599000000',
      );
      expect(
        PhoneNumberUtils.normalizePalestine('0569000000'),
        '+972569000000',
      );
    });

    test('normalizes international formats and removes trunk zero', () {
      expect(
        PhoneNumberUtils.normalizePalestine('+972599000000'),
        '+972599000000',
      );
      expect(
        PhoneNumberUtils.normalizePalestine('972599000000'),
        '+972599000000',
      );
      expect(
        PhoneNumberUtils.normalizePalestine('+9720599000000'),
        '+972599000000',
      );
    });

    test('rejects invalid Palestine mobile prefixes and lengths', () {
      expect(PhoneNumberUtils.normalizePalestine('0589000000'), isNull);
      expect(PhoneNumberUtils.normalizePalestine('059900000'), isNull);
    });
  });
}
