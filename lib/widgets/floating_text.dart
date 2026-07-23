import 'package:flutter/material.dart';

class FloatingText extends StatefulWidget {
  final String text;
  final VoidCallback onComplete;

  /// Overrides the sign-based colour (green +, red -) when set — e.g. gold crits.
  final Color? color;
  final double fontSize;

  const FloatingText({
    super.key,
    required this.text,
    required this.onComplete,
    this.color,
    this.fontSize = 24,
  });

  @override
  State<FloatingText> createState() => _FloatingTextState();
}

class _FloatingTextState extends State<FloatingText> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _opacity;
  late Animation<Offset> _offset;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _opacity = Tween<double>(begin: 1.0, end: 0.0).animate(
      CurvedAnimation(parent: _controller, curve: const Interval(0.5, 1.0)),
    );

    _offset = Tween<Offset>(begin: Offset.zero, end: const Offset(0, -2.0)).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );

    _controller.forward().then((_) => widget.onComplete());
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isNegative = widget.text.startsWith('-');
    final resolvedColor = widget.color ??
        (isNegative
            ? Colors.redAccent
            : (widget.text.startsWith('+') ? Colors.greenAccent : Colors.white));
    return SlideTransition(
      position: _offset,
      child: FadeTransition(
        opacity: _opacity,
        child: Text(
          widget.text,
          style: TextStyle(
            color: resolvedColor,
            fontSize: widget.fontSize,
            fontWeight: FontWeight.bold,
            shadows: const [Shadow(color: Colors.black, blurRadius: 4)],
          ),
        ),
      ),
    );
  }
}
