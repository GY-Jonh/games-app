/// 操作按钮行组件。
library;

import 'package:flutter/material.dart';

class ZhaJinhuaActionButtons extends StatelessWidget {
  final bool canCall;
  final bool canRaise;
  final bool canCompare;
  final bool isEnabled;
  final int callAmount;
  final int raiseAmount;
  final VoidCallback onPeek;
  final VoidCallback onCall;
  final VoidCallback onRaise;
  final VoidCallback onFold;
  final VoidCallback onCompare;

  const ZhaJinhuaActionButtons({
    super.key,
    required this.canCall,
    required this.canRaise,
    required this.canCompare,
    required this.isEnabled,
    required this.callAmount,
    required this.raiseAmount,
    required this.onPeek,
    required this.onCall,
    required this.onRaise,
    required this.onFold,
    required this.onCompare,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF2C2C2C),
        border: Border(
          top: BorderSide(color: Colors.grey.shade700, width: 1),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 第一行：跟注 / 加注
          Row(
            children: [
              Expanded(
                child: _buildButton(
                  label: '跟注 $callAmount',
                  icon: Icons.check_circle_outline,
                  color: Colors.teal,
                  onTap: onCall,
                  enabled: canCall && isEnabled,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildButton(
                  label: '加注 $raiseAmount',
                  icon: Icons.trending_up,
                  color: Colors.orange,
                  onTap: onRaise,
                  enabled: canRaise && isEnabled,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          // 第二行：弃牌 / 比牌
          Row(
            children: [
              Expanded(
                child: _buildButton(
                  label: '弃牌',
                  icon: Icons.cancel_outlined,
                  color: Colors.red,
                  onTap: onFold,
                  enabled: isEnabled,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildButton(
                  label: '比牌',
                  icon: Icons.compare_arrows,
                  color: Colors.purple,
                  onTap: onCompare,
                  enabled: canCompare && isEnabled,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildButton({
    required String label,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
    required bool enabled,
  }) {
    return SizedBox(
      height: 44,
      child: ElevatedButton.icon(
        onPressed: enabled ? onTap : null,
        icon: Icon(icon, size: 18),
        label: Text(label, style: const TextStyle(fontSize: 14)),
        style: ElevatedButton.styleFrom(
          backgroundColor: enabled ? color.withValues(alpha: 0.5) : null,
          foregroundColor: enabled ? Colors.white : Colors.grey,
          disabledBackgroundColor: Colors.grey.shade700,
          disabledForegroundColor: Colors.grey.shade400,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
            side: BorderSide(
              color: enabled ? color.withValues(alpha: 0.7) : Colors.grey.shade700,
              width: 1,
            ),
          ),
        ),
      ),
    );
  }
}
