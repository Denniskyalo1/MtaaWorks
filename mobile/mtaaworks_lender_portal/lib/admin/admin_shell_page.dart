import 'package:flutter/material.dart';

import '../api_service.dart';
import '../login_page.dart';
import 'admin_audit_page.dart';
import 'admin_dashboard_page.dart';
import 'admin_lenders_page.dart';
import 'admin_users_page.dart';
import 'admin_widgets.dart';

/// Admin workspace: Dashboard, Lenders, Users and Audit log.
class AdminShellPage extends StatefulWidget {
  const AdminShellPage({super.key});

  @override
  State<AdminShellPage> createState() => _AdminShellPageState();
}

class _AdminShellPageState extends State<AdminShellPage> {
  int _index = 0;

  static const _destinations = [
    (icon: Icons.space_dashboard_outlined, selected: Icons.space_dashboard, label: 'Dashboard'),
    (icon: Icons.account_balance_outlined, selected: Icons.account_balance, label: 'Lenders'),
    (icon: Icons.people_outline, selected: Icons.people, label: 'Users'),
    (icon: Icons.fact_check_outlined, selected: Icons.fact_check, label: 'Audit log'),
  ];

  Widget _page() {
    // Built fresh on each switch so every tab shows current data.
    switch (_index) {
      case 1:
        return const AdminLendersPage();
      case 2:
        return const AdminUsersPage();
      case 3:
        return const AdminAuditPage();
      default:
        return const AdminDashboardPage();
    }
  }

  Future<void> _logout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Sign out?'),
        content: const Text('You will need to sign in again to use the admin portal.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Sign out'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    await ApiService.logout();

    if (!mounted) return;

    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginPage()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.of(context).size.width >= 900;

    final appBar = AppBar(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.white,
      elevation: 0,
      titleSpacing: 20,
      title: const Row(
        children: [
          Icon(Icons.admin_panel_settings_rounded, color: AdminColors.primary),
          SizedBox(width: 10),
          Text(
            'MtaaWorks Admin',
            style: TextStyle(fontWeight: FontWeight.bold, color: AdminColors.text),
          ),
        ],
      ),
      actions: [
        if (ApiService.userName != null && isWide)
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: Center(
              child: Text(
                ApiService.userName!,
                style: const TextStyle(color: AdminColors.muted),
              ),
            ),
          ),
        IconButton(
          tooltip: 'Sign out',
          onPressed: _logout,
          icon: const Icon(Icons.logout_rounded),
        ),
        const SizedBox(width: 8),
      ],
      bottom: const PreferredSize(
        preferredSize: Size.fromHeight(1),
        child: Divider(height: 1, color: AdminColors.border),
      ),
    );

    final content = ColoredBox(
      color: AdminColors.background,
      child: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1200),
          child: _page(),
        ),
      ),
    );

    if (isWide) {
      return Scaffold(
        appBar: appBar,
        body: Row(
          children: [
            NavigationRail(
              backgroundColor: Colors.white,
              extended: true,
              minExtendedWidth: 200,
              selectedIndex: _index,
              onDestinationSelected: (i) => setState(() => _index = i),
              indicatorColor: AdminColors.primarySoft,
              destinations: [
                for (final d in _destinations)
                  NavigationRailDestination(
                    icon: Icon(d.icon),
                    selectedIcon: Icon(d.selected, color: AdminColors.primary),
                    label: Text(d.label),
                  ),
              ],
            ),
            const VerticalDivider(width: 1, color: AdminColors.border),
            Expanded(child: content),
          ],
        ),
      );
    }

    return Scaffold(
      appBar: appBar,
      body: content,
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        indicatorColor: AdminColors.primarySoft,
        destinations: [
          for (final d in _destinations)
            NavigationDestination(
              icon: Icon(d.icon),
              selectedIcon: Icon(d.selected, color: AdminColors.primary),
              label: d.label,
            ),
        ],
      ),
    );
  }
}
