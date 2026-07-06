#!/bin/bash
# AI Chief of Staff — Trigger every macOS permission prompt in one sitting.
# Touches each protected surface the system uses (files, Calendar, Messages)
# so users approve all prompts once at install time, instead of prompts
# appearing scattered across the first few scheduled runs.
# Run via the Runner app so grants attach to it: install-automation.sh does this.

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/config.sh"

echo "1/3 Files access (briefing folder)..."
ls "$BRIEFING_DIR" > /dev/null

echo "2/3 Calendar access..."
# Launch Calendar first and allow 5 min so the permission prompt isn't killed
# by the default 2-min AppleEvent timeout while the user reads it
open -gj -a Calendar
osascript -e 'with timeout of 300 seconds
tell application "Calendar" to get name of calendars
end timeout' > /dev/null

if [ -n "$PHONE_NUMBER" ]; then
    echo "3/3 Messages access (phone delivery)..."
    osascript -e 'tell application "Messages" to get name' > /dev/null
else
    echo "3/3 Messages — skipped (no PHONE_NUMBER in config.sh)"
fi

echo "All permissions granted."
