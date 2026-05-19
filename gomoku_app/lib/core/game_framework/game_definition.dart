import 'package:flutter/material.dart';

/// 游戏类型的元数据描述，用于游戏选择 UI 和注册
class GameDefinition {
  final String id;
  final String displayName;
  final IconData icon;
  final String subtitle;

  const GameDefinition({
    required this.id,
    required this.displayName,
    required this.icon,
    this.subtitle = '',
  });
}
