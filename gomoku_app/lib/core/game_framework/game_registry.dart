import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gomoku_app/core/game_framework/game_definition.dart';
import 'package:gomoku_app/core/game_framework/game_handler.dart';
import 'package:gomoku_app/models/network_message.dart';

/// 游戏 handler 工厂函数类型
typedef GameHandlerFactory = GameHandler Function(
  WidgetRef ref,
  void Function(NetworkMessage) sendMessage,
);

class _GameEntry {
  final GameDefinition definition;
  final GameHandlerFactory handlerFactory;

  const _GameEntry(this.definition, this.handlerFactory);
}

/// 游戏注册中心。大厅通过此中心创建游戏 handler，不直接引用游戏类型。
///
/// 新增游戏时只需在 main.dart 中调用 YourModule.register()。
class GameRegistry {
  static final Map<String, _GameEntry> _entries = {};

  /// 注册一个游戏类型
  static void register({
    required GameDefinition definition,
    required GameHandlerFactory handlerFactory,
  }) {
    _entries[definition.id] = _GameEntry(definition, handlerFactory);
  }

  /// 获取游戏定义（用于显示游戏选择 UI）
  static GameDefinition? getDefinition(String id) => _entries[id]?.definition;

  /// 获取所有已注册的游戏定义列表
  static List<GameDefinition> getAll() =>
      _entries.values.map((e) => e.definition).toList();

  /// 创建一个游戏 handler 实例
  static GameHandler createHandler(
    String gameId,
    WidgetRef ref,
    void Function(NetworkMessage) sendMessage,
  ) {
    final entry = _entries[gameId];
    if (entry == null) {
      throw ArgumentError('Unknown game type: $gameId');
    }
    return entry.handlerFactory(ref, sendMessage);
  }
}
