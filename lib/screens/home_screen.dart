import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/game_logic.dart';
import '../theme/app_theme.dart';
import '../widgets/news_ticker.dart';
import 'perks_screen.dart';
import 'research_tab.dart';
import 'mining_tab.dart';
import 'settings_screen.dart';
import 'stash_screen.dart';
import '../utils/formatter.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  int _currentIndex = 3; // Start at Mine (Index 3)
  late GameLogic _gameLogic;
  // Guards the "WELCOME BACK" dialog so a background/resume cycle (which sets a
  // fresh offlineEarningsAmount + notifies) can't stack a second dialog over an
  // un-dismissed first one.
  bool _offlineDialogOpen = false;

  @override
  void initState() {
    super.initState();
    _gameLogic = Provider.of<GameLogic>(context, listen: false);

    // Observe app lifecycle so backgrounded time is saved and later reconciled.
    WidgetsBinding.instance.addObserver(this);

    // Check initially (in case it loaded instantly)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_gameLogic.offlineEarningsAmount != null) {
        _showOfflineEarningsDialog(
          context,
          _gameLogic,
          _gameLogic.offlineEarningsAmount!,
        );
      }
    });

    // Listen for future updates (async load)
    _gameLogic.addListener(_onGameUpdate);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _gameLogic.removeListener(_onGameUpdate);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.paused:
      case AppLifecycleState.hidden:
      case AppLifecycleState.detached:
        // Leaving the foreground: persist now and stop the loop.
        _gameLogic.onAppPaused();
        break;
      case AppLifecycleState.resumed:
        // Returning: credit the elapsed background time and restart the loop.
        _gameLogic.onAppResumed();
        break;
      case AppLifecycleState.inactive:
        break;
    }
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
      const StashScreen(), // Index 2: STASH
      MiningTab(
        // Index 3: MINE
        onHardFork: () => _showHardForkDialog(
          context,
          Provider.of<GameLogic>(context, listen: false),
        ),
        onNewBlockchain: () => _showNewBlockchainDialog(
          context,
          Provider.of<GameLogic>(context, listen: false),
        ),
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
          // Isolated: the ticker repaints every frame (~60fps); RepaintBoundary
          // keeps those repaints from invalidating the rest of the screen.
          const RepaintBoundary(child: NewsTicker()),
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
            _gameLogic.playUiClick();
            setState(() {
              _currentIndex = index;
            });
          },
          selectedItemColor: AppTheme.accent,
          unselectedItemColor: AppTheme.textSecondary,
          showUnselectedLabels: true,
          type: BottomNavigationBarType.fixed,
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.auto_graph),
              label: 'PERKS',
            ),
            BottomNavigationBarItem(icon: Icon(Icons.science), label: 'LAB'),
            BottomNavigationBarItem(
              icon: Icon(Icons.inventory_2),
              label: 'STASH',
            ),
            BottomNavigationBarItem(icon: Icon(Icons.dashboard), label: 'MINE'),
          ],
        ),
      ),
    );
  }

  void _showHardForkDialog(BuildContext context, GameLogic game) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surface,
        title: const Text(
          'EXECUTE HARD FORK?',
          style: TextStyle(color: Colors.redAccent),
        ),
        content: Text(
          'This will reset your Money and Rigs.\n\n'
          'You will gain ${Formatter.formatNumber(game.pendingGovTokens.toDouble())} GovTokens.\n'
          'Current Multiplier: x${game.prestigeMultiplier.toStringAsFixed(1)}\n'
          'New Multiplier: x${game.prestigeMultiplierAfterHardFork.toStringAsFixed(1)}',
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

  void _showNewBlockchainDialog(BuildContext context, GameLogic game) {
    // Concave projection (matches PrestigeSystem), so the dialog never
    // overstates the reward of this irreversible reset.
    final nextMultiplier = game.genesisGainMultiplierAfterNewChain;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surface,
        title: const Text(
          'START A NEW BLOCKCHAIN?',
          style: TextStyle(color: Colors.deepPurpleAccent),
        ),
        content: Text(
          'THE DEEPEST RESET. This wipes your Money, Rigs, Research, Perks, '
          'Chips, GovTokens and Consensus.\n\n'
          'Your Stash collection is KEPT.\n\n'
          'You will gain ${game.pendingGenesis} Genesis Block(s).\n'
          'Consensus & GovToken gain: x${game.genesisGainMultiplier.toStringAsFixed(1)} '
          '→ x${nextMultiplier.toStringAsFixed(1)}',
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('CANCEL'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.deepPurple),
            onPressed: () {
              game.newBlockchain();
              Navigator.pop(ctx);
            },
            child: const Text('REBORN'),
          ),
        ],
      ),
    );
  }

  void _showOfflineEarningsDialog(
    BuildContext context,
    GameLogic game,
    double amount,
  ) {
    if (_offlineDialogOpen) return; // never stack a second WELCOME BACK dialog
    _offlineDialogOpen = true;
    game.clearOfflineEarnings();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surface,
        title: const Text(
          'WELCOME BACK!',
          style: TextStyle(color: AppTheme.accent),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'While you were away, your rigs mined:',
              style: TextStyle(color: Colors.white70),
            ),
            const SizedBox(height: 20),
            Text(
              Formatter.formatBitcoin(amount),
              style: const TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.bold,
                color: AppTheme.accent,
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
    ).whenComplete(() => _offlineDialogOpen = false);
  }
}
