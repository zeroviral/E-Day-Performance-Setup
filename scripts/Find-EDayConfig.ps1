# Lists every E-Day config file on this PC so the real Xbox app settings folder can be identified.
$ErrorActionPreference = 'SilentlyContinue'
$repo = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$report = Join-Path $repo 'EDay-Config-Report.txt'

$roots = @(
    $env:LOCALAPPDATA,
    $env:APPDATA,
    [Environment]::GetFolderPath('MyDocuments'),
    (Join-Path $env:USERPROFILE 'Saved Games')
)
foreach ($drive in Get-PSDrive -PSProvider FileSystem) {
    $xbox = Join-Path $drive.Root 'XboxGames'
    if (Test-Path -LiteralPath $xbox) { $roots += $xbox }
}

$names = @('GameUserSettings.ini','Engine.ini','Scalability.ini')
$results = @()
foreach ($root in ($roots | Where-Object { $_ -and (Test-Path -LiteralPath $_) } | Select-Object -Unique)) {
    Write-Host "Searching $root ..." -ForegroundColor Cyan
    $results += Get-ChildItem -LiteralPath $root -Recurse -File -Force -ErrorAction SilentlyContinue |
        Where-Object { $names -contains $_.Name -and $_.FullName -match 'Fairlight|E-Day|EDay|Gears|GoW' }
}

$lines = @("E-Day config report  $(Get-Date)", '')
if ($results.Count -eq 0) {
    $lines += 'No E-Day config files were found.'
} else {
    $lines += $results | Sort-Object LastWriteTime -Descending |
        ForEach-Object { '{0:yyyy-MM-dd HH:mm}  {1}' -f $_.LastWriteTime, $_.FullName }
}
$lines += ''
$lines += 'E-Day processes running now:'
$procs = Get-Process | Where-Object { $_.ProcessName -match 'GoW|EDay|Gears' }
if ($procs) { $lines += $procs | ForEach-Object { "  $($_.ProcessName)  $($_.Path)" } } else { $lines += '  (none)' }

$lines | Set-Content -LiteralPath $report -Encoding UTF8
Write-Host ''
$lines | ForEach-Object { Write-Host $_ }
Write-Host ''
Write-Host "Saved to: $report" -ForegroundColor Green
Start-Process notepad.exe $report
