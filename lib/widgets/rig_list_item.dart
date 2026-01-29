import 'package:flutter/material.dart';
import '../models/rig.dart';
import '../providers/game_logic.dart';
import '../theme/app_theme.dart';
import '../utils/formatter.dart';
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
        // Pulse speed scales slightly with amount
        double speedFactor = 1.0 + (widget.rig.amount * 0.05);
        if (speedFactor > 3.0) speedFactor = 3.0; // Cap pulse speed
        
        _controller.duration = Duration(milliseconds: (1000 / speedFactor).round());
        _controller.repeat(reverse: true);
      }
    } else {
      _controller.stop();
      _controller.value = 1.0; // Reset scale
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
                ScaleTransition(
                  scale: Tween(begin: 0.8, end: 1.2).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut)),
                  child: Icon(_getRigIcon(widget.rig.id), color: Colors.white24, size: 40),
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
                  '+${Formatter.formatNumber(widget.rig.baseHashRate)} H/s',
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
              'BUY \n${Formatter.formatCurrency(widget.rig.currentCost)}',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  IconData _getRigIcon(String id) {
    switch (id) {
      case 'cpu_rig':
        return Icons.memory;
      case 'gpu_rig':
        return Icons.developer_board;
      case 'asic_rig':
        return Icons.dns;
      case 'quantum':
        return Icons.hub;
      default:
        return Icons.cyclone;
    }
  }
}
