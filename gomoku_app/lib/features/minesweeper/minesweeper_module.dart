import 'package:flutter/material.dart';
import 'package:gomoku_app/core/game_framework/game_definition.dart';
import 'package:gomoku_app/core/game_framework/game_registry.dart';
import 'package:gomoku_app/features/minesweeper/minesweeper_handler.dart';

class MinesweeperModule {
  static void register() {
    GameRegistry.register(
      definition: const GameDefinition(
        id: 'minesweeper',
        displayName: '扫雷',
        icon: Icons.terrain,
        subtitle: '避开地雷 · 竞速对战',
      ),
      handlerFactory: (ref, sendMessage) =>
          MinesweeperHandler(ref, sendMessage),
    );
  }
}
