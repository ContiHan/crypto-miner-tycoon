import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/game_logic.dart';
import '../theme/app_theme.dart';
import '../widgets/class_picker.dart';
import '../widgets/first_visit_tip.dart';
import 'ending_overlay.dart';
import 'speed_run_overlay.dart';
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
  int _currentIndex = 2; // Start at MINE (centre tab)
  late GameLogic _gameLogic;
  // Guards the "WELCOME BACK" dialog so a background/resume cycle (which sets a
  // fresh offlineEarningsAmount + notifies) can't stack a second dialog over an
  // un-dismissed first one.
  bool _offlineDialogOpen = false;
  // Guards the once-per-crossing THE LAST SATOSHI ending overlay.
  bool _endingShown = false;
  // Re-entrancy guard for the (repeatable) SPEED RUN COMPLETE overlay.
  bool _speedRunOverlayOpen = false;

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
      _maybeShowEnding(_gameLogic);
      _maybeShowSpeedRunComplete(_gameLogic);
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
      case AppLifecycleState.detached:
        // Leaving the foreground: persist now and stop the loop. `paused` is
        // always reached on the way to the background (inactive->hidden->paused).
        _gameLogic.onAppPaused();
        break;
      case AppLifecycleState.resumed:
        // Returning: credit the elapsed background time and restart the loop.
        _gameLogic.onAppResumed();
        break;
      case AppLifecycleState.hidden:
      case AppLifecycleState.inactive:
        // Do NOT treat these as a pause. Flutter's lifecycle machine also
        // traverses paused->hidden->inactive->resumed on the way BACK to the
        // foreground; routing `hidden` to onAppPaused here would re-save
        // last_save_time=now on re-entry, zeroing the elapsed gap so the
        // WELCOME BACK offline payout is silently dropped on every warm resume.
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
    if (game.pendingTabUnlockToasts.isNotEmpty) {
      _showTabUnlockToasts(game);
    }
    // If a Wipe Save re-locked the tab we're parked on, fall back to MINE so we
    // never render a locked tab's body under a padlocked nav item.
    final onLocked = (_currentIndex == 0 && !game.unlockedSkill) ||
        (_currentIndex == 1 && !game.unlockedTech) ||
        (_currentIndex == 3 && !game.unlockedStash) ||
        (_currentIndex == 4 && !game.unlockedGoal);
    if (onLocked && mounted) setState(() => _currentIndex = 2); // fall back to MINE
    _maybeShowEnding(game);
    _maybeShowSpeedRunComplete(game);
  }

  void _showTabUnlockToasts(GameLogic game) {
    final tabs = List.of(game.pendingTabUnlockToasts);
    game.clearTabUnlockToasts();
    if (tabs.isEmpty) return;
    final label = tabs.length == 1
        ? '${tabs.first} tab unlocked!'
        : '${tabs.join(' & ')} tabs unlocked!';
    // Do NOT clearSnackBars() here — a tab unlock often coincides with an
    // achievement (first Hard Fork -> SKILL + hard_first; 1M sats -> STASH +
    // earn_1m); clearing would swallow the achievement's claim nudge. Let this
    // one queue after it instead.
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Row(
          children: [
            const Icon(Icons.lock_open_outlined, color: Colors.black, size: 18),
            const SizedBox(width: 8),
            Expanded(
              child: Text(label,
                  style: const TextStyle(
                      color: Colors.black, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
        duration: const Duration(seconds: 3),
        backgroundColor: AppTheme.accent,
        behavior: SnackBarBehavior.floating,
      ));
  }

  /// Fire the THE LAST SATOSHI ending exactly once when the win first crosses.
  void _maybeShowEnding(GameLogic game) {
    if (!game.pendingWinCelebration || _endingShown) return;
    // Don't stack over the WELCOME BACK dialog (an offline catch-up can trigger
    // both at once); defer — its whenComplete re-invokes this once dismissed.
    if (_offlineDialogOpen) return;
    _endingShown = true;
    game.clearWinCelebration();
    showEndingOverlay(
      context,
      game,
      onBackInTime: () => game.startSpeedRun(),
    );
  }

  /// Show the SPEED RUN COMPLETE overlay when a run finishes. Repeatable (each
  /// run), so it uses a re-entrancy guard rather than a permanent latch. Defers
  /// behind the WELCOME BACK dialog and the (higher-priority) THE LAST SATOSHI
  /// ending; both re-invoke this on dismissal / the next tick.
  void _maybeShowSpeedRunComplete(GameLogic game) {
    if (!game.pendingSpeedRunCelebration || _speedRunOverlayOpen) return;
    if (_offlineDialogOpen || game.pendingWinCelebration) return;
    _speedRunOverlayOpen = true;
    game.clearSpeedRunCelebration(); // the overlay reads last/best off `game`
    showSpeedRunCompleteOverlay(context, game).whenComplete(() {
      _speedRunOverlayOpen = false;
    });
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
        content: Row(
          children: [
            const Icon(Icons.emoji_events_outlined,
                color: Colors.black, size: 18),
            const SizedBox(width: 8),
            Expanded(
              child: Text('$label  ·  tap to claim',
                  style: const TextStyle(
                      color: Colors.black, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
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

  /// The first-visit coach card for [index], or nothing for MINE (index 2 has
  /// its own spotlight coach). Shows once per screen, then persists as dismissed.
  Widget _tipForTab(int index) {
    switch (index) {
      case 0:
        return const FirstVisitTip(
          tipId: 'tab_skill',
          icon: Icons.workspace_premium,
          title: 'SKILL',
          body: "Your class's skill tree. Pick a class at your first Hard "
              'Fork, then spend GovTokens on its nodes. Tap CLASS BONUSES to '
              'see every stat you have active right now.',
        );
      case 1:
        return const FirstVisitTip(
          tipId: 'tab_tech',
          icon: Icons.memory,
          title: 'TECH',
          body: 'Shared research, bought with BTC. One-shot upgrades that '
              'reset each fork — so grab the cheap early wins again every run.',
        );
      case 3:
        return const FirstVisitTip(
          tipId: 'tab_stash',
          icon: Icons.casino,
          title: 'STASH',
          body: 'SWEEP mini-games win UTXO, crates turn UTXO into permanent '
              'artifacts, and COLLECTION tracks what you own. Payouts are '
              'simulated — no real money or value.',
        );
      case 4:
        return const FirstVisitTip(
          tipId: 'tab_goal',
          icon: Icons.emoji_events,
          title: 'GOALS',
          body: 'Achievements. Each one you CLAIM adds permanent income '
              '(Notoriety), so check back and claim them as they unlock.',
        );
      default:
        return const SizedBox.shrink(); // MINE — handled by OnboardingCoach
    }
  }

  @override
  Widget build(BuildContext context) {
    // Pages for the navigation
    final List<Widget> pages = [
      const PerksScreen(isEmbedded: true), // Index 0: SKILL
      const ResearchTab(), // Index 1: TECH
      MiningTab(
        // Index 2: MINE (centre)
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
      const StashScreen(), // Index 3: STASH
      const AchievementsScreen(), // Index 4: GOAL
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
          Expanded(
            // A first-visit coach card overlays each newly-opened tab once
            // (MINE has its own spotlight coach, so it gets none here).
            child: Stack(
              children: [
                pages[_currentIndex],
                _tipForTab(_currentIndex),
              ],
            ),
          ),
        ],
      ),
      // Progressive disclosure: SKILL/TECH/STASH reveal as the player progresses
      // (sticky). The Selector rebuilds the bar only when an unlock flips.
      bottomNavigationBar: Selector<GameLogic, String>(
        selector: (_, g) =>
            '${g.unlockedSkill}|${g.unlockedTech}|${g.unlockedStash}|${g.unlockedGoal}',
        builder: (context, _, _) {
          final g = context.read<GameLogic>();
          final locked = <int, bool>{
            0: !g.unlockedSkill,
            1: !g.unlockedTech,
            3: !g.unlockedStash,
            4: !g.unlockedGoal,
          };
          return Theme(
            data: Theme.of(context).copyWith(
              canvasColor: AppTheme.surface, // Background for Nav Bar
            ),
            child: BottomNavigationBar(
              currentIndex: _currentIndex,
              onTap: (index) {
                // Locked tabs are inert — they don't switch, react, or reveal
                // what they are (a plain padlock only).
                if (locked[index] == true) return;
                _gameLogic.playUiClick();
                setState(() => _currentIndex = index);
              },
              selectedItemColor: AppTheme.accent,
              unselectedItemColor: AppTheme.textSecondary,
              showUnselectedLabels: true,
              type: BottomNavigationBarType.fixed,
              items: [
                _navItem(0, Icons.auto_graph, 'SKILL', locked),
                _navItem(1, Icons.science, 'TECH', locked),
                const BottomNavigationBarItem(
                    icon: Icon(Icons.dashboard), label: 'MINE'),
                _navItem(3, Icons.inventory_2, 'STASH', locked),
                // GOAL — an anonymous padlock until the first achievement lands;
                // once unlocked, the trophy + unread-claims badge.
                if (locked[4] == true)
                  _navItem(4, Icons.emoji_events, 'GOAL', locked)
                else
                  BottomNavigationBarItem(
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
          );
        },
      ),
    );
  }

  /// A nav item. Until unlocked it's an anonymous padlock ("???") — it never
  /// reveals which feature it will become.
  BottomNavigationBarItem _navItem(
      int index, IconData icon, String label, Map<int, bool> locked) {
    final isLocked = locked[index] == true;
    return BottomNavigationBarItem(
      icon: Icon(isLocked ? Icons.lock_outline : icon),
      label: isLocked ? '???' : label,
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
    final classHint = game.hasChosenClass
        ? ''
        : '\n\nTip: you can also pick/change your class anytime on the SKILL tab.';
    showClassPicker(
      context,
      game: game,
      title: 'START A NEW BLOCKCHAIN?',
      titleColor: Colors.deepPurpleAccent,
      confirmLabel: 'REBORN',
      confirmColor: Colors.deepPurple,
      headerLabel: 'CHOOSE YOUR CLASS FOR THE NEXT CHAIN:',
      info: 'THE DEEPEST RESET. Wipes Money, Rigs, Research, Talents, '
          'GovTokens and Consensus. Your Stash, UTXO chips & Mastery are KEPT.\n\n'
          'You will gain ${game.pendingGenesis} Genesis Block(s).\n'
          'Consensus & GovToken gain: x${game.genesisGainMultiplier.toStringAsFixed(1)} '
          '→ x${nextMultiplier.toStringAsFixed(1)}$classHint',
      onConfirm: (c) => game.newBlockchain(chosenClass: c),
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
    ).whenComplete(() {
      _offlineDialogOpen = false;
      // A win that crossed during the just-shown offline catch-up was deferred
      // (so it wouldn't stack); show it now that the dialog is dismissed.
      if (mounted) _maybeShowEnding(game);
      // Same for a Speed Run that finished during the offline catch-up.
      if (mounted) _maybeShowSpeedRunComplete(game);
    });
  }
}
