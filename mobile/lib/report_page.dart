import 'dart:typed_data';

import 'package:file_picker/file_picker.dart' as file_picker;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'services/api_service.dart';

const Color _purple = Color(0xFF7C3AED);
const Color _cardFill = Color(0xFFF9FAFB);

String _date(dynamic raw) {
  final d = DateTime.tryParse(raw?.toString() ?? '')?.toLocal();
  if (d == null) return '-';
  const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
  return '${d.day} ${months[d.month - 1]} ${d.year}';
}

/// Credit reports the borrower has created. Each has a code a lender can verify, and a PDF to share.
class ReportPage extends StatefulWidget {
  const ReportPage({super.key});

  @override
  State<ReportPage> createState() => _ReportPageState();
}

class _ReportPageState extends State<ReportPage> {
  bool _loading = true;
  bool _creating = false;
  bool _includeDrivers = false;
  String? _error;
  List<Map<String, dynamic>> _reports = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _message(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final response = await ApiService.getReports();
      final list = response['reports'];
      _reports = list is List ? list.whereType<Map<String, dynamic>>().toList() : [];
    } catch (e) {
      _error = friendlyError(e);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _create() async {
    setState(() => _creating = true);
    try {
      await ApiService.createReport(includeDrivers: _includeDrivers);
      await _load();
      _message('Report created. Download it to share it.');
    } catch (e) {
      _message(friendlyError(e));
    } finally {
      if (mounted) setState(() => _creating = false);
    }
  }

  Future<void> _download(Map<String, dynamic> r) async {
    try {
      final id = r['id'] is int ? r['id'] as int : int.parse('${r['id']}');
      final bytes = await ApiService.downloadReportPdf(id);
      final saved = await file_picker.FilePicker.platform.saveFile(
        dialogTitle: 'Save credit report',
        fileName: 'MtaaWorks-credit-report-${r['code']}.pdf',
        bytes: Uint8List.fromList(bytes),
        type: file_picker.FileType.custom,
        allowedExtensions: ['pdf'],
      );
      _message(saved == null ? 'Saving was cancelled.' : 'Report saved.');
    } catch (e) {
      _message(friendlyError(e));
    }
  }

  Future<void> _withdraw(Map<String, dynamic> r) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Withdraw this report?'),
        content: const Text('Its code will stop verifying. Copies of the PDF you already shared will show as withdrawn.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Keep')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Withdraw')),
        ],
      ),
    );
    if (ok != true) return;
    try {
      final id = r['id'] is int ? r['id'] as int : int.parse('${r['id']}');
      await ApiService.revokeReport(id);
      await _load();
    } catch (e) {
      _message(friendlyError(e));
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
        title: const Text('Credit report', style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: const Color(0xFFF3EEFF), borderRadius: BorderRadius.circular(18)),
              child: const Text(
                'A report is a PDF of your latest score with a code and a QR code. A lender can check it in the MtaaWorks '
                    'portal. It is valid for 30 days, you can withdraw it at any time, and it shows only a shortened name.',
                style: TextStyle(fontSize: 13, height: 1.4),
              ),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              activeThumbColor: _purple,
              title: const Text('Include the main reasons behind my score'),
              value: _includeDrivers,
              onChanged: (v) => setState(() => _includeDrivers = v),
            ),
            SizedBox(
              height: 52,
              child: ElevatedButton.icon(
                onPressed: _creating ? null : _create,
                icon: _creating
                    ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.picture_as_pdf_rounded),
                label: const Text('Create report from my latest score'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.black,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(26)),
                ),
              ),
            ),
            const SizedBox(height: 20),
            if (_loading)
              const Center(child: Padding(padding: EdgeInsets.all(24), child: CircularProgressIndicator()))
            else if (_error != null)
              Padding(padding: const EdgeInsets.all(12), child: Text(_error!))
            else if (_reports.isEmpty)
              const Padding(
                padding: EdgeInsets.all(24),
                child: Text('You have not created a report yet.', textAlign: TextAlign.center, style: TextStyle(color: Colors.grey)),
              )
            else
              for (final r in _reports) ...[_card(r), const SizedBox(height: 12)],
          ],
        ),
      ),
    );
  }

  Widget _card(Map<String, dynamic> r) {
    final status = '${r['status']}';
    final valid = status == 'valid';
    final (fg, bg) = switch (status) {
      'valid' => (const Color(0xFF15803D), const Color(0xFFDCFCE7)),
      'expired' => (const Color(0xFFB45309), const Color(0xFFFEF3C7)),
      _ => (const Color(0xFFB91C1C), const Color(0xFFFEE2E2)),
    };

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: _cardFill, borderRadius: BorderRadius.circular(18), border: Border.all(color: Colors.grey.shade200)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text('${r['code']}', style: const TextStyle(fontFamily: 'monospace', fontWeight: FontWeight.w700, fontSize: 15)),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(12)),
                child: Text(status[0].toUpperCase() + status.substring(1),
                    style: TextStyle(color: fg, fontSize: 12, fontWeight: FontWeight.w700)),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text('Score ${r['score']} · ${r['risk_tier']} · ${r['includes_drivers'] == true ? 'with reasons' : 'without reasons'}'),
          Text('Issued ${_date(r['issued_at'])} · valid until ${_date(r['expires_at'])}', style: TextStyle(color: Colors.grey.shade700, fontSize: 13)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 4,
            children: [
              TextButton.icon(
                onPressed: valid ? () => _download(r) : null,
                icon: const Icon(Icons.download_rounded, size: 18),
                label: const Text('Download PDF'),
              ),
              TextButton.icon(
                onPressed: () async {
                  await Clipboard.setData(ClipboardData(text: '${r['code']}'));
                  _message('Code copied.');
                },
                icon: const Icon(Icons.copy_rounded, size: 18),
                label: const Text('Copy code'),
              ),
              if (valid)
                TextButton.icon(
                  onPressed: () => _withdraw(r),
                  icon: const Icon(Icons.block_rounded, size: 18),
                  label: const Text('Withdraw'),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
