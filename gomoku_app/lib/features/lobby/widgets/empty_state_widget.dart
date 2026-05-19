import 'package:flutter/material.dart';

class EmptyStateWidget extends StatelessWidget {
  final bool isSearching;

  const EmptyStateWidget({super.key, this.isSearching = false});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isSearching ? Icons.wifi_find : Icons.people_outline,
              size: 64,
              color: Colors.grey.shade300,
            ),
            const SizedBox(height: 16),
            Text(
              isSearching ? '正在搜索同一 WiFi 的设备...' : '没有找到在线玩家',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey.shade500,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              isSearching ? '' : '请确保两台手机连接同一 WiFi',
              style: TextStyle(
                fontSize: 13,
                color: Colors.grey.shade400,
              ),
            ),
            if (isSearching) ...[
              const SizedBox(height: 24),
              const CircularProgressIndicator(),
            ],
          ],
        ),
      ),
    );
  }
}
