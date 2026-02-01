import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:crypto_miner_tycoon/providers/game_logic.dart';
import 'package:crypto_miner_tycoon/screens/home_screen.dart';
import 'package:crypto_miner_tycoon/screens/mining_tab.dart';
import 'package:crypto_miner_tycoon/widgets/news_ticker.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('NewsTicker shows Idle text by default', (WidgetTester tester) async {
    await tester.pumpWidget(
      ChangeNotifierProvider(
        create: (_) => GameLogic(startTimers: false),
        child: const MaterialApp(
          home: Scaffold(body: NewsTicker()),
        ),
      ),
    );
    
    // Use pump instead of pumpAndSettle due to infinite timers
    await tester.pump(const Duration(seconds: 1));

    expect(find.textContaining('MARKET STABLE'), findsOneWidget);
  });

  testWidgets('MiningTab shows Economy stats', (WidgetTester tester) async {
    await tester.pumpWidget(
      ChangeNotifierProvider(
        create: (_) => GameLogic(startTimers: false),
        child: MaterialApp(
          home: Scaffold(
            body: MiningTab(
              onHardFork: () {},
              onBuyRig: (id) {},
            )
          ),
        ),
      ),
    );

    await tester.pump(const Duration(seconds: 1));

    expect(find.textContaining('DIFFICULTY'), findsOneWidget);
    expect(find.textContaining('REWARD'), findsOneWidget);
    expect(find.textContaining('HALVING'), findsOneWidget);
  });
  
  testWidgets('HomeScreen navigation works', (WidgetTester tester) async {
    await tester.pumpWidget(
      ChangeNotifierProvider(
        create: (_) => GameLogic(startTimers: false),
        child: const MaterialApp(
          home: HomeScreen(),
        ),
      ),
    );
    
    await tester.pumpAndSettle(); 
    
    expect(find.byType(MiningTab), findsOneWidget);
    
    final researchIcon = find.byIcon(Icons.science);
    expect(researchIcon, findsOneWidget);
    
    await tester.tap(researchIcon);
    await tester.pump(const Duration(seconds: 1)); 
    
    // Just verify we didn't crash
  });
}
