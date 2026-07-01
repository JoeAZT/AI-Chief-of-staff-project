#!/bin/bash
# AI Chief of Staff — Create Apple Calendar events from schedule
# Reads a schedule file (CSV-like) and creates events in Apple Calendar
#
# Schedule file format (one event per line):
# HH:MM|HH:MM|Event title|Description/context (optional)
# e.g. 17:30|18:00|Kettlebell workout|C — Full Body Power: KB swings 4×15, push-ups 3×15, goblet squats 3×12

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/config.sh"
SCHEDULE_FILE="$1"
TODAY=$(date "+%Y-%m-%d")
EVENT_TAG="[CoS]"  # Tag so we can identify and clean up our events

if [ -z "$SCHEDULE_FILE" ] || [ ! -f "$SCHEDULE_FILE" ]; then
    echo "Usage: create-events.sh <schedule-file>"
    exit 1
fi

# First, clear any existing CoS events for today to avoid duplicates
osascript -e "
tell application \"Calendar\"
    tell calendar \"$CALENDAR_NAME\"
        set todayStart to current date
        set hours of todayStart to 0
        set minutes of todayStart to 0
        set seconds of todayStart to 0
        set todayEnd to current date
        set hours of todayEnd to 23
        set minutes of todayEnd to 59
        set seconds of todayEnd to 59
        set todayEvents to (every event whose start date ≥ todayStart and start date ≤ todayEnd and summary contains \"$EVENT_TAG\")
        repeat with e in todayEvents
            delete e
        end repeat
    end tell
end tell
" 2>/dev/null

# Read schedule and create events
EVENT_COUNT=0
while IFS='|' read -r START_TIME END_TIME TITLE DESCRIPTION; do
    # Skip empty lines and comments
    [ -z "$START_TIME" ] && continue
    [[ "$START_TIME" == \#* ]] && continue

    START_HOUR=${START_TIME%%:*}
    START_MIN=${START_TIME##*:}
    END_HOUR=${END_TIME%%:*}
    END_MIN=${END_TIME##*:}

    # Remove leading zeros for AppleScript
    START_HOUR=$((10#$START_HOUR))
    START_MIN=$((10#$START_MIN))
    END_HOUR=$((10#$END_HOUR))
    END_MIN=$((10#$END_MIN))

    # Build description: use provided context or default
    if [ -z "$DESCRIPTION" ]; then
        EVENT_DESC="Created by AI Chief of Staff"
    else
        EVENT_DESC="$DESCRIPTION"
    fi

    # Escape characters that break AppleScript string interpolation
    SAFE_TITLE=$(echo "$TITLE" | sed 's/\\/\\\\/g; s/"/\\"/g')
    SAFE_DESC=$(echo "$EVENT_DESC" | sed 's/\\/\\\\/g; s/"/\\"/g')

    osascript -e "
tell application \"Calendar\"
    tell calendar \"$CALENDAR_NAME\"
        set eventStart to current date
        set hours of eventStart to $START_HOUR
        set minutes of eventStart to $START_MIN
        set seconds of eventStart to 0
        set eventEnd to current date
        set hours of eventEnd to $END_HOUR
        set minutes of eventEnd to $END_MIN
        set seconds of eventEnd to 0
        make new event at end with properties {summary:\"$EVENT_TAG $SAFE_TITLE\", start date:eventStart, end date:eventEnd, description:\"$SAFE_DESC\"}
    end tell
end tell
" 2>/dev/null

    EVENT_COUNT=$((EVENT_COUNT + 1))
    echo "  Created: $START_TIME–$END_TIME — $TITLE"
done < "$SCHEDULE_FILE"

echo ""
echo "Done. $EVENT_COUNT events added to $CALENDAR_NAME calendar."
