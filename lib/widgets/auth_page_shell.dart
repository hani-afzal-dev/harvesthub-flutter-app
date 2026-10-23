import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'offline_banner.dart';

const Color _brand = Color(0xFF3B6D11);
const Color _textMain = Color(0xFF22301A);
const Color _textMuted = Color(0xFF6B7A5E);

class AuthPageShell extends StatelessWidget {
  final String pillLabel;
  final String title;
  final String subtitle;
  final List<Widget> children;
  final VoidCallback? onBack;

  const AuthPageShell({
    super.key,
    required this.pillLabel,
    required this.title,
    required this.subtitle,
    required this.children,
    this.onBack,
  });

  @override
  Widget build(BuildContext context) {
    final topInset = MediaQuery.paddingOf(context).top;
    final back = onBack ??
        (Navigator.of(context).canPop()
            ? () => Navigator.of(context).pop()
            : null);
    final canGoBack = back != null;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light
          .copyWith(statusBarColor: Colors.transparent),
      child: Scaffold(
        backgroundColor: const Color(0xFFF6F8F3),
        body: SingleChildScrollView(
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          child: Column(
            children: [
              Container(
                width: double.infinity,
                padding: EdgeInsets.fromLTRB(24, topInset + 8, 24, 72),
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xFF5A9A1F), _brand, Color(0xFF2A4A0C)],
                  ),
                ),
                child: Column(
                  children: [
                    Align(
                      alignment: Alignment.centerLeft,
                      child: canGoBack
                          ? IconButton(
                              tooltip: 'Back',
                              onPressed: back,
                              icon: const Icon(Icons.chevron_left_rounded,
                                  color: Colors.white, size: 28),
                            )
                          : const SizedBox(height: 48),
                    ),
                    SizedBox(
                      width: 96,
                      height: 96,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          Container(
                            width: 76,
                            height: 76,
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.14),
                              borderRadius: BorderRadius.circular(24),
                              border: Border.all(
                                  color: Colors.white.withValues(alpha: 0.32),
                                  width: 1.5),
                            ),
                          ),
                          Image.asset(
                            'assets/icon/app_icon_foreground.png',
                            width: 96,
                            height: 96,
                            semanticLabel: 'HarvestHub logo',
                            errorBuilder: (context, error, stackTrace) =>
                                const Icon(Icons.eco_outlined,
                                    color: Colors.white, size: 30),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                    const FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        'HarvestHub',
                        maxLines: 1,
                        style: TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.w800,
                            color: Colors.white),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Fresh from the farm, straight to you',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          fontSize: 14,
                          color: Colors.white.withValues(alpha: 0.9)),
                    ),
                    const SizedBox(height: 14),
                    Semantics(
                      button: canGoBack,
                      label:
                          canGoBack ? '$pillLabel. Tap to go back' : pillLabel,
                      excludeSemantics: true,
                      child: InkWell(
                        onTap: back,
                        borderRadius: BorderRadius.circular(20),
                        child: Container(
                          constraints: const BoxConstraints(minHeight: 36),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.14),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                                color: Colors.white.withValues(alpha: 0.5)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: 6,
                                height: 6,
                                decoration: const BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: Colors.white),
                              ),
                              const SizedBox(width: 8),
                              Flexible(
                                child: Text(
                                  pillLabel,
                                  style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Transform.translate(
                offset: const Offset(0, -44),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 480),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const OfflineBanner(),
                          Container(
                            padding: const EdgeInsets.fromLTRB(20, 24, 20, 16),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(24),
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(0xFF2E4A0F)
                                      .withValues(alpha: 0.10),
                                  blurRadius: 24,
                                  offset: const Offset(0, 10),
                                ),
                              ],
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Text(
                                  title,
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                      fontSize: 22,
                                      fontWeight: FontWeight.w800,
                                      color: _textMain),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  subtitle,
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                      fontSize: 13, color: _textMuted),
                                ),
                                const SizedBox(height: 20),
                                ...children,
                              ],
                            ),
                          ),
                          const SizedBox(height: 20),
                          const Row(
                            children: [
                              _Highlight(
                                  icon: Icons.agriculture_outlined,
                                  label: 'Local farms'),
                              _Highlight(
                                  icon: Icons.verified_user_outlined,
                                  label: 'Secure login'),
                              _Highlight(
                                  icon: Icons.storefront_outlined,
                                  label: 'Easy pickup'),
                            ],
                          ),
                          SizedBox(
                              height: MediaQuery.paddingOf(context).bottom),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class AuthOrDivider extends StatelessWidget {
  const AuthOrDivider({super.key});

  @override
  Widget build(BuildContext context) {
    return const Row(
      children: [
        Expanded(child: Divider(color: Color(0xFFE1E7D8))),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 10),
          child: Text(
            'OR CONTINUE WITH',
            style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.8,
                color: _textMuted),
          ),
        ),
        Expanded(child: Divider(color: Color(0xFFE1E7D8))),
      ],
    );
  }
}

class GoogleAuthButton extends StatelessWidget {
  final bool busy;
  final VoidCallback? onPressed;

  const GoogleAuthButton(
      {super.key, required this.busy, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 52,
      child: OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          backgroundColor: const Color(0xFFF1F4EC),
          foregroundColor: _textMain,
          side: BorderSide.none,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
        child: busy
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2, color: _brand),
              )
            : const Text('Continue with Google',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
      ),
    );
  }
}

class AuthSwitchLink extends StatelessWidget {
  final String prompt;
  final String action;
  final VoidCallback onPressed;

  const AuthSwitchLink(
      {super.key,
      required this.prompt,
      required this.action,
      required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: TextButton(
        onPressed: onPressed,
        style: TextButton.styleFrom(minimumSize: const Size(48, 48)),
        child: Text.rich(
          TextSpan(
            text: '$prompt ',
            style: const TextStyle(fontSize: 14, color: _textMuted),
            children: [
              TextSpan(
                  text: action,
                  style: const TextStyle(
                      fontWeight: FontWeight.w800, color: _brand)),
            ],
          ),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}

class _Highlight extends StatelessWidget {
  final IconData icon;
  final String label;

  const _Highlight({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Icon(icon, size: 22, color: _brand),
          const SizedBox(height: 4),
          Text(label,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 12, color: _textMuted)),
        ],
      ),
    );
  }
}
