<#
.SYNOPSIS
  Builds a Windows playtest executable of the prototype (build/windows/Vampire.exe).

.DESCRIPTION
  Needs the Godot 4.8 editor binary and the matching Windows EXPORT TEMPLATES installed
  (Godot editor: Editor > Manage Export Templates > Download and Install, or install the
  templates .tpz manually). The script checks for them first and tells you exactly what is
  missing instead of failing half way.

.EXAMPLE
  ./tools/build_windows.ps1 -Godot "C:\Godot\Godot_v4.8-stable_win64_console.exe"
#>
param(
    [string]$Godot = $env:GODOT,
    [string]$Preset = "Windows Desktop (playtest)",
    [string]$Out = "build/windows/Vampire.exe"
)

$ErrorActionPreference = "Stop"
Set-Location (Join-Path $PSScriptRoot "..")

if (-not $Godot -or -not (Test-Path $Godot)) {
    Write-Error "Godot binary not found. Pass -Godot <path to Godot_v4.8_..._console.exe> or set `$env:GODOT."
    exit 1
}

# "4.8.dev6.official.8898c2b3d" -> "4.8.dev6"; "4.8.stable.official.abc" -> "4.8.stable"
$full = (& $Godot --version).Trim()
$parts = $full.Split(".")
$tag = ($parts[0..2]) -join "."
$templates = Join-Path $env:APPDATA "Godot\export_templates\$tag"
$needed = @("windows_release_x86_64.exe", "windows_debug_x86_64.exe")
$missing = $needed | Where-Object { -not (Test-Path (Join-Path $templates $_)) }

if ($missing) {
    Write-Host ""
    Write-Host "Cannot export: Windows export templates for Godot $tag are not installed." -ForegroundColor Yellow
    Write-Host "  Expected folder : $templates"
    Write-Host "  Missing files   : $($missing -join ', ')"
    Write-Host "  Fix             : open the Godot editor > Editor > Manage Export Templates > Download and Install"
    Write-Host "                    (development builds such as 4.8-dev6 publish templates on the Godot download page)."
    exit 2
}

New-Item -ItemType Directory -Force (Split-Path $Out) | Out-Null
& $Godot --headless --path . --export-release $Preset $Out
if ($LASTEXITCODE -ne 0) { Write-Error "Export failed ($LASTEXITCODE)."; exit $LASTEXITCODE }

$commit = (git rev-parse --short HEAD)
Write-Host "Built $Out from commit $commit with Godot $tag." -ForegroundColor Green
