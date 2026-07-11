// LIVE end-to-end verification: real BookingScreen + real HTTP against the
// locally running backend (http://localhost:3000). Run manually with:
//   flutter test test/booking_screen_today_live_e2e_test.dart
// Requires: backend running and provider `ai-test-doc-cardio` with
// availability on today's weekday.
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart' as intl;

import 'package:carelink/features/patient/screens/booking_screen.dart';
import 'package:carelink/features/ai/provider_booking_eligibility.dart';
import 'package:carelink/shared/models/booking_request_model.dart';
import 'package:carelink/shared/models/provider_model.dart';
import 'package:carelink/shared/services/api_service.dart';

class _RealHttpOverrides extends HttpOverrides {}

void main() {
  setUpAll(() async {
    HttpOverrides.global = _RealHttpOverrides();
    await initializeDateFormatting('en');
    // Let google_fonts fetch over the (real) network and give it a real
    // directory to cache into by mocking path_provider.
    final fontsDir = Directory.systemTemp.createTempSync('carelink_fonts');
    TestWidgetsFlutterBinding.ensureInitialized();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/path_provider'),
      (call) async => fontsDir.path,
    );
  });

  testWidgets('LIVE: today appears first when provider has future slots today', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    debugPrint('--- LIVE E2E | local now: $now');

    // 1) Raw API + parsed model (real ApiService + real ProviderModel).
    late ProviderModel provider;
    await tester.runAsync(() async {
      final json = await ApiService().getProviderById(
        'ai-test-doc-cardio',
        realAvailability: true,
      );
      provider = ProviderModel.fromJson(json);
    });
    final todayKey =
        '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';
    final parsedToday = provider.availableSlots
        .where((s) => s.date == todayKey)
        .map((s) => s.startTime)
        .toList();
    debugPrint('--- Flutter-parsed availableSlots total: '
        '${provider.availableSlots.length}');
    debugPrint("--- Flutter-parsed slots for TODAY ($todayKey): $parsedToday");
    expect(parsedToday, isNotEmpty,
        reason: 'provider must still have future slots today for this test');

    await tester.runAsync(() async {
      final blocked =
          await ApiService().getProviderBlockedSlots('ai-test-doc-cardio');
      debugPrint('--- blocked slots: $blocked');
    });
    // ignore: avoid_dynamic_calls
    debugPrint('--- canBook: '
        // ignore: invalid_use_of_visible_for_testing_member
        '${ProviderBookingEligibility.canBook(provider)}');
    debugPrint('--- isActive=${provider.isActive} '
        'isProfileComplete=${provider.isProfileComplete} '
        'isAvailable=${provider.isAvailable} role=${provider.role}');

    // 2) Pump the real BookingScreen (it re-fetches over real HTTP itself).
    final request = BookingRequestModel(
      patientId: 'live-e2e-patient',
      providerId: 'ai-test-doc-cardio',
      providerName: 'Dr. Ahmed Cardio',
      providerRole: 'doctor',
      specialization: 'Cardiology',
      serviceType: 'Consultation',
      appointmentDate: '',
      appointmentTime: '',
      visitLatitude: 0,
      visitLongitude: 0,
      visitAddress: '',
      locationNote: '',
      patientReason: '',
      symptoms: '',
      isUrgent: false,
      additionalNotes: '',
      price: 100,
      paymentMethod: '',
      paymentStatus: '',
      bookingStatus: '',
    );

    // Pump inside runAsync so the screen's real HTTP calls in initState
    // execute on the real event loop.
    await tester.runAsync(() async {
      await tester.pumpWidget(
        MaterialApp(home: BookingScreen(request: request)),
      );
      await Future<void>.delayed(const Duration(seconds: 3));
    });
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 250));
    }

    // 3) Rendered horizontal date list.
    final dateCards = find.byWidgetPredicate(
      (w) => w is AnimatedScale && w.child is AnimatedContainer,
    );
    final rendered = <String>[];
    for (final e in dateCards.evaluate()) {
      final texts = find
          .descendant(of: find.byWidget(e.widget), matching: find.byType(Text))
          .evaluate()
          .map((t) => (t.widget as Text).data)
          .whereType<String>()
          .toList();
      final scale = (e.widget as AnimatedScale).scale;
      final container = (e.widget as AnimatedScale).child as AnimatedContainer;
      final deco = container.decoration as BoxDecoration?;
      rendered.add(
          '${texts.join(" ")} (scale=$scale color=${deco?.color})${scale > 1 ? "  <== SELECTED" : ""}');
    }
    debugPrint('--- Rendered date list:');
    for (final r in rendered) {
      debugPrint('    $r');
    }

    // Today's card must be rendered and be the selected one (scale 1.05).
    final todayLabel = '${today.day}';
    final monthLabel = intl.DateFormat.MMM('en').format(today);
    final selected = rendered.where((r) => r.contains('<== SELECTED')).toList();
    expect(selected, hasLength(1));
    expect(selected.single, contains(' $todayLabel '),
        reason: 'today must be the selected (first available) date');
    expect(selected.single, contains(monthLabel));

    // 4) Rendered time chips = only today's remaining future times.
    final pastChip = find.text('09:00 AM');
    final expected12h = parsedToday.map((t) {
      final h = int.parse(t.split(':')[0]);
      final period = h >= 12 ? 'PM' : 'AM';
      final h12 = h % 12 == 0 ? 12 : h % 12;
      return '${h12.toString().padLeft(2, '0')}:${t.split(':')[1]} $period';
    }).toList();
    debugPrint('--- Expected visible time chips: $expected12h');
    for (final label in expected12h) {
      expect(find.text(label), findsOneWidget,
          reason: 'future time $label today must be selectable');
    }
    expect(pastChip, findsNothing,
        reason: 'passed times today must be hidden');
    debugPrint('--- LIVE E2E PASSED: today is first selectable with only '
        'future times.');
  });
}
