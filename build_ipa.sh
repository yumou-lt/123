#!/usr/bin/env bash
# ============================================================
# chat_app iOS 一键打包脚本（在 macOS 上运行）
# ------------------------------------------------------------
# 用法：
#   1) 把整个 flutter_app 目录放到 Mac 上（或 git clone 下来）
#   2) 在终端进入 flutter_app 目录，执行：
#        chmod +x build_ipa.sh
#        ./build_ipa.sh              # 打未签名 IPA（无需证书，先验证流程）
#        ./build_ipa.sh --signed     # 打签名 IPA（需先在 Xcode 配好签名）
#   3) 打包产物在 build/ios/ipa/ 下，直接拷走即可
# ============================================================
set -e

MODE="${1:-unsigned}"   # 默认 unsigned，传 --signed 则签名

echo "========================================"
echo " chat_app iOS 打包脚本（模式: $MODE）"
echo "========================================"

# ---------- 1. 环境检查 ----------
echo ""
echo "[1/5] 检查环境..."

if ! command -v flutter &>/dev/null; then
  echo "❌ 未找到 flutter，请先安装 Flutter SDK："
  echo "   https://docs.flutter.dev/get-started/install/macos"
  echo "   安装后执行: flutter doctor 确认正常"
  exit 1
fi

if ! xcode-select -p &>/dev/null; then
  echo "❌ 未找到 Xcode，请先到 App Store 安装 Xcode，然后执行："
  echo "   sudo xcodebuild -license accept"
  exit 1
fi

if ! command -v pod &>/dev/null; then
  echo "→ 未找到 CocoaPods，正在安装..."
  sudo gem install cocoapods
fi

echo "✓ 环境就绪 (flutter: $(flutter --version | head -1))"

# ---------- 2. 进入项目目录 ----------
echo ""
echo "[2/5] 定位项目目录..."
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$SCRIPT_DIR"
echo "✓ 当前目录: $PWD"

# ---------- 3. 拉取 Flutter 依赖 ----------
echo ""
echo "[3/5] 拉取 Flutter 依赖..."
flutter pub get

# ---------- 4. 安装 iOS Pods ----------
echo ""
echo "[4/5] 安装 iOS Pods 依赖..."
cd ios
pod install
cd ..

# ---------- 5. 构建 IPA ----------
echo ""
echo "[5/5] 开始构建 IPA..."
if [ "$MODE" == "--signed" ]; then
  # 签名模式：需要先在 ios/Runner.xcworkspace 的 Signing 里选好 Team / 证书
  echo "→ 签名构建（使用 Xcode 自动签名）..."
  flutter build ipa --release
else
  echo "→ 未签名构建（仅用于验证流程，装不了真机）..."
  flutter build ipa --release --no-codesign
fi

echo ""
echo "========================================"
echo " ✅ 构建完成！"
echo " IPA 所在目录: $PWD/build/ios/ipa/"
ls -lh build/ios/ipa/
echo "========================================"
