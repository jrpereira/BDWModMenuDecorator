package.path='Scripts/?.lua;Scripts/vendor/?.lua;'..package.path
-- Needs the real DMM parser and model; skip without it.
local choicesPath=os.getenv('DMM_CHOICES_PATH')
if not choicesPath then print('SKIP player exists: DMM_CHOICES_PATH is not set');return end
local Choices=dofile(choicesPath)
assert(require('navigation').install(Choices))
local Presentation=require('presentation')
local player,checks=false,0
assert(Presentation.install(Choices,{build=function() end},{build=function() end},
    {playerExists=function()
        checks=checks+1
        if player=='error' then error('no world') end
        return player
    end}))

local manifest=[[
[Category.Tabs]
mcHeading=0

[Setting.Tab]
Id=Tab
Label=Tab
Group=Tabs
Type=picker
Default=0
PresetValues=0|1
PresetLabels=One|Two
mcNavigation=1

[Category.Played]
VisibleWhen=Tab
VisibleValues=0
mcPlayerExists=1

[Setting.Page]
Id=Page
Label=Page
Group=Played
Type=picker
Default=0
PresetValues=0|1
PresetLabels=1|2
mcNavigation=1

[Setting.Play]
Id=Play
Label=Sound
Group=Played
Type=picker
Default=0
PresetValues=0|1
PresetLabels=Play|Play
mcNavigation=1
VisibleWhen=Page
VisibleValues=0

[Category.Waiting]
mcHeading=0

[Setting.Waiting]
Id=Waiting
Label=Load a game
Group=Waiting
Type=picker
Default=0
PresetValues=0|1
PresetLabels=Unavailable|Unavailable
mcReadOnly=1
mcPlayerExists=0

[Setting.Always]
Id=Always
Label=Always
Group=Waiting
Type=picker
Default=0
PresetValues=0|1
PresetLabels=Shown|Shown
mcReadOnly=1
]]
local model=Choices.open({id='Player',choices=Choices.parse(manifest)})
assert(not model.error,model.error)
local function shown()
    local visible=model:visibility()
    local ids={}
    for i,item in ipairs(model.items) do if visible[i] then ids[#ids+1]=item.id end end
    return table.concat(ids,',')
end
assert(shown()=='Tab,Waiting,Always','without a player, only rows for no player show')
player=true
assert(shown()=='Tab,Page,Play,Always','with a player, the player rows show instead')
model:set(2,1)
assert(shown()=='Tab,Page,Always','the player condition adds to VisibleWhen')
model:set(2,0);model:set(1,1)
assert(shown()=='Tab,Always','and to the category VisibleWhen')
player='error'
assert(shown()=='Tab,Waiting,Always','a failing check counts as no player')
print('PASS mcPlayerExists shows rows and categories only while a player does, or does not, exist')

assert(not pcall(Choices.parse,'[Setting.A]\nId=A\nLabel=A\nType=picker\nDefault=0\nPresetValues=0|1\nPresetLabels=a|b\nmcPlayerExists=yes\n'),
    'mcPlayerExists must be 0 or 1')
local plain=Choices.open({id='Plain',choices=Choices.parse((manifest:gsub('mcPlayerExists=%d\n','')))})
checks=0;plain:visibility()
assert(checks==0,'pages without mcPlayerExists never check for a player')
print('PASS mcPlayerExists is validated and costs nothing where unused')
