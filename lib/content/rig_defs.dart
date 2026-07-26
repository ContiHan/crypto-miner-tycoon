import '../core/ids.dart';
import '../models/rig.dart';

/// Data-driven rig catalog (10 tiers). Rigs reveal PROGRESSIVELY via per-rig
/// unlock MILESTONES measured since the previous rig unlocked (see GameLogic's
/// `_rigConditionMet` / `rigUnlockHint`). This file holds only the economy
/// numbers — a smooth ~13× geometric hash + cost ladder.
class RigDef {
  final String id;
  final String name;
  final double baseCost;
  final double baseHashRate;
  final double costMultiplier;

  const RigDef({
    required this.id,
    required this.name,
    required this.baseCost,
    required this.baseHashRate,
    this.costMultiplier = 1.15,
  });
}

const List<RigDef> kRigDefs = [
  RigDef(id: RigIds.cpuRig, name: 'Starter CPU Rig', baseCost: 100, baseHashRate: 1),
  RigDef(id: RigIds.gpuRig, name: 'GPU Rack', baseCost: 1400, baseHashRate: 14),
  RigDef(id: RigIds.asicRig, name: 'ASIC Miner', baseCost: 18000, baseHashRate: 190),
  RigDef(id: RigIds.miningFarm, name: 'Mining Farm', baseCost: 240000, baseHashRate: 2600),
  RigDef(id: RigIds.quantumRig, name: 'Quantum Computer', baseCost: 3200000, baseHashRate: 35000),
  RigDef(id: RigIds.fusionRig, name: 'Fusion Reactor', baseCost: 42000000, baseHashRate: 480000),
  RigDef(id: RigIds.photonicRig, name: 'Photonic Array', baseCost: 560000000, baseHashRate: 6500000),
  RigDef(id: RigIds.datacenterRig, name: 'Orbital Datacenter', baseCost: 7400000000, baseHashRate: 88000000),
  RigDef(id: RigIds.dysonRig, name: 'Dyson Swarm', baseCost: 98000000000, baseHashRate: 1200000000),
  RigDef(id: RigIds.singularityRig, name: 'Singularity Core', baseCost: 1300000000000, baseHashRate: 16000000000),
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
