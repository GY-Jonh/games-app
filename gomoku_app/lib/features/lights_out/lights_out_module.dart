import 'package:flutter/material.dart';
import 'package:gomoku_app/core/game_framework/game_definition.dart';
import 'package:gomoku_app/core/game_framework/game_registry.dart';
import 'package:gomoku_app/features/lights_out/lights_out_handler.dart';

class LightsOutModule {
  static void register() {
    GameRegistry.register(
      definition: const GameDefinition(
        id: 'lights_out',
        displayName: '点灯游戏',
        icon: Icons.lightbulb_outline,
        subtitle: '点击灯泡，全部熄灭 · 竞速对战',
      ),
      handlerFactory: (ref, sendMessage) =>
          LightsOutHandler(ref, sendMessage),
    );
  }
}
