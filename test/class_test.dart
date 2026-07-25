import 'package:flutter_test/flutter_test.dart';
import 'package:crypto_miner_tycoon/logic/channels.dart';
import 'package:crypto_miner_tycoon/logic/managers/class_manager.dart';
import 'package:crypto_miner_tycoon/providers/game_logic.dart';
import 'package:crypto_miner_tycoon/services/economy_service.dart';
import 'package:crypto_miner_tycoon/services/stash_service.dart';
import 'test_helper.dart';
import 'fakes.dart';

void main() {
  group('ClassManager (unit)', () {
    test('prospector: no channel bonuses, neutral prestige, not chosen', () {
      final cm = ClassManager();
      expect(cm.current, BtcClass.prospector);
      expect(cm.hasChosenClass, false);
      final ch = Channels();
      cm.contributeChannels(ch);
      expect(ch.sum(Channel.hash), 0);
      expect(ch.sum(Channel.income), 0);
      expect(cm.prestigeGainMultiplier, 1.0);
    });

    test('each class contributes exactly its declared weightings', () {
      final cm = ClassManager()..select(BtcClass.corporation);
      final ch = Channels();
      cm.contributeChannels(ch);
      expect(ch.sum(Channel.hash), closeTo(0.20, 1e-9));
      expect(ch.sum(Channel.income), closeTo(0.15, 1e-9));
      expect(ch.sum(Channel.volatility), closeTo(0.15, 1e-9));
      expect(cm.prestigeGainMultiplier, 0.85);

      final og = ClassManager()..select(BtcClass.btcOg);
      expect(og.prestigeGainMultiplier, 1.25);

      final solo = ClassManager()..select(BtcClass.soloMiner);
      final ch2 = Channels();
      solo.contributeChannels(ch2);
      expect(ch2.sum(Channel.rigCost), closeTo(0.20, 1e-9));
      expect(ch2.sum(Channel.click), closeTo(0.15, 1e-9));
      expect(solo.prestigeGainMultiplier, 1.0);

      final pool = ClassManager()..select(BtcClass.poolMember);
      final ch3 = Channels();
      pool.contributeChannels(ch3);
      expect(ch3.sum(Channel.volatility), closeTo(-0.25, 1e-9)); // calmer
    });

    test('Mastery XP is concave and only real classes earn it', () {
      final cm = ClassManager();
      cm.creditMastery(BtcClass.prospector, 1e9); // ignored
      expect(cm.masteryLevel(BtcClass.prospector), 0);

      cm.creditMastery(BtcClass.corporation, 40000); // sqrt(40000/10000)=2
      expect(cm.masteryLevel(BtcClass.corporation), 2);
      cm.creditMastery(BtcClass.corporation, 50000); // total 90000 -> 3
      expect(cm.masteryLevel(BtcClass.corporation), 3);
      expect(cm.totalMasteryLevel, 3);
    });

    test('Mastery grants a tiny permanent all-class hash+income bonus', () {
      final cm = ClassManager()..creditMastery(BtcClass.corporation, 40000);
      cm.select(BtcClass.prospector); // even Prospector benefits
      final ch = Channels();
      cm.contributeChannels(ch);
      expect(ch.sum(Channel.hash), closeTo(0.01, 1e-9)); // 2 * 0.005
      expect(ch.sum(Channel.income), closeTo(0.01, 1e-9));
    });

    test('masteryJson/loadFrom round-trips and ignores junk', () {
      final cm = ClassManager()
        ..select(BtcClass.poolMember)
        ..creditMastery(BtcClass.btcOg, 12345);
      final json = cm.masteryJson();

      final cm2 = ClassManager()
        ..loadFrom('poolMember', {...json, 'garbage': 999, 'prospector': 5});
      expect(cm2.current, BtcClass.poolMember);
      expect(cm2.masteryXp[BtcClass.btcOg], 12345);
      expect(cm2.masteryXp[BtcClass.prospector], 0);

      // Unknown class name falls back to Prospector.
      final cm3 = ClassManager()..loadFrom('not_a_class', null);
      expect(cm3.current, BtcClass.prospector);
    });

    test('reset wipes class and Mastery', () {
      final cm = ClassManager()
        ..select(BtcClass.corporation)
        ..creditMastery(BtcClass.corporation, 40000);
      cm.reset();
      expect(cm.current, BtcClass.prospector);
      expect(cm.totalMasteryLevel, 0);
    });
  });

  group('Class integration (GameLogic)', () {
    test('class channel bonus reaches buildChannels', () async {
      final game = createTestGameLogic(loadOnStart: false);
      await game.loadGame();
      expect(game.buildChannels().sum(Channel.hash), 0);
      game.debugSelectClass(BtcClass.corporation);
      expect(game.buildChannels().sum(Channel.hash), closeTo(0.20, 1e-9));
    });

    test('class scales prestige gain (Consensus + GovTokens)', () async {
      final game = createTestGameLogic(loadOnStart: false);
      await game.loadGame();
      game.lifetimeEarnings = 1e13; // plenty for both pending gains

      game.debugSelectClass(BtcClass.corporation); // 0.85
      final corpCX = game.pendingConsensus;
      final corpGT = game.pendingGovTokens;
      game.debugSelectClass(BtcClass.btcOg); // 1.25
      final ogCX = game.pendingConsensus;
      final ogGT = game.pendingGovTokens;

      expect(ogCX, greaterThan(corpCX));
      expect(ogGT, greaterThan(corpGT));
      // Prospector is the neutral 1.0 reference in between.
      game.debugSelectClass(BtcClass.prospector);
      expect(game.pendingGovTokens, greaterThan(corpGT));
      expect(game.pendingGovTokens, lessThan(ogGT));
    });

    test('Mastery follows the MINT-time class; a last-second switch cannot farm it',
        () async {
      // QA regression: Mastery XP is credited per GovToken at Hard Fork (mint)
      // time to whoever was active THEN — not to the class held at New Blockchain
      // reset time. So switching class right before a New Blockchain credits the
      // switched-to class nothing.
      final game = createTestGameLogic(loadOnStart: false);
      await game.loadGame();

      // Play & mint a big batch of GovTokens as Corporation.
      game.debugSelectClass(BtcClass.corporation);
      game.lifetimeEarnings = 260000 * 260000 * 5.0e8;
      final minted = game.pendingGovTokens;
      expect(minted, greaterThan(0));
      game.hardFork(); // credits `minted` XP to Corporation at mint time
      expect(game.pendingGenesis, greaterThan(0)); // enough to New Blockchain

      final corpLevel = game.masteryLevel(BtcClass.corporation);
      expect(corpLevel, greaterThan(0),
          reason: 'the class that actually minted earns the XP');

      // Farm attempt: switch to a class that minted nothing, THEN New Blockchain.
      game.debugSelectClass(BtcClass.soloMiner);
      game.newBlockchain(chosenClass: BtcClass.btcOg);

      expect(game.currentClass, BtcClass.btcOg, reason: 'new class locked in');
      expect(game.masteryLevel(BtcClass.corporation), corpLevel,
          reason: 'earner keeps exactly its mint-time credit (no bulk re-credit)');
      expect(game.masteryLevel(BtcClass.soloMiner), 0,
          reason: 'the switched-through class minted nothing → no farmed credit');
      // Chain baseline reset, so the fresh chain starts at 0 mastery-earning.
      expect(game.pendingGenesis, 0);
    });

    test('class is LOCKED after the first pick — no mid-chain switching', () async {
      final game = createTestGameLogic(loadOnStart: false);
      await game.loadGame();
      expect(game.currentClass, BtcClass.prospector);

      // First pick (early, on the SKILL tab) works.
      game.chooseClass(BtcClass.soloMiner);
      expect(game.currentClass, BtcClass.soloMiner);

      // A mid-chain switch is blocked — locked until the next New Blockchain.
      game.chooseClass(BtcClass.corporation);
      expect(game.currentClass, BtcClass.soloMiner,
          reason: 'chooseClass is a no-op once a class is committed');

      // A New Blockchain re-opens the choice via its own picker.
      game.lifetimeEarnings = 260000 * 260000 * 5.0e8;
      game.hardFork();
      expect(game.pendingGenesis, greaterThan(0));
      game.newBlockchain(chosenClass: BtcClass.btcOg);
      expect(game.currentClass, BtcClass.btcOg, reason: 'New Blockchain re-picks');

      // ...and the new class is locked again on the fresh chain.
      game.chooseClass(BtcClass.poolMember);
      expect(game.currentClass, BtcClass.btcOg,
          reason: 're-locked after the New Blockchain pick');
    });

    test('a full Wipe Save clears class + Mastery', () async {
      final game = createTestGameLogic(loadOnStart: false);
      await game.loadGame();
      game.debugSelectClass(BtcClass.corporation);
      game.debugCreditMastery(BtcClass.corporation, 40000);
      await game.resetGame();
      expect(game.currentClass, BtcClass.prospector);
      expect(game.totalMasteryLevel, 0);
    });

    test('class + Mastery survive a save/reload (persistence)', () async {
      final repo = FakeGameRepository();
      final settings = FakeSettingsRepository();
      GameLogic make() => GameLogic(
            gameRepository: repo,
            settingsRepository: settings,
            economyService: EconomyService(),
            stashService: StashService(),
            soundService: FakeSoundService(),
            startTimers: false,
            loadOnStart: false,
          )..clickRng = NoCritRandom();

      final g1 = make();
      await g1.loadGame();
      g1.debugSelectClass(BtcClass.poolMember);
      g1.debugCreditMastery(BtcClass.btcOg, 40000); // level 2
      g1.wallet = 1e9;
      g1.buyRig('cpu_rig'); // a buy triggers a save into the shared repo

      final g2 = make();
      await g2.loadGame();
      expect(g2.currentClass, BtcClass.poolMember);
      expect(g2.masteryLevel(BtcClass.btcOg), 2);
    });
  });
}
