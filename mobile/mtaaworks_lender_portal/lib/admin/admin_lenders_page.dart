import 'package:flutter/material.dart';

import '../api_service.dart';
import 'admin_widgets.dart';

/// Lists lender organisations; adds new ones; suspends or reactivates them.
class AdminLendersPage extends StatefulWidget {
  const AdminLendersPage({super.key});

  @override
  State<AdminLendersPage> createState() => _AdminLendersPageState();
}

class _AdminLendersPageState extends State<AdminLendersPage> {
  List<Map<String, dynamic>> _lenders = [];
  String? _error;
  bool _loading = true;
  int? _busyId;

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
      final lenders = await ApiService.getAdminLenders();
      if (!mounted) return;
      setState(() => _lenders = lenders);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = errorText(e));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _openCreateDialog() async {
    final message = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const _CreateLenderDialog(),
    );

    if (message == null || !mounted) return;

    showMessage(context, message);
    await _load();
  }

  Future<void> _changeStatus(Map<String, dynamic> lender) async {
    final suspending = lender['status'] == 'active';
    final reasonController = TextEditingController();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(suspending ? 'Suspend ${lender['name']}?' : 'Reactivate ${lender['name']}?'),
        content: SizedBox(
          width: 420,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                suspending
                    ? 'Its staff will be signed out and blocked from the portal. '
                        'Grants and loan requests are kept, so reactivating restores access.'
                    : 'Its staff will be able to sign in to the portal again.',
              ),
              const SizedBox(height: 16),
              TextField(
                controller: reasonController,
                maxLength: 500,
                maxLines: 2,
                decoration: const InputDecoration(
                  labelText: 'Reason (optional, kept in the audit log)',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: suspending
                ? FilledButton.styleFrom(backgroundColor: AdminColors.red)
                : null,
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(suspending ? 'Suspend' : 'Reactivate'),
          ),
        ],
      ),
    );

    final reason = reasonController.text;
    reasonController.dispose();

    if (confirmed != true || !mounted) return;

    final id = int.tryParse(lender['id'].toString());
    if (id == null) return;

    setState(() => _busyId = id);

    try {
      final message = await ApiService.setLenderStatus(
        lenderId: id,
        status: suspending ? 'suspended' : 'active',
        reason: reason,
      );
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
    if (_loading && _lenders.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null && _lenders.isEmpty) {
      return ErrorState(message: _error!, onRetry: _load);
    }

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          PageHeader(
            title: 'Lenders',
            subtitle: 'Lender organisations on MtaaWorks and their portal access.',
            action: FilledButton.icon(
              onPressed: _openCreateDialog,
              style: FilledButton.styleFrom(backgroundColor: AdminColors.primary),
              icon: const Icon(Icons.add_rounded),
              label: const Text('Add lender'),
            ),
          ),
          if (_lenders.isEmpty)
            const EmptyState(
              icon: Icons.account_balance_outlined,
              message: 'No lenders yet. Add the first one.',
            )
          else
            for (final lender in _lenders)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _LenderTile(
                  lender: lender,
                  busy: _busyId == int.tryParse(lender['id'].toString()),
                  onChangeStatus: () => _changeStatus(lender),
                ),
              ),
        ],
      ),
    );
  }
}

class _LenderTile extends StatelessWidget {
  const _LenderTile({
    required this.lender,
    required this.busy,
    required this.onChangeStatus,
  });

  final Map<String, dynamic> lender;
  final bool busy;
  final VoidCallback onChangeStatus;

  @override
  Widget build(BuildContext context) {
    final active = lender['status'] == 'active';
    final staff = lender['staff_count'] ?? 0;

    return AdminCard(
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: AdminColors.primarySoft,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.account_balance_outlined, color: AdminColors.primary),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 10,
                  runSpacing: 6,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(
                      lender['name']?.toString() ?? '—',
                      style: const TextStyle(fontSize: 15.5, fontWeight: FontWeight.bold, color: AdminColors.text),
                    ),
                    StatusChip(
                      active ? 'Active' : 'Suspended',
                      tone: active ? ChipTone.good : ChipTone.bad,
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  '${humanise(lender['type']?.toString())} · Licence ${lender['licence_number'] ?? '—'} · '
                  '$staff staff · Added ${formatDateTime(lender['created_at'])}',
                  style: const TextStyle(color: AdminColors.muted, fontSize: 13),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          busy
              ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2))
              : OutlinedButton(
                  onPressed: onChangeStatus,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: active ? AdminColors.red : AdminColors.green,
                  ),
                  child: Text(active ? 'Suspend' : 'Reactivate'),
                ),
        ],
      ),
    );
  }
}

/// Pops with the server's success message, or null when cancelled.
class _CreateLenderDialog extends StatefulWidget {
  const _CreateLenderDialog();

  @override
  State<_CreateLenderDialog> createState() => _CreateLenderDialogState();
}

class _CreateLenderDialogState extends State<_CreateLenderDialog> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _licence = TextEditingController();
  final _contactName = TextEditingController();
  final _contactEmail = TextEditingController();

  String _type = 'sacco';
  bool _saving = false;
  String? _error;

  static const _types = {
    'sacco': 'SACCO',
    'mfi': 'Microfinance institution (MFI)',
    'digital_lender': 'Digital lender',
  };

  @override
  void dispose() {
    _name.dispose();
    _licence.dispose();
    _contactName.dispose();
    _contactEmail.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _saving = true;
      _error = null;
    });

    try {
      final message = await ApiService.createLender(
        name: _name.text,
        type: _type,
        licenceNumber: _licence.text,
        contactName: _contactName.text,
        contactEmail: _contactEmail.text,
      );
      if (!mounted) return;
      Navigator.of(context).pop(message);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = errorText(e));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  String? _required(String? value, String label) =>
      (value == null || value.trim().isEmpty) ? 'Enter the $label' : null;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Add lender'),
      content: SizedBox(
        width: 460,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: _name,
                  enabled: !_saving,
                  decoration: const InputDecoration(labelText: 'Organisation name', border: OutlineInputBorder()),
                  validator: (v) => _required(v, 'organisation name'),
                ),
                const SizedBox(height: 14),
                DropdownButtonFormField<String>(
                  initialValue: _type,
                  decoration: const InputDecoration(labelText: 'Type', border: OutlineInputBorder()),
                  items: [
                    for (final e in _types.entries)
                      DropdownMenuItem(value: e.key, child: Text(e.value)),
                  ],
                  onChanged: _saving ? null : (v) => setState(() => _type = v ?? _type),
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _licence,
                  enabled: !_saving,
                  decoration: const InputDecoration(labelText: 'Licence number', border: OutlineInputBorder()),
                  validator: (v) => _required(v, 'licence number'),
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _contactName,
                  enabled: !_saving,
                  decoration: const InputDecoration(labelText: 'Contact person', border: OutlineInputBorder()),
                  validator: (v) => _required(v, 'contact name'),
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _contactEmail,
                  enabled: !_saving,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(labelText: 'Contact email', border: OutlineInputBorder()),
                  validator: (v) {
                    final email = v?.trim() ?? '';
                    if (email.isEmpty) return 'Enter the contact email';
                    if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email)) {
                      return 'Enter a valid email address';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                const Text(
                  'The contact gets an email with a link to set their portal password.',
                  style: TextStyle(color: AdminColors.muted, fontSize: 12.5),
                ),
                if (_error != null) ...[
                  const SizedBox(height: 12),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AdminColors.redSoft,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(_error!, style: const TextStyle(color: AdminColors.red, fontSize: 13)),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _saving ? null : _submit,
          style: FilledButton.styleFrom(backgroundColor: AdminColors.primary),
          child: _saving
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                )
              : const Text('Create lender'),
        ),
      ],
    );
  }
}
