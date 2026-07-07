#!/bin/bash
# AI Chief of Staff — Install automation
# Generates and loads LaunchAgents for the morning briefing, evening review,
# and weekly review, using this repo's actual path and your preferred times.

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
AGENTS_DIR="$HOME/Library/LaunchAgents"
mkdir -p "$AGENTS_DIR" "$SCRIPT_DIR/logs"

# Build a small .app wrapper to run the scheduled scripts. macOS grants privacy
# permissions (Documents, Calendar, Messages) per-app via normal one-time prompts —
# without this, launchd's bare bash can't prompt and would need Full Disk Access.
APP="$HOME/Applications/Chief of Staff Runner.app"
mkdir -p "$HOME/Applications"
# The target script and log file come in as env vars (set per-agent in the plists);
# command-line args don't reliably reach applet run handlers. With no env vars set
# (i.e. the app is double-clicked or opened during install), it runs the permission
# grant — that way the prompts are attributed to this app, not to the user's terminal.
osacompile -o "$APP" <<APPLET
on run
    set s to system attribute "COS_SCRIPT"
    set logf to system attribute "COS_LOG"
    if s is "" then
        set s to "$SCRIPT_DIR/grant-permissions.sh"
        set logf to "$SCRIPT_DIR/logs/grant-permissions.log"
    end if
    do shell script "/bin/bash " & quoted form of s & " >> " & quoted form of logf & " 2>&1"
end run
APPLET
APP_EXEC="$APP/Contents/MacOS/applet"

# Times chosen during onboarding live in config.sh — used as defaults here
source "$SCRIPT_DIR/config.sh" 2>/dev/null || true

echo "Setting up automatic daily runs. Press Enter to accept the defaults."
read -p "Morning briefing time [${MORNING_TIME:-09:00}]: " MORNING
read -p "Evening review time [${EVENING_TIME:-21:00}]: " EVENING
read -p "Weekly review time, Sundays [${WEEKLY_TIME:-10:00}]: " WEEKLY
MORNING=${MORNING:-${MORNING_TIME:-09:00}}
EVENING=${EVENING:-${EVENING_TIME:-21:00}}
WEEKLY=${WEEKLY:-${WEEKLY_TIME:-10:00}}

write_agent() {
    local label="$1" script="$2" time="$3" weekday="$4"
    local hour=$((10#${time%%:*}))
    local minute=$((10#${time##*:}))
    local plist="$AGENTS_DIR/$label.plist"
    local weekday_xml=""
    if [ -n "$weekday" ]; then
        weekday_xml="
        <key>Weekday</key>
        <integer>$weekday</integer>"
    fi

    cat > "$plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>$label</string>
    <key>ProgramArguments</key>
    <array>
        <string>$APP_EXEC</string>
    </array>
    <key>StartCalendarInterval</key>
    <dict>
        <key>Hour</key>
        <integer>$hour</integer>
        <key>Minute</key>
        <integer>$minute</integer>$weekday_xml
    </dict>
    <key>EnvironmentVariables</key>
    <dict>
        <key>PATH</key>
        <string>/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin</string>
        <key>COS_SCRIPT</key>
        <string>$SCRIPT_DIR/$script</string>
        <key>COS_LOG</key>
        <string>$SCRIPT_DIR/logs/$label.log</string>
    </dict>
    <key>StandardOutPath</key>
    <string>$SCRIPT_DIR/logs/$label.log</string>
    <key>StandardErrorPath</key>
    <string>$SCRIPT_DIR/logs/$label.err</string>
</dict>
</plist>
PLIST

    # Start error logs fresh so doctor.sh only sees issues from this install onward
    : > "$SCRIPT_DIR/logs/$label.err"

    launchctl unload "$plist" 2>/dev/null || true
    launchctl load "$plist"
    echo "  Loaded: $label — $time"
}

write_agent "com.cos.morning" "morning-briefing.sh" "$MORNING" ""
write_agent "com.cos.evening" "evening-review.sh" "$EVENING" ""
write_agent "com.cos.weekly" "weekly-review.sh" "$WEEKLY" "0"

echo ""
echo "One-time permissions step: macOS will now show 2–3 prompts from"
echo "'Chief of Staff Runner' — files access (to read your notes), Calendar"
echo "(to add your schedule), and Messages (to text you the briefing)."
echo "Click Allow on each. You'll never see them again."
read -p "Press Enter to trigger the prompts... " _ || true
chmod +x "$SCRIPT_DIR/grant-permissions.sh"
# open (not direct exec) so macOS attributes the prompts to the Runner app itself —
# run from a terminal, the grants would wrongly attach to the terminal app instead.
: > "$SCRIPT_DIR/logs/grant-permissions.log"
if open -W "$APP" && grep -q "All permissions granted" "$SCRIPT_DIR/logs/grant-permissions.log" 2>/dev/null; then
    echo "  All permissions granted."
else
    echo "  A permission was denied or timed out — see $SCRIPT_DIR/logs/grant-permissions.log"
    echo "  IMPORTANT: macOS never re-asks after a denial. To recover, run:"
    echo "    tccutil reset AppleEvents && bash install-automation.sh"
fi

echo ""
echo "Done. The system will now run automatically."
echo ""
echo "If a briefing ever fails to arrive, run: bash $SCRIPT_DIR/doctor.sh"
echo ""
echo "To uninstall: launchctl unload ~/Library/LaunchAgents/com.cos.*.plist && rm ~/Library/LaunchAgents/com.cos.*.plist && rm -rf \"\$HOME/Applications/Chief of Staff Runner.app\""
