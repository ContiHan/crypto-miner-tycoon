import '../core/ids.dart';
import '../models/rig.dart';

/// Data-driven rig catalog. Add a rig by adding one entry here — GameLogic builds
/// its runtime rig list from this, the MINE tab renders whatever is present, and
/// the economy sums their hash. `unlockAtLifetimeSats` gates a rig behind an
/// earnings milestone (progressive discovery); 0 means available from the start.
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

const List<RigDef> kRigDefs = [
  RigDef(id: RigIds.cpuRig, name: 'Starter CPU Rig', baseCost: 100, baseHashRate: 1.0),
  RigDef(id: RigIds.gpuRig, name: 'GPU Rack', baseCost: 1500, baseHashRate: 20.0),
  RigDef(id: RigIds.asicRig, name: 'ASIC Miner', baseCost: 12000, baseHashRate: 250.0),
  RigDef(id: RigIds.quantumRig, name: 'Quantum Computer', baseCost: 150000, baseHashRate: 5000.0),
  RigDef(id: RigIds.fusionRig, name: 'Fusion Reactor', baseCost: 2500000, baseHashRate: 90000.0, unlockAtLifetimeSats: 1e6),
  RigDef(id: RigIds.datacenterRig, name: 'Orbital Datacenter', baseCost: 50000000, baseHashRate: 1600000.0, unlockAtLifetimeSats: 1e9),
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
