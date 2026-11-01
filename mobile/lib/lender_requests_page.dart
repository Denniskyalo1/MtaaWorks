
import 'package:flutter/material.dart';
import 'package:mtaaworks/services/api_service.dart';

class LenderRequestsPage extends StatefulWidget {
  const LenderRequestsPage({super.key});

  @override
  State<LenderRequestsPage> createState() =>
      _LenderRequestsPageState();
}

class _LenderRequestsPageState extends State<LenderRequestsPage> {
  static const Color primaryPurple = Color(0xFF6828D9);
  static const Color darkText = Color(0xFF111936);
  static const Color mutedText = Color(0xFF68738A);
  static const Color borderColor = Color(0xFFE2E8F2);
  static const Color green = Color(0xFF15945B);
  static const Color red = Color(0xFFEF4444);

  int selectedTab = 0;


  List<Map<String, dynamic>> pendingRequests = [];
  List<Map<String, dynamic>> approvedGrants = [];

  bool isLoading = true;
  bool isPerformingAction = false;
  String? loadError;

  @override
  void initState() {
    super.initState();
    loadRequests();
  }

  String formatDate(dynamic value) {
    if (value == null) return 'Not available';

    final date = DateTime.tryParse(value.toString())?.toLocal();
    if (date == null) return 'Not available';

    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];

    return '${months[date.month - 1]} ${date.day}, ${date.year}';
  }

  Future<void> loadRequests() async {
    setState(() {
      isLoading = true;
      loadError = null;
    });

    try {
      final response = await ApiService.getAccessRequests();
      final rawRequests = response['requests'];

      if (rawRequests is! List) {
        throw Exception('The server returned an invalid requests list.');
      }

      final pending = <Map<String, dynamic>>[];
      final approved = <Map<String, dynamic>>[];

      for (final item in rawRequests) {
        if (item is! Map) continue;

        final grant = Map<String, dynamic>.from(item);
        final lenderValue = grant['lender'];

        final lender = lenderValue is Map
            ? Map<String, dynamic>.from(lenderValue)
            : <String, dynamic>{};

        final status = grant['status']?.toString();

        final card = <String, dynamic>{
          ...grant,
          'name': lender['name']?.toString() ?? 'Unknown lender',
          'type': switch (lender['type']?.toString()) {
            'mfi' => 'Microfinance',
            'bank' => 'Bank',
            'sacco' => 'SACCO',
            _ => lender['type']?.toString() ?? 'Lender',
          },
          'scope': formatScope(grant['scope']),
          'date': formatDate(grant['requested_at']),
          'expiry': formatDate(grant['expires_at']),
          'views': grant['view_count'] ?? 0,
          'color': status == 'approved'
              ? green
              : const Color(0xFF1761B5),
          'background': status == 'approved'
              ? const Color(0xFFDDF5E8)
              : const Color(0xFFE1EFFF),
          'icon': Icons.account_balance_rounded,
        };

        if (status == 'requested') {
          pending.add(card);
        } else if (status == 'approved') {
          approved.add(card);
        }
      }

      if (!mounted) return;

      setState(() {
        pendingRequests = pending;
        approvedGrants = approved;
        isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        loadError = e.toString().replaceFirst('Exception: ', '');
        isLoading = false;
      });
    }
  }


  String formatScope(dynamic value) {
    if (value is List) {
      return value.map((item) => formatScope(item)).join(' and ');
    }

    switch (value?.toString()) {
      case 'score_tier':
        return 'View your credit score tier';
      case 'credit_score':
        return 'View your credit score';
      case 'transaction_history':
        return 'View your transaction history';
      case 'profile':
        return 'View your basic profile';
      default:
        return value?.toString().replaceAll('_', ' ') ??
            'View your credit score';
    }
  }



  Future<void> performRequestAction(
      Map<String, dynamic> item,
      String action,
      ) async {
    if (isPerformingAction) return;

    final id = int.tryParse(item['id'].toString());

    if (id == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Invalid lender request ID.')),
      );
      return;
    }

    setState(() => isPerformingAction = true);

    try {
      final result = await ApiService.respondToAccessRequest(
        grantId: id,
        action: action,
      );

      await loadRequests();

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            result['message']?.toString() ?? 'Request updated successfully.',
          ),
          backgroundColor: green,
        ),
      );

      if (action == 'approve') {
        setState(() => selectedTab = 1);
      }
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString().replaceFirst('Exception: ', '')),
          backgroundColor: red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => isPerformingAction = false);
      }
    }
  }

  void approveRequest(Map<String, dynamic> request) {
    performRequestAction(request, 'approve');
  }

  void declineRequest(Map<String, dynamic> request) {
    performRequestAction(request, 'decline');
  }

  void revokeGrant(Map<String, dynamic> grant) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Revoke access?'),
        content: Text(
          'Are you sure you want to revoke ${grant['name']}\'s access?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(dialogContext);
              performRequestAction(grant, 'revoke');
            },
            child: const Text(
              'Revoke',
              style: TextStyle(color: red),
            ),
          ),
        ],
      ),
    );
  }


  @override
  Widget build(BuildContext context) {
    final isPendingTab = selectedTab == 0;
    final requests = isPendingTab ? pendingRequests : approvedGrants;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        elevation: 0,
        title: const Text(
          'Lender Requests',
          style: TextStyle(
            color: darkText,
            fontSize: 22,
            fontWeight: FontWeight.w700,
          ),
        ),
        centerTitle: false,
        actions: [
          IconButton(
            onPressed: showAccessInfo,
            icon: const Icon(Icons.info_outline_rounded),
            color: darkText,
            tooltip: 'About lender access',
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            const SizedBox(height: 14),
            _buildTabs(),
            const SizedBox(height: 24),
            Expanded(
              child: isLoading
                  ? const Center(
                child: CircularProgressIndicator(
                  color: primaryPurple,
                ),
              )
                  : loadError != null
                  ? Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.cloud_off_outlined,
                        size: 48,
                        color: mutedText,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        loadError!,
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: mutedText),
                      ),
                      const SizedBox(height: 12),
                      ElevatedButton(
                        onPressed: loadRequests,
                        child: const Text('Try again'),
                      ),
                    ],
                  ),
                ),
              )
                  : requests.isEmpty
                  ? _buildEmptyState(isPendingTab)
                  : ListView(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                children: [
                  Text(
                    isPendingTab
                        ? '${pendingRequests.length} Pending '
                        '${pendingRequests.length == 1 ? 'Request' : 'Requests'}'
                        : '${approvedGrants.length} Approved '
                        '${approvedGrants.length == 1 ? 'Grant' : 'Grants'}',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: darkText,
                    ),
                  ),
                  const SizedBox(height: 16),
                  if (isPendingTab)
                    ...pendingRequests.map(
                          (request) => Padding(
                        key: ValueKey(request['id']),
                        padding: const EdgeInsets.only(bottom: 14),
                        child: _buildRequestCard(request),
                      ),
                    )
                  else
                    ...approvedGrants.map(
                          (grant) => Padding(
                        key: ValueKey(grant['id']),
                        padding: const EdgeInsets.only(bottom: 14),
                        child: _buildGrantCard(grant),
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

  Widget _buildTabs() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F2F6),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          _tabButton('Pending Requests', 0),
          _tabButton('Approved Grants', 1),
        ],
      ),
    );
  }

  Widget _tabButton(String label, int index) {
    final selected = selectedTab == index;

    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => selectedTab = index),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(
            vertical: 15,
            horizontal: 4,
          ),
          decoration: BoxDecoration(
            color: selected ? primaryPurple : Colors.transparent,
            borderRadius: BorderRadius.circular(15),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: selected ? Colors.white : darkText,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildRequestCard(Map<String, dynamic> request) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: borderColor),
        borderRadius: BorderRadius.circular(17),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.025),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildLenderHeader(request),
          const SizedBox(height: 22),
          _detailRow(
            Icons.article_outlined,
            'Requested access',
            request['scope'] as String,
          ),
          const SizedBox(height: 16),
          _detailRow(
            Icons.calendar_month_outlined,
            'Requested on',
            request['date'] as String,
          ),
          const SizedBox(height: 22),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: isPerformingAction
                      ? null
                      : () => declineRequest(request),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: darkText,
                    side: const BorderSide(color: Color(0xFF9AA3B5)),
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(28),
                    ),
                  ),
                  child: const Text(
                    'Decline',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ElevatedButton(
                  onPressed: isPerformingAction
                      ? null
                      : () => approveRequest(request),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryPurple,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(28),
                    ),
                  ),
                  child: const Text(
                    'Approve',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildGrantCard(Map<String, dynamic> grant) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFFFBFEFC),
        border: Border.all(color: const Color(0xFFD4EFE0)),
        borderRadius: BorderRadius.circular(17),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildLenderHeader(grant),
          const SizedBox(height: 24),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _detailRow(
                  Icons.schedule_rounded,
                  'Expires on',
                  grant['expiry'] as String,
                ),
              ),
              Container(
                width: 1,
                height: 48,
                margin: const EdgeInsets.symmetric(horizontal: 12),
                color: borderColor,
              ),
              Expanded(
                child: _detailRow(
                  Icons.visibility_outlined,
                  'Viewed',
                  '${grant['views']} ${grant['views'] == 1 ? 'time' : 'times'}',
                ),
              ),
            ],
          ),
          const SizedBox(height: 22),
          Align(
            alignment: Alignment.centerRight,
            child: OutlinedButton.icon(
              onPressed: isPerformingAction
                  ? null
                  : () => revokeGrant(grant),
              icon: const Icon(Icons.delete_outline_rounded, size: 18),
              label: const Text('Revoke'),
              style: OutlinedButton.styleFrom(
                foregroundColor: red,
                side: const BorderSide(color: Color(0xFFFFA0A0)),
                padding: const EdgeInsets.symmetric(
                  horizontal: 18,
                  vertical: 10,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(28),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLenderHeader(Map<String, dynamic> lender) {
    final color = lender['color'] as Color;
    final background = lender['background'] as Color;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          width: 54,
          height: 54,
          decoration: BoxDecoration(
            color: background,
            shape: BoxShape.circle,
          ),
          child: Icon(
            lender['icon'] as IconData,
            color: color,
            size: 28,
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                lender['name'] as String,
                style: const TextStyle(
                  color: darkText,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 7),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 11,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: background,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  lender['type'] as String,
                  style: TextStyle(
                    color: color,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _detailRow(IconData icon, String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 20, color: mutedText),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  color: mutedText,
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                value,
                style: const TextStyle(
                  color: darkText,
                  fontSize: 13,
                  height: 1.4,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyState(bool isPendingTab) {
    final title = isPendingTab
        ? 'No lender requests'
        : 'No approved grants';

    final message = isPendingTab
        ? 'You don’t have any pending lender requests right now.'
        : 'You haven’t granted any lenders access to your information.';

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 34),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 112,
              height: 112,
              decoration: BoxDecoration(
                color: const Color(0xFFF3EDFF),
                borderRadius: BorderRadius.circular(36),
              ),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  const Icon(
                    Icons.description_outlined,
                    size: 58,
                    color: Color(0xFF8C7AC6),
                  ),
                  Positioned(
                    right: 16,
                    bottom: 17,
                    child: Container(
                      width: 32,
                      height: 32,
                      decoration: const BoxDecoration(
                        color: primaryPurple,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.access_time_rounded,
                        size: 19,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: darkText,
                fontSize: 20,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: mutedText,
                fontSize: 14,
                height: 1.6,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void showAccessInfo() {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Your lender access'),
        content: const Text(
          'Review what each lender is asking to access before approving. '
              'You can revoke approved access at any time. Only grant access '
              'to information you are comfortable sharing.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              'Got it',
              style: TextStyle(color: primaryPurple),
            ),
          ),
        ],
      ),
    );
  }
}
