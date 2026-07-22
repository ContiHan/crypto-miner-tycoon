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
  @JsonKey(includeToJson: false, includeFromJson: false)
  final Channel? effectChannel;
  @JsonKey(includeToJson: false, includeFromJson: false)
  final double effectValue;

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
  });

  factory ResearchNode.fromJson(Map<String, dynamic> json) =>
      _$ResearchNodeFromJson(json);
  Map<String, dynamic> toJson() => _$ResearchNodeToJson(this);
}
