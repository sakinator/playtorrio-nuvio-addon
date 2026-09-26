#!/usr/bin/env bash
# ==========================================================
#  🔄 sakinator-MegaScraper Addon Update Pipeline (Linux/macOS)
# ==========================================================
set -e

cd "$(dirname "$0")/.."

# Locate Dart SDK
if command -v dart >/dev/null 2>&1; then
    DART_CMD="dart"
else
    echo "❌ Error: Dart SDK not found in PATH."
    echo "Please install Dart: https://dart.dev/get-dart"
    exit 1
fi

echo "Running platform-neutral Dart update pipeline..."
"$DART_CMD" run tool/update.dart "$@"
