
import 'package:flutter/material.dart';

import 'login_page.dart';
import 'set_password_page.dart';
import 'verify_report_page.dart';

void main() {
  runApp(const MtaaWorksLenderApp());
}

class MtaaWorksLenderApp extends StatelessWidget {
  const MtaaWorksLenderApp({super.key});

  /// The emailed set-password link carries a token and the email address in the URL.
  Widget _startPage() {
    final params = Uri.base.queryParameters;
    final token = params['token'];
    final email = params['email'];
    final verify = params['verify'];

    // The QR code on a credit report opens this page with ?verify=CODE
    if (verify != null && verify.isNotEmpty) {
      return VerifyReportPage(initialCode: verify);
    }

    if (token != null && token.isNotEmpty && email != null && email.isNotEmpty) {
      return SetPasswordPage(token: token, email: email);
    }

    return const LoginPage();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'MtaaWorks Lender Portal',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF5B3CC4),
        ),
        scaffoldBackgroundColor: const Color(0xFFF7F6FC),
        fontFamily: 'Arial',
      ),
      home: _startPage(),
    );
  }
}
