# apply-config.ps1 — Step 3: Merge statusLine config into settings.json
#
# Usage:
#   & "$PLUGIN_DIR\commands\scripts\apply-config.ps1" -ConfigDir $CONFIG_DIR -Command $GENERATED_COMMAND
#
# ConfigDir  — directory containing settings.json (e.g. ~/.claude)
# Command    — the full statusLine command string to write
#
# Creates settings.json if it doesn't exist.
# Merges {"statusLine":{"type":"command","command":"..."}} preserving all other keys.
# Retries once if the file was unexpectedly modified during the write.

param(
  [Parameter(Mandatory)][string]$ConfigDir,
  [Parameter(Mandatory)][string]$Command
)

$settingsFile = Join-Path $ConfigDir "settings.json"

function Invoke-ApplyConfig {
  param([string]$SettingsFile, [string]$Cmd)

  $existing = [ordered]@{}

  if (Test-Path $SettingsFile) {
    try {
      $raw = Get-Content $SettingsFile -Raw
      $parsed = $raw | ConvertFrom-Json
      # Convert PSCustomObject to ordered hashtable to preserve keys
      $parsed.PSObject.Properties | ForEach-Object {
        $existing[$_.Name] = $_.Value
      }
    } catch {
      Write-Error "Could not parse ${SettingsFile}: $_"
      return $false
    }
  }

  $existing["statusLine"] = [ordered]@{
    type    = "command"
    command = $Cmd
  }

  try {
    # Ensure directory exists
    $dir = Split-Path $SettingsFile
    if (-not (Test-Path $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }

    $existing | ConvertTo-Json -Depth 10 | Set-Content $SettingsFile -Encoding UTF8
    Write-Host "statusLine written to $SettingsFile"
    return $true
  } catch {
    Write-Host "Write failed: $_"
    return $false
  }
}

# First attempt
if (Invoke-ApplyConfig -SettingsFile $settingsFile -Cmd $Command) {
  exit 0
}

# Retry once on unexpected modification
Write-Host "Write failed. Retrying once..." -ForegroundColor Yellow
Start-Sleep -Milliseconds 500

if (Invoke-ApplyConfig -SettingsFile $settingsFile -Cmd $Command) {
  exit 0
} else {
  Write-Error "Failed to write $settingsFile after retry."
  exit 1
}
