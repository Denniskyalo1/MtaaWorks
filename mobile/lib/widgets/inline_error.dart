import 'package:flutter/material.dart';

/// An error message that stays on the page until the user acts.
class InlineError extends StatelessWidget {
  const InlineError(this.message, {super.key});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      liveRegion: true, // read out by screen readers when it appears
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xFFFDECEC),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFF5B5B5)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.error_outline_rounded, color: Color(0xFFC62828), size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(color: Color(0xFF8E1B1B), fontSize: 13.5, height: 1.4),
              ),
            ),
          ],
        ),
      ),
    );
  }
}