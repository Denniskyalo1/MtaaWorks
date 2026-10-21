
import 'package:flutter/material.dart';

import 'login_page.dart';
import 'api_service.dart';

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  static const Color primary = Color(0xFF5B3CC4);
  static const Color background = Color(0xFFF7F6FC);

  List<Map<String, dynamic>> _grants = [];
  bool _isLoading = true;
  bool _isRequesting = false;
  String? _errorMessage;
  String _filter = 'all';

  @override
  void initState() {
    super.initState();
    _loadGrants();
  }

  Future<void> _loadGrants() async {
    if (mounted) {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });
    }

    try {
      final grants = await ApiService.getGrants();

      if (!mounted) return;

      setState(() {
        _grants = grants;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _errorMessage = _cleanError(e);
        _isLoading = false;
      });
    }
  }

  String _cleanError(Object error) {
    return error.toString().replaceFirst('Exception: ', '');
  }

  int _countStatus(String status) {
    return _grants
        .where((grant) => grant['status']?.toString() == status)
        .length;
  }

  List<Map<String, dynamic>> get _filteredGrants {
    if (_filter == 'all') return _grants;

    return _grants
        .where((grant) => grant['status']?.toString() == _filter)
        .toList();
  }

  String _formatDate(dynamic value) {
    if (value == null || value.toString().isEmpty) return '—';

    final date = DateTime.tryParse(value.toString());
    if (date == null) return value.toString();

    final local = date.toLocal();

    return '${local.day.toString().padLeft(2, '0')}/'
        '${local.month.toString().padLeft(2, '0')}/'
        '${local.year}';
  }

  String _scopeLabel(dynamic value) {
    switch (value?.toString()) {
      case 'score_tier':
        return 'Score & tier';
      case 'score_tier_drivers':
        return 'Score, tier & drivers';
      default:
        return value?.toString() ?? '—';
    }
  }

  Color _statusColor(String status) {
    switch (status.toLowerCase()) {
      case 'approved':
        return const Color(0xFF16805D);
      case 'requested':
        return const Color(0xFFB7791F);
      case 'declined':
      case 'revoked':
        return const Color(0xFFB42318);
      case 'expired':
        return const Color(0xFF667085);
      default:
        return primary;
    }
  }

  void _showMessage(String message, {bool isError = false}) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor:
        isError ? const Color(0xFFB42318) : const Color(0xFF16805D),
      ),
    );
  }

  Future<void> _showRequestDialog() async {
    final formKey = GlobalKey<FormState>();
    final emailController = TextEditingController();

    String selectedScope = 'score_tier';
    String? dialogError;

    await showDialog<void>(
      context: context,
      barrierDismissible: !_isRequesting,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Request score access'),
              content: SizedBox(
                width: 440,
                child: Form(
                  key: formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Enter the email address associated with '
                            'the borrower’s MtaaWorks account.',
                      ),
                      const SizedBox(height: 20),
                      TextFormField(
                        controller: emailController,
                        keyboardType: TextInputType.emailAddress,
                        decoration: const InputDecoration(
                          labelText: 'Borrower email',
                          hintText: 'borrower@example.com',
                          prefixIcon: Icon(Icons.email_outlined),
                          border: OutlineInputBorder(),
                        ),
                        validator: (value) {
                          final email = value?.trim() ?? '';

                          if (email.isEmpty) {
                            return 'Enter the borrower’s email';
                          }

                          if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$')
                              .hasMatch(email)) {
                            return 'Enter a valid email address';
                          }

                          return null;
                        },
                      ),
                      const SizedBox(height: 20),
                      const Text(
                        'Access scope',
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 8),
                      RadioListTile<String>(
                        contentPadding: EdgeInsets.zero,
                        value: 'score_tier',
                        groupValue: selectedScope,
                        onChanged: _isRequesting
                            ? null
                            : (value) {
                          if (value != null) {
                            setDialogState(
                                  () => selectedScope = value,
                            );
                          }
                        },
                        title: const Text('Score and risk tier'),
                        subtitle: const Text(
                          'Request access to the score and risk tier.',
                        ),
                      ),
                      RadioListTile<String>(
                        contentPadding: EdgeInsets.zero,
                        value: 'score_tier_drivers',
                        groupValue: selectedScope,
                        onChanged: _isRequesting
                            ? null
                            : (value) {
                          if (value != null) {
                            setDialogState(
                                  () => selectedScope = value,
                            );
                          }
                        },
                        title: const Text('Score, tier and drivers'),
                        subtitle: const Text(
                          'Also request the top factors influencing the score.',
                        ),
                      ),
                      if (dialogError != null) ...[
                        const SizedBox(height: 8),
                        Text(
                          dialogError!,
                          style: const TextStyle(
                            color: Color(0xFFB42318),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: _isRequesting
                      ? null
                      : () => Navigator.of(dialogContext).pop(),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: _isRequesting
                      ? null
                      : () async {
                    if (!formKey.currentState!.validate()) return;

                    setDialogState(() {
                      _isRequesting = true;
                      dialogError = null;
                    });

                    try {
                      final message = await ApiService.requestAccess(
                        borrowerEmail: emailController.text,
                        scope: selectedScope,
                      );

                      if (!mounted) return;

                      Navigator.of(dialogContext).pop();
                      _showMessage(message);
                      await _loadGrants();
                    } catch (e) {
                      setDialogState(() {
                        _isRequesting = false;
                        dialogError = _cleanError(e);
                      });
                    }
                  },
                  style: FilledButton.styleFrom(
                    backgroundColor: primary,
                  ),
                  child: _isRequesting
                      ? const SizedBox(
                    height: 18,
                    width: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                      : const Text('Send request'),
                ),
              ],
            );
          },
        );
      },
    );

    emailController.dispose();

    if (mounted) {
      setState(() => _isRequesting = false);
    }
  }

  Future<void> _showScore(Map<String, dynamic> grant) async {
    final rawId = grant['id'];
    final grantId = rawId is int ? rawId : int.tryParse('$rawId');

    if (grantId == null) {
      _showMessage('This grant has an invalid ID.', isError: true);
      return;
    }

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return FutureBuilder<Map<String, dynamic>>(
          future: ApiService.getGrantScore(grantId),
          builder: (context, snapshot) {
            return AlertDialog(
              title: const Text('Approved credit score'),
              content: SizedBox(
                width: 440,
                child: _buildScoreContent(snapshot),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  child: const Text('Close'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildScoreContent(
      AsyncSnapshot<Map<String, dynamic>> snapshot,
      ) {
    if (snapshot.connectionState == ConnectionState.waiting) {
      return const Padding(
        padding: EdgeInsets.all(32),
        child: Center(child: CircularProgressIndicator()),
      );
    }

    if (snapshot.hasError) {
      return Text(
        _cleanError(snapshot.error!),
        style: const TextStyle(color: Color(0xFFB42318)),
      );
    }

    final score = snapshot.data!;

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: const Color(0xFFF0EBFF),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              children: [
                const Text(
                  'CREDIT SCORE',
                  style: TextStyle(
                    letterSpacing: 1.5,
                    fontWeight: FontWeight.w600,
                    color: primary,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '${score['score'] ?? '—'}',
                  style: const TextStyle(
                    fontSize: 42,
                    fontWeight: FontWeight.bold,
                    color: primary,
                  ),
                ),
                Text(
                  'Risk tier: ${score['risk_tier'] ?? '—'}',
                  style: const TextStyle(fontSize: 16),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          _detailRow(
            'High risk',
            score['high_risk'] == true ? 'Yes' : 'No',
          ),
          _detailRow('Model version', '${score['model_version'] ?? '—'}'),
          _detailRow('Scored at', _formatDate(score['scored_at'])),
          _detailRow(
            'Access expires',
            _formatDate(score['access_expires_at']),
          ),
          if (score['top_drivers'] is List) ...[
            const SizedBox(height: 16),
            const Text(
              'Top score drivers',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 8),
            ...((score['top_drivers'] as List).map((driver) {
              if (driver is Map) {
                return ListTile(
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                  title: Text(
                    '${driver['feature'] ?? driver['name'] ?? 'Driver'}',
                  ),
                  subtitle: Text(
                    '${driver['value'] ?? driver['contribution'] ?? ''}',
                  ),
                );
              }

              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Text('$driver'),
              );
            })),
          ],
          const SizedBox(height: 8),
          const Text(
            'Use this information only within the scope approved by the borrower.',
            style: TextStyle(fontSize: 12, color: Colors.black54),
          ),
        ],
      ),
    );
  }

  Widget _detailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(color: Colors.black54),
            ),
          ),
          const SizedBox(width: 12),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _logout() async {
    await ApiService.logout();

    if (!mounted) return;

    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginPage()),
          (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final approved = _countStatus('approved');
    final requested = _countStatus('requested');
    final expired = _countStatus('expired');
    final other = _grants.length - approved - requested - expired;

    return Scaffold(
      backgroundColor: background,
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        elevation: 0,
        title: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.account_balance_rounded, color: primary, size: 29),
            SizedBox(width: 10),
            Text(
              'MtaaWorks',
              style: TextStyle(
                color: Color(0xFF29243C),
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(width: 8),
            Text(
              'LENDER PORTAL',
              style: TextStyle(
                color: primary,
                fontSize: 11,
                fontWeight: FontWeight.bold,
                letterSpacing: 1,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: _isLoading ? null : _loadGrants,
            icon: const Icon(Icons.refresh_rounded),
          ),
          const SizedBox(width: 8),
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: TextButton.icon(
              onPressed: _logout,
              icon: const Icon(Icons.logout_rounded),
              label: const Text('Logout'),
            ),
          ),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1400),
          child: ListView(
            padding: const EdgeInsets.all(24),
            children: [
              Wrap(
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.center,
                runSpacing: 16,
                spacing: 16,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Lender dashboard',
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF29243C),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Manage borrower score access and approved grants.',
                        style: TextStyle(color: Colors.grey.shade700),
                      ),
                    ],
                  ),
                  FilledButton.icon(
                    onPressed: _showRequestDialog,
                    icon: const Icon(Icons.add_rounded),
                    label: const Text('Request access'),
                    style: FilledButton.styleFrom(
                      backgroundColor: primary,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 16,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 28),
              if (_errorMessage != null)
                Container(
                  margin: const EdgeInsets.only(bottom: 20),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF0F0),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.error_outline,
                        color: Color(0xFFB42318),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          _errorMessage!,
                          style: const TextStyle(
                            color: Color(0xFFB42318),
                          ),
                        ),
                      ),
                      TextButton(
                        onPressed: _loadGrants,
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                ),
              if (_isLoading && _grants.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(60),
                  child: Center(child: CircularProgressIndicator()),
                )
              else ...[
                LayoutBuilder(
                  builder: (context, constraints) {
                    final columns = constraints.maxWidth >= 1000
                        ? 4
                        : constraints.maxWidth >= 600
                        ? 2
                        : 1;
                    const gap = 16.0;
                    final cardWidth =
                        (constraints.maxWidth - gap * (columns - 1)) /
                            columns;

                    return Wrap(
                      spacing: gap,
                      runSpacing: gap,
                      children: [
                        SizedBox(
                          width: cardWidth,
                          child: _statCard(
                            'Total requests',
                            '${_grants.length}',
                            Icons.folder_open_rounded,
                            const Color(0xFF5B3CC4),
                          ),
                        ),
                        SizedBox(
                          width: cardWidth,
                          child: _statCard(
                            'Approved',
                            '$approved',
                            Icons.verified_user_outlined,
                            const Color(0xFF16805D),
                          ),
                        ),
                        SizedBox(
                          width: cardWidth,
                          child: _statCard(
                            'Pending',
                            '$requested',
                            Icons.hourglass_top_rounded,
                            const Color(0xFFB7791F),
                          ),
                        ),
                        SizedBox(
                          width: cardWidth,
                          child: _statCard(
                            'Other statuses',
                            '$other expired: $expired',
                            Icons.history_rounded,
                            const Color(0xFF667085),
                          ),
                        ),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 32),
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: const Color(0xFFECE9F5)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Wrap(
                        alignment: WrapAlignment.spaceBetween,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        runSpacing: 12,
                        spacing: 12,
                        children: [
                          const Text(
                            'Access requests and grants',
                            style: TextStyle(
                              fontSize: 19,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          DropdownButton<String>(
                            value: _filter,
                            underline: const SizedBox.shrink(),
                            items: const [
                              DropdownMenuItem(
                                value: 'all',
                                child: Text('All statuses'),
                              ),
                              DropdownMenuItem(
                                value: 'requested',
                                child: Text('Pending'),
                              ),
                              DropdownMenuItem(
                                value: 'approved',
                                child: Text('Approved'),
                              ),
                              DropdownMenuItem(
                                value: 'declined',
                                child: Text('Declined'),
                              ),
                              DropdownMenuItem(
                                value: 'revoked',
                                child: Text('Revoked'),
                              ),
                              DropdownMenuItem(
                                value: 'expired',
                                child: Text('Expired'),
                              ),
                            ],
                            onChanged: (value) {
                              if (value != null) {
                                setState(() => _filter = value);
                              }
                            },
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      if (_filteredGrants.isEmpty)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 42),
                          child: Center(
                            child: Column(
                              children: [
                                Icon(
                                  Icons.inbox_outlined,
                                  size: 48,
                                  color: Colors.grey.shade400,
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  _grants.isEmpty
                                      ? 'No access requests yet'
                                      : 'No grants match this filter',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                const Text(
                                  'Use “Request access” to contact a borrower.',
                                  textAlign: TextAlign.center,
                                ),
                              ],
                            ),
                          ),
                        )
                      else
                        SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: DataTable(
                            headingRowColor: WidgetStateProperty.all(
                              const Color(0xFFF8F7FC),
                            ),
                            columns: const [
                              DataColumn(label: Text('Borrower')),
                              DataColumn(label: Text('Scope')),
                              DataColumn(label: Text('Status')),
                              DataColumn(label: Text('Requested')),
                              DataColumn(label: Text('Expires')),
                              DataColumn(label: Text('Action')),
                            ],
                            rows: _filteredGrants.map((grant) {
                              final borrower = grant['borrower'];
                              final borrowerMap =
                              borrower is Map ? borrower : null;
                              final status =
                                  grant['status']?.toString() ?? 'unknown';
                              final borrowerName =
                              borrowerMap?['name']?.toString();
                              final borrowerEmail =
                              borrowerMap?['email']?.toString();

                              return DataRow(
                                cells: [
                                  DataCell(
                                    SizedBox(
                                      width: 190,
                                      child: Column(
                                        mainAxisAlignment:
                                        MainAxisAlignment.center,
                                        crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            borrowerName ?? 'Not yet approved',
                                            overflow: TextOverflow.ellipsis,
                                            style: const TextStyle(
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                          if (borrowerEmail != null)
                                            Text(
                                              borrowerEmail,
                                              overflow: TextOverflow.ellipsis,
                                              style: const TextStyle(
                                                fontSize: 12,
                                                color: Colors.black54,
                                              ),
                                            ),
                                        ],
                                      ),
                                    ),
                                  ),
                                  DataCell(Text(_scopeLabel(grant['scope']))),
                                  DataCell(
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 10,
                                        vertical: 6,
                                      ),
                                      decoration: BoxDecoration(
                                        color: _statusColor(status)
                                            .withValues(alpha: 0.10),
                                        borderRadius:
                                        BorderRadius.circular(30),
                                      ),
                                      child: Text(
                                        status.toUpperCase(),
                                        style: TextStyle(
                                          color: _statusColor(status),
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ),
                                  DataCell(
                                    Text(_formatDate(grant['requested_at'])),
                                  ),
                                  DataCell(
                                    Text(_formatDate(grant['expires_at'])),
                                  ),
                                  DataCell(
                                    status == 'approved'
                                        ? TextButton.icon(
                                      onPressed: () =>
                                          _showScore(grant),
                                      icon: const Icon(
                                        Icons.visibility_outlined,
                                        size: 18,
                                      ),
                                      label: const Text('View score'),
                                    )
                                        : const Text(
                                      '—',
                                      style: TextStyle(
                                        color: Colors.black38,
                                      ),
                                    ),
                                  ),
                                ],
                              );
                            }).toList(),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                const Row(
                  children: [
                    Icon(
                      Icons.lock_outline_rounded,
                      size: 18,
                      color: Color(0xFF667085),
                    ),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Borrower score information is available only when '
                            'access has been approved and remains valid.',
                        style: TextStyle(
                          fontSize: 12,
                          color: Color(0xFF667085),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _statCard(
      String title,
      String value,
      IconData icon,
      Color color,
      ) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFECE9F5)),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: color, size: 25),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.black54,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 23,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF29243C),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
