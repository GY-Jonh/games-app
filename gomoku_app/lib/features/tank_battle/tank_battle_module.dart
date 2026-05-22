/// 坦克大战注册模块。
library;

import 'package:flutter/material.dart';
import 'package:gomoku_app/core/game_framework/game_definition.dart';
import 'package:gomoku_app/core/game_framework/game_registry.dart';
import 'package:gomoku_app/features/tank_battle/tank_battle_handler.dart';

class TankBattleModule {
  static void register() {
    GameRegistry.register(
      definition: const GameDefinition(
        id: 'tank_battle',
        displayName: '坦克大战',
        icon: Icons.shield,
        subtitle: '经典坦克 · 保卫基地',
      ),
      handlerFactory: (ref, sendMessage) =>
          TankBattleHandler(ref, sendMessage),
    );
  }
}
