#!/bin/bash
# AI Chief of Staff — Full Morning Briefing
# Collects context and runs Claude Code for the briefing

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/config.sh"
OBSIDIAN_ROOT="$BRIEFING_DIR"
TODO_FILE="$OBSIDIAN_ROOT/To-do.md"
PROJECTS_DIR="$OBSIDIAN_ROOT/Project ideas"
BRIEFINGS_DIR="$OBSIDIAN_ROOT/Daily briefings"
TODAY=$(date "+%Y-%m-%d")
DAY_OF_WEEK=$(date "+%A")

# Collect to-do list
TODO_CONTENT=""
if [ -f "$TODO_FILE" ]; then
    TODO_CONTENT=$(cat "$TODO_FILE")
fi

# Collect calendar events via AppleScript
CALENDAR_EVENTS=$(osascript "$SCRIPT_DIR/get-calendar.scpt" 2>/dev/null || echo "Could not read calendar. Check permissions.")

# Collect workout library
WORKOUT_LIBRARY=""
if [ -f "$SCRIPT_DIR/workout-library.md" ]; then
    WORKOUT_LIBRARY=$(cat "$SCRIPT_DIR/workout-library.md")
fi

# Collect yesterday's evening review for context
YESTERDAY=$(date -v-1d "+%Y-%m-%d")
YESTERDAY_REVIEW=""
if [ -f "$BRIEFINGS_DIR/$YESTERDAY-evening.md" ]; then
    YESTERDAY_REVIEW=$(cat "$BRIEFINGS_DIR/$YESTERDAY-evening.md")
fi

# Detect how many consecutive days the evening review has been missing
EVENING_REVIEW_GAP=0
for i in $(seq 1 7); do
    CHECK_DATE=$(date -v-${i}d "+%Y-%m-%d")
    if [ -f "$BRIEFINGS_DIR/$CHECK_DATE-evening.md" ]; then
        break
    fi
    # Only count days that had a morning briefing (so we don't count days the system wasn't used)
    if [ -f "$BRIEFINGS_DIR/$CHECK_DATE.md" ]; then
        EVENING_REVIEW_GAP=$((EVENING_REVIEW_GAP + 1))
    fi
done

LOOP_HEALTH=""
if [ "$EVENING_REVIEW_GAP" -ge 3 ]; then
    LOOP_HEALTH="⚠️ LOOP BROKEN: No evening review has run for $EVENING_REVIEW_GAP days. The daily feedback loop is open — this briefing is planning blind without knowing what actually got done. Run 'bash $SCRIPT_DIR/evening-review.sh' tonight."
elif [ "$EVENING_REVIEW_GAP" -ge 1 ]; then
    LOOP_HEALTH="Note: No evening review ran yesterday. Tomorrow's briefing will be better if you run one tonight."
fi

# Collect fitness log for context
FITNESS_LOG=""
FITNESS_LOG_FILE="$OBSIDIAN_ROOT/Fitness log.md"
if [ -f "$FITNESS_LOG_FILE" ]; then
    FITNESS_LOG=$(tail -10 "$FITNESS_LOG_FILE")
fi

# Collect streak data
STREAK_DISPLAY=""
if [ -f "$SCRIPT_DIR/streaks.json" ]; then
    STREAK_DISPLAY=$(python3 -c "
import json
from datetime import datetime
with open('$SCRIPT_DIR/streaks.json', 'r') as f:
    data = json.load(f)
today = datetime.strptime('$TODAY', '%Y-%m-%d')
lines = []
for cat, label in [('ship', 'Ship'), ('workout', 'Workout'), ('learning', 'Learning'), ('public_output', 'Public Output')]:
    d = data[cat]
    cur = d['current']
    best = d['best']
    grace_used = d.get('grace_used_this_week', False)
    gap = (today - datetime.strptime(d['last_date'], '%Y-%m-%d')).days if d['last_date'] else None
    # streaks.json only updates on completion — a stale last_date means the streak already broke
    if cur > 0 and gap is not None and (gap > 2 or (gap == 2 and grace_used)):
        lines.append(f'{label}: 0 days — streak broke {gap} days ago (was {cur}, best: {best})')
        continue
    grace = '(grace day available)' if not grace_used else '(grace day used this week)'
    lines.append(f'{label}: {cur} days {grace} | Best: {best} days')
lines.append(f\"Momentum: {data.get('momentum', {}).get('score', 0)}/100\")
print('\n'.join(lines))
" 2>/dev/null || echo "Could not read streaks.")
fi

# Collect task completion history for pattern analysis
TASK_LOG=""
DAYS_TRACKED=0
if [ -f "$SCRIPT_DIR/task-log.csv" ]; then
    TASK_LOG=$(cat "$SCRIPT_DIR/task-log.csv")
    DAYS_TRACKED=$(cut -d'|' -f1 "$SCRIPT_DIR/task-log.csv" | sort -u | wc -l | tr -d ' ')
fi

# Collect this week's challenge (set by the weekly review)
CURRENT_CHALLENGE=""
if [ -f "$SCRIPT_DIR/current-challenge.md" ]; then
    CURRENT_CHALLENGE=$(cat "$SCRIPT_DIR/current-challenge.md")
fi

# Check for new milestones — read from the pending queue so announcements
# survive a failed briefing run
NEW_MILESTONES=""
if [ -f "$SCRIPT_DIR/check-milestones.sh" ]; then
    bash "$SCRIPT_DIR/check-milestones.sh" > /dev/null 2>&1 || true
fi
if [ -f "$SCRIPT_DIR/pending-milestones.txt" ]; then
    NEW_MILESTONES=$(sort -u "$SCRIPT_DIR/pending-milestones.txt")
fi

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

# Build the prompt
PROMPT="It's $DAY_OF_WEEK, $TODAY. Run my morning briefing.

Here's my to-do list:
$TODO_CONTENT

Here are today's calendar events:
$CALENDAR_EVENTS

Here are my project statuses:
$PROJECT_STATUSES

Here is my workout library (pick from these, matching today's day type):
$WORKOUT_LIBRARY

Yesterday's evening review (use this for context on what happened and what was suggested for today):
$YESTERDAY_REVIEW

Loop health status:
$LOOP_HEALTH

Recent fitness log (use this to know what workouts actually happened, not just what was planned):
$FITNESS_LOG

Current streaks:
$STREAK_DISPLAY

Newly achieved milestones (announce these if any):
$NEW_MILESTONES

Task completion history ($DAYS_TRACKED days tracked, format: date|day|time_slot|type|title|completed):
$TASK_LOG

This week's challenge (set by the weekly review):
$CURRENT_CHALLENGE

Based on all of this, give me:

1. **Streaks** — display the current streaks prominently at the top using this format:
   🔥 Ship: X days | 💪 Workout: X days | 📚 Learning: X days | 📣 Public Output: X days | ⚡ Momentum: X/100
   If any streak is at a personal best, add '(PB!)' after the number.
   If a milestone was just achieved, announce it: '🎯 Milestone unlocked: [name]!'
   If there's a challenge set above, show it here too: '🎯 This week's challenge: [challenge]' — and note progress if any of this week's activity counts toward it.

2. **Calendar** — quick summary of what's on today

3. **Today's specific tasks** — pick 3-5 concrete, actionable steps I can complete TODAY from the current project and self-improvement sections. Format each task as a markdown checkbox (e.g. '- [ ] Research 3 AppleScript examples for creating calendar events'). These should be granular — not project-level goals but steps completable in a single session. Focus on the current project only — don't spread across multiple projects. Include at least one self-improvement task (fitness, learning, or career).
   If fewer than 14 days are tracked in the task history ($DAYS_TRACKED so far), end the task list with this exact line: '☑️ *Tick these off in this note as you go — it's how I know what actually happened.*'

4. **Proposed schedule** — slot today's tasks into the user's available hours as defined in CLAUDE.md. Use the scheduling principles and available hours table from the profile. Leave breathing room — not every slot needs filling.
   Smart scheduling from the task completion history above: if 14+ days are tracked, use the data — schedule task types at the times they actually get completed, avoid slots where they're consistently skipped, and mention one insight when you adjust (e.g. 'You complete 85% of evening tasks but only 40% of morning ones — deep work moved to 19:00'). If fewer than 14 days are tracked, add one line: '📊 Learning your patterns: day $DAYS_TRACKED/14' and draw no conclusions from the data yet.

5. **Fitness** — one specific workout for today from the workout library provided. Vary it day to day — don't repeat the same routine. Include sets, reps, and rest times. Suggest a podcast or content to listen to during it if appropriate.

6. **Learning** — one specific podcast episode, video, or article to consume today. Rules:
   - Match it to what I'm actively working on this week, not generic inspiration.
   - Prioritise practitioners (founders, builders, engineers) over pundits. Case studies and build logs over listicles.
   - Match the length to the time slot — if it's for during a workout, keep it under 30 mins. If it's wind-down reading, keep it under 15 mins.
   - Check recent briefings to avoid repeating the same content within a week.
   - MUST include a direct clickable URL (YouTube, Spotify, or article). If you can't link it, don't recommend it.
   - Prefer trusted sources from the CLAUDE.md learning content section, but don't limit to them.

7. **Stuck / overdue** — check the *(added: YYYY-MM-DD)* dates on unchecked tasks in the to-do list. Today is $TODAY. Calculate how many days each unchecked task has been sitting there. Apply these rules:
   - **2 days:** flag it — 'This has been on your list for 2 days. Is something blocking you?'
   - **3+ days:** escalate — ask a direct question and suggest: break it down, reschedule, delegate, or drop it.
   - **5+ days:** dedicate a section called 'We need to talk about [task]' — diagnose whether it's avoidance, a skill gap, motivation, or a sign it shouldn't be on the list. Suggest a concrete next move.

8. **Naval check** — a short accountability section. Answer these honestly:
   - **Ship check:** Will today produce something that exists in the world (code shipped, content published, feature deployed)? If every task today is planning/research/setup, flag it: 'You're preparing to prepare. What can you ship today?'
   - **Ownership check:** Are today's tasks building toward something the user owns (equity, a product, an asset)? Or are they busywork?
   - **Public output:** When was the last piece of public content (blog post, tweet, shipped product)? If it's been more than 7 days, flag it: 'Nothing has gone out under your name this week. What can you publish today?'
   - **Hourly rate check:** Is any task on today's list below the user's aspirational hourly rate (see CLAUDE.md)? If so, suggest outsourcing or dropping it.

Keep it concise. I should be able to read this in 2 minutes.

IMPORTANT: At the very end of your response, after the stuck/overdue section, include a learning log entry block. This will be appended to the learning log. Format it exactly like this:

\`\`\`learning
- [ ] **\"Title\" — Creator/Source**
  - [Platform](URL) | [Platform](URL)
  - Brief description of what it covers and why it's relevant today.
  - **Relevant to:** tags for what goal/project this relates to
  - **Takeaways:**
\`\`\`

ALSO: At the very end of your response, after everything else, include a machine-readable schedule block. This will be parsed to create Apple Calendar events. Format it exactly like this, with no other text inside the block:

\`\`\`schedule
HH:MM|HH:MM|Event title|Context notes (what to do, where to look, specific details)
HH:MM|HH:MM|Event title|Context notes
\`\`\`

The context notes field is IMPORTANT — it appears in the calendar event description on the user's phone. Include enough detail that they know exactly what to do when the event pops up, without needing to check their notes. For example:
- Workout: include the routine name and key exercises
- Deep work: include which file/feature to work on and the specific goal
- Learning: include the title, URL, and why it's relevant
- Writing/reflection: include the specific question or prompt to answer and where to write it

Include ALL scheduled items from section 3 (skip 'Work — off limits' and free/decompress time). Include the workout and any learning time. Only include items that have a specific start and end time."

# Output directories
mkdir -p "$BRIEFINGS_DIR"
OUTPUT_FILE="$BRIEFINGS_DIR/$TODAY.md"
SCHEDULE_FILE="$SCRIPT_DIR/today-schedule.csv"

# Run Claude in the project directory (with retry and failure handling)
cd "$SCRIPT_DIR"
MAX_RETRIES=2
RETRY=0
FULL_OUTPUT=""
while [ $RETRY -le $MAX_RETRIES ]; do
    FULL_OUTPUT=$(echo "$PROMPT" | claude --print 2>>"$SCRIPT_DIR/logs/claude-errors.log") && break
    RETRY=$((RETRY + 1))
    if [ $RETRY -le $MAX_RETRIES ]; then
        echo "Claude call failed. Retrying ($RETRY/$MAX_RETRIES)..."
        sleep 5
    fi
done

if [ -z "$FULL_OUTPUT" ]; then
    echo "Morning briefing failed after $MAX_RETRIES retries." > "$OUTPUT_FILE"
    echo "Run manually: cd $SCRIPT_DIR && bash morning-briefing.sh" >> "$OUTPUT_FILE"
    osascript -e 'display notification "Morning briefing failed — run manually." with title "AI Chief of Staff" sound name "Basso"' 2>/dev/null
    exit 1
fi

# Briefing succeeded — pending milestones have been announced
rm -f "$SCRIPT_DIR/pending-milestones.txt"

# Extract schedule block and save to CSV
echo "$FULL_OUTPUT" | sed -n '/^```schedule$/,/^```$/p' | grep -v '```' > "$SCHEDULE_FILE"

# Extract learning block and append to learning log
LEARNING_LOG="$OBSIDIAN_ROOT/Learning log.md"
LEARNING_ENTRY=$(echo "$FULL_OUTPUT" | sed -n '/^```learning$/,/^```$/p' | grep -v '```')
if [ -n "$LEARNING_ENTRY" ]; then
    echo "" >> "$LEARNING_LOG"
    echo "## $TODAY" >> "$LEARNING_LOG"
    echo "" >> "$LEARNING_LOG"
    echo "$LEARNING_ENTRY" >> "$LEARNING_LOG"
fi

# Save briefing to Obsidian (without the raw schedule and learning blocks)
echo "$FULL_OUTPUT" | sed '/^```schedule$/,/^```$/d' | sed '/^```learning$/,/^```$/d' > "$OUTPUT_FILE"

# Phone gets a short digest, not the whole briefing — full context lives in the
# calendar events (tappable, notify at the right time) and the Obsidian note.
# Sent after the calendar step so it can say what actually happened.
send_phone_summary() {
    local SUMMARY_FILE="$SCRIPT_DIR/logs/phone-summary.txt"
    {
        echo "☀️ Briefing ready — $TODAY"
        grep -m1 '^🔥' "$OUTPUT_FILE" || true
        if [ -s "$SCHEDULE_FILE" ]; then
            echo ""
            while IFS='|' read -r S E T _; do
                # Braces required: bash 3.2 mis-parses $S followed by a multibyte char
                [ -n "$S" ] && echo "${S}–${E}  $T"
            done < "$SCHEDULE_FILE"
        fi
        echo ""
        echo "$1"
    } > "$SUMMARY_FILE"
    bash "$SCRIPT_DIR/send-to-phone.sh" "$SUMMARY_FILE" || echo "Could not send summary to phone."
}

# Add link to Daily briefings index note
BRIEFINGS_INDEX="$OBSIDIAN_ROOT/Daily briefings.md"
if [ -f "$BRIEFINGS_INDEX" ]; then
    if ! grep -q "\[\[$TODAY\]\]" "$BRIEFINGS_INDEX"; then
        echo "- [[$TODAY]] — $DAY_OF_WEEK" >> "$BRIEFINGS_INDEX"
    fi
fi

# Show schedule and ask for confirmation before creating events
if [ -s "$SCHEDULE_FILE" ]; then
    echo ""
    echo "=== Proposed schedule ==="
    while IFS='|' read -r START END TITLE; do
        [ -z "$START" ] && continue
        echo "  $START – $END  $TITLE"
    done < "$SCHEDULE_FILE"
    echo "========================="
    echo ""

    # Check if running interactively (terminal attached)
    if [ -t 0 ]; then
        read -p "Add these events to Apple Calendar? (y/n) " -n 1 -r
        echo ""
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            bash "$SCRIPT_DIR/create-events.sh" "$SCHEDULE_FILE"
            echo "" >> "$OUTPUT_FILE"
            echo "---" >> "$OUTPUT_FILE"
            echo "*Schedule added to Apple Calendar (Home).*" >> "$OUTPUT_FILE"
        else
            echo "Skipped — schedule not added to calendar."
            echo "" >> "$OUTPUT_FILE"
            echo "---" >> "$OUTPUT_FILE"
            echo "*Schedule saved but not added to calendar. Run \`bash $SCRIPT_DIR/create-events.sh $SCRIPT_DIR/today-schedule.csv\` to add manually.*" >> "$OUTPUT_FILE"
        fi
    else
        # Non-interactive (e.g. LaunchAgent) — add events automatically, same as
        # the briefing lands on the phone without asking
        if bash "$SCRIPT_DIR/create-events.sh" "$SCHEDULE_FILE"; then
            echo "" >> "$OUTPUT_FILE"
            echo "---" >> "$OUTPUT_FILE"
            echo "*Schedule added to Apple Calendar ($CALENDAR_NAME).*" >> "$OUTPUT_FILE"
            send_phone_summary "All in your calendar — tap an event for details and links. Full briefing in Obsidian."
            osascript -e 'display notification "Morning briefing ready — schedule added to calendar." with title "AI Chief of Staff" sound name "Glass"'
        else
            echo "" >> "$OUTPUT_FILE"
            echo "---" >> "$OUTPUT_FILE"
            echo "*Could not add events to calendar. Run \`bash $SCRIPT_DIR/approve-schedule.sh\` to add them manually.*" >> "$OUTPUT_FILE"
            send_phone_summary "Calendar events failed — run approve-schedule.sh. Full briefing in Obsidian."
            osascript -e 'display notification "Briefing ready, but calendar events failed. Run approve-schedule.sh." with title "AI Chief of Staff" sound name "Basso"'
        fi
        exit 0
    fi
fi

# Interactive and no-schedule runs land here (scheduled runs exit above)
send_phone_summary "Full briefing: Obsidian → Daily briefings → $TODAY."

# Send macOS notification
osascript -e 'display notification "Your morning briefing is ready in Obsidian." with title "AI Chief of Staff" sound name "Glass"'
