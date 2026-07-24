import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/game_logic.dart';
import '../logic/managers/class_manager.dart';
import '../logic/channels.dart';
import '../theme/app_theme.dart';
import '../widgets/news_ticker.dart';
import 'perks_screen.dart';
import 'research_tab.dart';
import 'mining_tab.dart';
import 'settings_screen.dart';
import 'stash_screen.dart';
import 'achievements_screen.dart';
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
    if (game.pendingAchievementToasts.isNotEmpty) {
      _showAchievementToasts(game);
    }
  }

  void _showAchievementToasts(GameLogic game) {
    final toasts = List.of(game.pendingAchievementToasts);
    game.clearAchievementToasts();
    if (toasts.isEmpty) return;

    // Aggregate simultaneous unlocks into one non-spammy, actionable toast.
    final label = toasts.length == 1
        ? 'Achievement unlocked: ${toasts.first.title}'
        : '${toasts.length} achievements unlocked!';
    final messenger = ScaffoldMessenger.of(context)..clearSnackBars();
    messenger.showSnackBar(
      SnackBar(
        content: Text('🏆  $label  ·  tap to claim'),
        duration: const Duration(seconds: 4),
        backgroundColor: AppTheme.accent,
        behavior: SnackBarBehavior.floating,
        action: SnackBarAction(
          label: 'VIEW',
          textColor: Colors.black,
          onPressed: () {
            if (mounted) setState(() => _currentIndex = 4); // GOALS tab
          },
        ),
      ),
    );
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
      const AchievementsScreen(), // Index 4: GOALS
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
          items: [
            const BottomNavigationBarItem(
              icon: Icon(Icons.auto_graph),
              label: 'SKILL',
            ),
            const BottomNavigationBarItem(
                icon: Icon(Icons.science), label: 'TECH'),
            const BottomNavigationBarItem(
              icon: Icon(Icons.inventory_2),
              label: 'STASH',
            ),
            const BottomNavigationBarItem(
                icon: Icon(Icons.dashboard), label: 'MINE'),
            BottomNavigationBarItem(
              // Unread badge so newly-unlocked achievements aren't missed.
              icon: Selector<GameLogic, int>(
                selector: (_, g) => g.unclaimedAchievements,
                builder: (_, count, _) => count > 0
                    ? Badge.count(
                        count: count,
                        backgroundColor: Colors.redAccent,
                        child: const Icon(Icons.emoji_events),
                      )
                    : const Icon(Icons.emoji_events),
              ),
              label: 'GOAL',
            ),
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

  /// Compact one-line effect summary for a class card.
  static String _classEffectSummary(ClassDef def) {
    final parts = <String>[];
    void pct(double v, String label) {
      if (v == 0) return;
      final sign = v > 0 ? '+' : '';
      parts.add('$sign${(v * 100).toStringAsFixed(0)}% $label');
    }

    pct(def.channelBonuses[Channel.hash] ?? 0, 'hash');
    pct(def.channelBonuses[Channel.income] ?? 0, 'income');
    pct(def.channelBonuses[Channel.click] ?? 0, 'click');
    final rig = def.channelBonuses[Channel.rigCost] ?? 0;
    if (rig != 0) parts.add('-${(rig * 100).toStringAsFixed(0)}% rig cost');
    pct(def.channelBonuses[Channel.luck] ?? 0, 'luck');
    final vol = def.channelBonuses[Channel.volatility] ?? 0;
    if (vol > 0) parts.add('louder chaos');
    if (vol < 0) parts.add('calmer markets');
    if (def.prestigeGainMult > 1) {
      parts.add('+${((def.prestigeGainMult - 1) * 100).toStringAsFixed(0)}% prestige gain');
    } else if (def.prestigeGainMult < 1) {
      parts.add('-${((1 - def.prestigeGainMult) * 100).toStringAsFixed(0)}% prestige gain');
    }
    return parts.join(' · ');
  }

  void _showNewBlockchainDialog(BuildContext context, GameLogic game) {
    // Concave projection (matches PrestigeSystem), so the dialog never
    // overstates the reward of this irreversible reset.
    final nextMultiplier = game.genesisGainMultiplierAfterNewChain;
    // The four real archetypes (Prospector is only the class-less start).
    final choices = BtcClass.values
        .where((c) => c != BtcClass.prospector)
        .toList();
    BtcClass? selected =
        game.hasChosenClass ? game.currentClass : null; // pre-select current

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          backgroundColor: AppTheme.surface,
          title: const Text(
            'START A NEW BLOCKCHAIN?',
            style: TextStyle(color: Colors.deepPurpleAccent),
          ),
          content: SizedBox(
            width: double.maxFinite,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'THE DEEPEST RESET. Wipes Money, Rigs, Research, Talents, '
                    'Chips, GovTokens and Consensus. Your Stash & Mastery are KEPT.\n\n'
                    'You will gain ${game.pendingGenesis} Genesis Block(s).\n'
                    'Consensus & GovToken gain: x${game.genesisGainMultiplier.toStringAsFixed(1)} '
                    '→ x${nextMultiplier.toStringAsFixed(1)}',
                    style: const TextStyle(color: Colors.white70, fontSize: 13),
                  ),
                  const SizedBox(height: 14),
                  const Text(
                    'CHOOSE YOUR CLASS FOR THE NEXT CHAIN:',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 8),
                  for (final c in choices)
                    _ClassChoiceCard(
                      def: kClasses[c]!,
                      masteryLevel: game.masteryLevel(c),
                      selected: selected == c,
                      effect: _classEffectSummary(kClasses[c]!),
                      onTap: () => setLocal(() => selected = c),
                    ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('CANCEL'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.deepPurple,
                disabledBackgroundColor: Colors.deepPurple.withValues(alpha: 0.3),
              ),
              onPressed: selected == null
                  ? null
                  : () {
                      game.newBlockchain(chosenClass: selected);
                      Navigator.pop(ctx);
                    },
              child: const Text('REBORN'),
            ),
          ],
        ),
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

/// A selectable class card in the New Blockchain picker.
class _ClassChoiceCard extends StatelessWidget {
  final ClassDef def;
  final int masteryLevel;
  final bool selected;
  final String effect;
  final VoidCallback onTap;

  const _ClassChoiceCard({
    required this.def,
    required this.masteryLevel,
    required this.selected,
    required this.effect,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: selected
              ? def.color.withValues(alpha: 0.15)
              : Colors.white.withValues(alpha: 0.03),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: selected ? def.color : Colors.white24,
            width: selected ? 2 : 1,
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(def.icon, color: def.color, size: 28),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          def.name,
                          style: TextStyle(
                            color: def.color,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                      ),
                      if (masteryLevel > 0)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.amber.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            'MASTERY $masteryLevel',
                            style: const TextStyle(
                              color: Colors.amber,
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                    ],
                  ),
                  Text(
                    def.tagline,
                    style: const TextStyle(
                      color: Colors.white54,
                      fontSize: 11,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                  if (effect.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      effect,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
