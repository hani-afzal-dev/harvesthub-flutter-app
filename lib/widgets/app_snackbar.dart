import 'package:flutter/material.dart';

enum SnackTone { info, success, error }

SnackBar appSnackBar(String message,
    {SnackTone tone = SnackTone.info, SnackBarAction? action}) {
  var icon = Icons.info_outline_rounded;
  var iconColor = const Color(0xFFB9D98F);
  var duration = const Duration(seconds: 3);
  if (tone == SnackTone.success) {
    icon = Icons.check_circle_rounded;
    iconColor = const Color(0xFF9FD86B);
  }
  if (tone == SnackTone.error) {
    icon = Icons.error_outline_rounded;
    iconColor = const Color(0xFFFFB4A8);
    duration = const Duration(seconds: 5);
  }

  return SnackBar(
    duration: duration,
    action: action,
    content: Row(
      children: [
        Icon(icon, color: iconColor, size: 22),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            message,
            style: const TextStyle(
                fontSize: 14,
                height: 1.35,
                color: Colors.white,
                fontWeight: FontWeight.w500),
          ),
        ),
      ],
    ),
  );
}
