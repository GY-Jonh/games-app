# Games App 🎮

情侣专属双人游戏 App —— 你和 TA 的手机连上同一 WiFi，就能一起玩双人游戏。支持多人对战，无需服务器，纯 P2P 局域网通信。

> **当前已实现：五子棋（17×17 棋盘）**
> **架构已预留多游戏扩展接口，可轻松添加更多游戏类型**

---

## 核心功能

### 局域网 P2P 对战
- **无需互联网**：两台设备连上同一 WiFi 即可发现对方
- **零配置**：自动发现、自动连接，无需手动输入 IP 地址
- **mDNS 服务发现**：基于 UDP 组播（端口 55555）广播设备在线状态
- **WebSocket 直连**：设备间建立直接的 WebSocket 连接，低延迟通信
- **游戏状态广播**：显示对方是否在游戏中（`idle` / `playing`）

### 游戏大厅

| 功能 | 说明 |
|------|------|
| 自动发现 | 打开 App 自动搜索同 WiFi 下的玩家 |
| 在线状态 | 实时显示在线玩家列表及人数 |
| 设备昵称 | 自定义昵称，刷新后生效 |
| 手动刷新 | 点击顶部刷新按钮重新搜索 |
| 10 秒超时 | 超过 10 秒未广播的设备自动从列表移除 |

### 邀请系统

| 功能 | 说明 |
|------|------|
| 游戏选择 | 邀请前弹出底部面板选择游戏类型 |
| 发送邀请 | 点击在线玩家即可发送游戏邀请 |
| 接收弹窗 | 收到邀请时底部弹出邀请面板 |
| 接受/拒绝 | 接受则自动建立连接并进入游戏 |
| 取消邀请 | 发送方可随时取消，30 秒超时自动取消 |
| 断线检测 | 网络异常时自动重置邀请状态 |

### 五子棋游戏

| 功能 | 说明 |
|------|------|
| 17×17 棋盘 | 标准五子棋棋盘（17×17 规格） |
| 手绘渲染 | 使用 CustomPaint 绘制棋盘与棋子 |
| 点击选择 | 首次点击选择位置（预览），再次点击确认落子 |
| 先黑后白 | 邀请方执黑先手，被邀请方执白后手 |
| 五子连珠 | 横、竖、斜四个方向检测胜利 |
| 和棋判定 | 棋盘满局判定为平局 |
| 回合计时器 | 每人独立计时，超时自动判负 |
| 退出确认 | 游戏中退出弹窗确认，防止误触 |

### 重开机制

| 功能 | 说明 |
|------|------|
| 再来一局 | 游戏结束后可发起重开请求 |
| 换先后手 | 重开时自动交换双方先后手 |
| 双方同步 | 双方同时发起重开请求时自动同意 |
| 拒绝处理 | 对方拒绝重开后返回大厅 |

### 连接管理

| 功能 | 说明 |
|------|------|
| 连接检测 | 实时监控 WebSocket 连接状态 |
| 断线通知 | 连接断开时弹出提示并自动返回大厅 |
| 邀请超时 | 30 秒未响应自动取消邀请 |
| 重入保护 | 防止游戏过程中重复操作 |

---

## 快速开始

### 环境要求

**最小方案（推荐，不用装 Xcode/Android Studio）**：

```bash
# 1. 安装 Android 命令行工具（替代 Android Studio，约 200MB）
brew install android-commandlinetools android-platform-tools

# 2. 配置 SDK
export ANDROID_HOME=$(brew --prefix)/share/android-commandlinetools
echo 'export ANDROID_HOME=$(brew --prefix)/share/android-commandlinetools' >> ~/.zshrc

$ANDROID_HOME/cmdline-tools/latest/bin/sdkmanager \
  "platforms;android-34" \
  "build-tools;34.0.0"

# 3. 告诉 Flutter 使用命令行工具
flutter config --android-sdk $ANDROID_HOME

# 4. 验证
flutter doctor
```

| 工具 | 用途 | 必须？ |
|------|------|--------|
| Flutter 3.x | 跨平台框架 | ✅ **必须** |
| Android 命令行工具 | 编译 Android APK | ✅ **必须** |
| Xcode | 编译 iOS IPA | ❌ 可选 |
| Android Studio | 图形化开发 | ❌ 可选 |

### 获取依赖

```bash
cd gomoku_app
flutter pub get
```

---

## 构建安装包

### Android (APK)

```bash
# debug 版（无需签名，直接安装）
./scripts/build_apk.sh debug

# release 版（需配置签名）
./scripts/build_apk.sh release
```

APK 路径：`build/app/outputs/flutter-apk/app-debug.apk`

### iOS (IPA) — GitHub Actions 云编译

项目已配置好云编译工作流（`.github/workflows/build_ios.yml`）：
1. 推送代码到 GitHub 仓库
2. 在 GitHub 页面点 **Actions → Build iOS IPA → Run workflow**
3. 下载生成的 `Runner.app` 压缩包
4. 用 [Sideloadly](https://sideloadly.io/) 签名安装到 iPhone

---

## 如何使用

1. 你和 TA 各装好 App
2. 确保两台手机**连接同一个 WiFi**
3. 打开 App → 自动搜索到对方 → 显示在线状态
4. 点击「邀请」→ 选择游戏 → 对方收到弹窗 →「接受」
5. 开始对战！

---

## 项目架构

### 多游戏框架

项目采用**插件式游戏架构**，新增游戏只需三步：

1. 创建游戏模块（如 `checkers_module.dart`）
2. 实现 `GameHandler` 接口
3. 在 `main.dart` 中调用 `YourModule.register()`

```
                                ┌─────────────────┐
                                │   GameRegistry   │
                                │  (游戏注册中心)   │
                                └──────┬──────────┘
                                       │
              ┌────────────────────────┼────────────────────┐
              │                        │                     │
    ┌─────────▼─────────┐   ┌─────────▼─────────┐   ┌───────▼───────┐
    │  GomokuHandler    │   │  (未来: 象棋/围棋)  │   │  (更多游戏...) │
    │  implements       │   │  implements        │   │               │
    │  GameHandler      │   │  GameHandler       │   │               │
    └───────────────────┘   └───────────────────┘   └───────────────┘
```

**`GameHandler` 接口**定义了游戏全生命周期：

| 方法 | 调用时机 |
|------|----------|
| `initGame` | 邀请被接受后，初始化游戏状态 |
| `handleMessage` | 处理游戏相关网络消息 |
| `handleConnectionLost` | 对手断线时处理 |
| `buildScreen` | 构建游戏页面 Widget |
| `dispose` | 页面 pop 后清理资源 |

### 通信架构

```
┌──────────┐    mDNS (UDP 55555)    ┌──────────┐
│ 设备 A   │ ◄────────────────────► │ 设备 B   │
│          │   发现了！我在: 192...  │          │
└────┬─────┘                        └────┬─────┘
     │           WebSocket               │
     │  ◄────────────────────────────►   │
     │  game_invite / invite_accepted    │
     │  game_move / game_over / rematch  │
     └──────────────────────────────────┘
```

- **mDNS 服务**：UDP 组播广播设备信息（IP、端口、设备名、游戏状态）
- **WebSocket 连接**：邀请时发起直连，后续所有消息走 WebSocket
- **双工通信**：双方均可发送消息，支持完整对战时序

### 目录结构

```
gomoku_app/
├── lib/
│   ├── main.dart                        # 入口：初始化并注册游戏模块
│   ├── app.dart                         # 主题 + MaterialApp
│   ├── core/                            # 基础框架
│   │   ├── constants/                   #   应用与游戏常量
│   │   ├── game_framework/              #   游戏注册中心 + 抽象接口
│   │   ├── theme/                       #   主题配色
│   │   └── utils/                       #   设备信息工具
│   ├── models/                          # 数据模型
│   │   ├── network_message.dart         #   网络消息协议
│   │   └── peer_device.dart             #   对端设备信息
│   ├── services/                        # 核心服务
│   │   ├── mdns_service.dart            #   mDNS 局域网发现
│   │   ├── websocket_server.dart        #   WebSocket 服务端
│   │   ├── websocket_client.dart        #   WebSocket 客户端
│   │   └── connection_manager.dart      #   连接管理器
│   ├── providers/                       # Riverpod 状态管理
│   │   ├── mdns_providers.dart          #   发现服务状态
│   │   ├── connection_providers.dart    #   连接状态
│   │   ├── invitation_providers.dart    #   邀请状态
│   │   └── player_providers.dart        #   玩家信息
│   └── features/                        # 游戏功能模块
│       ├── lobby/                       #   游戏大厅
│       ├── invitation/                  #   邀请 UI
│       └── gomoku/                      #   五子棋游戏
│           ├── models/                  #     棋子、走子模型
│           ├── gomoku_engine.dart       #     核心引擎
│           ├── gomoku_handler.dart      #     游戏处理器
│           ├── gomoku_providers.dart    #     游戏状态管理
│           ├── gomoku_screen.dart       #     游戏页面
│           ├── gomoku_timer.dart        #     回合计时器
│           └── widgets/                 #     棋盘、信息栏、结算弹窗
├── test/
│   └── unit/
│       └── gomoku_engine_test.dart      # 核心引擎单元测试
└── scripts/
    ├── build_apk.sh                     # Android 构建
    ├── build_ipa.sh                     # iOS 构建
    └── run_macos.sh                     # macOS 预览
```

---

## 技术栈

| 类别 | 技术 |
|------|------|
| **框架** | Flutter 3.41 + Dart |
| **状态管理** | Riverpod（StateNotifier + StateProvider） |
| **局域网发现** | UDP 组播 / mDNS (239.255.0.1:55555) |
| **游戏通信** | WebSocket（设备间直连） |
| **UI 渲染** | CustomPaint 手绘棋盘 |
| **测试覆盖** | 33 个单元测试覆盖全部核心引擎逻辑 |

---

## 网络协议

### 消息类型

| 类型 | 方向 | 说明 |
|------|------|------|
| `peer_info` | 连接建立后 | 交换设备信息 |
| `game_invite` | 邀请方 → 被邀请方 | 发送游戏邀请 |
| `invite_accepted` | 被邀请方 → 邀请方 | 接受邀请 |
| `invite_declined` | 被邀请方 → 邀请方 | 拒绝邀请 |
| `invite_cancelled` | 邀请方 → 被邀请方 | 取消邀请 |
| `game_move` | 双方 | 传递走子数据 |
| `game_over` | 双方 | 通知游戏结束（赢/超时/退出/断线） |
| `rematch_request` | 双方 | 请求重开一局 |
| `rematch_response` | 双方 | 响应重开请求（接受/拒绝） |
| `connection_lost` | 自动触发 | 检测到连接断开 |

---

## 常见问题

**Q: 搜索不到对方？**
- 确认两台手机连的是同一个 WiFi
- 检查路由器是否开启了"AP 隔离"（公司/酒店 WiFi 常见）
- 关闭防火墙或 VPN

**Q: iOS 安装后打不开？**
- 免费签名每 7 天过期，需要用侧载工具重新安装
- 安装后需在「设置 → 通用 → VPN 与设备管理」中信任证书

**Q: Android 安装 APK 报错？**
- 打开「设置 → 安全 → 允许安装未知来源应用」
- 确保下载的 APK 完整

**Q: 支持其他游戏吗？**
- 架构已预留扩展接口，后续可轻松添加象棋、围棋等
- 当前首款游戏：五子棋（17×17 标准棋盘）

---

## 开发路线

- [x] 多游戏框架（GameRegistry + GameHandler）
- [x] mDNS 局域网设备发现
- [x] WebSocket P2P 通信
- [x] 游戏大厅（设备列表 + 邀请系统）
- [x] 五子棋核心引擎（17×17 棋盘）
- [x] 回合计时器 + 超时判负
- [x] 重开机制（换先后手）
- [x] 断线检测与自动退出
- [ ] 更多游戏类型（象棋、围棋等）

---

*Made with ❤️ for you and your partner*
