import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

const Color _brand = Color(0xFF3B6D11);
const Color _brandDark = Color(0xFF2E4A0F);
const Color _textMain = Color(0xFF22301A);

class PageHeader extends StatelessWidget {
  final String title;
  final VoidCallback? onBack;
  final Widget? trailing;

  const PageHeader(
      {super.key, required this.title, this.onBack, this.trailing});

  @override
  Widget build(BuildContext context) {
    VoidCallback? backAction = onBack;
    if (backAction == null && Navigator.of(context).canPop()) {
      backAction = () => Navigator.of(context).maybePop();
    }
    final action = trailing;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark
          .copyWith(statusBarColor: Colors.transparent),
      child: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          border: Border(bottom: BorderSide(color: Color(0xFFE3E9DA))),
        ),
        padding: EdgeInsets.fromLTRB(
            12, MediaQuery.paddingOf(context).top + 8, 12, 8),
        child: Row(
          children: [
            if (backAction != null)
              Semantics(
                button: true,
                label: 'Back',
                child: InkWell(
                  onTap: backAction,
                  borderRadius: BorderRadius.circular(14),
                  child: SizedBox(
                    width: 48,
                    height: 48,
                    child: Center(
                      child: Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: _brandDark.withValues(alpha: 0.08),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: const Icon(Icons.chevron_left_rounded,
                            color: _textMain),
                      ),
                    ),
                  ),
                ),
              ),
            const SizedBox(width: 6),
            Expanded(
              child: Semantics(
                header: true,
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      fontSize: 22, fontWeight: FontWeight.w800, color: _brand),
                ),
              ),
            ),
            if (action != null) action,
          ],
        ),
      ),
    );
  }
}
