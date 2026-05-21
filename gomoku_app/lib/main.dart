import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gomoku_app/app.dart';
import 'package:gomoku_app/features/gomoku/gomoku_module.dart';
import 'package:gomoku_app/features/lights_out/lights_out_module.dart';
import 'package:gomoku_app/features/spot_diff/spot_diff_module.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  GomokuModule.register();
  SpotDiffModule.register();
  LightsOutModule.register();
  runApp(
    const ProviderScope(
      child: GomokuApp(),
    ),
  );
}
