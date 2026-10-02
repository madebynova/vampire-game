<#
.SYNOPSIS
  Packages the exported Windows game for a GitHub Release, in the exact format the launcher expects:
    dist/VampireGame-Windows-v<VERSION>.zip          (game files at the zip root + a VERSION file)
    dist/VampireGame-Windows-v<VERSION>.zip.sha256   ("<sha256>  <zip name>")

.DESCRIPTION
  Run tools/build_windows.ps1 first (it writes build/windows/). The version comes from the VERSION
  file at the repository root; nothing is typed by hand. The zip is NOT committed to git
  (dist/ and *.zip are git-ignored): it is uploaded to a GitHub Release instead.

  With -Publish the script also creates the GitHub Release (tag v<VERSION>) using the gh CLI.

.EXAMPLE
  ./tools/package_release.ps1                 # just build the zip + checksum
  ./tools/package_release.ps1 -Publish        # ...and create the GitHub Release
#>
param(
    [string]$Build = "build/windows",
    [string]$Out = "dist",
    [string]$NotesFile = "",
    [switch]$Publish
)

$ErrorActionPreference = "Stop"
Set-Location (Join-Path $PSScriptRoot "..")

$version = (Get-Content VERSION -Raw).Trim()
if ($version -notmatch '^\d+\.\d+\.\d+$') { Write-Error "VERSION must look like 0.1.0, found '$version'."; exit 1 }

# the .exe's own version metadata must agree with VERSION (run tools/sync_version.ps1 if not)
$quad = "$version.0"
if ((Get-Content export_presets.cfg -Raw) -notmatch [regex]::Escape("application/file_version=`"$quad`"")) {
    Write-Error "export_presets.cfg does not say $quad. Run ./tools/sync_version.ps1, commit, and rebuild."
    exit 1
}
if (-not (Test-Path (Join-Path $Build "VampireGame.exe"))) {
    Write-Error "$Build/VampireGame.exe not found. Export the game first: ./tools/build_windows.ps1 -Godot <path to Godot 4.8 console exe>"
    exit 1
}

$name = "VampireGame-Windows-v$version.zip"
$zip = Join-Path $Out $name
New-Item -ItemType Directory -Force $Out | Out-Null
Remove-Item $zip, "$zip.sha256" -ErrorAction SilentlyContinue

# stage a copy so the build folder is untouched, and add the VERSION file the launcher verifies
$stage = Join-Path ([IO.Path]::GetTempPath()) ("vg-stage-" + [guid]::NewGuid().ToString("N"))
Copy-Item $Build $stage -Recurse
[IO.File]::WriteAllText((Join-Path $stage "VERSION"), "$version`n", (New-Object Text.UTF8Encoding($false)))
# a short README for players who download the zip by hand (the launcher ignores it)
$readme = (Get-Content (Join-Path $PSScriptRoot "release_readme.txt") -Raw) -replace '\{\{VERSION\}\}', $version
[IO.File]::WriteAllText((Join-Path $stage "README.txt"), ($readme -replace "`r?`n", "`r`n"), (New-Object Text.UTF8Encoding($false)))

# .NET's zip writer (not Compress-Archive, which writes backslash paths on Windows PowerShell 5.1)
Add-Type -AssemblyName System.IO.Compression.FileSystem
[IO.Compression.ZipFile]::CreateFromDirectory((Resolve-Path $stage), (Join-Path (Resolve-Path $Out) $name),
    [IO.Compression.CompressionLevel]::Optimal, $false)
Remove-Item $stage -Recurse -Force

$hash = (Get-FileHash $zip -Algorithm SHA256).Hash.ToLower()
[IO.File]::WriteAllText("$zip.sha256", "$hash  $name`n", (New-Object Text.UTF8Encoding($false)))

$mb = [math]::Round((Get-Item $zip).Length / 1MB, 1)
Write-Host ""
Write-Host "Packaged $name ($mb MB)" -ForegroundColor Green
Write-Host "  sha256 $hash"
Write-Host "  $zip"
Write-Host "  $zip.sha256"

if (-not $Publish) {
    Write-Host ""
    Write-Host "Not published. To create the GitHub Release:  ./tools/package_release.ps1 -Publish"
    Write-Host "(or upload both files by hand to a release tagged v$version on GitHub)"
    exit 0
}

if (-not (Get-Command gh -ErrorAction SilentlyContinue)) { Write-Error "-Publish needs the GitHub CLI (gh), logged in."; exit 1 }
if (git status --porcelain) { Write-Warning "You have uncommitted changes; the release tag will point at the last commit, not these." }
$tag = "v$version"
$ghArgs = @("release", "create", $tag, $zip, "$zip.sha256", "--title", "Vampire Game $version")
if ($NotesFile) { $ghArgs += @("--notes-file", $NotesFile) } else { $ghArgs += "--generate-notes" }
gh @ghArgs
if ($LASTEXITCODE -ne 0) { Write-Error "gh release create failed ($LASTEXITCODE)."; exit $LASTEXITCODE }
Write-Host "Release $tag created. Players with the launcher will see it on their next update check." -ForegroundColor Green
