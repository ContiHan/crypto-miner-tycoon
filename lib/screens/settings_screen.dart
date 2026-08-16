import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/game_logic.dart';
import '../theme/app_theme.dart';
import 'credits_screen.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('SETTINGS'),
      ),
      body: Consumer<GameLogic>(
        builder: (context, game, child) {
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // Sound Settings
              ListTile(
                title: const Text('Sound Effects', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                subtitle: Text(game.soundEnabled ? 'On' : 'Off', style: const TextStyle(color: Colors.white70)),
                trailing: Switch(
                  value: game.soundEnabled,
                  activeThumbColor: AppTheme.accent,
                  activeTrackColor: AppTheme.accent.withValues(alpha: 0.3),
                  onChanged: (val) => game.toggleSound(),
                ),
              ),
              const Divider(color: Colors.white24),

              // Haptics Settings
              ListTile(
                title: const Text('Haptics (Vibration)', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                subtitle: Text(game.hapticsEnabled ? 'On' : 'Off', style: const TextStyle(color: Colors.white70)),
                trailing: Switch(
                  value: game.hapticsEnabled,
                  activeThumbColor: AppTheme.accent,
                  activeTrackColor: AppTheme.accent.withValues(alpha: 0.3),
                  onChanged: (val) => game.toggleHaptics(),
                ),
              ),
              const Divider(color: Colors.white24),

              // About / Credits — the finale. UNLOCKED only after THE LAST SATOSHI
              // (mining a full 21M supply in one era); hidden until then so it
              // reads as an earned reward, not something you can peek at from the
              // start. The ending overlay also links here on the win itself.
              if (game.hasWonGame) ...[
                ListTile(
                  title: const Text('Credits & Thanks',
                      style: TextStyle(
                          color: Colors.white, fontWeight: FontWeight.bold)),
                  subtitle: const Text('About the game & the human behind it',
                      style: TextStyle(color: Colors.white70)),
                  trailing:
                      const Icon(Icons.favorite_border, color: AppTheme.accent),
                  onTap: () => CreditsScreen.open(context),
                ),
                const Divider(color: Colors.white24),
              ],

              // Danger Zone
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 16.0),
                child: Text('DANGER ZONE', style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold, letterSpacing: 1.5)),
              ),
              
              Container(
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.redAccent.withValues(alpha: 0.5)),
                  borderRadius: BorderRadius.circular(8),
                  color: Colors.redAccent.withValues(alpha: 0.1),
                ),
                child: ListTile(
                  title: const Text('HARD RESET GAME', style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
                  subtitle: const Text('Wipes your save completely. No undo.', style: TextStyle(color: Colors.white60)),
                  trailing: const Icon(Icons.delete_forever, color: Colors.redAccent),
                  onTap: () => _confirmReset(context, game),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  void _confirmReset(BuildContext context, GameLogic game) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surface,
        title: const Text('DELETE EVERYTHING?', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
        content: const Text(
          'This will delete your progress, your rigs, your money, and your Prestige Tokens.\n\nAre you absolutely sure?',
          style: TextStyle(color: Colors.white),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('CANCEL', style: TextStyle(color: Colors.white70)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () {
              game.resetGame();
              Navigator.pop(ctx); // Close dialog
              Navigator.pop(context); // Close Settings, back to Home
              
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Game Reset Successful'), backgroundColor: Colors.redAccent),
              );
            },
            child: const Text('DELETE SAVE', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}
