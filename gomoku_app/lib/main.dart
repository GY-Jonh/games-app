import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gomoku_app/app.dart';
import 'package:gomoku_app/features/gomoku/gomoku_module.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  GomokuModule.register();
  runApp(
    const ProviderScope(
      child: GomokuApp(),
    ),
  );
}
