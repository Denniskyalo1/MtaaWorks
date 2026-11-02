import 'package:flutter/material.dart';

import '../api_service.dart';
import 'admin_widgets.dart';

/// System-wide counts. Aggregates only: no individual scores are shown.
class AdminDashboardPage extends StatefulWidget {
  const AdminDashboardPage({super.key});

  @override
  State<AdminDashboardPage> createState() => _AdminDashboardPageState();
}

class _AdminDashboardPageState extends State<AdminDashboardPage> {
  Map<String, dynamic>? _data;
  String? _error;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final data = await ApiService.getAdminDashboard();
      if (!mounted) return;
      setState(() => _data = data);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = errorText(e));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Map<String, dynamic> _map(String key) {
    final value = _data?[key];
    return value is Map<String, dynamic> ? value : <String, dynamic>{};
  }

  int _int(dynamic value) => int.tryParse(value?.toString() ?? '') ?? 0;

  @override
  Widget build(BuildContext context) {
    if (_loading && _data == null) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null && _data == null) {
      return ErrorState(message: _error!, onRetry: _load);
    }

    final borrowers = _map('borrowers');
    final lenders = _map('lenders_by_status');
    final scores = _map('scores');
    final grants = _map('grants_by_status');
    final loans = _map('loan_requests_by_status');
    final roles = _map('users_by_role');

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          PageHeader(
            title: 'Dashboard',
            subtitle: 'Platform activity at a glance. Counts only, no individual scores.',
            action: IconButton(
              tooltip: 'Refresh',
              onPressed: _loading ? null : _load,
              icon: const Icon(Icons.refresh_rounded),
            ),
          ),
          _Section(
            title: 'Borrowers',
            stats: [
              _Stat('Total borrowers', _int(borrowers['total']), Icons.people_outline),
              _Stat('Email verified', _int(borrowers['email_verified']), Icons.mark_email_read_outlined),
              _Stat('Phone verified', _int(borrowers['phone_verified']), Icons.verified_outlined),
              _Stat('New in last 7 days', _int(borrowers['new_last_7_days']), Icons.person_add_alt_outlined),
            ],
          ),
          _Section(
            title: 'Lenders and staff',
            stats: [
              _Stat('Active lenders', _int(lenders['active']), Icons.account_balance_outlined),
              _Stat('Suspended lenders', _int(lenders['suspended']), Icons.block_outlined),
              _Stat('Lender staff accounts', _int(roles['lender']), Icons.badge_outlined),
              _Stat('Admin accounts', _int(roles['admin']), Icons.admin_panel_settings_outlined),
            ],
          ),
          _Section(
            title: 'Scoring',
            stats: [
              _Stat('Scores generated', _int(scores['total']), Icons.insights_outlined),
              _Stat('Scores in last 7 days', _int(scores['last_7_days']), Icons.trending_up_rounded),
              _Stat('Lender score views (7 days)', _int(_data?['score_views_last_7_days']), Icons.visibility_outlined),
            ],
          ),
          _BreakdownSection(title: 'Access grants by status', counts: grants),
          _BreakdownSection(title: 'Loan requests by status', counts: loans),
        ],
      ),
    );
  }
}

class _Stat {
  const _Stat(this.label, this.value, this.icon);

  final String label;
  final int value;
  final IconData icon;
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.stats});

  final String title;
  final List<_Stat> stats;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AdminColors.text),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 14,
            runSpacing: 14,
            children: [for (final s in stats) _StatCard(stat: s)],
          ),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({required this.stat});

  final _Stat stat;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 220,
      child: AdminCard(
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: AdminColors.primarySoft,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(stat.icon, color: AdminColors.primary, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${stat.value}',
                    style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: AdminColors.text),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    stat.label,
                    style: const TextStyle(fontSize: 12.5, color: AdminColors.muted),
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

/// A status -> count breakdown, e.g. requested 3, approved 5, revoked 1.
class _BreakdownSection extends StatelessWidget {
  const _BreakdownSection({required this.title, required this.counts});

  final String title;
  final Map<String, dynamic> counts;

  @override
  Widget build(BuildContext context) {
    final entries = counts.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));

    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: AdminCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AdminColors.text),
            ),
            const SizedBox(height: 12),
            if (entries.isEmpty)
              const Text('Nothing yet.', style: TextStyle(color: AdminColors.muted))
            else
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  for (final e in entries)
                    StatusChip('${humanise(e.key)}: ${e.value}', tone: ChipTone.brand),
                ],
              ),
          ],
        ),
      ),
    );
  }
}
