import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'home_page.dart';
import 'upload_statement_page.dart';

const Color _purple = Color(0xFF7C3AED);
const Color _purpleSoft = Color(0xFFF3EEFF);
const Color _cardFill = Color(0xFFF9FAFB);
const Color _riskUp = Color(0xFFE5484D);
const Color _riskUpSoft = Color(0xFFFDECEC);
const Color _riskDown = Color(0xFF1E8E4E);
const Color _riskDownSoft = Color(0xFFE7F6EC);



class _Driver {
  const _Driver(this.title, this.hint, this.contribution);
  final String title;
  final String hint;
  final double contribution;
}

double? _asDouble(dynamic value) {
  if (value is num) return value.toDouble();
  return double.tryParse(value?.toString() ?? '');
}

String _driverTitle(String feature) {
  switch (feature) {
    case 'inflow_volatility':
      return 'Income volatility';
    case 'bill_payment_consistency':
      return 'Bill payment consistency';
    case 'outflow_to_inflow_ratio':
      return 'Spending vs income';
    case 'avg_monthly_inflow':
      return 'Average monthly income';
    case 'fuliza_usage_frequency':
      return 'Fuliza usage';
    case 'loan_repayment_regularity':
      return 'Loan repayment regularity';
    case 'savings_deposit_frequency':
      return 'Savings deposits';
    case 'account_age_months':
      return 'Account age';
    case 'transaction_count_monthly':
      return 'Monthly transactions';
    default:
      return feature
          .split('_')
          .map((word) => word.isEmpty
          ? word
          : '${word[0].toUpperCase()}${word.substring(1)}')
          .join(' ');
  }
}

String _driverHint(String feature) {
  switch (feature) {
    case 'inflow_volatility':
      return 'How much your monthly income fluctuates';
    case 'bill_payment_consistency':
      return 'How regularly you pay bills';
    case 'outflow_to_inflow_ratio':
      return 'How much of your income you spend';
    default:
      return 'How this factor relates to your financial activity';
  }
}
class ScoreResultPage extends StatelessWidget {
  const ScoreResultPage({
    super.key,
    required this.scoreData,
  });

  final Map<String, dynamic> scoreData;

  @override
  Widget build(BuildContext context) {
    final double width = MediaQuery.of(context).size.width;
    final double score = _asDouble(scoreData['score']) ?? 0.0;
    final String tier = scoreData['risk_tier']?.toString() ?? 'Unknown';
    final double probability =
        _asDouble(scoreData['default_probability']) ?? 0.0;

    final rawDrivers = scoreData['top_drivers'];

    final List<_Driver> drivers = rawDrivers is List
        ? rawDrivers.whereType<Map>().map((driver) {
      final feature = driver['feature']?.toString() ?? 'Unknown factor';

      return _Driver(
        _driverTitle(feature),
        _driverHint(feature),
        _asDouble(driver['contribution']) ?? 0.0,
      );
    }).toList()
        : <_Driver>[];

    final double maxContribution = drivers.isEmpty
        ? 1.0
        : drivers
        .map((driver) => driver.contribution.abs())
        .reduce(math.max);

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding:
                const EdgeInsets.symmetric(horizontal: 24.0, vertical: 12.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Container(
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
                              Navigator.of(context).push(
                                MaterialPageRoute(builder: (context)=>HomePage())
                              );
                            },
                          ),
                        ),
                        const Expanded(
                          child: Text(
                            'Your Score',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.black,
                            ),
                          ),
                        ),
                        const SizedBox(width: 44),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Gauge
                    Center(
                      child: SizedBox(
                        width: 230,
                        height: 230,
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            CustomPaint(
                              size: const Size(230, 230),
                              painter: _GaugePainter(value: score / 100),
                            ),
                            Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  score.toStringAsFixed(1),
                                  style: TextStyle(
                                    fontSize: width * 0.14,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.black,
                                    height: 1.0,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'out of 100',
                                  style: TextStyle(
                                    color: Colors.grey.shade500,
                                    fontSize: 14,
                                  ),
                                ),
                              ],
                            ),
                            Positioned(
                              left: 30,
                              bottom: 6,
                              child: Text('0',
                                  style: TextStyle(
                                      color: Colors.grey.shade500,
                                      fontSize: 12)),
                            ),
                            Positioned(
                              right: 24,
                              bottom: 6,
                              child: Text('100',
                                  style: TextStyle(
                                      color: Colors.grey.shade500,
                                      fontSize: 12)),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Center(
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 18, vertical: 8),
                        decoration: BoxDecoration(
                          color: _purple,
                          borderRadius: BorderRadius.circular(22),
                        ),
                        child: Text(
                          tier,
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Center(
                      child: Text(
                        'Estimated chance of default: '
                            '${(probability * 100).toStringAsFixed(1)}%',
                        style: TextStyle(
                          color: Colors.grey.shade600,
                          fontSize: 13.5,
                        ),
                      ),
                    ),
                    const SizedBox(height: 28),

                    // Drivers
                    const Text(
                      'What shaped your score',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                        color: Colors.black,
                      ),
                    ),
                    const SizedBox(height: 12),
                    ...drivers.map(
                          (d) => _DriverTile(
                        driver: d,
                        maxContribution: maxContribution,
                      ),
                    ),
                    const SizedBox(height: 8),

                    // Data notes
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFF8E8),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: const Color(0xFFFFE2A8)),
                      ),
                      child: const Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.info_outline_rounded,
                                  color: Color(0xFFB7791F), size: 20),
                              SizedBox(width: 8),
                              Text(
                                'Things to know about this score',
                                style: TextStyle(
                                  fontSize: 14.5,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF7A4F0C),
                                ),
                              ),
                            ],
                          ),
                          SizedBox(height: 10),
                          _NoteLine(
                            'Your income swings and monthly transaction count were '
                                'higher than anything the model has seen, so this score '
                                'is less certain.',
                          ),
                          _NoteLine(
                            'No loan repayment history was found, so a typical '
                                'value was used for that part.',
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Statement summary
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: _cardFill,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: Colors.grey.shade200),
                      ),
                      child: const Column(
                        children: [
                          _SummaryRow(
                            label: 'Statement period',
                            value: '22 Jun 2024 – 6 Oct 2026',
                          ),
                          Divider(height: 22),
                          _SummaryRow(
                            label: 'Full months used',
                            value: '27',
                          ),
                          Divider(height: 22),
                          _SummaryRow(
                            label: 'Model version',
                            value: '1.0.0',
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                    Text(
                      'This score comes from a model trained on synthetic data. '
                          'It is a demonstration and not a real credit decision.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.grey.shade500,
                        fontSize: 12,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ),

            // Bottom actions
            Container(
              padding: const EdgeInsets.fromLTRB(24, 12, 24, 12),
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border(top: BorderSide(color: Colors.grey.shade200)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(
                    height: 54,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(27),
                      gradient: const LinearGradient(
                        colors: [Color(0xFF2C2C2E), Color(0xFF000000)],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      ),
                    ),
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.pushAndRemoveUntil(
                          context,
                          MaterialPageRoute(builder: (_) => const HomePage()),
                              (route) => false,
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.transparent,
                        shadowColor: Colors.transparent,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(27),
                        ),
                      ),
                      child: const Text(
                        'Back to home',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: () {
                      Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(
                            builder: (_) => const UploadStatementPage()),
                      );
                    },
                    child: Text(
                      'Score another statement',
                      style: TextStyle(
                        color: Colors.grey.shade700,
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DriverTile extends StatelessWidget {
  const _DriverTile({required this.driver, required this.maxContribution});

  final _Driver driver;
  final double maxContribution;

  @override
  Widget build(BuildContext context) {
    final bool increasesRisk = driver.contribution > 0;
    final Color accent = increasesRisk ? _riskUp : _riskDown;
    final Color soft = increasesRisk ? _riskUpSoft : _riskDownSoft;
    final String sign = increasesRisk ? '+' : '−';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _cardFill,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(color: soft, shape: BoxShape.circle),
                child: Icon(
                  increasesRisk
                      ? Icons.trending_up_rounded
                      : Icons.trending_down_rounded,
                  color: accent,
                  size: 22,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      driver.title,
                      style: const TextStyle(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w600,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      driver.hint,
                      style:
                      TextStyle(color: Colors.grey.shade500, fontSize: 12),
                    ),
                  ],
                ),
              ),
              Container(
                padding:
                const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: soft,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  increasesRisk ? 'Raises risk' : 'Lowers risk',
                  style: TextStyle(
                    color: accent,
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: LinearProgressIndicator(
                    value: driver.contribution.abs() / maxContribution,
                    minHeight: 7,
                    backgroundColor: Colors.grey.shade200,
                    valueColor: AlwaysStoppedAnimation<Color>(accent),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Text(
                '$sign${driver.contribution.abs().toStringAsFixed(2)}',
                style: TextStyle(
                  color: accent,
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _NoteLine extends StatelessWidget {
  const _NoteLine(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(top: 6.0),
            child: Icon(Icons.circle, size: 5, color: Color(0xFFB7791F)),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                color: Color(0xFF7A4F0C),
                fontSize: 13,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  const _SummaryRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label,
            style: TextStyle(color: Colors.grey.shade600, fontSize: 13.5)),
        Text(
          value,
          style: const TextStyle(
            color: Colors.black87,
            fontSize: 13.5,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

class _GaugePainter extends CustomPainter {
  _GaugePainter({required this.value});

  final double value; // 0.0 to 1.0

  @override
  void paint(Canvas canvas, Size size) {
    const double stroke = 16;
    final Rect rect = Rect.fromLTWH(
      stroke / 2,
      stroke / 2,
      size.width - stroke,
      size.height - stroke,
    );
    const double start = math.pi * 0.75;
    const double sweep = math.pi * 1.5;

    final Paint track = Paint()
      ..color = const Color(0xFFEDEDF2)
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round;

    final Paint progress = Paint()
      ..color = _purple
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(rect, start, sweep, false, track);
    canvas.drawArc(rect, start, sweep * value.clamp(0.0, 1.0), false, progress);
  }

  @override
  bool shouldRepaint(covariant _GaugePainter oldDelegate) =>
      oldDelegate.value != value;
}