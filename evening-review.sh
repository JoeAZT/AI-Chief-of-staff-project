#!/bin/bash
# AI Chief of Staff — Evening Review
# Checks what got done today vs what was planned, updates to-do list, preps tomorrow

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/config.sh"
OBSIDIAN_ROOT="$BRIEFING_DIR"
TODO_FILE="$OBSIDIAN_ROOT/To-do.md"
PROJECTS_DIR="$OBSIDIAN_ROOT/Project ideas"
BRIEFINGS_DIR="$OBSIDIAN_ROOT/Daily briefings"
WINS_FILE="$OBSIDIAN_ROOT/Wins.md"
TODAY=$(date "+%Y-%m-%d")
DAY_OF_WEEK=$(date "+%A")

# Read today's briefing
TODAY_BRIEFING=""
if [ -f "$BRIEFINGS_DIR/$TODAY.md" ]; then
    TODAY_BRIEFING=$(cat "$BRIEFINGS_DIR/$TODAY.md")
fi

# Read current to-do list
TODO_CONTENT=""
if [ -f "$TODO_FILE" ]; then
    TODO_CONTENT=$(cat "$TODO_FILE")
fi

# Read today's calendar events
CALENDAR_EVENTS=$(osascript "$SCRIPT_DIR/get-calendar.scpt" 2>/dev/null || echo "Could not read calendar.")

# Collect project statuses
PROJECT_STATUSES=""
for file in "$PROJECTS_DIR"/*.md; do
    if [ -f "$file" ]; then
        filename=$(basename "$file" .md)
        status=$(sed -n '/^## Status/,/^---/p' "$file" | grep -E '^\- \*\*' || echo "  No status section")
        PROJECT_STATUSES="$PROJECT_STATUSES
$filename:
$status
"
    fi
done

# Read fitness log
FITNESS_LOG=""
FITNESS_LOG_FILE="$OBSIDIAN_ROOT/Fitness log.md"
if [ -f "$FITNESS_LOG_FILE" ]; then
    FITNESS_LOG=$(tail -10 "$FITNESS_LOG_FILE")
fi

PROMPT="It's $DAY_OF_WEEK evening, $TODAY. Run my evening review.

Here's what was planned this morning:
$TODAY_BRIEFING

Here's the current state of my to-do list:
$TODO_CONTENT

Here are today's calendar events (what actually happened):
$CALENDAR_EVENTS

Here are my project statuses:
$PROJECT_STATUSES

Recent fitness log (check if today's workout was logged — this is ground truth, not the to-do list):
$FITNESS_LOG

Give me:

1. **What got done** — check today's briefing for tasks formatted as checkboxes. Count how many are ticked '- [x]' vs unchecked '- [ ]'. Show the score (e.g. 3/5 completed). Acknowledge wins, even small ones.

2. **What didn't get done** — list the specific unchecked tasks from today's briefing. No judgement, just facts. If there's a pattern across recent days (e.g. always skipping fitness, always avoiding a specific task), mention it.

3. **Tomorrow's preview** — based on what's still open and what logically comes next, give a 2-3 bullet preview of what tomorrow should focus on. Don't generate a full schedule — that's the morning briefing's job.

4. **Fitness check** — did the workout happen? If not, suggest doing a quick 10-min bodyweight session now before bed (push-ups, squats, plank). If it did happen, acknowledge it.

5. **Ship check** — did today produce anything that exists in the world? Code committed, content published, a feature someone could use? If yes, acknowledge it. If no, be direct: 'Today was a zero-output day. That's fine occasionally, but if this is a pattern, you're building a planning habit, not a shipping habit.' Check if the last 3 days have been zero-output — if so, escalate harder.

6. **Public output check** — did anything go out under the user's name today? A blog post, a tweet about what they're building, a shipped product update? If not, and it's been more than 7 days since the last public output, say so.

7. **One reflection** — ask me one question to think about before bed. Something that helps me improve how I work, not just what I work on. Rotate between these themes:
   - Shipping: 'What stopped you from shipping something today?'
   - Leverage: 'Did you spend time on anything a machine or someone cheaper could have done?'
   - Authenticity: 'Is what you're building something only you can build?'
   - Compounding: 'What did you do today that will still matter in a year?'

Keep it short. This should take 1 minute to read.

Do NOT include a schedule block — this is a review, not a plan.

IMPORTANT: At the very end of your response, include two machine-readable blocks:

1. A wins block listing any concrete achievements from today (shipped code, completed features, published content, workouts done, milestones hit). If nothing was achieved today, leave it empty. Format:
\`\`\`wins
- Description of win 1
- Description of win 2
\`\`\`

2. A gamification block with yes/no for each tracking category. Be honest — only mark 'yes' if the evidence supports it:
\`\`\`gamification
ship: yes/no
workout: yes/no
learning: yes/no
public_output: yes/no
\`\`\`

For ship: did code get committed, a feature get built, or something tangible get produced?
For workout: did the fitness log show a workout today?
For learning: did the user consume learning content (podcast, article, video, course)?
For public_output: did something go out publicly under the user's name (blog post, tweet, shipped product update)?"

# Output file
OUTPUT_FILE="$BRIEFINGS_DIR/$TODAY-evening.md"

# Run Claude (with retry and failure handling)
cd "$SCRIPT_DIR"
MAX_RETRIES=2
RETRY=0
FULL_OUTPUT=""
while [ $RETRY -le $MAX_RETRIES ]; do
    FULL_OUTPUT=$(echo "$PROMPT" | claude --print 2>/dev/null) && break
    RETRY=$((RETRY + 1))
    if [ $RETRY -le $MAX_RETRIES ]; then
        echo "Claude call failed. Retrying ($RETRY/$MAX_RETRIES)..."
        sleep 5
    fi
done

if [ -z "$FULL_OUTPUT" ]; then
    echo "Evening review failed after $MAX_RETRIES retries." > "$OUTPUT_FILE"
    echo "Run manually: cd $SCRIPT_DIR && bash evening-review.sh" >> "$OUTPUT_FILE"
    osascript -e 'display notification "Evening review failed — run manually." with title "AI Chief of Staff" sound name "Basso"' 2>/dev/null
    exit 1
fi

# Extract wins and append to Wins.md
WINS_ENTRY=$(echo "$FULL_OUTPUT" | sed -n '/^```wins$/,/^```$/p' | grep -v '```')
if [ -n "$WINS_ENTRY" ]; then
    echo "" >> "$WINS_FILE"
    echo "### $TODAY ($DAY_OF_WEEK)" >> "$WINS_FILE"
    echo "$WINS_ENTRY" >> "$WINS_FILE"
fi

# Extract gamification data and update streaks
GAMIFICATION=$(echo "$FULL_OUTPUT" | sed -n '/^```gamification$/,/^```$/p' | grep -v '```')
STREAK_FLAGS=""
if echo "$GAMIFICATION" | grep -q "ship: yes"; then
    STREAK_FLAGS="$STREAK_FLAGS --ship"
fi
if echo "$GAMIFICATION" | grep -q "workout: yes"; then
    STREAK_FLAGS="$STREAK_FLAGS --workout"
fi
if echo "$GAMIFICATION" | grep -q "learning: yes"; then
    STREAK_FLAGS="$STREAK_FLAGS --learning"
fi
if echo "$GAMIFICATION" | grep -q "public_output: yes"; then
    STREAK_FLAGS="$STREAK_FLAGS --public"
fi

if [ -n "$STREAK_FLAGS" ]; then
    bash "$SCRIPT_DIR/update-streaks.sh" $STREAK_FLAGS
fi

# Save briefing to Obsidian (without the machine-readable blocks)
echo "$FULL_OUTPUT" | sed '/^```wins$/,/^```$/d' | sed '/^```gamification$/,/^```$/d' > "$OUTPUT_FILE"

# Send notification
osascript -e 'display notification "Your evening review is ready in Obsidian." with title "AI Chief of Staff" sound name "Purr"'
