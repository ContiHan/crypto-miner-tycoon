import 'package:flutter_test/flutter_test.dart';
import 'package:crypto_miner_tycoon/logic/systems/keystone_system.dart';

// TECH V2: keystones are grouped by the 3 branches ('A' Foundry / 'B' Golden
// Nonce / 'C' Degen) and unlock when that branch's CAPSTONE node is owned
// (passed in as a Set of owned-capstone branch letters).
void main() {
  group('Keystones — availability, cap, aggregate, persistence', () {
    KeystoneSystem sys() => KeystoneSystem();

    test('availability is gated by owned branch capstones', () {
      final s = sys();
      // No capstone owned → nothing offered.
      expect(s.availableFor({}).isEmpty, true);
      // Own the Foundry capstone → exactly branch A's four keystones.
      expect(s.availableFor({'A'}).map((k) => k.id).toSet(), {
        'ks_asic_monoculture',
        'ks_furnace_farm',
        'ks_low_time_preference',
        'ks_paper_hands',
      });
      // Two branches → eight keystones (4 + 4).
      expect(s.availableFor({'A', 'C'}).length, 8);
    });

    test('toggle refuses a keystone whose branch capstone is not owned', () {
      final s = sys();
      // ks_asic_monoculture is a branch-A keystone; only 'B' owned → refused.
      expect(s.toggle('ks_asic_monoculture', {'B'}), false);
      expect(s.isEquipped('ks_asic_monoculture'), false);
      // Own branch A → equips.
      expect(s.toggle('ks_asic_monoculture', {'A'}), true);
      expect(s.isEquipped('ks_asic_monoculture'), true);
      // Toggling again unequips.
      expect(s.toggle('ks_asic_monoculture', {'A'}), false);
      expect(s.isEquipped('ks_asic_monoculture'), false);
    });

    test('availableOrEquipped surfaces an orphaned (equipped, now-locked) keystone',
        () {
      final s = sys();
      s.toggle('ks_asic_monoculture', {'A'}); // equipped while A was finished
      // A fork reset the tree — now only branch C's capstone is owned.
      final owned = {'C'};
      expect(s.availableFor(owned).any((k) => k.id == 'ks_asic_monoculture'),
          false);
      final panel = s.availableOrEquipped(owned);
      expect(panel.any((k) => k.id == 'ks_asic_monoculture'), true);
      expect(panel.any((k) => k.branch == 'C'), true);
    });

    test('PAPER HANDS carries a real cost (no phantom Consensus-decay)', () {
      final s = sys();
      s.toggle('ks_paper_hands', {'A'});
      final m = s.aggregate();
      expect(m.govTokenGainMult, 2.0);
      expect(m.incomeMult, closeTo(0.75, 1e-9),
          reason: 'the GT×2 upside is paid for with −25% passive income');
    });

    test('equip cap is 2 — a 3rd is refused', () {
      final s = sys();
      final owned = {'A', 'C'};
      expect(s.toggle('ks_asic_monoculture', owned), true);
      expect(s.toggle('ks_furnace_farm', owned), true);
      expect(s.equipped.length, 2);
      expect(s.toggle('ks_cold_miner', owned), false);
      expect(s.equipped.length, 2);
    });

    test('single-keystone aggregate matches its def (ASIC Monoculture)', () {
      final s = sys();
      s.toggle('ks_asic_monoculture', {'A'});
      final m = s.aggregate();
      expect(m.hashMult, 2.0);
      expect(m.luckMult, 0.4);
      expect(m.noCrits, true);
      expect(m.incomeMult, 1.0);
      expect(m.offlineForceParity, false);
    });

    test('two-keystone aggregate: mults multiply, flags OR', () {
      final s = sys();
      final owned = {'B', 'C'};
      // COLD WALLET DISCIPLINE (branch B) + FORT KNOX (branch C).
      s.toggle('ks_cold_wallet_discipline', owned);
      s.toggle('ks_fort_knox', owned);
      final m = s.aggregate();
      expect(m.incomeMult, closeTo(0.55, 1e-9));
      expect(m.idleMult, closeTo(2.0, 1e-9));
      expect(m.breachLossMult, closeTo(0.2, 1e-9));
      expect(m.resistMult, closeTo(1.3, 1e-9));
      expect(m.luckMult, closeTo(0.5, 1e-9));
      expect(m.noCrits, true);
      expect(m.offlineForceParity, true);
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
      final owned = {'A', 'C'};
      s.toggle('ks_asic_monoculture', owned);
      s.toggle('ks_fort_knox', owned);
      final json = s.toJson();
      expect(json.toSet(), {'ks_asic_monoculture', 'ks_fort_knox'});

      final s2 = sys();
      s2.loadFrom(json);
      expect(s2.equipped, s.equipped);

      final s3 = sys();
      s3.loadFrom(['a', 'b', 'c', 'd']);
      expect(s3.equipped.length, 2);

      s.reset();
      expect(s.equipped.isEmpty, true);
    });
  });
}
