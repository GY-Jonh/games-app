import 'package:flutter/material.dart';
import 'package:gomoku_app/core/game_framework/game_definition.dart';
import 'package:gomoku_app/core/game_framework/game_registry.dart';
import 'package:gomoku_app/features/game_2048/game_2048_handler.dart';

class Game2048Module {
  static void register() {
    GameRegistry.register(
      definition: const GameDefinition(
        id: 'game_2048',
        displayName: '2048',
        icon: Icons.grid_on,
        subtitle: '滑动合并数字 · 竞速对战',
      ),
      handlerFactory: (ref, sendMessage) =>
          Game2048Handler(ref, sendMessage),
    );
  }
}
