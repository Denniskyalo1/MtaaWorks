
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mtaaworks/login_page.dart';

import '../services/api_service.dart';
import 'edit_profile_page.dart';
import 'change_password_page.dart';

const Color _purple = Color(0xFF7C3AED);
const Color _purpleSoft = Color(0xFFF3EEFF);
const Color _cardFill = Color(0xFFF9FAFB);
const Color _red = Color(0xFFE5484D);
const Color _redSoft = Color(0xFFFDECEC);
const Color _green = Color(0xFF1E8E4E);
const Color _greenSoft = Color(0xFFE7F6EC);

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  Map<String, dynamic>? _profile;

  bool _isLoading = true;
  bool _consent = false;
  bool _consentLoading = false;

  String? _error;
  int _pendingRequests = 0;

  String get _name => _profile?['name']?.toString() ?? 'User';

  String get _email => _profile?['email']?.toString() ?? 'No email';

  String get _phone =>
      _profile?['phone_number']?.toString() ?? 'No phone number';

  String get _maskedNationalId {
    final id = _profile?['national_id']?.toString() ?? '';

    if (id.isEmpty) return 'Not provided';
    if (id.length <= 2) return '*' * id.length;

    return '${'*' * (id.length - 2)}${id.substring(id.length - 2)}';
  }

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    if (mounted) {
      setState(() {
        _isLoading = true;
        _error = null;
      });
    }

    try {
      final results = await Future.wait([
        ApiService.getProfile(),
        ApiService.getAccessRequests(),
        ApiService.getConsents(),
      ]);

      if (!mounted) return;

      final profileResponse =
      Map<String, dynamic>.from(results[0] as Map);

      final requestsResponse =
      Map<String, dynamic>.from(results[1] as Map);

      final consentResponse =
      Map<String, dynamic>.from(results[2] as Map);

      final user = Map<String, dynamic>.from(
        profileResponse['user'] as Map,
      );

      final requests = requestsResponse['requests'] as List? ?? [];
      final consents = consentResponse['consents'] as List? ?? [];

      final activeConsent = consents.any((item) {
        return item is Map &&
            item['purpose'] == 'statement_analysis' &&
            item['revoked_at'] == null;
      });

      final pendingCount = requests.where((request) {
        return request is Map && request['status'] == 'requested';
      }).length;

      setState(() {
        _profile = user;
        _pendingRequests = pendingCount;
        _consent = activeConsent;
        _isLoading = false;
        _error = null;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _error = e.toString().replaceFirst('Exception: ', '');
        _isLoading = false;
      });
    }
  }

  Future<void> _onConsentChanged(bool value) async {
    if (_consentLoading) return;

    if (!value) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: const Text('Withdraw consent?'),
          content: const Text(
            'This withdraws statement-analysis consent, revokes requested '
                'or approved lender access, and deletes your stored statements. '
                'You will need to grant consent again before scoring another '
                'statement. Continue?',
          ),
          actions: [
            TextButton(
              onPressed: () =>
                  Navigator.of(dialogContext).pop(false),
              child: const Text(
                'Keep consent',
                style: TextStyle(color: Colors.black87),
              ),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: _red,
                shape: const StadiumBorder(),
              ),
              onPressed: () =>
                  Navigator.of(dialogContext).pop(true),
              child: const Text('Withdraw'),
            ),
          ],
        ),
      );

      if (confirmed != true || !mounted) return;
    }

    setState(() => _consentLoading = true);

    try {
      if (value) {
        await ApiService.grantStatementConsent();
      } else {
        await ApiService.revokeStatementConsent();
      }

      if (!mounted) return;

      setState(() => _consent = value);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            value
                ? 'Statement-analysis consent granted.'
                : 'Statement-analysis consent withdrawn.',
          ),
        ),
      );

      if (!value) {
        await _loadProfile();
      }
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            e.toString().replaceFirst('Exception: ', ''),
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _consentLoading = false);
      }
    }
  }

  Future<void> _logout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Log out?'),
        content: const Text('Are you sure you want to log out?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () =>
                Navigator.of(context).push(
                    MaterialPageRoute(builder: (context) => LoginPage(),)
                ),
            child: const Text('Log out'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    await ApiService.clearToken();

    if (!mounted) return;

    Navigator.of(context, rootNavigator: true)
        .popUntil((route) => route.isFirst);
  }

  Future<void> _openDeleteSheet() async {
    final deleted = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(28),
        ),
      ),
      builder: (_) => _DeleteAccountSheet(email: _email),
    );

    if (deleted != true || !mounted) return;

    try {
      await ApiService.clearToken();
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Account deleted, but clearing the local session failed: '
                '${e.toString().replaceFirst('Exception: ', '')}',
          ),
        ),
      );
    }

    if (!mounted) return;

    Navigator.of(context, rootNavigator: true)
        .popUntil((route) => route.isFirst);
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;

    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: _purple),
      );
    }

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.cloud_off_outlined,
                size: 42,
                color: _purple,
              ),
              const SizedBox(height: 12),
              const Text(
                'Could not load your profile',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _error!,
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey.shade600),
              ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: _loadProfile,
                child: const Text('Try again'),
              ),
            ],
          ),
        ),
      );
    }

    final firstLetter =
    _name.trim().isEmpty ? 'U' : _name.trim()[0].toUpperCase();

    return RefreshIndicator(
      onRefresh: _loadProfile,
      color: _purple,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.symmetric(
          horizontal: 24,
          vertical: 16,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: CircleAvatar(
                radius: 40,
                backgroundColor: _purpleSoft,
                child: Text(
                  firstLetter,
                  style: const TextStyle(
                    color: _purple,
                    fontWeight: FontWeight.bold,
                    fontSize: 32,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 14),
            Text(
              _name,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: width * 0.06,
                fontWeight: FontWeight.bold,
                color: Colors.black,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              _email,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.grey.shade600,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 28),

            // Personal details
            Row(
              children: [
                const Expanded(
                  child: _SectionTitle('Personal details'),
                ),
                TextButton(
                  onPressed: () async {
                    final updated = await Navigator.of(context)
                        .push<bool>(
                      MaterialPageRoute(
                        builder: (_) => EditProfilePage(
                          currentName: _name,
                          currentEmail:
                          _email == 'No email' ? '' : _email,
                          currentPhone: _phone,
                        ),
                      ),
                    );

                    if (updated == true && mounted) {
                      await _loadProfile();

                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                              'Profile updated successfully.',
                            ),
                          ),
                        );
                      }
                    }
                  },
                  child: const Text(
                    'Edit',
                    style: TextStyle(
                      color: _purple,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
            _Card(
              children: [
                _DetailRow(label: 'Full name', value: _name),
                _DetailRow(
                  label: 'Email',
                  value: _email,
                  trailing: Icon(
                    Icons.info_outline,
                    size: 18,
                    color: Colors.grey.shade500,
                  ),
                ),
                _DetailRow(
                  label: 'Phone number',
                  value: _phone,
                  trailing: Icon(
                    Icons.info_outline,
                    size: 18,
                    color: Colors.grey.shade500,
                  ),
                ),
                _DetailRow(
                  label: 'National ID',
                  value: _maskedNationalId,
                  trailing: Icon(
                    Icons.lock_outline_rounded,
                    size: 18,
                    color: Colors.grey.shade500,
                  ),
                  last: true,
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Security
            const _SectionTitle('Security'),
            const SizedBox(height: 8),
            _Card(
              children: [
                _SettingsRow(
                  icon: Icons.password_rounded,
                  title: 'Change password',
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const ChangePasswordPage(),
                      ),
                    );
                  },
                  last: true,
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Privacy
            const _SectionTitle('Privacy and data'),
            const SizedBox(height: 8),
            _Card(
              children: [
                _SettingsRow(
                  icon: Icons.verified_user_outlined,
                  title: 'Statement analysis consent',
                  subtitle: _consent
                      ? 'Active · consent text v1.0'
                      : 'Inactive · scoring is turned off',
                  trailing: _consentLoading
                      ? const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: _purple,
                    ),
                  )
                      : Switch(
                    value: _consent,
                    activeColor: _purple,
                    onChanged: _onConsentChanged,
                  ),
                ),
                _SettingsRow(
                  icon: Icons.business_outlined,
                  title: 'Lender access',
                  subtitle: '$_pendingRequests pending requests',
                  onTap: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(
                          'The lender access management screen has not '
                              'been connected to this row yet.',
                        ),
                      ),
                    );
                  },
                  last: true,
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Danger zone
            const _SectionTitle('Danger zone'),
            const SizedBox(height: 8),
            Container(
              decoration: BoxDecoration(
                color: _redSoft,
                borderRadius: BorderRadius.circular(20),
              ),
              child: _SettingsRow(
                icon: Icons.delete_outline_rounded,
                iconColor: _red,
                title: 'Delete my account',
                titleColor: _red,
                subtitle: 'Permanently removes your data',
                onTap: _openDeleteSheet,
                last: true,
              ),
            ),
            const SizedBox(height: 28),

            // Log out
            SizedBox(
              height: 54,
              child: OutlinedButton.icon(
                onPressed: _logout,
                icon: const Icon(
                  Icons.logout_rounded,
                  color: Colors.black,
                ),
                label: const Text(
                  'Log out',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.black,
                  ),
                ),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(
                    color: Colors.black,
                    width: 1.2,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(27),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Center(
              child: Text(
                'MtaaWorks v1.0.0',
                style: TextStyle(
                  color: Colors.grey.shade400,
                  fontSize: 12,
                ),
              ),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}


class _DeleteAccountSheet extends StatefulWidget {
  const _DeleteAccountSheet({required this.email});

  final String email;

  @override
  State<_DeleteAccountSheet> createState() =>
      _DeleteAccountSheetState();
}

class _DeleteAccountSheetState extends State<_DeleteAccountSheet> {
  final TextEditingController _codeController = TextEditingController();

  bool _codeSent = false;
  bool _sendingCode = false;
  bool _deleting = false;

  bool get _codeReady =>
      RegExp(r'^\d{6}$').hasMatch(_codeController.text.trim());

  @override
  void dispose() {
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

  Future<void> _requestCode() async {
    if (_sendingCode || _deleting) return;

    setState(() => _sendingCode = true);

    try {
      final result = await ApiService.requestAccountDeletion();

      if (!mounted) return;

      setState(() => _codeSent = true);

      _showMessage(
        result['message']?.toString() ??
            'Verification code sent to your email.',
      );
    } catch (e) {
      _showMessage(_errorMessage(e));
    } finally {
      if (mounted) {
        setState(() => _sendingCode = false);
      }
    }
  }

  Future<void> _deleteAccount() async {
    if (!_codeReady || _deleting || _sendingCode) return;

    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Permanently delete account?'),
        content: const Text(
          'Your account will be permanently deleted. '
              'This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () =>
                Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: _red,
            ),
            onPressed: () =>
                Navigator.of(dialogContext).pop(true),
            child: const Text('Delete permanently'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    setState(() => _deleting = true);

    try {
      await ApiService.deleteAccount(
        code: _codeController.text.trim(),
      );

      if (!mounted) return;

      // The parent clears the token and navigates to the entry screen.
      Navigator.of(context).pop(true);
    } catch (e) {
      _showMessage(_errorMessage(e));
    } finally {
      if (mounted) {
        setState(() => _deleting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return SafeArea(
      top: false,
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          24,
          12,
          24,
          24 + bottomInset,
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 44,
                  height: 5,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Center(
                child: Container(
                  width: 64,
                  height: 64,
                  decoration: const BoxDecoration(
                    color: _redSoft,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.delete_outline_rounded,
                    color: _red,
                    size: 30,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Delete your account?',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),

              if (!_codeSent) ...[
                Text(
                  'This permanently deletes everything linked to your '
                      'account. It cannot be undone.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.grey.shade600,
                    fontSize: 14,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 18),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: _cardFill,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.grey.shade200),
                  ),
                  child: const Column(
                    children: [
                      _BulletLine('Your profile and sign-in'),
                      _BulletLine('Your consent records'),
                      _BulletLine('Your stored statements and scores'),
                      _BulletLine(
                        'All lender access to your score',
                        last: true,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                _SolidButton(
                  label: _sendingCode
                      ? 'Sending code...'
                      : 'Email me a confirmation code',
                  color: _red,
                  onPressed: _sendingCode || _deleting
                      ? null
                      : _requestCode,
                ),
              ] else ...[
                Text(
                  'Enter the six-digit code sent to\n${widget.email}.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.grey.shade600,
                    fontSize: 14,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 20),
                TextField(
                  controller: _codeController,
                  keyboardType: TextInputType.number,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                  ],
                  maxLength: 6,
                  enabled: !_deleting,
                  textAlign: TextAlign.center,
                  onChanged: (_) => setState(() {}),
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
                    fillColor: const Color(0xFFF9FAFB),
                    contentPadding: const EdgeInsets.symmetric(
                      vertical: 16,
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide(
                        color: Colors.grey.shade300,
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: const BorderSide(
                        color: _red,
                        width: 1.2,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                _SolidButton(
                  label: _deleting
                      ? 'Deleting account...'
                      : 'Delete my account',
                  color: _red,
                  onPressed: _codeReady && !_deleting && !_sendingCode
                      ? _deleteAccount
                      : null,
                ),
                TextButton(
                  onPressed: _sendingCode || _deleting
                      ? null
                      : _requestCode,
                  child: Text(
                    _sendingCode ? 'Sending code...' : 'Resend code',
                    style: const TextStyle(
                      color: _purple,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],

              TextButton(
                onPressed: _deleting || _sendingCode
                    ? null
                    : () => Navigator.of(context).pop(false),
                child: Text(
                  'Cancel',
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

class _SolidButton extends StatelessWidget {
  const _SolidButton({
    required this.label,
    required this.color,
    required this.onPressed,
  });

  final String label;
  final Color color;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 54,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          disabledBackgroundColor: Colors.grey.shade400,
          shadowColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(27),
          ),
        ),
        child: Text(
          label,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
      ),
    );
  }
}

class _BulletLine extends StatelessWidget {
  const _BulletLine(this.text, {this.last = false});

  final String text;
  final bool last;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: last ? 0 : 8),
      child: Row(
        children: [
          const Icon(Icons.close_rounded, size: 16, color: _red),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                color: Colors.grey.shade700,
                fontSize: 13.5,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ------------------------------------------------------------
// Shared UI components

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 17,
        fontWeight: FontWeight.bold,
        color: Colors.black,
      ),
    );
  }
}

class _Card extends StatelessWidget {
  const _Card({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: _cardFill,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(children: children),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({
    required this.label,
    required this.value,
    this.chip,
    this.trailing,
    this.last = false,
  });

  final String label;
  final String value;
  final Widget? chip;
  final Widget? trailing;
  final bool last;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 16,
        vertical: 14,
      ),
      decoration: BoxDecoration(
        border: last
            ? null
            : Border(
          bottom: BorderSide(color: Colors.grey.shade200),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    color: Colors.grey.shade500,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
                ),
              ],
            ),
          ),
          if (chip != null) chip!,
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}

class _SettingsRow extends StatelessWidget {
  const _SettingsRow({
    required this.icon,
    required this.title,
    this.subtitle,
    this.trailing,
    this.onTap,
    this.iconColor = _purple,
    this.titleColor = Colors.black87,
    this.last = false,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;
  final Color iconColor;
  final Color titleColor;
  final bool last;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
        decoration: BoxDecoration(
          border: last
              ? null
              : Border(
            bottom: BorderSide(color: Colors.grey.shade200),
          ),
        ),
        child: Row(
          children: [
            Icon(icon, color: iconColor),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 14.5,
                      fontWeight: FontWeight.w600,
                      color: titleColor,
                    ),
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      subtitle!,
                      style: TextStyle(
                        color: Colors.grey.shade500,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            trailing ??
                Icon(
                  Icons.chevron_right_rounded,
                  color: Colors.grey.shade400,
                ),
          ],
        ),
      ),
    );
  }
}
