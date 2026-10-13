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
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\Restore-Default.ps1
```

This restores the backed-up files and removes the installed `Scalability.ini`.

## Portable installer

Run `Install-EDayPerformance.cmd` from this repository. The installer first
reports the currently installed profile, then offers:

1. Maximum Performance: the lowest practical quality profile, with ray tracing
   and Lumen disabled.
2. Enhanced Performance: low geometry/textures/foliage with better lighting,
   reflections, effects, and fog retained.
3. Cancel.

The active profile is highlighted with `[ACTIVE]` and is not offered as a
selection. Selecting the other profile switches to it and creates a fresh
rollback snapshot first. The
installer finds the user's E-Day config folder and changes only `Engine.ini`
and `Scalability.ini`.
`GameUserSettings.ini` is backed up but not overwritten.

If E-Day is still running, the installer waits and polls until the game exits.
Closing or force-quitting E-Day is detected automatically; press Ctrl+C to
cancel the wait.

To restore the saved pre-install configuration, double-click
`Rollback-EDayPerformance.cmd`. If the current files already match the saved
rollback/default configuration, it performs no operation. Otherwise it shows:

1. Roll back
2. Do nothing

The rollback script also reports whether the current profile is Maximum
Performance, Enhanced Performance, Default/no profile, or Custom/unknown.

The PowerShell entrypoint is also available directly:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\Rollback-EDayPerformance.ps1
```
