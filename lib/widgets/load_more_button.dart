import 'package:flutter/material.dart';

class LoadMoreButton extends StatelessWidget {
  final VoidCallback onPressed;

  const LoadMoreButton({super.key, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Center(
        child: OutlinedButton(
          onPressed: onPressed,
          style: OutlinedButton.styleFrom(
            foregroundColor: const Color(0xFF3B6D11),
            minimumSize: const Size(160, 48),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          ),
          child: const Text('Load more',
              style: TextStyle(fontWeight: FontWeight.w700)),
        ),
      ),
    );
  }
}
