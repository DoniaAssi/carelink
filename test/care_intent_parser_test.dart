import 'package:flutter_test/flutter_test.dart';

import 'package:carelink/features/ai/care_intent_parser.dart';

void main() {
  group('parseCareIntent', () {
    test('maps misspelled children request to pediatrics when available', () {
      final result = parseCareIntent('childreen', const [
        'All',
        'Nursing',
        'Pediatrics',
      ]);

      expect(result.specialtyChip, 'Pediatrics');
    });

    test(
      'falls back to nursing for child care when pediatrics is unavailable',
      () {
        final result = parseCareIntent('childreen', const [
          'All',
          'Cardiology',
          'Nursing',
        ]);

        expect(result.specialtyChip, 'Nursing');
      },
    );

    test('keeps availability intent with typo-tolerant specialty matching', () {
      final result = parseCareIntent('I need a dentist today', const [
        'All',
        'Dentistry',
      ]);

      expect(result.specialtyChip, 'Dentistry');
      expect(result.restrictToAvailable, isTrue);
    });
  });
}
