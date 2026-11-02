import 'package:flutter/material.dart';

import 'access_history_page.dart';
import 'activity_feed.dart';
import 'loan_pages.dart';
import 'score_history_page.dart';
import 'services/api_service.dart';

const Color _purple = Color(0xFF7C3AED);
const Color _purpleSoft = Color(0xFFF3EEFF);
const Color _cardFill = Color(0xFFF9FAFB);

/// Everything that happened on the borrower's account, newest first.
/// Items from lenders that arrived since the last visit are marked as new.
///
/// Pops with an [ActivityTarget] when the borrower picks something that lives
/// in a Home tab (lender requests or profile), so Home can switch to it.
class NotificationsPage extends StatefulWidget {
  const NotificationsPage({super.key});

  @override
  State<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends State<NotificationsPage> {
  ActivitySnapshot? _snapshot;
  DateTime? _seenAt;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);

    final seenAt = await ApiService.getNotificationsSeenAt();
    final snapshot = await ActivityFeed.load();

    if (!mounted) return;

    setState(() {
      // Keep the previous "seen" time for this visit, so new items stay marked
      // while the page is open; the next visit starts from now.
      _seenAt ??= seenAt;
      _snapshot = snapshot;
      _loading = false;
    });

    await ApiService.setNotificationsSeenAt(DateTime.now());
  }

  Future<void> _open(ActivityItem item) async {
    switch (item.target) {
      case ActivityTarget.requests:
      case ActivityTarget.profile:
        Navigator.of(context).pop(item.target);
        return;
      case ActivityTarget.loans:
        await Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const LoanRequestsPage()),
        );
        break;
      case ActivityTarget.views:
        await Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const AccessHistoryPage()),
        );
        break;
      case ActivityTarget.scoreHistory:
        await Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const ScoreHistoryPage()),
        );
        break;
    }
    if (mounted) await _load();
  }

  bool _isNew(ActivityItem item) =>
      item.fromOthers && (_seenAt == null || item.when.isAfter(_seenAt!));

  @override
  Widget build(BuildContext context) {
    final items = _snapshot?.items ?? const <ActivityItem>[];

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        elevation: 0,
        foregroundColor: Colors.black,
        title: const Text(
          'Notifications',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      body: _loading && _snapshot == null
          ? const Center(child: CircularProgressIndicator(color: _purple))
          : RefreshIndicator(
              color: _purple,
              onRefresh: _load,
              child: items.isEmpty
                  ? ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      children: [
                        const SizedBox(height: 120),
                        Icon(Icons.notifications_none_rounded,
                            size: 48, color: Colors.grey.shade400),
                        const SizedBox(height: 12),
                        Text(
                          'Nothing yet.\nLender requests, decisions and views will show here.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.grey.shade600, height: 1.4),
                        ),
                      ],
                    )
                  : ListView.separated(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                      itemCount: items.length > 40 ? 40 : items.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 10),
                      itemBuilder: (_, i) {
                        final item = items[i];
                        final isNew = _isNew(item);
                        return InkWell(
                          borderRadius: BorderRadius.circular(18),
                          onTap: () => _open(item),
                          child: Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: isNew ? _purpleSoft : _cardFill,
                              borderRadius: BorderRadius.circular(18),
                              border: Border.all(
                                color: isNew ? _purple.withValues(alpha: 0.35) : Colors.grey.shade200,
                              ),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  width: 42,
                                  height: 42,
                                  decoration: BoxDecoration(
                                    color: isNew ? Colors.white : _purpleSoft,
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(item.icon, color: _purple, size: 22),
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        item.title,
                                        style: TextStyle(
                                          fontSize: 14,
                                          fontWeight: isNew ? FontWeight.w700 : FontWeight.w600,
                                          color: Colors.black87,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        item.subtitle,
                                        style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Text(
                                      timeAgo(item.when),
                                      style: TextStyle(color: Colors.grey.shade500, fontSize: 12),
                                    ),
                                    if (isNew) ...[
                                      const SizedBox(height: 6),
                                      Container(
                                        width: 8,
                                        height: 8,
                                        decoration: const BoxDecoration(
                                          color: _purple,
                                          shape: BoxShape.circle,
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
            ),
    );
  }
}
