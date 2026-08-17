import 'dart:async';
import 'dart:collection';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// A top-anchored, cyberpunk-styled transient toast (chamfered neon panel that
/// slides in with a brief glitch jitter). Shown ABOVE the content, away from the
/// bottom MINE tap/ability zone. Toasts queue (one at a time, FIFO) so a tab
/// unlock and an achievement that fire together both get seen.
///
/// Rendered via the root [Overlay], so callers must still gate against
/// full-screen routes (the ending/credits) — an overlay entry can paint over a
/// pushed route just like a SnackBar does.
void showCyberToast(
  BuildContext context, {
  required String message,
  IconData icon = Icons.bolt,
  String? actionLabel,
  VoidCallback? onTap,
  Duration duration = const Duration(seconds: 4),
}) {
  final overlay = Overlay.of(context, rootOverlay: true);
  _CyberToastManager.instance.enqueue(
    overlay,
    _ToastReq(
      message: message,
      icon: icon,
      actionLabel: actionLabel,
      onTap: onTap,
      duration: duration,
    ),
  );
}

class _ToastReq {
  final String message;
  final IconData icon;
  final String? actionLabel;
  final VoidCallback? onTap;
  final Duration duration;
  const _ToastReq({
    required this.message,
    required this.icon,
    required this.actionLabel,
    required this.onTap,
    required this.duration,
  });
}

/// Serialises toasts through a single active overlay entry so they never stack
/// or overlap — the next one shows when the current finishes.
class _CyberToastManager {
  _CyberToastManager._();
  static final _CyberToastManager instance = _CyberToastManager._();

  final Queue<_ToastReq> _queue = Queue<_ToastReq>();
  OverlayEntry? _current;

  void enqueue(OverlayState overlay, _ToastReq req) {
    _queue.add(req);
    _pump(overlay);
  }

  void _pump(OverlayState overlay) {
    if (_current != null || _queue.isEmpty || !overlay.mounted) return;
    final req = _queue.removeFirst();
    late OverlayEntry entry;
    entry = OverlayEntry(
      builder: (_) => _CyberToast(
        req: req,
        onDone: () {
          entry.remove();
          _current = null;
          _pump(overlay); // show the next queued toast, if any
        },
      ),
    );
    _current = entry;
    overlay.insert(entry);
  }
}

class _CyberToast extends StatefulWidget {
  final _ToastReq req;
  final VoidCallback onDone;
  const _CyberToast({required this.req, required this.onDone});

  @override
  State<_CyberToast> createState() => _CyberToastState();
}

class _CyberToastState extends State<_CyberToast>
    with TickerProviderStateMixin {
  // Neon palette: cyan primary + amber secondary (the app accent) for a
  // cyberpunk two-tone glow.
  static const Color _cyan = Color(0xFF00E5FF);
  static const Color _amber = Color(0xFFFFB700);
  static const Color _panel = Color(0xF20A0E12); // near-black, slightly see-through

  late final AnimationController _in; // slide + fade entrance/exit
  late final AnimationController _glitch; // brief damped horizontal jitter
  Timer? _hold;
  bool _leaving = false;

  @override
  void initState() {
    super.initState();
    _in = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 320))
      ..forward();
    _glitch = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 480))
      ..forward();
    _hold = Timer(widget.req.duration, _dismiss);
  }

  void _dismiss() {
    if (_leaving) return;
    _leaving = true;
    _hold?.cancel();
    if (!mounted) {
      widget.onDone();
      return;
    }
    _in.reverse().whenComplete(widget.onDone);
  }

  @override
  void dispose() {
    _hold?.cancel();
    _in.dispose();
    _glitch.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final topInset = MediaQuery.of(context).padding.top;
    return Positioned(
      top: topInset + 10,
      left: 12,
      right: 12,
      child: AnimatedBuilder(
        animation: Listenable.merge([_in, _glitch]),
        builder: (context, child) {
          final t = Curves.easeOutCubic.transform(_in.value);
          // Damped horizontal glitch jitter, strongest at the start.
          final g = _glitch.value;
          final jitter = g >= 1.0 ? 0.0 : math.sin(g * math.pi * 9) * 5.0 * (1 - g);
          return Opacity(
            opacity: t.clamp(0.0, 1.0),
            child: Transform.translate(
              offset: Offset(jitter, (1 - t) * -18),
              child: child,
            ),
          );
        },
        child: _panelContent(),
      ),
    );
  }

  Widget _panelContent() {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          widget.req.onTap?.call();
          _dismiss();
        },
        child: ClipPath(
          clipper: _ChamferClipper(cut: 10),
          child: Container(
            decoration: BoxDecoration(
              color: _panel,
              border: Border.all(color: _cyan.withValues(alpha: 0.9), width: 1.4),
              boxShadow: [
                BoxShadow(
                    color: _cyan.withValues(alpha: 0.35),
                    blurRadius: 14,
                    spreadRadius: 0),
                BoxShadow(
                    color: _amber.withValues(alpha: 0.18),
                    blurRadius: 18,
                    spreadRadius: 0),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Top accent data-bar (cyan→amber gradient).
                Container(
                  height: 2,
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(colors: [_cyan, _amber]),
                  ),
                ),
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  child: Row(
                    children: [
                      // Icon chip.
                      Container(
                        width: 30,
                        height: 30,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: _cyan.withValues(alpha: 0.10),
                          border: Border.all(
                              color: _cyan.withValues(alpha: 0.7), width: 1),
                        ),
                        child: Icon(widget.req.icon, color: _cyan, size: 17),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              widget.req.message.toUpperCase(),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.orbitron(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 0.5,
                                height: 1.25,
                                shadows: [
                                  Shadow(
                                      color: _cyan.withValues(alpha: 0.6),
                                      blurRadius: 6),
                                ],
                              ),
                            ),
                            if (widget.req.actionLabel != null)
                              Padding(
                                padding: const EdgeInsets.only(top: 2),
                                child: Text(
                                  '» ${widget.req.actionLabel!.toUpperCase()}',
                                  style: GoogleFonts.orbitron(
                                    color: _amber,
                                    fontSize: 9,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 1.5,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Text('◈',
                          style: TextStyle(
                              color: _cyan,
                              fontSize: 14,
                              fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Cuts the top-left and bottom-right corners for a chamfered "hex-panel" look.
class _ChamferClipper extends CustomClipper<Path> {
  final double cut;
  const _ChamferClipper({required this.cut});

  @override
  Path getClip(Size s) {
    final c = math.min(cut, math.min(s.width, s.height) / 2);
    return Path()
      ..moveTo(c, 0)
      ..lineTo(s.width, 0)
      ..lineTo(s.width, s.height - c)
      ..lineTo(s.width - c, s.height)
      ..lineTo(0, s.height)
      ..lineTo(0, c)
      ..close();
  }

  @override
  bool shouldReclip(covariant _ChamferClipper old) => old.cut != cut;
}
