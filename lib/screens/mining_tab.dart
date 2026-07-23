import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'dart:math';
import '../providers/game_logic.dart';
import '../theme/app_theme.dart';
import '../utils/formatter.dart';
import '../widgets/stylized_card.dart';
import '../widgets/rig_list_item.dart';
import '../widgets/pulse_button.dart';
import '../widgets/floating_text.dart';
import '../widgets/binary_particle.dart';
import '../widgets/animated_count_text.dart';

class MiningTab extends StatefulWidget {
  final VoidCallback
  onHardFork; // Callback to trigger hard fork dialog from parent or here
  final Function(String) onBuyRig; // Callback for buying rig visual feedback
  // Tier-3 prestige (New Blockchain). Optional so widget tests can omit it; the
  // button only renders when a New Blockchain is actually available.
  final VoidCallback? onNewBlockchain;

  const MiningTab({
    super.key,
    required this.onHardFork,
    required this.onBuyRig,
    this.onNewBlockchain,
  });

  @override
  State<MiningTab> createState() => _MiningTabState();
}

class _MiningTabState extends State<MiningTab> with TickerProviderStateMixin {
  final List<Widget> _floatingTexts = [];
  late AnimationController _buttonScaleController;
  late Animation<double> _buttonScaleAnimation;
  // Decaying horizontal shake, kicked on a critical tap for extra impact.
  late AnimationController _shakeController;

  @override
  void initState() {
    super.initState();
    _buttonScaleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 100), // Fast press
    );
    _buttonScaleAnimation = Tween<double>(begin: 1.0, end: 0.95).animate(
      CurvedAnimation(parent: _buttonScaleController, curve: Curves.easeInOut),
    );
    _shakeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
  }

  @override
  void dispose() {
    _buttonScaleController.dispose();
    _shakeController.dispose();
    super.dispose();
  }

  /// Wraps [child] in a decaying left/right shake driven by [_shakeController].
  Widget _withShake(Widget child) {
    return AnimatedBuilder(
      animation: _shakeController,
      builder: (context, c) {
        final t = _shakeController.value;
        // No offset at rest; a few fast oscillations that damp to zero.
        final dx = t == 0.0 ? 0.0 : sin(t * pi * 8) * 10.0 * (1.0 - t);
        return Transform.translate(offset: Offset(dx, 0), child: c);
      },
      child: child,
    );
  }

  void spawnBinaryExplosion(Offset position) {
    if (!mounted) return;

    // Spawn fewer but bigger particles (3-5)
    final random = Random();
    int count = 3 + random.nextInt(3);

    for (int i = 0; i < count; i++) {
      final key = UniqueKey();

      // Random direction, biased towards sides
      // dx: -6 to -2 (Left) OR 2 to 6 (Right)
      bool goLeft = random.nextBool();
      double dx = goLeft
          ? (random.nextDouble() * -4) - 2
          : (random.nextDouble() * 4) + 2;

      double dy = (random.nextDouble() * -3) - 2; // Upwards (-2 to -5)

      Offset endOffset = Offset(dx, dy);
      String text = '₿'; // BTC Symbol

      setState(() {
        _floatingTexts.add(
          Positioned(
            key: key,
            top: position.dy - 20,
            left: position.dx,
            child: BinaryParticle(
              // Reusing widget but with BTC style
              text: text,
              endOffset: endOffset,
              color: Colors.amber,
              onComplete: () {
                if (mounted) {
                  setState(() {
                    _floatingTexts.removeWhere((w) => w.key == key);
                  });
                }
              },
            ),
          ),
        );
      });
    }
  }

  void addFloatingText([
    String? textOverride,
    Offset? position,
    Color? color,
    double fontSize = 24,
  ]) {
    final key = UniqueKey();
    final text = textOverride ?? '+${Formatter.formatBitcoin(1.0)}';

    // Default position
    double bottom = position == null
        ? 80 + (Random().nextInt(40).toDouble())
        : 0;
    double right = position == null
        ? 20 + (Random().nextInt(40).toDouble())
        : 0;

    setState(() {
      _floatingTexts.add(
        Positioned(
          key: key,
          top: position?.dy != null ? position!.dy - 40 : null,
          left: position?.dx != null ? position!.dx : null,
          bottom: position == null ? bottom : null,
          right: position == null ? right : null,
          child: FloatingText(
            text: text,
            color: color,
            fontSize: fontSize,
            onComplete: () {
              if (mounted) {
                setState(() {
                  _floatingTexts.removeWhere((w) => w.key == key);
                });
              }
            },
          ),
        ),
      );
    });
  }

  Widget _buildStatItem(String label, String value, Color valueColor) {
    return Column(
      children: [
        Text(
          label,
          style: const TextStyle(
            color: Colors.white38,
            fontSize: 10,
            fontWeight: FontWeight.bold,
            letterSpacing: 1,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: GoogleFonts.orbitron(
            color: valueColor,
            fontSize: 16, // Larger font
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<GameLogic>(
      builder: (context, game, child) {
        return LayoutBuilder(
          builder: (context, constraints) {
            // Feed the anomaly spawner the real tab size so anomalies never
            // spawn off-screen (landscape/small screens) or cluster in a corner.
            if (constraints.maxWidth.isFinite && constraints.maxHeight.isFinite) {
              game.setAnomalyViewport(
                constraints.maxWidth,
                constraints.maxHeight,
              );
            }
            return _withShake(Stack(
              children: [
            Column(
              children: [
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.all(8),
                    children: [
                      // Stats Panel
                      StylizedCard(
                        color: AppTheme.surface,
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          child: Column(
                            children: [
                              const Text(
                                'WALLET BALANCE',
                                style: TextStyle(
                                  color: AppTheme.textSecondary,
                                  letterSpacing: 2,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                ),
                              ),
                              GestureDetector(
                                onTap: () {
                                  game.toggleFiatDisplay();
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        game.showFiatPrices
                                            ? 'Display: Astronomical (Fiat)'
                                            : 'Display: Bitcoin (Sats)',
                                      ),
                                      duration: const Duration(
                                        milliseconds: 500,
                                      ),
                                      backgroundColor: AppTheme.accent,
                                    ),
                                  );
                                },
                                child: AnimatedCountText(
                                  // Keyed on the display mode so a fiat/sats
                                  // toggle remounts instead of tweening across
                                  // the two incomparable number scales.
                                  key: ValueKey(game.showFiatPrices),
                                  value: game.showFiatPrices
                                      ? game.toFiat(game.wallet)
                                      : game.wallet,
                                  formatter: game.showFiatPrices
                                      ? (v) => '\$ ${Formatter.formatNumber(v)}'
                                      : (v) => Formatter.formatBitcoin(v),
                                  style: const TextStyle(
                                    fontSize: 36,
                                    fontWeight: FontWeight.w900,
                                    color: AppTheme.accent,
                                    letterSpacing: 1.5,
                                  ),
                                ),
                              ),
                              const Divider(
                                color: Colors.black54,
                                thickness: 2,
                                height: 20,
                              ),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Icon(
                                    Icons.flash_on,
                                    color: Colors.amber,
                                    size: 20,
                                  ),
                                  const SizedBox(width: 5),
                                  Text(
                                    '${Formatter.formatNumber(game.globalHashRate)} H/s',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 18,
                                    ),
                                  ),
                                ],
                              ),
                              // ECONOMY 2.0 STATS
                              const SizedBox(height: 16),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 8,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.black45,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: Colors.white12,
                                    width: 1.5,
                                  ),
                                ),
                                child: Column(
                                  children: [
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceEvenly,
                                      children: [
                                        _buildStatItem(
                                          'DIFFICULTY',
                                          Formatter.formatNumber(
                                            game.networkDifficulty,
                                          ),
                                          Colors.white70,
                                        ),
                                        Container(
                                          width: 1,
                                          height: 30,
                                          color: Colors.white24,
                                        ),
                                        _buildStatItem(
                                          'REWARD',
                                          Formatter.formatBitcoin(
                                            game.blockReward,
                                          ),
                                          Colors.amber,
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 8),
                                    // Halving Progress
                                    Stack(
                                      alignment: Alignment.center,
                                      children: [
                                        ClipRRect(
                                          borderRadius: BorderRadius.circular(
                                            4,
                                          ),
                                          child: LinearProgressIndicator(
                                            value: game.halvingProgress,
                                            backgroundColor: Colors.black54,
                                            color: Colors.purpleAccent
                                                .withValues(alpha: 0.5),
                                            minHeight: 14,
                                          ),
                                        ),
                                        Text(
                                          'HALVING: ${(game.halvingProgress * 100).toStringAsFixed(1)}%',
                                          style: GoogleFonts.orbitron(
                                            color: Colors.white,
                                            fontSize: 10,
                                            fontWeight: FontWeight.bold,
                                            shadows: [
                                              const Shadow(
                                                color: Colors.black,
                                                blurRadius: 2,
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 10),
                              if (game.consensus > 0)
                                Text(
                                  'CONSENSUS: ${Formatter.formatNumber(game.consensus.toDouble())} (+${(game.consensusBonus * 100).toStringAsFixed(0)}% income)',
                                  style: const TextStyle(
                                    color: Colors.cyanAccent,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                  ),
                                ),
                              if (game.pendingConsensus > 0)
                                Padding(
                                  padding: const EdgeInsets.only(top: 8.0),
                                  child: ElevatedButton(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.cyan,
                                      foregroundColor: Colors.black,
                                    ),
                                    onPressed: () {
                                      game.softFork();
                                      ScaffoldMessenger.of(
                                        context,
                                      ).showSnackBar(
                                        const SnackBar(
                                          content: Text(
                                            'Soft Fork! LAB reset, Consensus banked.',
                                          ),
                                          duration: Duration(milliseconds: 800),
                                          backgroundColor: Colors.cyan,
                                        ),
                                      );
                                    },
                                    child: Text(
                                      'SOFT FORK (+${game.pendingConsensus} Consensus)',
                                    ),
                                  ),
                                ),
                              const SizedBox(height: 6),
                              if (game.govTokens > 0)
                                Text(
                                  'GOV TOKENS: ${Formatter.formatNumber(game.govTokens.toDouble())} (x${game.prestigeMultiplier.toStringAsFixed(1)})',
                                  style: const TextStyle(
                                    color: AppTheme.accent,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                  ),
                                ),
                              if (game.pendingGovTokens > 0)
                                Padding(
                                  padding: const EdgeInsets.only(top: 8.0),
                                  child: PulseButton(
                                    animate: true,
                                    onPressed: widget.onHardFork,
                                    child: Text(
                                      'HARD FORK (+${Formatter.formatNumber(game.pendingGovTokens.toDouble())} Tokens)',
                                    ),
                                  ),
                                ),
                              // Tier-3: New Blockchain / Genesis Blocks.
                              if (game.genesisBlocks > 0)
                                Padding(
                                  padding: const EdgeInsets.only(top: 6.0),
                                  child: Text(
                                    'GENESIS BLOCKS: ${Formatter.formatNumber(game.genesisBlocks.toDouble())} '
                                    '(x${game.genesisGainMultiplier.toStringAsFixed(1)} CX/GT gain)',
                                    style: const TextStyle(
                                      color: Colors.deepPurpleAccent,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13,
                                    ),
                                  ),
                                ),
                              if (game.pendingGenesis > 0 &&
                                  widget.onNewBlockchain != null)
                                Padding(
                                  padding: const EdgeInsets.only(top: 8.0),
                                  child: ElevatedButton(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.deepPurple,
                                      foregroundColor: Colors.white,
                                    ),
                                    onPressed: widget.onNewBlockchain,
                                    child: Text(
                                      'NEW BLOCKCHAIN (+${game.pendingGenesis} Genesis)',
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      ...game.visibleRigs.map(
                        (rig) => RigListItem(
                          rig: rig,
                          game: game,
                          onBuy: (pos) {
                            // [pos] is a GLOBAL coordinate; convert to this
                            // Stack's local space (mirrors the HACK handler) so
                            // the deduction glyph appears on the button, not
                            // ~100px below it.
                            final box = context.findRenderObject();
                            final local = box is RenderBox
                                ? box.globalToLocal(pos)
                                : pos;
                            addFloatingText(
                              game.showFiatPrices ? '-\$' : '-Ş',
                              local,
                            );
                          },
                        ),
                      ),
                      if (game.nextLockedRig != null)
                        _LockedRigTeaser(
                          threshold: game.unlockThresholdFor(
                            game.nextLockedRig!.id,
                          ),
                          showFiat: game.showFiatPrices,
                          toFiat: game.toFiat,
                        ),
                    ],
                  ),
                ),
                // Wide Action Button (Bottom Sticky)
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: GestureDetector(
                    onTapDown: (_) => _buttonScaleController.forward(),
                    onTapUp: (details) {
                      _buttonScaleController.reverse();

                      final game = Provider.of<GameLogic>(
                        context,
                        listen: false,
                      );
                      final result = game.clickMine();

                      RenderBox box = context.findRenderObject() as RenderBox;
                      Offset localPos = box.globalToLocal(
                        details.globalPosition,
                      );

                      // Show the real sats gained (fiat/sats aware), with a gold
                      // "CRIT!" + screen shake on a critical tap.
                      final gained = game.showFiatPrices
                          ? '+\$${Formatter.formatNumber(game.toFiat(result.sats))}'
                          : '+${Formatter.formatBitcoin(result.sats)}';
                      if (result.isCrit) {
                        addFloatingText(
                          'CRIT! $gained',
                          localPos,
                          Colors.amberAccent,
                          30,
                        );
                        _shakeController.forward(from: 0);
                      } else {
                        addFloatingText(gained, localPos);
                      }
                      spawnBinaryExplosion(localPos);
                    },
                    onTapCancel: () => _buttonScaleController.reverse(),
                    child: ScaleTransition(
                      scale: _buttonScaleAnimation,
                      child: Container(
                        width: double.infinity,
                        height: 60,
                        decoration: BoxDecoration(
                          color: AppTheme.accent,
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(color: Colors.black, width: 2),
                          boxShadow: const [
                            BoxShadow(
                              color: Colors.black45,
                              offset: Offset(0, 4),
                              blurRadius: 4,
                            ),
                          ],
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.terminal,
                                  size: 24,
                                  color: Colors.black,
                                ),
                                SizedBox(width: 8),
                                Text(
                                  'HACK NETWORK',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 2,
                                    color: Colors.black,
                                  ),
                                ),
                              ],
                            ),
                            Consumer<GameLogic>(
                              builder: (context, game, _) {
                                final estClick = game.showFiatPrices
                                    ? '\$ ${Formatter.formatNumber(game.toFiat(game.estimatedClickValue))}'
                                    : Formatter.formatBitcoin(
                                        game.estimatedClickValue,
                                      );
                                return Text(
                                  'EST. CLICK: $estClick',
                                  style: const TextStyle(
                                    fontSize: 10,
                                    color: Colors.black87,
                                  ),
                                );
                              },
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            ..._floatingTexts,

            // Anomaly Widget
            if (game.isAnomalyActive)
              Positioned(
                left: game.anomalyPosition.dx,
                top: game.anomalyPosition.dy,
                child: GestureDetector(
                  onTap: () {
                    game.clickAnomaly();
                    spawnBinaryExplosion(game.anomalyPosition); // Reuse visuals
                    addFloatingText('+1 CHIP', game.anomalyPosition);
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    width: 50,
                    height: 50,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.redAccent,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.red,
                          blurRadius: 10,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.bug_report,
                      color: Colors.white,
                      size: 30,
                    ),
                  ),
                ),
              ),
              ],
            ));
          },
        );
      },
    );
  }
}

/// Greyed "???" teaser for the next still-locked rig (progressive discovery).

class _LockedRigTeaser extends StatelessWidget {
  final double threshold;

  final bool showFiat;

  final double Function(double) toFiat;

  const _LockedRigTeaser({
    required this.threshold,

    required this.showFiat,

    required this.toFiat,
  });

  @override
  Widget build(BuildContext context) {
    final hint = showFiat
        ? '\$ ${Formatter.formatNumber(toFiat(threshold))}'
        : Formatter.formatBitcoin(threshold);

    return StylizedCard(
      color: Colors.black26,

      child: Padding(
        padding: const EdgeInsets.all(8.0),

        child: Row(
          children: [
            Container(
              width: 50,

              height: 50,

              decoration: BoxDecoration(
                color: Colors.white10,

                border: Border.all(color: Colors.white24),

                borderRadius: BorderRadius.circular(4),
              ),

              child: const Icon(
                Icons.lock_outline,
                color: Colors.white38,
                size: 28,
              ),
            ),

            const SizedBox(width: 12),

            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,

                children: [
                  const Text(
                    '???',

                    style: TextStyle(
                      color: Colors.white54,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      letterSpacing: 2,
                    ),
                  ),

                  const SizedBox(height: 4),

                  Text(
                    'Unlocks at $hint mined',

                    style: const TextStyle(color: Colors.white38, fontSize: 12),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
