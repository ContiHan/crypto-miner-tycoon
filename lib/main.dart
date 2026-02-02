import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'providers/game_logic.dart';
import 'screens/home_screen.dart';

import 'theme/app_theme.dart';

import 'repositories/game_repository.dart';
import 'repositories/settings_repository.dart';
import 'services/economy_service.dart';
import 'services/stash_service.dart';

void main() {
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(
          create: (_) {
            return GameLogic(
              gameRepository: GameRepository(),
              settingsRepository: SettingsRepository(),
              economyService: EconomyService(),
              stashService: StashService(),
            );
          },
        ),
      ],
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Bitcoin Idle Tycoon',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.darkTheme,
      home: const HomeScreen(),
    );
  }
}
