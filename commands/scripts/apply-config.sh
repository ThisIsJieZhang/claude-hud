#!/usr/bin/env bash
# apply-config.sh — Step 3: Merge statusLine config into settings.json
#
# Usage:
#   bash "$PLUGIN_DIR/commands/scripts/apply-config.sh" CONFIG_DIR COMMAND
#
# CONFIG_DIR  — directory containing settings.json (e.g. ~/.claude)
# COMMAND     — the full statusLine command string to write
#
# Creates settings.json if it doesn't exist.
# Merges {"statusLine":{"type":"command","command":"..."}} preserving all other keys.
# Retries once if the file was unexpectedly modified during the write.

CONFIG_DIR="${1:-$CONFIG_DIR}"
COMMAND="${2:-$COMMAND}"

if [ -z "$CONFIG_DIR" ]; then
  echo "ERROR: CONFIG_DIR not provided. Pass as \$1 or set the env var." >&2
  exit 1
fi

if [ -z "$COMMAND" ]; then
  echo "ERROR: COMMAND not provided. Pass as \$2 or set the env var." >&2
  exit 1
fi

SETTINGS_FILE="$CONFIG_DIR/settings.json"

_apply_config() {
  local settings_file="$1"
  local command="$2"

  # Build the merge script
  node -e "
    const fs = require('fs');
    const path = '$settings_file';
    const newCmd = process.argv[1];

    let existing = {};
    if (fs.existsSync(path)) {
      try {
        existing = JSON.parse(fs.readFileSync(path, 'utf8'));
      } catch (e) {
        console.error('ERROR: Could not parse ' + path + ': ' + e.message);
        process.exit(1);
      }
    }

    existing.statusLine = { type: 'command', command: newCmd };

    fs.writeFileSync(path, JSON.stringify(existing, null, 2) + '\n');
    console.log('statusLine written to ' + path);
  " "$command"
}

# Ensure config directory exists
mkdir -p "$CONFIG_DIR"

# First attempt
if _apply_config "$SETTINGS_FILE" "$COMMAND"; then
  exit 0
fi

# Check if failure was due to unexpected modification — retry once
echo "Write failed. Retrying once..." >&2
sleep 0.5
if _apply_config "$SETTINGS_FILE" "$COMMAND"; then
  exit 0
else
  echo "ERROR: Failed to write $SETTINGS_FILE after retry." >&2
  exit 1
fi
