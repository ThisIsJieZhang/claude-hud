#!/usr/bin/env bash
# check-install.sh — Step 0.5: Check for existing claude-hud statusLine installation
#
# Usage:
#   source "$PLUGIN_DIR/commands/scripts/check-install.sh"
#   bash "$PLUGIN_DIR/commands/scripts/check-install.sh" [CONFIG_DIR]
#
# Accepts CONFIG_DIR as $1 or env var. Prints INSTALL_STATUS=none|valid|stale.
# When sourced, also sets INSTALL_STATUS in the calling shell.

if [ -n "$1" ]; then
  CONFIG_DIR="$1"
fi

if [ -z "$CONFIG_DIR" ]; then
  echo "ERROR: CONFIG_DIR not set. Pass as \$1 or set the env var." >&2
  INSTALL_STATUS="error"
  export INSTALL_STATUS
  exit 1
fi

SETTINGS_FILE="$CONFIG_DIR/settings.json"

if [ ! -f "$SETTINGS_FILE" ]; then
  echo "No settings.json at $CONFIG_DIR — will be created in Step 3."
  INSTALL_STATUS="none"
  export INSTALL_STATUS
  return 0 2>/dev/null || exit 0
fi

# Extract existing statusLine.command
EXISTING_CMD=$(node -e "try{const c=JSON.parse(require('fs').readFileSync('$SETTINGS_FILE','utf8'));console.log(c.statusLine?.command||'')}catch(e){}" 2>/dev/null)

if [ -z "$EXISTING_CMD" ]; then
  echo "No existing statusLine config found in $SETTINGS_FILE"
  INSTALL_STATUS="none"
  export INSTALL_STATUS
  return 0 2>/dev/null || exit 0
fi

echo "Existing statusLine command found:"
echo "  $EXISTING_CMD"

# Extract the plugin index file path from the command
EXISTING_PLUGIN_PATH=$(echo "$EXISTING_CMD" | grep -oP '(?<= )[^ ]+index\.(js|ts)' | head -1)

if [ -n "$EXISTING_PLUGIN_PATH" ] && [ ! -f "$EXISTING_PLUGIN_PATH" ]; then
  echo "WARNING: Plugin path no longer exists: $EXISTING_PLUGIN_PATH"
  echo "This is a stale installation — setup will overwrite it."
  INSTALL_STATUS="stale"
else
  echo "Existing installation looks valid. Setup will update it."
  INSTALL_STATUS="valid"
fi

export INSTALL_STATUS
