package.path = 'Scripts/?.lua;' .. package.path

local Legacy = require('legacy_metadata')
local Navigation = require('navigation')
local Presentation = require('presentation')
local Choices = dofile(assert(os.getenv('DMM_CHOICES_PATH')))

local manifest = [[
[Mod]
Id=ModCoreControls
Name=ModCore Controls
[Category.Layout]
ammHeading=0
ammLevel=3
[Setting.View]
Id=View
Type=picker
Group=Layout
PresetValues=0|1
PresetLabels=More|Controls
Default=0
ammType=tab
ammLevel=1
ammNavigation=1
[Setting.Key]
Id=Key
Type=integer
Group=Layout
Minimum=0
Maximum=254
Step=1
Default=75
ammType=keybind
]]

assert(Navigation.install(Choices))
assert(Legacy.install(Choices))
assert(not Legacy.install(Choices))
local items = Choices.parse(manifest)
Presentation.parse(Legacy.normalize(manifest), items)
assert(#items == 2 and items[1].kemNavigation and items[1].kemTabs
    and items[1].kemFont == 1 and items[2].kemKeybind)
assert(items[1].kemGroup and items[1].kemGroup.heading == false)
local override = Legacy.normalize('[Setting.One]\nammType=keybind\nkemType=tab\n')
assert(override:find('kemType=tab', 1, true)
    and not override:find('keybind', 1, true), 'canonical KEM metadata must win')
print('Legacy AMM metadata renders through KEM without changing provider settings')
