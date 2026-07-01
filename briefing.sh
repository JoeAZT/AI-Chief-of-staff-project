#!/bin/bash
# AI Chief of Staff — Morning Briefing
# Reads to-do list, calendar events, and project statuses, then passes to Claude

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/config.sh"
OBSIDIAN_ROOT="$BRIEFING_DIR"
TODO_FILE="$OBSIDIAN_ROOT/To-do.md"
PROJECTS_DIR="$OBSIDIAN_ROOT/Project ideas"
TODAY=$(date "+%Y-%m-%d")
DAY_OF_WEEK=$(date "+%A")

echo "================================================"
echo "  AI Chief of Staff — Morning Briefing"
echo "  $DAY_OF_WEEK, $TODAY"
echo "================================================"
echo ""

# 1. Read to-do list
echo "--- TO-DO LIST ---"
if [ -f "$TODO_FILE" ]; then
    cat "$TODO_FILE"
else
    echo "No to-do file found at $TODO_FILE"
fi
echo ""

# 2. Read today's calendar events via AppleScript
echo "--- TODAY'S CALENDAR ($TODAY) ---"
osascript "$SCRIPT_DIR/get-calendar.scpt" 2>/dev/null || echo "Could not read calendar. Check permissions."
echo ""

# 3. Read project statuses
echo "--- PROJECT STATUSES ---"
for file in "$PROJECTS_DIR"/*.md; do
    if [ -f "$file" ]; then
        filename=$(basename "$file" .md)
        # Extract the Status section (Priority, Stage, Next milestone)
        status=$(sed -n '/^## Status/,/^---/p' "$file" | grep -E '^\- \*\*' || echo "  No status section")
        echo "$filename:"
        echo "$status"
        echo ""
    fi
done

echo "================================================"
echo ""
echo "Briefing data collected. Pass to Claude for scheduling."
echo ""
