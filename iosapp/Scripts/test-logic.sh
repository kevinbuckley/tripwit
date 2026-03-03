#!/bin/bash
# Quick validation: just TripCore logic tests (no simulator needed)
# Use this for fast iteration on business logic
set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$PROJECT_ROOT/Packages/TripCore"

echo "▶ TripCore: build + test (fast, no simulator)"
echo ""

swift test 2>&1 | grep -E "(Test Case|passed|failed|error:|Build complete|Compiling)" | while read -r line; do
    if echo "$line" | grep -q "passed"; then
        echo -e "\033[32m  $line\033[0m"
    elif echo "$line" | grep -q "failed\|error:"; then
        echo -e "\033[31m  $line\033[0m"
    else
        echo "  $line"
    fi
done
