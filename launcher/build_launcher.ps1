<#
.SYNOPSIS
  Builds the launcher into a single Windows program: launcher/dist/VampireGameLauncher-v<version>.exe

.DESCRIPTION
  The launcher itself needs only Python 3.12+ (standard library). Turning it into an .exe needs
  PyInstaller:  python -m pip install pyinstaller
  The version comes from launcher/VERSION (the launcher's single source of truth) and is bundled into the exe.

  NOTE: this script has not been run on a machine with PyInstaller yet - treat the first build as its test,
  and run the resulting exe once before you publish it.

.EXAMPLE
  ./launcher/build_launcher.ps1
#>
$ErrorActionPreference = "Stop"
Set-Location $PSScriptRoot

$version = (Get-Content VERSION -Raw).Trim()
if ($version -notmatch '^\d+\.\d+\.\d+$') { Write-Error "launcher/VERSION must look like 0.1.0, found '$version'."; exit 1 }

python -m PyInstaller --version *> $null
if ($LASTEXITCODE -ne 0) { Write-Error "PyInstaller is not installed. Run: python -m pip install pyinstaller"; exit 1 }

Write-Host "Running the launcher tests first..."
python -m unittest discover -s tests -t .
if ($LASTEXITCODE -ne 0) { Write-Error "Tests failed; not building."; exit 1 }

python -m PyInstaller --noconfirm --clean --onefile --windowed --name VampireGameLauncher `
    --add-data "VERSION;." --distpath dist --workpath build --specpath build run_launcher.py
if ($LASTEXITCODE -ne 0) { Write-Error "PyInstaller failed."; exit 1 }

$final = "dist/VampireGameLauncher-v$version.exe"
Move-Item "dist/VampireGameLauncher.exe" $final -Force
$hash = (Get-FileHash $final -Algorithm SHA256).Hash.ToLower()
[IO.File]::WriteAllText("$final.sha256", "$hash  VampireGameLauncher-v$version.exe`n", (New-Object Text.UTF8Encoding($false)))
Write-Host ""
Write-Host "Built launcher/$final" -ForegroundColor Green
Write-Host "  sha256 $hash"
Write-Host "Publish it as a GitHub Release tagged launcher-v$version (see docs/RELEASING.md)."
