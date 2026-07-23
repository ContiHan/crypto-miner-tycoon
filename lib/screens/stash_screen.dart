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
  SlotSpin? _lastSpin;
  String? _casinoMessage;
  Color _casinoMessageColor = Colors.white70;

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

    // Trigger Purchase
    game.buyCrate(isPremium);

    // Simple Feedback Dialog
    // Ideally we would animate this, but for now a dialog works
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (ctx) {
        // Get the item that was just added (hacky: we assume it's the last updated or we could return it from buyCrate if we refactored)
        // Since buyCrate is void in provider, we can't get the specific item easily without changing signature.
        // Let's just show a "Crate Opened!" generic message or check likely items.
        // Better: Let's assume the user checks the grid. Or just show a cool animation.
        return AlertDialog(
          backgroundColor: AppTheme.surface,
          title: Text(
            "CRATE UNLOCKED",
            style: GoogleFonts.orbitron(color: AppTheme.accent),
          ),
          content: const Text(
            "You found a new Artifact! Check your Collection.",
            style: TextStyle(color: Colors.white),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text("OK", style: TextStyle(color: AppTheme.accent)),
            ),
          ],
        );
      },
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
    final spin = game.playSlots(_bet);
    if (spin == null) return;
    setState(() {
      _lastSpin = spin;
      if (spin.isJackpot) {
        _casinoMessage = '🎉 JACKPOT! +${spin.net} chips';
        _casinoMessageColor = Colors.amber;
      } else if (spin.net > 0) {
        _casinoMessage = 'WIN +${spin.net} chips';
        _casinoMessageColor = Colors.greenAccent;
      } else if (spin.net == 0) {
        _casinoMessage = 'Push — broke even';
        _casinoMessageColor = Colors.white70;
      } else {
        _casinoMessage = 'Bust. -$_bet chips';
        _casinoMessageColor = Colors.redAccent;
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
              '${game.chips} CHIPS',
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
                  children: (_lastSpin?.symbols ?? ['❔', '❔', '❔'])
                      .map((s) => Container(
                            margin: const EdgeInsets.symmetric(horizontal: 6),
                            width: 64,
                            height: 64,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: Colors.black45,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.white24),
                            ),
                            child: Text(s, style: const TextStyle(fontSize: 34)),
                          ))
                      .toList(),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: canBet ? () => _playSlots(game) : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.accent,
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    child: Text('SPIN ($_bet chips)',
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
                  padding: const EdgeInsets.symmetric(vertical: 1),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(o.symbols.join(' '),
                            style: const TextStyle(fontSize: 13)),
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
