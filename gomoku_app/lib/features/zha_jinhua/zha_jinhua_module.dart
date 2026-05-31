/// 炸金花注册模块。
library;

import 'package:flutter/material.dart';
import 'package:gomoku_app/core/game_framework/game_definition.dart';
import 'package:gomoku_app/core/game_framework/game_registry.dart';
import 'package:gomoku_app/features/zha_jinhua/zha_jinhua_handler.dart';

class ZhaJinhuaModule {
  static void register() {
    GameRegistry.register(
      definition: const GameDefinition(
        id: 'zha_jinhua',
        displayName: '炸金花',
        icon: Icons.casino,
        subtitle: '三张扑克 · 经典比大小',
      ),
      handlerFactory: (ref, sendMessage) =>
          ZhaJinhuaHandler(ref, sendMessage),
    );
  }
}
