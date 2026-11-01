import 'package:flutter/material.dart';

import 'services/api_service.dart';

const Color _purple = Color(0xFF7C3AED);
const Color _cardFill = Color(0xFFF9FAFB);

double? _num(dynamic v) => v == null ? null : double.tryParse(v.toString());

String _niceName(String feature) {
  final text = feature.replaceAll('_', ' ').trim();
  return text.isEmpty ? feature : text[0].toUpperCase() + text.substring(1);
}

String _date(dynamic raw) {
  final d = DateTime.tryParse(raw?.toString() ?? '')?.toLocal();
  if (d == null) return '-';
  const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
  return '${d.day} ${months[d.month - 1]} ${d.year}';
}

/// Every score the borrower has had, newest first, with the change since the previous score and the main drivers.
class ScoreHistoryPage extends StatefulWidget {
  const ScoreHistoryPage({super.key});

  @override
  State<ScoreHistoryPage> createState() => _ScoreHistoryPageState();
}

class _ScoreHistoryPageState extends State<ScoreHistoryPage> {
  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _scores = [];

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
      final response = await ApiService.getScoreHistory();
      final list = response['scores'];
      _scores = list is List ? list.whereType<Map<String, dynamic>>().toList() : [];
    } catch (e) {
      _error = e.toString().replaceFirst('Exception: ', '');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        foregroundColor: Colors.black,
        title: const Text('Score history', style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
            ? ListView(children: [Padding(padding: const EdgeInsets.all(24), child: Text(_error!, textAlign: TextAlign.center))])
            : _scores.isEmpty
            ? ListView(children: const [
          Padding(
            padding: EdgeInsets.all(32),
            child: Text('You have not scored a statement yet.',
                textAlign: TextAlign.center, style: TextStyle(color: Colors.grey, fontSize: 15)),
          ),
        ])
            : ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
          children: [
            _trend(),
            const SizedBox(height: 16),
            for (var i = 0; i < _scores.length; i++) ...[
              _card(i),
              const SizedBox(height: 12),
            ],
          ],
        ),
      ),
    );
  }

  /// Small bar chart of up to the last 12 scores, oldest on the left.
  Widget _trend() {
    final recent = _scores.take(12).toList().reversed.toList();
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: _cardFill, borderRadius: BorderRadius.circular(20), border: Border.all(color: Colors.grey.shade200)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Trend', style: TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 12),
          SizedBox(
            height: 80,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                for (final s in recent)
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 3),
                      child: Container(
                        height: 8 + 72 * ((_num(s['score']) ?? 0).clamp(0, 100) / 100),
                        decoration: BoxDecoration(color: _purple, borderRadius: BorderRadius.circular(6)),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 6),
          Text('Last ${recent.length} score(s), oldest on the left. Scores are out of 100.',
              style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
        ],
      ),
    );
  }

  Widget _card(int i) {
    final s = _scores[i];
    final score = _num(s['score']);
    final previous = i + 1 < _scores.length ? _num(_scores[i + 1]['score']) : null;
    final change = (score != null && previous != null) ? score - previous : null;
    final drivers = s['top_drivers'] is List ? (s['top_drivers'] as List).whereType<Map>().toList() : <Map>[];

    return Container(
      decoration: BoxDecoration(color: _cardFill, borderRadius: BorderRadius.circular(20), border: Border.all(color: Colors.grey.shade200)),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          title: Row(
            children: [
              Text(score == null ? '-' : score.toStringAsFixed(1),
                  style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800)),
              const SizedBox(width: 10),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(color: const Color(0xFFF3EEFF), borderRadius: BorderRadius.circular(12)),
                child: Text('${s['risk_tier'] ?? ''}', style: const TextStyle(color: _purple, fontSize: 12, fontWeight: FontWeight.w700)),
              ),
              if (change != null) ...[
                const SizedBox(width: 10),
                Icon(change >= 0 ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded,
                    size: 16, color: change >= 0 ? const Color(0xFF15803D) : const Color(0xFFB91C1C)),
                Text(change.abs().toStringAsFixed(1),
                    style: TextStyle(fontSize: 13, color: change >= 0 ? const Color(0xFF15803D) : const Color(0xFFB91C1C))),
              ],
            ],
          ),
          subtitle: Text('Scored ${_date(s['scored_at'])}${s['high_risk'] == true ? ' · flagged high risk' : ''}'),
          childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
          expandedCrossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (drivers.isEmpty) const Text('No drivers were recorded for this score.'),
            for (final d in drivers)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 3),
                child: Row(
                  children: [
                    Icon(
                      (_num(d['contribution']) ?? 0) < 0 ? Icons.check_circle_outline_rounded : Icons.error_outline_rounded,
                      size: 18,
                      color: (_num(d['contribution']) ?? 0) < 0 ? const Color(0xFF15803D) : const Color(0xFFB45309),
                    ),
                    const SizedBox(width: 8),
                    Expanded(child: Text(_niceName('${d['feature']}'))),
                    Text((_num(d['contribution']) ?? 0) < 0 ? 'helping' : 'holding back',
                        style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
