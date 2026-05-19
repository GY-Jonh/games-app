import 'package:flutter/material.dart';
import 'package:gomoku_app/core/game_framework/game_definition.dart';
import 'package:gomoku_app/core/game_framework/game_registry.dart';
import 'package:gomoku_app/features/gomoku/gomoku_handler.dart';

class GomokuModule {
  static void register() {
    GameRegistry.register(
      definition: const GameDefinition(
        id: 'gomoku',
        displayName: '五子棋',
        icon: Icons.grid_on,
        subtitle: '17×17, 五子连珠',
      ),
      handlerFactory: (ref, sendMessage) => GomokuHandler(ref, sendMessage),
    );
  }
}
