import 'package:flutter/material.dart';
import 'package:json_annotation/json_annotation.dart';
import '../logic/channels.dart';

part 'research_node.g.dart';

@JsonSerializable()
class ResearchNode {
  final String id;

  // These internal fields are not serialized via default rules if we exclude them OR we accept they get serialized.
  // In `json_serializable`, we can ignore fields.
  // 'icon' is named 'IconData' which relies on Flutter. JsonSerializable doesn't support it by default.
  // We MUST ignore it or use a converter.

  // Fields to Serialize: just id, isUnlocked, isCompleted?
  // If we reload, we might overwrite name/description with old data if we saved it.
  // Better to only save state.
  // But json_serializable is all-or-nothing unless we customize.
  // Let's exclude constants from serialization using @JsonKey(includeFromJson: false, includeToJson: false)
  // BUT the constructor requires them!
  // This is the tricky part of "Automatic" serialization for prototype objects.
  // For now, let's allow saving them (except icon).

  // Actually, to handle IconData, we just exclude it.

  @JsonKey(includeToJson: false, includeFromJson: false)
  final String name;
  @JsonKey(includeToJson: false, includeFromJson: false)
  final String description;
  @JsonKey(includeToJson: false, includeFromJson: false)
  final double cost;

  @JsonKey(includeToJson: false, includeFromJson: false)
  final IconData icon;

  // Research State
  bool isUnlocked; // Visible and purchasable
  bool isCompleted; // Purchased and active

  // Requirements (optional IDs of parent nodes)
  @JsonKey(includeToJson: false, includeFromJson: false)
  final List<String> requirements;

  // Data-driven effect: when completed, adds [effectValue] to [effectChannel]
  // of the economy's channel model. Null channel = a special/mechanic node
  // (e.g. Chip Fab per-rig-type bonus, AI auto-clicker) handled explicitly.
  // A node may ALSO (or instead) declare a MULTI-channel [effects] map — used by
  // the TECH V2 branch nodes whose capstones hit several channels at once.
  @JsonKey(includeToJson: false, includeFromJson: false)
  final Channel? effectChannel;
  @JsonKey(includeToJson: false, includeFromJson: false)
  final double effectValue;
  @JsonKey(includeToJson: false, includeFromJson: false)
  final Map<Channel, double> effects;

  // TECH V2 layout/economy metadata (catalog constants, not serialized):
  // [branch] 'A'/'B'/'C' (null = the free core root); [lane] 'L'/'R' (null = a
  // root/capstone that spans both lanes); [tier] 0 core … 5 capstone; [rpCost] the
  // Research-Point cost (0 free root, 1 normal, 2 capstone).
  @JsonKey(includeToJson: false, includeFromJson: false)
  final String? branch;
  @JsonKey(includeToJson: false, includeFromJson: false)
  final String? lane;
  @JsonKey(includeToJson: false, includeFromJson: false)
  final int tier;
  @JsonKey(includeToJson: false, includeFromJson: false)
  final int rpCost;

  ResearchNode({
    required this.id,
    this.name = '',
    this.description = '',
    this.cost = 0,
    this.icon = Icons.error,
    this.isUnlocked = false,
    this.isCompleted = false,
    this.requirements = const [],
    this.effectChannel,
    this.effectValue = 0,
    this.effects = const {},
    this.branch,
    this.lane,
    this.tier = 0,
    this.rpCost = 1,
  });

  factory ResearchNode.fromJson(Map<String, dynamic> json) =>
      _$ResearchNodeFromJson(json);
  Map<String, dynamic> toJson() => _$ResearchNodeToJson(this);
}
