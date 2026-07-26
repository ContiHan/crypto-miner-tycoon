import '../core/ids.dart';
import '../models/rig.dart';

/// Data-driven rig catalog. Add a rig by adding one entry here — GameLogic builds
/// its runtime rig list from this, the MINE tab renders whatever is present, and
/// the economy sums their hash. Rigs reveal PROGRESSIVELY: you start with only the
/// first one, and each next rig unlocks once you OWN the previous one (buy one →
/// the next appears). `unlockAtLifetimeSats` is a secondary earnings fallback so a
/// tap-rich player can also reveal ahead; 0 means no earnings gate.
class RigDef {
  final String id;
  final String name;
  final double baseCost;
  final double baseHashRate;
  final double costMultiplier;
  final double unlockAtLifetimeSats;

  const RigDef({
    required this.id,
    required this.name,
    required this.baseCost,
    required this.baseHashRate,
    this.costMultiplier = 1.15,
    this.unlockAtLifetimeSats = 0,
  });
}

// The earnings fallbacks (~1.3× each rig's cost) rarely fire — the ownership
// chain reveals the next rig the moment you buy the current one — but they stop
// a tap-heavy player from ever getting stuck with nothing new to reveal.
const List<RigDef> kRigDefs = [
  RigDef(id: RigIds.cpuRig, name: 'Starter CPU Rig', baseCost: 100, baseHashRate: 1.0),
  RigDef(id: RigIds.gpuRig, name: 'GPU Rack', baseCost: 1500, baseHashRate: 20.0, unlockAtLifetimeSats: 2000),
  RigDef(id: RigIds.asicRig, name: 'ASIC Miner', baseCost: 12000, baseHashRate: 250.0, unlockAtLifetimeSats: 15000),
  RigDef(id: RigIds.quantumRig, name: 'Quantum Computer', baseCost: 150000, baseHashRate: 5000.0, unlockAtLifetimeSats: 200000),
  RigDef(id: RigIds.fusionRig, name: 'Fusion Reactor', baseCost: 2500000, baseHashRate: 90000.0, unlockAtLifetimeSats: 3e6),
  RigDef(id: RigIds.datacenterRig, name: 'Orbital Datacenter', baseCost: 50000000, baseHashRate: 1600000.0, unlockAtLifetimeSats: 6e7),
];

/// Fresh, mutable runtime Rig instances (amount = 0) for a new game/session.
List<Rig> createRigs() => kRigDefs
    .map((d) => Rig(
          id: d.id,
          name: d.name,
          baseCost: d.baseCost,
          baseHashRate: d.baseHashRate,
          costMultiplier: d.costMultiplier,
        ))
    .toList();

/// Lifetime-earnings gate for a rig id (0 if always available / unknown).
double rigUnlockThreshold(String id) {
  for (final d in kRigDefs) {
    if (d.id == id) return d.unlockAtLifetimeSats;
  }
  return 0;
}
