# ModCore Settings

Add key-binding pickers, Tap/Hold selectors, presets, and conditional settings
through declarative metadata, with Apply, Reset, and persistence support.
Compatible with Dawnwalker Mod Menu.

Define presentation in your provider's settings manifest. Your mod interprets
the saved values and implements input behavior; Settings supplies the controls.
Less widget plumbing, more actual mod.

## Features

- Key capture across standard keyboard, keypad, punctuation, media, browser,
  and mouse buttons, with distinct left/right modifiers and Escape cancellation.
- Paired key/mode controls, mapped presets, and dirty-setting indicators.
- Navigation tabs, conditional labels, grouped headings, and typography levels.
- Missing-default initialization that preserves existing user values.
- Durable Apply notifications for consumers.

## Requirements and installation

Use UE4SS with Lua 5.4 and Dawnwalker Mod Menu. The lifecycle adapter targets
DMM 1.0.7. Install Settings under `Mods/_ModCore_1_Settings`, enable it through
UE4SS or your mod manager, and disable the old `AdaptiveModMenu` installation.
Restart after installation or metadata changes.

UE4SSLuaEventBridge is not required for this module. An input provider may
require it separately.

## Add a key-binding control

In your mod's `mod_settings.ini`, define an integer setting and add `mcType = keybind`:

```ini
[Setting.MyAction]
Id = MyAction
Type = integer
mcType = keybind
Label = My action
Group = Controls
ConfigFile = config.ini
ConfigSection = Bindings
ConfigKey = MyAction
Minimum = 0
Maximum = 254
Step = 1
Default = 75
```

The stored value is a Windows virtual-key code. In this example, `75` means K; `0` means unbound.
Add `mcOptional = 1` when zero is a valid choice. An unbound row shows `(none)`
with a dimmed `Optional` marker. Binding a key reveals a separate red `X` clear
control and restores the Tap/Hold control; clearing the key returns to the
optional placeholder through DMM's pending state.
Add `mcDefaultControl = IA_ActionId` when zero should inherit a standard game
control. The inherited key appears in parentheses with `Default`; an optional
row without that field shows `(none)` with `Optional`. A custom key retains the
red `X` and its Tap/Hold control.

## Limits

- Key values are Windows virtual-key codes; modifier chords, Escape bindings,
  mouse-wheel directions, and gamepad capture are unsupported.
- Active control synchronization runs every 50 ms while the menu scope is usable.
- DMM widget or lifecycle changes can require compatibility updates.

## Documentation

- [Developer guide](docs/DEVELOPERS.md): integration contracts and examples.
- [Build guide](docs/BUILD.md): source preparation and tests.
- [Changelog](CHANGELOG.md): changes by version.
