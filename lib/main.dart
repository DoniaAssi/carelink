import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'package:carelink/core/app_localizations.dart';
import 'package:carelink/core/app_nav.dart';
import 'package:carelink/core/app_theme.dart';
import 'package:carelink/core/locale_controller.dart';
import 'package:carelink/core/theme_controller.dart';
import 'package:carelink/features/auth/login_screen.dart';
import 'package:carelink/features/auth/registration/getx/registration_entry.dart';
import 'package:carelink/features/auth/registration/professional_profile_completion_screen.dart';
import 'package:carelink/features/nurse/screens/nurse_dashboard.dart';
import 'package:carelink/features/onboarding/intro_screen.dart';
import 'package:carelink/features/patient/widgets/patient_navigation_shell.dart';
import 'package:carelink/shared/models/user.dart';
// AI Flow Screens
import 'package:carelink/features/ai/screens/find_provider_screen.dart';
import 'package:carelink/features/ai/screens/ai_provider_details_screen.dart';
import 'package:carelink/features/ai/screens/ai_appointment_screen.dart';
import 'package:carelink/features/ai/screens/ai_booking_confirmed_screen.dart';
import 'package:carelink/features/ai/recommendation/models/recommendation_models.dart';
import 'package:carelink/shared/models/booking_request_model.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Future.wait([themeController.load(), localeController.load()]);
  runApp(const CareLinkApp());
}

class CareLinkApp extends StatelessWidget {
  const CareLinkApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([themeController, localeController]),
      builder: (context, _) {
        return MaterialApp(
          navigatorKey: appNavigatorKey,
          scaffoldMessengerKey: appScaffoldMessengerKey,
          debugShowCheckedModeBanner: false,
          title: CarelinkL10n(localeController.locale).t('app.name'),
          locale: localeController.locale,
          scrollBehavior: const MaterialScrollBehavior().copyWith(
            dragDevices: {
              PointerDeviceKind.touch,
              PointerDeviceKind.mouse,
              PointerDeviceKind.trackpad,
              PointerDeviceKind.stylus,
            },
          ),
          supportedLocales: const [Locale('en'), Locale('ar')],
          localeResolutionCallback: (deviceLocale, supportedLocales) {
            if (deviceLocale == null) return const Locale('en');
            final code = deviceLocale.languageCode.toLowerCase();
            if (code == 'ar') return const Locale('ar');
            return const Locale('en');
          },
          localizationsDelegates: const [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          theme: AppTheme.light,
          darkTheme: AppTheme.dark,
          themeMode: themeController.themeMode,
          builder: (context, child) {
            return child ?? const SizedBox.shrink();
          },
          initialRoute: '/intro',
          routes: {
            '/intro': (context) => const IntroScreen(),
            '/login': (context) => const LoginScreen(),
            '/patient-home': (context) {
              final args = ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
              final initialTabValue = args?['initialTab'];
              final initialTab = initialTabValue is int
                  ? initialTabValue
                  : int.tryParse(initialTabValue?.toString() ?? '') ?? 0;
              return PatientNavigationShell(
                userId: (args?['userId'] ?? '').toString(),
                displayName: args?['displayName'] as String?,
                initialTab: initialTab.clamp(0, 4).toInt(),
              );
            },
            '/patient-profile': (_) => const PatientNavigationShell(initialIndex: 4),
          },
          onGenerateRoute: (settings) {
            if (settings.name == '/patient/profile' || settings.name == '/patient/profile/') {
              return MaterialPageRoute<void>(
                builder: (_) => const PatientNavigationShell(
                  initialIndex: 4,
                ),
                settings: const RouteSettings(name: '/patient-profile'),
              );
            }

            if (settings.name == '/email-register') {
              final args = settings.arguments;
              String? roleArg;
              if (args is Map<String, dynamic>) {
                roleArg = args['role']?.toString();
              }
              return MaterialPageRoute<void>(
                builder: (_) => CarelinkRegistrationEntry(initialRole: roleArg),
                settings: settings,
              );
            }

            if (settings.name == '/complete-professional-profile' ||
                settings.name == '/complete-profile') {
              final user = settings.arguments as User?;
              if (user != null) {
                return MaterialPageRoute<void>(
                  builder: (_) =>
                      ProfessionalProfileCompletionScreen(user: user),
                  settings: settings,
                );
              }
            }

            if (settings.name?.startsWith('/patient/') == true) {
              final pathSegments = settings.name!
                  .split('/')
                  .where((segment) => segment.isNotEmpty)
                  .toList();
              if (pathSegments.length == 2 && pathSegments[0] == 'patient') {
                final tabKey = pathSegments[1];
                final args = settings.arguments as Map<String, dynamic>?;
                int? initialTab;
                switch (tabKey) {
                  case 'home':
                    initialTab = 0;
                    break;
                  case 'bookings':
                  case 'schedule':
                    initialTab = 1;
                    break;
                  case 'care':
                  case 'care-hub':
                    initialTab = 2;
                    break;
                  case 'records':
                  case 'medical-records':
                    initialTab = 3;
                    break;
                }
                if (initialTab != null) {
                  return MaterialPageRoute<void>(
                    builder: (_) => PatientNavigationShell(
                      userId: (args?['userId'] ?? '').toString(),
                      displayName: args?['displayName'] as String?,
                      initialTab: initialTab!,
                    ),
                    settings: settings,
                  );
                }
              }
            }

            if (settings.name == '/nurse-dashboard') {
              final user = settings.arguments as User?;
              if (user != null) {
                return MaterialPageRoute(
                  builder: (_) => NurseDashboard(user: user),
                  settings: settings,
                );
              }
            }

            // AI Flow Named Routes with safety checks
            if (settings.name == '/find-provider') {
              final args = settings.arguments as Map<String, dynamic>?;
              return MaterialPageRoute(
                builder: (_) => FindProviderScreen(
                  userId: (args?['userId'] ?? '').toString(),
                ),
                settings: settings,
              );
            }

            if (settings.name == '/ai-details') {
              final args = settings.arguments as Map<String, dynamic>?;
              return MaterialPageRoute(
                builder: (_) => AiProviderDetailsScreen(
                  result: args?['result'] as AIRecommendationResult?,
                  patientUserId: args?['patientUserId'] as String?,
                  distanceKm: args?['distanceKm'] as double?,
                  caseReason: args?['caseReason'] as String? ?? '',
                ),
                settings: settings,
              );
            }

            if (settings.name == '/ai-appointment') {
              final args = settings.arguments as Map<String, dynamic>?;
              return MaterialPageRoute(
                builder: (_) => AiAppointmentScreen(
                  request: args?['request'] as BookingRequestModel?,
                  aiResult: args?['aiResult'] as AIRecommendationResult?,
                  displayDate: args?['displayDate'] as String? ?? '',
                  displayTime: args?['displayTime'] as String? ?? '',
                ),
                settings: settings,
              );
            }

            if (settings.name == '/ai-booking-confirmed') {
              final args = settings.arguments as Map<String, dynamic>?;
              return MaterialPageRoute(
                builder: (_) => AiBookingConfirmedScreen(
                  request: args?['request'] as BookingRequestModel?,
                  appointmentId: args?['appointmentId'] as String? ?? '',
                  displayDate: args?['displayDate'] as String? ?? '',
                  displayTime: args?['displayTime'] as String? ?? '',
                  patientUserId: args?['patientUserId'] as String? ?? '',
                ),
                settings: settings,
              );
            }

            return null;
          },
        );
      },
    );
  }
}
