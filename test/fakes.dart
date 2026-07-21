import 'package:crypto_miner_tycoon/repositories/game_repository.dart';
import 'package:crypto_miner_tycoon/repositories/settings_repository.dart';
import 'package:crypto_miner_tycoon/models/rig.dart';
import 'package:crypto_miner_tycoon/models/research_node.dart';
import 'package:crypto_miner_tycoon/services/sound_service.dart';

class FakeSoundService implements SoundService {
  @override
  bool get isMuted => false;

  @override
  void setMuted(bool muted) {}

  @override
  Future<void> playSound(String text) async {}

  @override
  Future<void> playMine() async {}

  @override
  Future<void> playBuy() async {}

  @override
  Future<void> playUnlock() async {}

  @override
  Future<void> playEventGood() async {}

  @override
  Future<void> playEventBad() async {}

  @override
  Future<void> playHalving() async {}
}

class FakeSettingsRepository implements SettingsRepository {
  Map<String, dynamic> data = {
    'sound_enabled': true,
    'show_fiat_prices': false,
  };

  @override
  Future<Map<String, dynamic>> loadSettings() async {
    return data;
  }

  @override
  Future<void> saveSettings({
    required bool soundEnabled,
    required bool showFiatPrices,
  }) async {
    data['sound_enabled'] = soundEnabled;
    data['show_fiat_prices'] = showFiatPrices;
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
  }) async {
    data['wallet'] = wallet;
    data['lifetimeEarnings'] = lifetimeEarnings;
    data['govTokens'] = govTokens;
    data['spentGovTokens'] = spentGovTokens;
    data['chips'] = chips;

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
