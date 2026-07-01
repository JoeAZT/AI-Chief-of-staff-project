#!/bin/bash
# AI Chief of Staff — Weekly Performance Review
# Analyses the week's briefings, to-do progress, and patterns. Runs on Sundays at 10am.

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/config.sh"
OBSIDIAN_ROOT="$BRIEFING_DIR"
TODO_FILE="$OBSIDIAN_ROOT/To-do.md"
PROJECTS_DIR="$OBSIDIAN_ROOT/Project ideas"
BRIEFINGS_DIR="$OBSIDIAN_ROOT/Daily briefings"
TODAY=$(date "+%Y-%m-%d")

# Collect this week's briefings (last 7 days)
WEEK_BRIEFINGS=""
for i in $(seq 0 6); do
    DAY=$(date -v-${i}d "+%Y-%m-%d")
    if [ -f "$BRIEFINGS_DIR/$DAY.md" ]; then
        WEEK_BRIEFINGS="$WEEK_BRIEFINGS
=== BRIEFING: $DAY ===
$(cat "$BRIEFINGS_DIR/$DAY.md")
"
    fi
    if [ -f "$BRIEFINGS_DIR/$DAY-evening.md" ]; then
        WEEK_BRIEFINGS="$WEEK_BRIEFINGS
=== EVENING REVIEW: $DAY ===
$(cat "$BRIEFINGS_DIR/$DAY-evening.md")
"
    fi
done

# Read current to-do list
TODO_CONTENT=""
if [ -f "$TODO_FILE" ]; then
    TODO_CONTENT=$(cat "$TODO_FILE")
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

PROMPT="It's Sunday, $TODAY. Run my weekly performance review.

Here are this week's morning briefings and evening reviews:
$WEEK_BRIEFINGS

Here's the current to-do list:
$TODO_CONTENT

Here are the project statuses:
$PROJECT_STATUSES

Give me a weekly performance review covering:

1. **Week summary** — what actually got done this week? List concrete achievements, not just 'worked on X'. Be specific.

2. **Completion rate** — of the tasks that were planned across the week's briefings, roughly what percentage got done? Be honest. Don't sugarcoat.

3. **Patterns** — what patterns do you see?
   - Which time slots were most productive?
   - Were any tasks consistently skipped or rescheduled?
   - Was fitness consistent? How many workouts happened vs the 4/week target?
   - Was learning/content consumption happening or getting skipped?

4. **Wins** — what went well? Acknowledge real progress, even if small.

5. **Problems** — what didn't work? Be direct. If the schedule was too packed, say so. If tasks were too vague, say so. If avoidance is happening, name it.

6. **Next week's focus** — based on project status and this week's momentum:
   - What should the primary focus be next week?
   - Any adjustments to the schedule or approach?
   - One specific thing to do differently next week.

7. **Goal progress** — how much closer are we to the user's goals (see CLAUDE.md)? For each goal:
   - What's the realistic next milestone?
   - Is progress real or just motion?
   - Are workouts and learning happening consistently?

8. **Naval scorecard** — grade the week on Naval's key principles. Be brutally honest.
   - **Shipping:** How many days this week produced tangible output (code committed, content published, features deployed)? Score: X/7 ship days.
   - **Public output:** What went out under the user's name this week? Blog posts, tweets, shipped products, open source. List them. If the answer is 'nothing', say so plainly.
   - **Ownership vs busywork:** What percentage of this week's time went toward building assets the user owns vs admin, setup, or consumption? Estimate roughly.
   - **Specific knowledge:** Is the current project leveraging the user's unique combination of skills and interests? Or is it something generic anyone could build? If generic, challenge it.
   - **Planning-to-doing ratio:** How much time was spent planning, researching, and preparing vs actually building? If the ratio is worse than 1:3 (planning:doing), flag it.
   - **Compounding check:** What was done this week that will still matter in 6 months? If the answer is 'nothing', that's a problem.

Keep it honest and actionable. This is a coaching conversation, not a report."

# Output
OUTPUT_FILE="$BRIEFINGS_DIR/$TODAY-weekly-review.md"

cd "$SCRIPT_DIR"
echo "$PROMPT" | claude --print > "$OUTPUT_FILE"

# Notification
osascript -e 'display notification "Your weekly review is ready in Obsidian." with title "AI Chief of Staff — Weekly Review" sound name "Glass"'
