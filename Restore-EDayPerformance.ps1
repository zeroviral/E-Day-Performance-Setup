$ErrorActionPreference = 'Stop'
$repo = Split-Path -Parent $MyInvocation.MyCommand.Path

function Find-EdayConfig {
    $roots = @(
        (Join-Path $env:LOCALAPPDATA 'Microsoft\Gears of War E-Day\Steam'),
        (Join-Path $env:LOCALAPPDATA 'FairlightConcept')
    )
    foreach ($root in $roots) {
        if (-not (Test-Path -LiteralPath $root)) { continue }
        $folders = @((Get-Item -LiteralPath $root)) + @(Get-ChildItem -LiteralPath $root -Directory -Recurse -ErrorAction SilentlyContinue)
        $match = $folders | Where-Object { Test-Path -LiteralPath (Join-Path $_.FullName 'GameUserSettings.ini') } | Select-Object -First 1
        if ($match) { return $match.FullName }
    }
    return $null
}

if (Get-Process -Name 'GoWEDay-Steam','GoWEDay','GoWEDay-WinGDK' -ErrorAction SilentlyContinue) {
    throw 'Close E-Day before restoring settings.'
}
$game = Find-EdayConfig
if (-not $game) { throw 'E-Day settings were not found.' }

$backup = Get-ChildItem -LiteralPath (Join-Path $repo 'backups') -Directory -Filter 'before-install-*' -ErrorAction SilentlyContinue | Sort-Object Name -Descending | Select-Object -First 1
if (-not $backup) { throw 'No installer backup was found in this repository.' }

foreach ($name in @('Engine.ini','GameUserSettings.ini')) {
    $source = Join-Path $backup.FullName $name
    if (-not (Test-Path -LiteralPath $source)) { throw "Backup file missing: $source" }
    $target = Join-Path $game $name
    attrib -R $target 2>$null | Out-Null
    Copy-Item -LiteralPath $source -Destination $target -Force
}
$scalability = Join-Path $game 'Scalability.ini'
$oldScalability = Join-Path $backup.FullName 'Scalability.ini'
if (Test-Path -LiteralPath $oldScalability) {
    attrib -R $scalability 2>$null | Out-Null
    Copy-Item -LiteralPath $oldScalability -Destination $scalability -Force
} elseif (Test-Path -LiteralPath $scalability) {
    Remove-Item -LiteralPath $scalability -Force
}
Write-Host "Restored backup: $($backup.Name)" -ForegroundColor Green
