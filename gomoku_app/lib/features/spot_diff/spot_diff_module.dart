import 'package:flutter/material.dart';
import 'package:gomoku_app/core/game_framework/game_definition.dart';
import 'package:gomoku_app/core/game_framework/game_registry.dart';
import 'package:gomoku_app/features/spot_diff/spot_diff_handler.dart';

class SpotDiffModule {
  static void register() {
    GameRegistry.register(
      definition: const GameDefinition(
        id: 'spot_diff',
        displayName: '一起来找茬',
        icon: Icons.visibility,
        subtitle: '双图找不同 · 抢答对战',
      ),
      handlerFactory: (ref, sendMessage) => SpotDiffHandler(ref, sendMessage),
    );
  }
}
