#!/bin/bash
# AI Chief of Staff — Send a file's contents to your phone via iMessage
# Sending to your own number/Apple ID lands it in Messages on the phone.
# Usage: send-to-phone.sh <file>
# No-op if PHONE_NUMBER is empty in config.sh.

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/config.sh"

[ -z "$PHONE_NUMBER" ] && exit 0
[ -f "$1" ] || { echo "Usage: send-to-phone.sh <file>"; exit 1; }

# Messages renders plain text only — flatten the markdown before sending.
# Links become "text: url" (bare URLs are tappable in iMessage; if the link
# text is just the URL again, send the URL once), headers lose their #s,
# checkboxes become ☐/☑, table rows become "a — b — c" lines.
BODY=$(python3 - "$1" <<'PYEOF'
import re, sys

def link(m):
    label, url = m.group(1), m.group(2)
    bare = url.split('://')[-1].rstrip('/')
    return url if label.rstrip('/') in (url, bare) else f"{label}: {url}"

out = []
for line in open(sys.argv[1], errors="replace").read().splitlines():
    line = re.sub(r'\[([^\]]+)\]\(([^)]+)\)', link, line)
    line = re.sub(r'\*\*([^*]+)\*\*', r'\1', line)
    line = re.sub(r'^#+ +', '', line)
    line = re.sub(r'^(\s*)- \[ \] ', r'\1☐ ', line)
    line = re.sub(r'^(\s*)- \[x\] ', r'\1☑ ', line)
    s = line.strip()
    if re.fullmatch(r'[-*_]{3,}', s) or re.fullmatch(r'\|[ :|-]+\|', s):
        continue
    if s.startswith('|'):
        line = ' — '.join(p.strip() for p in s.strip('|').split('|'))
    out.append(line)
print('\n'.join(out))
PYEOF
)

osascript - "$PHONE_NUMBER" "$BODY" <<'EOF'
on run {recipient, body}
    tell application "Messages"
        set svc to 1st account whose service type = iMessage
        send body to participant recipient of svc
    end tell
end run
EOF
