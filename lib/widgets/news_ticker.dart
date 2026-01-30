import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/game_logic.dart';
import '../theme/app_theme.dart';
import '../models/news_event.dart';

class NewsTicker extends StatelessWidget {
  const NewsTicker({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<GameLogic>(
      builder: (context, game, child) {
        if (game.currentNews == null) return const SizedBox.shrink();

        final news = game.currentNews!;

        return Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: news.color.withValues(alpha: 0.2),
            border: Border(bottom: BorderSide(color: news.color, width: 2)),
          ),
          child: Row(
            children: [
               Icon(Icons.campaign, color: news.color),
               const SizedBox(width: 8),
               Expanded(
                 child: Text(
                   news.message.toUpperCase(),
                   style: TextStyle(
                     color: news.color,
                     fontWeight: FontWeight.bold,
                     fontFamily: 'Orbitron',
                     fontSize: 12,
                   ),
                   overflow: TextOverflow.ellipsis,
                 ),
               ),
            ],
          ),
        );
      },
      child: const SizedBox.shrink(),
    );
  }
}
