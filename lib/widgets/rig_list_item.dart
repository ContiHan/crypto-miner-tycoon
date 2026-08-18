import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../core/ids.dart';
import '../models/rig.dart';
import '../providers/game_logic.dart';
import '../theme/app_theme.dart';
import '../utils/formatter.dart';
import 'stylized_card.dart';

class RigListItem extends StatefulWidget {
  final Rig rig;
  final GameLogic game;
  final Function(Offset)? onBuy;

  const RigListItem({
    super.key, 
    required this.rig, 
    required this.game,
    this.onBuy,
  });

  @override
  State<RigListItem> createState() => _RigListItemState();
}

class _RigListItemState extends State<RigListItem> with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  // Hold-to-buy state.
  final GlobalKey _buttonKey = GlobalKey();
  Timer? _holdTimer;
  int _holdMs = 0;
  int _batch = 1;
  bool _holding = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      // Base speed: 2 seconds per cycle
      duration: const Duration(seconds: 2),
      vsync: this,
    );
    _checkAnimation();
  }

  // Batch size grows the longer the button is held: 1 -> 2 -> 10 -> 100.
  int _batchForElapsed(int ms) {
    if (ms < 800) return 1;
    if (ms < 1800) return 2;
    if (ms < 3000) return 10;
    return 100;
  }

  void _emitFloatingText() {
    final box = _buttonKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null) return;
    widget.onBuy?.call(box.localToGlobal(box.size.center(Offset.zero)));
  }

  void _startHold() {
    // Immediate first buy so a hold feels responsive.
    if (widget.game.buyRigMax(widget.rig.id, 1) > 0) _emitFloatingText();
    _holding = true;
    _holdMs = 0;
    _batch = 1;
    _holdTimer?.cancel();
    _holdTimer = Timer.periodic(const Duration(milliseconds: 200), (t) {
      if (!mounted) {
        _stopHold();
        return;
      }
      _holdMs += 200;
      final int batch = _batchForElapsed(_holdMs);
      final int bought = widget.game.buyRigMax(widget.rig.id, batch);
      if (bought == 0) {
        // Ran out of money — stop auto-buying.
        _stopHold();
        return;
      }
      _emitFloatingText();
      setState(() => _batch = batch);
    });
  }

  void _stopHold() {
    _holdTimer?.cancel();
    _holdTimer = null;
    if (mounted) {
      setState(() {
        _holding = false;
        _batch = 1;
      });
    }
  }

  @override
  void didUpdateWidget(covariant RigListItem oldWidget) {
    super.didUpdateWidget(oldWidget);
    _checkAnimation();
  }

  void _checkAnimation() {
    if (widget.rig.amount > 0) {
      // Slow "processing" pulse that speeds up GENTLY with the rig count on a LOG
      // scale — so 1 / 10 / 100 / 1000 / 10000 rigs are each visibly different
      // (the old linear formula hit its speed cap by ~80 rigs, so everything
      // above looked identical). ~5s per cycle at 1 rig, floored so a huge farm
      // never blurs into a solid bar.
      final double speedFactor =
          1.0 + math.log(widget.rig.amount + 1) * 0.25; // ~-20% per 10x
      int ms = (5000 / speedFactor).round();
      if (ms < 1200) ms = 1200; // never faster than ~1.2s per cycle
      final newDuration = Duration(milliseconds: ms);

      if (_controller.duration != newDuration) {
        _controller.duration = newDuration;
        _controller.repeat(); // restart with the new duration
      } else if (!_controller.isAnimating) {
        _controller.repeat();
      }
    } else {
      _controller.stop();
      _controller.value = 0.0;
    }
  }

  @override
  void dispose() {
    _holdTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
      final double actualCost = widget.game.getRigCostInSats(widget.rig);
      final canAfford = widget.game.wallet >= actualCost;
      final neonColor = _getRigColor(widget.rig.id);

    return StylizedCard(
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Column(
          children: [
            Row(
              children: [
                // Static Neon Icon
                Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    color: neonColor.withValues(alpha: 0.1),
                    border: Border.all(color: neonColor.withValues(alpha: 0.5)),
                    borderRadius: BorderRadius.circular(4),
                    boxShadow: [
                      BoxShadow(color: neonColor.withValues(alpha: 0.2), blurRadius: 8, spreadRadius: 1)
                    ],
                  ),
                  child: Icon(_getRigIcon(widget.rig.id), color: neonColor, size: 30),
                ),
                const SizedBox(width: 12),
                
                // Info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                       Text(
                        widget.rig.name.toUpperCase(),
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                          color: Colors.white,
                          letterSpacing: 0.5,
                        ),
                        maxLines: 2,
                        // Ellipsis (not visible) so a long name truncates cleanly
                        // instead of breaking mid-word next to the fixed button.
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          // Amount Badge
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppTheme.surface,
                              border: Border.all(color: Colors.white24),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              'x${widget.rig.amount}',
                              style: const TextStyle(
                                  color: AppTheme.accent,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            '+${Formatter.formatNumber(widget.rig.baseHashRate)} H/s',
                            style: TextStyle(
                              color: neonColor,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                
                // Buy Button — tap buys one; hold auto-buys with an escalating
                // batch (1 -> 2 -> 10 -> 100), stopping when funds run out.
                GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: canAfford
                      ? () {
                          widget.game.buyRig(widget.rig.id);
                          _emitFloatingText();
                        }
                      : null,
                  onLongPressStart: canAfford ? (_) => _startHold() : null,
                  onLongPressEnd: (_) => _stopHold(),
                  onLongPressCancel: _stopHold,
                  child: AnimatedContainer(
                    key: _buttonKey,
                    duration: const Duration(milliseconds: 120),
                    // Fixed size so the button never grows with a long price and
                    // never crowds the rig name. Long prices scale DOWN via the
                    // FittedBox below (no ellipsis).
                    width: 104,
                    height: 48,
                    alignment: Alignment.center,
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                    decoration: BoxDecoration(
                      color: canAfford ? AppTheme.accent : Colors.grey[800],
                      borderRadius: BorderRadius.circular(4),
                      border: _holding
                          ? Border.all(color: Colors.white, width: 2)
                          : null,
                      boxShadow: _holding
                          ? [
                              BoxShadow(
                                color: AppTheme.accent.withValues(alpha: 0.9),
                                blurRadius: 14,
                                spreadRadius: 2,
                              ),
                            ]
                          : null,
                    ),
                    // One FittedBox around BOTH lines so the label+price scale
                    // down together to fit the fixed 104x48 button in BOTH axes
                    // (a hold showing "×100" is taller — this stops the ~5px
                    // vertical overflow without ever growing the button).
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            _holding ? '×$_batch' : 'BUY',
                            style: TextStyle(
                              fontSize: _holding ? 14 : 10,
                              height: 1.05,
                              fontWeight: FontWeight.bold,
                              color: Colors.black,
                            ),
                          ),
                          Text(
                            widget.game.showFiatPrices
                                ? '\$ ${Formatter.formatNumber(widget.game.toFiat(widget.game.getRigCostInSats(widget.rig)))}'
                                : Formatter.formatBitcoin(
                                    widget.game.getRigCostInSats(widget.rig)),
                            style: const TextStyle(
                              fontSize: 12,
                              height: 1.05,
                              fontWeight: FontWeight.w900,
                              color: Colors.black,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
            
            // Progress Bar (Processing)
            if (widget.rig.amount > 0)
              Padding(
                padding: const EdgeInsets.only(top: 8.0),
                child: AnimatedBuilder(
                  animation: _controller,
                  builder: (context, child) {
                    return LinearProgressIndicator(
                      value: _controller.value,
                      backgroundColor: Colors.black45,
                      color: neonColor,
                      minHeight: 4,
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }

  // A distinct, thematic icon per rig tier (all 10). Keep in sync with the
  // rig ladder in content/rig_defs.dart.
  IconData _getRigIcon(String id) {
    switch (id) {
      case RigIds.cpuRig: return Icons.memory;
      case RigIds.gpuRig: return Icons.developer_board;
      case RigIds.asicRig: return Icons.dns;
      case RigIds.miningFarm: return Icons.warehouse;
      case RigIds.quantumRig: return Icons.hub;
      case RigIds.fusionRig: return Icons.local_fire_department;
      case RigIds.photonicRig: return Icons.flare;
      case RigIds.datacenterRig: return Icons.cloud;
      case RigIds.dysonRig: return Icons.solar_power;
      case RigIds.singularityRig: return Icons.filter_tilt_shift;
      default: return Icons.cyclone;
    }
  }

  // A distinct neon accent per rig tier (all 10). Adjacent tiers never share a
  // hue so the ladder reads as ten different machines at a glance.
  Color _getRigColor(String id) {
    switch (id) {
      case RigIds.cpuRig: return Colors.cyanAccent;
      case RigIds.gpuRig: return Colors.purpleAccent;
      case RigIds.asicRig: return Colors.lightGreenAccent;
      case RigIds.miningFarm: return Colors.amberAccent;
      case RigIds.quantumRig: return Colors.blueAccent;
      case RigIds.fusionRig: return Colors.orangeAccent;
      case RigIds.photonicRig: return Colors.pinkAccent;
      case RigIds.datacenterRig: return Colors.tealAccent;
      case RigIds.dysonRig: return Colors.redAccent;
      case RigIds.singularityRig: return Colors.white;
      default: return AppTheme.accent;
    }
  }
}
