import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gomoku_app/core/game_framework/game_handler.dart';
import 'package:gomoku_app/core/utils/device_info.dart';
import 'package:gomoku_app/features/spot_diff/models/spot_diff_set.dart';
import 'package:gomoku_app/features/spot_diff/services/spot_diff_image_service.dart';
import 'package:gomoku_app/features/spot_diff/spot_diff_providers.dart';
import 'package:gomoku_app/features/spot_diff/spot_diff_screen.dart';
import 'package:gomoku_app/features/spot_diff/spot_diff_timer.dart';
import 'package:gomoku_app/models/network_message.dart';

/// 找茬游戏处理器，实现 GameHandler 接口。
class SpotDiffHandler extends GameHandler {
  final WidgetRef ref;
  final void Function(NetworkMessage) _sendMessage;
  bool _isSolo = false;

  SpotDiffHandler(this.ref, this._sendMessage);

  @override
  void initGame({
    required int myPlayerIndex,
    required String opponentName,
  }) {
    _isSolo = opponentName.isEmpty;
    if (_isSolo) {
      // Solo 模式：直接加载图集
      _loadGameSet();
    } else {
      // PvP 模式：Host (myPlayerIndex==0) 加载图集并发给对手
      // Guest (myPlayerIndex==1) 等待接收 spot_diff_set_selected
      if (myPlayerIndex == 0) {
        loadAndSendSet(opponentName);
      }
    }
  }

  Future<void> _loadGameSet() async {
    ref.read(spotDiffStateProvider.notifier).setLoading();
    try {
      final service = SpotDiffImageService();
      final sets = await service.getTodaySets();
      if (sets.isEmpty) {
        ref.read(spotDiffToastProvider.notifier).state = '暂无可用图集';
        ref.read(spotDiffAutoExitProvider.notifier).state = true;
        return;
      }
      // 随机选一套
      final randomIndex = DateTime.now().millisecondsSinceEpoch % sets.length;
      final set = sets[randomIndex];
      ref.read(spotDiffStateProvider.notifier).startGame(
        set,
        isSolo: true,
        selfName: deviceName,
      );
      ref.read(spotDiffTimerProvider.notifier).start();
    } catch (_) {
      ref.read(spotDiffToastProvider.notifier).state = '加载图集失败';
    }
  }

  @override
  void handleMessage(NetworkMessage message) {
    switch (message.type) {
      case 'spot_diff_set_selected':
        _handleSetSelected(message);
        break;
      case 'spot_diff_found':
        final diffIndex = message.payload['diffIndex'] as int;
        ref.read(spotDiffStateProvider.notifier).opponentFoundDifference(diffIndex);
        break;
      case 'spot_diff_game_over':
        final reason = message.payload['reason'] as String? ?? 'unknown';
        if (reason == 'quit' || reason == 'disconnect') {
          ref.read(spotDiffStateProvider.notifier).handleConnectionLost();
        } else if (reason == 'timeout') {
          ref.read(spotDiffStateProvider.notifier).opponentTimeout();
        }
        break;
      case 'spot_diff_rematch_request':
        _handleRematchRequest(message);
        break;
      case 'spot_diff_rematch_response':
        _handleRematchResponse(message);
        break;
    }
  }

  @override
  void handleConnectionLost() {
    ref.read(spotDiffTimerProvider.notifier).stop();
    ref.read(spotDiffRematchStatusProvider.notifier).state =
        SpotDiffRematchStatus.none;

    final gameState = ref.read(spotDiffStateProvider);
    if (gameState.status == SpotDiffGameStatus.playing) {
      ref.read(spotDiffStateProvider.notifier).handleConnectionLost();
    } else {
      ref.read(spotDiffAutoExitProvider.notifier).state = true;
    }
  }

  @override
  Widget buildScreen({
    required String opponentName,
    required void Function(NetworkMessage) onSendMessage,
  }) {
    return SpotDiffScreen(
      opponentName: opponentName,
      onSendMessage: onSendMessage,
    );
  }

  @override
  void dispose() {
    ref.read(spotDiffTimerProvider.notifier).stop();
    ref.read(spotDiffStateProvider.notifier).resetGame();
    ref.read(spotDiffRematchStatusProvider.notifier).state =
        SpotDiffRematchStatus.none;
    ref.read(spotDiffAutoExitProvider.notifier).state = false;
    ref.read(spotDiffToastProvider.notifier).state = null;
  }

  // ========== PvP Set Sync ==========

  void _handleSetSelected(NetworkMessage message) {
    final setJson = message.payload['set'] as Map<String, dynamic>;
    try {
      final set = SpotDiffSet.fromJson(setJson);
      final opponentName = message.payload['device_name'] as String? ?? '对手';
      ref.read(spotDiffStateProvider.notifier).startGame(
        set,
        isSolo: false,
        selfName: deviceName,
        opponentName: opponentName,
      );
      ref.read(spotDiffTimerProvider.notifier).start();
    } catch (_) {
      ref.read(spotDiffToastProvider.notifier).state = '图集同步失败';
    }
  }

  /// Host 加载图集并发给对手
  Future<void> loadAndSendSet(String opponentName) async {
    ref.read(spotDiffStateProvider.notifier).setLoading();
    try {
      final service = SpotDiffImageService();
      final sets = await service.getTodaySets();
      if (sets.isEmpty) {
        ref.read(spotDiffToastProvider.notifier).state = '暂无可用图集';
        ref.read(spotDiffAutoExitProvider.notifier).state = true;
        return;
      }
      // 随机选一套
      final randomIndex = DateTime.now().millisecondsSinceEpoch % sets.length;
      final set = sets[randomIndex];
      ref.read(spotDiffStateProvider.notifier).startGame(
        set,
        isSolo: false,
        selfName: deviceName,
        opponentName: opponentName,
      );
      ref.read(spotDiffTimerProvider.notifier).start();

      _sendMessage(NetworkMessage(
        type: 'spot_diff_set_selected',
        senderId: deviceId,
        payload: {
          'set': set.toJson(),
          'device_name': deviceName,
        },
        timestamp: DateTime.now().millisecondsSinceEpoch,
      ));
    } catch (_) {
      ref.read(spotDiffToastProvider.notifier).state = '加载图集失败';
    }
  }

  // ========== Rematch Logic ==========

  void _handleRematchRequest(NetworkMessage message) {
    if (ref.read(spotDiffRematchStatusProvider) ==
        SpotDiffRematchStatus.waiting) {
      // 双方同时请求重开，自动同意
      _sendMessage(NetworkMessage(
        type: 'spot_diff_rematch_response',
        senderId: deviceId,
        payload: {'accepted': true},
        timestamp: DateTime.now().millisecondsSinceEpoch,
      ));
      _restartGame();
    } else {
      ref.read(spotDiffRematchStatusProvider.notifier).state =
          SpotDiffRematchStatus.received;
      ref.read(spotDiffToastProvider.notifier).state = '对方请求了重赛';
    }
  }

  void _handleRematchResponse(NetworkMessage message) {
    final accepted = message.payload['accepted'] as bool? ?? false;
    if (accepted) {
      _restartGame();
    } else {
      ref.read(spotDiffRematchStatusProvider.notifier).state =
          SpotDiffRematchStatus.none;
      ref.read(spotDiffToastProvider.notifier).state = '对方拒绝了重开请求';
    }
  }

  void _restartGame() {
    ref.read(spotDiffStateProvider.notifier).incrementRound();
    ref.read(spotDiffRematchStatusProvider.notifier).state =
        SpotDiffRematchStatus.none;
    // 重新加载图集
    _loadGameSet();
  }
}
