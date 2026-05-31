/// 扑克收集战 — 注册模块。
library;

import 'package:flutter/material.dart';
import 'package:gomoku_app/core/game_framework/game_definition.dart';
import 'package:gomoku_app/core/game_framework/game_registry.dart';
import 'package:gomoku_app/features/card_battle/card_battle_handler.dart';

class CardBattleModule {
  static void register() {
    GameRegistry.register(
      definition: const GameDefinition(
        id: 'card_battle',
        displayName: '扑克收集战',
        icon: Icons.style,
        subtitle: '摸牌对战 · 炸弹管一切',
      ),
      handlerFactory: (ref, sendMessage) =>
          CardBattleHandler(ref, sendMessage),
    );
  }
}
