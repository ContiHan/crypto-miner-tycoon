import 'dart:async';
import 'dart:math';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/rig.dart';

class GameLogic with ChangeNotifier {
  double wallet = 0;
  double lifetimeEarnings = 0;
  
  List<Rig> rigs = [
    Rig(id: 'cpu_rig', name: 'Starter CPU Rig', baseCost: 10, baseHashRate: 0.1),
    Rig(id: 'gpu_rig', name: 'GPU Rack', baseCost: 150, baseHashRate: 2.0),
    Rig(id: 'asic_rig', name: 'ASIC Miner', baseCost: 1200, baseHashRate: 25.0),
    Rig(id: 'quantum', name: 'Quantum Computer', baseCost: 15000, baseHashRate: 500.0),
  ];

  int govTokens = 0;
  
  // 10% bonus per token
  double get prestigeMultiplier => 1.0 + (govTokens * 0.10);

  Timer? _gameTimer;

  GameLogic() {
    loadGame().then((_) {
      _startGameLoop();
    });
  }

  void _startGameLoop() {
    _gameTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      _mine();
    });
    
    // Auto-Save every 30 seconds
    Timer.periodic(const Duration(seconds: 30), (timer) {
      _saveGame();
      debugPrint('Auto-Saved Game');
    });
  }

  void _mine() {
    double totalHashRate = rigs.fold(0, (sum, rig) => sum + rig.totalHashRate);
    if (totalHashRate > 0) {
      double income = totalHashRate * prestigeMultiplier;
      wallet += income;
      lifetimeEarnings += income;
      notifyListeners();
    }
  }
  
  // Calculate tokens available to claim based on run earnings
  int get pendingGovTokens {
    if (lifetimeEarnings < 1000) return 0;
    // Formula: Sqrt(Earnings / 1000)
    return (sqrt(lifetimeEarnings / 1000).floor());
  }

  void hardFork() {
    int tokensToClaim = pendingGovTokens;
    if (tokensToClaim <= 0) return;

    govTokens += tokensToClaim;
    
    // Reset Progress
    wallet = 0;
    lifetimeEarnings = 0;
    for (var rig in rigs) {
      rig.amount = 0;
    }
    
    notifyListeners();
  }

  void clickMine() {
    wallet += 1 * prestigeMultiplier;
    lifetimeEarnings += 1 * prestigeMultiplier;
    notifyListeners();
  }

  void buyRig(String rigId) {
    int index = rigs.indexWhere((r) => r.id == rigId);
    if (index != -1) {
      Rig rig = rigs[index];
      if (wallet >= rig.currentCost) {
        wallet -= rig.currentCost;
        rig.amount++;
        notifyListeners();
        _saveGame();
      }
    }
  }

  // PERSISTENCE
  Future<void> _saveGame() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('wallet', wallet);
    await prefs.setDouble('lifetimeEarnings', lifetimeEarnings);
    await prefs.setInt('govTokens', govTokens);
    
    // Serialize Rigs
    final rigsJson = jsonEncode(rigs.map((r) => r.toJson()).toList());
    await prefs.setString('rigs', rigsJson);
    
    // Save Timestamp
    await prefs.setInt('last_save_time', DateTime.now().millisecondsSinceEpoch);
  }

  Future<void> loadGame() async {
    final prefs = await SharedPreferences.getInstance();
    wallet = prefs.getDouble('wallet') ?? 0;
    lifetimeEarnings = prefs.getDouble('lifetimeEarnings') ?? 0;
    govTokens = prefs.getInt('govTokens') ?? 0;

    final rigsString = prefs.getString('rigs');
    if (rigsString != null) {
      final List<dynamic> decoded = jsonDecode(rigsString);
      for (var jsonItem in decoded) {
        final id = jsonItem['id'];
        final amount = jsonItem['amount'];
        
        // Update local rig list
        final index = rigs.indexWhere((r) => r.id == id);
        if (index != -1) {
          rigs[index].amount = amount;
        }
      }
    }
    
    // Offline Earnings Logic
    final lastSaveTime = prefs.getInt('last_save_time');
    if (lastSaveTime != null) {
      final now = DateTime.now().millisecondsSinceEpoch;
      final diffSeconds = (now - lastSaveTime) ~/ 1000;
      
      if (diffSeconds > 10) { // Only count if away for more than 10 seconds
        double totalHashRate = rigs.fold(0, (sum, rig) => sum + rig.totalHashRate);
        if (totalHashRate > 0) {
           double offlineEarnings = diffSeconds * totalHashRate * prestigeMultiplier;
           wallet += offlineEarnings;
           lifetimeEarnings += offlineEarnings;
           debugPrint('Offline for $diffSeconds s. Earned $offlineEarnings');
           // Note: We might want to expose this to UI to show a dialog
           offlineEarningsAmount = offlineEarnings;
        }
      }
    }
    
    notifyListeners();
  }
  
  // Temporary storage for UI dialog
  double? offlineEarningsAmount;
  
  void clearOfflineEarnings() {
    offlineEarningsAmount = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _gameTimer?.cancel();
    super.dispose();
  }
}
