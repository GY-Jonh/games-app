import 'package:flutter/widgets.dart';
import 'package:gomoku_app/models/network_message.dart';

/// 每个游戏提供一个 GameHandler 实现，大厅通过此接口与游戏交互。
///
/// 使用方式：
/// 1. 邀请接受后调用 [initGame] 初始化游戏状态
/// 2. 游戏中网络消息通过 [handleMessage] 分发
/// 3. 对手断线通过 [handleConnectionLost] 处理
/// 4. 导航到游戏页面时调用 [buildScreen] 获取 Widget
/// 5. 页面 pop 后调用 [dispose] 清理
abstract class GameHandler {
  /// 初始化游戏（邀请接受后调用）。
  /// [myPlayerIndex]: 0 = 先手, 1 = 后手
  void initGame({
    required int myPlayerIndex,
    required String opponentName,
  });

  /// 处理该游戏的网络消息（game_move, game_over, rematch 等）
  void handleMessage(NetworkMessage message);

  /// 处理对手断线
  void handleConnectionLost();

  /// 构建游戏页面 Widget
  Widget buildScreen({
    required String opponentName,
    required void Function(NetworkMessage) onSendMessage,
  });

  /// 页面 pop 后清理
  void dispose();
}
