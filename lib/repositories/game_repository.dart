import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/rig.dart';
import '../models/research_node.dart';

class GameRepository {
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
  }) async {
    final prefs = await SharedPreferences.getInstance();

    await prefs.setDouble('wallet', wallet);
    await prefs.setDouble('lifetimeEarnings', lifetimeEarnings);
    await prefs.setInt('govTokens', govTokens);
    await prefs.setInt('spentGovTokens', spentGovTokens);
    await prefs.setInt('chips', chips);

    // Save Perks
    await prefs.setString('perks', jsonEncode(perks));
    await prefs.setString('perkCosts', jsonEncode(perkCosts));

    // Serialize Rigs
    // Using json_serializable generated toJson
    final rigsJson = jsonEncode(rigs.map((r) => r.toJson()).toList());
    await prefs.setString('rigs', rigsJson);

    // Serialize Research
    final researchJson = jsonEncode(
      researchNodes.map((r) => r.toJson()).toList(),
    );
    await prefs.setString('research', researchJson);

    // Save Stash
    if (stash != null) {
      await prefs.setString('stash', jsonEncode(stash));
    }

    // Save Timestamp
    await prefs.setInt('last_save_time', DateTime.now().millisecondsSinceEpoch);

    // Save Economy 2.0
    await prefs.setDouble('networkDifficulty', networkDifficulty);
    await prefs.setDouble('blockReward', blockReward);
    await prefs.setInt('blocksMined', blocksMined);
    await prefs.setInt('nextHalvingThreshold', nextHalvingThreshold);
    await prefs.setDouble('bitcoinExchangeRate', bitcoinExchangeRate);
  }

  Future<Map<String, dynamic>> loadGameState() async {
    final prefs = await SharedPreferences.getInstance();
    final data = <String, dynamic>{};

    data['wallet'] = prefs.getDouble('wallet') ?? 0;
    data['lifetimeEarnings'] = prefs.getDouble('lifetimeEarnings') ?? 0;
    data['govTokens'] = prefs.getInt('govTokens') ?? 0;
    data['spentGovTokens'] = prefs.getInt('spentGovTokens') ?? 0;

    data['networkDifficulty'] = prefs.getDouble('networkDifficulty') ?? 100.0;
    data['blockReward'] = prefs.getDouble('blockReward') ?? 50.0 * 100000000;
    data['blocksMined'] = prefs.getInt('blocksMined') ?? 0;
    data['nextHalvingThreshold'] = prefs.getInt('nextHalvingThreshold') ?? 5000;
    data['bitcoinExchangeRate'] = prefs.getDouble('bitcoinExchangeRate') ?? 1.0;
    data['last_save_time'] = prefs.getInt('last_save_time');

    data['chips'] = prefs.getInt('chips') ?? 0;
    if (prefs.containsKey('stash')) {
      data['stash'] = jsonDecode(prefs.getString('stash')!);
    }

    // Perks
    if (prefs.containsKey('perks')) {
      data['perks'] = jsonDecode(prefs.getString('perks')!);
    }
    if (prefs.containsKey('perkCosts')) {
      data['perkCosts'] = jsonDecode(prefs.getString('perkCosts')!);
    }

    // Rigs
    if (prefs.containsKey('rigs')) {
      data['rigs'] = jsonDecode(prefs.getString('rigs')!);
    }

    // Research
    if (prefs.containsKey('research')) {
      data['research'] = jsonDecode(prefs.getString('research')!);
    }

    return data;
  }

  Future<void> clearSave() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
  }
}
