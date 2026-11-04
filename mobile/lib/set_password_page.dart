import 'package:flutter/material.dart';

import '../services/api_service.dart';

const Color _purple = Color(0xFF7C3AED);
const Color _purpleSoft = Color(0xFFF3EEFF);
const Color _cardFill = Color(0xFFF9FAFB);

/// For users who signed up with Google and have no password yet.
/// Pops with true once the password is saved.
class SetPasswordPage extends StatefulWidget {
  const SetPasswordPage({super.key});

  @override
  State<SetPasswordPage> createState() => _SetPasswordPageState();
}

class _SetPasswordPageState extends State<SetPasswordPage> {
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmController = TextEditingController();

  bool _obscurePassword = true;
  bool _obscureConfirm = true;
  bool _isSaving = false;

  @override
  void dispose() {
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  bool get _canSave =>
      _passwordController.text.length >= 8 &&
          _passwordController.text == _confirmController.text &&
          !_isSaving;

  String? get _passwordError {
    final value = _passwordController.text;
    if (value.isEmpty || value.length >= 8) return null;
    return 'Use at least 8 characters';
  }

  String? get _confirmError {
    final value = _confirmController.text;
    if (value.isEmpty || value == _passwordController.text) return null;
    return 'Passwords do not match';
  }

  void _showMessage(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  Future<void> _save() async {
    if (!_canSave) return;

    FocusScope.of(context).unfocus();
    setState(() => _isSaving = true);

    try {
      await ApiService.setPassword(
        password: _passwordController.text,
        passwordConfirmation: _confirmController.text,
      );

      if (!mounted) return;

      _showMessage('Password set. You can now also log in with your email.');
      Navigator.of(context).pop(true);
    } catch (e) {
      _showMessage(friendlyError(e));
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  InputDecoration _decoration({
    required String hint,
    String? errorText,
    required bool obscured,
    required VoidCallback onToggle,
  }) {
    OutlineInputBorder border(Color color, [double width = 1.0]) {
      return OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: color, width: width),
      );
    }

    return InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 14),
      prefixIcon: Icon(Icons.lock_outline_rounded, color: Colors.grey.shade500),
      suffixIcon: IconButton(
        onPressed: onToggle,
        icon: Icon(
          obscured ? Icons.visibility_off_outlined : Icons.visibility_outlined,
          color: Colors.grey.shade500,
        ),
      ),
      errorText: errorText,
      filled: true,
      fillColor: _cardFill,
      contentPadding: const EdgeInsets.symmetric(vertical: 16),
      enabledBorder: border(Colors.grey.shade300),
      focusedBorder: border(Colors.black),
      errorBorder: border(Colors.red.shade400),
      focusedErrorBorder: border(Colors.red.shade400, 1.5),
    );
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        elevation: 0,
        foregroundColor: Colors.black,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 72,
                  height: 72,
                  decoration: const BoxDecoration(
                    color: _purpleSoft,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.key_outlined, color: _purple, size: 32),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'Set a password',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: width * 0.07,
                  fontWeight: FontWeight.bold,
                  color: Colors.black,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'You signed up with Google. Add a password to also\n'
                    'log in with your email address.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.grey.shade600,
                  fontSize: 14,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 28),
              TextField(
                controller: _passwordController,
                obscureText: _obscurePassword,
                enabled: !_isSaving,
                onChanged: (_) => setState(() {}),
                decoration: _decoration(
                  hint: 'New password (at least 8 characters)',
                  errorText: _passwordError,
                  obscured: _obscurePassword,
                  onToggle: () =>
                      setState(() => _obscurePassword = !_obscurePassword),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _confirmController,
                obscureText: _obscureConfirm,
                enabled: !_isSaving,
                onChanged: (_) => setState(() {}),
                onSubmitted: (_) => _save(),
                decoration: _decoration(
                  hint: 'Confirm password',
                  errorText: _confirmError,
                  obscured: _obscureConfirm,
                  onToggle: () =>
                      setState(() => _obscureConfirm = !_obscureConfirm),
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                height: 54,
                child: ElevatedButton(
                  onPressed: _canSave ? _save : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.black,
                    disabledBackgroundColor: Colors.grey.shade400,
                    shadowColor: Colors.transparent,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(27),
                    ),
                  ),
                  child: _isSaving
                      ? const SizedBox(
                    height: 22,
                    width: 22,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                      : const Text(
                    'Save password',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
