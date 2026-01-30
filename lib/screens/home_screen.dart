import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/game_logic.dart';
import '../theme/app_theme.dart';
import '../widgets/news_ticker.dart';
import 'perks_screen.dart';
import 'research_tab.dart';
import 'mining_tab.dart';
import 'settings_screen.dart';
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
    final game = Provider.of<GameLogic>(context, listen: false);
    
    // Check initially (in case it loaded instantly)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (game.offlineEarningsAmount != null) {
        _showOfflineEarningsDialog(context, game, game.offlineEarningsAmount!);
      }
    });

    // Listen for future updates (async load)
    game.addListener(_onGameUpdate);
  }

  @override
  void dispose() {
    final game = Provider.of<GameLogic>(context, listen: false);
    game.removeListener(_onGameUpdate);
    super.dispose();
  }

  void _onGameUpdate() {
    if (!mounted) return;
    final game = Provider.of<GameLogic>(context, listen: false);
    if (game.offlineEarningsAmount != null) {
      _showOfflineEarningsDialog(context, game, game.offlineEarningsAmount!);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Pages for the navigation
    final List<Widget> pages = [
      const PerksScreen(isEmbedded: true), // Index 0: PERKS
      const ResearchTab(), // Index 1: LAB
      _buildPlaceholder('SECRET STASH\n(Coming Soon)', Icons.lock), // Index 2: STASH
      const SizedBox.shrink(), // Index 3: Spacer
      MiningTab( // Index 4: HACK
        onHardFork: () => _showHardForkDialog(context, Provider.of<GameLogic>(context, listen: false)),
        onBuyRig: (cost) {}, 
      ),
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text('BTC ONLY TYCOON'),
        actions: [
           IconButton(
             icon: const Icon(Icons.settings),
             onPressed: () {
               Navigator.push(
                 context,
                 MaterialPageRoute(builder: (context) => const SettingsScreen()),
               );
             },
           ),
        ],
      ),
      body: Column(
        children: [
           const NewsTicker(),
           Expanded(child: pages[_currentIndex]),
        ],
      ),
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
              icon: Icon(Icons.lock), 
              label: 'STASH'
            ),
             BottomNavigationBarItem(
              icon: Icon(Icons.circle, color: Colors.transparent), // Invisible spacer
              label: ''
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.terminal), 
              label: 'HACK'
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
