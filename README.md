# Gears of War: E-Day performance setup (Xbox app / PC Game Pass)

This repository contains the new E-Day performance configuration studied from
`Downloads\New eDay perf stuff`.

## Installed files

- `Engine.ini`: aggressive performance engine settings with ray tracing/Lumen
  disabled, reduced shadow/foliage/Nanite cost, streaming tweaks, VSync off,
  and an uncapped frame rate.
- `Scalability.ini`: enhanced-performance quality groups. Lighting, effects,
  reflections, and fog remain above the low profile while ray tracing remains
  disabled.

This version targets the Xbox app / PC Game Pass (WinGDK) build. The live
target is:

`%LOCALAPPDATA%\FairlightConcept\Saved\Config\WinGDK`

If that folder is missing, the scripts search `%LOCALAPPDATA%\FairlightConcept`
and `%LOCALAPPDATA%\Microsoft\Gears of War E-Day` for a `WinGDK` config folder
containing `GameUserSettings.ini`. Steam folders are ignored. Launch E-Day from
the Xbox app at least once before running the installer so the folder exists.

`GameUserSettings.ini` is intentionally preserved. It contains resolution,
HDR, audio, controls, and account-specific settings.

## Rollback snapshot

The installer saves the user's default settings once in:

`rollback\`

It does not create a new backup when switching between profiles, so repeated
installs do not grow the repository. The snapshot contains the current
`Engine.ini` and `GameUserSettings.ini`, plus either the original
`Scalability.ini` or a marker stating that it was absent.

## Rollback

Close E-Day, then double-click `Rollback-EDayPerformance.cmd`. This restores
the saved default files and removes the installed `Scalability.ini` when the
default snapshot did not have one.

## Portable installer

Run `Install-EDayPerformance.cmd` from this repository. The installer first
reports the currently installed profile, then offers:

1. Maximum Performance: the lowest practical quality profile, with ray tracing
   and Lumen disabled.
2. Enhanced Performance: low geometry/textures/foliage with better lighting,
   reflections, effects, and fog retained.
3. Cancel.

The active profile is highlighted with `[ACTIVE]` and is not offered as a
selection. Selecting the other profile switches to it and reuses the existing
rollback snapshot. The
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
