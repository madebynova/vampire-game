<#
.SYNOPSIS
  Copies the game version from the VERSION file (the single source of truth) into
  export_presets.cfg (the Windows .exe's file/product version) and project.godot (config/version,
  readable in game code as ProjectSettings.get_setting("application/config/version")).

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
    Write-Host "export_presets.cfg updated to $quad." -ForegroundColor Green
} else {
    Write-Host "export_presets.cfg already matches $quad." -ForegroundColor Green
}

$proj = [IO.File]::ReadAllText("project.godot")
if ($proj -match '(?m)^config/version=') {
    $newProj = $proj -replace '(?m)^(config/version=)".*"', "`$1`"$version`""
} else {
    $newProj = $proj -replace '(?m)^(config/name=.*)$', "`$1`nconfig/version=`"$version`""
}
if ($newProj -ne $proj) {
    [IO.File]::WriteAllText("project.godot", $newProj, (New-Object Text.UTF8Encoding($false)))
    Write-Host "project.godot config/version updated to $version." -ForegroundColor Green
} else {
    Write-Host "project.godot already matches $version." -ForegroundColor Green
}
Write-Host "Commit the changes if any were made."
