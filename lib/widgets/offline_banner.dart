import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/connectivity_providers.dart';

class OfflineNotice extends StatelessWidget {
  final String message;

  const OfflineNotice({super.key, required this.message});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      liveRegion: true,
      child: Container(
        width: double.infinity,
        color: const Color(0xFFFDF2E3),
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.cloud_off, size: 16, color: Color(0xFF8A6A1F)),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                message,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 12, color: Color(0xFF8A6A1F)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class OfflineBanner extends ConsumerWidget {
  const OfflineBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final online = ref.watch(connectivityProvider).valueOrNull ?? true;
    if (online) return const SizedBox.shrink();
    return const OfflineNotice(
        message: 'No connection. Saved data is shown where available.');
  }
}
