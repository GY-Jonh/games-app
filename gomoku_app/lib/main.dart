import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gomoku_app/app.dart';
import 'package:gomoku_app/features/gomoku/gomoku_module.dart';
import 'package:gomoku_app/features/game_2048/game_2048_module.dart';
import 'package:gomoku_app/features/lights_out/lights_out_module.dart';
import 'package:gomoku_app/features/memory_match/memory_match_module.dart';
import 'package:gomoku_app/features/minesweeper/minesweeper_module.dart';
import 'package:gomoku_app/features/sliding_puzzle/sliding_puzzle_module.dart';
import 'package:gomoku_app/features/spot_diff/spot_diff_module.dart';
import 'package:gomoku_app/features/tank_battle/tank_battle_module.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  GomokuModule.register();
  SpotDiffModule.register();
  LightsOutModule.register();
  MemoryMatchModule.register();
  Game2048Module.register();
  SlidingPuzzleModule.register();
  MinesweeperModule.register();
  TankBattleModule.register();
  runApp(
    const ProviderScope(
      child: GomokuApp(),
    ),
  );
}
