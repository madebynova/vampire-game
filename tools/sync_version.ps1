<#
.SYNOPSIS
  Copies the game version from the VERSION file (the single source of truth) into
  export_presets.cfg, so the Windows .exe's file/product version matches the release.

.EXAMPLE
  ./tools/sync_version.ps1          # then commit export_presets.cfg
#>
$ErrorActionPreference = "Stop"
Set-Location (Join-Path $PSScriptRoot "..")

$version = (Get-Content VERSION -Raw).Trim()
if ($version -notmatch '^\d+\.\d+\.\d+$') { Write-Error "VERSION must look like 0.1.0, found '$version'."; exit 1 }

$quad = "$version.0"    # Windows file versions have four parts
$text = [IO.File]::ReadAllText("export_presets.cfg")
$new = $text -replace '(?m)^(application/file_version=)".*"', "`$1`"$quad`"" `
             -replace '(?m)^(application/product_version=)".*"', "`$1`"$quad`""
if ($new -ne $text) {
    [IO.File]::WriteAllText("export_presets.cfg", $new, (New-Object Text.UTF8Encoding($false)))
    Write-Host "export_presets.cfg updated to $quad. Commit it." -ForegroundColor Green
} else {
    Write-Host "export_presets.cfg already matches $quad." -ForegroundColor Green
}
