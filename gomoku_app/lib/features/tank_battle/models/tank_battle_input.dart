/// 坦克大战输入命令模型，用于 PvP 输入转发。
library;

import 'package:gomoku_app/features/tank_battle/constants/tank_battle_constants.dart';

class TankBattleInput {
  final Direction? direction;
  final bool firing;

  const TankBattleInput({this.direction, this.firing = false});

  Map<String, dynamic> toJson() => {
        'dir': direction?.index,
        'fire': firing,
      };

  factory TankBattleInput.fromJson(Map<String, dynamic> json) {
    final dirIndex = json['dir'] as int?;
    return TankBattleInput(
      direction: dirIndex != null ? Direction.fromIndex(dirIndex) : null,
      firing: json['fire'] as bool? ?? false,
    );
  }
}
