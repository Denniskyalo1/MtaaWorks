
import 'package:flutter/material.dart';
import 'package:mtaaworks/profile_page.dart';
import 'lender_requests_page.dart';
import 'consent_page.dart';
import 'services/api_service.dart';

const int _pendingRequests = 2;

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

  @override
  void initState() {
    super.initState();
    _loadProfile();
    _loadLatestScore();
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
            e.toString().replaceFirst('Exception: ', '');
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
          _scoreError = response['message']?.toString() ??
              'No credit score yet. Score a statement to get started.';
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
            e.toString().replaceFirst('Exception: ', '');
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
        )
            : _tab == 1
            ? const LenderRequestsPage()
            : const ProfilePage()
      ),
      bottomNavigationBar: NavigationBar(
        backgroundColor: Colors.white,
        indicatorColor: _purpleSoft,
        selectedIndex: _tab,
        onDestinationSelected: (i) => setState(() => _tab = i),
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

  @override
  Widget build(BuildContext context) {
    final double width = MediaQuery.of(context).size.width;
    final String avatarLetter = userName.trim().isNotEmpty
        ? userName.trim()[0].toUpperCase()
        : 'U';

    final double progress =
    score == null ? 0 : (score! / 100).clamp(0.0, 1.0);

    return SingleChildScrollView(
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
              Stack(
                clipBehavior: Clip.none,
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                    child: const Icon(
                      Icons.notifications_none_rounded,
                      color: Colors.black87,
                    ),
                  ),
                  Positioned(
                    right: 2,
                    top: 2,
                    child: Container(
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(
                        color: _purple,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: Colors.white,
                          width: 2,
                        ),
                      ),
                    ),
                  ),
                ],
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
            child: Column(
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
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const ConsentPage(),
                  ),
                );
              },
              icon: const Icon(
                Icons.upload_file_rounded,
                color: Colors.black,
              ),
              label: const Text(
                'Score a statement',
                style: TextStyle(
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

          const SizedBox(height: 24),

          Row(
            children: const [
              Expanded(
                child: _StatusCard(
                  icon: Icons.verified_user_outlined,
                  title: 'Consent',
                  chipText: 'Active',
                  chipColor: Color(0xFFE7F6EC),
                  chipTextColor: Color(0xFF1E8E4E),
                ),
              ),
              SizedBox(width: 14),
              Expanded(
                child: _StatusCard(
                  icon: Icons.business_outlined,
                  title: 'Lender requests',
                  chipText: '$_pendingRequests pending',
                  chipColor: _purpleSoft,
                  chipTextColor: _purple,
                ),
              ),
            ],
          ),

          const SizedBox(height: 28),

          const Text(
            'Recent activity',
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.bold,
              color: Colors.black,
            ),
          ),
          const SizedBox(height: 12),

          const _ActivityTile(
            icon: Icons.insights_rounded,
            title: 'Statement scored',
            subtitle: 'Latest scoring activity',
            time: 'Recent',
          ),
          const _ActivityTile(
            icon: Icons.business_outlined,
            title: 'Lender access',
            subtitle: 'Lender request activity',
            time: 'Recent',
          ),
          const _ActivityTile(
            icon: Icons.verified_user_outlined,
            title: 'Consent',
            subtitle: 'Statement analysis consent',
            time: 'Recent',
          ),
          const SizedBox(height: 8),
        ],
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
  });

  final IconData icon;
  final String title;
  final String chipText;
  final Color chipColor;
  final Color chipTextColor;

  @override
  Widget build(BuildContext context) {
    return Container(
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
    );
  }
}

class _ActivityTile extends StatelessWidget {
  const _ActivityTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.time,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final String time;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
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
    );
  }
}
