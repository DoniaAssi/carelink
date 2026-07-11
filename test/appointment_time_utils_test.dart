import 'package:carelink/shared/utils/appointment_time_utils.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AppointmentTimeUtils.parseBackendDateTime', () {
    test('preserves MySQL local appointment times', () {
      final parsed = AppointmentTimeUtils.parseBackendDateTime(
        '2026-12-12 10:00:00',
      );

      expect(parsed, isNotNull);
      expect(parsed!.year, 2026);
      expect(parsed.month, 12);
      expect(parsed.day, 12);
      expect(parsed.hour, 10);
      expect(parsed.minute, 0);
      expect(parsed.isUtc, isFalse);
    });

    test('normalizes UTC appointment payloads to local time once', () {
      const raw = '2026-12-12T07:00:00.000Z';
      final expected = DateTime.parse(raw).toLocal();
      final parsed = AppointmentTimeUtils.parseBackendDateTime(raw);

      expect(parsed, expected);
      expect(parsed!.isUtc, isFalse);
    });

    test('returns null for empty or invalid values', () {
      expect(AppointmentTimeUtils.parseBackendDateTime(null), isNull);
      expect(AppointmentTimeUtils.parseBackendDateTime(''), isNull);
      expect(AppointmentTimeUtils.parseBackendDateTime('not a date'), isNull);
    });
  });
}
