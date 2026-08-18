import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/game_logic.dart';
import '../models/research_node.dart';
import '../logic/systems/keystone_system.dart';
import '../theme/app_theme.dart';
import '../utils/formatter.dart';
import '../widgets/graph_node_sheet.dart';
import '../widgets/tech_preset_bar.dart';

/// TECH V2 — "The Three Engines". The tab is an accordion in two sections:
/// RESEARCH BRANCHES (three self-contained 2-lane trees) and KEYSTONES & SYNERGIES.
/// A single Research-Point budget bounds how many nodes you can own per fork.
/// See docs/TECH_TREE_REDESIGN_V2.md.
class ResearchTab extends StatefulWidget {
  const ResearchTab({super.key});

  @override
  State<ResearchTab> createState() => _ResearchTabState();
}

class _ResearchTabState extends State<ResearchTab> {
  // Which accordion card is open ('A'/'B'/'C' branches, 'KS', 'SYN', or null).
  String _open = 'A';

  // (branch, name, fantasy, tint)
  static const List<(String, String, String, Color)> _branches = [
    ('A', 'THE FOUNDRY', 'hash + income', Color(0xFFFFB400)),
    ('B', 'THE GOLDEN NONCE', 'click + crit', Color(0xFF22D3EE)),
    ('C', 'THE DEGEN', 'luck + loot + chaos', Color(0xFFB98BFF)),
  ];

  // Signature synergies (name, description, required node ids).
  static const List<(String, String, List<String>)> _synergies = [
    ('Crit Cascade', 'crit chance → payout → guaranteed golden nonce fuels procs',
        ['nonce_prediction', 'precision_hashing', 'golden_nonce_protocol']),
    ('Compound Interest', 'reinvestment turns your hash bonus into income',
        ['reinvestment_engine']),
    ('Double or Nothing', 'luck → drop quality → a SECOND crate every open',
        ['assay_lab', 'double_drop_manifold']),
    ('Chaos Surfer', 'more (positive-tilted) events, backed by resists',
        ['volatility_engine', 'hardened_vault']),
    ('Overclock Burst', 'haste + overcharge make abilities fire oftener & harder',
        ['immersion_cooling', 'power_capacitors']),
  ];

  @override
  Widget build(BuildContext context) {
    return Consumer<GameLogic>(
      builder: (context, game, _) {
        return Column(
          children: [
            _header(context, game),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(12, 4, 12, 40),
                children: [
                  _sectionHeader('RESEARCH BRANCHES'),
                  for (final b in _branches) _branchCard(context, game, b),
                  const SizedBox(height: 8),
                  _sectionHeader('KEYSTONES & SYNERGIES'),
                  _keystonesCard(context, game),
                  _synergiesCard(game),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  // ---- header: balance + RP budget + preset/respec ----
  Widget _header(BuildContext context, GameLogic game) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
      color: AppTheme.surface,
      width: double.infinity,
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.account_tree, size: 22, color: AppTheme.accent),
              const SizedBox(width: 8),
              const Text('TECH · RESEARCH',
                  style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.accent,
                      letterSpacing: 2)),
              const Spacer(),
              _rpMeter(game),
            ],
          ),
          const SizedBox(height: 8),
          GestureDetector(
            onTap: () => game.toggleFiatDisplay(),
            child: Text(
              'BALANCE: ${game.showFiatPrices ? '\$ ${Formatter.formatNumber(game.toFiat(game.wallet))}' : Formatter.formatBitcoin(game.wallet)}',
              style: const TextStyle(
                  fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white),
            ),
          ),
          const SizedBox(height: 8),
          TechPresetBar(game: game),
          RespecBar(game: game),
        ],
      ),
    );
  }

  Widget _rpMeter(GameLogic game) {
    final spent = game.rpSpent, cap = game.rpBudget;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text('RP ',
            style: TextStyle(
                color: AppTheme.textSecondary,
                fontSize: 11,
                letterSpacing: 1)),
        Text('$spent',
            style: const TextStyle(
                color: AppTheme.accent,
                fontWeight: FontWeight.bold,
                fontSize: 14)),
        Text(' / $cap',
            style:
                TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
      ],
    );
  }

  Widget _sectionHeader(String label) => Padding(
        padding: const EdgeInsets.fromLTRB(4, 14, 4, 8),
        child: Row(children: [
          Text(label,
              style: TextStyle(
                  color: AppTheme.textSecondary,
                  fontSize: 10.5,
                  letterSpacing: 2,
                  fontWeight: FontWeight.bold)),
          const SizedBox(width: 10),
          Expanded(child: Container(height: 1, color: Colors.white12)),
        ]),
      );

  // ---- generic accordion card shell ----
  Widget _card({
    required String id,
    required Color tint,
    required Widget headRight,
    required String title,
    String? subtitle,
    required Widget body,
  }) {
    final open = _open == id;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
            color: open
                ? tint.withValues(alpha: 0.55)
                : Colors.white.withValues(alpha: 0.06)),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          InkWell(
            onTap: () => setState(() => _open = open ? '' : id),
            child: Container(
              padding: const EdgeInsets.fromLTRB(13, 13, 15, 13),
              child: Row(
                children: [
                  Container(width: 3, height: 30, color: tint),
                  const SizedBox(width: 11),
                  AnimatedRotation(
                    turns: open ? 0.25 : 0,
                    duration: const Duration(milliseconds: 180),
                    child: Icon(Icons.chevron_right, size: 18, color: tint),
                  ),
                  const SizedBox(width: 6),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title,
                          style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14.5,
                              letterSpacing: 0.5,
                              color: Colors.white)),
                      if (subtitle != null)
                        Text(subtitle,
                            style: TextStyle(
                                color: AppTheme.textSecondary,
                                fontSize: 11,
                                fontStyle: FontStyle.italic)),
                    ],
                  ),
                  const Spacer(),
                  headRight,
                ],
              ),
            ),
          ),
          if (open)
            Container(
              width: double.infinity,
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: const Alignment(0, -1.1),
                  radius: 1.3,
                  colors: [tint.withValues(alpha: 0.07), Colors.transparent],
                ),
                border: Border(top: BorderSide(color: Colors.white12)),
              ),
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 16),
              child: body,
            ),
        ],
      ),
    );
  }

  // ---- a research branch (2-lane tree) ----
  Widget _branchCard(
      BuildContext context, GameLogic game, (String, String, String, Color) b) {
    final (branch, name, fant, tint) = b;
    final nodes = game.researchNodes.where((n) => n.branch == branch).toList();
    final root = nodes.firstWhere((n) => n.tier == 1,
        orElse: () => ResearchNode(id: ''));
    final laneL = (nodes.where((n) => n.lane == 'L').toList()
      ..sort((a, c) => a.tier.compareTo(c.tier)));
    final laneR = (nodes.where((n) => n.lane == 'R').toList()
      ..sort((a, c) => a.tier.compareTo(c.tier)));
    final cap = nodes.firstWhere((n) => n.tier == 5,
        orElse: () => ResearchNode(id: ''));

    final ownedCount = nodes.where((n) => n.isCompleted).length;
    final spent = nodes
        .where((n) => n.isCompleted)
        .fold(0, (s, n) => s + n.rpCost);
    final capOwned = cap.id.isNotEmpty && cap.isCompleted;

    Widget row2(int i) => Row(children: [
          Expanded(
              child: i < laneL.length
                  ? _nodeTile(context, game, laneL[i], tint)
                  : const SizedBox()),
          const SizedBox(width: 12),
          Expanded(
              child: i < laneR.length
                  ? _nodeTile(context, game, laneR[i], tint)
                  : const SizedBox()),
        ]);

    return _card(
      id: branch,
      tint: tint,
      title: name,
      subtitle: fant,
      headRight: Row(mainAxisSize: MainAxisSize.min, children: [
        if (capOwned)
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: Text('★',
                style: TextStyle(
                    color: tint,
                    fontSize: 13,
                    shadows: [Shadow(color: tint, blurRadius: 8)])),
          ),
        Text('$spent / 9',
            style: TextStyle(
                color: AppTheme.textSecondary,
                fontSize: 12,
                fontWeight: FontWeight.w600)),
      ]),
      body: Column(children: [
        _center(root.id.isEmpty ? const SizedBox() : _nodeTile(context, game, root, tint)),
        const SizedBox(height: 12),
        row2(0),
        const SizedBox(height: 12),
        row2(1),
        const SizedBox(height: 12),
        row2(2),
        const SizedBox(height: 12),
        _center(cap.id.isEmpty ? const SizedBox() : _nodeTile(context, game, cap, tint, capstone: true)),
        if (ownedCount == 0)
          Padding(
            padding: const EdgeInsets.only(top: 10),
            child: Text('Research a node to start this engine.',
                style: TextStyle(color: AppTheme.textSecondary, fontSize: 11)),
          ),
      ]),
    );
  }

  Widget _center(Widget child) => Center(
        child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 320), child: child),
      );

  // node states
  bool _rpBlocked(GameLogic g, ResearchNode n) =>
      n.isUnlocked && !n.isCompleted && (g.rpSpent + n.rpCost) > g.rpBudget;

  Widget _nodeTile(BuildContext context, GameLogic game, ResearchNode n, Color tint,
      {bool capstone = false}) {
    final owned = n.isCompleted;
    final unlocked = n.isUnlocked;
    final rpBlocked = _rpBlocked(game, n);
    final available = unlocked && !owned && !rpBlocked;

    Color border;
    Color bg;
    if (owned) {
      border = tint;
      bg = tint.withValues(alpha: 0.14);
    } else if (available) {
      border = tint.withValues(alpha: 0.7);
      bg = const Color(0xFF1C222B);
    } else if (rpBlocked) {
      border = Colors.orangeAccent.withValues(alpha: 0.5);
      bg = const Color(0xFF16191E);
    } else {
      border = Colors.white12; // locked teaser
      bg = const Color(0xFF14171C);
    }

    final show = owned || unlocked; // reveal name/effect once unlocked
    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: () => _openSheet(context, game, n, owned, unlocked, rpBlocked),
      child: Container(
        constraints: BoxConstraints(minHeight: capstone ? 62 : 54),
        padding: const EdgeInsets.fromLTRB(11, 9, 9, 9),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: border, width: capstone ? 1.5 : 1),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 3,
              height: capstone ? 40 : 34,
              margin: const EdgeInsets.only(right: 9, top: 1),
              decoration: BoxDecoration(
                  color: owned || available ? tint : Colors.white24,
                  borderRadius: BorderRadius.circular(2)),
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(show ? n.name : '???',
                      style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: capstone ? 12.5 : 11.5,
                          color: show ? Colors.white : AppTheme.textSecondary)),
                  const SizedBox(height: 2),
                  Text(show ? n.description : 'locked',
                      style: TextStyle(
                          color: AppTheme.textSecondary,
                          fontSize: 9.5,
                          height: 1.3)),
                ],
              ),
            ),
            const SizedBox(width: 6),
            _costChip(n, owned, available, rpBlocked, tint),
          ],
        ),
      ),
    );
  }

  Widget _costChip(ResearchNode n, bool owned, bool available, bool rpBlocked,
      Color tint) {
    if (owned) return Icon(Icons.check_circle, size: 15, color: tint);
    if (n.rpCost == 0) {
      return Text('FREE',
          style: TextStyle(
              color: AppTheme.textSecondary,
              fontSize: 8.5,
              fontWeight: FontWeight.bold));
    }
    final c = rpBlocked ? Colors.orangeAccent : (available ? tint : Colors.white24);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: c.withValues(alpha: 0.6))),
      child: Text('${n.rpCost} RP',
          style: TextStyle(
              color: c, fontSize: 9, fontWeight: FontWeight.bold)),
    );
  }

  // ---- node detail / buy sheet ----
  void _openSheet(BuildContext context, GameLogic game, ResearchNode n, bool owned,
      bool unlocked, bool rpBlocked) {
    if (owned) {
      showGraphNodeSheet(context,
          title: n.name.toUpperCase(),
          description: n.description,
          effectText: 'RESEARCHED — ACTIVE',
          lockedHint: 'Already researched.');
      return;
    }
    if (!unlocked) {
      final missing = n.requirements
          .map((r) => game.researchNodes
              .firstWhere((x) => x.id == r,
                  orElse: () => ResearchNode(id: r, name: r))
              .name)
          .join(', ');
      showGraphNodeSheet(context,
          title: '???',
          description: 'A locked research node.',
          lockedHint: missing.isEmpty
              ? 'Research the prerequisite first.'
              : 'Requires: $missing');
      return;
    }
    if (rpBlocked) {
      showGraphNodeSheet(context,
          title: n.name.toUpperCase(),
          description: n.description,
          lockedHint:
              'Not enough Research Points (${game.rpSpent}/${game.rpBudget}). '
              'Free up RP with a respec, or earn more via forks / Genesis Blocks / '
              'Mastery — your budget grows as you progress.');
      return;
    }
    // available — the real BUY. TECH is RP-only: the node just costs its RP; the
    // sheet only opens for an RP-affordable (not rpBlocked) node, so it's buyable.
    showGraphNodeSheet(
      context,
      title: n.name.toUpperCase(),
      description: n.description,
      costLabel: '${n.rpCost} RP',
      canAfford: true,
      buyLabel: 'RESEARCH',
      onBuy: () => game.buyResearch(n.id),
    );
  }

  // ---- keystones section ----
  Widget _keystonesCard(BuildContext context, GameLogic game) {
    final equipped = game.equippedKeystoneCount;
    final owned = game.ownedCapstones();
    return _card(
      id: 'KS',
      tint: const Color(0xFFFFD24A),
      title: 'KEYSTONES',
      subtitle: 'universal · earned by finishing a branch',
      headRight: Text('$equipped / 2',
          style: TextStyle(
              color: AppTheme.textSecondary,
              fontSize: 12,
              fontWeight: FontWeight.w600)),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final b in _branches)
            _keystoneGroup(context, game, b, owned.contains(b.$1)),
          const SizedBox(height: 8),
          Text(
              'Equip up to 2 — one per finished branch. A keystone is a whole-branch '
              'commitment, so two keystones is a deep, late-game build.',
              style: TextStyle(color: AppTheme.textSecondary, fontSize: 10.5)),
        ],
      ),
    );
  }

  Widget _keystoneGroup(BuildContext context, GameLogic game,
      (String, String, String, Color) b, bool unlocked) {
    final (branch, name, _, tint) = b;
    final ks = kKeystones.where((k) => k.branch == branch).toList();
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Container(width: 7, height: 7, color: tint),
            const SizedBox(width: 7),
            Text(name,
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10.5,
                    letterSpacing: 1,
                    fontWeight: FontWeight.bold)),
            const Spacer(),
            Text(unlocked ? 'unlocked' : 'reach the capstone',
                style: TextStyle(
                    color: unlocked ? tint : AppTheme.textSecondary,
                    fontSize: 9)),
          ]),
          const SizedBox(height: 6),
          for (final k in ks) _keystoneChip(game, k, tint, unlocked),
        ],
      ),
    );
  }

  Widget _keystoneChip(GameLogic game, KeystoneDef k, Color tint, bool unlocked) {
    final on = game.isKeystoneEquipped(k.id);
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: InkWell(
        onTap: unlocked
            ? () {
                if (!on && game.equippedKeystoneCount >= 2) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                      content: Text('Keystone slots full (2/2) — remove one first'),
                      duration: Duration(seconds: 2),
                      behavior: SnackBarBehavior.floating));
                  return;
                }
                game.toggleKeystone(k.id);
              }
            : null,
        child: Opacity(
          opacity: unlocked ? 1 : 0.5,
          child: Container(
            padding: const EdgeInsets.all(9),
            decoration: BoxDecoration(
              color: on ? tint.withValues(alpha: 0.16) : const Color(0xFF14171C),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                  color: on ? tint : Colors.white12,
                  style: unlocked ? BorderStyle.solid : BorderStyle.none),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Text(k.name,
                      style: TextStyle(
                          color: on ? tint : Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 11.5)),
                  const Spacer(),
                  if (on)
                    Icon(Icons.check_circle, size: 14, color: tint),
                ]),
                const SizedBox(height: 2),
                Text(k.description,
                    style: TextStyle(
                        color: AppTheme.textSecondary,
                        fontSize: 9.5,
                        height: 1.3)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ---- synergies section ----
  Widget _synergiesCard(GameLogic game) {
    int live = 0;
    for (final s in _synergies) {
      if (s.$3.every(game.isResearched)) live++;
    }
    return _card(
      id: 'SYN',
      tint: const Color(0xFF39D98A),
      title: 'SYNERGIES',
      subtitle: 'emergent combos — not a 4th branch',
      headRight: Text('$live / ${_synergies.length} live',
          style: TextStyle(
              color: AppTheme.textSecondary,
              fontSize: 12,
              fontWeight: FontWeight.w600)),
      body: Column(
        children: [
          for (final s in _synergies) _synergyRow(game, s),
        ],
      ),
    );
  }

  Widget _synergyRow(GameLogic game, (String, String, List<String>) s) {
    final (name, desc, need) = s;
    final on = need.every(game.isResearched);
    const good = Color(0xFF39D98A);
    final missing = need
        .where((id) => !game.isResearched(id))
        .map((id) => game.researchNodes
            .firstWhere((x) => x.id == id, orElse: () => ResearchNode(id: id, name: id))
            .name)
        .join(', ');
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: on ? good.withValues(alpha: 0.08) : const Color(0xFF14171C),
        borderRadius: BorderRadius.circular(9),
        border: Border.all(
            color: on ? good.withValues(alpha: 0.45) : Colors.white12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(on ? Icons.check_circle : Icons.circle_outlined,
              size: 15, color: on ? good : Colors.white24),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name,
                    style: TextStyle(
                        color: on ? good : Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 12)),
                const SizedBox(height: 2),
                Text(desc,
                    style: TextStyle(
                        color: AppTheme.textSecondary,
                        fontSize: 10,
                        height: 1.35)),
                if (!on && missing.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 3),
                    child: Text('needs $missing',
                        style: TextStyle(
                            color: Colors.white38,
                            fontSize: 9,
                            fontStyle: FontStyle.italic)),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
