# detect-runtime.ps1 — Step 1: Detect runtime (bun/node) and SOURCE file
#
# Usage:
#   . "$PLUGIN_DIR\commands\scripts\detect-runtime.ps1"
#   & "$PLUGIN_DIR\commands\scripts\detect-runtime.ps1" -PluginDir $pluginDir
#
# Accepts PLUGIN_DIR as parameter or env var.
# Prints RUNTIME_PATH=... and SOURCE=...
# When dot-sourced, sets $RUNTIME_PATH and $SOURCE in the calling shell.
# Throws on error with a clear message if no runtime is found or no source exists.

param(
  [string]$PluginDir = $env:PLUGIN_DIR
)

if (-not $PluginDir) {
  Write-Error "PLUGIN_DIR not set. Pass as -PluginDir or set the env var."
  return
}

# Probe for runtime: prefer bun for performance, fallback to node
$bunCmd  = Get-Command bun  -ErrorAction SilentlyContinue
$nodeCmd = Get-Command node -ErrorAction SilentlyContinue

if ($bunCmd) {
  $RUNTIME_PATH = $bunCmd.Source
} elseif ($nodeCmd) {
  $RUNTIME_PATH = $nodeCmd.Source
} else {
  Write-Error @"
Neither bun nor node found in PATH.

Install one of:
  Node.js LTS: https://nodejs.org/
  Bun:         https://bun.sh/

If winget is available:
  winget install OpenJS.NodeJS.LTS

After installation, restart PowerShell and re-run /claude-hud:setup.
"@
  return
}

$runtimeName = [System.IO.Path]::GetFileNameWithoutExtension($RUNTIME_PATH)

# Determine SOURCE based on what exists in PluginDir and which runtime we have
$distPath = Join-Path $PluginDir "dist\index.js"

if (Test-Path $distPath) {
  $SOURCE = "dist\index.js"
} elseif ($runtimeName -eq "bun") {
  $SOURCE = "src\index.ts"
} else {
  Write-Error @"
No dist\index.js found in $PluginDir and runtime is not bun.

Options:
  1. Install bun (native TypeScript support): irm bun.sh/install.ps1 | iex
  2. Reinstall the plugin (should include a dist\ build): /plugin install claude-hud
"@
  return
}

Write-Host "RUNTIME_PATH=$RUNTIME_PATH"
Write-Host "SOURCE=$SOURCE"
