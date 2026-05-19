# Gomoku Together 🎮

情侣专属双人游戏 App —— 你和 TA 的手机连上同一 WiFi，就能一起下五子棋。

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
| Flutter 3.x | 跨平台框架 | ✅ **必须**（已装好） |
| Android 命令行工具 | 编译 Android APK | ✅ **必须**（装上面 3 条命令即可） |
| Xcode | 编译 iOS IPA | ❌ 可选，不装也能用 |
| Android Studio | 图形化开发 | ❌ 可选，命令行工具代替 |

**不装 Xcode，iPhone 咋办？** → 见下方「iOS 云编译」方案。

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

构建完成后：
1. APK 在 `build/app/outputs/flutter-apk/app-debug.apk`
2. 会同时复制到项目根目录 `gomoku_app.apk`
3. 把 APK 传到小米手机上直接安装即可

### iOS (IPA) — 侧载到 iPhone

> ⚠️ 需要 Apple 开发者账号
> - **免费账号**: 每 7 天需重新签名
> - **付费账号** ($99/年): 签名有效期一年

**方案 A：用 GitHub Actions 云编译（推荐，不装 Xcode）**

项目已配置好云编译工作流（`.github/workflows/build_ios.yml`）：
1. 把代码推送到你的 GitHub 仓库
2. 在 GitHub 页面点 **Actions → Build iOS IPA → Run workflow**
3. 等几分钟，下载生成的 `Runner.app` 压缩包
4. 用 [Sideloadly](https://sideloadly.io/) 签名安装到 iPhone

> 快速推送代码：
> ```bash
> cd /Users/aa123/Desktop/lao\ gong/work/Qoder/games/gomoku_app
> git init && git add . && git commit -m "init"
> # 在 GitHub 新建仓库后：
> git remote add origin https://github.com/你的用户名/gomoku_app.git
> git push -u origin main
> ```

**方案 B：有 Xcode 时本地构建**

```bash
./scripts/build_ipa.sh
# 用 Sideloadly 签名生成的 .app 即可安装
```

---

## 如何使用

1. 你和 TA 各装好 App
2. 确保两台手机**连接同一个 WiFi**
3. 打开 App → 自动搜索到对方 → 显示在线状态
4. 点击「邀请」→ 对方收到弹窗 →「接受」
5. 开始下五子棋！

---

## 项目结构

```
gomoku_app/
├── lib/
│   ├── main.dart               # 入口
│   ├── app.dart                # 主题 + 路由
│   ├── core/                   # 常量、主题、工具
│   ├── models/                 # 数据模型
│   ├── services/               # 引擎、网络、发现
│   ├── providers/              # Riverpod 状态管理
│   └── features/               # 大厅、邀请、游戏
├── test/
│   └── unit/
│       └── game_engine_test.dart  # 33 个测试全部通过
├── scripts/
│   ├── build_apk.sh            # Android 构建
│   ├── build_ipa.sh            # iOS 构建
│   └── run_macos.sh            # macOS 预览
└── ios/ & android/             # 平台配置
```

## 技术栈

- **框架**: Flutter 3.41 + Dart
- **状态管理**: Riverpod
- **局域网发现**: UDP 组播 (239.255.0.1:55555)
- **游戏通信**: WebSocket
- **UI 渲染**: CustomPaint 手绘棋盘
- **测试**: 33 个单元测试覆盖全部核心逻辑

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
- 当前首款游戏：五子棋（15×15 标准棋盘）

---

*Made with ❤️ for you and your partner*
