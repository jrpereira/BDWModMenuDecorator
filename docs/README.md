# ModCore Settings

Add key-binding pickers, Tap/Hold selectors, presets, and conditional settings
through declarative metadata, with Apply, Reset, and persistence support.
Compatible with Dawnwalker Mod Menu.

Define presentation in your provider's settings manifest. Your mod interprets
the saved values and implements input behavior; Settings supplies the controls.
Less widget plumbing, more actual mod.

## Features

- A `keybind` setting type: one row with key capture, its own Tap/Hold control,
  an optional clear button and the default keys, saved as text (`LeftAlt|Hold`).
- Mapped presets and dirty-setting indicators.
- Navigation tabs, conditional labels, grouped headings, and typography levels.
- Missing-default initialization that preserves existing user values.
- Durable Apply notifications for consumers.

## Requirements and installation

Use UE4SS with Lua 5.4 and Dawnwalker Mod Menu (developed against 1.0.7.1).
ModCoreSettings does not edit DMM's files: it keeps DMM's `main.lua` as
`main.dmm.lua` and starts it through a small launcher, so the first start after
installing either mod may ask for a restart. Install Settings under `Mods/1_ModCore_Settings`, enable it through
UE4SS or your mod manager, and disable the old `AdaptiveModMenu` installation.
Restart after installation or metadata changes.

UE4SSLuaEventBridge is not required for this module. An input provider may
require it separately.

## Add a key-binding control

Keybinds need a page whose storage hooks own its settings (see the developer
guide's Page hooks); DMM's own config writer stores numbers only.

```ini
[Setting.MyAction]
Id = MyAction
Label = My action
Type = keybind
Triggers = Tap|Hold
Default = K
Optional = 1
DefaultControl = IA_MyAction
```

The value is `none` or the key's Unreal name and its trigger, `K|Tap`; number
keys are written as digits (`1|Tap`). Click the key box and press a key to bind
it (Escape cancels), click the trigger to cycle it, and with `Optional = 1` use
the red `X` to clear it. While unbound the row shows an italic `optional`
placeholder and, with `DefaultControl`, the player's keys for that game action.

## Limits

- Modifier chords, Escape bindings, mouse-wheel directions and gamepad capture
  are unsupported for keybinds.
- Dirty-label synchronization runs every 50 ms while the menu scope is usable.
- DMM widget or lifecycle changes can require compatibility updates.

## Logging

ModCoreSettings writes to the UE4SS log at levels TRACE, DEBUG, INFO, WARN, ERROR
and CRITICAL. Only WARN and above are written by default. To see more, create
`Mods/1_ModCore_Settings/log_level.txt` containing one level name, such as `debug`,
and restart the game. An unknown level is reported once and WARN is used.

Other mods can use the same logger by vendoring `Scripts/mc_log.lua` unchanged:
`require('mc_log').new({name='MyMod',path=modRoot..'/log_level.txt'})` returns a
logger with `trace`, `debug`, `info`, `warn`, `error` and `critical`.

## Documentation

- [Developer guide](DEVELOPERS.md): integration contracts and examples.
- [Build guide](BUILD.md): source preparation and tests.
- [Changelog](CHANGELOG.md): changes by version.
