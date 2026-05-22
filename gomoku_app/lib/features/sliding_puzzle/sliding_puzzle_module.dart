import 'package:flutter/material.dart';
import 'package:gomoku_app/core/game_framework/game_definition.dart';
import 'package:gomoku_app/core/game_framework/game_registry.dart';
import 'package:gomoku_app/features/sliding_puzzle/sliding_puzzle_handler.dart';

class SlidingPuzzleModule {
  static void register() {
    GameRegistry.register(
      definition: const GameDefinition(
        id: 'sliding_puzzle',
        displayName: '数字华容道',
        icon: Icons.grid_view,
        subtitle: '滑动数字归位 · 竞速对战',
      ),
      handlerFactory: (ref, sendMessage) =>
          SlidingPuzzleHandler(ref, sendMessage),
    );
  }
}
