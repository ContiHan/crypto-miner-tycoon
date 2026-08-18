import 'package:flutter/material.dart';

/// The repeated "rarity tag" chip: an optional colored dot + the UPPERCASE
/// rarity name, in the rarity's own color. Shared by the firmware affix list
/// and the achievements list so the tag renders identically everywhere.
///
/// Pass the already-resolved [color] (from `AppTheme.rarityColor`) and the raw
/// rarity [label] (e.g. `rarity.name` — it is uppercased here). [showDot],
/// [fontSize] and [letterSpacing] carry the small per-site differences.
class RarityBadge extends StatelessWidget {
  final Color color;
  final String label;
  final bool showDot;
  final double fontSize;
  final double letterSpacing;
  final double dotSize;

  const RarityBadge({
    super.key,
    required this.color,
    required this.label,
    this.showDot = true,
    this.fontSize = 10,
    this.letterSpacing = 1,
    this.dotSize = 7,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (showDot) ...[
          Icon(Icons.circle, size: dotSize, color: color),
          const SizedBox(width: 4),
        ],
        Text(
          label.toUpperCase(),
          style: TextStyle(
            color: color,
            fontSize: fontSize,
            fontWeight: FontWeight.bold,
            letterSpacing: letterSpacing,
          ),
        ),
      ],
    );
  }
}
