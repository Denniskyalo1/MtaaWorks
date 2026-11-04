
import 'package:flutter/material.dart';
import 'package:mtaaworks/profile_page.dart';
import 'lender_requests_page.dart';
import 'consent_page.dart';
import 'loan_pages.dart';
import 'report_page.dart';
import 'score_history_page.dart';
import 'access_history_page.dart';
import 'activity_feed.dart';
import 'notifications_page.dart';
import 'services/api_service.dart';

const Color _purple = Color(0xFF7C3AED);
const Color _purpleSoft = Color(0xFFF3EEFF);
const Color _cardFill = Color(0xFFF9FAFB);

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _tab = 0;

  String _userName = 'User';
  bool _isLoadingProfile = true;
  String? _profileError;

  double? _score;
  String? _tier;
  String? _lastScored;
  bool _isLoadingScore = true;
  String? _scoreError;

  ActivitySnapshot? _activity;
  bool _isLoadingActivity = true;
  DateTime? _notificationsSeenAt;

  @override
  void initState() {
    super.initState();
    _loadProfile();
    _loadLatestScore();
    _loadActivity();
  }

  /// Consent status, pending requests, recent activity and the unread count.
  Future<void> _loadActivity() async {
    final snapshot = await ActivityFeed.load();
    final seenAt = await ApiService.getNotificationsSeenAt();

    if (!mounted) return;

    setState(() {
      _activity = snapshot;
      _notificationsSeenAt = seenAt;
      _isLoadingActivity = false;
    });
  }

  Future<void> _refreshAll() async {
    await Future.wait([_loadProfile(), _loadLatestScore(), _loadActivity()]);
  }

  /// Requests and consent live in Home's own tabs; the rest are separate pages.
  Future<void> _openTarget(ActivityTarget? target) async {
    switch (target) {
      case ActivityTarget.requests:
        setState(() => _tab = 1);
        return;
      case ActivityTarget.profile:
        setState(() => _tab = 2);
        return;
      case ActivityTarget.loans:
        await Navigator.push(context, MaterialPageRoute(builder: (_) => const LoanRequestsPage()));
        break;
      case ActivityTarget.views:
        await Navigator.push(context, MaterialPageRoute(builder: (_) => const AccessHistoryPage()));
        break;
      case ActivityTarget.scoreHistory:
        await Navigator.push(context, MaterialPageRoute(builder: (_) => const ScoreHistoryPage()));
        break;
      case null:
        break;
    }
    if (mounted) await _loadActivity();
  }

  Future<void> _openNotifications() async {
    final target = await Navigator.push<ActivityTarget>(
      context,
      MaterialPageRoute(builder: (_) => const NotificationsPage()),
    );

    if (!mounted) return;

    await _loadActivity();
    if (target != null) await _openTarget(target);
  }

  Future<void> _loadProfile() async {
    try {
      final response = await ApiService.getProfile();
      final user = response['user'];

      if (user is! Map<String, dynamic>) {
        throw Exception('Invalid profile response from the server.');
      }

      if (!mounted) return;

      final name = user['name']?.toString().trim() ?? '';

      setState(() {
        _userName = name.isEmpty ? 'User' : name;
        _profileError = null;
        _isLoadingProfile = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _profileError =
            friendlyError(e);
        _isLoadingProfile = false;
      });
    }
  }


  Future<void> _loadLatestScore() async {
    setState(() {
      _isLoadingScore = true;
      _scoreError = null;
    });

    try {
      final response = await ApiService.getLatestScore();
      final scoreData = response['score'];

      if (!mounted) return;

      if (scoreData is! Map<String, dynamic>) {
        setState(() {
          _score = null;
          _tier = null;
          _lastScored = null;
          _scoreError = null;
          _isLoadingScore = false;
        });
        return;
      }

      // Laravel returns the score as a string, e.g. "80.20".
      final rawScore = scoreData['score'];
      final parsedScore = rawScore is num
          ? rawScore.toDouble()
          : double.tryParse(rawScore?.toString() ?? '');

      final rawDate = scoreData['scored_at']?.toString();
      final parsedDate =
      rawDate == null ? null : DateTime.tryParse(rawDate);

      setState(() {
        _score = parsedScore;
        _tier = scoreData['risk_tier']?.toString();

        _lastScored = parsedDate == null
            ? null
            : 'Scored ${parsedDate.toLocal().year}-'
            '${parsedDate.toLocal().month.toString().padLeft(2, '0')}-'
            '${parsedDate.toLocal().day.toString().padLeft(2, '0')}';

        _scoreError = parsedScore == null
            ? 'The server returned an invalid credit score.'
            : null;

        _isLoadingScore = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _score = null;
        _tier = null;
        _lastScored = null;
        _scoreError =
            friendlyError(e);
        _isLoadingScore = false;
      });
    }
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: _tab == 0
            ? _HomeBody(
          userName: _userName,
          isLoadingProfile: _isLoadingProfile,
          profileError: _profileError,
          onRetryProfile: _loadProfile,
          score: _score,
          tier: _tier,
          lastScored: _lastScored,
          isLoadingScore: _isLoadingScore,
          scoreError: _scoreError,
          onRetryScore: _loadLatestScore,
          consentActive: _activity?.consentActive,
          pendingRequests: _activity?.pendingRequests,
          activity: _activity?.items ?? const [],
          isLoadingActivity: _isLoadingActivity,
          unreadCount: _activity?.unreadSince(_notificationsSeenAt) ?? 0,
          onRefresh: _refreshAll,
          onOpenNotifications: _openNotifications,
          onOpenTarget: _openTarget,
        )
            : _tab == 1
            ? const LenderRequestsPage()
            : const ProfilePage()
      ),
      bottomNavigationBar: NavigationBar(
        backgroundColor: Colors.white,
        indicatorColor: _purpleSoft,
        selectedIndex: _tab,
        onDestinationSelected: (i) {
          setState(() => _tab = i);
          // Coming back to Home after answering a request or changing consent.
          if (i == 0) _loadActivity();
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home_rounded, color: _purple),
            label: 'Home',
          ),
          NavigationDestination(
            icon: Icon(Icons.inbox_outlined),
            selectedIcon: Icon(Icons.inbox_rounded, color: _purple),
            label: 'Requests',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline_rounded),
            selectedIcon: Icon(Icons.person_rounded, color: _purple),
            label: 'Profile',
          ),
        ],
      ),
    );
  }
}

class _HomeBody extends StatelessWidget {
  const _HomeBody({
    required this.userName,
    required this.isLoadingProfile,
    required this.profileError,
    required this.onRetryProfile,
    required this.score,
    required this.tier,
    required this.lastScored,
    required this.isLoadingScore,
    required this.scoreError,
    required this.onRetryScore,
    required this.consentActive,
    required this.pendingRequests,
    required this.activity,
    required this.isLoadingActivity,
    required this.unreadCount,
    required this.onRefresh,
    required this.onOpenNotifications,
    required this.onOpenTarget,
  });

  final String userName;
  final bool isLoadingProfile;
  final String? profileError;
  final Future<void> Function() onRetryProfile;

  final double? score;
  final String? tier;
  final String? lastScored;
  final bool isLoadingScore;
  final String? scoreError;
  final Future<void> Function() onRetryScore;

  final bool? consentActive;
  final int? pendingRequests;
  final List<ActivityItem> activity;
  final bool isLoadingActivity;
  final int unreadCount;
  final Future<void> Function() onRefresh;
  final Future<void> Function() onOpenNotifications;
  final Future<void> Function(ActivityTarget?) onOpenTarget;

  /// Opens a page, then refreshes Home when the borrower comes back.
  Future<void> _push(BuildContext context, Widget page) async {
    await Navigator.push(context, MaterialPageRoute(builder: (_) => page));
    await onRefresh();
  }

  @override
  Widget build(BuildContext context) {
    final double width = MediaQuery.of(context).size.width;
    final String avatarLetter = userName.trim().isNotEmpty
        ? userName.trim()[0].toUpperCase()
        : 'U';

    final double progress =
    score == null ? 0 : (score! / 100).clamp(0.0, 1.0);

    return RefreshIndicator(
      color: _purple,
      onRefresh: onRefresh,
      child: SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(
        horizontal: 24,
        vertical: 16,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Top bar
          Row(
            children: [
              CircleAvatar(
                radius: 22,
                backgroundColor: _purpleSoft,
                child: Text(
                  avatarLetter,
                  style: const TextStyle(
                    color: _purple,
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Welcome back',
                      style: TextStyle(
                        color: Colors.grey.shade500,
                        fontSize: 13,
                      ),
                    ),
                    Text(
                      isLoadingProfile
                          ? 'Loading profile...'
                          : userName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.black,
                      ),
                    ),
                  ],
                ),
              ),
              Tooltip(
                message: unreadCount > 0
                    ? '$unreadCount new notification${unreadCount == 1 ? '' : 's'}'
                    : 'Notifications',
                child: InkWell(
                  customBorder: const CircleBorder(),
                  onTap: () => onOpenNotifications(),
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.grey.shade300),
                        ),
                        child: Icon(
                          unreadCount > 0
                              ? Icons.notifications_active_outlined
                              : Icons.notifications_none_rounded,
                          color: Colors.black87,
                        ),
                      ),
                      if (unreadCount > 0)
                        Positioned(
                          right: -2,
                          top: -2,
                          child: Container(
                            constraints: const BoxConstraints(minWidth: 18),
                            height: 18,
                            padding: const EdgeInsets.symmetric(horizontal: 4),
                            decoration: BoxDecoration(
                              color: _purple,
                              borderRadius: BorderRadius.circular(9),
                              border: Border.all(color: Colors.white, width: 2),
                            ),
                            alignment: Alignment.center,
                            child: Text(
                              unreadCount > 9 ? '9+' : '$unreadCount',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 9,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),

          if (profileError != null) ...[
            const SizedBox(height: 12),
            _ErrorMessage(
              message: profileError!,
              onRetry: onRetryProfile,
            ),
          ],

          const SizedBox(height: 24),

          // Score card
          Container(
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(28),
              gradient: const LinearGradient(
                colors: [
                  Color(0xFF2C2C2E),
                  Color(0xFF000000),
                ],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
            child: (!isLoadingScore && score == null && scoreError == null)
                ? _FirstScoreGuide(consentActive: consentActive)
                : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'Your MtaaWorks Score',
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 14,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: _purple,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        isLoadingScore
                            ? 'Loading'
                            : tier ?? 'No tier',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    if (isLoadingScore)
                      const SizedBox(
                        height: 48,
                        width: 48,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 3,
                        ),
                      )
                    else
                      Text(
                        score?.toStringAsFixed(1) ?? '--',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: width * 0.16,
                          fontWeight: FontWeight.bold,
                          height: 1,
                        ),
                      ),
                    const SizedBox(width: 6),
                    const Padding(
                      padding: EdgeInsets.only(bottom: 8),
                      child: Text(
                        '/ 100',
                        style: TextStyle(
                          color: Colors.white54,
                          fontSize: 16,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: LinearProgressIndicator(
                    value: progress,
                    minHeight: 8,
                    backgroundColor: Colors.white24,
                    valueColor:
                    const AlwaysStoppedAnimation<Color>(
                      Color(0xFFA78BFA),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  lastScored ?? 'No score recorded yet',
                  style: const TextStyle(
                    color: Colors.white54,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),

          if (!isLoadingScore && scoreError != null) ...[
            const SizedBox(height: 12),
            _ErrorMessage(
              message: scoreError!,
              onRetry: onRetryScore,
            ),
          ],

          const SizedBox(height: 20),

          // Primary action
          Container(
            height: 54,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(27),
              border: Border.all(
                color: Colors.black,
                width: 1.2,
              ),
            ),
            child: ElevatedButton.icon(
              onPressed: () => _push(context, const ConsentPage()),
              icon: const Icon(
                Icons.upload_file_rounded,
                color: Colors.black,
              ),
              label: Text(
                consentActive == true ? 'Score a statement' : 'Get started',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.black,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                shadowColor: Colors.transparent,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(27),
                ),
              ),
            ),
          ),

          const SizedBox(height: 12),

          SizedBox(
            height: 54,
            child: OutlinedButton.icon(
              onPressed: () => _push(context, const LoanRequestsPage()),
              icon: const Icon(Icons.request_quote_outlined, color: _purple),
              label: const Text(
                'Loan requests',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: _purple,
                ),
              ),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: _purple, width: 1.2),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(27),
                ),
              ),
            ),
          ),

          const SizedBox(height: 12),

          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _push(context, const ScoreHistoryPage()),
                  icon: const Icon(Icons.show_chart_rounded, color: _purple),
                  label: const Text('Score history', style: TextStyle(color: _purple)),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: _purple, width: 1.2),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(27)),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _push(context, const AccessHistoryPage()),
                  icon: const Icon(Icons.visibility_outlined, color: _purple),
                  label: const Text('Who viewed', style: TextStyle(color: _purple)),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: _purple, width: 1.2),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(27)),
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          SizedBox(
            height: 54,
            child: OutlinedButton.icon(
              onPressed: () => _push(context, const ReportPage()),
              icon: const Icon(Icons.picture_as_pdf_rounded, color: _purple),
              label: const Text(
                'Credit report (PDF)',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: _purple),
              ),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: _purple, width: 1.2),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(27)),
              ),
            ),
          ),

          const SizedBox(height: 24),

          Row(
            children: [
              Expanded(
                child: _StatusCard(
                  icon: Icons.verified_user_outlined,
                  title: 'Consent',
                  chipText: isLoadingActivity
                      ? 'Loading'
                      : consentActive == null
                          ? 'Unavailable'
                          : consentActive!
                              ? 'Active'
                              : 'Not given',
                  chipColor: consentActive == true
                      ? const Color(0xFFE7F6EC)
                      : const Color(0xFFFFF8E8),
                  chipTextColor: consentActive == true
                      ? const Color(0xFF1E8E4E)
                      : const Color(0xFFB7791F),
                  // Consent is managed on the profile screen.
                  onTap: () => onOpenTarget(ActivityTarget.profile),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: _StatusCard(
                  icon: Icons.business_outlined,
                  title: 'Lender requests',
                  chipText: isLoadingActivity
                      ? 'Loading'
                      : pendingRequests == null
                          ? 'Unavailable'
                          : '$pendingRequests pending',
                  chipColor: _purpleSoft,
                  chipTextColor: _purple,
                  onTap: () => onOpenTarget(ActivityTarget.requests),
                ),
              ),
            ],
          ),

          const SizedBox(height: 28),

          Row(
            children: [
              const Expanded(
                child: Text(
                  'Recent activity',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                    color: Colors.black,
                  ),
                ),
              ),
              if (activity.length > 5)
                TextButton(
                  onPressed: () => onOpenNotifications(),
                  child: const Text(
                    'See all',
                    style: TextStyle(color: _purple, fontWeight: FontWeight.w700),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),

          if (isLoadingActivity)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 20),
              child: Center(
                child: SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(strokeWidth: 2, color: _purple),
                ),
              ),
            )
          else if (activity.isEmpty)
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: _cardFill,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Text(
                'No activity yet. Give consent and score a statement to get started.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
              ),
            )
          else
            for (final item in activity.take(5))
              _ActivityTile(
                icon: item.icon,
                title: item.title,
                subtitle: item.subtitle,
                time: timeAgo(item.when),
                onTap: () => onOpenTarget(item.target),
              ),
          const SizedBox(height: 8),
        ],
      ),
      ),
    );
  }
}

class _ErrorMessage extends StatelessWidget {
  const _ErrorMessage({
    required this.message,
    required this.onRetry,
  });

  final String message;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.red.shade50,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            message,
            style: TextStyle(
              color: Colors.red.shade700,
              fontSize: 13,
            ),
          ),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton(
              onPressed: () => onRetry(),
              child: const Text('Try again'),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusCard extends StatelessWidget {
  const _StatusCard({
    required this.icon,
    required this.title,
    required this.chipText,
    required this.chipColor,
    required this.chipTextColor,
    this.onTap,
  });

  final IconData icon;
  final String title;
  final String chipText;
  final Color chipColor;
  final Color chipTextColor;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _cardFill,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: Colors.black87),
          const SizedBox(height: 14),
          Text(
            title,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: 10,
              vertical: 4,
            ),
            decoration: BoxDecoration(
              color: chipColor,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              chipText,
              style: TextStyle(
                color: chipTextColor,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
      ),
    );
  }
}

class _ActivityTile extends StatelessWidget {
  const _ActivityTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.time,
    this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final String time;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _cardFill,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: const BoxDecoration(
              color: _purpleSoft,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: _purple, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(
                    color: Colors.grey.shade500,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          Text(
            time,
            style: TextStyle(
              color: Colors.grey.shade500,
              fontSize: 12,
            ),
          ),
        ],
      ),
      ),
      ),
    );
  }
}
/// Shown in the score card until the borrower has a first score.
class _FirstScoreGuide extends StatelessWidget {
  const _FirstScoreGuide({required this.consentActive});

  final bool? consentActive;

  @override
  Widget build(BuildContext context) {
    final bool consentDone = consentActive == true;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Get your first score',
          style: TextStyle(
            color: Colors.white,
            fontSize: 22,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 4),
        const Text(
          'Three steps. Scoring takes about a minute.',
          style: TextStyle(color: Colors.white70, fontSize: 13),
        ),
        const SizedBox(height: 18),
        _GuideStep(
          number: 1,
          done: consentDone,
          title: 'Give consent',
          detail: 'Allow MtaaWorks to analyse your statement.',
        ),
        const _GuideStep(
          number: 2,
          done: false,
          title: 'Upload your M-PESA statement',
          detail: 'A PDF covering at least 3 full months, with its password. '
              'You can request a full statement from the M-PESA app.',
        ),
        const _GuideStep(
          number: 3,
          done: false,
          title: 'See your score',
          detail: 'Your tier and what helped or held it back.',
          last: true,
        ),
      ],
    );
  }
}

class _GuideStep extends StatelessWidget {
  const _GuideStep({
    required this.number,
    required this.done,
    required this.title,
    required this.detail,
    this.last = false,
  });

  final int number;
  final bool done;
  final String title;
  final String detail;
  final bool last;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: last ? 0 : 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 28,
            height: 28,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: done ? const Color(0xFF1E8E4E) : Colors.white12,
              border: Border.all(color: done ? const Color(0xFF1E8E4E) : Colors.white38),
            ),
            child: done
                ? const Icon(Icons.check_rounded, color: Colors.white, size: 16)
                : Text(
              '$number',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 13,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  done ? '$title (done)' : title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  detail,
                  style: const TextStyle(color: Colors.white60, fontSize: 12.5, height: 1.35),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
