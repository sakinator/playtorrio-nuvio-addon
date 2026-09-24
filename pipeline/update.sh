#!/usr/bin/env bash
# =============================================================================
#  PlayTorrio Nuvio Addon — Linux / Android (Termux) Update Pipeline
#
#  Usage:
#    bash pipeline/update.sh
# =============================================================================

set -e
cd "$(cd "$(dirname "$0")/.." && pwd)"   # run from project root

echo ""
echo "=========================================================="
echo " 🔄 PlayTorrio Upstream Scraper Update Pipeline"
echo "=========================================================="

# ── Find Dart ─────────────────────────────────────────────────────────────────
DART_EXE=""
if   [ -f "../dart-sdk/bin/dart" ]; then DART_EXE="$(realpath ../dart-sdk/bin/dart)"
elif [ -f "dart-sdk/bin/dart" ];    then DART_EXE="$(realpath dart-sdk/bin/dart)"
elif command -v dart &>/dev/null;   then DART_EXE="dart"
fi

if [ -z "$DART_EXE" ]; then
    echo " ERROR: Dart not found. Install with: pkg install dart (Termux)"
    exit 1
fi

# ── 1. git pull ───────────────────────────────────────────────────────────────
echo ""
echo " [1/3] Checking for upstream updates from PlayTorrioV3..."
cd upstream/PlayTorrioV3
BEFORE=$(git rev-parse HEAD)
git fetch origin main --quiet
AFTER=$(git rev-parse origin/main)

if [ "$BEFORE" = "$AFTER" ]; then
    echo "  → Already up-to-date (commit: $BEFORE)"
else
    echo "  → New commits found! Pulling..."
    git pull origin main
    NEW=$(git rev-parse HEAD)
    echo "  → Updated to: $NEW"
fi
cd ../..

# ── 2. Regenerate registry ────────────────────────────────────────────────────
echo ""
echo " [2/3] Regenerating scraper registry..."
"$DART_EXE" run tool/generate_registry.dart
echo "  → Registry regenerated ✓"

# ── 3. Hot-reload running server ──────────────────────────────────────────────
echo ""
echo " [3/3] Checking if addon server is running..."
PORT=7000
if [ -f "data/config.json" ]; then
    CFG_PORT=$(python3 -c "import json,sys; d=json.load(open('data/config.json')); print(d.get('port',7000))" 2>/dev/null || echo "7000")
    PORT="$CFG_PORT"
fi

if curl -s --max-time 3 -X POST "http://localhost:$PORT/api/pipeline/update" > /dev/null 2>&1; then
    echo "  → Server notified — scrapers hot-reloaded ✓"
else
    echo "  → Server not running. Changes will load on next start."
fi

echo ""
echo "=========================================================="
echo " ✅ Update complete!"
echo "=========================================================="
echo ""
