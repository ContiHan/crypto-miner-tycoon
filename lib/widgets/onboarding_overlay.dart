import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_theme.dart';

/// One beat of the first-run coach. [targetKey] is the widget to spotlight;
/// when null the callout is centered with no spotlight (used for the closing
/// "prestige" beat, whose button doesn't exist yet on a fresh save).
class CoachStep {
  final String title;
  final String body;
  final GlobalKey? targetKey;
  const CoachStep({required this.title, required this.body, this.targetKey});
}

/// A guided first-run overlay: dims the screen, spotlights each target in turn
/// and explains the core loop. Tapping anywhere (or NEXT) advances; SKIP or the
/// final step calls [onComplete]. Hosted inside the MINE tab's Stack so it can
/// read the real HACK-button / rig positions.
class OnboardingCoach extends StatefulWidget {
  final List<CoachStep> steps;
  final VoidCallback onComplete;

  const OnboardingCoach({
    super.key,
    required this.steps,
    required this.onComplete,
  });

  @override
  State<OnboardingCoach> createState() => _OnboardingCoachState();
}

class _OnboardingCoachState extends State<OnboardingCoach> {
  int _index = 0;
  Rect? _rect; // target rect in this overlay's local space (null = centered)

  @override
  void initState() {
    super.initState();
    _scheduleRect();
  }

  // Measure the spotlight rect after this frame, then once more on the next —
  // the first frame after mount isn't always fully laid out (e.g. the HACK
  // button's position before the ListView finished sizing), which otherwise
  // left the first beat's spotlight in the wrong place.
  void _scheduleRect() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _updateRect();
      WidgetsBinding.instance.addPostFrameCallback((_) => _updateRect());
    });
  }

  void _updateRect() {
    if (!mounted) return;
    Rect? r;
    final targetCtx = widget.steps[_index].targetKey?.currentContext;
    final selfBox = context.findRenderObject();
    if (targetCtx != null && selfBox is RenderBox) {
      final tb = targetCtx.findRenderObject();
      if (tb is RenderBox && tb.hasSize) {
        final topLeft = selfBox.globalToLocal(tb.localToGlobal(Offset.zero));
        r = topLeft & tb.size;
      }
    }
    setState(() => _rect = r);
  }

  void _next() {
    if (_index >= widget.steps.length - 1) {
      widget.onComplete();
      return;
    }
    setState(() {
      _index++;
      _rect = null;
    });
    _scheduleRect();
  }

  @override
  Widget build(BuildContext context) {
    final step = widget.steps[_index];
    final isLast = _index == widget.steps.length - 1;

    final screenH = (context.findRenderObject() as RenderBox?)?.size.height ??
        MediaQuery.of(context).size.height;

    // Place the callout in the LARGER free gap beside the spotlight (above vs
    // below the target) and cap its height to that gap, so it can never cover
    // the thing it points at — the old "pick a half by target-centre" logic let
    // a tall callout sit on top of a mid-screen target (e.g. the first rig).
    Widget positionedCallout;
    if (_rect == null) {
      positionedCallout = Align(
        alignment: Alignment.center,
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: _callout(step, isLast, screenH * 0.8),
        ),
      );
    } else {
      const gap = 16.0; // clearance between the spotlight and the callout
      const margin = 20.0; // outer screen margin
      final spot = _rect!.inflate(8); // matches the painted spotlight halo
      final spaceAbove = spot.top - margin - gap;
      final spaceBelow = screenH - spot.bottom - margin - gap;
      final below = spaceBelow >= spaceAbove;
      final maxH = (below ? spaceBelow : spaceAbove).clamp(140.0, screenH * 0.8);
      positionedCallout = Positioned(
        left: margin,
        right: margin,
        top: below ? spot.bottom + gap : null,
        bottom: below ? null : (screenH - spot.top + gap),
        child: Align(
          alignment: below ? Alignment.topCenter : Alignment.bottomCenter,
          child: _callout(step, isLast, maxH),
        ),
      );
    }

    return Stack(
      children: [
        // Scrim + spotlight. Tapping anywhere advances.
        Positioned.fill(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: _next,
            child: CustomPaint(painter: _SpotlightPainter(_rect)),
          ),
        ),
        positionedCallout,
      ],
    );
  }

  Widget _callout(CoachStep step, bool isLast, double maxH) {
    // Bounded height + scroll so long body text, a large accessibility font
    // scale, or a short/landscape screen scrolls instead of overflowing.
    return Container(
      constraints: BoxConstraints(maxWidth: 340, maxHeight: maxH),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.accent, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: AppTheme.accent.withValues(alpha: 0.25),
            blurRadius: 18,
            spreadRadius: 1,
          ),
        ],
      ),
      child: SingleChildScrollView(
        child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            step.title,
            style: GoogleFonts.orbitron(
              color: AppTheme.accent,
              fontSize: 18,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.5,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            step.body,
            style: const TextStyle(color: Colors.white, fontSize: 14, height: 1.35),
          ),
          const SizedBox(height: 12),
          // Counter + SKIP on one row; the primary action is a full-width button
          // below so nothing can overflow on a narrow phone.
          Row(
            children: [
              Text(
                '${_index + 1}/${widget.steps.length}',
                style: const TextStyle(color: Colors.white38, fontSize: 12),
              ),
              const Spacer(),
              TextButton(
                onPressed: widget.onComplete,
                child: const Text('SKIP', style: TextStyle(color: Colors.white54)),
              ),
            ],
          ),
          const SizedBox(height: 4),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _next,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.accent,
                foregroundColor: Colors.black,
              ),
              child: Text(isLast ? 'START MINING' : 'NEXT'),
            ),
          ),
        ],
        ),
      ),
    );
  }
}

class _SpotlightPainter extends CustomPainter {
  final Rect? hole;
  const _SpotlightPainter(this.hole);

  @override
  void paint(Canvas canvas, Size size) {
    final scrim = Paint()..color = Colors.black.withValues(alpha: 0.82);
    final full = Offset.zero & size;
    if (hole == null) {
      canvas.drawRect(full, scrim);
      return;
    }
    final rr = RRect.fromRectAndRadius(
      hole!.inflate(8),
      const Radius.circular(10),
    );
    final dimmed = Path.combine(
      PathOperation.difference,
      Path()..addRect(full),
      Path()..addRRect(rr),
    );
    canvas.drawPath(dimmed, scrim);
    canvas.drawRRect(
      rr,
      Paint()
        ..color = AppTheme.accent
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5,
    );
  }

  @override
  bool shouldRepaint(_SpotlightPainter old) => old.hole != hole;
}
