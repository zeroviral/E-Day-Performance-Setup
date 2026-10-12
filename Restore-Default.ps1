$ErrorActionPreference = 'Stop'
$repo = Split-Path -Parent $MyInvocation.MyCommand.Path
$game = Join-Path $env:LOCALAPPDATA 'Microsoft\Gears of War E-Day\Steam\6BE41AB5\Saved\Config\Windows'
$backup = Join-Path $repo 'backups\current-default-20261012-185300'

if (Get-Process -Name 'GoWEDay-Steam','GoWEDay','GoWEDay-WinGDK' -ErrorAction SilentlyContinue) {
    throw 'Close E-Day before restoring settings.'
}
if (-not (Test-Path -LiteralPath $game)) { throw "E-Day config folder not found: $game" }

foreach ($name in @('Engine.ini','GameUserSettings.ini')) {
    $source = Join-Path $backup $name
    if (-not (Test-Path -LiteralPath $source)) { throw "Backup file missing: $source" }
    Copy-Item -LiteralPath $source -Destination (Join-Path $game $name) -Force
}
$scalability = Join-Path $game 'Scalability.ini'
if (Test-Path -LiteralPath $scalability) { Remove-Item -LiteralPath $scalability -Force }
Write-Host 'Restored the backed-up default E-Day settings.' -ForegroundColor Green
