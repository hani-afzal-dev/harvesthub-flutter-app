import 'package:flutter/material.dart';

const Color _brand = Color(0xFF3B6D11);
const Color _textMain = Color(0xFF22301A);
const Color _textMuted = Color(0xFF6B7A5E);

class AsyncErrorView extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  final String title;
  final IconData icon;
  final bool compact;

  const AsyncErrorView({
    super.key,
    required this.message,
    required this.onRetry,
    this.title = 'Something went wrong',
    this.icon = Icons.cloud_off_rounded,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final circle = compact ? 56.0 : 88.0;

    return Center(
      child: SingleChildScrollView(
        padding: EdgeInsets.all(compact ? 16 : 32),
        child: Semantics(
          liveRegion: true,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: circle,
                height: circle,
                decoration: const BoxDecoration(
                    shape: BoxShape.circle, color: Color(0xFFFBEDEA)),
                child: Icon(icon,
                    size: circle * 0.45, color: const Color(0xFFB3261E)),
              ),
              SizedBox(height: compact ? 10 : 16),
              Text(
                title,
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontSize: compact ? 15 : 18,
                    fontWeight: FontWeight.w700,
                    color: _textMain),
              ),
              const SizedBox(height: 6),
              Text(
                message,
                textAlign: TextAlign.center,
                style: const TextStyle(
                    fontSize: 14, height: 1.4, color: _textMuted),
              ),
              SizedBox(height: compact ? 12 : 20),
              FilledButton.icon(
                onPressed: onRetry,
                style: FilledButton.styleFrom(
                  backgroundColor: _brand,
                  minimumSize: const Size(140, 48),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                icon: const Icon(Icons.refresh_rounded, size: 20),
                label: const Text('Try again',
                    style: TextStyle(fontWeight: FontWeight.w700)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
