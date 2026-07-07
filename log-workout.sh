#!/bin/bash
# AI Chief of Staff — Log a completed workout
# Usage: bash log-workout.sh [optional workout type, e.g. "D — Pull + Core"]

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
[ -f "$SCRIPT_DIR/config.sh" ] || { echo "No config.sh found — run: bash setup.sh first"; exit 1; }
source "$SCRIPT_DIR/config.sh"
OBSIDIAN_ROOT="$BRIEFING_DIR"
TODO_FILE="$OBSIDIAN_ROOT/To-do.md"
TODAY=$(date "+%Y-%m-%d")
DAY_OF_WEEK=$(date "+%A")
WORKOUT_TYPE="${1:-unspecified}"

# Log to a persistent workout log
LOG_FILE="$OBSIDIAN_ROOT/Fitness log.md"

if [ ! -f "$LOG_FILE" ]; then
    echo "# Fitness Log" > "$LOG_FILE"
    echo "" >> "$LOG_FILE"
    echo "| Date | Day | Workout |" >> "$LOG_FILE"
    echo "|------|-----|---------|" >> "$LOG_FILE"
fi

# Check if already logged today
if grep -q "$TODAY" "$LOG_FILE" 2>/dev/null; then
    echo "Already logged a workout for today ($TODAY)."
    exit 0
fi

# Append to log
echo "| $TODAY | $DAY_OF_WEEK | $WORKOUT_TYPE |" >> "$LOG_FILE"

# Count workouts this week (Monday to Sunday)
# Find Monday of this week
MONDAY=$(date -v-"$(($(date +%u) - 1))"d "+%Y-%m-%d")
WEEK_COUNT=0
while IFS='|' read -r _ date _; do
    date=$(echo "$date" | xargs)
    if [[ "$date" > "$MONDAY" || "$date" == "$MONDAY" ]] && [[ "$date" < "$(date -v+1d "+%Y-%m-%d")" ]]; then
        WEEK_COUNT=$((WEEK_COUNT + 1))
    fi
done < <(grep "^|" "$LOG_FILE" | grep -v "Date" | grep -v "---")

# Update the tracker in To-do.md, preserving the user's own weekly target
if [ -f "$TODO_FILE" ]; then
    sed -i '' -E "s|(Track workouts completed this week: )[0-9]+/([0-9]+)|\1${WEEK_COUNT}/\2|" "$TODO_FILE"
fi

echo "Logged: $WORKOUT_TYPE on $DAY_OF_WEEK $TODAY ($WEEK_COUNT this week)"
