#!/bin/bash
# AI Chief of Staff — Review and approve today's schedule
# Run this after the morning briefing to add events to Apple Calendar

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
[ -f "$SCRIPT_DIR/config.sh" ] || { echo "No config.sh found — run: bash setup.sh first"; exit 1; }
source "$SCRIPT_DIR/config.sh"
SCHEDULE_FILE="$SCRIPT_DIR/today-schedule.csv"
BRIEFINGS_DIR="$BRIEFING_DIR/Daily briefings"
TODAY=$(date "+%Y-%m-%d")
OUTPUT_FILE="$BRIEFINGS_DIR/$TODAY.md"

if [ ! -s "$SCHEDULE_FILE" ]; then
    echo "No schedule to approve. Run the morning briefing first."
    exit 1
fi

echo ""
echo "=== Today's proposed schedule ==="
while IFS='|' read -r START END TITLE; do
    [ -z "$START" ] && continue
    echo "  $START – $END  $TITLE"
done < "$SCHEDULE_FILE"
echo "================================="
echo ""

read -p "Add these events to Apple Calendar? (y/n) " -n 1 -r
echo ""

if [[ $REPLY =~ ^[Yy]$ ]]; then
    bash "$SCRIPT_DIR/create-events.sh" "$SCHEDULE_FILE"
    # Update the briefing note
    if [ -f "$OUTPUT_FILE" ]; then
        sed -i '' 's/\*Schedule ready but not added to calendar\..*\*/\*Schedule added to Apple Calendar (Home).\*/' "$OUTPUT_FILE"
    fi
else
    echo "Skipped — schedule not added to calendar."
fi
