import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gomoku_app/core/constants/game_constants.dart';

final serverPortProvider = StateProvider<int>((ref) => 0);

final connectionStatusProvider =
    StateProvider<ConnectionStatus>((ref) => ConnectionStatus.idle);

// Empty stream provider that can be overridden at runtime
final incomingMessageProvider =
    StreamProvider<Map<String, dynamic>>((ref) {
  final controller = StreamController<Map<String, dynamic>>();
  ref.onDispose(() => controller.close());
  return controller.stream;
});
