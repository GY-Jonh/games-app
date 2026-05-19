import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gomoku_app/core/constants/game_constants.dart';
import 'package:gomoku_app/core/theme/app_theme.dart';
import 'package:gomoku_app/core/utils/device_info.dart';
import 'package:gomoku_app/features/gomoku/gomoku_providers.dart';
import 'package:gomoku_app/features/gomoku/gomoku_timer.dart';
import 'package:gomoku_app/features/gomoku/models/stone.dart';
import 'package:gomoku_app/features/gomoku/widgets/gomoku_board_widget.dart';
import 'package:gomoku_app/features/gomoku/widgets/gomoku_info_bar.dart';
import 'package:gomoku_app/features/gomoku/widgets/gomoku_game_over_dialog.dart';
import 'package:gomoku_app/models/network_message.dart';

class GomokuScreen extends ConsumerWidget {
  final String opponentName;
  final void Function(NetworkMessage message) onSendMessage;

  const GomokuScreen({
    super.key,
    required this.opponentName,
    required this.onSendMessage,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final gameState = ref.watch(gomokuStateProvider);
    final rematchStatus = ref.watch(gomokuRematchStatusProvider);
    final rematchDetails = ref.watch(gomokuRematchRequestDetailsProvider);
    final turnTimer = ref.watch(gomokuTurnTimerProvider);

    // 监听回合变化以管理计时器
    ref.listen<GomokuState>(gomokuStateProvider, (prev, next) {
      if (prev == null) return;
      final wasPlaying = prev.status == GameStatus.playing;
      final isPlaying = next.status == GameStatus.playing;

      // 游戏结束时停止计时器
      if (wasPlaying && !isPlaying) {
        ref.read(gomokuTurnTimerProvider.notifier).stop();
        return;
      }

      // 回合切换时启停计时器
      if (isPlaying && prev.isMyTurn != next.isMyTurn) {
        if (next.isMyTurn) {
          ref.read(gomokuTurnTimerProvider.notifier).start();
        } else {
          ref.read(gomokuTurnTimerProvider.notifier).stop();
        }
      }
    });

    // 监听计时器归零 → 超时判负
    ref.listen<int>(gomokuTurnTimerProvider, (prev, next) {
      if (prev != null && prev > 0 && next == 0) {
        final gs = ref.read(gomokuStateProvider);
        if (gs.status == GameStatus.playing) {
          ref.read(gomokuStateProvider.notifier).timeout();
          onSendMessage(NetworkMessage(
            type: 'game_over',
            senderId: deviceId,
            payload: {'reason': 'timeout'},
            timestamp: DateTime.now().millisecondsSinceEpoch,
          ));
        }
      }
    });

    // 监听重开相关的 toast 消息（如对方拒绝）并在本页面显示
    ref.listen<String?>(gomokuRematchToastProvider, (prev, next) {
      if (next != null) {
        ref.read(gomokuRematchToastProvider.notifier).state = null;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(next),
            duration: const Duration(seconds: 2),
          ),
        );
        // 收到对方拒绝/取消后，延迟一点返回大厅让 SnackBar 可见
        Future.delayed(const Duration(milliseconds: 500), () {
          if (context.mounted) {
            final navigator = Navigator.of(context);
            if (navigator.canPop()) {
              navigator.pop();
            }
          }
        });
      }
    });

    // 对方断线后自动返回大厅
    ref.listen<bool>(gomokuAutoExitGameProvider, (prev, next) {
      if (next == true) {
        ref.read(gomokuAutoExitGameProvider.notifier).state = false;
        final currentState = ref.read(gomokuStateProvider);
        // 如果游戏已结束（已有结果显示面板），让用户手动操作，防止双重 pop 导致黑屏
        if (currentState.status == GameStatus.won ||
            currentState.status == GameStatus.lost ||
            currentState.status == GameStatus.draw ||
            currentState.status == GameStatus.surrendered ||
            currentState.status == GameStatus.disconnected) {
          return;
        }
        // 自动退出前显示断线提示
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('连接已断开'),
            duration: const Duration(seconds: 2),
          ),
        );
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (context.mounted) {
            final navigator = Navigator.of(context);
            if (navigator.canPop()) {
              navigator.pop();
            }
          }
        });
      }
    });

    // 确保首次进入时如果已是己方回合，计时器正常启动
    if (gameState.isMyTurn && gameState.status == GameStatus.playing) {
      ref.read(gomokuTurnTimerProvider.notifier).startIfNotRunning();
    }

    return PopScope(
      canPop: gameState.status != GameStatus.playing,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && gameState.status == GameStatus.playing) {
          _showExitConfirm(context, ref);
        }
      },
      child: Scaffold(
        appBar: AppBar(
          toolbarHeight: 40,
          title: Text(opponentName),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () {
              if (gameState.status == GameStatus.playing) {
                _showExitConfirm(context, ref);
              } else {
                Navigator.of(context).pop();
              }
            },
          ),
        ),
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
            child: Column(
              children: [
                GomokuInfoBar(
                  playerName: '我',
                  opponentName: opponentName,
                  myStone: gameState.myStone ?? Stone.black,
                  currentTurn: gameState.currentTurn,
                  moveCount: gameState.moveCount,
                  isMyTurn: gameState.isMyTurn,
                  timeRemaining: turnTimer,
                ),
                const SizedBox(height: 4),
                Expanded(
                  child: GomokuBoardWidget(
                    board: gameState.board,
                    isMyTurn: gameState.isMyTurn &&
                        gameState.status == GameStatus.playing,
                    selectedRow: gameState.selectedRow,
                    selectedCol: gameState.selectedCol,
                    myStone: gameState.myStone,
                    lastMoveRow: gameState.lastMoveRow,
                    lastMoveCol: gameState.lastMoveCol,
                    onTap: (row, col) {
                      final notifier = ref.read(gomokuStateProvider.notifier);
                      if (!notifier.isValidMove(row, col)) return;

                      // 未选中任何位置 -> 选中该位置（预览）
                      if (gameState.selectedRow == null) {
                        notifier.selectPosition(row, col);
                        return;
                      }

                      // 点击同一位置 -> 确认落子
                      if (gameState.selectedRow == row &&
                          gameState.selectedCol == col) {
                        if (!notifier.placeStone(row, col)) return;
                        // 发送走子到对手
                        onSendMessage(NetworkMessage(
                          type: 'game_move',
                          senderId: deviceId,
                          payload: {
                            'row': row,
                            'col': col,
                            'stone':
                                gameState.myStone == Stone.black ? 1 : 2,
                          },
                          timestamp:
                              DateTime.now().millisecondsSinceEpoch,
                        ));

                        // 游戏结束时通知对手
                        final newState = ref.read(gomokuStateProvider);
                        if (newState.status == GameStatus.won ||
                            newState.status == GameStatus.draw) {
                          onSendMessage(NetworkMessage(
                            type: 'game_over',
                            senderId: deviceId,
                            payload: {
                              'reason':
                                  newState.status == GameStatus.won
                                      ? 'win'
                                      : 'draw',
                              if (newState.winner != null)
                                'winner': newState.winner!.index,
                            },
                            timestamp: DateTime.now()
                                .millisecondsSinceEpoch,
                          ));
                        }
                        return;
                      }

                      // 点击不同位置 -> 改选
                      notifier.selectPosition(row, col);
                    },
                  ),
                ),
                if (gameState.status == GameStatus.waiting)
                  const Padding(
                    padding: EdgeInsets.all(16),
                    child: CircularProgressIndicator(),
                  ),
              ],
            ),
          ),
        ),
        // Show game over dialog or rematch UI
        bottomSheet: rematchStatus == GomokuRematchStatus.waiting
            ? _RematchWaitingSheet(
                onCancel: () {
                  onSendMessage(NetworkMessage(
                    type: 'rematch_response',
                    senderId: deviceId,
                    payload: {'accepted': false},
                    timestamp: DateTime.now().millisecondsSinceEpoch,
                  ));
                  ref.read(gomokuRematchStatusProvider.notifier).state =
                      GomokuRematchStatus.none;
                  Navigator.of(context).pop();
                },
              )
            : rematchStatus == GomokuRematchStatus.received &&
                    rematchDetails != null
                ? _IncomingRematchSheet(
                    peerName: rematchDetails.fromName,
                    onAccept: () {
                      final myNewStone = rematchDetails.previousStone;
                      final requesterNewColor =
                          myNewStone == Stone.black ? 'white' : 'black';
                      onSendMessage(NetworkMessage(
                        type: 'rematch_response',
                        senderId: deviceId,
                        payload: {
                          'accepted': true,
                          'yourColor': requesterNewColor,
                        },
                        timestamp: DateTime.now().millisecondsSinceEpoch,
                      ));
                      ref.read(gomokuStateProvider.notifier).resetGame();
                      ref.read(gomokuStateProvider.notifier).startGame(
                            myNewStone,
                            opponentName,
                          );
                      ref.read(gomokuRematchStatusProvider.notifier).state =
                          GomokuRematchStatus.none;
                      ref.read(gomokuRematchRequestDetailsProvider.notifier).state =
                          null;
                    },
                    onDecline: () {
                      onSendMessage(NetworkMessage(
                        type: 'rematch_response',
                        senderId: deviceId,
                        payload: {'accepted': false},
                        timestamp: DateTime.now().millisecondsSinceEpoch,
                      ));
                      ref.read(gomokuRematchStatusProvider.notifier).state =
                          GomokuRematchStatus.none;
                      ref.read(gomokuRematchRequestDetailsProvider.notifier).state =
                          null;
                      Navigator.of(context).pop();
                    },
                  )
                : gameState.status == GameStatus.won ||
                        gameState.status == GameStatus.lost ||
                        gameState.status == GameStatus.draw ||
                        gameState.status == GameStatus.disconnected
                    ? GomokuGameOverDialog(
                        status: gameState.status,
                        onRematch: () {
                          onSendMessage(NetworkMessage(
                            type: 'rematch_request',
                            senderId: deviceId,
                            payload: {
                              'device_name': deviceName,
                              'previous_stone':
                                  gameState.myStone == Stone.black
                                      ? 'black'
                                      : 'white',
                            },
                            timestamp:
                                DateTime.now().millisecondsSinceEpoch,
                          ));
                          ref.read(gomokuRematchStatusProvider.notifier).state =
                              GomokuRematchStatus.waiting;
                        },
                        onQuit: () {
                          // 直接弹回大厅，不调用 resetGame()。
                          Navigator.of(context).pop();
                        },
                      )
                    : null,
      ),
    );
  }

  void _showExitConfirm(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('退出游戏？'),
        content: const Text('当前游戏将判负。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () {
              // 通知对手退出游戏
              onSendMessage(NetworkMessage(
                type: 'game_over',
                senderId: deviceId,
                payload: {'reason': 'quit'},
                timestamp: DateTime.now().millisecondsSinceEpoch,
              ));
              // 先关对话框，再弹回大厅。不调用 resetGame()（冗余）。
              Navigator.of(ctx).pop();
              Navigator.of(context).pop();
            },
            child: const Text('退出'),
          ),
        ],
      ),
    );
  }
}

class _RematchWaitingSheet extends StatelessWidget {
  final VoidCallback onCancel;

  const _RematchWaitingSheet({required this.onCancel});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius:
            const BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 32),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 24),
            const SizedBox(
              width: 48,
              height: 48,
              child: CircularProgressIndicator(strokeWidth: 3),
            ),
            const SizedBox(height: 16),
            const Text(
              '等待对方同意重开...',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '已发送重开请求',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey.shade600,
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: onCancel,
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text('取消请求'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _IncomingRematchSheet extends StatelessWidget {
  final String peerName;
  final VoidCallback onAccept;
  final VoidCallback onDecline;

  const _IncomingRematchSheet({
    required this.peerName,
    required this.onAccept,
    required this.onDecline,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius:
            const BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 32),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),
            CircleAvatar(
              radius: 30,
              backgroundColor: AppTheme.primaryColor.withValues(alpha: 0.1),
              child: const Icon(
                Icons.replay,
                size: 30,
                color: AppTheme.primaryColor,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              '$peerName 请求重开一局',
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '是否同意交换先后手？',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey.shade600,
              ),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: onDecline,
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text('拒绝', style: TextStyle(fontSize: 16)),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: ElevatedButton(
                    onPressed: onAccept,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryColor,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text('接受', style: TextStyle(fontSize: 16)),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
