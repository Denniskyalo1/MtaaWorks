
import 'package:flutter/material.dart';
import 'landing_page.dart';
import 'home_page.dart';
import 'services/api_service.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';


Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: ".env");
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'MtaaWorks',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.deepPurple,
        ),
        useMaterial3: true,
      ),
      home: const AuthGate(),
    );
  }
}

class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  Widget? _initialPage;

  @override
  void initState() {
    super.initState();
    _checkSession();
  }

  Future<void> _checkSession() async {
    try {
      final isLoggedIn = await ApiService.hasSavedSession();

      if (!mounted) return;

      setState(() {
        _initialPage =
        isLoggedIn ? const HomePage() : const LandingPage();
      });
    } catch (_) {
      if (!mounted) return;

      setState(() {
        _initialPage = const LandingPage();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_initialPage != null) {
      return _initialPage!;
    }

    // Display while the saved session is being checked.
    return const Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: CircularProgressIndicator(
          color: Color(0xFF7C3AED),
        ),
      ),
    );
  }
}
