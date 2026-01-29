import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/rig.dart';
import '../providers/game_logic.dart';
import '../theme/app_theme.dart';
import 'stylized_card.dart';

class RigListItem extends StatefulWidget {
  final Rig rig;
  final GameLogic game;
  final VoidCallback? onBuy;

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
      if (!_controller.isAnimating) {
        _controller.repeat();
      }
    } else {
      _controller.stop();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final canAfford = widget.game.wallet >= widget.rig.currentCost;

    return StylizedCard(
      child: Row(
        children: [
          // Icon / Spinner
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: Colors.black38,
              border: Border.all(color: AppTheme.accent),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                RotationTransition(
                  turns: _controller,
                  child: const Icon(Icons.toys, color: Colors.white24, size: 40),
                ),
                Text(
                  '${widget.rig.amount}',
                  style: const TextStyle(
                      color: AppTheme.accent,
                      fontWeight: FontWeight.bold,
                      fontSize: 20),
                ),
              ],
            ),
          ),
          const SizedBox(width: 15),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.rig.name.toUpperCase(),
                  style: const TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 16,
                    color: Colors.white,
                  ),
                ),
                Text(
                  '+${widget.rig.baseHashRate} H/s',
                  style: TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          ElevatedButton(
            onPressed: canAfford ? () {
              widget.game.buyRig(widget.rig.id);
              widget.onBuy?.call();
            } : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: canAfford ? AppTheme.accent : Colors.grey[800],
              foregroundColor: Colors.black,
            ),
            child: Text(
              'BUY \n${widget.rig.currentCost.toStringAsFixed(0)}',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }
}
