package.path='Scripts/?.lua;'..package.path
local FieldTypes=require('field_types')
local Keybind=require('keybind_editor')

-- Keybind values: one text value, normalized from what a manifest or file holds.
local s=Keybind.declare({Triggers='Hold|Tap',Optional='1',DefaultControl='IA_Combat_ToggleQuickslots'})
assert(s.optional and s.defaultControl=='IA_Combat_ToggleQuickslots' and s.defaultTrigger=='Hold'
    and s.triggers[1]=='Hold','the first listed trigger is the default')
for raw,expected in pairs({['']='none',['0']='none',none='none',NONE='none',LeftAlt='LeftAlt|Hold',
    ['LeftAlt|hold']='LeftAlt|Hold',[' F | Tap ']='F|Tap',One='1|Hold',['1|Hold']='1|Hold',['zero|tap']='0|Tap'}) do
    assert(Keybind.normalize(s,raw)==expected,raw)
end
for _,raw in ipairs({'LeftAlt|Push','Escape','None|Tap','Gamepad_FaceButton_Bottom','Left Alt','|Tap'}) do
    assert(Keybind.normalize(s,raw)==nil,raw)
end
assert(Keybind.valid(s,'LeftAlt|Hold') and not Keybind.valid(s,'LeftAlt') and not Keybind.valid(s,3))
local fixed=Keybind.declare({Triggers='Hold'})
assert(fixed.defaultTrigger=='Hold' and not fixed.optional and Keybind.normalize(fixed,'J')=='J|Hold')
assert(not pcall(Keybind.declare,{Triggers='Tap|tap'}) and not pcall(Keybind.declare,{Optional='yes'}))
print('PASS keybind values are none or <FKey>|<trigger>, normalized from manifests and files')

-- The panel loop with a stand-in editor: refresh sets, tick gets.
local reports={}
local registry=FieldTypes.new(function(event,detail) reports[#reports+1]=event..':'..tostring(detail) end)
local built,set={},{}
local editor={
    declare=function() return {} end,
    normalize=function(_,raw) return raw or 'a' end,
    valid=function(_,value) return value=='a' or value=='b' end,
    format=function() return '' end,
    build=function(row,setting)
        built[#built+1]=setting.id
        local instance={}
        function instance:set(value,committed) set[#set+1]=value..'/'..committed end
        function instance:tick() local value=row.next;row.next=nil;return value end
        return instance
    end,
}
registry:register('letter',editor)
assert(not pcall(registry.register,registry,'picker',editor),'DMM types cannot be replaced')
local refreshes=0
local choices
choices={parse=function() return {} end,index=function() return 1 end,format=function() return 'dmm' end,
    open=function(provider)
        local model={items=provider.choices,pending={'a'},committed={'a'}}
        function model:set(i,value) if choices.index(self.items[i],value) then self.pending[i]=value end end
        return model
    end}
local controls={build=function(_,providers)
    local ui={panels={{rows={{}}}}}
    function ui:prepare(index) self.panels[index].built=true end
    function ui:show(index) self.panels[index].built=true;self.active=index;self.model=choices.open(providers[index]) end
    function ui:refresh() refreshes=refreshes+1 end
    function ui:tick() return 'dmm tick' end
    return ui
end}
local published={}
local settingsApi={publish=function(id,event) published[#published+1]=event;return true end}
registry:install({choices=choices,controls=controls,settingsApi=settingsApi})
local setting={id='L',kind='extension',editor='letter',label='Letter'}
local ui=controls.build({},{{id='P',testOnly=true,choices={setting}}},{})
ui:show(1)
assert(built[1]=='L' and #built==1 and set[#set]=='a/a','show builds the editor once and sets its value')
ui:prepare(1)
assert(#built==1)
local row=ui.panels[1].rows[1]
row.next='b'
local before=refreshes
assert(ui:tick()=='dmm tick','DMM tick results pass through')
assert(ui.model.pending[1]=='b' and refreshes==before+1 and set[#set]=='b/a','a finished edit goes through model:set')
row.next='zzz'
ui:tick()
assert(ui.model.pending[1]=='b','DMM model validation still applies')
print('PASS refresh sets each editor and tick hands finished edits to the model')

-- A failing editor is reported; the page keeps working.
editor.build=function() error('editor failure') end
ui=controls.build({},{{id='P',testOnly=true,choices={setting}}},{})
ui:show(1)
assert(reports[#reports]:find('FIELD_EDITOR_FAILED:L: ',1,true))
assert(ui:tick()=='dmm tick')
print('PASS a failing editor is reported and DMM keeps running')

-- Applied notifications carry only numbers.
assert(settingsApi.publish('P',{values={Mode=2,Jump='LeftAlt|Hold'},changes={Jump={old='none',new='LeftAlt|Hold'}}}))
assert(published[1].values.Mode==2 and published[1].values.Jump==nil and published[1].changes.Jump==nil)
assert(settingsApi.publish('P',{values={Jump='F|Tap'},changes={}})==true and #published==1,
    'a notification with only text values is skipped')
print('PASS applied notifications drop text values')
