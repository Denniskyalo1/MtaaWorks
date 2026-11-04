import 'package:flutter/material.dart';

import 'api_service.dart';
import 'login_page.dart';

/// Checks a credit report code against the MtaaWorks record. It needs no sign-in, so it also opens
/// from the QR code on the PDF (the link carries ?verify=CODE).
class VerifyReportPage extends StatefulWidget {
  const VerifyReportPage({super.key, this.initialCode});

  final String? initialCode;

  @override
  State<VerifyReportPage> createState() => _VerifyReportPageState();
}

class _VerifyReportPageState extends State<VerifyReportPage> {
  static const Color primary = Color(0xFF5B3CC4);

  final _code = TextEditingController();
  Map<String, dynamic>? _result;
  bool _checking = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    if (widget.initialCode != null && widget.initialCode!.isNotEmpty) {
      _code.text = widget.initialCode!;
      WidgetsBinding.instance.addPostFrameCallback((_) => _check());
    }
  }

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  Future<void> _check() async {
    if (_code.text.trim().isEmpty || _checking) return;
    setState(() {
      _checking = true;
      _error = null;
      _result = null;
    });
    try {
      final r = await ApiService.verifyReport(_code.text);
      if (mounted) setState(() => _result = r);
    } catch (e) {
      if (mounted) setState(() => _error = friendlyError(e));
    } finally {
      if (mounted) setState(() => _checking = false);
    }
  }

  String _date(dynamic raw) {
    final d = DateTime.tryParse(raw?.toString() ?? '')?.toLocal();
    if (d == null) return '-';
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${d.day} ${months[d.month - 1]} ${d.year}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F6FC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        title: const Text('Verify a credit report', style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          if (!Navigator.of(context).canPop())
            TextButton(
              onPressed: () => Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => const LoginPage())),
              child: const Text('Lender sign in'),
            ),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640),
          child: ListView(
            padding: const EdgeInsets.all(24),
            children: [
              const Text('Enter the code printed on the report (it starts with MWR-).'),
              const SizedBox(height: 12),
              Row(children: [
                Expanded(
                  child: TextField(
                    controller: _code,
                    textCapitalization: TextCapitalization.characters,
                    onSubmitted: (_) => _check(),
                    decoration: const InputDecoration(hintText: 'MWR-XXXX-XXXX-XXXX', border: OutlineInputBorder(), filled: true, fillColor: Colors.white),
                  ),
                ),
                const SizedBox(width: 12),
                FilledButton(
                  onPressed: _checking ? null : _check,
                  style: FilledButton.styleFrom(backgroundColor: primary, padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 22)),
                  child: _checking
                      ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Text('Check'),
                ),
              ]),
              const SizedBox(height: 20),
              if (_error != null) Text(_error!, style: TextStyle(color: Colors.red.shade700)),
              if (_result != null) _resultCard(_result!),
            ],
          ),
        ),
      ),
    );
  }

  Widget _resultCard(Map<String, dynamic> r) {
    final valid = r['valid'] == true;
    final status = '${r['status']}';
    final headline = valid
        ? 'This report is valid'
        : switch (status) {
      'not_found' => 'No report has this code',
      'revoked' => 'The borrower withdrew this report',
      'expired' => 'This report has expired',
      'altered' => 'The record no longer matches this report',
      _ => 'This report could not be verified',
    };
    final colour = valid ? const Color(0xFF15803D) : const Color(0xFFB91C1C);

    Widget row(String k, String v) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(children: [SizedBox(width: 150, child: Text(k, style: TextStyle(color: Colors.grey.shade700))), Expanded(child: Text(v, style: const TextStyle(fontWeight: FontWeight.w600)))]),
    );

    final drivers = r['top_drivers'] is List ? (r['top_drivers'] as List).whereType<Map>().toList() : <Map>[];

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18), border: Border.all(color: colour.withValues(alpha: 0.4), width: 1.5)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(valid ? Icons.verified_rounded : Icons.gpp_bad_outlined, color: colour, size: 30),
            const SizedBox(width: 10),
            Expanded(child: Text(headline, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: colour))),
          ]),
          if (valid) ...[
            const SizedBox(height: 14),
            row('Borrower', '${r['name']}'),
            row('Score', '${r['score']} out of 100'),
            row('Risk tier', '${r['risk_tier']}${r['high_risk'] == true ? ' (flagged high risk)' : ''}'),
            row('Scored on', _date(r['scored_at'])),
            row('Model version', '${r['model_version']}'),
            row('Issued', _date(r['issued_at'])),
            row('Valid until', _date(r['expires_at'])),
            row('Fingerprint', '${r['fingerprint']}'),
            if (drivers.isNotEmpty) ...[
              const SizedBox(height: 8),
              const Text('Main reasons', style: TextStyle(fontWeight: FontWeight.w700)),
              for (final d in drivers)
                Text('${'${d['feature']}'.replaceAll('_', ' ')}: ${((double.tryParse('${d['contribution']}') ?? 0) < 0) ? 'helping' : 'holding back'}'),
            ],
            const SizedBox(height: 12),
            Text('Compare the score, tier and fingerprint with the PDF you were given. If any differ, do not rely on the PDF.',
                style: TextStyle(color: Colors.grey.shade700, fontSize: 13)),
          ] else if (status == 'not_found')
            const Padding(padding: EdgeInsets.only(top: 10), child: Text('Check the code for typing mistakes, or ask the borrower for the report again.')),
        ],
      ),
    );
  }
}
