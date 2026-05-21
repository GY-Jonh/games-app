import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gomoku_app/core/utils/device_info.dart';
import 'package:gomoku_app/features/spot_diff/spot_diff_providers.dart';
import 'package:gomoku_app/features/spot_diff/spot_diff_timer.dart';
import 'package:gomoku_app/features/spot_diff/widgets/spot_diff_canvas.dart';
import 'package:gomoku_app/features/spot_diff/widgets/spot_diff_game_over_dialog.dart';
import 'package:gomoku_app/features/spot_diff/widgets/spot_diff_info_bar.dart';
import 'package:gomoku_app/features/spot_diff/services/spot_diff_image_service.dart';
import 'package:gomoku_app/models/network_message.dart';

class SpotDiffScreen extends ConsumerStatefulWidget {
  final String opponentName;
  final void Function(NetworkMessage) onSendMessage;

  const SpotDiffScreen({
    super.key,
    required this.opponentName,
    required this.onSendMessage,
  });

  @override
  ConsumerState<SpotDiffScreen> createState() => _SpotDiffScreenState();
}

class _SpotDiffScreenState extends ConsumerState<SpotDiffScreen> {
  @override
  Widget build(BuildContext context) {
    final gameState = ref.watch(spotDiffStateProvider);
    final rematchStatus = ref.watch(spotDiffRematchStatusProvider);
    final timerValue = ref.watch(spotDiffTimerProvider);

    // 计时归零 → timeout
    ref.listen<int>(spotDiffTimerProvider, (prev, next) {
      if (prev != null && prev > 0 && next == 0) {
        final gs = ref.read(spotDiffStateProvider);
        if (gs.status == SpotDiffGameStatus.playing) {
          ref.read(spotDiffStateProvider.notifier).timeout();
          widget.onSendMessage(NetworkMessage(
            type: 'spot_diff_game_over',
            senderId: deviceId,
            payload: {'reason': 'timeout'},
            timestamp: DateTime.now().millisecondsSinceEpoch,
          ));
        }
      }
    });

    // 游戏结束时停定时器（all_found / timeout / disconnect / quit）
    ref.listen<SpotDiffState>(spotDiffStateProvider, (prev, next) {
      if (prev?.status == SpotDiffGameStatus.playing &&
          next.status != SpotDiffGameStatus.playing) {
        ref.read(spotDiffTimerProvider.notifier).stop();
      }
    });

    // 自动退出监听
    ref.listen<bool>(spotDiffAutoExitProvider, (prev, next) {
      if (next == true) {
        ref.read(spotDiffAutoExitProvider.notifier).state = false;
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
    ref.listen<String?>(spotDiffToastProvider, (prev, next) {
      if (next != null) {
        ref.read(spotDiffToastProvider.notifier).state = null;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(next),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    });

    // 进入 playing 状态时启动计时器
    if (gameState.status == SpotDiffGameStatus.playing) {
      ref.read(spotDiffTimerProvider.notifier).startIfNotRunning();
    }

    final isSolo = gameState.isSolo;
    final displayName = isSolo ? '单人模式' : widget.opponentName;

    return PopScope(
      canPop: gameState.status != SpotDiffGameStatus.playing,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && gameState.status == SpotDiffGameStatus.playing) {
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
              if (gameState.status == SpotDiffGameStatus.playing) {
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
    SpotDiffState gameState,
    SpotDiffRematchStatus rematchStatus,
    int timerValue,
  ) {
    // Loading state
    if (gameState.status == SpotDiffGameStatus.loading) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(),
            if (!gameState.isSolo) ...[
              const SizedBox(height: 16),
              const Text('等待对方加载图集...'),
            ],
          ],
        ),
      );
    }

    // No set loaded
    if (gameState.currentSet == null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(),
            if (!gameState.isSolo) ...[
              const SizedBox(height: 16),
              const Text('等待对方加载图集...'),
            ],
          ],
        ),
      );
    }

    final set = gameState.currentSet!;

    return Column(
      children: [
        SpotDiffInfoBar(
          selfName: deviceName,
          opponentName: widget.opponentName,
          myScore: gameState.myScore,
          opponentScore: gameState.opponentScore,
          totalDiffs: gameState.totalDiffs,
          timeRemaining: timerValue,
          isSolo: gameState.isSolo,
        ),
        const SizedBox(height: 4),
        Expanded(
          child: SpotDiffCanvas(
            set: set,
            foundByMe: gameState.foundByMe,
            foundByOpponent: gameState.foundByOpponent,
            canTap: gameState.status == SpotDiffGameStatus.playing,
            onTap: (nx, ny) {
              final notifier = ref.read(spotDiffStateProvider.notifier);
              final result = notifier.tryFindDifference(nx, ny);
              if (result != null && !gameState.isSolo) {
                // PvP: 通知对手
                widget.onSendMessage(NetworkMessage(
                  type: 'spot_diff_found',
                  senderId: deviceId,
                  payload: {'diffIndex': result},
                  timestamp: DateTime.now().millisecondsSinceEpoch,
                ));

                // 全部找到时通知
                final newState = ref.read(spotDiffStateProvider);
                if (newState.areAllFound) {
                  widget.onSendMessage(NetworkMessage(
                    type: 'spot_diff_game_over',
                    senderId: deviceId,
                    payload: {'reason': 'all_found'},
                    timestamp: DateTime.now().millisecondsSinceEpoch,
                  ));
                }
              }
            },
          ),
        ),
        // Bottom sheet
        if (gameState.status == SpotDiffGameStatus.won ||
            gameState.status == SpotDiffGameStatus.lost ||
            gameState.status == SpotDiffGameStatus.draw ||
            gameState.status == SpotDiffGameStatus.disconnected)
          SpotDiffGameOverDialog(
            status: gameState.status,
            myScore: gameState.myScore,
            opponentScore: gameState.opponentScore,
            totalDiffs: gameState.totalDiffs,
            isSolo: gameState.isSolo,
            onRematch: gameState.isSolo
                ? _restartSoloGame
                : () {
                    widget.onSendMessage(NetworkMessage(
                      type: 'spot_diff_rematch_request',
                      senderId: deviceId,
                      payload: {'device_name': deviceName},
                      timestamp: DateTime.now().millisecondsSinceEpoch,
                    ));
                    ref.read(spotDiffRematchStatusProvider.notifier).state =
                        SpotDiffRematchStatus.waiting;
                  },
            onQuit: () {
              if (context.mounted) {
                Navigator.of(context).pop();
              }
            },
          ),
      ],
    );
  }

  Future<void> _restartSoloGame() async {
    ref.read(spotDiffStateProvider.notifier).setLoading();
    ref.read(spotDiffTimerProvider.notifier).reset();
    try {
      final service = SpotDiffImageService();
      final sets = await service.getTodaySets();
      if (sets.isEmpty || !mounted) return;

      // 随机选一套，避免重复
      final currentSet = ref.read(spotDiffStateProvider).currentSet;
      final candidates = currentSet != null && sets.length > 1
          ? sets.where((s) => s.id != currentSet.id).toList()
          : sets;
      final randomIndex = DateTime.now().millisecondsSinceEpoch % candidates.length;
      final set = candidates[randomIndex];

      ref.read(spotDiffStateProvider.notifier).startGame(
        set,
        isSolo: true,
        selfName: deviceName,
      );
      ref.read(spotDiffTimerProvider.notifier).start();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('加载图集失败')),
        );
      }
    }
  }

  void _showExitConfirm(BuildContext context) {
    final isSolo = ref.read(spotDiffStateProvider).isSolo;
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
              widget.onSendMessage(NetworkMessage(
                type: 'spot_diff_game_over',
                senderId: deviceId,
                payload: {'reason': 'quit'},
                timestamp: DateTime.now().millisecondsSinceEpoch,
              ));
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
