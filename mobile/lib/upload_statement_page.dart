import 'package:file_picker/file_picker.dart' as file_picker;
import 'package:flutter/material.dart';
import 'package:mtaaworks/score_result_page.dart';
import 'package:file_picker/file_picker.dart';
import 'services/api_service.dart';


const Color _purple = Color(0xFF7C3AED);
const Color _purpleSoft = Color(0xFFF3EEFF);
const Color _cardFill = Color(0xFFF9FAFB);

class UploadStatementPage extends StatefulWidget {
  const UploadStatementPage({super.key});

  @override
  State<UploadStatementPage> createState() => _UploadStatementPageState();
}

class _StatementEntry {
  _StatementEntry(this.file);

  final PlatformFile file;
  final TextEditingController password = TextEditingController();
  bool obscure = true;
}

class _UploadStatementPageState extends State<UploadStatementPage> {
  static const int _maxFiles = 6;
  static const int _maxFileBytes = 10 * 1024 * 1024;

  final List<_StatementEntry> _entries = [];
  bool _scoring = false;
  int _step = 0;

  bool get _canSubmit =>
      _entries.isNotEmpty &&
          _entries.every((e) => e.password.text.isNotEmpty) &&
          !_scoring;

  @override
  void dispose() {
    for (final e in _entries) {
      e.password.dispose();
    }
    super.dispose();
  }

  void _message(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  Future<void> _pickFiles() async {
    try {
      final result = await file_picker.FilePicker.platform.pickFiles(
        type: file_picker.FileType.custom,
        allowedExtensions: ['pdf'],
        allowMultiple: true,
      );

      if (result == null || result.files.isEmpty) return;

      var skippedLarge = 0;
      var skippedLimit = 0;

      for (final file in result.files) {
        if (file.path == null) continue;
        if (file.size > _maxFileBytes) {
          skippedLarge++;
          continue;
        }
        if (_entries.length >= _maxFiles) {
          skippedLimit++;
          continue;
        }
        // the same file chosen twice is ignored
        if (_entries.any((e) => e.file.name == file.name && e.file.size == file.size)) continue;
        _entries.add(_StatementEntry(file));
      }

      setState(() {});

      if (skippedLarge > 0) _message('$skippedLarge file(s) skipped: each file must be 10 MB or less.');
      if (skippedLimit > 0) _message('Only $_maxFiles statements can be scored at once.');
    } catch (e) {
      _message('File selection failed: $e');
    }
  }

  void _removeEntry(int index) {
    setState(() {
      _entries.removeAt(index).password.dispose();
    });
  }

  Future<void> _runDemoScoring() async {
    if (!_canSubmit) return;

    FocusScope.of(context).unfocus();

    setState(() {
      _scoring = true;
      _step = 0;
    });

    try {
      final response = await ApiService.scoreStatements(
        statementPaths: _entries.map((e) => e.file.path!).toList(),
        passwords: _entries.map((e) => e.password.text).toList(),
      );

      final scoreData = response['score'];

      if (scoreData is! Map<String, dynamic>) {
        throw Exception(
          'The server did not return a valid score.',
        );
      }

      if (!mounted) return;

      setState(() => _step = 4);

      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ScoreResultPage(
            scoreData: scoreData,
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            e.toString().replaceFirst('Exception: ', ''),
          ),
          duration: const Duration(seconds: 5),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _scoring = false);
      }
    }
  }
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: _scoring ? _buildScoring() : _buildForm(),
      ),
    );
  }


  Widget _buildForm() {
    final double width = MediaQuery.of(context).size.width;

    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            padding:
            const EdgeInsets.symmetric(horizontal: 24.0, vertical: 12.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Align(
                  alignment: Alignment.centerLeft,
                  child: Container(
                    width: 44,
                    height: 44,
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                    ),
                    child: IconButton(
                      icon: const Icon(Icons.arrow_back,
                          color: Colors.black, size: 30),
                      onPressed: () {
                        if (Navigator.canPop(context)) {
                          Navigator.pop(context);
                        }
                      },
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Upload your statements',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: width * 0.07,
                    fontWeight: FontWeight.bold,
                    color: Colors.black,
                    letterSpacing: 0.4,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Choose one or more M-PESA statements (up to 6)\nand enter the password Safaricom sent for each.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: width * 0.038,
                    color: Colors.grey,
                    height: 1.35,
                  ),
                ),
                const SizedBox(height: 28),

                // Statement files, each with its own password
                if (_entries.isEmpty) _buildPicker(),
                for (var i = 0; i < _entries.length; i++) ...[
                  _buildEntry(i),
                  const SizedBox(height: 16),
                ],
                if (_entries.isNotEmpty && _entries.length < _maxFiles)
                  OutlinedButton.icon(
                    onPressed: _scoring ? null : _pickFiles,
                    icon: const Icon(Icons.add_rounded),
                    label: const Text('Add another statement'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: _purple,
                      side: const BorderSide(color: _purple),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                  ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(Icons.lock_clock_outlined,
                        size: 15, color: Colors.grey.shade500),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'Each password is used once to open its file. We never store it.',
                        style: TextStyle(
                            color: Colors.grey.shade600, fontSize: 12.5),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // How to get a statement
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: _cardFill,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.grey.shade200),
                  ),
                  child: const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'How to get your statement',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: Colors.black,
                        ),
                      ),
                      SizedBox(height: 14),
                      _NumberedStep(
                        number: '1',
                        text:
                        'Request a full M-PESA statement in the M-PESA app or on *334#.',
                      ),
                      _NumberedStep(
                        number: '2',
                        text: 'Safaricom emails you the PDF.',
                      ),
                      _NumberedStep(
                        number: '3',
                        text: 'The password arrives by SMS. Enter it under the file.',
                      ),
                      _NumberedStep(
                        number: '!',
                        text:
                        'Together, the statements must cover at least 3 full months with no missing months in between.',
                        last: true,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
        ),

        // Bottom action
        Container(
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 16),
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border(top: BorderSide(color: Colors.grey.shade200)),
          ),
          child: Container(
            height: 54,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(27),
              gradient: LinearGradient(
                colors: _canSubmit
                    ? const [Color(0xFF2C2C2E), Color(0xFF000000)]
                    : [Colors.grey.shade400, Colors.grey.shade400],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
            child: ElevatedButton(
              onPressed: _canSubmit ? _runDemoScoring : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.transparent,
                disabledBackgroundColor: Colors.transparent,
                shadowColor: Colors.transparent,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(27),
                ),
              ),
              child: const Text(
                'Score my statements',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPicker() {
    return GestureDetector(
      onTap: _pickFiles,
      child: CustomPaint(
        painter: _DashedBorderPainter(color: Colors.grey.shade400),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 30, horizontal: 16),
          decoration: BoxDecoration(
            color: _cardFill,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: const BoxDecoration(
                  color: _purpleSoft,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.cloud_upload_outlined,
                    color: _purple, size: 28),
              ),
              const SizedBox(height: 14),
              const Text(
                'Tap to choose your statements',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'PDF only · up to 10 MB each',
                style: TextStyle(color: Colors.grey.shade500, fontSize: 12.5),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEntry(int index) {
    final entry = _entries[index];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildFileRow(entry, () => _removeEntry(index)),
        const SizedBox(height: 10),
        TextField(
          controller: entry.password,
          obscureText: entry.obscure,
          onChanged: (_) => setState(() {}),
          decoration: InputDecoration(
            hintText: 'Password for this statement',
            hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 14),
            prefixIcon:
            Icon(Icons.lock_outline_rounded, color: Colors.grey.shade500),
            suffixIcon: IconButton(
              icon: Icon(
                entry.obscure
                    ? Icons.visibility_off_outlined
                    : Icons.visibility_outlined,
                color: Colors.grey.shade500,
              ),
              onPressed: () => setState(() => entry.obscure = !entry.obscure),
            ),
            filled: true,
            fillColor: const Color(0xFFF9FAFB),
            contentPadding: const EdgeInsets.symmetric(vertical: 16.0),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(color: Colors.grey.shade300, width: 1.0),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(color: Colors.black, width: 1.0),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildFileRow(_StatementEntry entry, VoidCallback onRemove) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _cardFill,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _purple, width: 1.2),
      ),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: const Color(0xFFFDECEC),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.picture_as_pdf_rounded,
                color: Color(0xFFE5484D)),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  entry.file.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${(entry.file.size / (1024 * 1024)).toStringAsFixed(2)} MB · PDF',
                  style: TextStyle(color: Colors.grey.shade500, fontSize: 12),
                ),
              ],
            ),
          ),
          IconButton(
            icon: Icon(Icons.close_rounded, color: Colors.grey.shade600),
            onPressed: onRemove,
          ),
        ],
      ),
    );
  }

  Widget _buildScoring() {
    final double width = MediaQuery.of(context).size.width;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Container(
              width: 84,
              height: 84,
              decoration: const BoxDecoration(
                color: _purpleSoft,
                shape: BoxShape.circle,
              ),
              child: const Padding(
                padding: EdgeInsets.all(24.0),
                child: CircularProgressIndicator(
                  strokeWidth: 4,
                  color: _purple,
                ),
              ),
            ),
          ),
          const SizedBox(height: 28),
          Text(
            'Reading your statement',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: width * 0.065,
              fontWeight: FontWeight.bold,
              color: Colors.black,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'This can take up to 3 minutes. \n Please keep the app open.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: width * 0.038,
              color: Colors.grey,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 32),
          _ProgressStep(label: 'Opening the file', index: 0, current: _step),
          _ProgressStep(
              label: 'Reading your transactions', index: 1, current: _step),
          _ProgressStep(
              label: 'Checking the statement totals', index: 2, current: _step),
          _ProgressStep(
              label: 'Calculating your score', index: 3, current: _step),
        ],
      ),
    );
  }
}

class _NumberedStep extends StatelessWidget {
  const _NumberedStep({
    required this.number,
    required this.text,
    this.last = false,
  });

  final String number;
  final String text;
  final bool last;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: last ? 0 : 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 24,
            height: 24,
            alignment: Alignment.center,
            decoration: const BoxDecoration(
              color: _purpleSoft,
              shape: BoxShape.circle,
            ),
            child: Text(
              number,
              style: const TextStyle(
                color: _purple,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(top: 2.0),
              child: Text(
                text,
                style: TextStyle(
                  color: Colors.grey.shade700,
                  fontSize: 13.5,
                  height: 1.35,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ProgressStep extends StatelessWidget {
  const _ProgressStep({
    required this.label,
    required this.index,
    required this.current,
  });

  final String label;
  final int index;
  final int current;

  @override
  Widget build(BuildContext context) {
    final bool done = current > index;
    final bool active = current == index;

    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        children: [
          SizedBox(
            width: 24,
            height: 24,
            child: done
                ? const Icon(Icons.check_circle_rounded,
                color: _purple, size: 24)
                : active
                ? const Padding(
              padding: EdgeInsets.all(3.0),
              child: CircularProgressIndicator(
                strokeWidth: 2.5,
                color: _purple,
              ),
            )
                : Icon(Icons.radio_button_unchecked_rounded,
                color: Colors.grey.shade400, size: 24),
          ),
          const SizedBox(width: 14),
          Text(
            label,
            style: TextStyle(
              fontSize: 14.5,
              fontWeight: active ? FontWeight.w600 : FontWeight.w500,
              color: done || active ? Colors.black87 : Colors.grey.shade500,
            ),
          ),
        ],
      ),
    );
  }
}

class _DashedBorderPainter extends CustomPainter {
  _DashedBorderPainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4;

    final path = Path()
      ..addRRect(
        RRect.fromRectAndRadius(Offset.zero & size, const Radius.circular(20)),
      );

    for (final metric in path.computeMetrics()) {
      double distance = 0;
      while (distance < metric.length) {
        canvas.drawPath(metric.extractPath(distance, distance + 6), paint);
        distance += 11;
      }
    }
  }

  @override
  bool shouldRepaint(covariant _DashedBorderPainter oldDelegate) =>
      oldDelegate.color != color;
}