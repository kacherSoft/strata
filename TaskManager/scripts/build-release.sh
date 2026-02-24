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
xcodebuild \
  -project "$PROJECT_DIR/TaskManagerApp.xcodeproj" \
  -scheme "TaskManager" \
  -configuration Release \
  -destination "generic/platform=macOS" \
  -archivePath "$OUTPUT_DIR/TaskManager.xcarchive" \
  CODE_SIGN_IDENTITY="Developer ID Application: KACHERSOFT APPLIED SOLUTIONS CO.,LTD (4QZFT5Q76A)" \
  CODE_SIGN_STYLE=Manual \
  archive \
  | xcpretty --color 2>/dev/null || cat

# Copy app to output directory
APP_PATH="$OUTPUT_DIR/TaskManager.xcarchive/Products/Applications/TaskManager.app"
cp -R "$APP_PATH" "$OUTPUT_DIR/"

# Remove archive, keep only .app
rm -rf "$OUTPUT_DIR/TaskManager.xcarchive"

echo ""
echo "✅ Release build complete!"
echo "📍 Location: $OUTPUT_DIR/TaskManager.app"
echo ""
echo "Install to Applications:"
echo "  ditto \"$OUTPUT_DIR/TaskManager.app\" /Applications/TaskManager.app"
