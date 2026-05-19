import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gomoku_app/core/utils/device_info.dart';

/// 玩家自定义名称，初始值读取系统 hostname
final playerNameProvider = StateProvider<String>((ref) => deviceName);
