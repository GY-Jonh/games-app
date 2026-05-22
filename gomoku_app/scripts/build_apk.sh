#!/bin/bash
# ============================================================
#  Android APK 构建脚本 - Gomoku Together
#  用法: ./scripts/build_apk.sh [debug|release]
#  默认: debug
# ============================================================

set -e

# --- JDK 17 配置 (Android 构建需要 JDK 17+, Java 25 不兼容当前 Kotlin 版本) ---
export JAVA_HOME="/usr/local/lib/jdk17/jdk-17.0.19+10/Contents/Home"
export PATH="$JAVA_HOME/bin:$PATH"

# --- Android SDK 配置 ---
export ANDROID_HOME="/usr/local/share/android-commandlinetools"
export PATH="$ANDROID_HOME/cmdline-tools/latest/bin:$PATH"

# --- 国内镜像 (必需: pub.dev 在国内可能无法访问, 使用国内镜像确保构建成功) ---
export PUB_HOSTED_URL="https://pub.flutter-io.cn"
export FLUTTER_STORAGE_BASE_URL="https://storage.flutter-io.cn"

BUILD_TYPE="${1:-debug}"
PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"

echo "=========================================="
echo "  Game Hub - Android APK 构建"
echo "=========================================="
echo "构建类型: $BUILD_TYPE"
echo "项目目录: $PROJECT_DIR"
echo ""

cd "$PROJECT_DIR"

# 检查 Flutter
if ! command -v flutter &> /dev/null; then
    echo "❌ 错误: 未找到 Flutter 命令"
    echo "   请先安装 Flutter: https://flutter.dev/docs/get-started/install"
    exit 1
fi

echo "📦 获取依赖..."
flutter pub get

echo ""
echo "🔨 开始构建 APK ($BUILD_TYPE)..."

if [ "$BUILD_TYPE" = "release" ]; then
    # 检查 keystore 配置
    if [ ! -f "android/key.properties" ]; then
        echo ""
        echo "⚠️  未找到 android/key.properties"
        echo "   将使用 debug 签名构建"
        echo "   要构建正式版 APK，请参考:"
        echo "   https://flutter.dev/to/android-signature"
        echo ""
        flutter build apk --debug
        APK_PATH="build/app/outputs/flutter-apk/app-debug.apk"
    else
        flutter build apk --release
        APK_PATH="build/app/outputs/flutter-apk/app-release.apk"
    fi
else
    flutter build apk --debug
    APK_PATH="build/app/outputs/flutter-apk/app-debug.apk"
fi

echo ""
echo "=========================================="
echo "  ✅ 构建完成!"
echo "=========================================="
echo "APK 位置: $PROJECT_DIR/$APK_PATH"
echo ""
echo "📱 安装到手机:"
echo "   1. 打开手机上的 USB 调试"
echo "   2. 连接电脑并运行:"
echo "      flutter install"
echo "   3. 或将 APK 传到手机上直接安装"
echo ""

# 自动复制到项目根目录方便查找
cp "$APK_PATH" "$PROJECT_DIR/gomoku_app.apk" 2>/dev/null || true
echo "📋 已复制到: $PROJECT_DIR/gomoku_app.apk"
