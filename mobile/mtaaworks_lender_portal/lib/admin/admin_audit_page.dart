import 'package:flutter/material.dart';

import '../api_service.dart';
import 'admin_widgets.dart';

enum _AuditView { adminActions, scoreViews }

/// Two trails: what admins did, and when lender staff opened a borrower's score.
class AdminAuditPage extends StatefulWidget {
  const AdminAuditPage({super.key});

  @override
  State<AdminAuditPage> createState() => _AdminAuditPageState();
}

class _AdminAuditPageState extends State<AdminAuditPage> {
  _AuditView _view = _AuditView.adminActions;
  List<Map<String, dynamic>> _rows = [];
  int _page = 1;
  int _lastPage = 1;
  bool _loading = true;
  bool _loadingMore = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load({bool more = false}) async {
    setState(() {
      if (more) {
        _loadingMore = true;
      } else {
        _loading = true;
        _error = null;
      }
    });

    try {
      final nextPage = more ? _page + 1 : 1;
      final data = _view == _AuditView.adminActions
          ? await ApiService.getAuditLogs(page: nextPage)
          : await ApiService.getAccessEvents(page: nextPage);
      if (!mounted) return;

      final rows = (data['data'] as List? ?? []).whereType<Map<String, dynamic>>().toList();

      setState(() {
        _rows = more ? [..._rows, ...rows] : rows;
        _page = int.tryParse(data['current_page'].toString()) ?? nextPage;
        _lastPage = int.tryParse(data['last_page'].toString()) ?? 1;
      });
    } catch (e) {
      if (!mounted) return;
      if (more) {
        showMessage(context, errorText(e));
      } else {
        setState(() => _error = errorText(e));
      }
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
          _loadingMore = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          const PageHeader(
            title: 'Audit log',
            subtitle: 'Admin actions, and every time lender staff opened a borrower\'s score.',
          ),
          SegmentedButton<_AuditView>(
            segments: const [
              ButtonSegment(
                value: _AuditView.adminActions,
                label: Text('Admin actions'),
                icon: Icon(Icons.admin_panel_settings_outlined),
              ),
              ButtonSegment(
                value: _AuditView.scoreViews,
                label: Text('Score views'),
                icon: Icon(Icons.visibility_outlined),
              ),
            ],
            selected: {_view},
            onSelectionChanged: (s) {
              setState(() => _view = s.first);
              _load();
            },
          ),
          const SizedBox(height: 16),
          if (_loading)
            const Padding(
              padding: EdgeInsets.all(48),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (_error != null)
            ErrorState(message: _error!, onRetry: _load)
          else if (_rows.isEmpty)
            EmptyState(
              icon: Icons.fact_check_outlined,
              message: _view == _AuditView.adminActions
                  ? 'No admin actions recorded yet.'
                  : 'No lender has opened a score yet.',
            )
          else ...[
            AdminCard(
              padding: EdgeInsets.zero,
              child: Column(
                children: [
                  for (var i = 0; i < _rows.length; i++)
                    _view == _AuditView.adminActions
                        ? _AdminActionRow(row: _rows[i], last: i == _rows.length - 1)
                        : _ScoreViewRow(row: _rows[i], last: i == _rows.length - 1),
                ],
              ),
            ),
            if (_page < _lastPage)
              LoadMoreButton(loading: _loadingMore, onPressed: () => _load(more: true)),
          ],
        ],
      ),
    );
  }
}

class _RowShell extends StatelessWidget {
  const _RowShell({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.time,
    required this.last,
    this.tone = ChipTone.brand,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final String time;
  final bool last;
  final ChipTone tone;

  @override
  Widget build(BuildContext context) {
    final color = switch (tone) {
      ChipTone.bad => AdminColors.red,
      ChipTone.good => AdminColors.green,
      _ => AdminColors.primary,
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      decoration: BoxDecoration(
        border: last ? null : const Border(bottom: BorderSide(color: AdminColors.border)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.w600, color: AdminColors.text)),
                const SizedBox(height: 3),
                Text(subtitle, style: const TextStyle(fontSize: 12.5, color: AdminColors.muted)),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Text(time, style: const TextStyle(fontSize: 12.5, color: AdminColors.muted)),
        ],
      ),
    );
  }
}

class _AdminActionRow extends StatelessWidget {
  const _AdminActionRow({required this.row, required this.last});

  final Map<String, dynamic> row;
  final bool last;

  @override
  Widget build(BuildContext context) {
    final action = row['action']?.toString() ?? '';
    final meta = row['meta'] is Map ? row['meta'] as Map : const {};
    final actor = row['actor']?.toString() ?? 'Unknown';

    final (IconData icon, String title, ChipTone tone) = switch (action) {
      'lender.created' => (Icons.add_business_outlined, 'Created lender ${meta['name'] ?? ''}', ChipTone.good),
      'lender.suspended' => (Icons.block_outlined, 'Suspended lender ${meta['name'] ?? ''}', ChipTone.bad),
      'lender.reactivated' => (Icons.check_circle_outline, 'Reactivated lender ${meta['name'] ?? ''}', ChipTone.good),
      'user.role_changed' => (
          Icons.manage_accounts_outlined,
          'Changed ${meta['email'] ?? 'a user'} from ${meta['from'] ?? '?'} to ${meta['to'] ?? '?'}',
          ChipTone.brand,
        ),
      _ => (Icons.history_rounded, humanise(action), ChipTone.brand),
    };

    final details = <String>[
      'By $actor',
      if (meta['contact_email'] != null) 'Contact ${meta['contact_email']}',
      if (meta['reason'] != null) 'Reason: ${meta['reason']}',
      if (row['ip_address'] != null) 'IP ${row['ip_address']}',
    ];

    return _RowShell(
      icon: icon,
      title: title.trim(),
      subtitle: details.join(' · '),
      time: formatDateTime(row['created_at']),
      tone: tone,
      last: last,
    );
  }
}

class _ScoreViewRow extends StatelessWidget {
  const _ScoreViewRow({required this.row, required this.last});

  final Map<String, dynamic> row;
  final bool last;

  @override
  Widget build(BuildContext context) {
    return _RowShell(
      icon: Icons.visibility_outlined,
      title: '${row['lender'] ?? 'A lender'} viewed ${row['borrower'] ?? 'a borrower'}\'s score',
      subtitle: 'By ${row['viewer'] ?? 'unknown staff'} · Borrower ${row['borrower_email_masked'] ?? '—'}',
      time: formatDateTime(row['created_at']),
      last: last,
    );
  }
}
