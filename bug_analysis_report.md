# P2P Gomoku App - Bug 分析报告

> 分析日期：2026-05-19
> 方法：模拟用户安装 App 后逐屏逐功能使用，检查代码逻辑与竞态条件

---

## 一、关键 Bug（App 无法正常使用）

### 1. [关键] MDnsService 双重实例化 —— 设备发现完全失效

**位置:** `lib/features/lobby/lobby_screen.dart:41` 和 `lib/services/mdns_providers.dart:6`

**问题:** `MDnsService` 在两个地方分别创建了独立的实例：

- `lobby_screen.dart` 中 `LobbyScreenState` 创建了 `_mdns = MDnsService()`
- `mdns_providers.dart` 中通过 Provider 创建了另一个 `MDnsService()`

**后果:** 这两个实例互不共享状态。UI 监听的是 Provider 中的实例（通过 `mdnsStatusProvider` 获取设备列表），但实际发送/接收 mDNS 广播的是 `LobbyScreen` 持有的那个实例。导致：

- 通过 mDNS 发现的设备列表从来不会出现在 UI 中
- 你的设备永远看不到别人，别人也看不到你——**App 核心功能完全不可用**

**修复建议:** 统一到一个单例。推荐方式：在 `mdns_providers.dart` 中创建实例，`LobbyScreen` 通过 Provider 获取引用，不再自己 new。

---

### 2. [关键] 玩家索引（Player Index）分配逻辑反转

**位置:** `lib/features/lobby/lobby_screen.dart:281` 和 `293`

**问题:** 玩家索引的分配逻辑在邀请者和被邀请者之间存在不一致性：

1. **邀请者**在 `_navigateToGame()`（约 line 281）发送 `game_invite` 消息时附带 `your_player: 0`，并认为自己就是 player 0（先手）
2. **被邀请者**在收到邀请（约 line 293）时解析 `your_player`，但初始化逻辑可能将其映射为自己是 player 0

导致双方都认为自己是先手(player 0)，或者双方都认为是后手(player 1)。

**后果:** 对局中出现"双方都认为自己先走"的混乱局面——要么双方都等待对方先手导致僵局，要么双方都下第一子导致状态错乱。**一局棋永远无法正常开始。**

**修复建议:** 统一 player index 的分配约定：

- 邀请者 = player 0（先手执黑）
- 被邀请者 = player 1（后手执白）
- 在 `game_invite` 消息中用 `your_player` 明确告诉对方"你是 player N"
- 双方据此初始化各自的 `GomokuEngine`

---

## 二、高优先级 Bug（明显影响体验）

### 3. [高] 计时器生命周期泄漏

**位置:** `lib/features/gomoku/gomoku_timer.dart` 和 `gomoku_screen.dart:54`、`gomoku_handler.dart:72`、`gomoku_handler.dart:90`

**问题:** `Timer.periodic` 在以下场景没有被取消：

- **超时后**（`gomoku_screen.dart:54`）：检测到超时只显示了"超时"状态，但 `Timer.periodic` 仍在运行继续发射 tick
- **连接断开时**（`gomoku_handler.dart:72`）：`handleConnectionLost` 只添加了断线状态，没有停止计时器
- **dispose 时**（`gomoku_handler.dart:90`）：GameHandler 的 `dispose()` 中没有停止计时器的逻辑

**后果:**

- 计时器回调持续触发，可能尝试更新已销毁的 Widget 状态（`setState` on unmounted widget）
- 内存泄漏——每个对局创建一个新的 Timer，旧的不会被清理
- 如果重新开局，旧 Timer 和新 Timer 同时运行，倒计时显示混乱跳跃

**修复建议:** 在 `GomokuTurnTimerNotifier` 中添加 `dispose()` 方法调用 `_timer?.cancel()`，并在 `GomokuHandler.dispose()` 中调用 timer provider 的 dispose。

---

### 4. [高] 自动退出（Auto-Exit）竞态条件

**位置:** `lib/features/gomoku/gomoku_providers.dart` — `autoExitProvider`

**问题:** 游戏结束时弹出对话框，用户点击退出后的执行路径存在竞态：

1. `autoExitWatcher` 监听 `gomokuStateProvider`，检测到游戏结束（`GameStatus` 非 `playing`）
2. 自动触发 `Navigator.pop()` 返回大厅
3. 但 `gomoku_handler.dart` 的 `handleGameOver()` 可能也触发了返回
4. 两路 `Navigator.pop()` 几乎同时执行

**后果:** 触发 `double-pop`——两次返回操作，导致直接退出 App 或进入黑屏死界面。

**此外:** 代码中**未排除 `GameStatus.surrendered`**——主动认输时，auto-exit 可能意外地连赢家的屏幕一起 pop 掉。

**修复建议:**

- 使用 `Navigator.of(context).canPop()` 检查是否可以 pop
- 添加防抖标志（`_isExiting = true`）
- 排除 `GameStatus.surrendered` 的自动退出场景

---

### 5. [高] 异步初始化竞态条件

**位置:** `lib/features/lobby/lobby_screen.dart:83-97`

**问题:** `initState()` 中同时启动了多个异步操作，没有协调依赖关系：

```dart
_initMdns();           // 异步
_loadIdentity();       // 异步
_initConnectionManager(); // 异步
```

- `_initMdns()` 的回调中访问 `_deviceInfo`，但 `_loadIdentity()` 可能还没完成
- `_initConnectionManager()` 启动 WebSocket 服务器时，`_identity` 可能还没加载完成

**后果:** 偶现的启动失败——部分用户启动后设备名称为空、mDNS 服务未正常广播。重启后可能恢复正常（难以复现的间歇性 Bug）。

**修复建议:** 使用 `Future.wait()` 确保初始化顺序，或在各异步函数内做 null safety 检查。

---

## 三、中优先级问题

### 6. [中] 接收邀请时未做防重复点击

**位置:** `lib/features/invitation/widgets/incoming_invitation_sheet.dart`

**问题:** 点击"接受"按钮后，按钮没有进入 loading/disabled 状态。如果用户快速点击两次：

1. 两个 `invite_accepted` 消息会发送给对方
2. 两个导航请求会被推入导航栈

**后果:** 重复导航到游戏屏幕，返回时需要按两次返回键。对手方收到两条消息也可能导致状态混乱。

**修复建议:** 点击后立即设置 `_isAccepting = true` 并禁用按钮。

---

### 7. [中] 棋盘点击未做防重复

**位置:** `lib/features/gomoku/widgets/gomoku_board_widget.dart` — GestureDetector

**问题:** 快速点击棋盘同一格或相邻格可能触发两次 `onMove` 回调。第二次调用时 game engine 中该位置可能由于状态更新延迟，`canMove` 检查读到的是旧状态。

**后果:** 极少数情况下，同一格出现两次落子（一方连走两子），破坏游戏规则。

**修复建议:**

- 在 `GomokuStateNotifier` 中添加 `_isProcessingMove` 标志
- 收到消息处理完成前忽略新的落子操作

---

### 8. [中] 重赛（Rematch）时 opponentName 丢失

**位置:** `lib/features/gomoku/gomoku_providers.dart` — `resetGame()`

**问题:** 当双方同时快速点击"重赛"时：

1. A 方调用 `resetGame()` 清理游戏状态
2. B 方也调用 `resetGame()` 清理游戏状态
3. `opponentName` 存储在某个被 `resetGame()` 清理的 provider 或局部状态中

**后果:** 重赛开始后，玩家名称显示为空或"对手"。

**修复建议:** `resetGame()` 只重置游戏逻辑相关状态，保留对手名称等 UI 元数据。

---

### 9. [中] mDNS Peers 列表断开后未清理

**位置:** `lib/services/mdns_providers.dart`

**问题:** 当设备断开连接或退出 App 后，其所对应的条目在 `peers` 列表中不会自动移除。

**后果:** 设备列表中混入已经离线的设备，用户点击连接尝试时会长时间超时。列表随时间越积越多。

**修复建议:**

- 添加 mDNS 记录超时机制（如 30 秒未收到广播则自动移除）
- 或使用 TCP 连接状态作为存活性判断依据

---

### 10. [中] 邀请超时无视觉反馈

**位置:** `lib/features/lobby/lobby_screen.dart` — 发送邀请后的回调

**问题:** 发送邀请后，UI 只显示一个加载指示器。超时后（对方不应答），没有明确的超时提示——只是静默关闭邀请状态。

**后果:** 用户不知道对方是没收到、拒绝了、还是 App 出问题了。体验不够友好。

**修复建议:** 添加超时倒计时显示，超时后弹出 SnackBar 提示"对方未响应邀请"。

---

### 11. [中] 断线场景缺少状态恢复

**位置:** `lib/features/gomoku/gomoku_handler.dart` — `handleConnectionLost()`

**问题:** 连接断开后，游戏直接弹出 Game Over 对话框，没有任何重试机制。对于短暂断连的情况（如网络抖动），当前的处理方式过于激进。

**后果:** 正常对局中偶发的网络波动直接导致游戏结束，体验较差。

**修复建议:** 添加 3-5 秒重连等待窗口期，期间显示"连接中断，正在重连..."提示。

---

## 四、低优先级 / 体验优化

| # | 问题 | 位置 | 说明 |
|---|------|------|------|
| 12 | 空白状态提示缺失 | `lobby_screen.dart` | 没有设备时显示空列表，用户不知道是否在搜索中 |
| 13 | 连接状态指示不足 | 全局 | `ConnectionStatus` 变化时 UI 反馈不够明显 |
| 14 | 落子无音效/震动 | `gomoku_board_widget.dart` | 落子缺少触感反馈 |
| 15 | 游戏内无返回确认 | `gomoku_screen.dart` | 游戏中按返回直接退出，无"确认退出？"对话框 |
| 16 | 超时后无醒目提示 | `gomoku_screen.dart` | 计时器归零只显示状态变化，缺少视觉/动效提示 |
| 17 | 开局无"游戏开始"提示 | `gomoku_screen.dart` | 双方连接建立后直接开局，缺少过渡提示 |
| 18 | mDNS 端口/地址硬编码 | `mdns_service.dart` | 端口 55555 和组播地址直接写在代码中 |
| 19 | 棋盘渲染选中态与手势区域不一致 | `gomoku_board_widget.dart` | 高亮区域和实际点击区域可能不匹配 |
| 20 | 设备名未做截断处理 | 全局 | 长设备名可能破坏 UI 布局 |

---

## 五、整体风险评估

| 方面 | 风险等级 | 原因 |
|------|----------|------|
| **设备发现** | ❌ 不可用 | MDnsService 双重实例化，核心功能完全失效（Bug #1） |
| **游戏流程** | ⚠️ 不稳定 | Player index 逻辑模糊、竞态条件、计时器泄漏（Bug #2, #3, #5） |
| **游戏结束/退出** | ⚠️ 偶发崩溃 | Auto-exit 可能 double-pop，rematch 可能丢失状态（Bug #4, #8） |
| **并发防护** | ⚠️ 缺失 | 多处未做防重复点击，竞态条件多发（Bug #6, #7） |
| **UI/UX** | 🟡 体验粗糙 | 无超时反馈、无连接状态提示、无断线重连（Bug #10, #11, #12+） |
| **整体可用性** | ❌ **不可发布** | Bug #1 和 #2 直接影响核心功能，App 无法正常使用 |

---

## 六、修复优先级建议

### 第一优先（立即修复，影响核心功能）

1. **Bug #1** — MDnsService 单例化（设备发现完全修复）
2. **Bug #2** — Player index 逻辑统一（对局正常开始）

### 第二优先（高影响，用户感受明显）

3. **Bug #3** — Timer 生命周期管理（崩溃泄漏）
4. **Bug #4** — Auto-exit 竞态条件（崩溃风险）
5. **Bug #5** — 异步初始化竞态（间歇性启动失败）

### 第三优先（中影响，体验改进）

6. **Bug #6, #7** — 防重复点击
7. **Bug #8** — Rematch opponentName
8. **Bug #9** — mDNS 断开清理
9. **Bug #10** — 邀请超时反馈
10. **Bug #11** — 断线重连机制

### 第四优先（体验打磨）

11. **Bug #12-20** — UI/UX 优化项
