# Developer guide

ModCore Settings (MCS) extends Dawnwalker Mod Menu (DMM). Your mod declares
settings and implements their behavior. DMM manages pending edits and Apply;
MCS adds presentation, generated pages and custom field types.

A **provider** is a page owner identified by its `[Mod] Id`. Keep provider IDs,
setting IDs and config keys stable after users save settings.

## Add your first setting

Install the dependencies in the [README](README.md). In your mod folder, create
`mod_settings.ini` with this complete numeric setting:

```ini
[Mod]
Id=ExampleMod
Name=Example Mod

[Setting.Scale]
Id=Scale
Label=Scale
Type=integer
Minimum=50
Maximum=150
Step=10
Default=100
ConfigFile=config.ini
ConfigSection=General
ConfigKey=Scale
```

Restart and open **Example Mod** in DMM. Change Scale to `120` and Apply. The
mod's `config.ini` should then contain:

```ini
[General]
Scale=120
```

MCS initializes missing numeric defaults when the page opens. It preserves
existing values and unrelated content, and reports invalid data. Parent directories
must already exist. Your gameplay code still needs startup defaults because it
can run before the player opens this page.

## React to Apply

Copy `Scripts/settings_api.lua` unchanged into your mod's `Scripts` folder.
In `Scripts/main.lua`, subscribe to your provider ID:

```lua
local Settings = require('settings_api')
local scale = 100 -- replace with your saved config value at startup
local unsubscribe = Settings.subscribe('ExampleMod', function(event)
    scale = event.values.Scale
    -- Apply scale to your feature; dispatch UObject work to the game thread.
end)
-- Call unsubscribe() when your mod shuts down.
```

The callback runs after a successful save. It receives `providerId`, `revision`,
`values`, and `changes` (`{old=...,new=...}` per changed ID). Events contain numeric
settings only and do not replay startup values. Use one subscriber per provider;
a second subscription in the same client replaces its callback. See the
[notification contract](REFERENCE.md#apply-notifications) for ownership details.

## Add a keybind

A keybind requires a [generated page with storage hooks](REFERENCE.md#page-hooks),
because DMM's ordinary INI writer accepts numbers only. This is a manifest
fragment for such a page:

```ini
[Setting.MyAction]
Id=MyAction
Label=My action
Type=keybind
Triggers=Tap|Hold
Default=K|Tap
Optional=1
```

The stored value is `none` or `<FKey>|<trigger>`: `K|Tap`, `LeftAlt|Hold`, or
`1|Tap`. A bare default key takes the first listed trigger. `Optional=1` adds a
clear button; `DefaultControl=IA_Name` displays the player's native keys while
unbound. Your input code implements any inheritance and Tap/Hold timing.

Capture changes DMM's pending value. Apply calls your storage hook with all
stored values and changed IDs; return the saved values only after persistence
succeeds. Raise an error to reject the Apply. Navigation/read-only rows are
excluded. Numeric Apply events omit text keybinds, so reload your config when
handling the event, as MCC does.

Escape cancels capture. Modifier chords, Escape bindings, wheel directions and
gamepad capture are unsupported.

## Add presentation only when needed

| Need | Metadata | Example |
| --- | --- | --- |
| Navigation picker | `mcNavigation=1` | Switch visible groups without saving a choice |
| Tab choices | `mcType=tab` | Two to eight picker choices |
| Compact cycling picker | `mcType=cycle` | Click to advance to the next choice |
| Conditional rows | `VisibleWhen` / `VisibleValues` | Show a row when an earlier picker equals `1` |
| Shared page area | `mcSlot` | Let MCT contribute visual settings to Controls |

See the [integration reference](REFERENCE.md) for complete metadata, generated
pages, links, presets and migration contracts. Use MCS metadata and the two
vendored clients; internal UI modules are not a provider API.

## Check your integration

Use the [build guide](BUILD.md) for offline checks. In game, test Apply, Restore,
Reset, reopening, restart persistence, and your feature's resulting behavior.
A visible key label alone does not prove the value was saved or activated.
