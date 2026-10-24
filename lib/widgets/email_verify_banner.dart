import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/service_providers.dart';
import '../providers/verification_providers.dart';
import 'app_snackbar.dart';

class EmailVerifyBanner extends ConsumerStatefulWidget {
  const EmailVerifyBanner({super.key});

  @override
  ConsumerState<EmailVerifyBanner> createState() => _EmailVerifyBannerState();
}

class _EmailVerifyBannerState extends ConsumerState<EmailVerifyBanner>
    with WidgetsBindingObserver {
  bool _sending = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) ref.read(emailVerifiedProvider.notifier).refresh();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      ref.read(emailVerifiedProvider.notifier).refresh();
    }
  }

  Future<void> _resend() async {
    if (_sending) return;
    setState(() => _sending = true);
    final authService = ref.read(authServiceProvider);
    String message = 'Verification email sent. Check your inbox.';
    var tone = SnackTone.success;
    try {
      await authService.sendVerificationEmail();
    } on FirebaseAuthException catch (e) {
      message = authService.mapAuthError(e);
      tone = SnackTone.error;
    } catch (_) {
      message = 'Something went wrong. Please try again.';
      tone = SnackTone.error;
    }
    if (!mounted) return;
    setState(() => _sending = false);
    ScaffoldMessenger.of(context)
        .showSnackBar(appSnackBar(message, tone: tone));
  }

  @override
  Widget build(BuildContext context) {
    final verified = ref.watch(emailVerifiedProvider);
    if (verified) return const SizedBox.shrink();

    return Material(
      color: const Color(0xFFFDF2E3),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          children: [
            const Icon(Icons.mark_email_unread_outlined,
                size: 16, color: Color(0xFF8A6A1F)),
            const SizedBox(width: 10),
            const Expanded(
              child: Text(
                'Please verify your email. Check your inbox for a link from HarvestHub.',
                style: TextStyle(fontSize: 12, color: Color(0xFF8A6A1F)),
              ),
            ),
            TextButton(
              key: const ValueKey('resend_verification_button'),
              onPressed: _sending ? null : _resend,
              child: const Text('Resend'),
            ),
          ],
        ),
      ),
    );
  }
}
