#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
ROOT_DIR="$(cd "$PROJECT_DIR/.." && pwd)"
OUTPUT_DIR="$ROOT_DIR/build/Release"

echo "🔨 Building Release version (signed)..."

cd "$PROJECT_DIR"
xcodegen generate

# Clean previous build
rm -rf "$OUTPUT_DIR"
mkdir -p "$OUTPUT_DIR"

# Build signed archive
if command -v xcpretty >/dev/null 2>&1; then
  xcodebuild \
    -project "$PROJECT_DIR/TaskManagerApp.xcodeproj" \
    -scheme "TaskManager" \
    -configuration Release \
    -destination "generic/platform=macOS" \
    -archivePath "$OUTPUT_DIR/TaskManager.xcarchive" \
    CODE_SIGN_IDENTITY="Developer ID Application: KACHERSOFT APPLIED SOLUTIONS CO.,LTD (4QZFT5Q76A)" \
    CODE_SIGN_STYLE=Manual \
    archive \
    | xcpretty --color
else
  xcodebuild \
    -project "$PROJECT_DIR/TaskManagerApp.xcodeproj" \
    -scheme "TaskManager" \
    -configuration Release \
    -destination "generic/platform=macOS" \
    -archivePath "$OUTPUT_DIR/TaskManager.xcarchive" \
    CODE_SIGN_IDENTITY="Developer ID Application: KACHERSOFT APPLIED SOLUTIONS CO.,LTD (4QZFT5Q76A)" \
    CODE_SIGN_STYLE=Manual \
    archive
fi

# Copy app to output directory
APP_PATH="$OUTPUT_DIR/TaskManager.xcarchive/Products/Applications/TaskManager.app"
rm -rf "$OUTPUT_DIR/TaskManager.app"
ditto "$APP_PATH" "$OUTPUT_DIR/TaskManager.app"

# Remove archive, keep only .app
rm -rf "$OUTPUT_DIR/TaskManager.xcarchive"

# Verify release signature and hardened runtime
codesign --verify --deep --strict --verbose=2 "$OUTPUT_DIR/TaskManager.app"
codesign_details="$(codesign -dv --verbose=4 "$OUTPUT_DIR/TaskManager.app" 2>&1)"
if ! printf '%s\n' "$codesign_details" | grep -q "flags=.*runtime"; then
  echo "❌ Hardened runtime is not enabled in Release build."
  exit 1
fi

echo ""
echo "✅ Release build complete!"
echo "📍 Location: $OUTPUT_DIR/TaskManager.app"
echo ""
echo "Install to Applications:"
echo "  ditto \"$OUTPUT_DIR/TaskManager.app\" /Applications/TaskManager.app"
