# Developer guide

- [Requirements and installation](#requirements-and-installation)
- [Minimal integration](#minimal-integration)
- [Pairing a mode picker](#pairing-a-mode-picker)
- [Apply and persistence contract](#apply-and-persistence-contract)
- [Discovery and layout constraints](#discovery-and-layout-constraints)
- [Logging and integration checks](#logging-and-integration-checks)
- [Known limitation: Delete](#known-limitation-delete)
- [Menu scope and row ownership](#menu-scope-and-row-ownership)
- [Menu pages](#menu-pages)
- [Apply notifications](#apply-notifications)
- [Presentation metadata](#presentation-metadata)
- [Migrating missing defaults](#migrating-missing-defaults)
- [Fixed mode labels](#fixed-mode-labels)

ModCoreSettings replaces explicitly marked Dawnwalker Mod Menu (DMM) numeric key
controls with key-capture controls. An optional mode picker is displayed on the same
row. Your mod continues to own its configuration and gameplay behavior; DMM owns
pending edits, dirty state, Apply, saving, Reset, and Restore.

The decorator does **not** register gameplay bindings, implement Tap/Hold timing,
or depend on UE4SSLuaEventBridge. Input providers can use the bridge separately. Choosing a key changes a setting. The menu can name a spell; it cannot cast it.

## Requirements and installation

The current implementation targets Dawnwalker with UE4SS/Lua 5.4 and the tested DMM
widget layout. It is not a generic settings framework for every Unreal game or DMM
version. Install DMM and ModCoreSettings as separate UE4SS mods. Do not copy DMM
source into your mod. Install Settings under `_ModCore_1_Settings`.
Remove the old `AdaptiveModMenu` mod folder before starting the game. ModCoreSettings reads
`mc*` manifest fields only. Producers must emit this prefix; no legacy metadata translation is installed. Saved setting names and values are unchanged.

Your provider folder needs `mod_settings.ini` and its own configuration file, for example:

```text
Mods/
  DawnwalkerModMenu/
  _ModCore_1_Settings/
    enabled.txt
    Scripts/main.lua
  ExampleMod/
    enabled.txt
    mod_settings.ini
    config.ini
    Scripts/main.lua
```

Immediately before DMM opens a provider model, ModCoreSettings uses DMM's parsed provider
settings to initialize its declared configuration. It creates a missing INI or
adds missing assignments while preserving existing values, comments and unrelated
keys. This applies to every ordinary provider opened by DMM, whether or not its
settings request decoration. DMM test-only providers remain memory-only.

DMM's installed schema parser validates the schema and the resulting configuration
before saving. Invalid or ambiguous input is reported without substituting defaults
for user values. DMM settings are numeric: `0` is retained as off/unbound; a literal
`false` or empty numeric value is preserved but rejected by DMM validation.
One schema-declared INI path per provider is supported, including existing nested
directories; initialization does not create directories. Existing complete files
are not rewritten. Interrupted configuration transactions retain recovery files
and are reported for review rather than overwritten on the next provider open.

Initialization completes synchronously before DMM reads configuration for the
provider's settings page. It adds no polling or gameplay work. Your mod must still
handle its own startup defaults because menu initialization can occur later.
Restart after adding/changing manifest metadata; this is
not a manifest or configuration hot-reload API. On supported DMM 1.0.7 installs,
ModCoreSettings transactionally adds the lifecycle callback API to DMM's Lua files and keeps
verified `.amm-1.0.7.bak` baselines for rollback. A restart activates that patch.

## Minimal integration

### Dirty-label presentation

While the settings menu is open, ModCoreSettings moves DMM's value-side dirty marker to the
left of the setting label and italicizes the label. A separate, non-interactive
TextBlock occupies the existing left gutter; the label text and layout stay unchanged. It uses an italic face from
the existing font when available, otherwise Slate font skew. Clean values restore
the original face and skew. This covers recognized sliders, pickers and toggles,
including settings without key decorations. Key and paired mode changes share
the visible key row's indicator. Schema-declared literal stars are not removed.

Dirty presentation observes only already-bound rows during ModCoreSettings's existing
menu-scoped update. Presentation state is stored in a collapsed child owned by the
row. No process-wide text hook, additional polling loop or configuration write is
used for styling.

Mapped-preset suppression happens in DMM's pending model before its row text is
rendered. The decorator state only mirrors the resulting clean or dirty text; it
does not expose a second value-mutation API or write settings through UI controls.

### Mapped presets

ModCoreSettings expands mapped presets inside DMM's own pending model. Declare a picker with
`CustomValue`, a pipe-separated `MappedPresetTargets` list of setting IDs, and
semicolon-separated `MappedPresetValues` entries. Each entry has the form
`presetValue:targetValue|targetValue`, in target order. For example:

```ini
MappedPresetTargets=Ability1|Ability1Mode
MappedPresetValues=1:82|0;2:49|1
CustomValue=0
```

The picker must declare values `0|1|2` in this example. Every non-Custom value
needs a complete mapping. Targets may be sliders, pickers or toggles; values must
fit their declared ranges, steps or choices. Overlapping and nested presets are
rejected, including overlap with DMM's ordinary `PresetTargets`.

Selecting a preset synchronously updates all targets before DMM refreshes or
applies. Preset-derived target changes hide their dirty indicators while retaining
the actual pending/committed differences. A manual target edit selects Custom and
marks only that target against the selected preset's visual baseline. Returning
all targets to a named preset selects it automatically. Custom cannot be chosen
directly. Apply and Restore clear the visual baseline.
Apply and Restore remain DMM operations. Opening an inconsistent saved preset
preserves its keys and changes the pending picker to Custom.

Dawnwalker Mod Menu loads `Scripts/dmm_extension.lua` from enabled direct mods at
startup and passes its choices, controls and pages modules through extension API
version 1. ModCoreSettings installs its mapped-preset, presentation and migration wrappers in
that Lua state. No native DLL, additional runtime or gameplay timer is used. The
startup bootstrap installs the version-checked DMM lifecycle patch described above.
Install both mods before starting the game; loading ModCoreSettings after DMM has started does
not retrofit the existing page. Restart after installing, removing or updating an
extension.

Offline tests exercise the Lua extension and UI modules. Validate native widget
behavior against the supported DMM version in-game.

### Key controls

Copy the complete [example manifest](../examples/ExampleMod/mod_settings.ini) into
your provider and adapt its IDs, labels, config paths and defaults. The matching
[example config](../examples/ExampleMod/config.example.ini) starts with Q + Tap.
For that example, copy it to `config.ini` in the provider folder.

The key row's essential fields are:

```ini
[Setting.Interact]
Id = Interact
Type = integer
mcType = keybind
Label = Interact key
Group = Controls
ConfigFile = config.ini
ConfigSection = Bindings
ConfigKey = Interact
Minimum = 0
Maximum = 254
Step = 1
Default = 81
```

The stored number is a Windows virtual-key code, not an Unreal FKey name or scan
code. `81` is Q; `0` means unbound. Use the 0–254 range and integer steps for this
representation. The registry accepts numeric `integer` or `slider` rows with valid
Minimum/Maximum, but capture only supports the mappings in
[key_codes.lua](../Scripts/key_codes.lua). Numeric range membership alone does not
make every key supported. Escape is reserved for cancellation. Left/right Shift,
Control, Alt and Windows keys are stored as distinct virtual-key values. Modifier
chords and gamepad capture are disabled. Unsupported captured keys are rejected rather than
silently substituted.

## Pairing a mode picker

Add a picker that declares the key setting through `Pair`:

```ini
[Setting.InteractMode]
Id = InteractMode
Type = picker
Pair = Interact
Label = Interact
Group = Controls
ConfigFile = config.ini
ConfigSection = Bindings
ConfigKey = InteractMode
PresetValues = 0|1
PresetLabels = Tap|Hold
Default = 0
```

The picker that declares `Pair` owns the composite row and supplies its visible
label. The target key setting contributes only its key control. If DMM visibility
hides the key setting, the key control disappears while the picker retains its
normal full-width row. Pairing is ID-based and does not depend on row order.
The first two declared modes share one control: its label shows the selected mode,
and each click switches to the other declared value. An optional third `-1`
Default mode remains a separate control; clicking the shared control from Default
selects the first mode. `Pair` renders this mode control without `mcType=tab`.

A picker without explicit decoration remains a stock control. No mode row is
required for a standalone keybind. Use matching ordered `PresetValues` and
`PresetLabels`; the provider defines their meaning. Tap and Hold are example labels,
not behavior supplied by the decorator. Your provider must interpret `InteractMode`
and apply it to its input implementation.

## Apply and persistence contract

1. Native capture updates the selector's reflected `SelectedKey` property.
2. The decorator converts the FKey name to the stored numeric representation and
   writes the stock numeric slider once.
3. DMM ingests that change, marks it dirty, and enables its normal Apply action.
4. The decorator mirrors the stock value and DMM's dirty label, without waiting for acknowledgement or retrying submission.
5. DMM saves on Apply; your provider must reload the saved config and update gameplay.

Do not save directly from the decorator or bypass DMM's pending state. Escape
cancels capture and should preserve both the previous key and any earlier unsaved
changes. A key write is submitted once: Restore/Reset must be able to
supersede it. Seeing a new key label alone is not proof that DMM ingested or saved it.

## Discovery and layout constraints

DMM discovers and parses providers. ModCoreSettings's parser extension enriches those exact
in-memory setting objects with decoration metadata, and DMM places the provider ID,
setting ID, kind and object reference on each row-owned marker during construction.
Give every provider a unique `[Mod] Id` and every setting an explicit unique `Id`.
DMM's duplicate-provider policy remains authoritative.

The ModCore browser groups `ModCoreControls`, `ModCoreSettings`, and providers whose
IDs start with `ModCoreTemplates.module.`. Other providers can opt into the module
group by setting `mcBrowserGroup='module'` on their in-memory DMM provider object.
Unmarked providers keep their normal DMM position.

ModCoreSettings accepts a page only when its row markers identify one provider and contain
unique setting IDs whose kinds match their DMM setting objects. It does not infer
identity from row order or localized labels. DMM lifecycle callbacks provide the
completed provider ScrollBox after construction and after visibility refreshes.
Changes to DMM's marker or widget hierarchy can still require compatibility work.

Decoration uses proxy widgets while retaining stock controls as backing state.
UObject work is dispatched to the game thread. Do not import this mod's internal Lua
modules from a provider: decoration is configured through manifest metadata. The supported
[Apply notification API](#apply-notifications) is a separate integration surface.

## Logging and integration checks

`UE4SS.log` contains one ready message plus actionable failures under `[ModCoreSettings]`.
Verbose construction, binding and capture traces are removed; there is no debug-mode toggle.
Discovery runs once per coalesced DMM provider callback, after DMM completes row
construction. The callback normally supplies the exact provider ScrollBox; one
bounded selected-tree traversal remains as recovery when that selection is unavailable.
There is no periodic tree scan or timed discovery retry. A later provider callback
rebuilds scope after page reconstruction or visibility changes.
Control synchronization remains at 50 ms within that scope and stops when no usable controls remain, using fresh child-path traversal
from the current host root rather than repeated global lookups for each control. Each eligible update performs exact owner/host lookups; there is no global widget enumeration
or permanently running discovery timer. Closing/loading revokes deferred work;
obsolete queued callbacks drain without UObject access or rescheduling.
Picker clicks use one UE4SS left-mouse callback that queues primitive Lua state. Each menu-scoped game-thread update samples the hovered owned proxy button. A queued press is delivered only if that same button remains hovered at the next update; movement to another target discards it instead of changing the wrong setting. Pointer movement away and back entirely between updates cannot be observed, and a click during that interval can still be attributed to the sampled button.
No UObject is accessed by the key callback and no press-state sampling is used. Click routing and lifecycle integration still need
in-game validation; unavailable pointer input leaves the stock mode row available.

For your integration, test a key-only change, a mode-only change,
the dirty marker and Apply, persistence after reopening/restarting, clean and
already-dirty Escape cancellation, Reset/Restore, unrelated settings pages, and
the provider's actual gameplay behavior after Apply. Test transparent surfaces and
longest mode labels in the real UI. Automated mocks cannot validate those native paths.

## Optional key bindings

Set `mcOptional=1` on an `mcType=keybind` integer setting when zero represents a
valid default choice. Without `mcDefaultControl`, zero renders `(none)` with an
`Optional` marker. Set `mcDefaultControl=IA_ActionId` to resolve zero from that
standard game control; it renders the inherited key in parentheses with a
`Default` marker. A custom nonzero key shows the red `X` and its mode; clicking
the `X` writes zero to the stock DMM slider, so Apply, Reset, dirty state, and
persistence remain owned by DMM.


## Menu scope and row ownership

Decoration requires the exact visible, active DMM host supplied by its lifecycle
callback. Every update resolves that host and validates its address, viewport,
activation, visibility and WidgetTree identity. DMM's close callback retires the
scope; the next provider callback can create a new one. A lifecycle callback
exception cancels the current scope. Actionable errors include the setting and
original failure reason; repeated failures disable only that control until the next
page event.

A collapsed TextBlock inside the key overlay stores versioned scalar control state.
Every created widget uses the row's WidgetTree as outer and attaches beneath its
surface. Row presence determines decoration presence. Reopening an intact page
adopts the existing subtree and reconnects its temporary input routing. A new row
has no marker and receives a new decoration. No persistent host/row decorated
registry or partial-child repair scan exists.

Lua bindings and primitive traversal routes are temporary, discarded on scope changes. They support active input updates and never determine whether a row has been decorated. Capture/presentation state is compared with the last successfully saved scalars in the temporary binding; unchanged state is neither serialized nor written. Persistent state remains on the row. Pending click delivery is transient and cleared on scope changes. Construction failures roll back mutations; repeated update failures stop that control until the next page event rather than dismantling its decoration. Attached widgets leave the page with their row; final UObject reclamation follows Unreal garbage collection.

## Menu pages

ModCoreSettings is the only DMM integration. Other mods never install a DMM
extension or call DMM directly; to add generated menu pages they publish data
through `Scripts/menu_contributions.lua`. Vendor that file unchanged and publish
from the ordinary mod state:

```lua
local Menu=require('menu_contributions')
local pages=Menu.publisher(ModRef,{id='ExampleMod',directory='<absolute writable folder>'})
pages:publish({pages={
    {id='ExampleMod',name='Example',attach='ExampleMod'},
    {id='ExampleMod.speed',name='Speed',under='ExampleMod',
        manifest=settingsManifest,configDirectory='<absolute folder for ConfigFile>'},
}})
-- pages:withdraw() removes them; Menu.validate(id,{pages=...}) checks offline.
```

Page fields: `id` (the contributor id or `<id>.*`; it is the `providerId` in Apply
notifications), `name`, optional `author`, `version`, `description`, `visible`,
`manifest` with `configDirectory`, and at most one of `under` (an earlier page of
the same contributor) or `attach` (a mod folder name). `group='module'` puts the
page in the ModCore browser group.

Placement on every menu build:

- `under`: after the parent and its earlier children, indented.
- `attach`: matched case-insensitively against a mod's name, id or detected
  folder. A detected placeholder without settings is hidden while the page is
  shown. Otherwise the page follows that mod, indented, unless it is a module
  group page. A name matching several mods rejects the contributor. A page with
  `visible=false` still hides its detected placeholder.
- Otherwise: sorted by name with other mods, so a page that returns does not move.

Contributed pages need no `mod_settings.ini` on disk; ModCoreSettings keeps
their manifest in memory and only uses `configDirectory` to resolve `ConfigFile`.

Publishing writes a new generation of files and then switches the contributor's
shared variable; the menu keeps showing the previous generation until then.
`publish` rejects structurally invalid pages. Settings manifests are parsed when
the menu builds; any failure (manifest, id collision, ambiguous `attach`) skips
that contributor's pages and is logged once. The rest of the menu is unaffected.

### Slot rows

A page can reserve a place for another mod's settings. Mark a read-only row as
the slot:

```ini
[Setting.MCC_Visuals_Pending]
Id=MCC_Visuals_Pending
Type=picker
Label=Quickslot templates
Group=Visuals
PresetValues=0|1
PresetLabels=Coming soon|Coming soon
mcReadOnly=1
mcSlot=visuals
```

Slot names are letters, digits and `_`, at most 64 characters, unique per page.
The page needs explicit `Id`s on every setting. Contributors address a slot as
`<provider id>:<slot>`; a `ModCore<Name>` provider may also be written as its
lowercase `<name>`, so `controls:visuals` and `ModCoreControls:visuals` are the
same slot. A contributor publishes settings from one of its own manifest pages
(which may be `visible=false`):

```lua
pages:publish({pages={...},rows={
    {page='ModCoreTemplates',slot='controls:visuals',settings={'MCT_Template','MCT_RingSize'}},
}})
```

When the page loads, the listed settings replace the slot row in place, in
contributor and list order. Each takes the slot's `Group`, so the group's
Category rule gates it. A row carries its own `VisibleWhen`/`VisibleValues`
only when they name a row the same contributor inserted earlier in that slot.
DMM ANDs that rule with the Category rule. A row without its own rule takes the
slot row's rule; a slot row with its own `VisibleWhen` rejects rows that bring
one. Source Category rules are not carried. Only core DMM fields are copied, so
inserted rows render as plain pickers, toggles or sliders. Presets, navigation,
read-only and link rows cannot be inserted. With no valid rows the slot row
shows unchanged. A failed row is skipped and logged on its own.

The page's model sees only its own settings: its configuration, initialization
and Apply event never include inserted rows. Inserted rows edit the source
page's model. The page's Apply commits its own settings first, then each
dirtied source, which publishes its Apply event under the source page id. A
source fails only its own commit; the host's event is still published. Restore,
Reset and the unapplied-changes guard cover both. A source whose model cannot
open leaves its rows inert. As on any page, unapplied changes are discarded
when the page closes, so the same setting on two pages never holds two pending
values.

Rows need descriptor contract 2, so a ModCoreSettings build that predates
slots skips the whole contribution, pages included.

### Page links

A navigation picker with `mcLinkPage=<page id>` opens that page instead of saving
a value. It requires `mcNavigation=1` and works in any manifest. With unapplied
changes the link is refused and the page shows a status message.

## Apply notifications

`Scripts/settings_api.lua` is ModCoreSettings's versioned, game-agnostic consumer API. A mod
may vendor that file unchanged and subscribe to its own DMM provider ID:

```lua
local Settings=require('settings_api')
local unsubscribe=Settings.subscribe('ExampleMod',function(event)
    -- event.providerId, event.revision, event.values and event.changes
end)
```

DMM publishes only after a successful, durable Apply. Delivery is event-driven;
there is no file watcher or polling. Revisions are delivered at most once in a
Lua state. `values` contains the complete applied numeric setting map and
`changes` contains `{old=...,new=...}` only for changed IDs. Treat the event and
its nested tables as read-only. Callback failure cannot turn a completed save
into an Apply failure. Calling the returned function stops delivery to that
callback.

## Presentation metadata

`mcType=tab` renders an ordinary picker as contour-free, right-aligned choices
with a 24-pixel right inset on the same row as its label. It supports two to eight
choices and retains DMM's keyboard/controller navigation, pending model and
Apply/Restore behavior.

Set `mcNavigation=1` on a picker to use its choices only for menu navigation.
The picker can drive ordinary `VisibleWhen` / `VisibleValues` rules, but has no
config key, never marks the menu dirty, and is omitted from Apply events. Its
selected view lasts while the menu model is open. Navigation pickers use DMM's
arrow selector unless they explicitly request another presentation.

Set `mcTabsWidth` to an integer from 160 through 440 to reserve that total
width in pixels for the horizontal choices. The default grows by option count
up to 384 pixels. A two-option `mcTabsWidth=440` picker is twice the default
220-pixel width while retaining 144 pixels for its label.

`mcLevel=0` inherits the existing font. Levels 2–6 use sizes
16, 15, 14, 12 and 11 respectively. Level2/3 use the heading color;
Level4 uses normal body text; Level5/6 use
muted text, with Level5 at 85% opacity. The property applies to setting labels
and Category headings without changing control types.

Set `mcHeading=true` on a setting to use the title style. On generated
ModCoreTemplates module pages, that setting
shares the mod page title row above the divider. Its setting label is hidden
while the original control retains its value and navigation. Dirty styling is
omitted from this title row. The Templates page keeps its heading settings in
the normal settings list with title styling. This supports
toggles, pickers and sliders; at most one setting per provider may be a heading.
Mods still implement their settings' behavior.

Categories can declare `mcHelp` to show Level5 explanatory text under
the heading. DMM's `VisibleWhen` / `VisibleValues` rules still govern the group.

Set `mcHeading=0` on a category to suppress only that category's heading:

```ini
[Category.Player Actions]
mcHeading=0
```

The category remains a normal DMM group: its rows retain their manifest order,
visibility rules, navigation and Apply/Restore behavior. Any shared `mcParent`
heading remains visible while the category has visible rows. `mcHelp` is not
rendered when its category heading is suppressed. `mcHeading` accepts
`false`/`true` or `0`/`1` and defaults to `true` on categories.

Categories can also share a parent heading without flattening that heading into
each category label:

```ini
[Category.PrimaryWheel]
mcParent=Interaction: Independent
mcParentLevel=2
mcLevel=3

[Category.SecondaryWheel]
mcParent=Interaction: Independent
mcParentLevel=2
mcLevel=3

[Category.SelectiveBindings]
mcParent=Interaction: Selective
mcParentLevel=2
mcLevel=3
```

`mcParent` is the displayed parent label. Categories with the same exact
label share one parent heading and retain their own category headings as
subgroups. `mcParentLevel` accepts levels 0–6 and defaults to 2; every
category sharing a parent must use the same level. Parent headings do not add
visibility rules. A provider that wants persistent Independent and Selective
sections should leave their categories unconditional. If every subgroup under
a parent is hidden by DMM, ModCoreSettings hides the otherwise empty parent heading.

For labels that depend on another picker or toggle, settings and categories
can declare:

```ini
mcLabelWhen=PrimaryWheel
mcLabels=0:Secondary Wheel;1:Primary Wheel
```

Unlisted source values retain the original label. Category ordering is opt-in:

```ini
mcOrderWhen=PrimaryWheel
mcOrders=0:20;1:10
```

Only opted-in categories exchange positions, in ascending rank order. Other
categories remain in their original positions. Rows retain their setting IDs,
config keys and children. Reordering occurs on a relevant value change, using
DMM's existing menu refresh; no additional timer is created.

## Migrating missing defaults

`DefaultFrom=OldConfigKey` copies an existing value in the same `ConfigFile` and
explicit `ConfigSection` only when the destination key is absent. The source
must satisfy the destination range/choices and step. An invalid source prevents
initialization instead of silently overwriting it. An explicit destination value
always wins; an absent source uses the ordinary `Default`. Migration reads only
existing values, so it does not depend on setting order or follow default chains.

`DefaultFromMap=0:1;1:2` optionally converts the copied number through a finite
map. An existing source must have a mapped entry. No expressions are evaluated.

For cross-section or conditional copies, use ordered sections:

```ini
[DefaultRule.PositionFromLegacy]
Target = Position
SourceSection = Legacy Layout
SourceKey = UpperX
SourceDefault = 40
WhenAbsent = General/Role
WhenZero = Legacy Layout/Swap

[DefaultRule.PositionFallback]
Target = Position
SourceSection = Legacy Layout
SourceKey = LowerX
SourceDefault = 20
```

`Target` is a setting ID with an explicit `ConfigSection`. Rule section names
must be unique. Rules run in manifest order, at most 32 per target; the first
matching rule with an available source supplies the missing value. A rule without
`SourceDefault` is skipped when its source is absent. If no rule supplies a value,
the setting's ordinary `Default` applies. A target cannot also use `DefaultFrom`.

Both optional conditions must match. `WhenAbsent=Section/Key` tests whether the
key existed in the original file. `WhenZero=Section/Key` accepts finite integers;
zero or an absent key matches, while any nonzero integer does not. It is evaluated
only after `WhenAbsent` matches. References are exact and case-sensitive, and
read only the same configuration file's original snapshot. Explicit destination
values bypass all source and condition evaluation. Consumed source values must
satisfy the destination range, choices and step; malformed values fail instead
of being clamped or replaced. Duplicate config sections/keys are rejected.

Migration retains original bytes and unknown keys, adding only missing declared
destinations in one file transaction. Providers declaring migrations also pass
through an owned DMM open adapter: a failed migration sets DMM's normal error
state and disables editing/Apply until the problem is corrected. Other providers
use the original open path. No DMM source files are modified.

## Fixed mode labels

A standalone keybind can declare `mcMode=Tap` or `mcMode=Hold`. This supplies
a fixed, noninteractive label without creating a second setting. Paired pickers
instead use the picker-owned `Pair` contract described above.

No mode/config value is created to match the fixed label. In particular, Hold
is only display text; a mod can implement immediate physical hold behavior
without a Tap/Hold threshold. This metadata does not implement input behavior.

```ini
[Setting.SharedSlot1]
Id=SharedSlot1
Type=integer
mcType=keybind
mcMode=Tap
; Include the ordinary range, default and config fields.

```

`mcOptional=1` can be combined with either a fixed `mcMode` or a paired picker.
