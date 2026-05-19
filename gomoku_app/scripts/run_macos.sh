#!/bin/bash
# ============================================================
#  macOS 上的"运行预览"脚本
#  用于在 macOS 上验证 App（仅限 UI，无局域网发现）
#  用法: ./scripts/run_macos.sh
# ============================================================

set -e
PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"

cd "$PROJECT_DIR"

echo "🔍 检查 Flutter..."
flutter doctor 2>&1 | head -10

echo ""
echo "🚀 启动 macOS 版本（预览模式）..."
echo "   注意: macOS 版本用于 UI 预览，"
echo "   局域网发现需要真机部署。"
echo ""

flutter run -d macos 2>&1 || {
    echo ""
    echo "❌ macOS 运行失败"
    echo "   如果未启用 macOS 支持，请运行:"
    echo "   flutter config --enable-macos-desktop"
}
