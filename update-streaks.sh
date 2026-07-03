#!/bin/bash
# AI Chief of Staff — Update Streak Data
# Usage: bash update-streaks.sh --ship --workout --learning --public
# Pass flags for each category that was completed today.
# Handles grace day logic: 1 missed day per week doesn't break the streak.

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
STREAKS_FILE="$SCRIPT_DIR/streaks.json"
TODAY=$(date "+%Y-%m-%d")
YESTERDAY=$(date -v-1d "+%Y-%m-%d")

# Monday of this week (for grace day weekly reset)
WEEK_START=$(date -v-"$(($(date +%u) - 1))"d "+%Y-%m-%d")

# Parse flags
SHIP=false
WORKOUT=false
LEARNING=false
PUBLIC=false

for arg in "$@"; do
    case $arg in
        --ship) SHIP=true ;;
        --workout) WORKOUT=true ;;
        --learning) LEARNING=true ;;
        --public) PUBLIC=true ;;
    esac
done

# Read current streaks (requires python3 for JSON handling)
update_category() {
    local category="$1"
    local completed="$2"

    python3 -c "
import json, sys
from datetime import datetime, timedelta

with open('$STREAKS_FILE', 'r') as f:
    data = json.load(f)

cat = data['$category']
today = '$TODAY'
yesterday = '$YESTERDAY'
week_start = '$WEEK_START'
completed = $completed

# Reset grace flag if we're in a new week
if cat['grace_week_start'] != week_start:
    cat['grace_used_this_week'] = False
    cat['grace_week_start'] = week_start

if completed:
    if cat['last_date'] == today:
        # Already logged today, skip
        pass
    elif cat['last_date'] == yesterday or cat['current'] == 0:
        # Consecutive day or fresh start
        cat['current'] += 1
        cat['last_date'] = today
    else:
        # Gap > 1 day — check if we can use grace
        if cat['last_date']:
            last = datetime.strptime(cat['last_date'], '%Y-%m-%d')
            gap = (datetime.strptime(today, '%Y-%m-%d') - last).days
            if gap == 2 and not cat['grace_used_this_week']:
                # 1 missed day, grace available
                cat['grace_used_this_week'] = True
                cat['current'] += 1
                cat['last_date'] = today
            else:
                # Streak broken
                cat['current'] = 1
                cat['last_date'] = today
        else:
            cat['current'] = 1
            cat['last_date'] = today
else:
    # Not completed today — streak may break tomorrow
    # Don't reset yet; the grace day check happens when the next completion comes in
    pass

# Update personal best
if cat['current'] > cat['best']:
    cat['best'] = cat['current']

data['$category'] = cat

with open('$STREAKS_FILE', 'w') as f:
    json.dump(data, f, indent=2)
"
}

# Convert bash booleans to Python booleans
[[ "$SHIP" == "true" ]] && S="True" || S="False"
[[ "$WORKOUT" == "true" ]] && W="True" || W="False"
[[ "$LEARNING" == "true" ]] && L="True" || L="False"
[[ "$PUBLIC" == "true" ]] && P="True" || P="False"

update_category "ship" "$S"
update_category "workout" "$W"
update_category "learning" "$L"
update_category "public_output" "$P"

# Update momentum score (0-100): grows with active categories, decays slowly on zero days
python3 -c "
import json

with open('$STREAKS_FILE', 'r') as f:
    data = json.load(f)

m = data.setdefault('momentum', {'score': 0, 'last_date': None})
active = [$S, $W, $L, $P].count(True)

if m['last_date'] != '$TODAY':
    # ponytail: +3 per active category, -2 on zero days — tune if it feels off after a few weeks
    if active > 0:
        m['score'] = min(100, m['score'] + 3 * active)
    else:
        m['score'] = max(0, m['score'] - 2)
    m['last_date'] = '$TODAY'

with open('$STREAKS_FILE', 'w') as f:
    json.dump(data, f, indent=2)
print(f\"Momentum: {m['score']}/100\")
"

# Print current streaks
python3 -c "
import json
with open('$STREAKS_FILE', 'r') as f:
    data = json.load(f)
for cat in ['ship', 'workout', 'learning', 'public_output']:
    d = data[cat]
    label = cat.replace('_', ' ').title()
    print(f'{label}: {d[\"current\"]} days (best: {d[\"best\"]})')
"
