#!/usr/bin/env bash
# detect-runtime.sh — Step 1: Detect runtime (bun/node) and SOURCE file
#
# Usage:
#   source "$PLUGIN_DIR/commands/scripts/detect-runtime.sh"
#   bash "$PLUGIN_DIR/commands/scripts/detect-runtime.sh" [PLUGIN_DIR]
#
# Accepts PLUGIN_DIR as $1 or env var.
# Prints RUNTIME_PATH=... and SOURCE=...
# When sourced, sets RUNTIME_PATH and SOURCE in the calling shell.
# Exits 1 with a clear error message if neither bun nor node is found,
# or if no compiled output exists and runtime is not bun.

if [ -n "$1" ]; then
  PLUGIN_DIR="$1"
fi

if [ -z "$PLUGIN_DIR" ]; then
  echo "ERROR: PLUGIN_DIR not set. Pass as \$1 or set the env var." >&2
  return 1 2>/dev/null || exit 1
fi

# Probe for runtime: prefer bun for performance, fallback to node
RUNTIME_PATH=$(command -v bun 2>/dev/null || command -v node 2>/dev/null)

if [ -z "$RUNTIME_PATH" ]; then
  echo "ERROR: Neither bun nor node found in PATH." >&2
  echo "" >&2
  echo "Install one of:" >&2
  echo "  Node.js LTS: https://nodejs.org/" >&2
  echo "  Bun:         https://bun.sh/" >&2
  echo "" >&2
  echo "If winget is available: winget install OpenJS.NodeJS.LTS" >&2
  echo "" >&2
  echo "After installation, restart your shell and re-run /claude-hud:setup." >&2
  return 1 2>/dev/null || exit 1
fi

RUNTIME_NAME=$(basename "$RUNTIME_PATH")

# Determine SOURCE based on what exists in PLUGIN_DIR and which runtime we have
if [ -f "${PLUGIN_DIR}dist/index.js" ]; then
  SOURCE="dist/index.js"
elif [ "$RUNTIME_NAME" = "bun" ]; then
  SOURCE="src/index.ts"
else
  echo "ERROR: No dist/index.js found in ${PLUGIN_DIR} and runtime is not bun." >&2
  echo "" >&2
  echo "Options:" >&2
  echo "  1. Install bun (native TypeScript support): curl -fsSL https://bun.sh/install | bash" >&2
  echo "  2. Reinstall the plugin (should include a dist/ build): /plugin install claude-hud" >&2
  return 1 2>/dev/null || exit 1
fi

echo "RUNTIME_PATH=$RUNTIME_PATH"
echo "SOURCE=$SOURCE"

export RUNTIME_PATH
export SOURCE
