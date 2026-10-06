# ModCore Settings

ModCore Settings (MCS) adds keybind editors, navigation, presets and contributed
pages to Dawnwalker Mod Menu (DMM). Your mod defines settings; DMM manages pending
edits and Apply; your mod applies the saved values to gameplay.

## Choose the right module

| Module | Responsibility |
| --- | --- |
| ModCoreSettings (MCS) | Menu controls, pending edits and Apply |
| ModCoreControls (MCC) | Input bindings and quickslot actions |
| ModCoreTemplates (MCT) | Visual templates, settings and object lifecycle |

Start with the [developer guide](DEVELOPERS.md) to add a numeric setting and
receive Apply notifications. Keybinds need custom storage hooks; they cannot use
DMM's numeric INI writer directly.

## Requirements and installation

Use Dawnwalker, UE4SS with Lua 5.4, and DMM 1.0.7.1 (the declared minimum).
Install and enable MCS under `Mods/1_ModCore_Settings`; disable the old
`AdaptiveModMenu` installation. MCS itself does not require UE4SSLuaEventBridge.

MCS renames DMM's `Scripts/main.lua` to `main.dmm.lua` and installs a launcher
as `main.lua`. The launcher loads MCS inside DMM's Lua state, then runs DMM's
original entry point. If DMM already started, restart when
`DMM_RESTART_REQUIRED` is reported. Restart after metadata changes too.

## Behavior and limits

- Numeric settings use ordinary DMM storage; keybind values are text such as
  `K|Tap` and need a page whose hooks save them.
- Navigation and read-only rows are omitted from persistence and Apply events.
- Apply notifications contain numeric values; consumers reload text bindings.
- Key capture excludes modifier chords, Escape, wheel directions and gamepads.
- MCS depends on DMM's widget layout; offline tests do not prove live UI compatibility.

## Logging

Logs appear in `UE4SS.log`. The default level is WARN. For more detail, put
`debug` in `Mods/1_ModCore_Settings/log_level.txt` and restart.

## Documentation

- [Developer guide](DEVELOPERS.md): first setting, Apply and keybinds.
- [Integration reference](REFERENCE.md): metadata, pages, slots and migrations.
- [Build guide](BUILD.md): offline tests and in-game checks.
- [Changelog](CHANGELOG.md): version history.
