# Gears of War: E-Day performance setup

This repository contains the new E-Day performance configuration studied from
`Downloads\New eDay perf stuff`.

## Installed files

- `Engine.ini`: aggressive performance engine settings with ray tracing/Lumen
  disabled, reduced shadow/foliage/Nanite cost, streaming tweaks, VSync off,
  and an uncapped frame rate.
- `Scalability.ini`: enhanced-performance quality groups. Lighting, effects,
  reflections, and fog remain above the low profile while ray tracing remains
  disabled.

The live target is:

`%LOCALAPPDATA%\Microsoft\Gears of War E-Day\Steam\6BE41AB5\Saved\Config\Windows`

`GameUserSettings.ini` is intentionally preserved. It contains resolution,
HDR, audio, controls, and account-specific settings.

## Backup

Before installation, the current settings were copied to:

`backups\current-default-20261012-185300`

The backup contains the current `Engine.ini` and `GameUserSettings.ini`.
There was no live `Scalability.ini` before installation.

## Restore

Close E-Day, then run:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\Restore-Default.ps1
```

This restores the backed-up files and removes the installed `Scalability.ini`.
