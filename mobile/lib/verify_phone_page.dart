import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/api_service.dart';
import 'home_page.dart';

const Color _purple = Color(0xFF7C3AED);
const Color _purpleSoft = Color(0xFFF3EEFF);
const Color _cardFill = Color(0xFFF9FAFB);

/// Sends an SMS code to the signed-in user's phone number and checks it.
///
/// [fromSetup] true  -> finishing (verified or skipped) opens Home and
///                      clears every previous route.
/// [fromSetup] false -> finishing pops this page with true (verified)
///                      or false (skipped), e.g. when opened from Profile.
class VerifyPhonePage extends StatefulWidget {
  const VerifyPhonePage({
    super.key,
    required this.phoneNumber,
    this.fromSetup = false,
  });

  final String phoneNumber;
  final bool fromSetup;

  @override
  State<VerifyPhonePage> createState() => _VerifyPhonePageState();
}

class _VerifyPhonePageState extends State<VerifyPhonePage> {
  final TextEditingController _codeController = TextEditingController();

  bool _sending = false;
  bool _verifying = false;
  bool _codeSent = false;
  int _cooldown = 0;
  Timer? _timer;

  bool get _codeReady =>
      RegExp(r'^\d{6}$').hasMatch(_codeController.text.trim());

  bool get _busy => _sending || _verifying;

  @override
  void initState() {
    super.initState();
    // Send the first code as soon as the page opens.
    WidgetsBinding.instance.addPostFrameCallback((_) => _sendCode());
  }

  @override
  void dispose() {
    _timer?.cancel();
    _codeController.dispose();
    super.dispose();
  }

  void _showMessage(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  String _errorMessage(Object error) {
    return error.toString().replaceFirst('Exception: ', '');
  }

  bool _isAlreadyVerified(String message) {
    return message.toLowerCase().contains('already verified');
  }

  void _startCooldown() {
    _timer?.cancel();
    setState(() => _cooldown = 30);

    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }

      if (_cooldown <= 1) {
        timer.cancel();
        setState(() => _cooldown = 0);
      } else {
        setState(() => _cooldown--);
      }
    });
  }

  Future<void> _sendCode() async {
    if (_busy || _cooldown > 0) return;

    setState(() => _sending = true);

    try {
      final result = await ApiService.sendPhoneCode();

      if (!mounted) return;

      setState(() => _codeSent = true);
      _startCooldown();

      _showMessage(
        result['message']?.toString() ?? 'Verification code sent.',
      );
    } catch (e) {
      final message = _errorMessage(e);

      if (_isAlreadyVerified(message)) {
        _finish(true);
        return;
      }

      _showMessage(message);
    } finally {
      if (mounted) {
        setState(() => _sending = false);
      }
    }
  }

  Future<void> _verifyCode() async {
    if (!_codeReady || _busy) return;

    FocusScope.of(context).unfocus();
    setState(() => _verifying = true);

    try {
      await ApiService.verifyPhoneCode(_codeController.text.trim());

      if (!mounted) return;

      _showMessage('Phone number verified.');
      _finish(true);
    } catch (e) {
      final message = _errorMessage(e);

      if (_isAlreadyVerified(message)) {
        _finish(true);
        return;
      }

      _showMessage(message);
    } finally {
      if (mounted) {
        setState(() => _verifying = false);
      }
    }
  }

  void _finish(bool verified) {
    if (!mounted) return;

    if (widget.fromSetup) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const HomePage()),
        (route) => false,
      );
    } else {
      Navigator.of(context).pop(verified);
    }
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: SingleChildScrollView(
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 24),
              Center(
                child: Container(
                  width: 72,
                  height: 72,
                  decoration: const BoxDecoration(
                    color: _purpleSoft,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.sms_outlined,
                    color: _purple,
                    size: 32,
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'Verify your phone',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: width * 0.07,
                  fontWeight: FontWeight.bold,
                  color: Colors.black,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _codeSent
                    ? 'Enter the 6-digit code we sent to\n${widget.phoneNumber}.'
                    : 'Sending a code to\n${widget.phoneNumber}...',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.grey.shade600,
                  fontSize: 14,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 28),
              TextField(
                controller: _codeController,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                maxLength: 6,
                enabled: !_verifying,
                textAlign: TextAlign.center,
                onChanged: (_) => setState(() {}),
                onSubmitted: (_) => _verifyCode(),
                style: const TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 10,
                ),
                decoration: InputDecoration(
                  counterText: '',
                  hintText: '••••••',
                  hintStyle: TextStyle(
                    color: Colors.grey.shade300,
                    letterSpacing: 10,
                  ),
                  filled: true,
                  fillColor: _cardFill,
                  contentPadding: const EdgeInsets.symmetric(vertical: 16),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide(color: Colors.grey.shade300),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: const BorderSide(color: Colors.black),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                height: 54,
                child: ElevatedButton(
                  onPressed: _codeReady && !_busy ? _verifyCode : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.black,
                    disabledBackgroundColor: Colors.grey.shade400,
                    shadowColor: Colors.transparent,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(27),
                    ),
                  ),
                  child: _verifying
                      ? const SizedBox(
                          height: 22,
                          width: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text(
                          'Verify',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                ),
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: _busy || _cooldown > 0 ? null : _sendCode,
                child: Text(
                  _sending
                      ? 'Sending code...'
                      : _cooldown > 0
                          ? 'Resend code in ${_cooldown}s'
                          : 'Resend code',
                  style: TextStyle(
                    color: _busy || _cooldown > 0
                        ? Colors.grey.shade500
                        : _purple,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              TextButton(
                onPressed: _busy ? null : () => _finish(false),
                child: Text(
                  'Verify later',
                  style: TextStyle(
                    color: Colors.grey.shade700,
                    fontWeight: FontWeight.w600,
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
