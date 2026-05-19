#!/bin/bash
# ============================================================
#  iOS IPA 构建脚本 - Gomoku Together
#  用于侧载安装（需要 Xcode + Apple 开发者账号）
#  
#  用法:
#    ./scripts/build_ipa.sh            # 构建 .app (无签名)
#    ./scripts/build_ipa.sh sign       # 构建 + ad-hoc 签名
# ============================================================

set -e

BUILD_MODE="${1:-app}"
PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"

echo "=========================================="
echo "  Gomoku Together - iOS 构建"
echo "=========================================="
echo "项目目录: $PROJECT_DIR"
echo ""

cd "$PROJECT_DIR"

# 检查 Xcode
if ! command -v xcodebuild &> /dev/null; then
    echo "❌ 错误: 未找到 Xcode"
    echo "   请从 Mac App Store 安装 Xcode"
    exit 1
fi

XCODE_VERSION=$(xcodebuild -version | head -1)
echo "🛠   Xcode 版本: $XCODE_VERSION"

# 检查 Flutter
if ! command -v flutter &> /dev/null; then
    echo "❌ 错误: 未找到 Flutter 命令"
    exit 1
fi

echo "📦 获取依赖..."
flutter pub get

echo ""
echo "🔨 安装 CocoaPods 依赖..."
cd ios
pod install --repo-update 2>/dev/null || echo "   CocoaPods 跳过（非必需）"
cd ..

echo ""
echo "🔨 构建 iOS ($BUILD_MODE)..."

if [ "$BUILD_MODE" = "sign" ]; then
    # --------------------------------------------------
    # 构建 + ad-hoc 签名（需要 Apple Developer 账号）
    # --------------------------------------------------
    echo ""
    echo "📋 列出可用签名证书:"
    security find-identity -v -p codesigning 2>/dev/null || echo "   无可用证书"

    echo ""
    echo "📋 列出可用 Provisioning Profile:"
    PROFILE_DIR="$HOME/Library/MobileDevice/Provisioning Profiles"
    if [ -d "$PROFILE_DIR" ]; then
        ls "$PROFILE_DIR"/*.mobileprovision 2>/dev/null | head -5 || echo "   无"
    fi

    echo ""
    echo "🔐 构建带签名的 IPA..."
    flutter build ios --release --no-codesign

    IOS_BUILD_DIR="build/ios/iphoneos"
    APP_PATH="$IOS_BUILD_DIR/Runner.app"
    PAYLOAD_DIR="$IOS_BUILD_DIR/Payload"

    echo "📦 打包 IPA..."
    mkdir -p "$PAYLOAD_DIR"
    cp -r "$APP_PATH" "$PAYLOAD_DIR/"
    cd "$IOS_BUILD_DIR"
    zip -r "$PROJECT_DIR/gomoku_app.ipa" Payload/ > /dev/null 2>&1
    cd "$PROJECT_DIR"
    rm -rf "$PAYLOAD_DIR"

    echo ""
    echo "=========================================="
    echo "  ✅ IPA 已生成"
    echo "=========================================="
    echo "IPA 位置: $PROJECT_DIR/gomoku_app.ipa"
    echo ""
    echo "📱 侧载安装方式:"
    echo "   方法 1: 使用 SideStore / AltStore"
    echo "   方法 2: 使用 Sideloadly (Windows/Mac)"
    echo "   方法 3: 使用 Xcode + 个人开发者账号"
    echo ""
    echo "⚠️  注意:"
    echo "   - 免费账号每 7 天需重新签名"
    echo "   - 付费账号 ($99/年) 可签名一年"
else
    # --------------------------------------------------
    # 构建 .app（无签名，用于调试）
    # --------------------------------------------------
    flutter build ios --debug --no-codesign

    APP_PATH="build/ios/iphonesimulator/Runner.app"
    if [ -f "build/ios/iphoneos/Runner.app" ]; then
        APP_PATH="build/ios/iphoneos/Runner.app"
    fi

    echo ""
    echo "=========================================="
    echo "  ✅ .app 已生成"
    echo "=========================================="
    echo ".app 位置: $PROJECT_DIR/$APP_PATH"
    echo ""
    echo "📱 如需侧载安装:"
    echo "   1. 准备 Apple 开发者账号"
    echo "   2. 运行: ./scripts/build_ipa.sh sign"
    echo "   3. 或用侧载工具直接安装 .app"
fi

echo ""
echo "💡 提示: 如果构建遇到问题，尝试:"
echo "   flutter clean && flutter pub get"
echo "   cd ios && pod deintegrate && pod install && cd .."
