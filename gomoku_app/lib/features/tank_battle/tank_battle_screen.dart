/// 坦克大战主界面。
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gomoku_app/core/utils/device_info.dart';
import 'package:gomoku_app/features/tank_battle/constants/tank_battle_constants.dart';
import 'package:gomoku_app/features/tank_battle/models/tank_battle_state.dart';
import 'package:gomoku_app/features/tank_battle/rendering/tank_battle_canvas.dart';
import 'package:gomoku_app/features/tank_battle/tank_battle_providers.dart';
import 'package:gomoku_app/features/tank_battle/widgets/tank_battle_dpad.dart';
import 'package:gomoku_app/features/tank_battle/widgets/tank_battle_fire_button.dart';
import 'package:gomoku_app/features/tank_battle/widgets/tank_battle_game_over.dart';
import 'package:gomoku_app/features/tank_battle/widgets/tank_battle_hud.dart';
import 'package:gomoku_app/features/tank_battle/widgets/tank_battle_level_intro.dart';
import 'package:gomoku_app/models/network_message.dart';

class TankBattleScreen extends ConsumerStatefulWidget {
  final String opponentName;
  final void Function(NetworkMessage) onSendMessage;

  const TankBattleScreen({
    super.key,
    required this.opponentName,
    required this.onSendMessage,
  });

  @override
  ConsumerState<TankBattleScreen> createState() => _TankBattleScreenState();
}

class _TankBattleScreenState extends ConsumerState<TankBattleScreen> {
  bool get isSolo => widget.opponentName.isEmpty;

  @override
  Widget build(BuildContext context) {
    final gameState = ref.watch(tankBattleStateProvider);
    final rematchStatus = ref.watch(tankBattleRematchStatusProvider);

    // 自动退出监听
    ref.listen<bool>(tankBattleAutoExitProvider, (prev, next) {
      if (next) {
        ref.read(tankBattleAutoExitProvider.notifier).state = false;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (context.mounted) Navigator.of(context).pop();
        });
      }
    });

    // Toast 监听
    ref.listen<String?>(tankBattleToastProvider, (prev, next) {
      if (next != null) {
        ref.read(tankBattleToastProvider.notifier).state = null;
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(next), duration: const Duration(seconds: 2)),
          );
        }
      }
    });

    final isPlaying = gameState.phase == TankBattlePhase.playing;

    return PopScope(
      canPop: !isPlaying,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && isPlaying) _showExitConfirm(context);
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        appBar: AppBar(
          toolbarHeight: 36,
          backgroundColor: Colors.grey.shade900,
          title: Text(
            isSolo ? '坦克大战' : widget.opponentName,
            style: const TextStyle(fontSize: 15),
          ),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, size: 20),
            onPressed: () {
              if (isPlaying) {
                _showExitConfirm(context);
              } else {
                Navigator.of(context).pop();
              }
            },
          ),
        ),
        body: SafeArea(
          child: _buildBody(gameState, rematchStatus),
        ),
      ),
    );
  }

  Widget _buildBody(
      TankBattleState gameState, TankBattleRematchStatus rematchStatus) {
    // Loading
    if (gameState.phase == TankBattlePhase.loading) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(color: Colors.white),
            SizedBox(height: 16),
            Text('加载中...', style: TextStyle(color: Colors.white70)),
          ],
        ),
      );
    }

    // Level Intro
    if (gameState.phase == TankBattlePhase.levelIntro) {
      return TankBattleLevelIntro(level: gameState.currentLevel);
    }

    return Column(
      children: [
        // HUD
        TankBattleHud(
          lives: gameState.livesRemaining,
          enemiesRemaining: gameState.enemiesRemaining,
          currentLevel: gameState.currentLevel,
          score: gameState.score,
          isBaseDestroyed: gameState.isBaseDestroyed,
          isSolo: isSolo,
          opponentName: widget.opponentName,
        ),

        // 战场画布
        Expanded(
          child: Center(
            child: TankBattleCanvas(state: gameState),
          ),
        ),

        // 操控区 (仅在 playing 时显示)
        if (gameState.phase == TankBattlePhase.playing)
          _buildControls(),

        // 游戏结束 / 过关面板
        if (gameState.phase == TankBattlePhase.lost ||
            gameState.phase == TankBattlePhase.won ||
            gameState.phase == TankBattlePhase.disconnected ||
            gameState.phase == TankBattlePhase.levelComplete)
          _buildEndPanel(gameState, rematchStatus),
      ],
    );
  }

  Widget _buildControls() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
      color: Colors.grey.shade900,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          TankBattleDpad(
            onDirectionChanged: (dir) {
              ref
                  .read(tankBattleStateProvider.notifier)
                  .setPlayerInput(dir, _isFiring);
              _forwardInput(dir, _isFiring);
            },
          ),
          TankBattleFireButton(
            onFiringChanged: (firing) {
              _isFiring = firing;
              final currentDir = ref
                  .read(tankBattleStateProvider.notifier)
                  .getCurrentInput()
                  .direction;
              ref
                  .read(tankBattleStateProvider.notifier)
                  .setPlayerInput(currentDir, firing);
              _forwardInput(currentDir, firing);
            },
          ),
        ],
      ),
    );
  }

  bool _isFiring = false;

  /// PvP Guest: 转发输入到 Host。
  void _forwardInput(Direction? dir, bool firing) {
    if (isSolo) return;
    widget.onSendMessage(NetworkMessage(
      type: 'tank_battle_input',
      senderId: deviceId,
      payload: {
        'dir': dir?.index,
        'fire': firing,
      },
      timestamp: DateTime.now().millisecondsSinceEpoch,
    ));
  }

  Widget _buildEndPanel(
      TankBattleState gameState, TankBattleRematchStatus rematchStatus) {
    return TankBattleGameOver(
      phase: gameState.phase,
      score: gameState.score,
      currentLevel: gameState.currentLevel,
      isSolo: isSolo,
      isWaitingRematch: rematchStatus == TankBattleRematchStatus.waiting,
      showAcceptRematch: rematchStatus == TankBattleRematchStatus.received,
      onAcceptRematch: rematchStatus == TankBattleRematchStatus.received
          ? () => _acceptRematch()
          : null,
      onRematch: () => _handleRematch(gameState, rematchStatus),
      onQuit: () => Navigator.of(context).pop(),
    );
  }

  // ========== 重赛逻辑 ==========

  void _handleRematch(
      TankBattleState gameState, TankBattleRematchStatus rematchStatus) {
    if (isSolo) {
      if (gameState.phase == TankBattlePhase.levelComplete) {
        // 单人过关: 直接进入下一关
        final seed = TankBattleStateNotifier.generateSeed();
        ref.read(tankBattleStateProvider.notifier).advanceToNextLevel(
              seed: seed,
              isSolo: true,
              selfName: deviceName,
            );
      } else {
        // 单人 Game Over: 从第1关重新开始
        final seed = TankBattleStateNotifier.generateSeed();
        ref.read(tankBattleStateProvider.notifier).startLevel(
              level: 1,
              seed: seed,
              isSolo: true,
              selfName: deviceName,
            );
      }
    } else {
      // PvP: 无论过关还是 Game Over，都走重赛协议
      ref.read(tankBattleRematchStatusProvider.notifier).state =
          TankBattleRematchStatus.waiting;
      widget.onSendMessage(NetworkMessage(
        type: 'tank_battle_rematch_request',
        senderId: deviceId,
        payload: {'device_name': deviceName},
        timestamp: DateTime.now().millisecondsSinceEpoch,
      ));
    }
  }

  void _acceptRematch() {
    ref.read(tankBattleRematchStatusProvider.notifier).state =
        TankBattleRematchStatus.waiting;
    widget.onSendMessage(NetworkMessage(
      type: 'tank_battle_rematch_request',
      senderId: deviceId,
      payload: {'device_name': deviceName},
      timestamp: DateTime.now().millisecondsSinceEpoch,
    ));
  }

  // ========== 退出确认 ==========

  void _showExitConfirm(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.grey.shade900,
        title: const Text('退出游戏？', style: TextStyle(color: Colors.white)),
        content: Text(
          isSolo ? '当前进度将丢失。' : '当前游戏将判负。',
          style: TextStyle(color: Colors.grey.shade300),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () {
              if (!isSolo) {
                widget.onSendMessage(NetworkMessage(
                  type: 'tank_battle_game_over',
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
