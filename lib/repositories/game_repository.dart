import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/constants.dart';
import '../models/rig.dart';
import '../models/research_node.dart';

/// Persists the whole game state as a single JSON document.
///
/// The previous implementation spread state across ~15 separate keys written
/// sequentially. A process death mid-save produced a torn state, and a single
/// corrupted key threw an unhandled [FormatException] that bricked the game and
/// then let a blank save overwrite it. This version writes one atomic blob and
/// never throws on load: a corrupted document falls back to defaults instead of
/// crashing, and a schema version is stored for future migrations.
class GameRepository {
  static const String _saveKey = 'game_save_v2';
  static const int _schemaVersion = 2;

  /// Legacy per-key format (schema v1). Read once for migration, then a normal
  /// save rewrites everything into [_saveKey].
  static const List<String> _legacyKeys = [
    'wallet',
    'lifetimeEarnings',
    'govTokens',
    'spentGovTokens',
    'chips',
    'perks',
    'perkCosts',
    'rigs',
    'research',
    'stash',
    'last_save_time',
    'networkDifficulty',
    'blockReward',
    'blocksMined',
    'nextHalvingThreshold',
    'bitcoinExchangeRate',
  ];

  Future<void> saveGameState({
    required double wallet,
    required double lifetimeEarnings,
    required int govTokens,
    required int spentGovTokens,
    required Map<String, int> perks,
    required Map<String, int> perkCosts,
    required List<Rig> rigs,
    required List<ResearchNode> researchNodes,
    Map<String, int> researchCount = const {}, // BLUEPRINTS (permanent)
    List<Map<String, dynamic>> techPresets = const [], // PRESETS (permanent)
    int activeTechPreset = -1,
    bool autoApplyPresets = true,
    Map<String, int> abilityCooldowns = const {}, // ability last-used (wall-clock)
    bool firstBreachDone = false, // THE BREACH: the one-time 0-loss drill is spent
    bool respecUsed = false, // the one-per-era free TECH respec is spent
    Map<String, dynamic> auras = const {}, // equipped stance + auras (loadout)
    List<dynamic> keystones = const [], // equipped keystones (≤2, loadout)
    List<dynamic> firmware = const [], // equipped Rig Firmware loadout
    // Economy 2.0
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
    bool unlockedTech = false,
    bool unlockedStash = false,
    bool unlockedSkill = false,
    bool unlockedGoal = false,
    int eventsSeen = 0,
    List<String> unlockedRigs = const [],
    Map<String, dynamic> rigSnap = const {},
    bool speedRunActive = false,
    int speedRunStartMs = 0,
    double speedRunMinedSats = 0,
    int speedRunBestMs = 0,
    Map<String, dynamic> speedRunBestByClass = const {},
    int speedRunLastMs = 0,
  }) async {
    final prefs = await SharedPreferences.getInstance();

    // jsonEncode throws on Infinity/NaN. networkDifficulty legitimately becomes
    // Infinity at the supply cap (and it's a display-only value recomputed on
    // load), so coerce every double defensively — a non-finite value must never
    // brick the save.
    double fin(double v, [double fallback = 0]) => v.isFinite ? v : fallback;

    final Map<String, dynamic> state = {
      'version': _schemaVersion,
      'wallet': fin(wallet),
      'lifetimeEarnings': fin(lifetimeEarnings),
      'govTokens': govTokens,
      'spentGovTokens': spentGovTokens,
      'chips': chips,
      'perks': perks,
      'perkCosts': perkCosts,
      'rigs': rigs.map((r) => r.toJson()).toList(),
      'research': researchNodes.map((r) => r.toJson()).toList(),
      'researchCount': researchCount,
      'techPresets': techPresets,
      'activeTechPreset': activeTechPreset,
      'autoApplyPresets': autoApplyPresets,
      'abilityCooldowns': abilityCooldowns,
      'firstBreachDone': firstBreachDone,
      'respecUsed': respecUsed,
      'auras': auras,
      'keystones': keystones,
      'firmware': firmware,
      'stash': stash,
      'networkDifficulty': fin(networkDifficulty),
      'blockReward': fin(blockReward),
      'blocksMined': blocksMined,
      'nextHalvingThreshold': nextHalvingThreshold,
      'bitcoinExchangeRate': fin(bitcoinExchangeRate, 1.0),
      'consensus': consensus,
      'lifetimeAtLastSoftFork': fin(lifetimeAtLastSoftFork),
      'genesisBlocks': genesisBlocks,
      'totalGovTokensEver': fin(totalGovTokensEver),
      'govTokensEverAtLastNewChain': fin(govTokensEverAtLastNewChain),
      'achievements': achievements,
      'claimedAchievements': claimedAchievements,
      'hardForkCount': hardForkCount,
      'softForkCount': softForkCount,
      'newChainCount': newChainCount,
      'cratesOpened': cratesOpened,
      'casinoSpins': casinoSpins,
      'casinoJackpots': casinoJackpots,
      'casinoWindowNet': fin(casinoWindowNet),
      'casinoWindowStartMs': casinoWindowStartMs,
      'currentClass': currentClass,
      'mastery': mastery,
      'lifetimeEverSats': fin(lifetimeEverSats),
      'hasWonGame': hasWonGame,
      'unlockedTech': unlockedTech,
      'unlockedStash': unlockedStash,
      'unlockedSkill': unlockedSkill,
      'unlockedGoal': unlockedGoal,
      'eventsSeen': eventsSeen,
      'unlockedRigs': unlockedRigs,
      'rigSnap': rigSnap,
      'speedRunActive': speedRunActive,
      'speedRunStartMs': speedRunStartMs,
      'speedRunMinedSats': fin(speedRunMinedSats),
      'speedRunBestMs': speedRunBestMs,
      'speedRunBestByClass': speedRunBestByClass,
      'speedRunLastMs': speedRunLastMs,
      'last_save_time': DateTime.now().millisecondsSinceEpoch,
    };

    // Single write => atomic. Either the whole new state lands or the previous
    // one is kept intact; a torn/partial save is impossible.
    await prefs.setString(_saveKey, jsonEncode(state));
  }

  Future<Map<String, dynamic>> loadGameState() async {
    final prefs = await SharedPreferences.getInstance();

    // Preferred: v2 single-blob format.
    final raw = prefs.getString(_saveKey);
    if (raw != null) {
      try {
        final decoded = jsonDecode(raw);
        if (decoded is Map) {
          return _normalize(Map<String, dynamic>.from(decoded));
        }
      } catch (e) {
        debugPrint('GameRepository: corrupted save blob ignored: $e');
        // Fall through to legacy / defaults rather than crashing the game.
      }
    }

    // Fallback: migrate a legacy (v1) per-key save if one exists.
    return _normalize(_loadLegacy(prefs));
  }

  /// Reads just the last-save timestamp without materialising full state.
  /// Used by the resume path to reconcile background time.
  Future<int?> readLastSaveTime() async {
    final data = await loadGameState();
    final t = data['last_save_time'];
    return t is int ? t : null;
  }

  Future<void> clearSave() async {
    final prefs = await SharedPreferences.getInstance();
    // Remove only game-state keys. User settings (sound_enabled,
    // show_fiat_prices) live in the same store and must survive a reset.
    await prefs.remove(_saveKey);
    for (final key in _legacyKeys) {
      await prefs.remove(key);
    }
  }

  /// Coerces a decoded document into the exact shape/types GameLogic expects.
  /// JSON does not distinguish int from double, so numeric fields are forced to
  /// the type the caller assigns them to (prevents runtime "int is not double").
  Map<String, dynamic> _normalize(Map<String, dynamic> m) {
    double asDouble(dynamic v, double fallback) =>
        v is num ? v.toDouble() : fallback;
    int asInt(dynamic v, int fallback) => v is num ? v.toInt() : fallback;

    final normalized = <String, dynamic>{
      'wallet': asDouble(m['wallet'], 0),
      'lifetimeEarnings': asDouble(m['lifetimeEarnings'], 0),
      'govTokens': asInt(m['govTokens'], 0),
      'spentGovTokens': asInt(m['spentGovTokens'], 0),
      'chips': asInt(m['chips'], 0),
      'networkDifficulty': asDouble(m['networkDifficulty'], 100.0),
      'blockReward': asDouble(m['blockReward'], 50.0 * 100000000),
      'blocksMined': asInt(m['blocksMined'], 0),
      'nextHalvingThreshold':
          asInt(m['nextHalvingThreshold'], GameConstants.halvingFirstThreshold),
      'bitcoinExchangeRate': asDouble(m['bitcoinExchangeRate'], 1.0),
      'consensus': asInt(m['consensus'], 0),
      'lifetimeAtLastSoftFork': asDouble(m['lifetimeAtLastSoftFork'], 0),
      'genesisBlocks': asInt(m['genesisBlocks'], 0),
      // Tier-3 accumulator: for saves predating this field, seed it from the
      // player's current tokens so their New-Blockchain progress isn't lost.
      'totalGovTokensEver': m.containsKey('totalGovTokensEver')
          ? asDouble(m['totalGovTokensEver'], 0)
          : (asInt(m['govTokens'], 0) + asInt(m['spentGovTokens'], 0)).toDouble(),
      'govTokensEverAtLastNewChain':
          asDouble(m['govTokensEverAtLastNewChain'], 0),
      // For saves predating these counters, proxy the "first-action" state from
      // persisted progress so the first-fork achievements still grandfather
      // (GovTokens only come from Hard Forks; Consensus only from Soft Forks;
      // Genesis Blocks only from New Blockchains). Exact historical counts are
      // unrecoverable and re-earn naturally.
      'hardForkCount': m.containsKey('hardForkCount')
          ? asInt(m['hardForkCount'], 0)
          : ((asInt(m['govTokens'], 0) + asInt(m['spentGovTokens'], 0) > 0 ||
                  asDouble(m['totalGovTokensEver'], 0) > 0)
              ? 1
              : 0),
      'softForkCount': m.containsKey('softForkCount')
          ? asInt(m['softForkCount'], 0)
          : ((asInt(m['consensus'], 0) > 0 ||
                  asDouble(m['lifetimeAtLastSoftFork'], 0) > 0)
              ? 1
              : 0),
      'newChainCount': m.containsKey('newChainCount')
          ? asInt(m['newChainCount'], 0)
          : (asInt(m['genesisBlocks'], 0) > 0 ? 1 : 0),
      'cratesOpened': asInt(m['cratesOpened'], 0),
      'casinoSpins': asInt(m['casinoSpins'], 0),
      'casinoJackpots': asInt(m['casinoJackpots'], 0),
      'casinoWindowNet': asDouble(m['casinoWindowNet'], 0),
      'casinoWindowStartMs': asInt(m['casinoWindowStartMs'], 0),
      // RPG class + Mastery (Phase 3). Class name is a plain string; ClassManager
      // maps unknown names back to Prospector. Mastery is a {className: xp} map.
      'currentClass':
          m['currentClass'] is String ? m['currentClass'] : 'prospector',
      'mastery': m['mastery'] is Map ? m['mastery'] : const {},
      // THE LAST SATOSHI endgame. `lifetimeEverSats` is now a cosmetic lifetime
      // stat (legacy saves without it seed from lifetimeEarnings). The win latches
      // the moment a single era fills the 21M cap — GameLogic.loadGame() also
      // re-latches it defensively for any legacy save already at the ceiling.
      // Dropped fields (sandboxNoCap, winCount) from the retired sandbox/NG+ are
      // ignored on load.
      'lifetimeEverSats': m.containsKey('lifetimeEverSats')
          ? asDouble(m['lifetimeEverSats'], 0)
          : asDouble(m['lifetimeEarnings'], 0),
      'hasWonGame': (m['hasWonGame'] == true) ||
          (asDouble(m['lifetimeEarnings'], 0) >= GameConstants.maxSupplySats),
      // Progressive-disclosure tab unlocks (sticky bools; default false, then
      // GameLogic re-derives from loaded progress silently).
      'unlockedTech': m['unlockedTech'] == true,
      'unlockedStash': m['unlockedStash'] == true,
      'unlockedSkill': m['unlockedSkill'] == true,
      'unlockedGoal': m['unlockedGoal'] == true,
      'eventsSeen': asInt(m['eventsSeen'] ?? m['bullRunsSeen'], 0),
      'speedRunActive': m['speedRunActive'] == true,
      'speedRunStartMs': asInt(m['speedRunStartMs'], 0),
      'speedRunMinedSats': asDouble(m['speedRunMinedSats'], 0),
      'speedRunBestMs': asInt(m['speedRunBestMs'], 0),
      if (m['speedRunBestByClass'] is Map)
        'speedRunBestByClass': m['speedRunBestByClass'],
      'speedRunLastMs': asInt(m['speedRunLastMs'], 0),
      'last_save_time': m['last_save_time'] is num
          ? (m['last_save_time'] as num).toInt()
          : null,
    };

    // Collections are optional; GameLogic guards each with containsKey.
    if (m['perks'] != null) normalized['perks'] = m['perks'];
    if (m['perkCosts'] != null) normalized['perkCosts'] = m['perkCosts'];
    if (m['rigs'] != null) normalized['rigs'] = m['rigs'];
    if (m['research'] != null) normalized['research'] = m['research'];
    if (m['stash'] != null) normalized['stash'] = m['stash'];
    if (m['achievements'] != null) normalized['achievements'] = m['achievements'];
    if (m['claimedAchievements'] != null) {
      normalized['claimedAchievements'] = m['claimedAchievements'];
    }
    if (m['unlockedRigs'] != null) normalized['unlockedRigs'] = m['unlockedRigs'];
    if (m['rigSnap'] != null) normalized['rigSnap'] = m['rigSnap'];
    // BLUEPRINTS (Phase 3): permanent per-node re-tech counts (survive resets).
    if (m['researchCount'] != null) {
      normalized['researchCount'] = m['researchCount'];
    }
    // PRESETS (Phase 3): saved TECH builds + active index + auto-apply flag.
    if (m['techPresets'] != null) normalized['techPresets'] = m['techPresets'];
    if (m['activeTechPreset'] != null) {
      normalized['activeTechPreset'] = m['activeTechPreset'];
    }
    if (m['autoApplyPresets'] != null) {
      normalized['autoApplyPresets'] = m['autoApplyPresets'];
    }
    if (m['abilityCooldowns'] != null) {
      normalized['abilityCooldowns'] = m['abilityCooldowns'];
    }
    normalized['firstBreachDone'] = m['firstBreachDone'] == true;
    normalized['respecUsed'] = m['respecUsed'] == true;
    if (m['auras'] != null) normalized['auras'] = m['auras'];
    if (m['keystones'] != null) normalized['keystones'] = m['keystones'];
    if (m['firmware'] != null) normalized['firmware'] = m['firmware'];

    return normalized;
  }

  Map<String, dynamic> _loadLegacy(SharedPreferences prefs) {
    final data = <String, dynamic>{};

    data['wallet'] = prefs.getDouble('wallet') ?? 0.0;
    data['lifetimeEarnings'] = prefs.getDouble('lifetimeEarnings') ?? 0.0;
    data['govTokens'] = prefs.getInt('govTokens') ?? 0;
    data['spentGovTokens'] = prefs.getInt('spentGovTokens') ?? 0;
    data['chips'] = prefs.getInt('chips') ?? 0;

    data['networkDifficulty'] = prefs.getDouble('networkDifficulty') ?? 100.0;
    data['blockReward'] = prefs.getDouble('blockReward') ?? 50.0 * 100000000;
    data['blocksMined'] = prefs.getInt('blocksMined') ?? 0;
    data['nextHalvingThreshold'] = prefs.getInt('nextHalvingThreshold') ??
        GameConstants.halvingFirstThreshold;
    data['bitcoinExchangeRate'] = prefs.getDouble('bitcoinExchangeRate') ?? 1.0;
    data['last_save_time'] = prefs.getInt('last_save_time');

    // Each decode is isolated: one corrupt key no longer takes down the load.
    data['stash'] = _tryDecode(prefs.getString('stash'));
    data['perks'] = _tryDecode(prefs.getString('perks'));
    data['perkCosts'] = _tryDecode(prefs.getString('perkCosts'));
    data['rigs'] = _tryDecode(prefs.getString('rigs'));
    data['research'] = _tryDecode(prefs.getString('research'));

    return data;
  }

  dynamic _tryDecode(String? raw) {
    if (raw == null) return null;
    try {
      return jsonDecode(raw);
    } catch (e) {
      debugPrint('GameRepository: dropping corrupted legacy value: $e');
      return null;
    }
  }
}
