#!/bin/bash
# AI Chief of Staff — Install automation
# Generates and loads LaunchAgents for the morning briefing, evening review,
# and weekly review, using this repo's actual path and your preferred times.

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
AGENTS_DIR="$HOME/Library/LaunchAgents"
mkdir -p "$AGENTS_DIR" "$SCRIPT_DIR/logs"

echo "Setting up automatic daily runs. Press Enter to accept the defaults."
read -p "Morning briefing time [09:00]: " MORNING
read -p "Evening review time [21:00]: " EVENING
read -p "Weekly review time, Sundays [10:00]: " WEEKLY
MORNING=${MORNING:-09:00}
EVENING=${EVENING:-21:00}
WEEKLY=${WEEKLY:-10:00}

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
        <string>/bin/bash</string>
        <string>$SCRIPT_DIR/$script</string>
    </array>
    <key>StartCalendarInterval</key>
    <dict>
        <key>Hour</key>
        <integer>$hour</integer>
        <key>Minute</key>
        <integer>$minute</integer>$weekday_xml
    </dict>
    <key>StandardOutPath</key>
    <string>$SCRIPT_DIR/logs/$label.log</string>
    <key>StandardErrorPath</key>
    <string>$SCRIPT_DIR/logs/$label.err</string>
</dict>
</plist>
PLIST

    launchctl unload "$plist" 2>/dev/null || true
    launchctl load "$plist"
    echo "  Loaded: $label — $time"
}

write_agent "com.cos.morning" "morning-briefing.sh" "$MORNING" ""
write_agent "com.cos.evening" "evening-review.sh" "$EVENING" ""
write_agent "com.cos.weekly" "weekly-review.sh" "$WEEKLY" "0"

echo ""
echo "Done. The system will now run automatically."
echo ""
echo "macOS permissions — two things to know:"
echo "  1. The first scheduled run may trigger permission prompts (Calendar,"
echo "     notifications). Approve them once and they stick."
echo "  2. If a scheduled run produces nothing, check $SCRIPT_DIR/logs/ for"
echo "     errors, and System Settings > Privacy & Security > Automation to"
echo "     confirm Calendar access. You can always run any script manually."
echo ""
echo "To uninstall: launchctl unload ~/Library/LaunchAgents/com.cos.*.plist && rm ~/Library/LaunchAgents/com.cos.*.plist"
