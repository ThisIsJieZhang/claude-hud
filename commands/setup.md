---
description: Configure claude-hud as your statusline
allowed-tools: Bash, Read, Edit, AskUserQuestion
---

**Note**: Placeholders like `{RUNTIME_PATH}`, `{SOURCE}`, `{CLI_TYPE}`, `{CONFIG_DIR}`, and `{GENERATED_COMMAND}` should be substituted with actual detected values.

## Bootstrap (inline — required before scripts are accessible)

Run this first to detect `CLI_TYPE`, `CONFIG_DIR`, and `PLUGIN_DIR`. All subsequent steps delegate to scripts inside `$PLUGIN_DIR`.

**macOS/Linux**:
```bash
# ── 1. Detect CLI_TYPE + CONFIG_DIR ────────────────────────────────────────
if [ -n "$CLAUDE_HUD_CLI" ]; then
  CLI_TYPE="$CLAUDE_HUD_CLI"
  echo "Using CLAUDE_HUD_CLI override: $CLI_TYPE"
else
  PARENT_CMD=$(ps -p $PPID -o comm= 2>/dev/null | tr -d '[:space:]')
  PARENT_CMD=$(basename "$PARENT_CMD" 2>/dev/null || echo "$PARENT_CMD")
  if [ -n "$PARENT_CMD" ] && [ "$PARENT_CMD" != "bash" ] && [ "$PARENT_CMD" != "sh" ]; then
    if [ "$PARENT_CMD" = "claude" ]; then
      CANDIDATE_DIR="${CLAUDE_CONFIG_DIR:-$HOME/.claude}"
    else
      CANDIDATE_DIR="$HOME/.$PARENT_CMD"
    fi
    if [ -d "$CANDIDATE_DIR" ] || command -v "$PARENT_CMD" >/dev/null 2>&1; then
      CLI_TYPE="$PARENT_CMD"
      CONFIG_DIR="$CANDIDATE_DIR"
      echo "Detected CLI from parent process: $CLI_TYPE"
    fi
  fi
  if [ -z "$CLI_TYPE" ]; then
    CLI_TYPE="claude"
    echo "No CLI detected from parent process, defaulting to: $CLI_TYPE"
  fi
fi
if [ -z "$CONFIG_DIR" ]; then
  if [ "$CLI_TYPE" = "claude" ]; then
    CONFIG_DIR="${CLAUDE_CONFIG_DIR:-$HOME/.claude}"
  else
    CONFIG_DIR="$HOME/.$CLI_TYPE"
  fi
fi
echo "CLI_TYPE=$CLI_TYPE | CONFIG_DIR=$CONFIG_DIR"

# ── 2. Detect PLUGIN_DIR ───────────────────────────────────────────────────
# Format A — versioned cache layout (Claude Code)
PLUGIN_DIR=$(ls -d "$CONFIG_DIR"/plugins/cache/claude-hud/claude-hud/*/ 2>/dev/null \
  | awk -F/ '{ print $(NF-1) "\t" $(0) }' \
  | sort -t. -k1,1n -k2,2n -k3,3n -k4,4n \
  | tail -1 | cut -f2-)

# Format B — flat marketplaces layout (CodeBuddy and similar CLIs)
if [ -z "$PLUGIN_DIR" ]; then
  PLUGIN_DIR=$(ls -d "$CONFIG_DIR"/plugins/marketplaces/*/external_plugins/claude-hud/ 2>/dev/null | head -1)
fi

if [ -z "$PLUGIN_DIR" ]; then
  echo "ERROR: claude-hud plugin not found. Run /plugin install claude-hud first." >&2
  exit 1
fi
echo "PLUGIN_DIR=$PLUGIN_DIR"
```

**Windows (PowerShell)**:
```powershell
# ── 1. Detect CLI_TYPE + CONFIG_DIR ────────────────────────────────────────
if ($env:CLAUDE_HUD_CLI) {
  $CLI_TYPE = $env:CLAUDE_HUD_CLI
  Write-Host "Using CLAUDE_HUD_CLI override: $CLI_TYPE"
} else {
  $parentId   = (Get-Process -Id $PID).Parent.Id
  $parentName = if ($parentId) { (Get-Process -Id $parentId -ErrorAction SilentlyContinue).Name } else { $null }
  if ($parentName -and $parentName -notin @("bash","sh","powershell","pwsh","cmd")) {
    $candidateDir = if ($parentName -eq "claude") {
      if ($env:CLAUDE_CONFIG_DIR) { $env:CLAUDE_CONFIG_DIR } else { Join-Path $HOME ".claude" }
    } else { Join-Path $HOME ".$parentName" }
    if ((Test-Path $candidateDir) -or (Get-Command $parentName -ErrorAction SilentlyContinue)) {
      $CLI_TYPE   = $parentName
      $CONFIG_DIR = $candidateDir
      Write-Host "Detected CLI from parent process: $CLI_TYPE"
    }
  }
  if (-not $CLI_TYPE) {
    $CLI_TYPE = "claude"
    Write-Host "No CLI detected from parent process, defaulting to: $CLI_TYPE"
  }
}
if (-not $CONFIG_DIR) {
  $CONFIG_DIR = if ($CLI_TYPE -eq "claude") {
    if ($env:CLAUDE_CONFIG_DIR) { $env:CLAUDE_CONFIG_DIR } else { Join-Path $HOME ".claude" }
  } else { Join-Path $HOME ".$CLI_TYPE" }
}
Write-Host "CLI_TYPE=$CLI_TYPE | CONFIG_DIR=$CONFIG_DIR"

# ── 2. Detect PLUGIN_DIR ───────────────────────────────────────────────────
# Format A — versioned cache layout (Claude Code)
$pluginDir = (Get-ChildItem (Join-Path $CONFIG_DIR "plugins\cache\claude-hud\claude-hud") `
  -Directory -ErrorAction SilentlyContinue `
  | Where-Object { $_.Name -match '^\d+(\.\d+)+$' } `
  | Sort-Object { [version]$_.Name } -Descending `
  | Select-Object -First 1).FullName

# Format B — flat marketplaces layout (CodeBuddy and similar CLIs)
if (-not $pluginDir) {
  $pluginDir = (Get-ChildItem (Join-Path $CONFIG_DIR "plugins\marketplaces") `
    -Directory -ErrorAction SilentlyContinue `
    | ForEach-Object { Join-Path $_.FullName "external_plugins\claude-hud" } `
    | Where-Object { Test-Path $_ } `
    | Select-Object -First 1)
}

if (-not $pluginDir) {
  Write-Error "claude-hud plugin not found. Run /plugin install claude-hud first."
  exit 1
}
$PLUGIN_DIR = $pluginDir
Write-Host "PLUGIN_DIR=$PLUGIN_DIR"
```

If the detected CLI is wrong, set `CLAUDE_HUD_CLI` to the correct CLI type key and re-run setup. Any key registered in `src/cli-profiles.ts` (built-in: `claude`, `codebuddy`, `claude-internal`) or user-defined under `cliProfiles` in the HUD `config.json` is valid.

---

## Step 0.5: Check for Existing Installation

Using `$CONFIG_DIR` from the bootstrap, check whether claude-hud is already configured.

**macOS/Linux**:
```bash
source "$PLUGIN_DIR/commands/scripts/check-install.sh"
```

**Windows (PowerShell)**:
```powershell
. "$PLUGIN_DIR\commands\scripts\check-install.ps1" -ConfigDir $CONFIG_DIR
```

**Interpreting results** (`INSTALL_STATUS` is set in the calling shell):

| `INSTALL_STATUS` | Message | Action |
|-----------------|---------|--------|
| `none` | "No existing statusLine config" | Proceed normally — Step 3 will create it |
| `valid` | "Existing installation looks valid" | Proceed — Step 3 will update to the latest format |
| `stale` | "Plugin path no longer exists" | Proceed — Step 3 will overwrite with the correct path |
| `error` | "Could not parse settings.json" | Warn the user; fix JSON before proceeding |

**Cleanup** (only if user wants to start fresh):
```bash
# macOS/Linux — remove only the statusLine key, preserve other settings
node -e "
  const fs = require('fs');
  const path = '$CONFIG_DIR/settings.json';
  const c = JSON.parse(fs.readFileSync(path, 'utf8'));
  delete c.statusLine;
  fs.writeFileSync(path, JSON.stringify(c, null, 2));
  console.log('statusLine removed from', path);
"
```

**Linux cross-device filesystem note**: If `$CONFIG_DIR` is on a different filesystem than `/tmp` (common with tmpfs), plugin installation may fail with `EXDEV: cross-device link not permitted`. If that error occurred, set `TMPDIR` before re-running the CLI:
```bash
mkdir -p ~/.cache/tmp && TMPDIR=~/.cache/tmp claude
```

---

## Step 1: Detect Platform, Shell, and Runtime

**IMPORTANT**: Use the environment context values (`Platform:` and `Shell:`), not `uname -s` or ad-hoc checks. The Bash tool may report MINGW/MSYS on Windows, so branch only by the context values.

| Platform | Shell | Command Format |
|----------|-------|----------------|
| `darwin` | any | bash (macOS instructions) |
| `linux` | any | bash (Linux instructions) |
| `win32` | `bash` (Git Bash, MSYS2) | bash - use macOS/Linux instructions. Never use PowerShell commands with bash. |
| `win32` | `powershell`, `pwsh`, or `cmd` | PowerShell (use Windows + PowerShell instructions) |

---

**macOS/Linux** (Platform: `darwin` or `linux`):

Run the detect-runtime script (uses `$PLUGIN_DIR` from bootstrap):

```bash
source "$PLUGIN_DIR/commands/scripts/detect-runtime.sh"
```

This sets `RUNTIME_PATH` and `SOURCE` in the calling shell, or exits with a clear error.

If the script errors, follow the instructions it prints (install bun/node or reinstall plugin).

Now generate `GENERATED_COMMAND` from the values above. The command sets `CLAUDE_HUD_CLI` at runtime:

**Format A (versioned cache layout) — bun**:
```
bash -c 'export CLAUDE_HUD_CLI={CLI_TYPE}; plugin_dir=$(ls -d "{CONFIG_DIR}"/plugins/cache/claude-hud/claude-hud/*/ 2>/dev/null | awk -F/ '"'"'{ print $(NF-1) "\t" $(0) }'"'"' | sort -t. -k1,1n -k2,2n -k3,3n -k4,4n | tail -1 | cut -f2-); exec "{RUNTIME_PATH}" --env-file /dev/null "${plugin_dir}{SOURCE}"'
```

**Format A (versioned cache layout) — node**:
```
bash -c 'export CLAUDE_HUD_CLI={CLI_TYPE}; plugin_dir=$(ls -d "{CONFIG_DIR}"/plugins/cache/claude-hud/claude-hud/*/ 2>/dev/null | awk -F/ '"'"'{ print $(NF-1) "\t" $(0) }'"'"' | sort -t. -k1,1n -k2,2n -k3,3n -k4,4n | tail -1 | cut -f2-); exec "{RUNTIME_PATH}" "${plugin_dir}{SOURCE}"'
```

**Format B (flat marketplaces layout) — bun** (path is static, no version lookup):
```
bash -c 'export CLAUDE_HUD_CLI={CLI_TYPE}; exec "{RUNTIME_PATH}" --env-file /dev/null "{PLUGIN_DIR}{SOURCE}"'
```

**Format B (flat marketplaces layout) — node**:
```
bash -c 'export CLAUDE_HUD_CLI={CLI_TYPE}; exec "{RUNTIME_PATH}" "{PLUGIN_DIR}{SOURCE}"'
```

**Note**: `{CLI_TYPE}`, `{CONFIG_DIR}`, and `{PLUGIN_DIR}` are the literal values detected above. Substitute them when generating the command.

**Windows + Git Bash** (Platform: `win32`, Shell: `bash`):

Use the macOS/Linux bash instructions above — same detection commands, same command format. Do not use PowerShell commands when the shell is bash.

**Windows + PowerShell** (Platform: `win32`, Shell: `powershell`, `pwsh`, or `cmd`):

Run the detect-runtime script (uses `$PLUGIN_DIR` from bootstrap):

```powershell
. "$PLUGIN_DIR\commands\scripts\detect-runtime.ps1" -PluginDir $PLUGIN_DIR
```

This sets `$RUNTIME_PATH` and `$SOURCE` in the calling shell, or prints an error.

Now generate `$GENERATED_COMMAND` from the values above:

**Format A (versioned cache layout) — bun**:
```
powershell -Command "& {$env:CLAUDE_HUD_CLI='{CLI_TYPE}'; $p=(Get-ChildItem (Join-Path '{CONFIG_DIR}' 'plugins\cache\claude-hud\claude-hud') -Directory | Where-Object { $_.Name -match '^\d+(\.\d+)+$' } | Sort-Object { [version]$_.Name } -Descending | Select-Object -First 1).FullName; & '{RUNTIME_PATH}' '--env-file' 'NUL' (Join-Path $p '{SOURCE}')}"
```

**Format A (versioned cache layout) — node**:
```
powershell -Command "& {$env:CLAUDE_HUD_CLI='{CLI_TYPE}'; $p=(Get-ChildItem (Join-Path '{CONFIG_DIR}' 'plugins\cache\claude-hud\claude-hud') -Directory | Where-Object { $_.Name -match '^\d+(\.\d+)+$' } | Sort-Object { [version]$_.Name } -Descending | Select-Object -First 1).FullName; & '{RUNTIME_PATH}' (Join-Path $p '{SOURCE}')}"
```

**Format B (flat marketplaces layout) — bun** (path is static):
```
powershell -Command "& {$env:CLAUDE_HUD_CLI='{CLI_TYPE}'; & '{RUNTIME_PATH}' '--env-file' 'NUL' (Join-Path '{PLUGIN_DIR}' '{SOURCE}')}"
```

**Format B (flat marketplaces layout) — node**:
```
powershell -Command "& {$env:CLAUDE_HUD_CLI='{CLI_TYPE}'; & '{RUNTIME_PATH}' (Join-Path '{PLUGIN_DIR}' '{SOURCE}')}"
```

**Note**: `{CLI_TYPE}`, `{CONFIG_DIR}`, and `{PLUGIN_DIR}` are the literal values detected above. Substitute them when generating the command.

**WSL (Windows Subsystem for Linux)**: If running in WSL, use the macOS/Linux instructions. Run the bootstrap inside WSL to detect the correct CLI and config dir. Ensure the plugin is installed in the Linux environment, not the Windows side.

## Step 2: Test Command

Run the generated command. It should produce output (the HUD lines) within a few seconds.

- If it errors, do not proceed to Step 3.
- If it hangs for more than a few seconds, cancel and debug.
- This test catches issues like broken runtime binaries, missing plugins, or path problems.

## Step 3: Apply Configuration

Write the `statusLine` config into `settings.json`, merging with any existing settings.

**macOS/Linux** (Platform: `darwin` or `linux`, or Platform: `win32` + Shell: `bash`):
```bash
bash "$PLUGIN_DIR/commands/scripts/apply-config.sh" "$CONFIG_DIR" "$GENERATED_COMMAND"
```

**Windows (PowerShell)**:
```powershell
& "$PLUGIN_DIR\commands\scripts\apply-config.ps1" -ConfigDir $CONFIG_DIR -Command $GENERATED_COMMAND
```

The script creates `settings.json` if it doesn't exist, preserves all existing keys, and retries once if the file was unexpectedly modified. If the file contains invalid JSON it will report the error without overwriting.

After successfully writing the config, tell the user:

> ✅ Config written to `{CONFIG_DIR}/settings.json`. **Please restart {CLI_TYPE} now** — quit and relaunch the CLI.
> Once restarted, run `/claude-hud:setup` again to complete Step 4 and verify the HUD is working.

**Windows note**: Keep the restart guidance separate from runtime installation guidance.
- If the user just installed Node.js or Bun, they should restart their shell first so `bun` or `node` is available in `PATH`.
- After `statusLine` is written successfully, they should fully quit the CLI and launch a fresh session before judging whether the HUD setup worked.

**Note**: The generated command dynamically finds and runs the latest installed plugin version. Updates are automatic - no need to re-run setup after plugin updates. If the HUD suddenly stops working, re-run `/claude-hud:setup` to verify the plugin is still installed.

## Step 4: Optional Features

After the statusLine is applied, ask the user if they'd like to enable additional HUD features beyond the default 2-line display.

Use AskUserQuestion:
- header: "Extras"
- question: "Enable any optional HUD features? (all hidden by default)"
- multiSelect: true
- options:
  - "Tools activity" — Shows running/completed tools (◐ Edit: file.ts | ✓ Read ×3)
  - "Agents & Todos" — Shows subagent status and todo progress
  - "Session info" — Shows session duration and config counts (CLAUDE.md, rules, MCPs)
  - "Session name" — Shows session slug or custom title from /rename
  - "Custom line" — Display a custom phrase in the HUD

**If user selects any options**, write `plugins/claude-hud/config.json` inside the `$CONFIG_DIR` detected in the bootstrap (e.g. `$CONFIG_DIR/plugins/claude-hud/config.json`). Create directories if needed:

| Selection | Config keys |
|-----------|------------|
| Tools activity | `display.showTools: true` |
| Agents & Todos | `display.showAgents: true, display.showTodos: true` |
| Session info | `display.showDuration: true, display.showConfigCounts: true` |
| Session name | `display.showSessionName: true` |
| Custom line | `display.customLine: "<user's text>"` — ask user for the text (max 80 chars) |

Merge with existing config if the file already exists. Only write keys the user selected — don't write `false` for unselected items (defaults handle that).

**If user selects nothing** (or picks "Other" and says skip/none), do not create a config file. The defaults are fine.

---

## Step 5: Verify & Finish

**First, confirm the user has restarted the CLI** since Step 3 wrote the config. If they haven't, ask them to restart before proceeding — the HUD cannot appear in the same session where setup was run.

Use AskUserQuestion:
- Question: "Setup complete! The HUD should appear below your input field. Is it working?"
- Options: "Yes, it's working" / "No, something's wrong"

**If yes**: Ask the user if they'd like to ⭐ star the claude-hud repository on GitHub to support the project. If they agree and `gh` CLI is available, run: `gh api -X PUT /user/starred/jarrodwatts/claude-hud`. Only run the star command if they explicitly say yes.

**If no**: Debug systematically:

1. **Restart the CLI** (most common cause on macOS):
    - The statusLine config requires a restart to take effect
    - Quit the CLI completely and relaunch it, then re-run `/claude-hud:setup` to verify
    - If you've already restarted, continue below

2. **Verify config was applied**:
   - Read settings file at `$CONFIG_DIR/settings.json` (use the value from the bootstrap)
   - Check statusLine.command exists and looks correct
   - If command contains a hardcoded version path (not using the dynamic version-lookup command), it may be a stale config from a previous setup
   - Verify the command contains `CLAUDE_HUD_CLI={CLI_TYPE}` matching the detected CLI

3. **Test the command manually** and capture error output:
   ```bash
   {GENERATED_COMMAND} 2>&1
   ```

4. **Common issues to check**:

   **"command not found" or empty output**:
   - Runtime path might be wrong: `ls -la {RUNTIME_PATH}`
   - On macOS with mise/nvm/asdf: the absolute path may have changed after a runtime update
   - Symlinks may be stale: `command -v node` often returns a symlink that can break after version updates
   - Solution: re-detect with `command -v bun` or `command -v node`, and verify with `realpath {RUNTIME_PATH}` (or `readlink -f {RUNTIME_PATH}`) to get the true absolute path

   **"No such file or directory" for plugin**:
   - Check Format A (versioned cache): `ls "$CONFIG_DIR/plugins/cache/claude-hud/"`
   - Check Format B (flat marketplaces): `ls "$CONFIG_DIR/plugins/marketplaces/"*/external_plugins/claude-hud/`
   - If neither exists, reinstall via `/plugin install claude-hud`

   **Windows shell mismatch (for example, "bash not recognized")**:
   - Command format does not match `Platform:` + `Shell:`
   - Solution: re-run Step 1 branch logic and use the matching variant

   **Windows: PowerShell execution policy error**:
   - Run: `Set-ExecutionPolicy -Scope CurrentUser -ExecutionPolicy RemoteSigned`

   **Permission denied**:
   - Runtime not executable: `chmod +x {RUNTIME_PATH}`

   **WSL confusion**:
   - If using WSL, ensure plugin is installed in Linux environment, not Windows
   - Check: `ls "$CONFIG_DIR/plugins/cache/claude-hud/"`

5. **If still stuck**: Show the user the exact command that was generated and the error, so they can report it or debug further
