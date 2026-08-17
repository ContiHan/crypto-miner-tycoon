import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/game_logic.dart';
import '../logic/systems/ability_system.dart';
import '../theme/app_theme.dart';

/// The Abilities Bar docked above the HACK button: up to three class abilities,
/// with a live active-buff ticker above them. Ready abilities pulse; on-cooldown
/// ones show a radial sweep + wall-clock countdown; locked ones show a Mastery
/// gate. Casting pops the button and floats the ability name upward.
class AbilitiesBar extends StatefulWidget {
  const AbilitiesBar({super.key});

  static String fmt(int ms) {
    if (ms <= 0) return '';
    final s = (ms / 1000).ceil();
    if (s >= 3600) {
      final h = s ~/ 3600;
      final m = (s % 3600) ~/ 60;
      return '${h}h${m.toString().padLeft(2, '0')}';
    }
    if (s >= 60) {
      final m = s ~/ 60;
      final sec = s % 60;
      return '$m:${sec.toString().padLeft(2, '0')}';
    }
    return '${s}s';
  }

  @override
  State<AbilitiesBar> createState() => _AbilitiesBarState();
}

class _AbilitiesBarState extends State<AbilitiesBar>
    with SingleTickerProviderStateMixin {
  // One shared repeating driver: powers the ready-pulse AND the per-frame
  // refresh of the wall-clock cooldown sweep + buff countdowns.
  late final AnimationController _pulse;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    )..repeat();
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<GameLogic>(
      builder: (context, game, _) {
        if (!game.hasChosenClass) return const SizedBox.shrink();
        final abilities = game.currentClassAbilities
          ..sort((a, b) => a.slot.index.compareTo(b.slot.index));
        return Padding(
          padding: const EdgeInsets.only(left: 16, right: 16, top: 4),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _BuffTicker(game: game, pulse: _pulse),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  for (final def in abilities)
                    _AbilityButton(game: game, def: def, pulse: _pulse),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

/// A live row of chips for each active ability buff, with a soonest-first
/// countdown. Empty (and zero-height) when nothing is active.
class _BuffTicker extends StatelessWidget {
  final GameLogic game;
  final Animation<double> pulse;
  const _BuffTicker({required this.game, required this.pulse});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: pulse,
      builder: (context, _) {
        final buffs = game.activeAbilityBuffs();
        if (buffs.isEmpty) return const SizedBox.shrink();
        return Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: Wrap(
            spacing: 6,
            runSpacing: 4,
            alignment: WrapAlignment.center,
            children: [
              for (final b in buffs)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppTheme.accent.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                        color: AppTheme.accent.withValues(alpha: 0.55)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(b.def.icon, size: 12, color: AppTheme.accent),
                      const SizedBox(width: 4),
                      Text(
                        AbilitiesBar.fmt(b.remainingMs),
                        style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.accent,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

class _AbilityButton extends StatefulWidget {
  final GameLogic game;
  final AbilityDef def;
  final Animation<double> pulse;
  const _AbilityButton(
      {required this.game, required this.def, required this.pulse});

  @override
  State<_AbilityButton> createState() => _AbilityButtonState();
}

class _AbilityButtonState extends State<_AbilityButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pop; // one-shot cast pop

  @override
  void initState() {
    super.initState();
    _pop = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 320),
      value: 1.0, // 1 = at rest (no pop)
    );
  }

  @override
  void dispose() {
    _pop.dispose();
    super.dispose();
  }

  void _onTap() {
    final game = widget.game;
    final def = widget.def;
    final unlocked = game.isAbilityUnlocked(def);
    if (!unlocked) {
      final gate = def.slot == AbilitySlot.basic2
          ? 'Reach Mastery 1 with this class'
          : def.slot == AbilitySlot.ultimate
              ? 'Reach Mastery 2 with this class'
              : 'Choose this class';
      _snack('${def.name} — locked. $gate.');
      return;
    }
    if (!game.isAbilityReady(def)) {
      _snack('${def.name} on cooldown '
          '(${AbilitiesBar.fmt(game.abilityCooldownRemainingMs(def))}).');
      return;
    }
    if (game.castAbility(def.id)) {
      _pop.forward(from: 0.0);
      _floatCastText(def.name);
    }
  }

  void _floatCastText(String name) {
    final overlay = Overlay.maybeOf(context);
    final box = context.findRenderObject() as RenderBox?;
    if (overlay == null || box == null || !box.hasSize) return;
    final origin = box.localToGlobal(Offset(box.size.width / 2, 0));
    late OverlayEntry entry;
    entry = OverlayEntry(
      builder: (_) => _FloatingCastText(
        origin: origin,
        text: name,
        onDone: () => entry.remove(),
      ),
    );
    overlay.insert(entry);
  }

  void _snack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      duration: const Duration(seconds: 2),
      behavior: SnackBarBehavior.floating,
    ));
  }

  @override
  Widget build(BuildContext context) {
    final game = widget.game;
    final def = widget.def;
    return Expanded(
      child: GestureDetector(
        onTap: _onTap,
        child: AnimatedBuilder(
          // Rebuild every frame: refreshes the wall-clock cooldown sweep, the
          // ready-pulse glow, and the cast-pop scale together.
          animation: Listenable.merge([widget.pulse, _pop]),
          builder: (context, _) {
            final unlocked = game.isAbilityUnlocked(def);
            final ready = unlocked && game.isAbilityReady(def);
            final cdMs = unlocked ? game.abilityCooldownRemainingMs(def) : 0;
            final totalCd = game.abilityEffectiveCooldownMs(def);
            final remainFrac =
                totalCd <= 0 ? 0.0 : (cdMs / totalCd).clamp(0.0, 1.0);

            // Pulse only when ready: a soft breathing glow.
            final double wave =
                0.5 + 0.5 * math.sin(widget.pulse.value * 2 * math.pi);
            final double glow = ready ? (0.25 + 0.45 * wave) : 0.0;
            // Cast pop: brief scale-up that eases back to 1.
            final double pop = 1.0 + 0.18 * (1.0 - _pop.value);

            final Color accent = AppTheme.accent;
            final Color border = !unlocked
                ? Colors.white24
                : ready
                    ? accent
                    : Colors.white38;

            return Transform.scale(
              scale: pop,
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 4),
                padding: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  color: ready
                      ? accent.withValues(alpha: 0.15)
                      : Colors.black26,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: border, width: ready ? 1.5 : 1),
                  boxShadow: glow > 0
                      ? [
                          BoxShadow(
                            color: accent.withValues(alpha: glow),
                            blurRadius: 10 + 6 * wave,
                          )
                        ]
                      : null,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Icon wrapped in the radial cooldown ring.
                    SizedBox(
                      width: 34,
                      height: 34,
                      child: CustomPaint(
                        painter: _RadialCooldownPainter(remainFrac, accent),
                        child: Center(
                          child: Icon(
                            unlocked ? def.icon : Icons.lock_outline,
                            size: 20,
                            color: !unlocked
                                ? Colors.white38
                                : ready
                                    ? accent
                                    : Colors.white54,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      !unlocked
                          ? (def.slot == AbilitySlot.ultimate ? 'M2' : 'M1')
                          : ready
                              ? 'READY'
                              : AbilitiesBar.fmt(cdMs),
                      style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                        color: !unlocked
                            ? Colors.white38
                            : ready
                                ? accent
                                : Colors.white54,
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

/// The circular cooldown sweep drawn around an ability icon: a faint full ring
/// plus a top-anchored arc whose length is the fraction of cooldown remaining
/// (full just after a cast, gone when ready).
class _RadialCooldownPainter extends CustomPainter {
  final double remainingFraction; // 1 = just cast, 0 = ready
  final Color color;
  _RadialCooldownPainter(this.remainingFraction, this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = size.width / 2 - 1.5;
    final bg = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5
      ..color = Colors.white.withValues(alpha: 0.12);
    canvas.drawCircle(center, radius, bg);
    if (remainingFraction <= 0) return;
    final fg = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round
      ..color = color.withValues(alpha: 0.85);
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi / 2, // start at 12 o'clock
      2 * math.pi * remainingFraction,
      false,
      fg,
    );
  }

  @override
  bool shouldRepaint(covariant _RadialCooldownPainter old) =>
      old.remainingFraction != remainingFraction || old.color != color;
}

/// A short-lived overlay: the cast ability's name floats up ~40px and fades out.
class _FloatingCastText extends StatefulWidget {
  final Offset origin;
  final String text;
  final VoidCallback onDone;
  const _FloatingCastText(
      {required this.origin, required this.text, required this.onDone});

  @override
  State<_FloatingCastText> createState() => _FloatingCastTextState();
}

class _FloatingCastTextState extends State<_FloatingCastText>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..forward();
    _c.addStatusListener((s) {
      if (s == AnimationStatus.completed) widget.onDone();
    });
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (context, _) {
        final t = Curves.easeOut.transform(_c.value);
        final dy = -40.0 * t;
        final opacity = (1.0 - t).clamp(0.0, 1.0);
        return Positioned(
          left: widget.origin.dx - 80,
          top: widget.origin.dy - 18 + dy,
          width: 160,
          child: IgnorePointer(
            child: Opacity(
              opacity: opacity,
              child: Text(
                widget.text.toUpperCase(),
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.5,
                  color: AppTheme.accent,
                  shadows: const [
                    Shadow(color: Colors.black, blurRadius: 4),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
