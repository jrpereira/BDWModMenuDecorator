# Build guide

- [Requirements](#requirements)
- [Implementation](#implementation)
- [Offline tests](#offline-tests)
- [Validation limits](#validation-limits)

## Requirements

- Lua 5.4 for source checks and offline tests.
- Python 3 for the documented tooling.
- A compatible UE4SS/Dawnwalker installation for native integration checks.

These are Lua modules; there is no native compilation step in this repository.
Run the commands below from the repository root.

## Implementation

DMM owns provider parsing, pending edits, Apply, Reset, and persistence.
Settings decorates those parsed rows through the DMM extension and lifecycle
callbacks. Decoration state belongs to each row; temporary Lua bindings belong
to the active menu scope. Closing the menu revokes deferred work.

The DMM 1.0.7 bootstrap can patch its lifecycle callbacks; restart after that
change. Compatibility depends on the supported widget layout. A passing Lua
fixture does not certify a different DMM version.

## Offline tests

The navigation integration test uses the actual Dawnwalker Mod Menu parser.
Set `DMM_CHOICES_PATH` to that installation's choices script, then run the suites
from Bash:

```sh
export DMM_CHOICES_PATH="/path/to/ue4ss/Mods/DawnwalkerModMenu/Scripts/choices.lua"
for test in tests/*_test.lua; do
    lua "$test" || exit 1
done
```

Use a Lua 5.4 executable on your PATH. Individual suites can also be run as
`lua tests/<suite>_test.lua` from the repository root.

## Validation limits

Fixtures cover schema metadata, presets, capture, dirty labels, persistence
adapters, and menu scope changes. They simulate the Unreal UI boundary.
Check actual key capture, Apply, Reset, page reconstruction, and save/reload
against DMM 1.0.7. Test input behavior in the consuming mod separately.
