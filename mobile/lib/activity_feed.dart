import 'package:flutter/material.dart';

import 'services/api_service.dart';

/// Where tapping an activity item should take the borrower.
enum ActivityTarget { scoreHistory, requests, loans, views, profile }

class ActivityItem {
  const ActivityItem({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.when,
    required this.target,
    this.fromOthers = false,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final DateTime when;
  final ActivityTarget target;

  /// True for things a lender did (a request, a decision, a view), which are
  /// what the notification badge counts. The borrower's own actions are not.
  final bool fromOthers;
}

class ActivitySnapshot {
  const ActivitySnapshot({
    required this.consentActive,
    required this.pendingRequests,
    required this.items,
  });

  /// Null when the consent status could not be loaded.
  final bool? consentActive;

  /// Null when the requests could not be loaded.
  final int? pendingRequests;

  /// Newest first.
  final List<ActivityItem> items;

  int unreadSince(DateTime? seenAt) => items
      .where((i) => i.fromOthers && (seenAt == null || i.when.isAfter(seenAt)))
      .length;
}

/// Builds the borrower's activity from the existing API routes. Each source is
/// loaded on its own, so one failing route does not empty the whole feed.
class ActivityFeed {
  static Future<Map<String, dynamic>> _safe(Future<Map<String, dynamic>> call) async {
    try {
      return await call;
    } catch (_) {
      return <String, dynamic>{};
    }
  }

  static DateTime? _date(dynamic value) =>
      DateTime.tryParse(value?.toString() ?? '')?.toLocal();

  static List<Map<String, dynamic>> _list(Map<String, dynamic> data, String key) {
    final value = data[key];
    return value is List ? value.whereType<Map<String, dynamic>>().toList() : [];
  }

  static String _lenderName(Map<String, dynamic> row) {
    final lender = row['lender'];
    if (lender is Map && lender['name'] != null) return lender['name'].toString();
    return 'A lender';
  }

  static Future<ActivitySnapshot> load() async {
    final results = await Future.wait([
      _safe(ApiService.getConsents()),
      _safe(ApiService.getAccessRequests()),
      _safe(ApiService.getLoanRequests()),
      _safe(ApiService.getAccessHistory()),
      _safe(ApiService.getScoreHistory()),
    ]);

    final consentsData = results[0];
    final requestsData = results[1];
    final items = <ActivityItem>[];

    // Consent
    final consents = _list(consentsData, 'consents')
        .where((c) => c['purpose'] == 'statement_analysis')
        .toList();
    final bool? consentActive = consentsData.containsKey('consents')
        ? consents.any((c) => c['revoked_at'] == null)
        : null;
    for (final c in consents) {
      final granted = _date(c['granted_at']);
      if (granted != null) {
        items.add(ActivityItem(
          icon: Icons.verified_user_outlined,
          title: 'Consent granted',
          subtitle: 'Statement analysis',
          when: granted,
          target: ActivityTarget.profile,
        ));
      }
      final revoked = _date(c['revoked_at']);
      if (revoked != null) {
        items.add(ActivityItem(
          icon: Icons.remove_moderator_outlined,
          title: 'Consent withdrawn',
          subtitle: 'Stored statements and scores were deleted',
          when: revoked,
          target: ActivityTarget.profile,
        ));
      }
    }

    // Lender access requests
    final requests = _list(requestsData, 'requests');
    final int? pending = requestsData.containsKey('requests')
        ? requests.where((r) => r['status'] == 'requested').length
        : null;
    for (final r in requests) {
      final when = _date(r['requested_at']);
      if (when == null) continue;
      const statusText = {
        'requested': 'Waiting for your answer',
        'approved': 'You approved access',
        'declined': 'You declined',
        'revoked': 'Access was revoked',
        'expired': 'Access expired',
      };
      items.add(ActivityItem(
        icon: Icons.business_outlined,
        title: '${_lenderName(r)} asked to see your score',
        subtitle: statusText[r['status']] ?? 'Lender request',
        when: when,
        target: ActivityTarget.requests,
        fromOthers: true,
      ));
    }

    // Loan requests
    for (final l in _list(results[2], 'loan_requests')) {
      final status = l['status']?.toString() ?? '';
      final decided = status == 'approved' || status == 'declined';
      final when = _date(l['responded_at']) ?? _date(l['requested_at']);
      if (when == null) continue;
      const statusText = {
        'pending': 'Waiting for the lender',
        'approved': 'Approved in principle',
        'declined': 'Declined by the lender',
        'withdrawn': 'You withdrew it',
      };
      items.add(ActivityItem(
        icon: Icons.request_quote_outlined,
        title: 'Loan request to ${_lenderName(l)}',
        subtitle: statusText[status] ?? 'Loan request',
        when: when,
        target: ActivityTarget.loans,
        fromOthers: decided,
      ));
    }

    // Lender views of the score
    for (final e in _list(results[3], 'events')) {
      final when = _date(e['viewed_at']);
      if (when == null) continue;
      items.add(ActivityItem(
        icon: Icons.visibility_outlined,
        title: '${_lenderName(e)} viewed your score',
        subtitle: e['scope'] == 'score_tier_drivers'
            ? 'Score, tier and main reasons'
            : 'Score and tier',
        when: when,
        target: ActivityTarget.views,
        fromOthers: true,
      ));
    }

    // Scores
    for (final s in _list(results[4], 'scores')) {
      final when = _date(s['scored_at']);
      if (when == null) continue;
      final raw = s['score'];
      final score = raw is num ? raw.toDouble() : double.tryParse(raw?.toString() ?? '');
      items.add(ActivityItem(
        icon: Icons.insights_rounded,
        title: 'Statement scored',
        subtitle: [
          if (score != null) 'Score ${score.toStringAsFixed(1)}',
          if (s['risk_tier'] != null) '${s['risk_tier']}',
        ].join(' · '),
        when: when,
        target: ActivityTarget.scoreHistory,
      ));
    }

    items.sort((a, b) => b.when.compareTo(a.when));

    return ActivitySnapshot(
      consentActive: consentActive,
      pendingRequests: pending,
      items: items,
    );
  }
}

/// "Just now", "5 min ago", "3 h ago", "Yesterday", "4 days ago", or a date.
String timeAgo(DateTime when) {
  final diff = DateTime.now().difference(when);
  if (diff.inMinutes < 1) return 'Just now';
  if (diff.inMinutes < 60) return '${diff.inMinutes} min ago';
  if (diff.inHours < 24) return '${diff.inHours} h ago';
  if (diff.inDays == 1) return 'Yesterday';
  if (diff.inDays < 7) return '${diff.inDays} days ago';

  const months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];
  return '${when.day} ${months[when.month - 1]}';
}
