<#
.SYNOPSIS
  Runs the game's own automated test suites INSIDE an exported Windows build (not the editor), to prove the
  exported game behaves like the one in the editor: transformation, day/night, sunlight, Sense, feeding, NPCs,
  input map, traversal, UI, content loading...

.DESCRIPTION
  Exported Godot binaries refuse a scene path on the command line, so this script:
    1. copies the project to a temporary folder (your working copy is never modified),
    2. makes tests/export_selftest.tscn that copy's main scene,
    3. exports it with the "Windows Desktop (self-test)" preset (the game plus the tests),
    4. runs each suite through the exported .exe headlessly and reports the results.
  The real release preset ("Windows Desktop (playtest)") does not contain the tests.
  %APPDATA% is pointed at a throwaway folder while the suites run, so tests can never touch a real
  player's settings or saves in %APPDATA%\VampireGame.

.EXAMPLE
  ./tools/test_exported_build.ps1 -Godot "C:\Godot\Godot_v4.8-dev6_win64_console.exe"
  ./tools/test_exported_build.ps1 -Godot ... -Suites unit_tests,smoke_test
#>
param(
    [string]$Godot = $env:GODOT,
    [string[]]$Suites = @("unit_tests", "smoke_test", "scenario_tests", "feel_tests", "polish_tests", "hunt_tests"),
    [string]$Work = (Join-Path ([IO.Path]::GetTempPath()) "vg-selftest")
)

$ErrorActionPreference = "Stop"
$Suites = @($Suites | ForEach-Object { $_ -split ',' } | Where-Object { $_ })   # powershell -File passes "a,b" as one string
$repo = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
if (-not $Godot -or -not (Test-Path $Godot)) { Write-Error "Pass -Godot <path to the Godot 4.8 console exe> or set `$env:GODOT."; exit 1 }

Write-Host "Copying the project to $Work ..."
if (Test-Path $Work) { Remove-Item $Work -Recurse -Force }
robocopy $repo $Work /MIR /XD .git .godot .claude build dist website launcher supabase docs node_modules __pycache__ /XF *.zip /NFL /NDL /NJH /NJS /NP | Out-Null
if ($LASTEXITCODE -ge 8) { Write-Error "robocopy failed ($LASTEXITCODE)"; exit 1 }

$projFile = Join-Path $Work "project.godot"
$proj = [IO.File]::ReadAllText($projFile)
$proj = $proj -replace '(?m)^run/main_scene=.*$', 'run/main_scene="res://tests/export_selftest.tscn"'
[IO.File]::WriteAllText($projFile, $proj, (New-Object Text.UTF8Encoding($false)))

$out = Join-Path $Work "build\selftest"
New-Item -ItemType Directory -Force $out | Out-Null
$exe = Join-Path $out "VampireGameSelfTest.exe"

# Godot writes warnings to stderr (some tests provoke them on purpose); judge by exit code and log content instead.
$ErrorActionPreference = "Continue"
Write-Host "Importing and exporting ..."
& $Godot --headless --path $Work --import --quit *> (Join-Path $Work "import.log")
# debug template: same packed scripts/resources as release, and it allows the console wrapper's output
& $Godot --headless --path $Work --export-debug "Windows Desktop (self-test)" $exe *> (Join-Path $Work "export.log")
if (-not (Test-Path $exe)) { Write-Error "Self-test export failed; see $Work\export.log"; exit 2 }
Write-Host ("Exported {0} ({1:N0} MB)" -f $exe, ((Get-Item $exe).Length / 1MB))

# Tests write temporary mods etc. into the per-user folder; isolate it from any real player data.
$realAppData = $env:APPDATA
$env:APPDATA = Join-Path $Work "appdata"

# Checks that cannot pass inside an export, by design of the TEST (not the game): the example-mod test copies
# res://examples/example_mod into user://mods byte-for-byte, which only works from the editor (an export stores
# those files remapped). Real mods are plain files in user://mods and are unaffected.
$known = @{ unit_tests = @("mod.cfg manifest is read", "the mod added a new blood type", "the mod replaced the core sunlight profile", "gentle sun roughly doubles") }

$console = Join-Path $out "VampireGameSelfTest.console.exe"
$failed = @()
foreach ($s in $Suites) {
    $log = Join-Path $Work "$s.log"
    $env:VG_SELFTEST_SUITE = $s
    $sw = [Diagnostics.Stopwatch]::StartNew()
    & $console --headless *> $log
    $code = $LASTEXITCODE
    $text = @((Get-Content $log) -replace "\x1b\[[0-9;]*m", "")
    $summary = "$(($text | Select-String -Pattern '=====\s*\d+ checks, \d+ failures' | Select-Object -Last 1).Line)".Trim()

    $errPattern = 'SCRIPT ERROR|Parse Error|Failed to load|Cannot open file|Failed loading'
    $scriptErrors = @($text | Where-Object { $_ -match $errPattern -and $_ -notmatch 'user://mods/example_mod' }).Count

    $fails = @($text | Where-Object { $_ -match '\] FAIL ' })
    $knownList = @($known[$s])
    $expected = @($fails | Where-Object { $f = $_; @($knownList | Where-Object { $_ -and $f.Contains($_) }).Count -gt 0 })
    $unexpected = @($fails | Where-Object { $_ -notin $expected })

    $ok = ($summary -ne "" -and $unexpected.Count -eq 0 -and $scriptErrors -eq 0 -and ($code -eq 0 -or $expected.Count -gt 0))
    $status = if ($ok) { "PASS" } else { "FAIL" }
    Write-Host ("[{0}] {1,-16} {2}  ({3:N0}s, exit {4}, script errors {5})" -f $status, $s, $summary, $sw.Elapsed.TotalSeconds, $code, $scriptErrors) -ForegroundColor $(if ($ok) { "Green" } else { "Red" })
    if ($expected.Count) { Write-Host ("      note: {0} known export-only test limitation(s) ignored (example mod is copied from res://)" -f $expected.Count) -ForegroundColor DarkYellow }
    if (-not $ok) { $failed += $s; Write-Host "      log: $log"; $unexpected | ForEach-Object { Write-Host "      $_" } }
}
Remove-Item Env:VG_SELFTEST_SUITE -ErrorAction SilentlyContinue
$env:APPDATA = $realAppData

if ($failed.Count) { Write-Host "FAILED suites: $($failed -join ', ')" -ForegroundColor Red; exit 1 }
Write-Host "All suites passed inside the exported build." -ForegroundColor Green
