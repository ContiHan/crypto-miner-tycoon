import 'package:flutter/material.dart';

class PulseButton extends StatefulWidget {
  final Widget child;
  final VoidCallback? onPressed;
  final bool animate;

  const PulseButton({
    super.key,
    required this.child,
    this.onPressed,
    this.animate = true,
  });

  @override
  State<PulseButton> createState() => _PulseButtonState();
}

class _PulseButtonState extends State<PulseButton> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(seconds: 1),
      vsync: this,
    );

    _scaleAnimation = Tween<double>(begin: 1.0, end: 1.05).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );

    _checkAnimation();
  }

  @override
  void didUpdateWidget(covariant PulseButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    _checkAnimation();
  }

  void _checkAnimation() {
    if (widget.animate && widget.onPressed != null) {
      if (!_controller.isAnimating) {
        _controller.repeat(reverse: true);
      }
    } else {
      _controller.stop();
      _controller.value = 0; // Reset to original scale
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: _scaleAnimation,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.redAccent,
          foregroundColor: Colors.white,
          elevation: widget.animate ? 8 : 2,
        ),
        onPressed: widget.onPressed,
        child: widget.child,
      ),
    );
  }
}
