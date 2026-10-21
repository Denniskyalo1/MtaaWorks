
import 'package:flutter/material.dart';

import 'login_page.dart';

void main() {
  runApp(const MtaaWorksLenderApp());
}

class MtaaWorksLenderApp extends StatelessWidget {
  const MtaaWorksLenderApp({super.key});

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
      home: const LoginPage(),
    );
  }
}
