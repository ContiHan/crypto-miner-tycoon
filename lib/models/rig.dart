import 'dart:math';
import 'package:json_annotation/json_annotation.dart';

part 'rig.g.dart';

@JsonSerializable()
class Rig {
  final String id;

  // These internal fields are not serialized or have special handling if we want full sync
  // But Rig is usually prototype + dynamic amount.
  // We only strictly need 'id' and 'amount' to be saved.
  // However, 'json_serializable' saves all fields by default.
  // Rig stats (name, baseCost) are constants from code (prototypes).
  // If we save them, we bloat the save file, but it's fine.
  // The critical part is reloading.
  // If we load from JSON, we get a NEW Rig object with values from JSON.
  // We need to ensure logic preserves specific behaviors.

  @JsonKey(includeToJson: false, includeFromJson: false)
  final String name;
  @JsonKey(includeToJson: false, includeFromJson: false)
  double baseCost;
  @JsonKey(includeToJson: false, includeFromJson: false)
  double baseHashRate;
  int amount;
  @JsonKey(includeToJson: false, includeFromJson: false)
  double costMultiplier;

  Rig({
    required this.id,
    this.name = '',
    this.baseCost = 0,
    this.baseHashRate = 0,
    this.amount = 0,
    this.costMultiplier = 1.15,
  });

  double get currentCost {
    return baseCost * pow(costMultiplier, amount);
  }

  double get totalHashRate => baseHashRate * amount;

  factory Rig.fromJson(Map<String, dynamic> json) => _$RigFromJson(json);
  Map<String, dynamic> toJson() => _$RigToJson(this);
}
