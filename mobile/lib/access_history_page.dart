import 'package:flutter/material.dart';

import 'services/api_service.dart';

const Color _purple = Color(0xFF7C3AED);
const Color _cardFill = Color(0xFFF9FAFB);

String _when(dynamic raw) {
  final d = DateTime.tryParse(raw?.toString() ?? '')?.toLocal();
  if (d == null) return '-';
  const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
  final hh = d.hour.toString().padLeft(2, '0');
  final mm = d.minute.toString().padLeft(2, '0');
  return '${d.day} ${months[d.month - 1]} ${d.year}, $hh:$mm';
}

/// Who has opened the borrower's score, and when. Each time lender staff open a shared score, it is listed here.
class AccessHistoryPage extends StatefulWidget {
  const AccessHistoryPage({super.key});

  @override
  State<AccessHistoryPage> createState() => _AccessHistoryPageState();
}

class _AccessHistoryPageState extends State<AccessHistoryPage> {
  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _events = [];

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
      final response = await ApiService.getAccessHistory();
      final list = response['events'];
      _events = list is List ? list.whereType<Map<String, dynamic>>().toList() : [];
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
        title: const Text('Who viewed my score', style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
            ? ListView(children: [Padding(padding: const EdgeInsets.all(24), child: Text(_error!, textAlign: TextAlign.center))])
            : _events.isEmpty
            ? ListView(children: const [
          Padding(
            padding: EdgeInsets.all(32),
            child: Text('No lender has opened your score yet.',
                textAlign: TextAlign.center, style: TextStyle(color: Colors.grey, fontSize: 15)),
          ),
        ])
            : ListView.separated(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
          itemCount: _events.length,
          separatorBuilder: (_, _) => const SizedBox(height: 10),
          itemBuilder: (_, i) {
            final e = _events[i];
            final lender = e['lender'] is Map ? e['lender'] as Map : const {};
            final drivers = e['scope'] == 'score_tier_drivers';
            return Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: _cardFill, borderRadius: BorderRadius.circular(18), border: Border.all(color: Colors.grey.shade200)),
              child: Row(
                children: [
                  const Icon(Icons.visibility_outlined, color: _purple),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('${lender['name'] ?? 'Lender'}', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                        const SizedBox(height: 2),
                        Text(_when(e['viewed_at']), style: TextStyle(color: Colors.grey.shade700)),
                        Text(drivers ? 'Saw score, tier and drivers' : 'Saw score and tier',
                            style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}
