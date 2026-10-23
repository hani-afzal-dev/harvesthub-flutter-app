import 'dart:async';

import 'package:flutter/material.dart';
import '../core/semantics_id.dart';

enum _BtnStage { idle, pulse, transition, morph, success }

class AnimatedAuthButton extends StatefulWidget {
  final String label;
  final IconData icon;
  final IconData transitionIcon;
  final Color accentColor;
  final Color successColor;
  final FutureOr<void> Function() onSuccess;
  final Future<bool> Function()? onPressedAsync;
  final void Function(String message)? onError;
  final double width;
  final double height;

  const AnimatedAuthButton({
    super.key,
    required this.label,
    required this.icon,
    required this.transitionIcon,
    required this.onSuccess,
    this.accentColor = const Color(0xFF3B6D11),
    this.successColor = const Color(0xFF3B6D11),
    this.onPressedAsync,
    this.onError,
    this.width = 240,
    this.height = 58,
  });

  @override
  State<AnimatedAuthButton> createState() => _AnimatedAuthButtonState();
}

class _AnimatedAuthButtonState extends State<AnimatedAuthButton> {
  _BtnStage _stage = _BtnStage.idle;
  bool _animating = false;

  static const Color _disabledColor = Color(0xFF9AA58F);

  bool get _enabled => widget.onPressedAsync != null;

  Future<void> _handleTap() async {
    final action = widget.onPressedAsync;
    if (_animating || action == null) return;
    setState(() {
      _animating = true;
      _stage = _BtnStage.pulse;
    });

    String? caughtError;
    final result = action().catchError((Object e) {
      caughtError = e.toString();
      return false;
    });

    await Future.delayed(const Duration(milliseconds: 120));
    if (!mounted) return;
    setState(() => _stage = _BtnStage.transition);

    await Future.delayed(const Duration(milliseconds: 180));
    if (!mounted) return;
    setState(() => _stage = _BtnStage.morph);

    final success = await result;
    if (!mounted) return;

    final error = caughtError;
    if (!success && error != null) {
      widget.onError?.call(error);
    }

    if (success) {
      setState(() => _stage = _BtnStage.success);
      await Future.delayed(const Duration(milliseconds: 400));
      if (!mounted) return;
      await widget.onSuccess();
      if (!mounted) return;
      final stillHere = ModalRoute.of(context)?.isCurrent ?? true;
      if (!stillHere) return;
    }

    setState(() {
      _stage = _BtnStage.idle;
      _animating = false;
    });
  }

  bool get _isCircle =>
      _stage == _BtnStage.morph || _stage == _BtnStage.success;
  bool get _isSuccess => _stage == _BtnStage.success;

  @override
  Widget build(BuildContext context) {
    final Color bgColor = !_enabled
        ? _disabledColor
        : (_isSuccess ? widget.successColor : widget.accentColor);

    return SizedBox(
      height: widget.height + 24,
      child: Stack(
        alignment: Alignment.center,
        children: [
          TweenAnimationBuilder<double>(
            key: ValueKey(_isSuccess),
            tween: Tween(begin: 1.0, end: _isSuccess ? 2.4 : 1.0),
            duration: const Duration(milliseconds: 700),
            curve: Curves.easeOut,
            builder: (context, scale, child) {
              return Opacity(
                opacity: _isSuccess ? (2.4 - scale) / 1.4 : 0,
                child: Transform.scale(
                  scale: scale,
                  child: Container(
                    width: widget.height,
                    height: widget.height,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: widget.successColor, width: 2),
                    ),
                  ),
                ),
              );
            },
          ),
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 1, end: _isSuccess ? 1.06 : 1),
            duration: const Duration(milliseconds: 400),
            curve: Curves.elasticOut,
            builder: (context, bounce, child) =>
                Transform.scale(scale: bounce, child: child),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 400),
              curve: Curves.easeOutBack,
              width: _isCircle ? widget.height : widget.width,
              height: widget.height,
              decoration: BoxDecoration(
                color: bgColor,
                borderRadius: BorderRadius.circular(widget.height / 2),
                boxShadow: _enabled
                    ? [
                        BoxShadow(
                          color: bgColor.withValues(alpha: 0.4),
                          blurRadius: 18,
                          offset: const Offset(0, 6),
                        ),
                      ]
                    : const <BoxShadow>[],
              ),
              child: Semantics(
                button: true,
                enabled: _enabled,
                label: widget.label,
                identifier: semanticsIdOf(widget.key),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(widget.height / 2),
                    onTap: _enabled ? _handleTap : null,
                    child:
                        Center(child: ExcludeSemantics(child: _buildContent())),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContent() {
    switch (_stage) {
      case _BtnStage.idle:
        return _idleContent();
      case _BtnStage.pulse:
        return TweenAnimationBuilder<double>(
          tween: Tween(begin: 1, end: 1.5),
          duration: const Duration(milliseconds: 300),
          builder: (context, scale, child) => Transform.scale(
            scale: scale,
            child: Icon(widget.icon, color: Colors.white, size: 21),
          ),
        );
      case _BtnStage.transition:
        return TweenAnimationBuilder<double>(
          tween: Tween(begin: -0.1, end: 0.0),
          duration: const Duration(milliseconds: 500),
          curve: Curves.easeInOut,
          builder: (context, angle, child) => Transform.rotate(
            angle: angle,
            child: Transform.scale(
              scale: 1.6,
              child: Icon(widget.transitionIcon, color: Colors.white, size: 21),
            ),
          ),
        );
      case _BtnStage.morph:
        return const SizedBox(
          width: 22,
          height: 22,
          child:
              CircularProgressIndicator(color: Colors.white, strokeWidth: 2.4),
        );
      case _BtnStage.success:
        return TweenAnimationBuilder<double>(
          tween: Tween(begin: 0, end: 1),
          duration: const Duration(milliseconds: 350),
          curve: Curves.elasticOut,
          builder: (context, value, child) => Transform.scale(
            scale: value,
            child: const Icon(Icons.check, color: Colors.white, size: 20),
          ),
        );
    }
  }

  Widget _idleContent() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(widget.icon, color: Colors.white, size: 21),
            const SizedBox(width: 10),
            Text(
              widget.label,
              maxLines: 1,
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 17,
                  fontWeight: FontWeight.w700),
            ),
          ],
        ),
      ),
    );
  }
}
