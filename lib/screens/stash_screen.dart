import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../providers/game_logic.dart';
import '../services/stash_service.dart';
import '../services/casino_service.dart';
import '../theme/app_theme.dart';
import '../utils/formatter.dart';
import '../widgets/stylized_card.dart';
import '../widgets/firmware_panel.dart';

class StashScreen extends StatefulWidget {
  const StashScreen({super.key});

  @override
  State<StashScreen> createState() => _StashScreenState();
}

/// Which casino game the selector is showing (only one is mounted at a time).
enum CasinoGame { slots, plinko, flip }

class _StashScreenState extends State<StashScreen>
    with TickerProviderStateMixin, WidgetsBindingObserver {
  late TabController _tabController;
  bool _isErrorShowing = false;

  // Casino local UI state.
  int _bet = 1;
  CasinoGame _selectedGame = CasinoGame.slots; // slots = the polished default
  // Drives the SWEEP game body. The three games live in a PageView with swipe
  // DISABLED (the parent STASH TabBarView already owns the horizontal swipe) —
  // the SegmentedButton animates between "windows" instead, giving the slide
  // feel without a gesture conflict.
  late PageController _gamePageController;
  String? _casinoMessage;
  Color _casinoMessageColor = Colors.white70;

  // Slot reel animation state.
  final Random _rng = Random();
  bool _slotSpinning = false;
  final List<String> _reels = ['coin', 'rocket', 'diamond'];
  List<bool> _reelSettled = [true, true, true];
  Timer? _spinTimer;

  // A RESOLVED-but-not-yet-committed sweep outcome: its stake is already deducted
  // (so the header naturally shows the bet gone, payout hidden), but the payout /
  // net cap / achievements are committed only when the animation lands — via
  // [_finishSweep], which also runs on dispose so leaving mid-flight never loses
  // the stake. This is what stops a win/achievement/cap from flashing at tap time.
  SweepOutcome? _pendingSweep;
  GameLogic? _pendingGame;

  // Plinko animation state.
  bool _plinkoDropping = false;
  late final AnimationController _plinkoController;
  List<bool>? _plinkoPath; // the drop being animated (null = idle)
  int _plinkoLandedSlot = -1; // landed bucket, highlighted after settle

  // Hash Flip animation state. While hashing, the hex string scrambles ("mining"
  // a nonce); on reveal it settles to a hash with `_flipReveal.zeros` glowing
  // leading zeros (the tier that was hit).
  bool _flipHashing = false;
  String _flipHashText = '0x00000000';
  FlipResult? _flipReveal; // the settled result (null while hashing / idle)
  Timer? _flipTimer;

  // The three SWEEP games share _casinoMessage / the pending-sweep slot, so only
  // one may animate at a time — otherwise a second game clobbers the first.
  bool get _casinoBusy => _slotSpinning || _plinkoDropping || _flipHashing;

  // Real outline icons (no emoji) for the slot symbol keys.
  static const Map<String, IconData> _slotIcons = {
    'moon': Icons.dark_mode_outlined,
    'rocket': Icons.rocket_launch_outlined,
    'diamond': Icons.diamond_outlined,
    'coin': Icons.paid_outlined,
    'bolt': Icons.electric_bolt_outlined,
  };
  static const Map<String, Color> _slotColors = {
    'moon': Colors.amberAccent,
    'rocket': Colors.redAccent,
    'diamond': Colors.cyanAccent,
    'coin': AppTheme.accent,
    'bolt': Colors.yellowAccent,
  };

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _gamePageController = PageController(initialPage: _selectedGame.index);
    _plinkoController = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1400));
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // If the app backgrounds mid-animation, settle the in-flight sweep NOW (a
    // silent commit that saves) so a process-kill can't strand a deducted stake
    // with no payout. A no-op when nothing is pending. The animation, if the app
    // resumes, finishes into an already-committed (idempotent) _finishSweep.
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden ||
        state == AppLifecycleState.detached) {
      _finishSweep(silent: true);
    }
  }

  @override
  void dispose() {
    // The screen is rebuilt on every bottom-nav switch, so a missing dispose
    // leaked a TabController (and its ticker) per visit and could assert in
    // debug when leaving mid tab-animation.
    WidgetsBinding.instance.removeObserver(this);
    _tabController.dispose();
    _gamePageController.dispose();
    _spinTimer?.cancel();
    _flipTimer?.cancel();
    _plinkoController.dispose();
    // If the player left mid-animation, still commit the resolved outcome so the
    // stake isn't silently lost. SILENT: no notifyListeners during dispose (it
    // would markNeedsBuild on the locked tree and assert in debug); it still
    // credits + saves, so the payout lands into their balance for later.
    _finishSweep(silent: true);
    super.dispose();
  }

  void _showCrateOpening(BuildContext context, CrateTier tier, GameLogic game) {
    // Logic is handled in game.buyCrate, here we just trigger it and show feedback
    if (game.chips < crateDef(tier).cost) {
      if (_isErrorShowing) return;
      _isErrorShowing = true;
      ScaffoldMessenger.of(context)
          .showSnackBar(
            const SnackBar(
              content: Text('Not enough UTXO!'),
              backgroundColor: Colors.red,
            ),
          )
          .closed
          .then((_) => _isErrorShowing = false);
      return;
    }

    // Open the crate and reveal exactly what dropped.
    final won = game.buyCrate(tier);
    if (won == null) return;
    final count = game.stashService.ownedArtifacts[won.id] ?? 1;
    final color = _rarityColor(won.rarity);

    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        elevation: 0,
        child: TweenAnimationBuilder<double>(
          tween: Tween(begin: 0.0, end: 1.0),
          duration: const Duration(milliseconds: 500),
          curve: Curves.easeOutBack, // pop-in overshoot
          builder: (context, t, child) =>
              Transform.scale(scale: t.clamp(0.0, 1.2), child: child),
          child: _crateRevealCard(ctx, won, count, color),
        ),
      ),
    );
  }

  Widget _crateRevealCard(
      BuildContext ctx, Artifact won, int count, Color color) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color, width: 2),
        boxShadow: [
          BoxShadow(
              color: color.withValues(alpha: 0.45),
              blurRadius: 28,
              spreadRadius: 2),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            won.rarity.name.toUpperCase(),
            style: GoogleFonts.orbitron(
              color: color,
              fontWeight: FontWeight.bold,
              letterSpacing: 4,
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 16),
          Icon(Icons.extension, color: color, size: 64),
          const SizedBox(height: 16),
          Text(
            won.name,
            textAlign: TextAlign.center,
            style: const TextStyle(
                color: Colors.white, fontWeight: FontWeight.bold, fontSize: 20),
          ),
          const SizedBox(height: 6),
          Text(won.description,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white70, fontSize: 13)),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              count <= 1 ? 'NEW!' : 'DUPLICATE — now Lvl $count',
              style: TextStyle(
                  color: color, fontWeight: FontWeight.bold, fontSize: 12),
            ),
          ),
          const SizedBox(height: 18),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx),
            style: ElevatedButton.styleFrom(
                backgroundColor: color, foregroundColor: Colors.black),
            child: const Text('NICE',
                style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        backgroundColor: AppTheme.surface,
        centerTitle: true,
        // Full title at a size that fits; FittedBox scales down further on very
        // narrow screens so it never truncates with an ellipsis.
        title: FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            'STASH',
            maxLines: 1,
            style: GoogleFonts.orbitron(
              fontWeight: FontWeight.bold,
              fontSize: 15,
              letterSpacing: 0.5,
              color: AppTheme.accent,
            ),
          ),
        ),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppTheme.accent,
          labelColor: AppTheme.accent,
          unselectedLabelColor: Colors.white54,
          isScrollable: true,
          tabs: const [
            Tab(icon: Icon(Icons.casino), text: "SWEEP"),
            Tab(icon: Icon(Icons.inventory_2), text: "CRATES"),
            Tab(icon: Icon(Icons.grid_view), text: "COLLECTION"),
            Tab(icon: Icon(Icons.memory), text: "FIRMWARE"),
          ],
        ),
      ),
      body: Consumer<GameLogic>(
        builder: (context, game, child) {
          return TabBarView(
            controller: _tabController,
            children: [
              _buildCasinoTab(context, game),
              _buildMarketTab(context, game),
              _buildCollectionTab(context, game),
              FirmwarePanel(game: game),
            ],
          );
        },
      ),
    );
  }

  Widget _buildMarketTab(BuildContext context, GameLogic game) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Balance Header
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.black45,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppTheme.accent.withValues(alpha: 0.3)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'UTXO COLLECTED',
                    style: TextStyle(
                      color: Colors.white54,
                      fontSize: 10,
                      letterSpacing: 1,
                    ),
                  ),
                  Row(
                    children: [
                      const Icon(
                        Icons.token,
                        color: Colors.cyanAccent,
                        size: 24,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '${game.chips}',
                        style: GoogleFonts.orbitron(
                          fontSize: 28,
                          color: Colors.cyanAccent,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  const Text(
                    'GOVERNANCE TOKENS',
                    style: TextStyle(
                      color: Colors.white54,
                      fontSize: 10,
                      letterSpacing: 1,
                    ),
                  ),
                  Text(
                    Formatter.formatNumber(game.govTokens.toDouble()),
                    style: GoogleFonts.orbitron(
                      fontSize: 18,
                      color: Colors.white70,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),

        const Text(
          'SUPPLY CRATES',
          style: TextStyle(
            color: AppTheme.accent,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.5,
          ),
        ),
        const SizedBox(height: 8),

        // 2×2 grid of the four crate tiers. IntrinsicHeight per row keeps each
        // pair equal height and lets them GROW to fit their text (no clipping).
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(child: _buildCrateCard(context, game, CrateTier.scrap)),
              const SizedBox(width: 12),
              Expanded(
                  child: _buildCrateCard(context, game, CrateTier.standard)),
            ],
          ),
        ),
        const SizedBox(height: 12),
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                  child: _buildCrateCard(context, game, CrateTier.premium)),
              const SizedBox(width: 12),
              Expanded(
                  child: _buildCrateCard(context, game, CrateTier.quantum)),
            ],
          ),
        ),
      ],
    );
  }

  static Color _crateColor(CrateTier tier) {
    switch (tier) {
      case CrateTier.scrap:
        return Colors.blueGrey;
      case CrateTier.standard:
        return Colors.blueAccent;
      case CrateTier.premium:
        return Colors.amber;
      case CrateTier.quantum:
        return Colors.purpleAccent;
    }
  }

  static IconData _crateIcon(CrateTier tier) {
    switch (tier) {
      case CrateTier.scrap:
        return Icons.inventory_2_outlined;
      case CrateTier.standard:
        return Icons.inventory_2;
      case CrateTier.premium:
        return Icons.workspace_premium;
      case CrateTier.quantum:
        return Icons.auto_awesome;
    }
  }

  Widget _buildCrateCard(BuildContext context, GameLogic game, CrateTier tier) {
    final def = crateDef(tier);
    final color = _crateColor(tier);
    final affordable = game.chips >= def.cost;
    return Opacity(
      opacity: affordable ? 1.0 : 0.45, // dim (still tappable → "not enough" toast)
      child: GestureDetector(
        onTap: () => _showCrateOpening(context, tier, game),
        child: Container(
          constraints: const BoxConstraints(minHeight: 168),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: color, width: 2),
          ),
          padding: const EdgeInsets.all(14),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(_crateIcon(tier), size: 44, color: color),
              const SizedBox(height: 10),
              Text(
                def.name,
                style: GoogleFonts.orbitron(
                  color: color,
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '${def.cost} UTXO',
                style: const TextStyle(
                    color: Colors.white, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                def.blurb,
                style: const TextStyle(color: Colors.white54, fontSize: 10),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCollectionTab(BuildContext context, GameLogic game) {
    final owned = game.stashService.ownedArtifacts;

    // Completion log: every artifact, ordered by rarity then name. Undiscovered
    // ones show as rarity-tinted "???" silhouettes so the collection is a
    // long-tail discovery goal (not just a list of what you happen to own).
    final all = [...StashService.allArtifacts]..sort((a, b) {
      final r = a.rarity.index.compareTo(b.rarity.index);
      return r != 0 ? r : a.name.compareTo(b.name);
    });
    final discovered = all.where((a) => (owned[a.id] ?? 0) > 0).length;
    final pct = all.isEmpty ? 0.0 : discovered / all.length;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'COLLECTION  $discovered / ${all.length}  (${(pct * 100).toStringAsFixed(0)}%)',
                style: GoogleFonts.orbitron(
                  color: AppTheme.accent,
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                  letterSpacing: 1,
                ),
              ),
              const SizedBox(height: 6),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: pct,
                  minHeight: 6,
                  backgroundColor: Colors.black45,
                  color: AppTheme.accent,
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: GridView.builder(
            padding: const EdgeInsets.all(12),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              childAspectRatio: 0.8,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
            ),
            itemCount: all.length,
            itemBuilder: (context, index) {
              final artifact = all[index];
              final count = owned[artifact.id] ?? 0;
              return count > 0
                  ? _buildArtifactCard(artifact, count)
                  : _buildLockedArtifactCard(artifact);
            },
          ),
        ),
      ],
    );
  }

  /// Rarity-tinted "???" silhouette for an undiscovered artifact.
  Widget _buildLockedArtifactCard(Artifact artifact) {
    final color = _rarityColor(artifact.rarity).withValues(alpha: 0.35);
    return Container(
      decoration: BoxDecoration(
        color: Colors.black26,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color),
      ),
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.help_outline, color: color, size: 34),
          const SizedBox(height: 10),
          const Text(
            '???',
            style: TextStyle(
              color: Colors.white38,
              fontWeight: FontWeight.bold,
              fontSize: 16,
              letterSpacing: 3,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            artifact.rarity.name.toUpperCase(),
            style: TextStyle(
              color: color,
              fontSize: 10,
              fontWeight: FontWeight.bold,
              letterSpacing: 1,
            ),
          ),
        ],
      ),
    );
  }

  // ---- SWEEP minigame (SIMULATED — in-game UTXO only) --------------------

  /// Commit the pending sweep outcome exactly once — credits the payout, advances
  /// the net cap, and evaluates achievements. Called when an animation lands, and
  /// as a safety net from dispose / app-pause (with [silent] = true, which skips
  /// the reveal feedback + notify but still credits and saves). Idempotent: it
  /// nulls the pending slot first, so a second call is a no-op.
  void _finishSweep({bool silent = false}) {
    final outcome = _pendingSweep;
    final game = _pendingGame;
    _pendingSweep = null;
    _pendingGame = null;
    if (outcome != null && game != null) {
      game.commitSweep(outcome, silent: silent);
    }
  }

  void _playSlots(GameLogic game) {
    if (_casinoBusy) return;
    // Resolve now (stake deducted, reels will show the real symbols) but DEFER the
    // commit until the reels settle, so the payout can't spoil the header early.
    final spin = game.resolveSlots(_bet);
    if (spin == null) return;
    _pendingSweep = spin;
    _pendingGame = game;

    setState(() {
      _slotSpinning = true;
      _casinoMessage = null;
      _reelSettled = [false, false, false];
    });

    // Spin the reels: each cycles random symbols, then settles left-to-right.
    const settleTick = [9, 15, 21]; // 60ms ticks -> ~0.54s / 0.9s / 1.26s
    int tick = 0;
    _spinTimer?.cancel();
    _spinTimer = Timer.periodic(const Duration(milliseconds: 60), (t) {
      if (!mounted) {
        t.cancel();
        return;
      }
      tick++;
      setState(() {
        for (int i = 0; i < 3; i++) {
          if (_reelSettled[i]) continue;
          if (tick >= settleTick[i]) {
            _reels[i] = spin.symbols[i];
            _reelSettled[i] = true;
          } else {
            _reels[i] = CasinoService
                .symbolKeys[_rng.nextInt(CasinoService.symbolKeys.length)];
          }
        }
      });
      if (_reelSettled.every((s) => s)) {
        t.cancel();
        _finishSweep(); // reels settled → NOW credit payout / cap / achievements
        setState(() {
          _slotSpinning = false;
          if (spin.isJackpot) {
            _casinoMessage = 'JACKPOT!  +${spin.net} UTXO';
            _casinoMessageColor = Colors.amberAccent;
          } else if (spin.net > 0) {
            _casinoMessage = 'SWEEP  +${spin.net} UTXO';
            _casinoMessageColor = Colors.greenAccent;
          } else if (spin.net == 0) {
            _casinoMessage = 'Push — broke even';
            _casinoMessageColor = Colors.white70;
          } else {
            // Use the staked amount from the resolved spin, not the live _bet.
            _casinoMessage = 'Junk block.  -${spin.bet} UTXO';
            _casinoMessageColor = Colors.redAccent;
          }
        });
      }
    });
  }

  static const String _hexChars = '0123456789abcdef';

  String _randomHash({int len = 8}) {
    final b = StringBuffer('0x');
    for (int i = 0; i < len; i++) {
      b.write(_hexChars[_rng.nextInt(16)]);
    }
    return b.toString();
  }

  // A hash with EXACTLY [zeros] leading zeros (the char after them is forced
  // non-zero), so the reveal visibly matches the resolved tier.
  String _hashWithLeadingZeros(int zeros, {int len = 8}) {
    final b = StringBuffer('0x');
    for (int i = 0; i < len; i++) {
      if (i < zeros) {
        b.write('0');
      } else if (i == zeros) {
        b.write(_hexChars[1 + _rng.nextInt(15)]); // first non-zero nibble
      } else {
        b.write(_hexChars[_rng.nextInt(16)]);
      }
    }
    return b.toString();
  }

  void _playFlip(GameLogic game) {
    if (_casinoBusy) return;
    // Resolve now (the hash scramble will settle on the REAL tier), but DEFER the
    // commit until the reveal — so payout / achievement / cap don't flash early.
    final result = game.resolveFlip(_bet);
    if (result == null) return;
    _pendingSweep = result;
    _pendingGame = game;

    setState(() {
      _flipHashing = true;
      _flipReveal = null;
      _casinoMessage = null;
      _flipHashText = _randomHash();
    });

    int tick = 0;
    const totalTicks = 18; // ~1s of "mining" at 55ms/tick
    _flipTimer?.cancel();
    _flipTimer = Timer.periodic(const Duration(milliseconds: 55), (t) {
      if (!mounted) {
        t.cancel();
        return;
      }
      tick++;
      if (tick < totalTicks) {
        setState(() => _flipHashText = _randomHash());
        return;
      }
      t.cancel();
      _finishSweep(); // nonce settled → NOW credit payout / cap / achievements
      setState(() {
        _flipHashing = false;
        _flipReveal = result;
        _flipHashText = _hashWithLeadingZeros(result.zeros);
        if (result.isJackpot) {
          _casinoMessage = 'BLOCK FOUND!  +${result.net} UTXO';
          _casinoMessageColor = Colors.amberAccent;
        } else if (result.net > 0) {
          final z = result.zeros;
          _casinoMessage =
              '$z leading zero${z == 1 ? '' : 's'}  ·  +${result.net} UTXO';
          _casinoMessageColor = Colors.greenAccent;
        } else {
          _casinoMessage = 'Stale share.  ${result.net} UTXO';
          _casinoMessageColor = Colors.redAccent;
        }
      });
    });
  }

  void _playPlinko(GameLogic game) {
    if (_casinoBusy) return;
    // Resolve now (stake deducted, ball will land in the REAL bucket) but DEFER
    // the commit until the ball lands — so the payout, an achievement toast, or
    // the MEMPOOL CONGESTED cap never appear before the ball settles.
    final drop = game.resolvePlinko(_bet);
    if (drop == null) return;
    _pendingSweep = drop;
    _pendingGame = game;

    setState(() {
      _plinkoDropping = true;
      _casinoMessage = null;
      _plinkoPath = drop.path;
      _plinkoLandedSlot = -1;
    });

    // Smooth cosmetic drop: the controller animates the ball down the already
    // decided path (see _PlinkoPainter); reveal the result on completion.
    _plinkoController
      ..reset()
      ..forward().whenComplete(() {
        if (!mounted) return;
        _finishSweep(); // ball landed → NOW credit payout / cap / achievements
        setState(() {
          _plinkoDropping = false;
          _plinkoLandedSlot = drop.slotIndex;
          if (drop.isJackpot) {
            _casinoMessage = 'JACKPOT!  +${drop.net} UTXO';
            _casinoMessageColor = Colors.amberAccent;
          } else if (drop.net > 0) {
            _casinoMessage = 'RELAYED  +${drop.net} UTXO';
            _casinoMessageColor = Colors.greenAccent;
          } else if (drop.net == 0) {
            _casinoMessage = 'Push — broke even';
            _casinoMessageColor = Colors.white70;
          } else {
            _casinoMessage = 'Dropped ${drop.net} UTXO';
            _casinoMessageColor = Colors.redAccent;
          }
        });
      });
  }

  static Color _plinkoSlotColor(double mult) {
    if (mult >= 10) return Colors.amberAccent; // jackpot edges
    if (mult >= 2) return Colors.cyanAccent;
    if (mult >= 1) return Colors.greenAccent;
    return Colors.white24; // <1x: a net loss bucket
  }

  Widget _buildPlinko(GameLogic game, bool canBet) {
    return _sweepCard(
      title: 'PACKET RELAY',
      children: [
        SizedBox(
          height: 240,
          width: double.infinity,
          child: CustomPaint(
            painter: _PlinkoPainter(
              path: _plinkoPath,
              progress: _plinkoController,
              landedSlot: _plinkoLandedSlot,
              dropping: _plinkoDropping,
            ),
            size: Size.infinite,
          ),
        ),
        const SizedBox(height: 14),
        _sweepControl(
          game,
          label: _plinkoDropping ? 'RELAYING…' : 'RELAY ($_bet UTXO)',
          onPressed:
              (canBet && !_casinoBusy) ? () => _playPlinko(game) : null,
        ),
      ],
    );
  }

  static const double _kGameBodyHeight = 400;

  /// A sweep is allowed when the stake is affordable AND the per-window cap has
  /// not been hit.
  bool _canSweep(GameLogic game) =>
      game.chips >= _bet && _bet > 0 && !game.casinoCapped;

  String _resetCountdown(int ms) {
    if (ms <= 0) return 'soon';
    final h = ms ~/ 3600000;
    final m = (ms % 3600000) ~/ 60000;
    return h > 0 ? '${h}h ${m}m' : '${m}m';
  }

  Widget _buildCasinoTab(BuildContext context, GameLogic game) {
    final canBet = _canSweep(game);

    // The three games share a FIXED body height so switching never jumps; clamp
    // this tab's text scaling so large accessibility fonts can't overflow that
    // fixed box (the balance/selectors above it still scroll in the ListView).
    return MediaQuery.withClampedTextScaling(
      maxScaleFactor: 1.3,
      child: ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // UTXO balance
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.token, color: Colors.cyanAccent, size: 24),
            const SizedBox(width: 8),
            Text(
              '${game.chips} UTXO',
              style: GoogleFonts.orbitron(
                fontSize: 24,
                color: Colors.cyanAccent,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        // Luck readout — Luck boosts SWEEP PAYOUTS (not the shown win %). Surfaces
        // the OG/Pool + stash luck stat so its casino effect is visible.
        Center(
          child: Text(
            game.luckMultiplier > 1.001
                ? 'LUCK ×${game.luckMultiplier.toStringAsFixed(2)}  ·  bigger payouts & jackpots'
                : 'LUCK ×1.00  ·  raise Luck to boost payouts',
            style: TextStyle(
              color: game.luckMultiplier > 1.001
                  ? Colors.amberAccent
                  : Colors.white38,
              fontSize: 11,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        const SizedBox(height: 14),

        // NOTE: the cap ("MEMPOOL CONGESTED") is surfaced IN PLACE of the play
        // button inside the fixed-height game body (see _sweepControl) — never as
        // a banner above the scroll, which would shift the scrolled content and
        // look like the screen jumping when the cap hits mid-play.

        // Stake selector (centered)
        const Center(
          child: Text('STAKE',
              style: TextStyle(
                  color: Colors.white54, fontSize: 11, letterSpacing: 1)),
        ),
        const SizedBox(height: 6),
        Wrap(
          alignment: WrapAlignment.center,
          spacing: 8,
          children: [1, 5, 10, 25, 100].map((b) {
            final selected = _bet == b;
            return ChoiceChip(
              label: Text('$b'),
              selected: selected,
              // Locked while a sweep animates so the stake can't change mid-run.
              onSelected: _casinoBusy ? null : (_) => setState(() => _bet = b),
              selectedColor: AppTheme.accent,
              labelStyle: TextStyle(
                color: selected ? Colors.black : Colors.white,
                fontWeight: FontWeight.bold,
              ),
              backgroundColor: Colors.black45,
            );
          }).toList(),
        ),
        const SizedBox(height: 14),

        // Game switcher — a single connected control (not three loose chips).
        // Tapping a segment slides the body to that game's "window" via the
        // PageView below (swipe stays disabled so the parent tab keeps it).
        Center(child: _gameSelector()),
        const SizedBox(height: 12),

        // Shared result line (fixed slot so the layout never jumps).
        SizedBox(
          height: 28,
          child: _casinoMessage == null
              ? null
              : Center(
                  child: Text(
                    _casinoMessage!,
                    style: GoogleFonts.orbitron(
                      color: _casinoMessageColor,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
        ),

        // The games — FIXED height so switching never jumps. A PageView gives the
        // "slide to another window" feel, but user swipe is DISABLED so it can't
        // fight the parent STASH TabBarView; the segmented control pages it.
        SizedBox(
          height: _kGameBodyHeight,
          child: PageView(
            controller: _gamePageController,
            physics: const NeverScrollableScrollPhysics(),
            onPageChanged: (i) => setState(() {
              _selectedGame = CasinoGame.values[i];
              _casinoMessage = null;
            }),
            children: [
              _buildSlots(game, canBet),
              _buildPlinko(game, canBet),
              _buildFlip(game, canBet),
            ],
          ),
        ),
      ],
      ),
    );
  }

  /// Shared card shell for the three SWEEP games — uniform title + centering, so
  /// each fills the same fixed body height and switching never jumps.
  Widget _sweepCard({required String title, required List<Widget> children}) {
    return StylizedCard(
      color: const Color(0xFF1E1E24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(title,
              style: GoogleFonts.orbitron(
                  color: AppTheme.accent, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          ...children,
        ],
      ),
    );
  }

  Widget _sweepButton({
    required String label,
    required VoidCallback? onPressed,
    Color color = AppTheme.accent,
  }) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          foregroundColor: Colors.black,
          padding: const EdgeInsets.symmetric(vertical: 14),
        ),
        child: Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
      ),
    );
  }

  /// The play button — OR, once the per-window cap is hit, a "MEMPOOL CONGESTED"
  /// notice IN ITS PLACE (inside the fixed-height game body). Surfacing the cap
  /// here (not as a banner above the scroll) means hitting the cap mid-play never
  /// shifts the scrolled content, so the screen can't jump.
  Widget _sweepControl(
    GameLogic game, {
    required String label,
    required VoidCallback? onPressed,
    Color color = AppTheme.accent,
  }) {
    if (game.casinoCapped) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
        decoration: BoxDecoration(
          color: Colors.orangeAccent.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.orangeAccent.withValues(alpha: 0.5)),
        ),
        child: Text(
          'MEMPOOL CONGESTED\nresets in ${_resetCountdown(game.casinoWindowResetInMs)}',
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: Colors.orangeAccent,
            fontWeight: FontWeight.bold,
            fontSize: 12,
          ),
        ),
      );
    }
    return _sweepButton(label: label, onPressed: onPressed, color: color);
  }

  /// The connected SWEEP game switcher (Material 3 SegmentedButton). Disabled
  /// mid-animation so a switch can't strand an in-flight spin/drop on a hidden
  /// game. Selecting a segment pages the body (see `_switchGame`).
  Widget _gameSelector() {
    return SegmentedButton<CasinoGame>(
      segments: const [
        ButtonSegment(
            value: CasinoGame.slots,
            label: Text('SCAN'),
            icon: Icon(Icons.grid_on, size: 16)),
        ButtonSegment(
            value: CasinoGame.plinko,
            label: Text('RELAY'),
            icon: Icon(Icons.account_tree, size: 16)),
        ButtonSegment(
            value: CasinoGame.flip,
            label: Text('FLIP'),
            icon: Icon(Icons.bolt, size: 16)),
      ],
      selected: {_selectedGame},
      showSelectedIcon: false,
      onSelectionChanged:
          _casinoBusy ? null : (sel) => _switchGame(sel.first),
      style: SegmentedButton.styleFrom(
        backgroundColor: Colors.black45,
        foregroundColor: Colors.white70,
        selectedBackgroundColor: AppTheme.accent,
        selectedForegroundColor: Colors.black,
        side: const BorderSide(color: Colors.white24),
        textStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
      ),
    );
  }

  /// Slide the body to [g]'s window. `onPageChanged` syncs `_selectedGame` and
  /// clears the shared result line once the page settles.
  void _switchGame(CasinoGame g) {
    if (g == _selectedGame) return;
    _gamePageController.animateToPage(
      g.index,
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOutCubic,
    );
  }

  Widget _buildSlots(GameLogic game, bool canBet) {
    return _sweepCard(
      title: 'BLOCK SCANNER',
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            for (int i = 0; i < 3; i++) _buildReel(_reels[i], _reelSettled[i]),
          ],
        ),
        const SizedBox(height: 14),
        _sweepControl(
          game,
          label: _slotSpinning ? 'SCANNING…' : 'SCAN ($_bet UTXO)',
          onPressed: (canBet && !_casinoBusy) ? () => _playSlots(game) : null,
        ),
        const SizedBox(height: 12),
        _buildPaytable(),
      ],
    );
  }

  Widget _buildFlip(GameLogic game, bool canBet) {
    return _sweepCard(
      title: 'HASH FLIP',
      children: [
        const Text(
          'Flip the nonce — the more leading zeros in the hash,\n'
          'the bigger the block. High risk, high reward.',
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.white54, fontSize: 12),
        ),
        const SizedBox(height: 14),
        _flipHashDisplay(),
        const SizedBox(height: 14),
        _flipPaytable(),
        const SizedBox(height: 16),
        _sweepControl(
          game,
          label: _flipHashing ? 'HASHING…' : 'FLIP ($_bet UTXO)',
          color: Colors.purpleAccent,
          onPressed: (canBet && !_casinoBusy) ? () => _playFlip(game) : null,
        ),
      ],
    );
  }

  /// The nonce/hash readout: a scrambling hex string while "mining", settling to
  /// a hash whose `_flipReveal.zeros` leading zeros glow (the tier that hit).
  Widget _flipHashDisplay() {
    final revealed = _flipReveal;
    final zeros = revealed?.zeros ?? 0;
    final body = _flipHashText.startsWith('0x')
        ? _flipHashText.substring(2)
        : _flipHashText;

    final spans = <TextSpan>[
      const TextSpan(text: '0x', style: TextStyle(color: Colors.white30)),
    ];
    for (int i = 0; i < body.length; i++) {
      final isFoundZero = revealed != null && i < zeros;
      final Color c = _flipHashing
          ? Colors.cyanAccent
          : (isFoundZero ? Colors.amberAccent : Colors.white38);
      spans.add(TextSpan(
        text: body[i],
        style: TextStyle(
          color: c,
          fontWeight: isFoundZero ? FontWeight.bold : FontWeight.normal,
        ),
      ));
    }

    final String label;
    final Color labelColor;
    if (_flipHashing) {
      label = 'HASHING NONCE…';
      labelColor = Colors.cyanAccent;
    } else if (revealed == null) {
      label = 'READY';
      labelColor = Colors.white38;
    } else if (zeros == 0) {
      label = 'NO LEADING ZERO — STALE SHARE';
      labelColor = Colors.redAccent;
    } else {
      label = '$zeros LEADING ZERO${zeros == 1 ? '' : 'S'}'
          '${revealed.isJackpot ? ' — BLOCK FOUND!' : ''}';
      labelColor = revealed.isJackpot ? Colors.amberAccent : Colors.greenAccent;
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.black38,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: labelColor.withValues(alpha: 0.4)),
      ),
      child: Column(
        children: [
          Text(label,
              style: TextStyle(
                  color: labelColor,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.5)),
          const SizedBox(height: 8),
          RichText(
            text: TextSpan(
              style: const TextStyle(
                fontFamily: 'monospace',
                fontSize: 20,
                letterSpacing: 2,
              ),
              children: spans,
            ),
          ),
        ],
      ),
    );
  }

  /// Disclosed Hash Flip odds — one row per winning tier (zeros hit, chance, pay).
  Widget _flipPaytable() {
    Color tierColor(double mult) {
      if (mult >= 30) return Colors.amberAccent; // jackpot
      if (mult >= 5) return Colors.cyanAccent;
      return Colors.greenAccent;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text('PAYTABLE',
            style: TextStyle(
                color: Colors.white38, fontSize: 10, letterSpacing: 1)),
        const SizedBox(height: 4),
        ...CasinoService.flipTable.where((o) => o.multiplier > 0).map((o) {
          final color = tierColor(o.multiplier);
          final pct = (o.weight / CasinoService.flipTotalWeight * 100)
              .toStringAsFixed(0);
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 2),
            child: Row(
              children: [
                Expanded(
                  child: Row(
                    children: [
                      Icon(Icons.filter_none, size: 14, color: color),
                      const SizedBox(width: 6),
                      Text(
                        '${o.zeros} zero${o.zeros == 1 ? '' : 's'}'
                        '${o.multiplier >= 30 ? '  · BLOCK' : ''}',
                        style: TextStyle(color: color, fontSize: 12),
                      ),
                    ],
                  ),
                ),
                Text('$pct%',
                    style:
                        const TextStyle(color: Colors.white38, fontSize: 11)),
                const SizedBox(width: 16),
                SizedBox(
                  width: 44,
                  child: Text(
                    '${o.multiplier.toStringAsFixed(0)}×',
                    textAlign: TextAlign.right,
                    style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                        fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
          );
        }),
      ],
    );
  }

  Widget _buildReel(String symbol, bool settled) {
    final color = _slotColors[symbol] ?? Colors.white;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 80),
      margin: const EdgeInsets.symmetric(horizontal: 6),
      width: 64,
      height: 64,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: Colors.black45,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: settled ? color : Colors.white24,
          width: settled ? 2 : 1,
        ),
      ),
      child: Icon(_slotIcons[symbol] ?? Icons.help_outline,
          color: settled ? color : Colors.white54, size: 34),
    );
  }

  Widget _buildPaytable() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text('PAYTABLE',
            style: TextStyle(color: Colors.white38, fontSize: 10, letterSpacing: 1)),
        const SizedBox(height: 4),
        ...CasinoService.slotTable
            .where((o) => o.multiplier > 0)
            .map((o) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Row(
                    children: [
                      Expanded(
                        child: Row(
                          children: [
                            for (final s in o.symbols)
                              Padding(
                                padding: const EdgeInsets.only(right: 3),
                                child: Icon(
                                  _slotIcons[s] ?? Icons.help_outline,
                                  size: 16,
                                  color: _slotColors[s] ?? Colors.white70,
                                ),
                              ),
                          ],
                        ),
                      ),
                      // Per-outcome probability — makes "odds disclosed" literal.
                      Text(
                        '${(o.weight / CasinoService.totalWeight * 100).toStringAsFixed(1)}%',
                        style: const TextStyle(
                            color: Colors.white38, fontSize: 11),
                      ),
                      const SizedBox(width: 16),
                      SizedBox(
                        width: 44,
                        child: Text(
                          '${o.multiplier.toStringAsFixed(o.multiplier % 1 == 0 ? 0 : 1)}×',
                          textAlign: TextAlign.right,
                          style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 12,
                              fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                )),
      ],
    );
  }

  Color _rarityColor(ArtifactRarity rarity) {
    switch (rarity) {
      case ArtifactRarity.common:
        return Colors.grey;
      case ArtifactRarity.uncommon:
        return Colors.greenAccent;
      case ArtifactRarity.rare:
        return Colors.blueAccent;
      case ArtifactRarity.epic:
        return Colors.purpleAccent;
      case ArtifactRarity.legendary:
        return Colors.amber;
      case ArtifactRarity.mythic:
        return Colors.redAccent;
    }
  }

  Widget _buildArtifactCard(Artifact artifact, int count) {
    final Color borderColor = _rarityColor(artifact.rarity);

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E24),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: borderColor),
      ),
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Icon(Icons.extension, color: borderColor, size: 20),
              Text(
                'Lvl $count',
                style: GoogleFonts.orbitron(color: Colors.white, fontSize: 12),
              ),
            ],
          ),
          const Spacer(),
          Text(
            artifact.name,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 4),
          Text(
            artifact.description,
            style: const TextStyle(color: Colors.white54, fontSize: 10),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: borderColor.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              // rigCost is a DISCOUNT (stored positive) — show it as a minus so
              // the badge matches the artifact's own "-X% Rig Cost" description.
              'Total: ${artifact.bonusType == BonusType.rigCost ? '-' : '+'}'
              '${(artifact.baseBonus * count * 100).toStringAsFixed(0)}%',
              style: TextStyle(
                color: borderColor,
                fontSize: 10,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Draws the Plinko board: a triangular peg lattice, the payout bins along the
/// bottom (coloured by multiplier, the landed one highlighted), and the ball at
/// its current row while a drop animates.
class _PlinkoPainter extends CustomPainter {
  final List<bool>? path;
  final Animation<double> progress; // 0..1 drop animation
  final int landedSlot;
  final bool dropping;

  _PlinkoPainter({
    required this.path,
    required this.progress,
    required this.landedSlot,
    required this.dropping,
  }) : super(repaint: progress); // repaint every animation frame

  @override
  void paint(Canvas canvas, Size size) {
    const rows = CasinoService.plinkoRows; // 8
    const slots = rows + 1; // 9
    final slotW = size.width / slots;
    const slotH = 34.0; // bottom bin height
    final pegAreaH = size.height - slotH;
    final rowH = pegAreaH / (rows + 1);
    final centerX = size.width / 2;
    final halfStep = slotW / 2;

    // Peg lattice (triangular Galton board).
    final pegPaint = Paint()..color = Colors.white24;
    for (int r = 1; r <= rows; r++) {
      final y = r * rowH;
      for (int j = 0; j <= r; j++) {
        canvas.drawCircle(
            Offset(centerX + (2 * j - r) * halfStep, y), 2.5, pegPaint);
      }
    }

    // Bottom payout bins.
    final mults = CasinoService.plinkoMultipliers;
    for (int i = 0; i < slots; i++) {
      final color = _StashScreenState._plinkoSlotColor(mults[i]);
      final left = i * slotW;
      final highlighted = i == landedSlot;
      final rect = Rect.fromLTWH(left + 2, pegAreaH + 2, slotW - 4, slotH - 4);
      canvas.drawRRect(
        RRect.fromRectAndRadius(rect, const Radius.circular(4)),
        Paint()..color = color.withValues(alpha: highlighted ? 0.85 : 0.22),
      );
      final tp = TextPainter(
        text: TextSpan(
          text: _fmtMult(mults[i]),
          style: TextStyle(
            color: highlighted ? Colors.black : Colors.white,
            fontSize: 10,
            fontWeight: FontWeight.bold,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout(maxWidth: slotW);
      tp.paint(
        canvas,
        Offset(left + (slotW - tp.width) / 2,
            pegAreaH + (slotH - tp.height) / 2),
      );
    }

    // The ball. Waypoints = the exact peg path from drop.path (i=0..rows), plus
    // a final settle into the resolved bin. The ball is animated smoothly along
    // them (gravity ease-in overall + a small peg-to-peg hop) so it visibly
    // threads the pegs and lands in the already-decided bin — purely cosmetic.
    if (path != null) {
      final wp = <Offset>[];
      for (int i = 0; i <= rows; i++) {
        final rights = path!.take(i).where((b) => b).length;
        wp.add(Offset(centerX + (2 * rights - i) * halfStep, i * rowH));
      }
      wp.add(Offset(wp.last.dx, pegAreaH + slotH / 2)); // settle into the bin

      Offset ball;
      if (dropping) {
        final t = Curves.easeIn.transform(progress.value.clamp(0.0, 1.0));
        final segTotal = wp.length - 1;
        final fp = t * segTotal;
        final seg = fp.floor().clamp(0, segTotal - 1);
        final u = fp - seg;
        final a = wp[seg], b = wp[seg + 1];
        final x = a.dx + (b.dx - a.dx) * Curves.easeOut.transform(u);
        final yBase = a.dy + (b.dy - a.dy) * Curves.easeInOut.transform(u);
        final hop = -rowH * 0.35 * sin(pi * u); // arc between pegs
        ball = Offset(x, yBase + hop);
      } else {
        // Resting: in the landed bin after a drop, else at the top.
        ball = landedSlot >= 0 ? wp.last : wp.first;
      }
      canvas.drawCircle(ball, 8,
          Paint()..color = AppTheme.accent.withValues(alpha: 0.3));
      canvas.drawCircle(ball, 6, Paint()..color = AppTheme.accent);
    }
  }

  static String _fmtMult(double m) =>
      '${m.toStringAsFixed(m % 1 == 0 ? 0 : 1)}x';

  @override
  bool shouldRepaint(_PlinkoPainter old) =>
      old.landedSlot != landedSlot ||
      old.dropping != dropping ||
      !identical(old.path, path);
}

