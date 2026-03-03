#!/bin/bash
# TripWit Validation Script
# Claude Code runs this after every code change
PROJECT_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$PROJECT_ROOT"

PASS=0
FAIL=0
SIMDEVICE="platform=iOS Simulator,name=iPhone 17 Pro"

green() { printf "\033[32m%s\033[0m\n" "$1"; }
red() { printf "\033[31m%s\033[0m\n" "$1"; }

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo " TripWit Validation"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# ── STEP 1: TripCore build ──────────────────────────────
echo "▶ Step 1: TripCore package build"
cd "$PROJECT_ROOT/Packages/TripCore"
if swift build 2>&1 | tail -1 | grep -q "Build complete"; then
    PASS=$((PASS + 1)); green "  ✓ TripCore builds"
else
    FAIL=$((FAIL + 1)); red "  ✗ TripCore build FAILED"
    swift build 2>&1 | grep "error:" | head -5
fi

# ── STEP 2: TripCore tests ─────────────────────────────
echo ""
echo "▶ Step 2: TripCore tests"
cd "$PROJECT_ROOT/Packages/TripCore"
CORE_TEST_OUT=$(swift test 2>&1)
CORE_EXIT=$?
if [ $CORE_EXIT -eq 0 ]; then
    COUNT=$(echo "$CORE_TEST_OUT" | grep -oE "[0-9]+ tests? passed" | head -1)
    PASS=$((PASS + 1)); green "  ✓ TripCore tests passed ($COUNT)"
else
    FAIL=$((FAIL + 1)); red "  ✗ TripCore tests FAILED"
    echo "$CORE_TEST_OUT" | grep -E "FAIL|error:" | head -5
fi

# ── STEP 3: App build ──────────────────────────────────
echo ""
echo "▶ Step 3: App build (xcodebuild)"
cd "$PROJECT_ROOT"
APP_BUILD_OUT=$(xcodebuild build -scheme TripWit -destination "$SIMDEVICE" -quiet 2>&1)
APP_BUILD_EXIT=$?
if [ $APP_BUILD_EXIT -eq 0 ]; then
    PASS=$((PASS + 1)); green "  ✓ App builds for simulator"
else
    FAIL=$((FAIL + 1)); red "  ✗ App build FAILED"
    echo "$APP_BUILD_OUT" | grep "error:" | head -10
fi

# ── STEP 4: App tests ──────────────────────────────────
echo ""
echo "▶ Step 4: App tests (xcodebuild test)"
cd "$PROJECT_ROOT"
APP_TEST_OUT=$(xcodebuild test -scheme TripWit -destination "$SIMDEVICE" -only-testing:TripWitTests 2>&1)
# Check Swift Testing output for actual test failures (more reliable than
# xcodebuild exit code, which can be non-zero due to Core Data warnings)
REAL_FAILURES=$(echo "$APP_TEST_OUT" | grep -c "^✘ Test .* failed after")
if [ "$REAL_FAILURES" -eq 0 ] && echo "$APP_TEST_OUT" | grep -q "Suite TripWitTests"; then
    PASS=$((PASS + 1)); green "  ✓ App tests passed"
else
    FAIL=$((FAIL + 1)); red "  ✗ App tests FAILED"
    echo "$APP_TEST_OUT" | grep "^✘" | head -10
fi

# ── SUMMARY ─────────────────────────────────────────────
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
TOTAL=$((PASS + FAIL))
if [ $FAIL -eq 0 ]; then
    green "  ALL PASSED ($PASS/$TOTAL steps)"
else
    red "  $FAIL FAILED ($PASS passed, $FAIL failed)"
fi
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

exit $FAIL
