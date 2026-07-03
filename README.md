# AI Chief of Staff

An AI system that plans your day, holds you accountable, and calls you out when you're avoiding things.

Not a to-do app. Not a calendar. A coach that wakes up before you, looks at your goals, tells you exactly what to do today — then checks in at night and asks what happened.

Built on [Claude Code](https://docs.anthropic.com/en/docs/claude-code). Runs in your terminal. Writes to markdown files. Syncs to your phone via Apple Calendar.

**macOS only** (calendar integration and scheduling use AppleScript and LaunchAgents). Linux/Windows support isn't planned for v1.

## What it does

**Morning briefing** (daily, automatic or on demand)
- Reads your to-do list, calendar, project statuses, and yesterday's review
- Generates 3–5 specific, actionable tasks for today
- Proposes a schedule fitted to your available hours — and once it has 2+ weeks of data, adjusts it to when you *actually* complete things, not when you think you do
- Suggests a workout and learning content with direct links
- Flags stuck tasks: 2 days → nudge, 3 days → escalation, 5 days → intervention
- Creates Apple Calendar events with context notes (syncs to your phone)

**Evening review** (daily, automatic or on demand)
- Quick interactive check-in: did the workout happen, did you ship, what's blocking you
- Compares what was planned vs what got done
- Judges ship quality — a typo fix doesn't keep your ship streak alive
- Drafts a tweet + LinkedIn post from anything post-worthy you did today, so publishing takes 2 minutes
- Asks one reflection question to think about before bed

**Weekly review** (Sundays, automatic or on demand)
- Completion rate, productivity patterns, goal progress — honest, not sugarcoated
- **Weekly Wrapped** — a shareable, screenshot-friendly summary card of your week
- Sets one challenge for next week based on your weakest area

**Gamification that respects you**
- 🔥 Streaks for shipping, workouts, learning, and public output — with 1 grace day a week, because a streak that dies forever the first time you miss makes people quit
- ⚡ Momentum score (0–100) that builds with active days and decays slowly — a bad day dents it, it doesn't zero it
- 🎯 Milestones announced as you hit them: first commit → first feature → first public post → first user → first paying customer
- 🏆 A wins log that grows into evidence the system works

## Example briefing

```
🔥 Ship: 6 days | 💪 Workout: 3 days | 📚 Learning: 4 days | 📣 Public Output: 0 days | ⚡ Momentum: 47/100
🎯 This week's challenge: publish one build-log post by Friday

**Calendar:** Work 9–5. Dentist 17:30.

**Today's tasks**
- [ ] Write the AppleScript that creates a calendar event from title + time
- [ ] Commit and push the event-creation script
- [ ] Draft 3 bullet points for the build-log post (feeds Friday's challenge)
- [ ] 25-min kettlebell session — Routine C

**Schedule**
18:15–19:45  Deep work: calendar event script (your 85%-completion slot)
20:00–20:30  Kettlebell Routine C + podcast
21:30–22:00  Build-log bullet points

**Stuck:** "Set up analytics" — day 3. Break it down, schedule it, or drop it.
Your call, but stop carrying it.

**Naval check:** Yesterday shipped. Today ships the script. But nothing has
gone out under your name in 9 days — the draft in Content drafts.md is ready.
Post it.
```

## Costs — read this first

Every briefing and review is a Claude API call — roughly 3 calls a day. You need Claude Code installed and authenticated (Pro/Max subscription or API key). Typical usage runs well within a Pro subscription; on a pay-as-you-go API key, expect a small daily cost depending on model. There are no other services, accounts, or fees.

## Privacy

Your goals, schedule, fitness log, and daily performance are sent to Anthropic's API to generate each briefing — that's how the system works, so be comfortable with it before you start. Everything else stays on your Mac as plain markdown and JSON you can read, edit, and delete. Nothing is sent anywhere else.

## Setup

Prerequisites: macOS, [Claude Code](https://docs.anthropic.com/en/docs/claude-code) installed and authenticated, Apple Calendar, and a folder for output (an Obsidian vault works great).

```bash
git clone https://github.com/JoeAZT/AI-Chief-of-staff-project.git
cd AI-Chief-of-staff-project
bash setup.sh              # ~5 min of questions → your personalised system
bash install-automation.sh # schedules the daily runs (optional but recommended)
```

Setup asks about your schedule, goals, energy patterns, fitness setup, and how hard you want to be coached, then generates a profile (`CLAUDE.md`), workout library, config, and starter to-do list. The briefings are specific to your life — not generic productivity advice.

## Usage

```bash
bash morning-briefing.sh    # generate today's plan
bash approve-schedule.sh    # review + add events to Apple Calendar
bash log-workout.sh "C — Full Body Power"
bash evening-review.sh      # check-in + review of the day
bash weekly-review.sh       # weekly review + Wrapped
```

**The one habit that matters:** tick tasks off in the briefing note (`- [ ]` → `- [x]`) as you complete them. That's how the evening review knows what happened, how streaks stay honest, and how the scheduler learns your real patterns. The interactive evening check-in catches what you didn't tick — but ticking is faster.

## How the accountability works

The system doesn't let tasks quietly rot on your list:

| Days stuck | What happens |
|------------|-------------|
| 2 days | Flagged: "Is something blocking you?" |
| 3 days | Escalated: suggests breaking it down, rescheduling, delegating, or dropping it |
| 5 days | Dedicated section: "We need to talk about this." Diagnoses avoidance, skill gaps, or wrong priorities |

It also watches itself: if the evening review stops running for 3+ days, the morning briefing warns that the feedback loop is broken and it's planning blind.

## What's in the box

| File | Purpose |
|------|---------|
| `setup.sh` | Interactive onboarding — generates your personalised system |
| `install-automation.sh` | Generates + loads LaunchAgents for automatic daily runs |
| `onboarding-prompt.md` | System prompt that guides the onboarding conversation |
| `CLAUDE.md` | Your personalised profile, goals, schedule, and rules (generated) |
| `config.sh` | File paths and calendar name (generated) |
| `workout-library.md` | Workout routines matched to your equipment (generated) |
| `morning-briefing.sh` | Collects context and generates the daily briefing |
| `evening-review.sh` | Check-in, review, wins, streaks, content drafts, task log |
| `weekly-review.sh` | Weekly review, Wrapped card, next week's challenge |
| `update-streaks.sh` | Streak + momentum tracking with grace-day logic |
| `check-milestones.sh` | Detects and queues newly achieved milestones |
| `create-events.sh` | Creates Apple Calendar events from the proposed schedule |
| `approve-schedule.sh` | Review and approve the schedule before it hits your calendar |
| `log-workout.sh` | Log a completed workout to the fitness log |
| `get-calendar.scpt` | AppleScript to read today's calendar events |
| `streaks.template.json`, `milestones.template.json` | Fresh gamification state for new installs |

Note: `create-events.sh` replaces the day's `[CoS]`-tagged events on each run — edit the schedule file rather than the calendar events themselves.

## Customisation

Everything is markdown and shell scripts — no hidden config.

- **Change your goals or schedule:** edit `CLAUDE.md`
- **Change your calendar or file paths:** edit `config.sh`
- **Change your workouts:** edit `workout-library.md`
- **Change automation times:** re-run `bash install-automation.sh`
- **Start over:** delete `CLAUDE.md`, `config.sh`, and `workout-library.md`, then run `bash setup.sh`

## License

MIT

---

*Built by [Joe Taylor](https://github.com/JoeAZT). Inspired by [Jessie Yorke's AI Chief of Staff guide](https://www.jessieyorke.com/guides/ai-chief-of-staff.html).*
