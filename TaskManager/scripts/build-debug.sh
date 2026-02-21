#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
ROOT_DIR="$(cd "$PROJECT_DIR/.." && pwd)"
OUTPUT_DIR="$ROOT_DIR/build/Debug"

echo "🔨 Building Debug version..."

cd "$PROJECT_DIR"
xcodegen generate

# Clean previous build
rm -rf "$OUTPUT_DIR"
mkdir -p "$OUTPUT_DIR"

# Build archive
xcodebuild \
  -project "$PROJECT_DIR/TaskManagerApp.xcodeproj" \
  -scheme "TaskManager" \
  -configuration Debug \
  -destination "generic/platform=macOS" \
  -archivePath "$OUTPUT_DIR/TaskManager.xcarchive" \
  CODE_SIGNING_ALLOWED=NO \
  CODE_SIGNING_REQUIRED=NO \
  archive \
  | xcpretty --color 2>/dev/null || cat

# Copy app to output directory
APP_PATH="$OUTPUT_DIR/TaskManager.xcarchive/Products/Applications/TaskManager.app"
cp -R "$APP_PATH" "$OUTPUT_DIR/"

# Remove archive, keep only .app
rm -rf "$OUTPUT_DIR/TaskManager.xcarchive"

echo ""
echo "✅ Debug build complete!"
echo "📍 Location: $OUTPUT_DIR/TaskManager.app"
echo ""
echo "Run: open \"$OUTPUT_DIR/TaskManager.app\""
