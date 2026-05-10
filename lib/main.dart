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
import 'package:carelink/features/patient/screens/patient_home_screen.dart';
import 'package:carelink/shared/models/user.dart';
import 'package:carelink/shared/widgets/carelink_theme_toggle.dart';

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
            return Stack(
              fit: StackFit.expand,
              clipBehavior: Clip.none,
              children: [
                child ?? const SizedBox.shrink(),
                carelinkGlobalLocaleOverlay(context),
              ],
            );
          },
          initialRoute: '/intro',
          routes: {
            '/intro': (context) => const IntroScreen(),
            '/login': (context) => const LoginScreen(),
          },
          onGenerateRoute: (settings) {
            if (settings.name == '/email-register') {
              final args = settings.arguments;
              String? roleArg;
              if (args is Map<String, dynamic>) {
                roleArg = args['role']?.toString();
              }
              return MaterialPageRoute<void>(
                builder: (_) => CarelinkRegistrationEntry(initialRole: roleArg),
              );
            }

            if (settings.name == '/patient-home') {
              final args = settings.arguments as Map<String, dynamic>?;
              return MaterialPageRoute(
                builder: (_) => PatientHomeScreen(
                  userId: args?['userId'] as String?,
                  displayName: args?['displayName'] as String?,
                ),
              );
            }

            if (settings.name == '/complete-professional-profile' ||
                settings.name == '/complete-profile') {
              final user = settings.arguments as User?;
              if (user != null) {
                return MaterialPageRoute<void>(
                  builder: (_) =>
                      ProfessionalProfileCompletionScreen(user: user),
                );
              }
            }

            if (settings.name == '/nurse-dashboard') {
              final user = settings.arguments as User?;
              if (user != null) {
                return MaterialPageRoute(
                  builder: (_) => NurseDashboard(user: user),
                );
              }
            }
            return null;
          },
        );
      },
    );
  }
}
