import 'package:flutter/material.dart';

import 'api_service.dart';
import 'login_page.dart';

/// Opened from the link in the email sent when a lender account is created or a password is reset.
/// The link carries the one-time token and the email address.
class SetPasswordPage extends StatefulWidget {
  const SetPasswordPage({super.key, required this.token, required this.email});

  final String token;
  final String email;

  @override
  State<SetPasswordPage> createState() => _SetPasswordPageState();
}

class _SetPasswordPageState extends State<SetPasswordPage> {
  static const Color primary = Color(0xFF5B3CC4);

  final _password = TextEditingController();
  final _confirm = TextEditingController();
  bool _hide = true;
  bool _saving = false;
  bool _done = false;
  String? _error;

  @override
  void dispose() {
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  bool get _valid => _password.text.length >= 8 && _password.text == _confirm.text && !_saving;

  Future<void> _save() async {
    if (!_valid) return;
    setState(() {
      _saving = true;
      _error = null;
    });

    try {
      await ApiService.setPassword(
        token: widget.token,
        email: widget.email,
        password: _password.text,
        confirmation: _confirm.text,
      );
      if (mounted) setState(() => _done = true);
    } catch (e) {
      if (mounted) {
        setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _goToSignIn() {
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginPage()),
          (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 440),
          child: Card(
            elevation: 0,
            color: Colors.white,
            margin: const EdgeInsets.all(24),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: _done ? _success() : _form(),
            ),
          ),
        ),
      ),
    );
  }

  Widget _success() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.check_circle_outline_rounded, size: 56, color: Color(0xFF15803D)),
        const SizedBox(height: 16),
        const Text('Password saved', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        const Text('You can now sign in to the lender portal.', textAlign: TextAlign.center),
        const SizedBox(height: 24),
        FilledButton(onPressed: _goToSignIn, child: const Text('Go to sign in')),
      ],
    );
  }

  Widget _form() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text('Set your password', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
        const SizedBox(height: 6),
        Text('for ${widget.email}', style: TextStyle(color: Colors.grey.shade700)),
        const SizedBox(height: 24),
        TextField(
          controller: _password,
          obscureText: _hide,
          onChanged: (_) => setState(() {}),
          decoration: InputDecoration(
            labelText: 'New password (at least 8 characters)',
            border: const OutlineInputBorder(),
            suffixIcon: IconButton(
              icon: Icon(_hide ? Icons.visibility_off_outlined : Icons.visibility_outlined),
              onPressed: () => setState(() => _hide = !_hide),
            ),
          ),
        ),
        const SizedBox(height: 14),
        TextField(
          controller: _confirm,
          obscureText: _hide,
          onChanged: (_) => setState(() {}),
          onSubmitted: (_) => _save(),
          decoration: const InputDecoration(labelText: 'Confirm password', border: OutlineInputBorder()),
        ),
        if (_password.text.isNotEmpty && _confirm.text.isNotEmpty && _password.text != _confirm.text)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text('The passwords do not match.', style: TextStyle(color: Colors.red.shade700)),
          ),
        if (_error != null)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(_error!, style: TextStyle(color: Colors.red.shade700)),
          ),
        const SizedBox(height: 20),
        FilledButton(
          onPressed: _valid ? _save : null,
          style: FilledButton.styleFrom(backgroundColor: primary, padding: const EdgeInsets.symmetric(vertical: 16)),
          child: _saving
              ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : const Text('Save password'),
        ),
        const SizedBox(height: 8),
        const Text('The link in your email can be used once and expires after a short time.',
            style: TextStyle(fontSize: 12, color: Colors.grey)),
      ],
    );
  }
}
