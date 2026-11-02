# Project Folder Manager

A Windows dashboard for a project's master folder, by [Excel to KML](https://www.exceltokml.com/project-folder-manager):
every numbered module (00 Admin … 99 Archive) with its discipline colour, instant search across
every folder and file, and a side panel to view, copy, move, rename and tidy folders without
leaving the dashboard.

Version 7 is the 6.2 HTML application rebuilt in Flutter with the same look, as a proper
installed program that updates itself. See [CHANGELOG.md](CHANGELOG.md) for what is new.

![The dashboard](docs/screenshots/1-dashboard.png)
![A folder in the side panel](docs/screenshots/2-panel.png)

## Install
Download `ProjectFolderManager-Setup.exe` from the [latest release](https://github.com/Asjad-Mehmood/Project-Folder-Manager/releases/latest)
and open it. It installs for your Windows user only (no administrator rights), to
`%LOCALAPPDATA%\ProjectFolderManager`, with Start menu and desktop shortcuts. Uninstall from
Settings → Apps. Windows 10 or 11, 64-bit.

The first time it opens it brings in a 6.2 copy's settings (`Project_Folder_Manager_config.txt`
on the Desktop, in Downloads, Documents or the Survey Toolkit's folder); otherwise use ⋯ →
*Bring in settings from v6*, or just paste the project folder into ROOT PATH and press SET.

## Use
One row under the banner holds everything; the less-used options sit in its menus.

| | |
|---|---|
| **Project ▾** (top left) | Your projects, to switch between them. Open a project: pick its folder, type or paste its path, or FIND projects on every drive. This project: open the root in Explorer, rename it, take it off the list. |
| **Search, DEEP, Discipline** | Without DEEP the box filters module names; with DEEP it searches every indexed folder and file (every word must be in the name). Esc clears it. |
| **LIST ▾** | Always open the whole tree, hide missing modules, collapse; Scan, Fix names, Rebuild, Refresh (F5). |
| **INDEX ▾** | Index this project, the whole drive or all drives; Stop keeps what was found. The project also indexes itself in the background. |
| **GO TO ▾** | Pinned folders (right-click any folder → Pin), every drive, and the drives strip. |
| **View ▾** | The six layouts, Alt+1 to Alt+6. |
| **⋯** | Bring in v6 settings, look for an update, keyboard shortcuts, about. |
| **Modules** | Click a name or VIEW for the panel, OPEN or double-click for Explorer, the arrow for its sub-folders, the coloured chip for its discipline. Right-click for more. |
| **Panel** | Back, forward, up, filter, Show ▾ and Sort ▾ on top. Below, what you can do now: New folder, LIST / EDIT and Explorer; or, once something is selected, Copy, Cut, Rename and Delete. Paste appears when something is copied. Drag items onto any folder. UNDO (Ctrl+Z). |
| **LIST / EDIT** | The names in a box to copy, or to edit and rename many at once, with a preview and quick tools (find and replace, add text, number, case). |

Settings live in `%APPDATA%\Excel to KML\Project Folder Manager\settings.json`, the index in
`%LOCALAPPDATA%\Excel to KML\Project Folder Manager\index`.

## Releases
A release is made by pushing a tag, never by hand:

1. Write `docs/releases/v7.0.1.md` (the release's description) and add a line to `CHANGELOG.md`.
2. Merge to `main`, then tag: `git tag v7.0.1 && git push origin v7.0.1`.
3. [`release.yml`](.github/workflows/release.yml) runs the tests, builds the program and the
   installer on Windows, installs and checks that very installer (`tool/windows_check.ps1`),
   writes `latest.json` (version and SHA-256) and publishes both files as the latest release; a
   last job downloads them the way installed copies do and checks the SHA-256.

Installed copies read `latest.json` from the latest release a few seconds after opening; when the
version is higher they offer the update, download the installer, check its SHA-256 and run it
silently, and the new version opens by itself.

## Develop
Flutter 3.47.7. `flutter test` runs everything that doesn't need Windows; [`check.yml`](.github/workflows/check.yml)
also builds, installs, self-checks (`ProjectFolderManager.exe --self-check <folder> <report.json>`
does the real jobs on a real Windows), opens and uninstalls the program on every push, and keeps
the test installer and screenshots under the run's Artifacts.

```
flutter pub get
dart format lib test            # page width 120
flutter analyze
flutter test
flutter test test/ui_test.dart --dart-define=SHOTS=true   # pictures in docs/screenshots
```

| | |
|---|---|
| `lib/src/core` | The rules, without Flutter: settings and the v6.2 file, modules, the index and its background walk, copy / move / rename / undo, LIST / EDIT, FIND |
| `lib/src/state` | `AppModel` (everything the window shows and does) and `Store` (files in AppData) |
| `lib/src/platform` | Windows: drives, Recycle Bin, opening files and folders (win32), folder picker |
| `lib/src/ui` | The window, in v6.2's colours (`theme.dart`) |
| `lib/src/update` | Self-update |
| `installer`, `tool`, `.github/workflows` | NSIS installer, the Windows check, CI and releases |

Copyright © 2026 Asjad Mehmood.
