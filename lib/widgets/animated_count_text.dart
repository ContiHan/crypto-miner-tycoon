import 'package:flutter/material.dart';

/// A number that rolls smoothly to its new value instead of snapping — the
/// "juice" idle games live on. Tweens the underlying [value] and reformats every
/// frame via [formatter], so the digits count up/down.
///
/// The first mount shows [value] immediately (no count-up from 0 — that would
/// re-roll the whole balance every time the widget remounts, e.g. on a tab
/// switch). Every later change animates from the previously shown value to the
/// new one (TweenAnimationBuilder tracks the last committed target for us).
///
/// Note: if the *format* changes (e.g. a Bitcoin/fiat toggle) the two number
/// spaces aren't comparable, so give the widget a [ValueKey] on the format so it
/// remounts and doesn't tween across the discontinuity.
class AnimatedCountText extends StatelessWidget {
  final double value;
  final String Function(double) formatter;
  final TextStyle? style;
  final Duration duration;
  final Curve curve;
  final TextAlign? textAlign;

  const AnimatedCountText({
    super.key,
    required this.value,
    required this.formatter,
    this.style,
    this.duration = const Duration(milliseconds: 550),
    this.curve = Curves.easeOutCubic,
    this.textAlign,
  });

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(end: value),
      duration: duration,
      curve: curve,
      builder: (context, val, child) {
        return Text(
          formatter(val),
          style: style,
          textAlign: textAlign,
        );
      },
    );
  }
}
