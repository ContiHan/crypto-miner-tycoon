import 'dart:math';
import 'package:crypto_miner_tycoon/repositories/game_repository.dart';
import 'package:crypto_miner_tycoon/repositories/settings_repository.dart';
import 'package:crypto_miner_tycoon/models/rig.dart';
import 'package:crypto_miner_tycoon/models/research_node.dart';
import 'package:crypto_miner_tycoon/services/sound_service.dart';

/// Deterministic Random that never rolls a mining crit (nextDouble stays above
/// clickCritChance), so click-earnings assertions are stable. This is the
/// default injected by createTestGameLogic.
class NoCritRandom implements Random {
  @override
  double nextDouble() => 0.999;
  @override
  int nextInt(int max) => 0;
  @override
  bool nextBool() => false;
}

/// Deterministic Random that always rolls a crit (nextDouble below the chance).
class AlwaysCritRandom implements Random {
  @override
  double nextDouble() => 0.0;
  @override
  int nextInt(int max) => 0;
  @override
  bool nextBool() => false;
}

class FakeSoundService implements SoundService {
  bool _muted = false;
  final List<bool> setMutedCalls = [];
  int mineCount = 0;
  int buyCount = 0;
  int unlockCount = 0;
  int eventGoodCount = 0;
  int eventBadCount = 0;
  int halvingCount = 0;

  @override
  bool get isMuted => _muted;

  @override
  void setMuted(bool muted) {
    _muted = muted;
    setMutedCalls.add(muted);
  }

  @override
  Future<void> playSound(String text) async {}

  @override
  Future<void> playMine() async => mineCount++;

  @override
  Future<void> playBuy() async => buyCount++;

  @override
  Future<void> playUnlock() async => unlockCount++;

  @override
  Future<void> playEventGood() async => eventGoodCount++;

  @override
  Future<void> playEventBad() async => eventBadCount++;

  @override
  Future<void> playHalving() async => halvingCount++;
}

class FakeSettingsRepository implements SettingsRepository {
  Map<String, dynamic> data = {
    'sound_enabled': true,
    'haptics_enabled': true,
    'show_fiat_prices': false,
    // Default to DONE so widget tests aren't covered by the first-run coach;
    // the onboarding test flips this to false explicitly.
    'onboarding_complete': true,
    // Pre-dismiss every per-screen first-visit tip so they don't overlay tests.
    'seen_tips': const ['tab_skill', 'tab_tech', 'tab_stash', 'tab_goal'],
  };

  @override
  Future<Map<String, dynamic>> loadSettings() async {
    return data;
  }

  @override
  Future<void> saveSettings({
    required bool soundEnabled,
    required bool showFiatPrices,
    bool hapticsEnabled = true,
    bool onboardingComplete = false,
    List<String> seenTips = const [],
  }) async {
    data['sound_enabled'] = soundEnabled;
    data['haptics_enabled'] = hapticsEnabled;
    data['show_fiat_prices'] = showFiatPrices;
    data['onboarding_complete'] = onboardingComplete;
    data['seen_tips'] = seenTips;
  }
}

class FakeGameRepository implements GameRepository {
  Map<String, dynamic> data = {
    'wallet': 0.0,
    'lifetimeEarnings': 0.0,
    'govTokens': 0,
    'spentGovTokens': 0,
    'chips': 0,
    'blockReward': 50.0 * 100000000,
    'blocksMined': 0,
    'nextHalvingThreshold': 5000,
    'bitcoinExchangeRate': 1.0,
    'networkDifficulty': 100.0,
  };

  @override
  Future<void> clearSave() async {
    data = {
      'wallet': 0.0,
      // Keep defaults logic similar to loadGame or just empty?
      // GameLogic.resetGame handles defaults in memory, but repo just clears.
    };
  }

  @override
  Future<Map<String, dynamic>> loadGameState() async {
    return data;
  }

  @override
  Future<int?> readLastSaveTime() async {
    final t = data['last_save_time'];
    return t is int ? t : null;
  }

  @override
  Future<void> saveGameState({
    required double wallet,
    required double lifetimeEarnings,
    required int govTokens,
    required int spentGovTokens,
    required Map<String, int> perks,
    required Map<String, int> perkCosts,
    required List<Rig> rigs,
    required List<ResearchNode> researchNodes,
    required double networkDifficulty,
    required double blockReward,
    required int blocksMined,
    required int nextHalvingThreshold,
    required double bitcoinExchangeRate,
    int chips = 0,
    Map<String, dynamic>? stash,
    int consensus = 0,
    double lifetimeAtLastSoftFork = 0,
    int genesisBlocks = 0,
    double totalGovTokensEver = 0,
    double govTokensEverAtLastNewChain = 0,
    List<String> achievements = const [],
    List<String> claimedAchievements = const [],
    int hardForkCount = 0,
    int softForkCount = 0,
    int newChainCount = 0,
    int cratesOpened = 0,
    int casinoSpins = 0,
    int casinoJackpots = 0,
    double casinoWindowNet = 0,
    int casinoWindowStartMs = 0,
    String currentClass = 'prospector',
    Map<String, dynamic> mastery = const {},
    double lifetimeEverSats = 0,
    bool hasWonGame = false,
    bool sandboxNoCap = false,
    int winCount = 0,
    bool unlockedTech = false,
    bool unlockedStash = false,
    bool unlockedSkill = false,
    bool unlockedGoal = false,
  }) async {
    data['wallet'] = wallet;
    data['lifetimeEarnings'] = lifetimeEarnings;
    data['govTokens'] = govTokens;
    data['spentGovTokens'] = spentGovTokens;
    data['chips'] = chips;
    data['consensus'] = consensus;
    data['lifetimeAtLastSoftFork'] = lifetimeAtLastSoftFork;
    data['genesisBlocks'] = genesisBlocks;
    data['totalGovTokensEver'] = totalGovTokensEver;
    data['govTokensEverAtLastNewChain'] = govTokensEverAtLastNewChain;
    data['achievements'] = achievements;
    data['claimedAchievements'] = claimedAchievements;
    data['hardForkCount'] = hardForkCount;
    data['softForkCount'] = softForkCount;
    data['newChainCount'] = newChainCount;
    data['cratesOpened'] = cratesOpened;
    data['casinoSpins'] = casinoSpins;
    data['casinoJackpots'] = casinoJackpots;
    data['casinoWindowNet'] = casinoWindowNet;
    data['casinoWindowStartMs'] = casinoWindowStartMs;
    data['currentClass'] = currentClass;
    data['mastery'] = mastery;
    data['lifetimeEverSats'] = lifetimeEverSats;
    data['hasWonGame'] = hasWonGame;
    data['sandboxNoCap'] = sandboxNoCap;
    data['winCount'] = winCount;
    data['unlockedTech'] = unlockedTech;
    data['unlockedStash'] = unlockedStash;
    data['unlockedSkill'] = unlockedSkill;
    data['unlockedGoal'] = unlockedGoal;

    data['perks'] = perks;
    data['perkCosts'] = perkCosts;

    // Logic requires valid Maps/Lists as if decoded from JSON
    data['rigs'] = rigs.map((r) => {'id': r.id, 'amount': r.amount}).toList();
    data['research'] = researchNodes
        .map(
          (r) => {
            'id': r.id,
            'isUnlocked': r.isUnlocked,
            'isCompleted': r.isCompleted,
          },
        )
        .toList();

    if (stash != null) {
      data['stash'] = stash;
    }

    data['networkDifficulty'] = networkDifficulty;
    data['blockReward'] = blockReward;
    data['blocksMined'] = blocksMined;
    data['nextHalvingThreshold'] = nextHalvingThreshold;
    data['bitcoinExchangeRate'] = bitcoinExchangeRate;

    // Mirror the real repository, which stamps the save time inside the blob.
    data['last_save_time'] = DateTime.now().millisecondsSinceEpoch;
  }
}
