import 'dart:math';

class Rig {
  final String id;
  final String name;
  double baseCost;
  double baseHashRate;
  int amount;
  double costMultiplier;

  Rig({
    required this.id,
    required this.name,
    required this.baseCost,
    required this.baseHashRate,
    this.amount = 0,
    this.costMultiplier = 1.15,
  });

  double get currentCost {
    return baseCost * pow(costMultiplier, amount);
  }

  double get totalHashRate => baseHashRate * amount;

  Map<String, dynamic> toJson() => {
    'id': id,
    'amount': amount,
  };

  factory Rig.fromJson(Map<String, dynamic> json, List<Rig> prototypes) {
    // Find the prototype rig to get base stats
    Rig prototype = prototypes.firstWhere((r) => r.id == json['id']);
    // Return a new object (or modify prototype if we were mutable, but here we update amount)
    // Actually, since our logic holds a list of rigs, we will just update the amount of the existing rig in the list
    // This factory might be better as a static helper or just handle it in GameLogic.
    // Let's just return a placeholder or handle logic in GameLogic.
    // Better approach: GameLogic loads the list, then iterates JSON to update amounts.
    return prototype..amount = json['amount'] ?? 0;
  }
}
