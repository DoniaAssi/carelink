import 'package:flutter/material.dart';

/// Simple in-app legal copy (no WebView dependency).
class LegalDocumentScreen extends StatelessWidget {
  const LegalDocumentScreen({
    super.key,
    required this.title,
    required this.bodyText,
  });

  final String title;
  final String bodyText;

  static const String privacyPolicyBody = '''
CareLink Privacy Policy

Last updated: May 2026

1. Information we collect
We collect account information you provide (name, email, phone, role, and profile details), health-related information you choose to enter in the app, device and usage data needed to run the service, and communications you send to support.

2. How we use information
We use your information to provide scheduling, care coordination, notifications, safety, fraud prevention, and to improve the app. We do not sell your personal information.

3. Sharing
We may share data with healthcare providers you interact with through the app, payment processors if you pay through the platform, and service providers who help us host and secure the service, only as needed to operate CareLink.

4. Security
We use industry-standard safeguards. No method of transmission over the internet is 100% secure.

5. Your choices
You may update profile fields in the app where supported, opt out of non-essential notifications in settings, and contact support to request account or data assistance subject to applicable law.

6. Contact
Questions about this policy: support@carelink.com
''';

  static const String termsOfServiceBody = '''
CareLink Terms of Service

Last updated: May 2026

1. Acceptance
By using CareLink, you agree to these terms. If you do not agree, do not use the app.

2. Not medical advice
CareLink helps coordinate care and communication. It is not a substitute for professional medical diagnosis or treatment. In an emergency, call local emergency services.

3. Accounts
You are responsible for your account credentials and for activity under your account. You must provide accurate information for your role (patient, nurse, or doctor).

4. Acceptable use
You may not misuse the service, attempt unauthorized access, harass others, or upload unlawful content.

5. Providers
Independent professionals using CareLink remain responsible for their licenses, scope of practice, and compliance with applicable regulations.

6. Limitation of liability
To the fullest extent permitted by law, CareLink and its operators are not liable for indirect or consequential damages arising from use of the service.

7. Changes
We may update these terms; continued use after changes means you accept the updated terms.

8. Contact
support@carelink.com
''';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(title),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Text(
            bodyText.trim(),
            style: const TextStyle(fontSize: 15, height: 1.5),
          ),
        ),
      ),
    );
  }
}
