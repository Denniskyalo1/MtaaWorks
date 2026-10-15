import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'home_page.dart';
import 'upload_statement_page.dart';

const Color _purple = Color(0xFF7C3AED);
const Color _purpleSoft = Color(0xFFF3EEFF);
const Color _cardFill = Color(0xFFF9FAFB);
const Color _green = Color(0xFF1E8E4E);
const Color _greenSoft = Color(0xFFE7F6EC);
const Color _amber = Color(0xFFB7791F);
const Color _amberSoft = Color(0xFFFFF8E8);
const Color _amberBorder = Color(0xFFFFE2A8);
const Color _amberText = Color(0xFF7A4F0C);

const String _tier3Range = 'Below 80.2';
const String _tier2Range = '80.2 – 89.3';
const String _tier1Range = '89.3 and above';


double? _asDouble(dynamic value) {
  if (value is num) return value.toDouble();
  return double.tryParse(value?.toString() ?? '');
}

List<String> _stringList(dynamic value) =>
    value is List ? value.map((e) => e.toString()).toList() : <String>[];

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

String _holdingPhrase(String feature) {
  switch (feature) {
    case 'inflow_volatility':
      return 'uneven monthly income';
    case 'outflow_to_inflow_ratio':
      return 'spending most of what comes in';
    case 'bill_payment_consistency':
      return 'gaps in bill payments';
    case 'loan_repayment_regularity':
      return 'months without a loan repayment';
    case 'fuliza_usage_frequency':
      return 'frequent Fuliza use';
    case 'savings_deposit_frequency':
      return 'few savings deposits';
    case 'account_age_months':
      return 'a short transaction history';
    case 'avg_monthly_inflow':
      return 'a lower monthly income';
    case 'transaction_count_monthly':
      return 'your level of monthly activity';
    default:
      return _driverTitle(feature).toLowerCase();
  }
}

String _helpingPhrase(String feature) {
  switch (feature) {
    case 'inflow_volatility':
      return 'steady monthly income';
    case 'outflow_to_inflow_ratio':
      return 'spending well within your income';
    case 'bill_payment_consistency':
      return 'regular bill payments';
    case 'loan_repayment_regularity':
      return 'regular loan repayments';
    case 'fuliza_usage_frequency':
      return 'little Fuliza use';
    case 'savings_deposit_frequency':
      return 'regular savings deposits';
    case 'account_age_months':
      return 'a long transaction history';
    case 'avg_monthly_inflow':
      return 'a higher monthly income';
    case 'transaction_count_monthly':
      return 'your level of monthly activity';
    default:
      return _driverTitle(feature).toLowerCase();
  }
}

String _tip(String feature) {
  switch (feature) {
    case 'inflow_volatility':
      return 'Income that arrives more evenly from month to month tends to help. '
          'Regular sources of income count for the most.';
    case 'outflow_to_inflow_ratio':
      return 'Setting aside a small share of what comes in each month gives you '
          'a buffer, and tends to help.';
    case 'bill_payment_consistency':
      return 'Paying at least one bill through M-PESA every month tends to help.';
    case 'loan_repayment_regularity':
      return 'Repaying loans on time, month after month, tends to help.';
    case 'fuliza_usage_frequency':
      return 'Using Fuliza less often tends to help.';
    case 'savings_deposit_frequency':
      return 'Saving small amounts regularly tends to help.';
    case 'account_age_months':
      return 'A longer record of regular activity builds up over time.';
    case 'avg_monthly_inflow':
      return 'Income level is one factor. Steady income over time matters too.';
    case 'transaction_count_monthly':
      return 'Your usual level of activity is what counts, so there is nothing '
          'to change here.';
    default:
      return 'Steady, regular activity over time tends to help.';
  }
}

String _joinPhrases(List<String> items) {
  if (items.isEmpty) return '';
  if (items.length == 1) return items.first;
  return '${items.sublist(0, items.length - 1).join(', ')} and ${items.last}';
}

String _pct(double v) => '${(v * 100).round()}%';

String _thousands(num v) => v.round().toString().replaceAllMapped(
  RegExp(r'\B(?=(\d{3})+(?!\d))'),
      (_) => ',',
);

String? _valueText(
    String feature,
    Map<String, dynamic> features,
    List<String> imputed,
    ) {
  if (imputed.contains(feature)) {
    return 'This could not be worked out from your statement, so a typical '
        'value was used.';
  }
  final double? v = _asDouble(features[feature]);
  if (v == null) return null;

  switch (feature) {
    case 'inflow_volatility':
      return 'Your monthly income varied by about ${_pct(v)} around your average.';
    case 'outflow_to_inflow_ratio':
      return 'You spent about ${_pct(v)} of the money that came in.';
    case 'bill_payment_consistency':
      return 'You paid at least one bill in about ${_pct(v)} of months.';
    case 'loan_repayment_regularity':
      return 'You made a loan repayment in about ${_pct(v)} of months.';
    case 'fuliza_usage_frequency':
      return 'You used Fuliza about ${v.toStringAsFixed(1)} times a month.';
    case 'savings_deposit_frequency':
      return 'You made about ${v.toStringAsFixed(1)} savings deposits a month.';
    case 'account_age_months':
      return 'Your statement shows about ${v.round()} months of history.';
    case 'transaction_count_monthly':
      return 'You made about ${v.round()} transactions a month.';
    case 'avg_monthly_inflow':
      return 'You received about KES ${_thousands(v)} a month.';
    default:
      return null;
  }
}

String? _formatDate(dynamic value) {
  final DateTime? parsed = DateTime.tryParse(value?.toString() ?? '');
  if (parsed == null) return null;
  final DateTime d = parsed.toLocal();
  const months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];
  return '${d.day} ${months[d.month - 1]} ${d.year}';
}

class _Driver {
  const _Driver({
    required this.feature,
    required this.contribution,
    required this.share,
  });

  final String feature;
  final double contribution;

  final double share;

  bool get helping => contribution < 0;
}


class ScoreResultPage extends StatelessWidget {
  const ScoreResultPage({super.key, required this.scoreData});

  final Map<String, dynamic> scoreData;

  void _goHome(BuildContext context) {
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const HomePage()),
          (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final double width = MediaQuery.of(context).size.width;

    final double score = _asDouble(scoreData['score']) ?? 0.0;
    final String tier = scoreData['risk_tier']?.toString() ?? 'Unknown';

    final Map<String, dynamic> features = scoreData['features'] is Map
        ? Map<String, dynamic>.from(scoreData['features'] as Map)
        : <String, dynamic>{};
    final List<String> imputed = _stringList(scoreData['imputed_features']);
    final List<String> outOfRange =
    _stringList(scoreData['out_of_range_features']);

    // Drivers
    final dynamic rawDrivers = scoreData['top_drivers'];
    final List<Map> driverMaps =
    rawDrivers is List ? rawDrivers.whereType<Map>().toList() : <Map>[];
    double total = 0;
    for (final d in driverMaps) {
      total += (_asDouble(d['contribution']) ?? 0.0).abs();
    }
    if (total == 0) total = 1;

    final List<_Driver> drivers = driverMaps.map((d) {
      final double c = _asDouble(d['contribution']) ?? 0.0;
      return _Driver(
        feature: d['feature']?.toString() ?? 'unknown',
        contribution: c,
        share: c.abs() / total,
      );
    }).toList();

    final List<_Driver> helping = drivers.where((d) => d.helping).toList();
    final List<_Driver> holding = drivers.where((d) => !d.helping).toList();

    // Summary sentence
    String summary;
    final String holdingText =
    _joinPhrases(holding.map((d) => _holdingPhrase(d.feature)).toList());
    final String helpingText =
    _joinPhrases(helping.map((d) => _helpingPhrase(d.feature)).toList());
    if (holding.isNotEmpty && helping.isNotEmpty) {
      summary = 'Your score is held back mainly by $holdingText, '
          'and helped by $helpingText.';
    } else if (holding.isNotEmpty) {
      summary = 'Your score is held back mainly by $holdingText.';
    } else if (helping.isNotEmpty) {
      summary = 'Your score is helped mainly by $helpingText.';
    } else {
      summary = 'We could not work out what shaped this score.';
    }

    final int activeTier =
    tier == 'Tier 3' ? 0 : (tier == 'Tier 2' ? 1 : (tier == 'Tier 1' ? 2 : -1));

    final String? scoredOn = _formatDate(scoreData['scored_at']);
    final String? modelVersion = scoreData['model_version']?.toString();

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
                    // Top bar
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
                            onPressed: () => _goHome(context),
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
                      child: Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        alignment: WrapAlignment.center,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 18, vertical: 8),
                            decoration: BoxDecoration(
                              color: _purple,
                              borderRadius: BorderRadius.circular(22),
                            ),
                            child: Text(
                              tier,
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                                fontSize: 14,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 18),

                    // Tier scale
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _TierSegment(
                            label: 'Tier 3',
                            range: _tier3Range,
                            active: activeTier == 0),
                        const SizedBox(width: 6),
                        _TierSegment(
                            label: 'Tier 2',
                            range: _tier2Range,
                            active: activeTier == 1),
                        const SizedBox(width: 6),
                        _TierSegment(
                            label: 'Tier 1',
                            range: _tier1Range,
                            active: activeTier == 2),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Center(
                      child: Text(
                        'Tier 1 is the strongest.',
                        style: TextStyle(
                            color: Colors.grey.shade500, fontSize: 12.5),
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Summary sentence
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: _purpleSoft,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(Icons.lightbulb_outline_rounded,
                              color: _purple, size: 22),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              summary,
                              style: const TextStyle(
                                fontSize: 14.5,
                                height: 1.45,
                                fontWeight: FontWeight.w600,
                                color: Colors.black87,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Helping
                    if (helping.isNotEmpty) ...[
                      const _GroupTitle(
                        icon: Icons.check_circle_rounded,
                        color: _green,
                        text: 'Helping your score',
                      ),
                      const SizedBox(height: 12),
                      ...helping.map(
                            (d) => _DriverTile(
                          driver: d,
                          valueText: _valueText(d.feature, features, imputed),
                          tip: null,
                        ),
                      ),
                      const SizedBox(height: 8),
                    ],

                    // Holding back
                    if (holding.isNotEmpty) ...[
                      const _GroupTitle(
                        icon: Icons.error_outline_rounded,
                        color: _amber,
                        text: 'Holding it back',
                      ),
                      const SizedBox(height: 12),
                      ...holding.map(
                            (d) => _DriverTile(
                          driver: d,
                          valueText: _valueText(d.feature, features, imputed),
                          tip: _tip(d.feature),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8.0),
                        child: Text(
                          'Tips are general. They do not promise a higher score.',
                          style: TextStyle(
                              color: Colors.grey.shade500, fontSize: 12),
                        ),
                      ),
                    ],

                    // Notes (only when there is something to say)
                    if (outOfRange.isNotEmpty || imputed.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: _amberSoft,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: _amberBorder),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Row(
                              children: [
                                Icon(Icons.info_outline_rounded,
                                    color: _amber, size: 20),
                                SizedBox(width: 8),
                                Text(
                                  'Things to know about this score',
                                  style: TextStyle(
                                    fontSize: 14.5,
                                    fontWeight: FontWeight.bold,
                                    color: _amberText,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            if (outOfRange.isNotEmpty)
                              _NoteLine(
                                'Some of your figures (${_joinPhrases(outOfRange.map((f) => _driverTitle(f).toLowerCase()).toList())}) '
                                    'were unusual compared with the data the model learned '
                                    'from, so this score is less certain.',
                              ),
                            ...imputed.map(
                                  (f) => _NoteLine(
                                f == 'loan_repayment_regularity'
                                    ? 'No loan repayment history was found, so a typical '
                                    'value was used for that part.'
                                    : '${_driverTitle(f)} could not be worked out from '
                                    'your statement, so a typical value was used.',
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                    const SizedBox(height: 16),

                    // Details
                    if (scoredOn != null || modelVersion != null)
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: _cardFill,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: Colors.grey.shade200),
                        ),
                        child: Column(
                          children: [
                            if (scoredOn != null)
                              _SummaryRow(label: 'Scored on', value: scoredOn),
                            if (scoredOn != null && modelVersion != null)
                              const Divider(height: 22),
                            if (modelVersion != null)
                              _SummaryRow(
                                  label: 'Model version', value: modelVersion),
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
                      onPressed: () => _goHome(context),
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


class _TierSegment extends StatelessWidget {
  const _TierSegment({
    required this.label,
    required this.range,
    required this.active,
  });

  final String label;
  final String range;
  final bool active;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Container(
            height: 8,
            decoration: BoxDecoration(
              color: active ? _purple : Colors.grey.shade300,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: active ? FontWeight.w700 : FontWeight.w500,
              color: active ? _purple : Colors.grey.shade600,
            ),
          ),
          Text(
            range,
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey.shade500, fontSize: 11),
          ),
        ],
      ),
    );
  }
}

class _GroupTitle extends StatelessWidget {
  const _GroupTitle({
    required this.icon,
    required this.color,
    required this.text,
  });

  final IconData icon;
  final Color color;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: color, size: 22),
        const SizedBox(width: 8),
        Text(
          text,
          style: const TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.bold,
            color: Colors.black,
          ),
        ),
      ],
    );
  }
}

class _DriverTile extends StatelessWidget {
  const _DriverTile({
    required this.driver,
    required this.valueText,
    required this.tip,
  });

  final _Driver driver;
  final String? valueText;
  final String? tip;

  @override
  Widget build(BuildContext context) {
    final bool helping = driver.helping;
    final Color accent = helping ? _green : _amber;
    final Color soft = helping ? _greenSoft : _amberSoft;

    final int dots = driver.share >= 0.5 ? 3 : (driver.share >= 0.3 ? 2 : 1);
    final String impact = dots == 3
        ? 'Strong influence'
        : (dots == 2 ? 'Moderate influence' : 'Slight influence');

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _cardFill,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(color: soft, shape: BoxShape.circle),
                child: Icon(
                  helping
                      ? Icons.check_rounded
                      : Icons.arrow_downward_rounded,
                  color: accent,
                  size: 22,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  _driverTitle(driver.feature),
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: Colors.black87,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (valueText != null)
            Text(
              valueText!,
              style: TextStyle(
                color: Colors.grey.shade700,
                fontSize: 13.5,
                height: 1.4,
              ),
            ),
          const SizedBox(height: 10),
          Row(
            children: [
              ...List.generate(
                3,
                    (i) => Container(
                  width: 9,
                  height: 9,
                  margin: const EdgeInsets.only(right: 4),
                  decoration: BoxDecoration(
                    color: i < dots ? accent : Colors.grey.shade300,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
              const SizedBox(width: 6),
              Text(
                impact,
                style: TextStyle(
                  color: accent,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          if (tip != null) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: _amberSoft,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.lightbulb_outline_rounded,
                      color: _amber, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      tip!,
                      style: const TextStyle(
                        color: _amberText,
                        fontSize: 12.5,
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
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
            child: Icon(Icons.circle, size: 5, color: _amber),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                color: _amberText,
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

  final double value;

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