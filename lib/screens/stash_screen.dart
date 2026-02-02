import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../providers/game_logic.dart';
import '../services/stash_service.dart';
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

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
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
          tabs: const [
            Tab(icon: Icon(Icons.inventory_2), text: "CRATES & TRADING"),
            Tab(icon: Icon(Icons.grid_view), text: "COLLECTION"),
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

    if (owned.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.widgets_outlined, size: 64, color: Colors.white24),
            SizedBox(height: 16),
            Text("No Artifacts Yet", style: TextStyle(color: Colors.white54)),
          ],
        ),
      );
    }

    return GridView.builder(
      padding: const EdgeInsets.all(12),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 0.8,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
      ),
      itemCount: owned.length,
      itemBuilder: (context, index) {
        String id = owned.keys.elementAt(index);
        int count = owned.values.elementAt(index);
        // We need a helper to get Artifact details.
        // Since StashService.allArtifacts is static public, we can access it.
        // But looking it up is O(N).
        final artifact = StashService.allArtifacts.firstWhere(
          (a) => a.id == id,
          orElse: () => StashService.allArtifacts.first,
        );

        return _buildArtifactCard(artifact, count);
      },
    );
  }

  Widget _buildArtifactCard(Artifact artifact, int count) {
    Color borderColor = Colors.grey;
    if (artifact.rarity == ArtifactRarity.rare) borderColor = Colors.blueAccent;
    if (artifact.rarity == ArtifactRarity.legendary) borderColor = Colors.amber;
    if (artifact.rarity == ArtifactRarity.unique)
      borderColor = Colors.purpleAccent;

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
