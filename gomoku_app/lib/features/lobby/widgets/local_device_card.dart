import 'package:flutter/material.dart';
import 'package:gomoku_app/core/theme/app_theme.dart';

class LocalDeviceCard extends StatelessWidget {
  final String deviceName;
  final int serverPort;
  final bool isServerRunning;
  final VoidCallback? onEditName;

  const LocalDeviceCard({
    super.key,
    required this.deviceName,
    required this.serverPort,
    required this.isServerRunning,
    this.onEditName,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isServerRunning
            ? AppTheme.onlineGreen.withValues(alpha: 0.05)
            : Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isServerRunning
              ? AppTheme.onlineGreen.withValues(alpha: 0.3)
              : Colors.grey.shade200,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: isServerRunning
                  ? AppTheme.onlineGreen.withValues(alpha: 0.1)
                  : Colors.grey.shade200,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              Icons.person,
              color: isServerRunning ? AppTheme.onlineGreen : Colors.grey,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: GestureDetector(
              onTap: onEditName,
              child: Row(
                children: [
                  Flexible(
                    child: Text(
                      '我 ($deviceName)',
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (onEditName != null) ...[
                    const SizedBox(width: 4),
                    Icon(
                      Icons.edit,
                      size: 14,
                      color: Colors.grey.shade400,
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            isServerRunning
                ? '端口 $serverPort'
                : '正在启动...',
            style: TextStyle(
              fontSize: 12,
              color: isServerRunning ? AppTheme.onlineGreen : Colors.grey,
            ),
          ),
          const SizedBox(width: 8),
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isServerRunning ? AppTheme.onlineGreen : Colors.grey,
            ),
          ),
        ],
      ),
    );
  }
}
