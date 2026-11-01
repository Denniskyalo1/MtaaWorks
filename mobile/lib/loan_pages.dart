import 'package:flutter/material.dart';

import 'services/api_service.dart';

const Color _purple = Color(0xFF7C3AED);
const Color _purpleSoft = Color(0xFFF3EEFF);
const Color _cardFill = Color(0xFFF9FAFB);

String _kes(dynamic value) {
  final n = num.tryParse(value?.toString() ?? '');
  if (n == null) return 'KES -';
  final digits = n.round().toString();
  final grouped = digits.replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (_) => ',');
  return 'KES $grouped';
}

/// The borrower's own loan requests, with a button to ask a lender for a loan.
class LoanRequestsPage extends StatefulWidget {
  const LoanRequestsPage({super.key});

  @override
  State<LoanRequestsPage> createState() => _LoanRequestsPageState();
}

class _LoanRequestsPageState extends State<LoanRequestsPage> {
  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _loans = [];

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
      final response = await ApiService.getLoanRequests();
      final list = response['loan_requests'];
      _loans = list is List ? list.whereType<Map<String, dynamic>>().toList() : [];
    } catch (e) {
      _error = e.toString().replaceFirst('Exception: ', '');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _withdraw(int id) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Withdraw this request?'),
        content: const Text(
          'The lender will no longer see it. Your score stays visible to the lender '
              'until the access expires; you can end it under Lender access.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Keep')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Withdraw')),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      await ApiService.withdrawLoanRequest(id);
      await _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
      );
    }
  }

  Future<void> _openForm() async {
    final sent = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => const RequestLoanPage()),
    );
    if (sent == true) _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        foregroundColor: Colors.black,
        title: const Text('Loan requests', style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openForm,
        backgroundColor: _purple,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add_rounded),
        label: const Text('Request a loan'),
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
            ? ListView(children: [
          Padding(
            padding: const EdgeInsets.all(24),
            child: Text(_error!, textAlign: TextAlign.center),
          ),
        ])
            : _loans.isEmpty
            ? ListView(children: const [
          Padding(
            padding: EdgeInsets.all(32),
            child: Text(
              'You have not asked any lender for a loan yet.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey, fontSize: 15),
            ),
          ),
        ])
            : ListView.separated(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 96),
          itemCount: _loans.length,
          separatorBuilder: (_, _) => const SizedBox(height: 12),
          itemBuilder: (_, i) => _loanCard(_loans[i]),
        ),
      ),
    );
  }

  Widget _loanCard(Map<String, dynamic> loan) {
    final lender = loan['lender'] is Map ? loan['lender'] as Map : const {};
    final status = loan['status']?.toString() ?? '';
    final note = loan['decision_note']?.toString();
    final id = loan['id'] is int ? loan['id'] as int : int.tryParse('${loan['id']}');

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _cardFill,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  lender['name']?.toString() ?? 'Lender',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                ),
              ),
              _statusChip(status),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '${_kes(loan['amount'])} over ${loan['term_months']} month(s)',
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
          ),
          if ((loan['purpose']?.toString() ?? '').isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(loan['purpose'].toString(), style: TextStyle(color: Colors.grey.shade700)),
          ],
          if (note != null && note.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text('Lender note: $note', style: TextStyle(color: Colors.grey.shade700)),
          ],
          if (status == 'pending' && id != null) ...[
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(onPressed: () => _withdraw(id), child: const Text('Withdraw')),
            ),
          ],
        ],
      ),
    );
  }

  Widget _statusChip(String status) {
    final (label, fg, bg) = switch (status) {
      'approved' => ('Approved in principle', const Color(0xFF15803D), const Color(0xFFDCFCE7)),
      'declined' => ('Declined', const Color(0xFFB91C1C), const Color(0xFFFEE2E2)),
      'withdrawn' => ('Withdrawn', const Color(0xFF4B5563), const Color(0xFFE5E7EB)),
      _ => ('Pending', const Color(0xFFB45309), const Color(0xFFFEF3C7)),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(12)),
      child: Text(label, style: TextStyle(color: fg, fontSize: 12, fontWeight: FontWeight.w600)),
    );
  }
}

/// Form for asking one lender for a loan. Sending it also shares the latest score with that lender.
class RequestLoanPage extends StatefulWidget {
  const RequestLoanPage({super.key});

  @override
  State<RequestLoanPage> createState() => _RequestLoanPageState();
}

class _RequestLoanPageState extends State<RequestLoanPage> {
  final _amount = TextEditingController();
  final _term = TextEditingController();
  final _purpose = TextEditingController();

  List<Map<String, dynamic>> _lenders = [];
  int? _lenderId;
  bool _shareDrivers = false;
  bool _loading = true;
  bool _sending = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadLenders();
  }

  @override
  void dispose() {
    _amount.dispose();
    _term.dispose();
    _purpose.dispose();
    super.dispose();
  }

  Future<void> _loadLenders() async {
    try {
      final response = await ApiService.getLenders();
      final list = response['lenders'];
      _lenders = list is List ? list.whereType<Map<String, dynamic>>().toList() : [];
    } catch (e) {
      _error = e.toString().replaceFirst('Exception: ', '');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  bool get _valid =>
      _lenderId != null &&
          (num.tryParse(_amount.text.replaceAll(',', '')) ?? 0) > 0 &&
          (int.tryParse(_term.text) ?? 0) > 0 &&
          !_sending;

  Future<void> _send() async {
    if (!_valid) return;
    FocusScope.of(context).unfocus();
    setState(() => _sending = true);

    try {
      await ApiService.createLoanRequest(
        lenderId: _lenderId!,
        amount: num.parse(_amount.text.replaceAll(',', '')),
        termMonths: int.parse(_term.text),
        purpose: _purpose.text,
        shareDrivers: _shareDrivers,
      );
      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
      );
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  InputDecoration _decoration(String label, {String? prefix}) => InputDecoration(
    labelText: label,
    prefixText: prefix,
    filled: true,
    fillColor: _cardFill,
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
  );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        foregroundColor: Colors.black,
        title: const Text('Request a loan', style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? Center(child: Padding(padding: const EdgeInsets.all(24), child: Text(_error!)))
          : ListView(
        padding: const EdgeInsets.all(24),
        children: [
          DropdownButtonFormField<int>(
            initialValue: _lenderId,
            decoration: _decoration('Lender'),
            items: [
              for (final l in _lenders)
                DropdownMenuItem<int>(
                  value: l['id'] is int ? l['id'] as int : int.tryParse('${l['id']}'),
                  child: Text('${l['name']} (${l['type']})'),
                ),
            ],
            onChanged: (v) => setState(() => _lenderId = v),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _amount,
            keyboardType: TextInputType.number,
            onChanged: (_) => setState(() {}),
            decoration: _decoration('Amount', prefix: 'KES '),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _term,
            keyboardType: TextInputType.number,
            onChanged: (_) => setState(() {}),
            decoration: _decoration('Repayment period (months)'),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _purpose,
            maxLength: 255,
            decoration: _decoration('What is the loan for? (optional)'),
          ),
          const SizedBox(height: 8),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            activeThumbColor: _purple,
            title: const Text('Also share the main reasons behind my score'),
            value: _shareDrivers,
            onChanged: (v) => setState(() => _shareDrivers = v),
          ),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: _purpleSoft,
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Text(
              'Sending this request lets the lender see your latest score and risk tier '
                  'for 30 days. You can end that access any time under Lender access. '
                  'The lender decides whether to continue; MtaaWorks does not lend money.',
              style: TextStyle(fontSize: 13, height: 1.4),
            ),
          ),
          const SizedBox(height: 20),
          SizedBox(
            height: 54,
            child: ElevatedButton(
              onPressed: _valid ? _send : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.black,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(27)),
              ),
              child: _sending
                  ? const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
              )
                  : const Text('Send request', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
            ),
          ),
        ],
      ),
    );
  }
}
