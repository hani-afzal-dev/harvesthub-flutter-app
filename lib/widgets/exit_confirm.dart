import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

Future<void> askExit(BuildContext context) async {
  final yes = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Exit app?'),
      content: const Text('Do you want to close the app?'),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(false),
          child: const Text('No'),
        ),
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(true),
          child: const Text('Yes'),
        ),
      ],
    ),
  );

  if (yes == true) SystemNavigator.pop();
}