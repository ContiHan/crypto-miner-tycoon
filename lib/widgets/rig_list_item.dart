import 'package:flutter/material.dart';
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

  @override
  void didUpdateWidget(covariant RigListItem oldWidget) {
    super.didUpdateWidget(oldWidget);
    _checkAnimation();
  }

  void _checkAnimation() {
    if (widget.rig.amount > 0) {
      // Speed up progress bar based on amount.
      double speedFactor = 1.0 + (widget.rig.amount * 0.05);
      if (speedFactor > 5.0) speedFactor = 5.0; // Cap speed
      
      final newDuration = Duration(milliseconds: (2000 / speedFactor).round());
      
      if (_controller.duration != newDuration) {
        _controller.duration = newDuration;
        if (_controller.isAnimating) {
           _controller.repeat(); // Restart with new duration
        } else {
           _controller.repeat();
        }
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
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
      final double actualCost = widget.game.getRigCost(widget.rig);
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
                        overflow: TextOverflow.visible,
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
                
                // Buy Button
                Builder(
                  builder: (ctx) {
                    return ElevatedButton(
                      onPressed: canAfford ? () {
                        widget.game.buyRig(widget.rig.id);
                        
                        // Find position of this button
                        final RenderBox box = ctx.findRenderObject() as RenderBox;
                        final Offset position = box.localToGlobal(box.size.center(Offset.zero));
                        
                        widget.onBuy?.call(position);
                      } : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: canAfford ? AppTheme.accent : Colors.grey[800],
                        foregroundColor: Colors.black,
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        minimumSize: const Size(80, 40),
                      ),
                      child: Column(
                        children: [
                          const Text(
                            'BUY',
                            style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
                          ),
                          FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(
                              widget.game.showFiatPrices 
                                  ? '\$ ${Formatter.formatNumber(widget.game.getRigCostInCredits(widget.rig))}'
                                  : Formatter.formatBitcoin(widget.game.getRigCost(widget.rig)),
                              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w900),
                            ),
                          ),
                        ],
                      ),
                    );
                  }
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

  IconData _getRigIcon(String id) {
    switch (id) {
      case 'cpu_rig': return Icons.memory;
      case 'gpu_rig': return Icons.developer_board;
      case 'asic_rig': return Icons.dns;
      case 'quantum': return Icons.hub;
      default: return Icons.cyclone;
    }
  }

  Color _getRigColor(String id) {
    switch (id) {
      case 'cpu_rig': return Colors.cyanAccent;
      case 'gpu_rig': return Colors.purpleAccent;
      case 'asic_rig': return Colors.lightGreenAccent;
      case 'quantum': return Colors.blueAccent;
      default: return AppTheme.accent;
    }
  }
}
