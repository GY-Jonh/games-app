import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gomoku_app/core/utils/device_info.dart';
import 'package:gomoku_app/features/game_2048/game_2048_providers.dart';
import 'package:gomoku_app/features/game_2048/game_2048_timer.dart';
import 'package:gomoku_app/features/game_2048/widgets/game_2048_grid.dart';
import 'package:gomoku_app/models/network_message.dart';

class Game2048Screen extends ConsumerStatefulWidget {
  final String opponentName;
  final void Function(NetworkMessage) onSendMessage;

  const Game2048Screen({
    super.key,
    required this.opponentName,
    required this.onSendMessage,
  });

  @override
  ConsumerState<Game2048Screen> createState() => _Game2048ScreenState();
}

class _Game2048ScreenState extends ConsumerState<Game2048Screen> {
  @override
  Widget build(BuildContext context) {
    final gameState = ref.watch(game2048StateProvider);
    final rematchStatus = ref.watch(game2048RematchStatusProvider);
    final timerValue = ref.watch(game2048TimerProvider);

    // 计时归零 → timeout
    ref.listen<int>(game2048TimerProvider, (prev, next) {
      if (prev != null && prev > 0 && next == 0) {
        final gs = ref.read(game2048StateProvider);
        if (gs.status == Game2048Status.playing) {
          ref.read(game2048StateProvider.notifier).timeout();
          if (!gs.isSolo) {
            widget.onSendMessage(NetworkMessage(
              type: 'game_2048_game_over',
              senderId: deviceId,
              payload: {'reason': 'timeout'},
              timestamp: DateTime.now().millisecondsSinceEpoch,
            ));
          }
        }
      }
    });

    // 游戏结束时停定时器
    ref.listen<Game2048State>(game2048StateProvider, (prev, next) {
      if (prev?.status == Game2048Status.playing &&
          next.status != Game2048Status.playing) {
        ref.read(game2048TimerProvider.notifier).stop();
      }
    });

    // 自动退出监听
    ref.listen<bool>(game2048AutoExitProvider, (prev, next) {
      if (next == true) {
        ref.read(game2048AutoExitProvider.notifier).state = false;
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
    ref.listen<String?>(game2048ToastProvider, (prev, next) {
      if (next != null) {
        ref.read(game2048ToastProvider.notifier).state = null;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(next), duration: const Duration(seconds: 2)),
        );
      }
    });

    // 进入 playing 状态时启动计时器
    if (gameState.status == Game2048Status.playing) {
      ref.read(game2048TimerProvider.notifier).startIfNotRunning();
    }

    final isSolo = gameState.isSolo;
    final displayName = isSolo ? '2048' : widget.opponentName;

    return PopScope(
      canPop: gameState.status != Game2048Status.playing,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && gameState.status == Game2048Status.playing) {
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
              if (gameState.status == Game2048Status.playing) {
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
    Game2048State gameState,
    Game2048RematchStatus rematchStatus,
    int timerValue,
  ) {
    if (gameState.status == Game2048Status.loading) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(),
            if (!gameState.isSolo) ...[
              const SizedBox(height: 16),
              const Text('等待对方准备...'),
            ],
          ],
        ),
      );
    }

    return GestureDetector(
      onPanEnd: (details) {
        if (gameState.status != Game2048Status.playing) return;
        final velocity = details.velocity.pixelsPerSecond;
        final dx = velocity.dx;
        final dy = velocity.dy;

        if (dx.abs() < 50 && dy.abs() < 50) return; // 太小忽略

        MoveDirection direction;
        if (dx.abs() > dy.abs()) {
          direction = dx > 0 ? MoveDirection.right : MoveDirection.left;
        } else {
          direction = dy > 0 ? MoveDirection.down : MoveDirection.up;
        }

        final (:moved, mergeScore: _) =
            ref.read(game2048StateProvider.notifier).move(direction);

        if (moved) {
          final newState = ref.read(game2048StateProvider);
          if (newState.status == Game2048Status.won && !gameState.isSolo) {
            widget.onSendMessage(NetworkMessage(
              type: 'game_2048_won',
              senderId: deviceId,
              payload: {'move_count': newState.moveCount},
              timestamp: DateTime.now().millisecondsSinceEpoch,
            ));
          }
        }
      },
      child: Column(
        children: [
          _buildInfoBar(gameState, timerValue),
          Expanded(
            child: Game2048Grid(grid: gameState.grid),
          ),
          if (gameState.status == Game2048Status.playing)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text(
                '滑动屏幕合并相同数字\n达到 2048 即可获胜',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.grey.shade500,
                  fontSize: 13,
                ),
              ),
            ),
          if (gameState.status == Game2048Status.won ||
              gameState.status == Game2048Status.lost ||
              gameState.status == Game2048Status.draw ||
              gameState.status == Game2048Status.disconnected)
            _buildGameOverPanel(gameState, rematchStatus),
        ],
      ),
    );
  }

  Widget _buildInfoBar(Game2048State state, int timerValue) {
    final minutes = timerValue ~/ 60;
    final seconds = timerValue % 60;
    final timeStr = '$minutes:${seconds.toString().padLeft(2, '0')}';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      color: Colors.grey.shade100,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            state.selfName.isNotEmpty ? state.selfName : '己方',
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
          ),
          Column(
            children: [
              Text(
                '分数: ${state.score} · ${state.moveCount} 步',
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
    Game2048State state,
    Game2048RematchStatus rematchStatus,
  ) {
    String title;
    Color titleColor;

    if (state.status == Game2048Status.won) {
      title = '你赢了！';
      titleColor = Colors.green;
    } else if (state.status == Game2048Status.lost) {
      title = '你输了';
      titleColor = Colors.red;
    } else if (state.status == Game2048Status.draw) {
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
            '分数: ${state.score} · ${state.moveCount} 步',
            style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (!state.isSolo &&
                  rematchStatus == Game2048RematchStatus.received) ...[
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
                        .read(game2048RematchStatusProvider.notifier)
                        .state = Game2048RematchStatus.waiting;
                    widget.onSendMessage(NetworkMessage(
                      type: 'game_2048_rematch_request',
                      senderId: deviceId,
                      payload: {'device_name': deviceName},
                      timestamp: DateTime.now().millisecondsSinceEpoch,
                    ));
                  },
                ),
                const SizedBox(width: 12),
              ] else ...[
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
          if (!state.isSolo &&
              rematchStatus == Game2048RematchStatus.waiting)
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
    Game2048State state,
    Game2048RematchStatus rematchStatus,
  ) {
    if (state.isSolo) {
      _restartSoloGame();
    } else if (rematchStatus != Game2048RematchStatus.waiting) {
      widget.onSendMessage(NetworkMessage(
        type: 'game_2048_rematch_request',
        senderId: deviceId,
        payload: {'device_name': deviceName},
        timestamp: DateTime.now().millisecondsSinceEpoch,
      ));
      ref.read(game2048RematchStatusProvider.notifier).state =
          Game2048RematchStatus.waiting;
    }
  }

  Future<void> _restartSoloGame() async {
    ref.read(game2048StateProvider.notifier).setLoading();
    ref.read(game2048TimerProvider.notifier).reset();

    final seed = Game2048StateNotifier.generateSeed();
    ref.read(game2048StateProvider.notifier).startGame(
      seed: seed,
      isSolo: true,
      selfName: deviceName,
    );
    ref.read(game2048TimerProvider.notifier).start();
  }

  void _showExitConfirm(BuildContext context) {
    final isSolo = ref.read(game2048StateProvider).isSolo;
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
                  type: 'game_2048_game_over',
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
