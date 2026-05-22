# 构建说明

## 环境要求

- Flutter SDK（Channel stable，≥3.41）
- JDK 17（Gradle 8.14 不兼容 JDK 25 及以上版本）
- Android SDK Command-Line Tools

## 环境配置

### 1. 安装 JDK 17

```bash
brew install openjdk@17
```

> 注意：JDK 17 是 **keg-only** 安装，不会覆盖系统默认 Java 路径，需要额外配置。

### 2. 配置 Flutter 使用 JDK 17

```bash
flutter config --jdk-dir=/usr/local/opt/openjdk@17
```

配置后 Flutter 会记住此路径，后续构建无需重复设置。

### 3. 验证环境

```bash
flutter doctor
```

重点关注以下几项：

- `Flutter` — 正常
- `Android toolchain` — 正常（显示 JDK 版本为 17）
- 其余项（Xcode、Chrome 等）为可选，不影响 Android 构建

## 构建步骤

### 1. 设置国内镜像（必需）

此项目依赖的包通过国内镜像 `pub.flutter-io.cn` 缓存，构建前必须设置：

```bash
export PUB_HOSTED_URL=https://pub.flutter-io.cn
export FLUTTER_STORAGE_BASE_URL=https://storage.flutter-io.cn
```

> 若未设置，`flutter pub get` 会尝试连接 `pub.dev`，在部分网络环境下会失败（DNS 解析到 `0.0.0.0`，连接被拒绝）。

### 2. 代码检查（可选）

```bash
flutter analyze
```

确保无分析错误。

### 3. 运行测试（可选）

```bash
flutter test
```

### 4. 构建 Release APK

推荐使用构建脚本（自动配置 JDK、SDK 路径和镜像）：

```bash
./scripts/build_apk.sh release
```

或手动构建：

```bash
export PUB_HOSTED_URL=https://pub.flutter-io.cn
export FLUTTER_STORAGE_BASE_URL=https://storage.flutter-io.cn
flutter build apk --release
```

构建产物路径：

```
build/app/outputs/flutter-apk/app-release.apk
```

## 常见问题

### Gradle 构建失败，错误信息包含 Java 版本号

```
FAILURE: Build failed with an exception.
* What went wrong:
25.0.2
```

**原因**：系统默认 Java 版本过高（如 JDK 25），Gradle 8.14 不支持。

**解决**：确认已安装 JDK 17，并检查 `flutter config --list` 中 `jdk-dir` 是否正确指向 JDK 17 路径。

### `flutter build` 提示找不到 Java

```
Unable to locate a Java Runtime.
```

**原因**：系统默认 `/usr/bin/java` 是 macOS 占位程序，未安装真正的 JDK。

**解决**：通过 Homebrew 安装 JDK 17 并配置 `flutter config --jdk-dir`。

### 下载依赖过慢

Flutter doctor 可能提示网络超时，可配置国内镜像：

```bash
export PUB_HOSTED_URL=https://pub.flutter-io.cn
export FLUTTER_STORAGE_BASE_URL=https://storage.flutter-io.cn
```

或在 `android/gradle-wrapper.properties` 中已配置腾讯云 Gradle 镜像：

```
distributionUrl=https\://mirrors.cloud.tencent.com/gradle/gradle-8.14-all.zip
```

### `flutter pub get` 连接 pub.dev 失败

```
Got socket error trying to find package flutter_lints at https://pub.dev.
Failed to update packages.
```

**原因**：部分网络环境下 `pub.dev` DNS 解析到 `0.0.0.0`，连接被拒绝。此项目的依赖包已在 `pub.flutter-io.cn` 镜像中缓存。

**解决**：在构建前设置国内镜像：

```bash
export PUB_HOSTED_URL=https://pub.flutter-io.cn
export FLUTTER_STORAGE_BASE_URL=https://storage.flutter-io.cn
```

推荐始终使用 `./scripts/build_apk.sh` 脚本构建，脚本已自动配置国内镜像。
