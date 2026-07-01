#!/bin/bash
# AI Chief of Staff — Setup
# Runs the onboarding flow to generate a personalised system

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

echo ""
echo "==================================="
echo "  AI Chief of Staff — Setup"
echo "==================================="
echo ""
echo "This will ask you some questions about your schedule, goals, and"
echo "preferences, then generate a personalised AI chief of staff system."
echo ""
echo "Takes about 5 minutes."
echo ""

# Check Claude CLI is installed
if ! command -v claude &> /dev/null; then
    echo "Error: Claude CLI is not installed."
    echo "Install it with: brew install claude-code"
    echo "Or see: https://docs.anthropic.com/en/docs/claude-code"
    exit 1
fi

# Run the onboarding prompt in interactive mode
cd "$SCRIPT_DIR"
claude --system-prompt "$(cat "$SCRIPT_DIR/onboarding-prompt.md")" "Hi! I'd like to set up my AI Chief of Staff. Let's go."
