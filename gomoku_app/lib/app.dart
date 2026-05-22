import 'package:flutter/material.dart';
import 'package:gomoku_app/core/theme/app_theme.dart';
import 'package:gomoku_app/features/lobby/lobby_screen.dart';

class GomokuApp extends StatelessWidget {
  const GomokuApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Game Hub',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.theme,
      home: const LobbyScreen(),
    );
  }
}
