# Integration reference

Start with the [developer guide](DEVELOPERS.md) for a complete first setting.
Examples below are fragments unless they include a full file. `settingsManifest`
means an INI string; replace example paths with absolute paths on the game host.

- [Generated pages](#menu-pages) and [slot rows](#slot-rows)
- [Page hooks](#page-hooks) and [page links](#page-links)
- [Apply notifications](#apply-notifications)
- [Presentation metadata](#presentation-metadata)
- [Migrating missing defaults](#migrating-missing-defaults)
- [Mapped presets](#mapped-presets)

## Menu pages

ModCoreSettings is the only DMM integration. Other mods never install a DMM
extension or call DMM directly; to add generated menu pages they publish data
through `Scripts/menu_contributions.lua`. A provider is the mod/page that owns
a settings model. Vendor that file unchanged and publish
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
the same contributor) or `attach` (a mod folder name). `link` makes a
[slot link](#slot-rows) entry. `group='module'` puts the
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
inserted rows render as plain pickers, toggles or sliders. The exception is a
row label rule (`mcLabelWhen`/`mcLabels`): it is copied when `mcLabelWhen` names
a row the same contributor inserted earlier, and the row is skipped otherwise. A
row named by `mcSlotLabel=1` keeps no label rule. Presets, navigation,
read-only and link rows cannot be inserted. With no valid rows the slot row
shows unchanged. Each `rows` entry is all or nothing: one invalid setting skips
that entry, logged as `SLOT_ROW_SKIPPED`, and other entries still insert.

Add `mcSlotLabel=1` to the slot row to let the host name the slot. The first
inserted row then takes the slot row's `Label`, `mcLevel` and `mcCategory`;
later rows keep their own. To make that row stand in for the group heading,
suppress the heading with `mcHeading=0` on the group's Category and give the
slot row `mcCategory=1`:

```ini
[Category.Visuals]
VisibleWhen=MCC_Page
VisibleValues=1
mcHeading=0

[Setting.MCC_Visuals_Pending]
...
Label=Quickslots Visuals
mcCategory=1
mcReadOnly=1
mcSlot=visuals
mcSlotLabel=1
```

Filled, the page shows one `Quickslots Visuals` row whose value side is the
contributed picker; with no rows, the placeholder shows under the same label.
The row stays the source's setting: storage, Apply and visibility are unchanged.
`mcHeading` itself is not transferred; a page has at most one level-one heading.

The page's model sees only its own settings: its configuration, initialization
and Apply event never include inserted rows. Inserted rows edit the source
page's model. The page's Apply commits its own settings first, then each
dirtied source, which publishes its Apply event under the source page id. A
source fails only its own commit; the host's event is still published. Restore,
Reset and the unapplied-changes guard cover both. A source whose model cannot
open leaves its rows inert. As on any page, unapplied changes are discarded
when the page closes, so the same setting on two pages never holds two pending
values.

A `visible=false` page that is a row source shows as an ordinary page, in its
declared place (`under`, `attach`), when none of its rows has an available
slot: the host page is not listed or does not declare the slot. Its rows then
work as on any page, with the same page id and storage. Build such a page to
stand alone. Availability is decided per menu build; a row entry rejected
later, while the page loads, does not bring the fallback back.

A page with `link='<provider>:<slot>'` and no manifest is a browser entry for
that slot. Selecting it opens the slot's page and sets the navigation pickers
that gate the slot so its rows show; navigation never marks the page dirty.
The entry is listed only while the host page declares the slot and the slot
has rows. Otherwise it is hidden like `visible=false`, including any detected
placeholder it claims. Link pages cannot have children.

Rows and links need descriptor contract 2, so a ModCoreSettings build that predates
slots skips the whole contribution, pages included.

### Page hooks

A page whose settings change at runtime, or that owns its own storage, names a
hooks file instead of a manifest. ModCoreSettings loads it in its own menu
state, once per session, and modules beside it can be `require`d:

```lua
{id='ExampleMod',name='Example',attach='ExampleMod',
    hooks='<absolute path>/Scripts/mcs_page.lua',configDirectory='<absolute folder>'}
```

```lua
-- mcs_page.lua
return {contract=1,
    manifest=function(context) return settingsManifest end,           -- every menu build
    load=function(context) return {[settingId]=value} end,             -- optional
    apply=function(context,values,changes) return saved,warning end,   -- with load
}
```

`context` is `{page=<page id>,directory=<configDirectory>}`. With `load` and
`apply`, ModCoreSettings never reads or writes the page's config file: `load`
supplies the values (missing ids keep their defaults), and Apply passes every
value by id and the edited ones as `{old=,new=}`. `apply` returns the values it
saved, which become committed and are published in the Apply notification, plus
an optional warning. An error from `apply` rejects the Apply and keeps the page
dirty; an error from `load` shows the page error. An error loading the file or
from `manifest` skips the contributor like any other failure. Hooks pages need
descriptor contract 3, which older ModCoreSettings builds skip.

### Page links

A navigation picker with `mcLinkPage=<page id>` opens that page instead of saving
a value. It requires `mcNavigation=1` and works in any manifest. With unapplied
changes the link is refused and the page shows a status message.
`mcLinkPage=<provider>:<slot>` opens the page that hosts that slot, sets its
navigation pickers so the slot shows, and selects the slot's first row. With
`mcType=tab`, a link shows one button labelled with its first choice. `mcLevel=5`
sets the row label in small (12pt) muted text, which suits a notice.

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
Lua state. There is one active callback per provider ID; subscribing again through
the same client replaces it. Another Lua state cannot claim that provider ID.
Existing revisions are not replayed at subscription time: load startup values
from your config. Unsubscribing stops delivery but does not release the native
handler/claim; fully restart after script reloads. `values` contains the applied numeric settings (text keybinds are omitted), and
`changes` contains `{old=...,new=...}` only for changed IDs. Treat the event and
its nested tables as read-only. Reload your config to read text bindings; the event is not their value transport.
Callback failure cannot turn a completed save
into an Apply failure. Calling the returned function stops delivery to that
callback.

## Presentation metadata

`mcType=tab` renders an ordinary picker as outlined, right-aligned choices
with a 24-pixel right inset on the same row as its label. Choices sit 4 pixels
apart; the selected choice's outline is drawn at full strength. It supports two to eight
choices and retains DMM's keyboard/controller navigation, pending model and
Apply/Restore behavior.

`mcType=cycle` renders a picker as one button showing only the current choice at
13pt; a click moves to the next choice, wrapping. The button is as wide as the
keybind editor's key box and sits in its key column, so it lines up under keys.
DMM's keyboard/controller navigation is retained.

`mcWrap=1` on an `mcReadOnly=1` picker shows its value as 13pt left-aligned
text in a wider column, broken after commas so no line reaches 34 characters;
the row grows to fit its lines.

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

Set `mcCategory=1` on a setting to make it stand in for its group's heading. Its
label takes the Category heading's look: 16pt muted, unindented, with the
heading's spacing. While it shows, the rows after it indent beneath it as they
would under a visible heading. Pair it with `mcHeading=0` on the group so the
heading does not show twice. It cannot be combined with `mcLevel` or `mcHeading`.

Set `mcHeading=true` on a setting to use the title style. On generated
ModCoreTemplates module pages, that setting
shares the mod page title row above the divider. Its setting label is hidden
while the original control retains its value and navigation. Dirty styling is
omitted from this title row. The Templates page keeps its heading settings in
the normal settings list with title styling. This supports
toggles, pickers and sliders; at most one setting per provider may be a heading.
Your mod still implements its settings' behavior.

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

## Mapped presets

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

