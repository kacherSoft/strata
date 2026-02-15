#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
ROOT_DIR="$(cd "$PROJECT_DIR/.." && pwd)"
ARCHIVE_PATH="${1:-$ROOT_DIR/build/TaskManager.xcarchive}"

cd "$PROJECT_DIR"
xcodegen generate

xcodebuild \
  -project "$PROJECT_DIR/TaskManagerApp.xcodeproj" \
  -scheme "TaskManager" \
  -configuration Release \
  -destination "generic/platform=macOS" \
  -archivePath "$ARCHIVE_PATH" \
  CODE_SIGNING_ALLOWED=NO \
  CODE_SIGNING_REQUIRED=NO \
  archive

echo "Archive: $ARCHIVE_PATH"
echo "App: $ARCHIVE_PATH/Products/Applications/TaskManager.app"
