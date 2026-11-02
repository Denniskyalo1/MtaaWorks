import 'package:flutter/material.dart';

/// Colours shared with the lender portal.
class AdminColors {
  static const primary = Color(0xFF5B3CC4);
  static const primarySoft = Color(0xFFEDE8FB);
  static const background = Color(0xFFF7F6FC);
  static const border = Color(0xFFE8E5F0);
  static const text = Color(0xFF242136);
  static const muted = Color(0xFF77718F);
  static const green = Color(0xFF1E8E4E);
  static const greenSoft = Color(0xFFE7F6EC);
  static const red = Color(0xFFB42318);
  static const redSoft = Color(0xFFFFF0F0);
  static const amber = Color(0xFFB7791F);
  static const amberSoft = Color(0xFFFFF8E8);
}

String errorText(Object error) =>
    error.toString().replaceFirst('Exception: ', '');

/// '2026-11-02T07:31:00.000000Z' -> '2 Nov 2026, 10:31' (local time).
String formatDateTime(dynamic value) {
  final parsed = DateTime.tryParse(value?.toString() ?? '')?.toLocal();
  if (parsed == null) return '—';

  const months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];
  final hh = parsed.hour.toString().padLeft(2, '0');
  final mm = parsed.minute.toString().padLeft(2, '0');

  return '${parsed.day} ${months[parsed.month - 1]} ${parsed.year}, $hh:$mm';
}

/// 'digital_lender' -> 'Digital lender', 'sacco' -> 'SACCO'.
String humanise(String? value) {
  if (value == null || value.isEmpty) return '—';
  const special = {'sacco': 'SACCO', 'mfi': 'MFI'};
  if (special.containsKey(value)) return special[value]!;

  final words = value.replaceAll('_', ' ').replaceAll('.', ' ');
  return words[0].toUpperCase() + words.substring(1);
}

void showMessage(BuildContext context, String message) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text(message)),
  );
}

class PageHeader extends StatelessWidget {
  const PageHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.action,
  });

  final String title;
  final String? subtitle;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: AdminColors.text,
                  ),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    subtitle!,
                    style: const TextStyle(color: AdminColors.muted, fontSize: 13.5),
                  ),
                ],
              ],
            ),
          ),
          if (action != null) action!,
        ],
      ),
    );
  }
}

class StatusChip extends StatelessWidget {
  const StatusChip(this.label, {super.key, this.tone = ChipTone.neutral});

  final String label;
  final ChipTone tone;

  @override
  Widget build(BuildContext context) {
    final (bg, fg) = switch (tone) {
      ChipTone.good => (AdminColors.greenSoft, AdminColors.green),
      ChipTone.bad => (AdminColors.redSoft, AdminColors.red),
      ChipTone.warn => (AdminColors.amberSoft, AdminColors.amber),
      ChipTone.brand => (AdminColors.primarySoft, AdminColors.primary),
      ChipTone.neutral => (const Color(0xFFF1F0F5), AdminColors.muted),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: TextStyle(color: fg, fontSize: 12, fontWeight: FontWeight.w700),
      ),
    );
  }
}

enum ChipTone { good, bad, warn, brand, neutral }

class AdminCard extends StatelessWidget {
  const AdminCard({super.key, required this.child, this.padding});

  final Widget child;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding ?? const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AdminColors.border),
      ),
      child: child,
    );
  }
}

class ErrorState extends StatelessWidget {
  const ErrorState({super.key, required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.cloud_off_outlined, size: 40, color: AdminColors.muted),
            const SizedBox(height: 12),
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            OutlinedButton(onPressed: onRetry, child: const Text('Try again')),
          ],
        ),
      ),
    );
  }
}

class EmptyState extends StatelessWidget {
  const EmptyState({super.key, required this.icon, required this.message});

  final IconData icon;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 48),
      child: Column(
        children: [
          Icon(icon, size: 40, color: AdminColors.muted),
          const SizedBox(height: 12),
          Text(message, style: const TextStyle(color: AdminColors.muted)),
        ],
      ),
    );
  }
}

/// "Load more" button for paginated lists.
class LoadMoreButton extends StatelessWidget {
  const LoadMoreButton({
    super.key,
    required this.loading,
    required this.onPressed,
  });

  final bool loading;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Center(
        child: loading
            ? const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : OutlinedButton(onPressed: onPressed, child: const Text('Load more')),
      ),
    );
  }
}
