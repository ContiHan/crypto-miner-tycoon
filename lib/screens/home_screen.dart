import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/game_logic.dart';
import '../theme/app_theme.dart';
import 'perks_screen.dart';
import 'mining_tab.dart';
import '../utils/formatter.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 4; // Start at Mine (Index 4)

  @override
  void initState() {
    super.initState();
    // Check for offline earnings after first frame
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final game = Provider.of<GameLogic>(context, listen: false);
      if (game.offlineEarningsAmount != null) {
        _showOfflineEarningsDialog(context, game, game.offlineEarningsAmount!);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    // Pages for the navigation
    final List<Widget> pages = [
      const PerksScreen(isEmbedded: true), // Index 0: Perks
      _buildPlaceholder('LABORATORY\n(Research Coming Soon)', Icons.science), // Index 1: Research
      _buildPlaceholder('WAREHOUSE\n(Reserve Coming Soon)', Icons.inventory_2), // Index 2: Reserve
      const SizedBox.shrink(), // Index 3: Spacer/Empty
      MiningTab( // Index 4: Mine
        onHardFork: () => _showHardForkDialog(context, Provider.of<GameLogic>(context, listen: false)),
        onBuyRig: (cost) {}, // Managed internally by tab now
      ),
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text('BTC ONLY TYCOON'),
      ),
      body: pages[_currentIndex],
      bottomNavigationBar: Theme(
        data: Theme.of(context).copyWith(
           canvasColor: AppTheme.surface, // Background for Nav Bar
        ),
        child: BottomNavigationBar(
          currentIndex: _currentIndex,
          onTap: (index) {
            // Index 3 is empty spacer, ignore click
            if (index != 3) {
              setState(() {
                _currentIndex = index;
              });
            }
          },
          selectedItemColor: AppTheme.accent,
          unselectedItemColor: AppTheme.textSecondary,
          showUnselectedLabels: true,
          type: BottomNavigationBarType.fixed,
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.auto_graph), 
              label: 'PERKS'
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.science), 
              label: 'LAB'
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.inventory_2), 
              label: 'RESERVE'
            ),
             BottomNavigationBarItem(
              icon: Icon(Icons.circle, color: Colors.transparent), // Invisible spacer
              label: ''
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.touch_app), 
              label: 'MINE'
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildPlaceholder(String text, IconData icon) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 80, color: Colors.white12),
          const SizedBox(height: 20),
          Text(text, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white54)),
        ],
      ),
    );
  }

  void _showHardForkDialog(BuildContext context, GameLogic game) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surface,
        title: const Text('EXECUTE HARD FORK?', style: TextStyle(color: Colors.redAccent)),
        content: Text(
          'This will reset your Money and Rigs.\n\n'
          'You will gain ${Formatter.formatNumber(game.pendingGovTokens.toDouble())} GovTokens.\n'
          'Current Multiplier: x${game.prestigeMultiplier.toStringAsFixed(1)}\n'
          'New Multiplier: x${(1.0 + ((game.govTokens + game.pendingGovTokens) * 0.1)).toStringAsFixed(1)}',
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('CANCEL'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () {
              game.hardFork();
              Navigator.pop(ctx);
            },
            child: const Text('RESET & CLAIM'),
          ),
        ],
      ),
    );
  }

  void _showOfflineEarningsDialog(BuildContext context, GameLogic game, double amount) {
    game.clearOfflineEarnings();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surface,
        title: const Text('WELCOME BACK!', style: TextStyle(color: AppTheme.accent)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('While you were away, your rigs mined:', style: TextStyle(color: Colors.white70)),
            const SizedBox(height: 20),
            Text(
              '₿ ${Formatter.formatCurrency(amount)}',
              style: const TextStyle(
                fontSize: 32, 
                fontWeight: FontWeight.bold, 
                color: AppTheme.accent
              ),
            ),
          ],
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('COLLECT'),
          ),
        ],
      ),
    );
  }
}
