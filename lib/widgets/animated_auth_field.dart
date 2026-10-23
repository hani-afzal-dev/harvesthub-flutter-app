import 'package:flutter/material.dart';
import '../core/semantics_id.dart';

typedef FieldValidator = bool Function(String value);

class AnimatedAuthField extends StatefulWidget {
  final TextEditingController controller;
  final String label;
  final IconData icon;
  final bool obscureText;
  final FieldValidator validator;
  final String errorText;
  final String? Function(String value)? errorMessage;
  final Color accentColor;
  final Color successColor;
  final Color errorColor;
  final TextInputType keyboardType;

  const AnimatedAuthField({
    super.key,
    required this.controller,
    required this.label,
    required this.icon,
    required this.validator,
    required this.errorText,
    this.errorMessage,
    this.obscureText = false,
    this.accentColor = const Color(0xFF3B6D11),
    this.successColor = const Color(0xFF639922),
    this.errorColor = const Color(0xFFB3261E),
    this.keyboardType = TextInputType.text,
  });

  @override
  State<AnimatedAuthField> createState() => _AnimatedAuthFieldState();
}

class _AnimatedAuthFieldState extends State<AnimatedAuthField>
    with SingleTickerProviderStateMixin {
  final FocusNode _focusNode = FocusNode();
  late final AnimationController _shakeController;
  late final Animation<double> _shakeAnimation;

  bool _isFocused = false;
  bool _isValid = false;
  bool _hasError = false;
  bool _obscure = true;

  @override
  void initState() {
    super.initState();
    _obscure = widget.obscureText;
    _focusNode.addListener(_handleFocusChange);
    widget.controller.addListener(_handleTextChange);

    _shakeController = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 400));
    _shakeAnimation = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0, end: -8), weight: 1),
      TweenSequenceItem(tween: Tween(begin: -8, end: 8), weight: 1),
      TweenSequenceItem(tween: Tween(begin: 8, end: -5), weight: 1),
      TweenSequenceItem(tween: Tween(begin: -5, end: 5), weight: 1),
      TweenSequenceItem(tween: Tween(begin: 5, end: 0), weight: 1),
    ]).animate(_shakeController);
  }

  @override
  void dispose() {
    _focusNode.removeListener(_handleFocusChange);
    widget.controller.removeListener(_handleTextChange);
    _focusNode.dispose();
    _shakeController.dispose();
    super.dispose();
  }

  void _handleTextChange() {
    final text = widget.controller.text;
    final valid = text.isNotEmpty && widget.validator(text);
    if (valid != _isValid || _hasError) {
      setState(() {
        _isValid = valid;
        if (valid) _hasError = false;
      });
    }
  }

  void _handleFocusChange() {
    setState(() => _isFocused = _focusNode.hasFocus);

    if (!_focusNode.hasFocus) {
      final text = widget.controller.text;
      if (text.isEmpty) {
        setState(() {
          _isValid = false;
          _hasError = false;
        });
        return;
      }
      final valid = widget.validator(text);
      setState(() {
        _isValid = valid;
        _hasError = !valid;
      });
      if (!valid) {
        _shakeController.forward(from: 0);
      }
    }
  }

  Color get _borderColor {
    if (_hasError) return widget.errorColor;
    if (_isValid) return widget.successColor;
    if (_isFocused) return widget.accentColor;
    return const Color(0xFFE3E9DA);
  }

  Color get _iconColor {
    if (_hasError) return widget.errorColor;
    if (_isFocused) return widget.accentColor;
    return const Color(0xFF6B7A5E);
  }

  @override
  Widget build(BuildContext context) {
    Color floatingColor = widget.accentColor;
    if (_hasError) floatingColor = widget.errorColor;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AnimatedBuilder(
          animation: _shakeAnimation,
          builder: (context, child) => Transform.translate(
            offset: Offset(_shakeAnimation.value, 0),
            child: child,
          ),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeOut,
            constraints: const BoxConstraints(minHeight: 56),
            padding:
                EdgeInsets.only(left: 14, right: widget.obscureText ? 4 : 14),
            decoration: BoxDecoration(
              color: _isFocused ? Colors.white : const Color(0xFFF1F4EC),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: _borderColor, width: 1.5),
              boxShadow: _isFocused
                  ? [
                      BoxShadow(
                        color: widget.accentColor.withValues(alpha: 0.18),
                        blurRadius: 16,
                        offset: const Offset(0, 8),
                      ),
                    ]
                  : [],
            ),
            child: Row(
              children: [
                Icon(widget.icon, size: 20, color: _iconColor),
                const SizedBox(width: 10),
                Expanded(
                  child: Semantics(
                    identifier: semanticsIdOf(widget.key),
                    child: TextField(
                      controller: widget.controller,
                      focusNode: _focusNode,
                      obscureText: widget.obscureText ? _obscure : false,
                      keyboardType: widget.keyboardType,
                      style: const TextStyle(
                          fontSize: 15, color: Color(0xFF22301A)),
                      decoration: InputDecoration(
                        labelText: widget.label,
                        labelStyle: const TextStyle(
                            fontSize: 15, color: Color(0xFF6B7A5E)),
                        floatingLabelStyle: TextStyle(
                            color: floatingColor, fontWeight: FontWeight.w600),
                        border: InputBorder.none,
                        isDense: true,
                        contentPadding:
                            const EdgeInsets.symmetric(vertical: 10),
                      ),
                    ),
                  ),
                ),
                if (widget.obscureText)
                  IconButton(
                    tooltip: _obscure ? 'Show password' : 'Hide password',
                    onPressed: () => setState(() => _obscure = !_obscure),
                    iconSize: 20,
                    color: const Color(0xFF6B7A5E),
                    icon: Icon(_obscure
                        ? Icons.visibility_outlined
                        : Icons.visibility_off_outlined),
                  ),
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 250),
                  transitionBuilder: (child, anim) =>
                      ScaleTransition(scale: anim, child: child),
                  child: _isValid
                      ? Padding(
                          key: const ValueKey('valid'),
                          padding: const EdgeInsets.only(left: 8, right: 4),
                          child: Icon(Icons.check_circle,
                              size: 18, color: widget.successColor),
                        )
                      : const SizedBox.shrink(key: ValueKey('empty')),
                ),
              ],
            ),
          ),
        ),
        AnimatedSize(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
          alignment: Alignment.topLeft,
          child: _hasError
              ? Semantics(
                  liveRegion: true,
                  child: Padding(
                    padding: const EdgeInsets.only(top: 6, left: 4),
                    child: Text(
                      widget.errorMessage?.call(widget.controller.text) ??
                          widget.errorText,
                      style: TextStyle(fontSize: 12, color: widget.errorColor),
                    ),
                  ),
                )
              : const SizedBox(width: double.infinity),
        ),
      ],
    );
  }
}
