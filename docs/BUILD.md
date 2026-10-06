# Build guide

## Requirements

Use Lua 5.4. MCS is Lua-only; no compilation is needed. Run commands from this
repository's root. Live integration requires the dependencies in the [README](README.md).

## Offline tests

Run every Lua suite from Bash:

```sh
for test in tests/*_test.lua; do
    lua5.4 "$test" || exit 1
done
```

Parser integration tests skip when `DMM_CHOICES_PATH` is unset. To include them,
set this variable before running the same loop:

```sh
export DMM_CHOICES_PATH="/path/to/DawnwalkerModMenu/Scripts/choices.lua"
```

Focused checks include `lua5.4 tests/settings_api_test.lua` for notifications
and `lua5.4 tests/page_hooks_test.lua` for custom storage.

## In-game checks

Restart after launcher installation or metadata changes. Check capture, Escape
cancellation, Apply, Restore, Reset, reopening and restart persistence. Check
slot navigation and the consuming mod's behavior separately.
Fixtures simulate the Unreal UI boundary; they do not establish native widget
behavior or compatibility with a different DMM layout.
