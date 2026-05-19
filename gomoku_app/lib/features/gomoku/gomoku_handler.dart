import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gomoku_app/core/constants/game_constants.dart';
import 'package:gomoku_app/core/game_framework/game_handler.dart';
import 'package:gomoku_app/core/utils/device_info.dart';
import 'package:gomoku_app/features/gomoku/gomoku_providers.dart';
import 'package:gomoku_app/features/gomoku/gomoku_screen.dart';
import 'package:gomoku_app/features/gomoku/gomoku_timer.dart';
import 'package:gomoku_app/features/gomoku/models/stone.dart';
import 'package:gomoku_app/models/network_message.dart';

/// 五子棋游戏处理器，实现 GameHandler 接口。
/// 处理五子棋特有的消息（game_move, game_over, rematch 等）。
class GomokuHandler extends GameHandler {
  final WidgetRef ref;
  final void Function(NetworkMessage) _sendMessage;

  GomokuHandler(this.ref, this._sendMessage);

  @override
  void initGame({
    required int myPlayerIndex,
    required String opponentName,
  }) {
    // myPlayerIndex: 0 = 先手执黑, 1 = 后手执白
    final myStone = myPlayerIndex == 0 ? Stone.black : Stone.white;
    ref.read(gomokuStateProvider.notifier).startGame(myStone, opponentName);
  }

  @override
  void handleMessage(NetworkMessage message) {
    switch (message.type) {
      case 'game_move':
        final row = message.payload['row'] as int;
        final col = message.payload['col'] as int;
        final stone = message.payload['stone'] == 1 ? Stone.black : Stone.white;
        ref.read(gomokuStateProvider.notifier).receiveMove(row, col, stone);
        break;

      case 'game_over':
        final reason = message.payload['reason'] as String? ?? 'unknown';
        if (reason == 'quit' || reason == 'disconnect') {
          ref.read(gomokuStateProvider.notifier).endGame();
        } else if (reason == 'timeout') {
          ref.read(gomokuStateProvider.notifier).opponentTimeout();
        }
        break;

      case 'rematch_request':
        _handleRematchRequest(message);
        break;

      case 'rematch_response':
        _handleRematchResponse(message);
        break;
    }
  }

  @override
  void handleConnectionLost() {
    // 停止计时器
    ref.read(gomokuTurnTimerProvider.notifier).stop();

    // 重置邀请和重开状态
    ref.read(gomokuRematchStatusProvider.notifier).state =
        GomokuRematchStatus.none;
    ref.read(gomokuRematchRequestDetailsProvider.notifier).state = null;

    // 通知游戏页面处理
    final gameState = ref.read(gomokuStateProvider);
    if (gameState.status == GameStatus.playing) {
      ref.read(gomokuStateProvider.notifier).endGame();
    } else {
      ref.read(gomokuAutoExitGameProvider.notifier).state = true;
    }
  }

  @override
  Widget buildScreen({
    required String opponentName,
    required void Function(NetworkMessage) onSendMessage,
  }) {
    return GomokuScreen(
      opponentName: opponentName,
      onSendMessage: onSendMessage,
    );
  }

  @override
  void dispose() {
    ref.read(gomokuTurnTimerProvider.notifier).stop();
    ref.read(gomokuStateProvider.notifier).resetGame();
    ref.read(gomokuRematchStatusProvider.notifier).state =
        GomokuRematchStatus.none;
    ref.read(gomokuRematchRequestDetailsProvider.notifier).state = null;
    ref.read(gomokuRematchToastProvider.notifier).state = null;
    ref.read(gomokuAutoExitGameProvider.notifier).state = false;
  }

  // ========== Rematch 处理逻辑 ==========

  void _handleRematchRequest(NetworkMessage message) {
    final fromName =
        message.payload['device_name'] as String? ?? '对方';
    final prevStone =
        message.payload['previous_stone'] as String? ?? 'black';

    // 双方同时请求重开时自动同意
    if (ref.read(gomokuRematchStatusProvider) == GomokuRematchStatus.waiting) {
      _sendMessage(NetworkMessage(
        type: 'rematch_response',
        senderId: deviceId,
        payload: {
          'accepted': true,
          'yourColor': prevStone == 'black' ? 'white' : 'black',
        },
        timestamp: DateTime.now().millisecondsSinceEpoch,
      ));
      final myNewStone = prevStone == 'black'
          ? Stone.black
          : Stone.white;
      final opponentName = ref.read(gomokuStateProvider).opponentName;
      ref.read(gomokuStateProvider.notifier).resetGame();
      ref.read(gomokuStateProvider.notifier)
          .startGame(myNewStone, opponentName);
      ref.read(gomokuRematchStatusProvider.notifier).state =
          GomokuRematchStatus.none;
    } else {
      ref.read(gomokuRematchRequestDetailsProvider.notifier).state =
          GomokuRematchRequestDetails(
        fromName: fromName,
        previousStone: prevStone == 'black'
            ? Stone.black
            : Stone.white,
      );
      ref.read(gomokuRematchStatusProvider.notifier).state =
          GomokuRematchStatus.received;
    }
  }

  void _handleRematchResponse(NetworkMessage message) {
    final accepted =
        message.payload['accepted'] as bool? ?? false;
    if (accepted) {
      final myColor =
          message.payload['yourColor'] as String? ?? 'black';
      final opponentName =
          ref.read(gomokuStateProvider).opponentName;
      ref.read(gomokuStateProvider.notifier).resetGame();
      ref.read(gomokuStateProvider.notifier).startGame(
        myColor == 'black' ? Stone.black : Stone.white,
        opponentName,
      );
      ref.read(gomokuRematchStatusProvider.notifier).state =
          GomokuRematchStatus.none;
    } else {
      ref.read(gomokuRematchStatusProvider.notifier).state =
          GomokuRematchStatus.none;
      ref.read(gomokuRematchRequestDetailsProvider.notifier).state = null;
      ref.read(gomokuRematchToastProvider.notifier).state =
          '对方拒绝了重开请求';
    }
  }
}
