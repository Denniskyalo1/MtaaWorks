import 'dart:async';

import 'package:flutter/material.dart';

import '../api_service.dart';
import 'admin_widgets.dart';

/// Accounts with masked personal details. No scores or statements are shown.
class AdminUsersPage extends StatefulWidget {
  const AdminUsersPage({super.key});

  @override
  State<AdminUsersPage> createState() => _AdminUsersPageState();
}

class _AdminUsersPageState extends State<AdminUsersPage> {
  final _searchController = TextEditingController();
  Timer? _debounce;

  String _role = 'borrower';
  List<Map<String, dynamic>> _users = [];
  int _page = 1;
  int _lastPage = 1;
  int _total = 0;
  bool _loading = true;
  bool _loadingMore = false;
  int? _busyId;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    super.dispose();
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
      final data = await ApiService.getAdminUsers(
        role: _role,
        search: _searchController.text,
        page: nextPage,
      );
      if (!mounted) return;

      final rows = (data['data'] as List? ?? []).whereType<Map<String, dynamic>>().toList();

      setState(() {
        _users = more ? [..._users, ...rows] : rows;
        _page = int.tryParse(data['current_page'].toString()) ?? nextPage;
        _lastPage = int.tryParse(data['last_page'].toString()) ?? 1;
        _total = int.tryParse(data['total'].toString()) ?? _users.length;
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

  void _onSearchChanged(String _) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), _load);
  }

  Future<void> _changeRole(Map<String, dynamic> user, String newRole) async {
    final promoting = newRole == 'admin';

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(promoting ? 'Make ${user['name']} an admin?' : 'Remove admin rights from ${user['name']}?'),
        content: SizedBox(
          width: 420,
          child: Text(
            promoting
                ? 'They will be able to manage lenders and users and read the audit log. '
                    'As an admin they can no longer use the borrower app. They will be signed out now.'
                : 'They will become a borrower again and be signed out now.',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(promoting ? 'Make admin' : 'Remove admin'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    final id = int.tryParse(user['id'].toString());
    if (id == null) return;

    setState(() => _busyId = id);

    try {
      final message = await ApiService.changeUserRole(userId: id, role: newRole);
      if (!mounted) return;
      showMessage(context, message);
      await _load();
    } catch (e) {
      if (!mounted) return;
      showMessage(context, errorText(e));
    } finally {
      if (mounted) setState(() => _busyId = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        const PageHeader(
          title: 'Users',
          subtitle: 'Personal details are masked. Scores and statements are never shown here.',
        ),
        Wrap(
          spacing: 14,
          runSpacing: 12,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            SegmentedButton<String>(
              segments: const [
                ButtonSegment(value: 'borrower', label: Text('Borrowers'), icon: Icon(Icons.person_outline)),
                ButtonSegment(value: 'lender', label: Text('Lender staff'), icon: Icon(Icons.badge_outlined)),
                ButtonSegment(value: 'admin', label: Text('Admins'), icon: Icon(Icons.admin_panel_settings_outlined)),
              ],
              selected: {_role},
              onSelectionChanged: (s) {
                setState(() => _role = s.first);
                _load();
              },
            ),
            SizedBox(
              width: 300,
              child: TextField(
                controller: _searchController,
                onChanged: _onSearchChanged,
                decoration: InputDecoration(
                  hintText: 'Search name or email',
                  prefixIcon: const Icon(Icons.search_rounded),
                  isDense: true,
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: AdminColors.border),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: AdminColors.border),
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        if (_loading)
          const Padding(
            padding: EdgeInsets.all(48),
            child: Center(child: CircularProgressIndicator()),
          )
        else if (_error != null)
          ErrorState(message: _error!, onRetry: _load)
        else if (_users.isEmpty)
          const EmptyState(icon: Icons.people_outline, message: 'No accounts match.')
        else ...[
          Text(
            '$_total account${_total == 1 ? '' : 's'}',
            style: const TextStyle(color: AdminColors.muted, fontSize: 13),
          ),
          const SizedBox(height: 10),
          for (final user in _users)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _UserTile(
                user: user,
                busy: _busyId == int.tryParse(user['id'].toString()),
                isSelf: int.tryParse(user['id'].toString()) == ApiService.userId,
                onChangeRole: (role) => _changeRole(user, role),
              ),
            ),
          if (_page < _lastPage)
            LoadMoreButton(loading: _loadingMore, onPressed: () => _load(more: true)),
        ],
      ],
    );
  }
}

class _UserTile extends StatelessWidget {
  const _UserTile({
    required this.user,
    required this.busy,
    required this.isSelf,
    required this.onChangeRole,
  });

  final Map<String, dynamic> user;
  final bool busy;
  final bool isSelf;
  final ValueChanged<String> onChangeRole;

  @override
  Widget build(BuildContext context) {
    final role = user['role']?.toString() ?? '';
    final name = user['name']?.toString() ?? '—';
    final details = <String>[
      if (user['lender'] != null) 'Lender: ${user['lender']}',
      'Phone ${user['phone_masked'] ?? 'not given'}',
      'ID ${user['national_id_masked'] ?? 'not given'}',
      'Joined ${formatDateTime(user['created_at'])}',
    ];

    return AdminCard(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: AdminColors.primarySoft,
            child: Text(
              name.isEmpty ? '?' : name[0].toUpperCase(),
              style: const TextStyle(color: AdminColors.primary, fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(
                      isSelf ? '$name (you)' : name,
                      style: const TextStyle(fontWeight: FontWeight.bold, color: AdminColors.text),
                    ),
                    StatusChip(humanise(role), tone: role == 'admin' ? ChipTone.brand : ChipTone.neutral),
                    StatusChip(
                      user['email_verified'] == true ? 'Email verified' : 'Email unverified',
                      tone: user['email_verified'] == true ? ChipTone.good : ChipTone.warn,
                    ),
                    if (role == 'borrower')
                      StatusChip(
                        user['phone_verified'] == true ? 'Phone verified' : 'Phone unverified',
                        tone: user['phone_verified'] == true ? ChipTone.good : ChipTone.warn,
                      ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  user['email']?.toString() ?? '—',
                  style: const TextStyle(fontSize: 13, color: AdminColors.text),
                ),
                const SizedBox(height: 2),
                Text(
                  details.join(' · '),
                  style: const TextStyle(fontSize: 12.5, color: AdminColors.muted),
                ),
              ],
            ),
          ),
          if (busy)
            const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2))
          // Lender staff are managed by suspending their lender; you cannot change your own role.
          else if (!isSelf && role != 'lender')
            PopupMenuButton<String>(
              tooltip: 'Actions',
              onSelected: onChangeRole,
              itemBuilder: (_) => [
                if (role == 'borrower')
                  const PopupMenuItem(value: 'admin', child: Text('Make admin')),
                if (role == 'admin')
                  const PopupMenuItem(value: 'borrower', child: Text('Remove admin rights')),
              ],
            ),
        ],
      ),
    );
  }
}
