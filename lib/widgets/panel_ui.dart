import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class PanelColors {
  static const Color brand = Color(0xFF3B6D11);
  static const Color brandDark = Color(0xFF2E4A0F);
  static const Color textMain = Color(0xFF22301A);
  static const Color textBody = Color(0xFF4C5943);
  static const Color textMuted = Color(0xFF6B7A5E);
  static const Color tint = Color(0xFFEFF3EA);
  static const Color pageBg = Color(0xFFF6F8F3);
  static const Color border = Color(0xFFE3E9DA);
  static const Color cardBorder = Color(0xFFD6DEC7);
  static const Color amber = Color(0xFF8A5A00);
  static const Color amberBg = Color(0xFFFDF2E3);
  static const Color blue = Color(0xFF1F5FA8);
  static const Color blueBg = Color(0xFFE6F0FB);
  static const Color danger = Color(0xFFB3261E);
  static const Color dangerBg = Color(0xFFFBE9E7);
  static const Color greyBg = Color(0xFFEDEFEA);
}

class PanelHeader extends StatelessWidget {
  final String title;
  final String? subtitle;
  final Widget? trailing;

  const PanelHeader(
      {super.key, required this.title, this.subtitle, this.trailing});

  @override
  Widget build(BuildContext context) {
    final action = trailing;
    final caption = subtitle;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark
          .copyWith(statusBarColor: Colors.transparent),
      child: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          border: Border(bottom: BorderSide(color: PanelColors.border)),
        ),
        padding: EdgeInsets.fromLTRB(
            20, MediaQuery.paddingOf(context).top + 10, 12, 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Semantics(
                    header: true,
                    child: Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.w800,
                        color: PanelColors.brandDark,
                      ),
                    ),
                  ),
                  if (caption != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      caption,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontSize: 13,
                          height: 1.35,
                          color: PanelColors.textMuted),
                    ),
                  ],
                ],
              ),
            ),
            if (action != null) ...[const SizedBox(width: 8), action],
          ],
        ),
      ),
    );
  }
}

class PanelStatStrip extends StatelessWidget {
  final List<(String, String)> stats;
  final List<IconData?>? icons;
  final List<Color>? valueColors;

  const PanelStatStrip({
    super.key,
    required this.stats,
    this.icons,
    this.valueColors,
  });

  @override
  Widget build(BuildContext context) {
    return PanelCard(
      padding: const EdgeInsets.symmetric(vertical: 14),
      child: IntrinsicHeight(
        child: Row(
          children: [
            for (var i = 0; i < stats.length; i++) ...[
              if (i > 0)
                const VerticalDivider(
                    width: 1, thickness: 1, color: PanelColors.border),
              Expanded(
                child: Semantics(
                  label: '${stats[i].$2}: ${stats[i].$1}',
                  excludeSemantics: true,
                  child: Column(
                    children: [
                      if (icons != null && icons![i] != null) ...[
                        Icon(icons![i],
                            size: 18,
                            color: valueColors?[i] ?? PanelColors.textMain),
                        const SizedBox(height: 4),
                      ],
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          stats[i].$1,
                          maxLines: 1,
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                            color: valueColors?[i] ?? PanelColors.textMain,
                            fontFeatures: const [FontFeature.tabularFigures()],
                          ),
                        ),
                      ),
                      Text(
                        stats[i].$2,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontSize: 12, color: PanelColors.textMuted),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class PanelCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;
  final Color? borderColor;

  const PanelCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.onTap,
    this.borderColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: borderColor ?? PanelColors.cardBorder),
        boxShadow: [
          BoxShadow(
            color: PanelColors.brandDark.withValues(alpha: 0.10),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
          BoxShadow(
            color: PanelColors.brandDark.withValues(alpha: 0.05),
            blurRadius: 2,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(18),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(padding: padding, child: child),
        ),
      ),
    );
  }
}

class StatusPill extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final Color background;

  const StatusPill({
    super.key,
    required this.label,
    required this.icon,
    required this.color,
    required this.background,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
          color: background, borderRadius: BorderRadius.circular(10)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                  fontSize: 12, fontWeight: FontWeight.w700, color: color),
            ),
          ),
        ],
      ),
    );
  }
}

class PanelEmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  const PanelEmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    this.actionLabel,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    final label = actionLabel;
    final action = onAction;
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: PanelColors.tint,
                borderRadius: BorderRadius.circular(22),
              ),
              child: Icon(icon, size: 34, color: PanelColors.brand),
            ),
            const SizedBox(height: 16),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                  color: PanelColors.textMain),
            ),
            const SizedBox(height: 6),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(
                  fontSize: 14, height: 1.45, color: PanelColors.textMuted),
            ),
            if (label != null && action != null) ...[
              const SizedBox(height: 20),
              FilledButton.icon(
                onPressed: action,
                style: FilledButton.styleFrom(
                  backgroundColor: PanelColors.brand,
                  minimumSize: const Size(0, 48),
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                ),
                icon: const Icon(Icons.add_rounded),
                label: Text(label,
                    style: const TextStyle(fontWeight: FontWeight.w700)),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class FilterChipBar extends StatelessWidget {
  final List<String> labels;
  final List<int> counts;
  final int selected;
  final ValueChanged<int> onSelected;

  const FilterChipBar({
    super.key,
    required this.labels,
    required this.counts,
    required this.selected,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 44,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: labels.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final isSelected = index == selected;
          final count = counts[index];
          return Semantics(
            button: true,
            selected: isSelected,
            label: '${labels[index]}, $count',
            excludeSemantics: true,
            child: Material(
              color: isSelected ? PanelColors.brand : Colors.white,
              borderRadius: BorderRadius.circular(22),
              child: InkWell(
                borderRadius: BorderRadius.circular(22),
                onTap: () => onSelected(index),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(22),
                    border: Border.all(
                        color: isSelected
                            ? PanelColors.brand
                            : PanelColors.border),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        labels[index],
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color:
                              isSelected ? Colors.white : PanelColors.textBody,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 7, vertical: 1),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? Colors.white.withValues(alpha: 0.22)
                              : PanelColors.tint,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          '$count',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color:
                                isSelected ? Colors.white : PanelColors.brand,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class PanelSectionLabel extends StatelessWidget {
  final String text;

  const PanelSectionLabel(this.text, {super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Text(
        text.toUpperCase(),
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.9,
          color: PanelColors.textMuted,
        ),
      ),
    );
  }
}

InputDecoration panelInputDecoration(
  String label, {
  String? hint,
  String? helper,
  String? error,
  String? prefixText,
  IconData? icon,
}) {
  return InputDecoration(
    labelText: label,
    hintText: hint,
    helperText: helper,
    errorText: error,
    errorMaxLines: 2,
    helperMaxLines: 2,
    prefixText: prefixText,
    prefixIcon: icon == null
        ? null
        : Icon(icon, size: 20, color: PanelColors.textMuted),
    filled: true,
    fillColor: PanelColors.pageBg,
    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: const BorderSide(color: PanelColors.border),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: const BorderSide(color: PanelColors.border),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: const BorderSide(color: PanelColors.brand, width: 1.5),
    ),
    errorBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: const BorderSide(color: PanelColors.danger),
    ),
    focusedErrorBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: const BorderSide(color: PanelColors.danger, width: 1.5),
    ),
  );
}

class PanelSearchField extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final ValueChanged<String> onChanged;

  const PanelSearchField({
    super.key,
    required this.controller,
    required this.hint,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
      child: TextField(
        controller: controller,
        onChanged: onChanged,
        textInputAction: TextInputAction.search,
        decoration: InputDecoration(
          hintText: hint,
          prefixIcon: const Icon(Icons.search_rounded,
              color: PanelColors.textMuted, size: 22),
          suffixIcon: controller.text.isEmpty
              ? null
              : IconButton(
                  tooltip: 'Clear search',
                  icon: const Icon(Icons.close_rounded, size: 20),
                  onPressed: () {
                    controller.clear();
                    onChanged('');
                  },
                ),
          filled: true,
          fillColor: Colors.white,
          contentPadding: const EdgeInsets.symmetric(vertical: 12),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: PanelColors.border),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: PanelColors.border),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: PanelColors.brand, width: 1.5),
          ),
        ),
      ),
    );
  }
}

class PanelAvatar extends StatelessWidget {
  final String name;
  final IconData? icon;
  final double size;
  final bool muted;

  const PanelAvatar({
    super.key,
    required this.name,
    this.icon,
    this.size = 44,
    this.muted = false,
  });

  @override
  Widget build(BuildContext context) {
    final parts = name.trim().split(RegExp(r'\s+'));
    var initials = '';
    for (final part in parts.take(2)) {
      if (part.isNotEmpty) initials += part[0].toUpperCase();
    }
    final avatarIcon = icon;
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: muted ? PanelColors.greyBg : PanelColors.tint,
        borderRadius: BorderRadius.circular(size * 0.32),
      ),
      child: avatarIcon != null || initials.isEmpty
          ? Icon(avatarIcon ?? Icons.person_outline_rounded,
              size: size * 0.5,
              color: muted ? PanelColors.textMuted : PanelColors.brand)
          : Text(
              initials,
              style: TextStyle(
                fontSize: size * 0.36,
                fontWeight: FontWeight.w800,
                color: muted ? PanelColors.textMuted : PanelColors.brand,
              ),
            ),
    );
  }
}

Future<bool> showPanelConfirm(
  BuildContext context, {
  required String title,
  required String message,
  required String confirmLabel,
  String cancelLabel = 'Cancel',
  bool destructive = true,
}) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text(title),
      content: Text(message),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(false),
          child: Text(cancelLabel),
        ),
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(true),
          style: TextButton.styleFrom(
              foregroundColor:
                  destructive ? PanelColors.danger : PanelColors.brand),
          child: Text(confirmLabel),
        ),
      ],
    ),
  );
  return confirmed == true;
}

bool matchesSearch(String query, List<String> fields) {
  final needle = query.trim().toLowerCase();
  if (needle.isEmpty) return true;
  for (final field in fields) {
    if (field.toLowerCase().contains(needle)) return true;
  }
  return false;
}
