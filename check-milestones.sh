#!/bin/bash
# AI Chief of Staff — Check and Announce Milestones
# Reads streaks, fitness log, and briefing count to check for newly achieved milestones.
# Outputs any newly achieved milestones and updates milestones.json.

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/config.sh"
MILESTONES_FILE="$SCRIPT_DIR/milestones.json"
STREAKS_FILE="$SCRIPT_DIR/streaks.json"
FITNESS_LOG="$BRIEFING_DIR/Fitness log.md"
BRIEFINGS_DIR="$BRIEFING_DIR/Daily briefings"
TODAY=$(date "+%Y-%m-%d")

python3 -c "
import json, os, glob
from datetime import datetime, timedelta

with open('$MILESTONES_FILE', 'r') as f:
    milestones = json.load(f)

with open('$STREAKS_FILE', 'r') as f:
    streaks = json.load(f)

today = '$TODAY'
newly_achieved = []

# Count total workouts from fitness log
workout_count = 0
fitness_log = '$FITNESS_LOG'
if os.path.exists(fitness_log):
    with open(fitness_log, 'r') as f:
        for line in f:
            if line.startswith('|') and '---' not in line and 'Date' not in line:
                workout_count += 1

# Count total briefings
briefings_dir = '$BRIEFINGS_DIR'
briefing_count = 0
if os.path.isdir(briefings_dir):
    briefing_count = len(glob.glob(os.path.join(briefings_dir, '????-??-??.md')))

# Check fitness milestones
for m in milestones['fitness']:
    if m['achieved']:
        continue
    if m['id'] == 'first_workout' and workout_count >= 1:
        m['achieved'] = True
        m['date'] = today
        newly_achieved.append(m['name'])
    elif m['id'] == '10_workouts' and workout_count >= 10:
        m['achieved'] = True
        m['date'] = today
        newly_achieved.append(m['name'])
    elif m['id'] == '50_workouts' and workout_count >= 50:
        m['achieved'] = True
        m['date'] = today
        newly_achieved.append(m['name'])
    elif m['id'] == '100_workouts' and workout_count >= 100:
        m['achieved'] = True
        m['date'] = today
        newly_achieved.append(m['name'])
    elif m['id'] == '4_week_consistency':
        # Check if workout streak >= 28 days
        if streaks['workout']['current'] >= 28:
            m['achieved'] = True
            m['date'] = today
            newly_achieved.append(m['name'])

# Check system milestones
for m in milestones['system']:
    if m['achieved']:
        continue
    if m['id'] == 'first_week' and briefing_count >= 7:
        m['achieved'] = True
        m['date'] = today
        newly_achieved.append(m['name'])
    elif m['id'] == '30_day_streak':
        # Any category with 30+ day streak
        for cat in ['ship', 'workout', 'learning', 'public_output']:
            if streaks[cat]['current'] >= 30:
                m['achieved'] = True
                m['date'] = today
                newly_achieved.append(m['name'])
                break
    elif m['id'] == '100_briefings' and briefing_count >= 100:
        m['achieved'] = True
        m['date'] = today
        newly_achieved.append(m['name'])

# Builder milestones are manual — they get set via the wins log / evening review
# We just check if any were newly set today
for m in milestones['builder']:
    if m['achieved'] and m['date'] == today:
        newly_achieved.append(m['name'])

with open('$MILESTONES_FILE', 'w') as f:
    json.dump(milestones, f, indent=2)

# Output newly achieved milestones
for name in newly_achieved:
    print(name)
"
