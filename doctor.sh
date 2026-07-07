#!/bin/bash
# AI Chief of Staff — Health check
# Verifies install, Claude auth, automation, and permissions, and prints the fix
# for anything broken. Run this whenever a briefing doesn't arrive.
# Note: includes a live Claude call to test the scheduled-run environment (~15s).

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PASS=0
FAIL=0

ok()  { echo "  ✓ $1"; PASS=$((PASS + 1)); }
bad() { echo "  ✗ $1"; echo "      fix: $2"; FAIL=$((FAIL + 1)); }

echo ""
echo "AI Chief of Staff — doctor"
echo ""

# 1. Config generated?
if [ -f "$SCRIPT_DIR/config.sh" ]; then
    source "$SCRIPT_DIR/config.sh"
    ok "config.sh exists"
else
    bad "config.sh missing" "run: bash setup.sh"
fi

# 2. Output folder reachable?
if [ -n "$BRIEFING_DIR" ] && [ -d "$BRIEFING_DIR" ]; then
    ok "output folder exists ($BRIEFING_DIR)"
else
    bad "output folder missing (${BRIEFING_DIR:-not set})" "re-run: bash setup.sh"
fi

# 3. Claude CLI installed?
if command -v claude > /dev/null; then
    ok "claude CLI found ($(command -v claude))"

    # 4. Does Claude work in the scheduled-run environment? Scheduled runs get no
    # shell profile — an ANTHROPIC_API_KEY exported in .zshrc is invisible to them.
    # env -i reproduces that, catching "works in my terminal, fails at 9am".
    echo "  … testing Claude in the scheduled-run environment (takes ~15s)"
    # env matches what launchd provides; claude exits 0 even when not logged in,
    # so validate the reply content rather than the exit code
    RESULT=$(echo "Reply with the word OK and nothing else." | env -i HOME="$HOME" USER="$USER" LOGNAME="$USER" SHELL="$SHELL" TMPDIR="${TMPDIR:-/tmp}" PATH="/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin" claude --print 2>&1)
    if [[ "$RESULT" == *OK* ]]; then
        ok "claude responds in scheduled-run environment"
    else
        bad "claude fails outside your shell profile — scheduled runs will fail the same way" "run 'claude' once and log in interactively (credentials land in the keychain, which scheduled runs can read; an API key in your shell profile cannot be)"
    fi
else
    bad "claude CLI not found" "install Claude Code: https://docs.anthropic.com/en/docs/claude-code"
fi

# 5. LaunchAgents loaded?
for label in com.cos.morning com.cos.evening com.cos.weekly; do
    if launchctl list "$label" > /dev/null 2>&1; then
        ok "$label loaded"
    else
        bad "$label not loaded" "run: bash install-automation.sh"
    fi
done

# 6. Runner app present?
if [ -d "$HOME/Applications/Chief of Staff Runner.app" ]; then
    ok "Chief of Staff Runner.app installed"
else
    bad "Chief of Staff Runner.app missing" "run: bash install-automation.sh"
fi

# 7. Permission errors in recent run logs? (evidence from the real scheduled path)
PERM_ERR=0
for f in "$SCRIPT_DIR"/logs/*.err "$SCRIPT_DIR"/logs/calendar-errors.log; do
    [ -s "$f" ] || continue
    if grep -q "Operation not permitted" "$f"; then
        bad "'Operation not permitted' in logs/$(basename "$f")" "the Runner lacks file access — re-run: bash install-automation.sh and approve the prompts"
        PERM_ERR=1
    fi
    if grep -qE -- '-1743|Not authorized|not allowed' "$f"; then
        bad "automation denied in logs/$(basename "$f")" "run: tccutil reset AppleEvents && bash install-automation.sh (macOS never re-asks after a denial)"
        PERM_ERR=1
    fi
done
[ "$PERM_ERR" -eq 0 ] && ok "no permission errors in recent logs"

# 8. Did today's briefing arrive?
TODAY=$(date "+%Y-%m-%d")
if [ -n "$BRIEFING_DIR" ] && [ -f "$BRIEFING_DIR/Daily briefings/$TODAY.md" ]; then
    ok "today's briefing exists"
else
    echo "  – no briefing for today yet (fine if the scheduled time hasn't passed)"
    echo "      test the full run now: launchctl kickstart gui/\$(id -u)/com.cos.morning"
fi

echo ""
if [ "$FAIL" -eq 0 ]; then
    echo "All good — $PASS checks passed."
else
    echo "$FAIL problem(s) found, $PASS checks passed. Fixes are listed above."
    exit 1
fi
