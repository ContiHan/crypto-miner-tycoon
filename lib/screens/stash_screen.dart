import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../providers/game_logic.dart';
import '../services/stash_service.dart';
import '../theme/app_theme.dart';
import '../utils/formatter.dart';
import '../widgets/firmware_panel.dart';
import 'casino_tab.dart';

class StashScreen extends StatefulWidget {
  const StashScreen({super.key});

  @override
  State<StashScreen> createState() => _StashScreenState();
}

class _StashScreenState extends State<StashScreen>
    with TickerProviderStateMixin {
  late TabController _tabController;
  bool _isErrorShowing = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    // The screen is rebuilt on every bottom-nav switch, so a missing dispose
    // leaked a TabController (and its ticker) per visit and could assert in
    // debug when leaving mid tab-animation.
    _tabController.dispose();
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
              CasinoTab(game: game),
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
