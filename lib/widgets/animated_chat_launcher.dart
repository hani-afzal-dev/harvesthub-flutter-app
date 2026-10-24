import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';

class AnimatedChatLauncher extends StatefulWidget {
  final WidgetBuilder panelBuilder;
  final IconData icon;
  final Color color;
  final double buttonSize;
  final double panelWidth;
  final double panelHeight;
  final Alignment alignment;
  final String openLabel;
  final String closeLabel;
  final String openTooltip;
  final String closeTooltip;

  const AnimatedChatLauncher({
    super.key,
    required this.panelBuilder,
    this.icon = Icons.eco_outlined,
    this.color = const Color(0xFF3B6D11),
    this.buttonSize = 56,
    this.panelWidth = 300,
    this.panelHeight = 420,
    this.alignment = Alignment.bottomRight,
    this.openLabel = 'Open farm assistant chat',
    this.closeLabel = 'Close farm assistant chat',
    this.openTooltip = 'Ask the farm assistant',
    this.closeTooltip = 'Close assistant',
  });

  @override
  State<AnimatedChatLauncher> createState() => _AnimatedChatLauncherState();
}

class _AnimatedChatLauncherState extends State<AnimatedChatLauncher>
    with SingleTickerProviderStateMixin {
  bool _open = false;
  double _wiggle = 0;
  Timer? _idleTimer;
  late AnimationController _ringController;

  @override
  void initState() {
    super.initState();
    _ringController = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 500));
    _idleTimer = Timer.periodic(const Duration(milliseconds: 3500), (_) async {
      if (_open || !mounted || MediaQuery.of(context).disableAnimations) {
        return;
      }
      setState(() => _wiggle = -0.08);
      await Future.delayed(const Duration(milliseconds: 150));
      if (!mounted) return;
      setState(() => _wiggle = 0.08);
      await Future.delayed(const Duration(milliseconds: 150));
      if (!mounted) return;
      setState(() => _wiggle = 0);
    });
  }

  @override
  void dispose() {
    _idleTimer?.cancel();
    _ringController.dispose();
    super.dispose();
  }

  void _toggle() {
    setState(() => _open = !_open);
    _ringController.forward(from: 0);
  }

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: LayoutBuilder(
        builder: (context, constraints) {
          var panelWidth = widget.panelWidth;
          if (panelWidth > constraints.maxWidth - 40) {
            panelWidth = constraints.maxWidth - 40;
          }
          var panelHeight = widget.panelHeight;
          final roomAbove = constraints.maxHeight - widget.buttonSize - 60;
          if (panelHeight > roomAbove) panelHeight = roomAbove;
          if (panelHeight < 0) panelHeight = 0;

          final isLeft = widget.alignment == Alignment.bottomLeft;
          return Align(
            alignment: widget.alignment,
            child: Padding(
              padding: EdgeInsets.only(
                left: isLeft ? 20 : 0,
                right: isLeft ? 0 : 20,
                bottom: 20,
              ),
              child: Stack(
                alignment: widget.alignment,
                clipBehavior: Clip.none,
                children: [
                  AnimatedScale(
                    duration: const Duration(milliseconds: 350),
                    curve: Curves.easeOutBack,
                    alignment: widget.alignment,
                    scale: _open ? 1 : 0.15,
                    child: AnimatedOpacity(
                      duration: const Duration(milliseconds: 250),
                      opacity: _open ? 1 : 0,
                      child: IgnorePointer(
                        ignoring: !_open,
                        child: Container(
                          margin:
                              EdgeInsets.only(bottom: widget.buttonSize + 20),
                          width: panelWidth,
                          height: panelHeight,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.12),
                                  blurRadius: 24,
                                  offset: const Offset(0, 8)),
                            ],
                          ),
                          clipBehavior: Clip.antiAlias,
                          child: widget.panelBuilder(context),
                        ),
                      ),
                    ),
                  ),
                  AnimatedBuilder(
                    animation: _ringController,
                    builder: (context, child) {
                      final v = _ringController.value;
                      return Opacity(
                        opacity: (1 - v).clamp(0, 1),
                        child: Transform.scale(
                          scale: 1 + v * 0.8,
                          child: Container(
                            width: widget.buttonSize,
                            height: widget.buttonSize,
                            decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border:
                                    Border.all(color: widget.color, width: 2)),
                          ),
                        ),
                      );
                    },
                  ),
                  Semantics(
                    button: true,
                    label: _open ? widget.closeLabel : widget.openLabel,
                    child: Tooltip(
                      message:
                          _open ? widget.closeTooltip : widget.openTooltip,
                      child: GestureDetector(
                        onTap: _toggle,
                        child: Container(
                          width: widget.buttonSize,
                          height: widget.buttonSize,
                          decoration: BoxDecoration(
                            color: widget.color,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                  color: widget.color.withValues(alpha: 0.4),
                                  blurRadius: 16,
                                  offset: const Offset(0, 6))
                            ],
                          ),
                          child: Transform.rotate(
                            angle: _wiggle,
                            child: AnimatedSwitcher(
                              duration: const Duration(milliseconds: 250),
                              transitionBuilder: (child, anim) =>
                                  RotationTransition(
                                turns:
                                    Tween(begin: 0.75, end: 1.0).animate(anim),
                                child:
                                    ScaleTransition(scale: anim, child: child),
                              ),
                              child: _open
                                  ? const Icon(Icons.close,
                                      key: ValueKey('close'),
                                      color: Colors.white,
                                      size: 24)
                                  : Icon(widget.icon,
                                      key: const ValueKey('bot'),
                                      color: Colors.white,
                                      size: 24),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class AnimatedThinkingLoader extends StatefulWidget {
  final double size;
  const AnimatedThinkingLoader({super.key, this.size = 36});

  @override
  State<AnimatedThinkingLoader> createState() => _AnimatedThinkingLoaderState();
}

class _AnimatedThinkingLoaderState extends State<AnimatedThinkingLoader>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  static const _colors = [
    Color(0xFF3B6D11),
    Color(0xFF639922),
    Color(0xFFEF9F27)
  ];

  @override
  void initState() {
    super.initState();
    _controller =
        AnimationController(vsync: this, duration: const Duration(seconds: 1))
          ..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: widget.size,
      height: widget.size,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          return Stack(
            alignment: Alignment.center,
            children: [
              ...List.generate(3, (i) {
                final angle =
                    _controller.value * 2 * math.pi + (i * 2 * math.pi / 3);
                final radius = widget.size / 2 - 4;
                return Positioned(
                  left: widget.size / 2 + radius * math.cos(angle) - 3,
                  top: widget.size / 2 + radius * math.sin(angle) - 3,
                  child: Container(
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                          color: _colors[i], shape: BoxShape.circle)),
                );
              }),
              Container(
                width: widget.size * 0.4,
                height: widget.size * 0.4,
                decoration: const BoxDecoration(
                    color: Color(0xFF3B6D11), shape: BoxShape.circle),
              ),
            ],
          );
        },
      ),
    );
  }
}
