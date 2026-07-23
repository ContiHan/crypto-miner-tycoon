import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../core/constants.dart';
import '../providers/game_logic.dart';
import '../services/stash_service.dart';
import '../services/casino_service.dart';
import '../theme/app_theme.dart';
import '../utils/formatter.dart';
import '../widgets/stylized_card.dart';
import '../widgets/pulse_button.dart';

class StashScreen extends StatefulWidget {
  const StashScreen({super.key});

  @override
  State<StashScreen> createState() => _StashScreenState();
}

class _StashScreenState extends State<StashScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _isErrorShowing = false;

  // Casino local UI state.
  int _bet = 5;
  String? _casinoMessage;
  Color _casinoMessageColor = Colors.white70;

  // Slot reel animation state.
  final Random _rng = Random();
  bool _slotSpinning = false;
  final List<String> _reels = ['coin', 'rocket', 'diamond'];
  List<bool> _reelSettled = [true, true, true];
  Timer? _spinTimer;
  int? _chipOverride; // shown while spinning so the header can't spoil the win

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
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    // The screen is rebuilt on every bottom-nav switch, so a missing dispose
    // leaked a TabController (and its ticker) per visit and could assert in
    // debug when leaving mid tab-animation.
    _tabController.dispose();
    _spinTimer?.cancel();
    super.dispose();
  }

  void _showCrateOpening(BuildContext context, bool isPremium, GameLogic game) {
    // Logic is handled in game.buyCrate, here we just trigger it and show feedback
    if ((isPremium && game.chips < 50) || (!isPremium && game.chips < 10)) {
      if (_isErrorShowing) return;
      _isErrorShowing = true;
      ScaffoldMessenger.of(context)
          .showSnackBar(
            const SnackBar(
              content: Text('Not enough Chips!'),
              backgroundColor: Colors.red,
            ),
          )
          .closed
          .then((_) => _isErrorShowing = false);
      return;
    }

    // Open the crate and reveal exactly what dropped.
    final won = game.buyCrate(isPremium);
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
        title: Text(
          'STASH & BLACK MARKET',
          style: GoogleFonts.orbitron(fontWeight: FontWeight.bold),
        ),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppTheme.accent,
          labelColor: AppTheme.accent,
          unselectedLabelColor: Colors.white54,
          isScrollable: true,
          tabs: const [
            Tab(icon: Icon(Icons.inventory_2), text: "CRATES"),
            Tab(icon: Icon(Icons.grid_view), text: "COLLECTION"),
            Tab(icon: Icon(Icons.casino), text: "CASINO"),
          ],
        ),
      ),
      body: Consumer<GameLogic>(
        builder: (context, game, child) {
          return TabBarView(
            controller: _tabController,
            children: [
              _buildMarketTab(context, game),
              _buildCollectionTab(context, game),
              _buildCasinoTab(context, game),
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
                    'MICRO-CHIPS OBTAINED',
                    style: TextStyle(
                      color: Colors.white54,
                      fontSize: 10,
                      letterSpacing: 1,
                    ),
                  ),
                  Row(
                    children: [
                      const Icon(
                        Icons.memory,
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
          'BLACK MARKET EXCHANGE',
          style: TextStyle(
            color: AppTheme.accent,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.5,
          ),
        ),
        const SizedBox(height: 8),
        StylizedCard(
          color: const Color(0xFF1E1E24),
          child: ListTile(
            leading: const Icon(
              Icons.currency_exchange,
              color: Colors.purpleAccent,
              size: 32,
            ),
            title: const Text(
              'Buy 1 Micro-Chip',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
            subtitle: const Text(
              'Cost: 5,000 Gov Tokens',
              style: TextStyle(color: Colors.white54),
            ),
            trailing: PulseButton(
              animate: false,
              onPressed: game.govTokens >= 5000
                  ? () => game.buyChipsWithTokens()
                  : null,
              child: const Text('EXCHANGE'),
            ),
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

        Row(
          children: [
            Expanded(
              child: _buildCrateCard(
                context,
                "STANDARD",
                10,
                Colors.blueGrey,
                () => _showCrateOpening(context, false, game),
                "Common items, chance for Rare.",
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildCrateCard(
                context,
                "PREMIUM",
                50,
                Colors.amber,
                () => _showCrateOpening(context, true, game),
                "Guaranteed Rare+, high Legendary chance.",
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildCrateCard(
    BuildContext context,
    String title,
    int cost,
    Color color,
    VoidCallback onTap,
    String desc,
  ) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 180,
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color, width: 2),
        ),
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.inventory_2_outlined, size: 48, color: color),
            const SizedBox(height: 12),
            Text(
              title,
              style: GoogleFonts.orbitron(
                color: color,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '$cost CHIPS',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              desc,
              style: const TextStyle(color: Colors.white54, fontSize: 10),
              textAlign: TextAlign.center,
            ),
          ],
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

  // ---- Casino (SIMULATED — in-game Micro-Chips only) ----------------------

  void _playSlots(GameLogic game) {
    if (_slotSpinning) return;
    final spin = game.playSlots(_bet); // resolves the outcome up front
    if (spin == null) return;

    setState(() {
      _slotSpinning = true;
      _casinoMessage = null;
      _reelSettled = [false, false, false];
      // Show the bet as already deducted, but hide the payout until reels settle
      // (otherwise the balance header spoils the win/loss).
      _chipOverride = game.chips - spin.payout;
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
        setState(() {
          _slotSpinning = false;
          _chipOverride = null; // reveal the real balance now
          if (spin.isJackpot) {
            _casinoMessage = 'JACKPOT!  +${spin.net} chips';
            _casinoMessageColor = Colors.amberAccent;
          } else if (spin.net > 0) {
            _casinoMessage = 'WIN  +${spin.net} chips';
            _casinoMessageColor = Colors.greenAccent;
          } else if (spin.net == 0) {
            _casinoMessage = 'Push — broke even';
            _casinoMessageColor = Colors.white70;
          } else {
            _casinoMessage = 'Bust.  -$_bet chips';
            _casinoMessageColor = Colors.redAccent;
          }
        });
      }
    });
  }

  void _playFlip(GameLogic game) {
    final win = game.playDoubleOrNothing(_bet);
    if (win == null) return;
    setState(() {
      _casinoMessage = win ? 'DOUBLED! +$_bet chips' : 'Nothing. -$_bet chips';
      _casinoMessageColor = win ? Colors.greenAccent : Colors.redAccent;
    });
  }

  Widget _buildCasinoTab(BuildContext context, GameLogic game) {
    final canBet = game.chips >= _bet && _bet > 0;
    final rtp = (CasinoService.slotsReturnToPlayer * 100).toStringAsFixed(0);
    final flipPct =
        (GameConstants.casinoFlipWinChance * 100).toStringAsFixed(0);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Compliance disclosure — required for simulated gambling content.
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.redAccent.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.redAccent.withValues(alpha: 0.4)),
          ),
          child: const Text(
            '🎰 SIMULATED — For entertainment only. Micro-Chips are in-game '
            'tokens with NO real-world value. No real money, deposits, or prizes.',
            style: TextStyle(color: Colors.white70, fontSize: 11),
          ),
        ),
        const SizedBox(height: 16),

        // Chip balance
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.memory, color: Colors.cyanAccent, size: 26),
            const SizedBox(width: 8),
            Text(
              '${_chipOverride ?? game.chips} CHIPS',
              style: GoogleFonts.orbitron(
                fontSize: 24,
                color: Colors.cyanAccent,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),

        // Bet selector
        const Text('BET', style: TextStyle(color: Colors.white54, fontSize: 11, letterSpacing: 1)),
        const SizedBox(height: 6),
        Wrap(
          spacing: 8,
          children: [1, 5, 10, 25, 100].map((b) {
            final selected = _bet == b;
            return ChoiceChip(
              label: Text('$b'),
              selected: selected,
              onSelected: (_) => setState(() => _bet = b),
              selectedColor: AppTheme.accent,
              labelStyle: TextStyle(
                color: selected ? Colors.black : Colors.white,
                fontWeight: FontWeight.bold,
              ),
              backgroundColor: Colors.black45,
            );
          }).toList(),
        ),
        const SizedBox(height: 16),

        // Result message
        if (_casinoMessage != null)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 10),
            alignment: Alignment.center,
            child: Text(
              _casinoMessage!,
              style: GoogleFonts.orbitron(
                color: _casinoMessageColor,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),

        // Slots
        StylizedCard(
          color: const Color(0xFF1E1E24),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Text('CRYPTO SLOTS',
                    style: GoogleFonts.orbitron(
                        color: AppTheme.accent, fontWeight: FontWeight.bold)),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    for (int i = 0; i < 3; i++) _buildReel(_reels[i], _reelSettled[i]),
                  ],
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: (canBet && !_slotSpinning)
                        ? () => _playSlots(game)
                        : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.accent,
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    child: Text(_slotSpinning ? 'SPINNING…' : 'SPIN ($_bet chips)',
                        style: const TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ),
                const SizedBox(height: 10),
                _buildPaytable(rtp),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),

        // Double or Nothing
        StylizedCard(
          color: const Color(0xFF1E1E24),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Text('DOUBLE OR NOTHING',
                    style: GoogleFonts.orbitron(
                        color: AppTheme.accent, fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                Text('$flipPct% chance to win 2×  •  odds disclosed',
                    style: const TextStyle(color: Colors.white54, fontSize: 11)),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: canBet ? () => _playFlip(game) : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.purpleAccent,
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    child: Text('FLIP ($_bet chips)',
                        style: const TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          ),
        ),
        if (!canBet)
          const Padding(
            padding: EdgeInsets.only(top: 12),
            child: Text(
              'Not enough chips for this bet. Earn chips from anomalies or the Black Market.',
              style: TextStyle(color: Colors.redAccent, fontSize: 12),
              textAlign: TextAlign.center,
            ),
          ),
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

  Widget _buildPaytable(String rtp) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('PAYTABLE (odds disclosed)',
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
        const SizedBox(height: 4),
        Text('Average return ~$rtp% • house edge (a chip sink for fun).',
            style: const TextStyle(color: Colors.white38, fontSize: 10)),
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
              'Total: +${(artifact.baseBonus * count * 100).toStringAsFixed(0)}%',
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
