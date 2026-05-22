import 'package:flutter/material.dart';
import 'package:gomoku_app/core/game_framework/game_definition.dart';
import 'package:gomoku_app/core/game_framework/game_registry.dart';
import 'package:gomoku_app/features/memory_match/memory_match_handler.dart';

class MemoryMatchModule {
  static void register() {
    GameRegistry.register(
      definition: const GameDefinition(
        id: 'memory_match',
        displayName: '记忆翻牌',
        icon: Icons.style,
        subtitle: '翻牌配对记忆 · 竞速对战',
      ),
      handlerFactory: (ref, sendMessage) =>
          MemoryMatchHandler(ref, sendMessage),
    );
  }
}
