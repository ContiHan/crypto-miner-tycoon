import 'package:flutter/material.dart';

class BinaryParticle extends StatefulWidget {
  final String text;
  final Offset endOffset;
  final VoidCallback onComplete;
  final Color color;

  const BinaryParticle({
    super.key, 
    required this.text, 
    required this.endOffset, 
    required this.onComplete,
    this.color = Colors.greenAccent,
  });

  @override
  State<BinaryParticle> createState() => _BinaryParticleState();
}

class _BinaryParticleState extends State<BinaryParticle> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _opacity;
  late Animation<Offset> _offset;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      // Slightly longer duration for the 'throw' feel
      duration: const Duration(milliseconds: 800), 
      vsync: this,
    );

    _opacity = Tween<double>(begin: 1.0, end: 0.0).animate(
      CurvedAnimation(parent: _controller, curve: const Interval(0.6, 1.0)),
    );

    // Animate from zero to endOffset
    _offset = Tween<Offset>(begin: Offset.zero, end: widget.endOffset).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic),
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
    return SlideTransition(
      position: _offset,
      child: FadeTransition(
        opacity: _opacity,
        child: Text(
          widget.text,
          style: TextStyle(
            color: widget.color, 
            fontSize: 20,
            fontWeight: FontWeight.w900,
            shadows: [Shadow(color: widget.color.withValues(alpha: 0.5), blurRadius: 4)],
          ),
        ),
      ),
    );
  }
}
