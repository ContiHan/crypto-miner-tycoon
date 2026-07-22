import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
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
  }) async {
    final prefs = await SharedPreferences.getInstance();

    final Map<String, dynamic> state = {
      'version': _schemaVersion,
      'wallet': wallet,
      'lifetimeEarnings': lifetimeEarnings,
      'govTokens': govTokens,
      'spentGovTokens': spentGovTokens,
      'chips': chips,
      'perks': perks,
      'perkCosts': perkCosts,
      'rigs': rigs.map((r) => r.toJson()).toList(),
      'research': researchNodes.map((r) => r.toJson()).toList(),
      'stash': stash,
      'networkDifficulty': networkDifficulty,
      'blockReward': blockReward,
      'blocksMined': blocksMined,
      'nextHalvingThreshold': nextHalvingThreshold,
      'bitcoinExchangeRate': bitcoinExchangeRate,
      'consensus': consensus,
      'lifetimeAtLastSoftFork': lifetimeAtLastSoftFork,
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
      'nextHalvingThreshold': asInt(m['nextHalvingThreshold'], 5000),
      'bitcoinExchangeRate': asDouble(m['bitcoinExchangeRate'], 1.0),
      'consensus': asInt(m['consensus'], 0),
      'lifetimeAtLastSoftFork': asDouble(m['lifetimeAtLastSoftFork'], 0),
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
    data['nextHalvingThreshold'] = prefs.getInt('nextHalvingThreshold') ?? 5000;
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
