import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gomoku_app/core/game_framework/game_handler.dart';
import 'package:gomoku_app/core/utils/device_info.dart';
import 'package:gomoku_app/features/minesweeper/minesweeper_providers.dart';
import 'package:gomoku_app/features/minesweeper/minesweeper_screen.dart';
import 'package:gomoku_app/features/minesweeper/minesweeper_timer.dart';
import 'package:gomoku_app/models/network_message.dart';

class MinesweeperHandler extends GameHandler {
  final WidgetRef ref;
  final void Function(NetworkMessage) _sendMessage;
  bool _isSolo = false;
  int _myPlayerIndex = 0;

  MinesweeperHandler(this.ref, this._sendMessage);

  @override
  void initGame({
    required int myPlayerIndex,
    required String opponentName,
  }) {
    _isSolo = opponentName.isEmpty;
    _myPlayerIndex = myPlayerIndex;
    if (_isSolo) {
      _startSoloGame();
    } else {
      if (myPlayerIndex == 0) {
        _startPvPAsHost(opponentName);
      }
    }
  }

  Future<void> _startSoloGame() async {
    ref.read(minesweeperStateProvider.notifier).setLoading();
    final seed = MinesweeperStateNotifier.generateSeed();
    ref.read(minesweeperStateProvider.notifier).startGame(
      seed: seed,
      isSolo: true,
      selfName: deviceName,
    );
    ref.read(minesweeperTimerProvider.notifier).start();
  }

  void _startPvPAsHost(String opponentName) {
    ref.read(minesweeperStateProvider.notifier).setLoading();
    final seed = MinesweeperStateNotifier.generateSeed();
    // PvP 模式：预生成地雷布局（无首次点击保护），确保双方布局一致
    final mines = MinesweeperStateNotifier.generateMines(seed);
    ref.read(minesweeperStateProvider.notifier).startGameWithMines(
      mines: mines,
      seed: seed,
      isSolo: false,
      selfName: deviceName,
      opponentName: opponentName,
    );
    ref.read(minesweeperTimerProvider.notifier).start();

    _sendMessage(NetworkMessage(
      type: 'minesweeper_board',
      senderId: deviceId,
      payload: {
        'seed': seed,
        'mines': mines,
        'device_name': deviceName,
      },
      timestamp: DateTime.now().millisecondsSinceEpoch,
    ));
  }

  @override
  void handleMessage(NetworkMessage message) {
    switch (message.type) {
      case 'minesweeper_board':
        _handleBoardMessage(message);
        break;
      case 'minesweeper_won':
        _handleOpponentWon(message);
        break;
      case 'minesweeper_hit_mine':
        _handleOpponentHitMine(message);
        break;
      case 'minesweeper_game_over':
        _handleGameOver(message);
        break;
      case 'minesweeper_rematch_request':
        _handleRematchRequest(message);
        break;
      case 'minesweeper_rematch_response':
        _handleRematchResponse(message);
        break;
    }
  }

  @override
  void handleConnectionLost() {
    ref.read(minesweeperTimerProvider.notifier).stop();
    ref.read(minesweeperRematchStatusProvider.notifier).state =
        MinesweeperRematchStatus.none;

    final gameState = ref.read(minesweeperStateProvider);
    if (gameState.status == MinesweeperStatus.playing) {
      ref.read(minesweeperStateProvider.notifier).handleConnectionLost();
    } else {
      ref.read(minesweeperAutoExitProvider.notifier).state = true;
    }
  }

  @override
  Widget buildScreen({
    required String opponentName,
    required void Function(NetworkMessage) onSendMessage,
  }) {
    return MinesweeperScreen(
      opponentName: opponentName,
      onSendMessage: onSendMessage,
    );
  }

  @override
  void dispose() {
    ref.read(minesweeperTimerProvider.notifier).stop();
    ref.read(minesweeperStateProvider.notifier).resetGame();
    ref.read(minesweeperRematchStatusProvider.notifier).state =
        MinesweeperRematchStatus.none;
    ref.read(minesweeperAutoExitProvider.notifier).state = false;
    ref.read(minesweeperToastProvider.notifier).state = null;
  }

  void _handleBoardMessage(NetworkMessage message) {
    if (ref.read(minesweeperStateProvider).status ==
        MinesweeperStatus.playing) {
      return;
    }

    final seed = message.payload['seed'] as int;
    final mines = (message.payload['mines'] as List).cast<int>();
    final opponentName =
        message.payload['device_name'] as String? ?? '对手';

    ref.read(minesweeperStateProvider.notifier).startGameWithMines(
      mines: mines,
      seed: seed,
      isSolo: false,
      selfName: deviceName,
      opponentName: opponentName,
    );
    ref.read(minesweeperTimerProvider.notifier).start();
  }

  void _handleOpponentWon(NetworkMessage message) {
    ref.read(minesweeperStateProvider.notifier).opponentWon();
    ref.read(minesweeperTimerProvider.notifier).stop();
  }

  void _handleOpponentHitMine(NetworkMessage message) {
    ref.read(minesweeperStateProvider.notifier).opponentWon();
    ref.read(minesweeperTimerProvider.notifier).stop();
  }

  void _handleGameOver(NetworkMessage message) {
    final reason = message.payload['reason'] as String? ?? 'unknown';
    if (reason == 'quit' || reason == 'disconnect') {
      ref.read(minesweeperStateProvider.notifier).handleConnectionLost();
    } else if (reason == 'timeout') {
      ref.read(minesweeperStateProvider.notifier).opponentTimeout();
    }
    ref.read(minesweeperTimerProvider.notifier).stop();
  }

  void _handleRematchRequest(NetworkMessage message) {
    if (ref.read(minesweeperStateProvider).status ==
        MinesweeperStatus.playing) {
      return;
    }

    if (ref.read(minesweeperRematchStatusProvider) ==
        MinesweeperRematchStatus.waiting) {
      _sendMessage(NetworkMessage(
        type: 'minesweeper_rematch_response',
        senderId: deviceId,
        payload: {'accepted': true},
        timestamp: DateTime.now().millisecondsSinceEpoch,
      ));
      _restartGame();
    } else {
      ref.read(minesweeperRematchStatusProvider.notifier).state =
          MinesweeperRematchStatus.received;
      ref.read(minesweeperToastProvider.notifier).state = '对方请求了重赛';
    }
  }

  void _handleRematchResponse(NetworkMessage message) {
    final accepted = message.payload['accepted'] as bool? ?? false;
    if (accepted) {
      _restartGame();
    } else {
      ref.read(minesweeperRematchStatusProvider.notifier).state =
          MinesweeperRematchStatus.none;
      ref.read(minesweeperToastProvider.notifier).state = '对方拒绝了重开请求';
    }
  }

  void _restartGame() {
    ref.read(minesweeperStateProvider.notifier).incrementRound();
    ref.read(minesweeperRematchStatusProvider.notifier).state =
        MinesweeperRematchStatus.none;
    ref.read(minesweeperTimerProvider.notifier).reset();

    if (_isSolo) {
      _startSoloGame();
    } else if (_myPlayerIndex == 0) {
      final seed = MinesweeperStateNotifier.generateSeed();
      final opponentName =
          ref.read(minesweeperStateProvider).opponentName;
      // PvP 重赛：同样预生成地雷布局
      final mines = MinesweeperStateNotifier.generateMines(seed);
      ref.read(minesweeperStateProvider.notifier).startGameWithMines(
        mines: mines,
        seed: seed,
        isSolo: false,
        selfName: deviceName,
        opponentName: opponentName,
      );
      ref.read(minesweeperTimerProvider.notifier).start();

      _sendMessage(NetworkMessage(
        type: 'minesweeper_board',
        senderId: deviceId,
        payload: {
          'seed': seed,
          'mines': mines,
          'device_name': deviceName,
        },
        timestamp: DateTime.now().millisecondsSinceEpoch,
      ));
    }
  }
}
