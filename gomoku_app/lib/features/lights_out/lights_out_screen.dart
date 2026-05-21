import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gomoku_app/core/utils/device_info.dart';
import 'package:gomoku_app/features/lights_out/lights_out_providers.dart';
import 'package:gomoku_app/features/lights_out/lights_out_timer.dart';
import 'package:gomoku_app/features/lights_out/widgets/lights_out_grid.dart';
import 'package:gomoku_app/models/network_message.dart';

class LightsOutScreen extends ConsumerStatefulWidget {
  final String opponentName;
  final void Function(NetworkMessage) onSendMessage;

  const LightsOutScreen({
    super.key,
    required this.opponentName,
    required this.onSendMessage,
  });

  @override
  ConsumerState<LightsOutScreen> createState() => _LightsOutScreenState();
}

class _LightsOutScreenState extends ConsumerState<LightsOutScreen> {
  @override
  Widget build(BuildContext context) {
    final gameState = ref.watch(lightsOutStateProvider);
    final rematchStatus = ref.watch(lightsOutRematchStatusProvider);
    final timerValue = ref.watch(lightsOutTimerProvider);

    // 计时归零 → timeout
    ref.listen<int>(lightsOutTimerProvider, (prev, next) {
      if (prev != null && prev > 0 && next == 0) {
        final gs = ref.read(lightsOutStateProvider);
        if (gs.status == LightsOutGameStatus.playing) {
          ref.read(lightsOutStateProvider.notifier).timeout();
          if (!gs.isSolo) {
            widget.onSendMessage(NetworkMessage(
              type: 'lights_out_game_over',
              senderId: deviceId,
              payload: {'reason': 'timeout'},
              timestamp: DateTime.now().millisecondsSinceEpoch,
            ));
          }
        }
      }
    });

    // 游戏结束时停定时器
    ref.listen<LightsOutState>(lightsOutStateProvider, (prev, next) {
      if (prev?.status == LightsOutGameStatus.playing &&
          next.status != LightsOutGameStatus.playing) {
        ref.read(lightsOutTimerProvider.notifier).stop();
      }
    });

    // 自动退出监听
    ref.listen<bool>(lightsOutAutoExitProvider, (prev, next) {
      if (next == true) {
        ref.read(lightsOutAutoExitProvider.notifier).state = false;
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

    // Toast 监听
    ref.listen<String?>(lightsOutToastProvider, (prev, next) {
      if (next != null) {
        ref.read(lightsOutToastProvider.notifier).state = null;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(next),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    });

    // 进入 playing 状态时启动计时器
    if (gameState.status == LightsOutGameStatus.playing) {
      ref.read(lightsOutTimerProvider.notifier).startIfNotRunning();
    }

    final isSolo = gameState.isSolo;
    final displayName = isSolo ? '点灯游戏' : widget.opponentName;

    return PopScope(
      canPop: gameState.status != LightsOutGameStatus.playing,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && gameState.status == LightsOutGameStatus.playing) {
          _showExitConfirm(context);
        }
      },
      child: Scaffold(
        appBar: AppBar(
          toolbarHeight: 40,
          title: Text(displayName),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () {
              if (gameState.status == LightsOutGameStatus.playing) {
                _showExitConfirm(context);
              } else {
                Navigator.of(context).pop();
              }
            },
          ),
        ),
        body: SafeArea(
          child: _buildBody(gameState, rematchStatus, timerValue),
        ),
      ),
    );
  }

  Widget _buildBody(
    LightsOutState gameState,
    LightsOutRematchStatus rematchStatus,
    int timerValue,
  ) {
    if (gameState.status == LightsOutGameStatus.loading) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(),
            if (!gameState.isSolo) ...[
              const SizedBox(height: 16),
              const Text('等待对方加载棋盘...'),
            ],
          ],
        ),
      );
    }

    return Column(
      children: [
        // 信息栏
        _buildInfoBar(gameState, timerValue),
        // 网格
        Expanded(
          child: LightsOutGrid(
            gridBits: gameState.gridBits,
            canTap: gameState.status == LightsOutGameStatus.playing,
            onTap: (row, col) {
              final notifier = ref.read(lightsOutStateProvider.notifier);
              final won = notifier.toggle(row, col);
              if (won && !gameState.isSolo) {
                // PvP 获胜，通知对手
                widget.onSendMessage(NetworkMessage(
                  type: 'lights_out_won',
                  senderId: deviceId,
                  payload: {
                    'move_count': ref.read(lightsOutStateProvider).moveCount,
                  },
                  timestamp: DateTime.now().millisecondsSinceEpoch,
                ));
              }
            },
          ),
        ),
        // 操作提示
        if (gameState.status == LightsOutGameStatus.playing)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Text(
              '点击灯泡，翻转自身和相邻的灯\n将所有灯熄灭即可获胜',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.grey.shade500,
                fontSize: 13,
              ),
            ),
          ),
        // 底部弹窗（游戏结束）
        if (gameState.status == LightsOutGameStatus.won ||
            gameState.status == LightsOutGameStatus.lost ||
            gameState.status == LightsOutGameStatus.draw ||
            gameState.status == LightsOutGameStatus.disconnected)
          _buildGameOverPanel(gameState, rematchStatus),
      ],
    );
  }

  Widget _buildInfoBar(LightsOutState state, int timerValue) {
    final minutes = timerValue ~/ 60;
    final seconds = timerValue % 60;
    final timeStr = '$minutes:${seconds.toString().padLeft(2, '0')}';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      color: Colors.grey.shade100,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // 己方
          Text(
            state.selfName.isNotEmpty ? state.selfName : '己方',
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
          ),
          // 中间：操作次数 + 时间
          Column(
            children: [
              Text(
                '操作: ${state.moveCount}',
                style: TextStyle(fontSize: 13, color: Colors.grey.shade700),
              ),
              const SizedBox(height: 2),
              Text(
                timeStr,
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: timerValue <= 30 ? Colors.red : Colors.black87,
                ),
              ),
            ],
          ),
          // 对方
          Text(
            state.isSolo
                ? ''
                : (state.opponentName.isNotEmpty
                    ? state.opponentName
                    : '对手'),
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
          ),
        ],
      ),
    );
  }

  Widget _buildGameOverPanel(
    LightsOutState state,
    LightsOutRematchStatus rematchStatus,
  ) {
    String title;
    Color titleColor;

    if (state.status == LightsOutGameStatus.won) {
      title = '你赢了！';
      titleColor = Colors.green;
    } else if (state.status == LightsOutGameStatus.lost) {
      title = '你输了';
      titleColor = Colors.red;
    } else if (state.status == LightsOutGameStatus.draw) {
      title = '平局';
      titleColor = Colors.orange;
    } else {
      title = '连接断开';
      titleColor = Colors.grey;
    }

    return Container(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: titleColor,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '操作次数: ${state.moveCount}',
            style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (!state.isSolo &&
                  rematchStatus == LightsOutRematchStatus.received) ...[
                // 收到对方重赛请求：接受 / 拒绝
                ElevatedButton.icon(
                  icon: const Icon(Icons.check, size: 18),
                  label: const Text('接受重赛'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  onPressed: () {
                    ref
                        .read(lightsOutRematchStatusProvider.notifier)
                        .state = LightsOutRematchStatus.waiting;
                    widget.onSendMessage(NetworkMessage(
                      type: 'lights_out_rematch_request',
                      senderId: deviceId,
                      payload: {'device_name': deviceName},
                      timestamp:
                          DateTime.now().millisecondsSinceEpoch,
                    ));
                  },
                ),
                const SizedBox(width: 12),
              ] else ...[
                // 再来一局 / 重赛按钮
                ElevatedButton.icon(
                  icon: Icon(
                    state.isSolo ? Icons.replay : Icons.refresh,
                    size: 18,
                  ),
                  label: Text(state.isSolo ? '再来一局' : '重赛'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue.shade600,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  onPressed: () =>
                      _handleRematchAction(state, rematchStatus),
                ),
              ],
              const SizedBox(width: 12),
              // 退出
              OutlinedButton.icon(
                icon: const Icon(Icons.exit_to_app, size: 18),
                label: const Text('退出'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                onPressed: () {
                  if (context.mounted) {
                    Navigator.of(context).pop();
                  }
                },
              ),
            ],
          ),
          if (!state.isSolo && rematchStatus == LightsOutRematchStatus.waiting)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                '等待对方回应...',
                style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
              ),
            ),
        ],
      ),
    );
  }

  void _handleRematchAction(
    LightsOutState state,
    LightsOutRematchStatus rematchStatus,
  ) {
    if (state.isSolo) {
      _restartSoloGame();
    } else if (rematchStatus != LightsOutRematchStatus.waiting) {
      // 防止按钮连点发送重复请求
      widget.onSendMessage(NetworkMessage(
        type: 'lights_out_rematch_request',
        senderId: deviceId,
        payload: {'device_name': deviceName},
        timestamp: DateTime.now().millisecondsSinceEpoch,
      ));
      ref.read(lightsOutRematchStatusProvider.notifier).state =
          LightsOutRematchStatus.waiting;
    }
  }

  Future<void> _restartSoloGame() async {
    ref.read(lightsOutStateProvider.notifier).setLoading();
    ref.read(lightsOutTimerProvider.notifier).reset();

    final seed = LightsOutStateNotifier.generateSeed();
    ref.read(lightsOutStateProvider.notifier).startGame(
      seed: seed,
      isSolo: true,
      selfName: deviceName,
    );
    ref.read(lightsOutTimerProvider.notifier).start();
  }

  void _showExitConfirm(BuildContext context) {
    final isSolo = ref.read(lightsOutStateProvider).isSolo;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('退出游戏？'),
        content: Text(isSolo ? '当前进度将丢失。' : '当前游戏将判负。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () {
              if (!isSolo) {
                widget.onSendMessage(NetworkMessage(
                  type: 'lights_out_game_over',
                  senderId: deviceId,
                  payload: {'reason': 'quit'},
                  timestamp: DateTime.now().millisecondsSinceEpoch,
                ));
              }
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
