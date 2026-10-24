import 'package:flutter/material.dart';

class StarRatingWidget extends StatelessWidget {
  final int value;
  final ValueChanged<int>? onChanged;

  const StarRatingWidget({super.key, required this.value, this.onChanged});

  @override
  Widget build(BuildContext context) {
    final callback = onChanged;
    return Semantics(
      label: 'Rating: $value out of 5 stars',
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: List.generate(5, (index) {
          final filled = index < value;
          return IconButton(
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
            tooltip: '${index + 1} star${index == 0 ? '' : 's'}',
            onPressed: callback == null ? null : () => callback(index + 1),
            icon: Icon(filled ? Icons.star : Icons.star_border,
                color: const Color(0xFFEF9F27)),
          );
        }),
      ),
    );
  }
}
