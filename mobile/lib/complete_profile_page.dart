
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/api_service.dart';
import 'home_page.dart';

const Color _purple = Color(0xFF7C3AED);
const Color _purpleSoft = Color(0xFFF3EEFF);
const Color _cardFill = Color(0xFFF9FAFB);

class CompleteProfilePage extends StatefulWidget {
  const CompleteProfilePage({
    super.key,
    this.googleName = 'Google User',
    this.googleEmail = '',
  });

  final String googleName;
  final String googleEmail;

  @override
  State<CompleteProfilePage> createState() =>
      _CompleteProfilePageState();
}

class _CompleteProfilePageState extends State<CompleteProfilePage> {
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _idController = TextEditingController();

  bool _confirmed = false;
  bool _isSubmitting = false;

  @override
  void dispose() {
    _phoneController.dispose();
    _idController.dispose();
    super.dispose();
  }

  bool get _idValid =>
      RegExp(r'^\d{7,8}$').hasMatch(_idController.text.trim());

  bool get _phoneProvided =>
      _phoneController.text.trim().isNotEmpty;

  String get _cleanPhone => _phoneController.text
      .trim()
      .replaceAll(RegExp(r'[\s\-()]'), '');

  bool get _phoneValid {
    if (!_phoneProvided) return true;
    return RegExp(r'^(\+254|254|0)[17]\d{8}$')
        .hasMatch(_cleanPhone);
  }

  bool get _canSubmit =>
      _idValid && _confirmed && _phoneValid && !_isSubmitting;

  String? get _idError {
    if (_idController.text.isEmpty || _idValid) return null;
    return 'A national ID has 7 or 8 digits';
  }

  String? get _phoneError {
    if (!_phoneProvided || _phoneValid) return null;
    return 'Use a Kenyan number, e.g. 0712 345 678';
  }

  InputDecoration _decoration({
    required String hint,
    required IconData icon,
    String? errorText,
  }) {
    OutlineInputBorder border(Color color, [double width = 1.0]) {
      return OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: color, width: width),
      );
    }

    return InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(
        color: Colors.grey.shade400,
        fontSize: 14,
      ),
      prefixIcon: Icon(icon, color: Colors.grey.shade500),
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

  Widget _label(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: Colors.black87,
        ),
      ),
    );
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

  String get _phoneForBackend {
    if (!_phoneProvided) return '';

    // Convert common Kenyan formats to a consistent local format.
    if (_cleanPhone.startsWith('+254')) {
      return '0${_cleanPhone.substring(4)}';
    }

    if (_cleanPhone.startsWith('254')) {
      return '0${_cleanPhone.substring(3)}';
    }

    return _cleanPhone;
  }

  Future<void> _finishSetup() async {
    if (!_canSubmit) return;

    FocusScope.of(context).unfocus();
    setState(() => _isSubmitting = true);

    try {
      await ApiService.completeGoogleProfile(
        nationalId: _idController.text.trim(),
        phoneNumber:
        _phoneProvided ? _phoneForBackend : null,
      );

      if (!mounted) return;

      // The backend has confirmed profile completion.
      // Keep the existing authenticated session.
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(
          builder: (_) => const HomePage(),
        ),
            (route) => false,
      );
    } catch (e) {
      _showMessage(_errorMessage(e));
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final name = widget.googleName.trim().isEmpty
        ? 'Google User'
        : widget.googleName.trim();
    final email = widget.googleEmail.trim();

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                keyboardDismissBehavior:
                ScrollViewKeyboardDismissBehavior.onDrag,
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Text(
                          'Step 2 of 2',
                          style: TextStyle(
                            color: Colors.grey.shade600,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const Spacer(),
                        TextButton(
                          onPressed: _isSubmitting
                              ? null
                              : () async {
                            final confirmed =
                            await showDialog<bool>(
                              context: context,
                              builder: (dialogContext) =>
                                  AlertDialog(
                                    title: const Text(
                                      'Use another account?',
                                    ),
                                    content: const Text(
                                      'You will return to the previous '
                                          'screen. Your current session '
                                          'will not be cleared automatically.',
                                    ),
                                    actions: [
                                      TextButton(
                                        onPressed: () =>
                                            Navigator.of(
                                              dialogContext,
                                            ).pop(false),
                                        child:
                                        const Text('Cancel'),
                                      ),
                                      FilledButton(
                                        onPressed: () =>
                                            Navigator.of(
                                              dialogContext,
                                            ).pop(true),
                                        child:
                                        const Text('Continue'),
                                      ),
                                    ],
                                  ),
                            );

                            if (confirmed == true &&
                                mounted) {
                              Navigator.of(
                                context,
                                rootNavigator: true,
                              ).popUntil(
                                    (route) => route.isFirst,
                              );
                            }
                          },
                          child: Text(
                            'Use another account',
                            style: TextStyle(
                              color: Colors.grey.shade600,
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),

                    // Progress indicator
                    Row(
                      children: [
                        Expanded(
                          child: Container(
                            height: 6,
                            decoration: BoxDecoration(
                              color: _purple,
                              borderRadius: BorderRadius.circular(3),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Container(
                            height: 6,
                            decoration: BoxDecoration(
                              color: _purple,
                              borderRadius: BorderRadius.circular(3),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 28),

                    Text(
                      'Complete your profile',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: width * 0.07,
                        fontWeight: FontWeight.bold,
                        color: Colors.black,
                        letterSpacing: 0.4,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Google gave us your name and email.\n'
                          'We just need a few more details.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: width * 0.038,
                        color: Colors.grey,
                        height: 1.35,
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Google account details
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: _cardFill,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: Colors.grey.shade200,
                        ),
                      ),
                      child: Row(
                        children: [
                          CircleAvatar(
                            radius: 24,
                            backgroundColor: _purpleSoft,
                            child: Text(
                              name.isEmpty
                                  ? 'G'
                                  : name[0].toUpperCase(),
                              style: const TextStyle(
                                color: _purple,
                                fontWeight: FontWeight.bold,
                                fontSize: 20,
                              ),
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment:
                              CrossAxisAlignment.start,
                              children: [
                                Text(
                                  name,
                                  style: const TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.black87,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  email.isEmpty
                                      ? 'Google account'
                                      : email,
                                  style: TextStyle(
                                    color: Colors.grey.shade600,
                                    fontSize: 13,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 5,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFFE7F6EC),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.check_circle_rounded,
                                  size: 14,
                                  color: Color(0xFF1E8E4E),
                                ),
                                SizedBox(width: 4),
                                Text(
                                  'Google',
                                  style: TextStyle(
                                    color: Color(0xFF1E8E4E),
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 26),

                    // Phone number
                    _label('Phone Number (optional)'),
                    TextField(
                      controller: _phoneController,
                      keyboardType: TextInputType.phone,
                      enabled: !_isSubmitting,
                      onChanged: (_) => setState(() {}),
                      decoration: _decoration(
                        hint: 'e.g. 0712 345 678',
                        icon: Icons.phone_outlined,
                        errorText: _phoneError,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          Icons.sms_outlined,
                          size: 15,
                          color: Colors.grey.shade500,
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            'We will text you a code to verify it later.',
                            style: TextStyle(
                              color: Colors.grey.shade600,
                              fontSize: 12.5,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 22),

                    // National ID
                    _label('National ID'),
                    TextField(
                      controller: _idController,
                      keyboardType: TextInputType.number,
                      enabled: !_isSubmitting,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                      ],
                      maxLength: 8,
                      onChanged: (_) => setState(() {}),
                      decoration: _decoration(
                        hint: 'Enter Your National ID Number',
                        icon: Icons.badge_outlined,
                        errorText: _idError,
                      ).copyWith(counterText: ''),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          Icons.lock_outline_rounded,
                          size: 15,
                          color: Colors.grey.shade500,
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            'Your national ID is used to verify your '
                                'identity and check for duplicate accounts.',
                            style: TextStyle(
                              color: Colors.grey.shade600,
                              fontSize: 12.5,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),

                    // Warning
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFF8E8),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: const Color(0xFFFFE2A8),
                        ),
                      ),
                      child: const Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            Icons.info_outline_rounded,
                            color: Color(0xFFB7791F),
                            size: 20,
                          ),
                          SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'Check your national ID carefully. '
                                  'Make sure it belongs to you before '
                                  'finishing setup.',
                              style: TextStyle(
                                color: Color(0xFF7A4F0C),
                                fontSize: 13,
                                height: 1.4,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ),

            // Bottom action
            Container(
              padding: const EdgeInsets.fromLTRB(24, 12, 24, 16),
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border(
                  top: BorderSide(color: Colors.grey.shade200),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(
                        width: 28,
                        height: 28,
                        child: Checkbox(
                          value: _confirmed,
                          activeColor: _purple,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(6),
                          ),
                          onChanged: _isSubmitting
                              ? null
                              : (value) => setState(
                                () => _confirmed = value ?? false,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: GestureDetector(
                          onTap: _isSubmitting
                              ? null
                              : () => setState(
                                () => _confirmed = !_confirmed,
                          ),
                          child: Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text(
                              'I confirm this is my own national ID number.',
                              style: TextStyle(
                                color: Colors.grey.shade700,
                                fontSize: 13,
                                height: 1.4,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Container(
                    height: 54,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(27),
                      gradient: LinearGradient(
                        colors: _canSubmit
                            ? const [
                          Color(0xFF2C2C2E),
                          Color(0xFF000000),
                        ]
                            : [
                          Colors.grey.shade400,
                          Colors.grey.shade400,
                        ],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      ),
                    ),
                    child: ElevatedButton(
                      onPressed: _canSubmit ? _finishSetup : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.transparent,
                        disabledBackgroundColor: Colors.transparent,
                        shadowColor: Colors.transparent,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(27),
                        ),
                      ),
                      child: _isSubmitting
                          ? const SizedBox(
                        height: 22,
                        width: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                          : const Text(
                        'Finish setup',
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
          ],
        ),
      ),
    );
  }
}
