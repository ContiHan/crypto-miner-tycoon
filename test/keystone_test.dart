import 'package:flutter_test/flutter_test.dart';
import 'package:crypto_miner_tycoon/logic/managers/research_manager.dart';
import 'package:crypto_miner_tycoon/logic/systems/keystone_system.dart';

void main() {
  group('Keystones — availability, cap, aggregate, persistence', () {
    KeystoneSystem sys() => KeystoneSystem();

    test('availability is gated by committed doctrines', () {
      final s = sys();
      // No commitments → nothing offered.
      expect(s.availableFor({}).isEmpty, true);
      // Commit MEGA-HASH → exactly its two capstone keystones.
      final mega = s.availableFor({Doctrine.megaHash});
      expect(mega.map((k) => k.id).toSet(),
          {'ks_asic_monoculture', 'ks_furnace_farm'});
      // Two doctrines → four keystones.
      expect(s.availableFor({Doctrine.megaHash, Doctrine.coldStorage}).length, 4);
    });

    test('toggle refuses a keystone whose doctrine is not committed', () {
      final s = sys();
      expect(s.toggle('ks_asic_monoculture', {Doctrine.leanRig}), false);
      expect(s.isEquipped('ks_asic_monoculture'), false);
      // Committed → equips.
      expect(s.toggle('ks_asic_monoculture', {Doctrine.megaHash}), true);
      expect(s.isEquipped('ks_asic_monoculture'), true);
      // Toggling again unequips.
      expect(s.toggle('ks_asic_monoculture', {Doctrine.megaHash}), false);
      expect(s.isEquipped('ks_asic_monoculture'), false);
    });

    test('availableOrEquipped surfaces an orphaned (equipped, uncommitted) keystone',
        () {
      final s = sys();
      s.toggle('ks_asic_monoculture', {Doctrine.megaHash}); // equip in an era
      // Next era commits a DIFFERENT doctrine (a fork reset the old one).
      final committed = {Doctrine.coldStorage};
      // availableFor hides the orphan → the bug (can't see/unequip it).
      expect(s.availableFor(committed).any((k) => k.id == 'ks_asic_monoculture'),
          false);
      // availableOrEquipped includes it so the panel can show + unequip it.
      final panel = s.availableOrEquipped(committed);
      expect(panel.any((k) => k.id == 'ks_asic_monoculture'), true);
      expect(panel.any((k) => k.doctrine == Doctrine.coldStorage), true);
    });

    test('PAPER HANDS carries a real cost (no phantom Consensus-decay)', () {
      final s = sys();
      s.toggle('ks_paper_hands', {Doctrine.degenYield});
      final m = s.aggregate();
      expect(m.govTokenGainMult, 2.0);
      expect(m.incomeMult, closeTo(0.75, 1e-9),
          reason: 'the GT×2 upside is paid for with −25% passive income');
    });

    test('equip cap is 2 — a 3rd is refused', () {
      final s = sys();
      final committed = {Doctrine.megaHash, Doctrine.coldStorage};
      expect(s.toggle('ks_asic_monoculture', committed), true);
      expect(s.toggle('ks_furnace_farm', committed), true);
      expect(s.equipped.length, 2);
      // 3rd from a committed doctrine is still refused (cap).
      expect(s.toggle('ks_cold_miner', committed), false);
      expect(s.equipped.length, 2);
    });

    test('single-keystone aggregate matches its def (ASIC Monoculture)', () {
      final s = sys();
      s.toggle('ks_asic_monoculture', {Doctrine.megaHash});
      final m = s.aggregate();
      expect(m.hashMult, 2.0);
      expect(m.luckMult, 0.4);
      expect(m.noCrits, true);
      // Untouched levers stay neutral.
      expect(m.incomeMult, 1.0);
      expect(m.offlineForceParity, false);
    });

    test('two-keystone aggregate: mults multiply, flags OR', () {
      final s = sys();
      final committed = {Doctrine.hodler, Doctrine.coldStorage};
      // COLD WALLET DISCIPLINE (income 0.55, idle 2.0, noCrits) +
      // FORT KNOX (breachLoss 0.2, resist 1.3, luck 0.5, noCrits).
      s.toggle('ks_cold_wallet_discipline', committed);
      s.toggle('ks_fort_knox', committed);
      final m = s.aggregate();
      expect(m.incomeMult, closeTo(0.55, 1e-9));
      expect(m.idleMult, closeTo(2.0, 1e-9));
      expect(m.breachLossMult, closeTo(0.2, 1e-9));
      expect(m.resistMult, closeTo(1.3, 1e-9));
      expect(m.luckMult, closeTo(0.5, 1e-9));
      expect(m.noCrits, true); // OR of both
      expect(m.offlineForceParity, true); // from COLD WALLET DISCIPLINE
    });

    test('neutral aggregate when nothing equipped', () {
      final m = sys().aggregate();
      expect(m.hashMult, 1.0);
      expect(m.incomeMult, 1.0);
      expect(m.luckMult, 1.0);
      expect(m.rigCostBonus, 0.0);
      expect(m.noCrits, false);
      expect(m.immuneNegatives, false);
      expect(m.suppressPositives, false);
      expect(m.upkeepPinned, false);
    });

    test('persistence round-trips and load clamps to the cap', () {
      final s = sys();
      final committed = {Doctrine.megaHash, Doctrine.coldStorage};
      s.toggle('ks_asic_monoculture', committed);
      s.toggle('ks_fort_knox', committed);
      final json = s.toJson();
      expect(json.toSet(), {'ks_asic_monoculture', 'ks_fort_knox'});

      final s2 = sys();
      s2.loadFrom(json);
      expect(s2.equipped, s.equipped);

      // A corrupt save with too many is clamped to 2.
      final s3 = sys();
      s3.loadFrom(['a', 'b', 'c', 'd']);
      expect(s3.equipped.length, 2);

      // reset() clears everything.
      s.reset();
      expect(s.equipped.isEmpty, true);
    });
  });
}
