import 'package:flutter/material.dart';

import 'api_service.dart';

/// Summary of the borrowers whose scores the lender may currently see: tiers, average score, the
/// main drivers (only for borrowers who shared them) and loan request totals. No borrower is named.
class PortfolioPage extends StatefulWidget {
  const PortfolioPage({super.key});

  @override
  State<PortfolioPage> createState() => _PortfolioPageState();
}

class _PortfolioPageState extends State<PortfolioPage> {
  static const Color primary = Color(0xFF5B3CC4);
  static const Color background = Color(0xFFF7F6FC);

  Map<String, dynamic>? _data;
  bool _loading = true;
  String? _error;

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
      _data = await ApiService.getPortfolio();
    } catch (e) {
      _error = e.toString().replaceFirst('Exception: ', '');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  num _n(dynamic v) => v is num ? v : (num.tryParse('$v') ?? 0);
  String _kes(dynamic v) =>
      'KES ${_n(v).round().toString().replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (_) => ',')}';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: background,
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        title: const Text('Portfolio', style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [IconButton(tooltip: 'Refresh', onPressed: _loading ? null : _load, icon: const Icon(Icons.refresh_rounded))],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? Center(child: Text(_error!))
          : _content(),
    );
  }

  Widget _content() {
    final p = (_data?['portfolio'] as Map?)?.cast<String, dynamic>() ?? {};
    final grants = (p['grants'] as Map?)?.cast<String, dynamic>() ?? {};
    final scores = (p['scores'] as Map?)?.cast<String, dynamic>() ?? {};
    final tiers = (scores['tiers'] as Map?)?.cast<String, dynamic>() ?? {};
    final drivers = (p['drivers'] as Map?)?.cast<String, dynamic>() ?? {};
    final top = drivers['top'] is List ? (drivers['top'] as List).whereType<Map>().toList() : <Map>[];
    final loans = (p['loans'] as Map?)?.cast<String, dynamic>() ?? {};
    final maxTier = [1, ...tiers.values.map(_n)].reduce((a, b) => a > b ? a : b);
    final rate = loans['approval_rate'];

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 980),
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            Wrap(spacing: 16, runSpacing: 16, children: [
              _stat('Borrowers you can see', '${_n(grants['active'])}'),
              _stat('Average score', scores['average'] == null ? '-' : '${scores['average']}'),
              _stat('Flagged high risk', '${_n(scores['high_risk'])}'),
              _stat('Times scores were opened', '${_n(p['views'])}'),
            ]),
            const SizedBox(height: 20),
            _card('Risk tiers', [
              for (final t in ['Tier 1', 'Tier 2', 'Tier 3'])
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Row(children: [
                    SizedBox(width: 60, child: Text(t)),
                    Expanded(
                      child: LayoutBuilder(builder: (context, c) {
                        final w = c.maxWidth * (_n(tiers[t]) / maxTier);
                        // Align loosens the tight width the Expanded parent gives, so the bar can be shorter than the row
                        return Align(
                          alignment: Alignment.centerLeft,
                          child: Container(
                            height: 22,
                            width: w < 4 && _n(tiers[t]) > 0 ? 4 : w,
                            decoration: BoxDecoration(color: primary, borderRadius: BorderRadius.circular(6)),
                          ),
                        );
                      }),
                    ),
                    const SizedBox(width: 10),
                    Text('${_n(tiers[t])}', style: const TextStyle(fontWeight: FontWeight.w700)),
                  ]),
                ),
              Text('Only scores shared with you and not expired or revoked are counted.',
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
            ]),
            const SizedBox(height: 16),
            _card('Access to scores', [
              Text('Active ${_n(grants['active'])}   ·   Waiting for the borrower ${_n(grants['pending'])}   ·   '
                  'Expired ${_n(grants['expired'])}   ·   Revoked ${_n(grants['revoked'])}   ·   Declined ${_n(grants['declined'])}'),
            ]),
            const SizedBox(height: 16),
            _card('Main drivers (${_n(drivers['borrowers_sharing_drivers'])} borrower(s) shared them)', [
              if (top.isEmpty) const Text('No borrower has shared drivers with you yet.'),
              for (final d in top)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(children: [
                    Expanded(child: Text('${d['label']}')),
                    Text('helping ${_n(d['helping'])}  ·  holding back ${_n(d['holding_back'])}',
                        style: TextStyle(color: Colors.grey.shade700, fontSize: 13)),
                  ]),
                ),
            ]),
            const SizedBox(height: 16),
            _card('Loan requests', [
              for (final s in ['pending', 'approved', 'declined', 'withdrawn'])
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 3),
                  child: Row(children: [
                    SizedBox(width: 110, child: Text(s[0].toUpperCase() + s.substring(1))),
                    Text('${_n((loans[s] as Map?)?['count'])} request(s)', style: const TextStyle(fontWeight: FontWeight.w600)),
                    const SizedBox(width: 16),
                    Text(_kes((loans[s] as Map?)?['amount']), style: TextStyle(color: Colors.grey.shade700)),
                  ]),
                ),
              const SizedBox(height: 6),
              Text(rate == null ? 'Approval rate: no decisions yet' : 'Approval rate: ${(_n(rate) * 100).toStringAsFixed(0)}% of decided requests'),
            ]),
          ],
        ),
      ),
    );
  }

  Widget _stat(String label, String value) {
    return Container(
      width: 220,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18), border: Border.all(color: Colors.grey.shade200)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: TextStyle(color: Colors.grey.shade700, fontSize: 13)),
        const SizedBox(height: 6),
        Text(value, style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w800)),
      ]),
    );
  }

  Widget _card(String title, List<Widget> children) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18), border: Border.all(color: Colors.grey.shade200)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
        const SizedBox(height: 10),
        ...children,
      ]),
    );
  }
}
