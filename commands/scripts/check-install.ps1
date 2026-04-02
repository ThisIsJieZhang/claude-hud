# check-install.ps1 — Step 0.5: Check for existing claude-hud statusLine installation
#
# Usage:
#   . "$PLUGIN_DIR\commands\scripts\check-install.ps1"
#   & "$PLUGIN_DIR\commands\scripts\check-install.ps1" -ConfigDir $CONFIG_DIR
#
# Accepts CONFIG_DIR as parameter or env var. Prints INSTALL_STATUS=none|valid|stale.
# When dot-sourced, also sets $INSTALL_STATUS in the calling shell.

param(
  [string]$ConfigDir = $env:CONFIG_DIR
)

if (-not $ConfigDir) {
  Write-Error "CONFIG_DIR not set. Pass as -ConfigDir or set the env var."
  $INSTALL_STATUS = "error"
  return
}

$settingsFile = Join-Path $ConfigDir "settings.json"

if (-not (Test-Path $settingsFile)) {
  Write-Host "No settings.json at $ConfigDir — will be created in Step 3."
  $INSTALL_STATUS = "none"
  return
}

try {
  $settings = Get-Content $settingsFile -Raw | ConvertFrom-Json
  $existingCmd = $settings.statusLine.command

  if (-not $existingCmd) {
    Write-Host "No existing statusLine config found in $settingsFile"
    $INSTALL_STATUS = "none"
    return
  }

  Write-Host "Existing statusLine command found:"
  Write-Host "  $existingCmd"

  # Check if plugin path in the command still exists
  if ($existingCmd -match ' ([^ ]+index\.(js|ts))') {
    $existingPath = $Matches[1]
    if (-not (Test-Path $existingPath)) {
      Write-Host "WARNING: Plugin path no longer exists: $existingPath"
      Write-Host "This is a stale installation — setup will overwrite it."
      $INSTALL_STATUS = "stale"
    } else {
      Write-Host "Existing installation looks valid. Setup will update it."
      $INSTALL_STATUS = "valid"
    }
  } else {
    Write-Host "Existing installation looks valid. Setup will update it."
    $INSTALL_STATUS = "valid"
  }
} catch {
  Write-Host "Could not parse $settingsFile — will merge carefully in Step 3."
  $INSTALL_STATUS = "error"
}
