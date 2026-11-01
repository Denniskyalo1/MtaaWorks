import 'package:flutter/material.dart';

import 'api_service.dart';

/// Loan requests addressed to the signed-in lender. A lender can open a request to see the score
/// the borrower chose to share, then approve it in principle or decline it.
class LoanRequestsPage extends StatefulWidget {
  const LoanRequestsPage({super.key});

  @override
  State<LoanRequestsPage> createState() => _LoanRequestsPageState();
}

class _LoanRequestsPageState extends State<LoanRequestsPage> {
  static const Color background = Color(0xFFF7F6FC);

  List<Map<String, dynamic>> _loans = [];
  bool _loading = true;
  String? _error;
  String _filter = 'pending';

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
      _loans = await ApiService.getLoanRequests();
    } catch (e) {
      _error = e.toString().replaceFirst('Exception: ', '');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  int _id(Map<String, dynamic> loan) =>
      loan['id'] is int ? loan['id'] as int : int.parse('${loan['id']}');

  String _kes(dynamic value) {
    final n = num.tryParse(value?.toString() ?? '');
    if (n == null) return 'KES -';
    final grouped = n.round().toString().replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (_) => ',');
    return 'KES $grouped';
  }

  String _date(dynamic raw) {
    final d = DateTime.tryParse(raw?.toString() ?? '')?.toLocal();
    if (d == null) return '-';
    return '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
  }

  void _message(String text, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(text), backgroundColor: error ? Colors.red.shade700 : null),
    );
  }

  Future<void> _open(Map<String, dynamic> loan) async {
    final id = _id(loan);
    final pending = loan['status'] == 'pending';
    final noteController = TextEditingController();

    final decision = await showDialog<String>(
      context: context,
      builder: (dialogContext) => FutureBuilder<Map<String, dynamic>>(
        future: ApiService.getLoanRequest(id),
        builder: (context, snapshot) {
          final score = snapshot.data?['score'];

          return AlertDialog(
            title: Text('Loan request: ${_kes(loan['amount'])}'),
            content: SizedBox(
              width: 440,
              child: snapshot.connectionState != ConnectionState.done
                  ? const SizedBox(height: 120, child: Center(child: CircularProgressIndicator()))
                  : Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('${loan['borrower']?['name'] ?? 'Borrower'} · ${loan['borrower']?['email'] ?? ''}'),
                  Text('${loan['term_months']} month(s)'
                      '${(loan['purpose']?.toString() ?? '').isEmpty ? '' : ' · ${loan['purpose']}'}'),
                  const Divider(height: 24),
                  if (snapshot.hasError)
                    Text(
                      snapshot.error.toString().replaceFirst('Exception: ', ''),
                      style: TextStyle(color: Colors.red.shade700),
                    )
                  else if (score is Map) ...[
                    Text('Score ${score['score']} · ${score['risk_tier']}',
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    Text('High risk: ${score['high_risk'] == true ? 'Yes' : 'No'}'),
                    Text('Model version ${score['model_version']} · access until ${_date(score['access_expires_at'])}'),
                    if (score['top_drivers'] is List && (score['top_drivers'] as List).isNotEmpty) ...[
                      const SizedBox(height: 8),
                      const Text('Main drivers', style: TextStyle(fontWeight: FontWeight.w600)),
                      for (final d in (score['top_drivers'] as List).whereType<Map>())
                        Text('${d['feature']}: ${d['contribution']}'),
                    ],
                  ],
                  if (pending) ...[
                    const SizedBox(height: 16),
                    TextField(
                      controller: noteController,
                      maxLength: 255,
                      decoration: const InputDecoration(
                        labelText: 'Note to the borrower (optional)',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.of(dialogContext).pop(), child: const Text('Close')),
              if (pending) ...[
                TextButton(onPressed: () => Navigator.of(dialogContext).pop('decline'), child: const Text('Decline')),
                FilledButton(onPressed: () => Navigator.of(dialogContext).pop('approve'), child: const Text('Approve')),
              ],
            ],
          );
        },
      ),
    );

    final note = noteController.text;
    noteController.dispose();

    if (decision == null) return;

    try {
      final message = await ApiService.decideLoanRequest(id: id, approve: decision == 'approve', note: note);
      _message(message);
      await _load();
    } catch (e) {
      _message(e.toString().replaceFirst('Exception: ', ''), error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final shown = _filter == 'all' ? _loans : _loans.where((l) => l['status'] == _filter).toList();

    return Scaffold(
      backgroundColor: background,
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        title: const Text('Loan requests', style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          IconButton(tooltip: 'Refresh', onPressed: _loading ? null : _load, icon: const Icon(Icons.refresh_rounded)),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 980),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 8,
                  children: [
                    for (final f in const ['pending', 'approved', 'declined', 'withdrawn', 'all'])
                      ChoiceChip(
                        label: Text(f[0].toUpperCase() + f.substring(1)),
                        selected: _filter == f,
                        onSelected: (_) => setState(() => _filter = f),
                      ),
                  ],
                ),
                const SizedBox(height: 16),
                Expanded(
                  child: _loading
                      ? const Center(child: CircularProgressIndicator())
                      : _error != null
                      ? Center(child: Text(_error!))
                      : shown.isEmpty
                      ? const Center(child: Text('No loan requests in this view.'))
                      : ListView.separated(
                    itemCount: shown.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 10),
                    itemBuilder: (_, i) {
                      final l = shown[i];
                      return Card(
                        color: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                          side: BorderSide(color: Colors.grey.shade200),
                        ),
                        child: ListTile(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                          title: Text('${_kes(l['amount'])} over ${l['term_months']} month(s)',
                              style: const TextStyle(fontWeight: FontWeight.w700)),
                          subtitle: Text('${l['borrower']?['name'] ?? 'Borrower'} · requested ${_date(l['requested_at'])}'
                              '${(l['purpose']?.toString() ?? '').isEmpty ? '' : '\n${l['purpose']}'}'),
                          isThreeLine: (l['purpose']?.toString() ?? '').isNotEmpty,
                          trailing: Chip(label: Text(l['status'].toString().toUpperCase())),
                          onTap: () => _open(l),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
