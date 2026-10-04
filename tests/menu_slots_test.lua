package.path='Scripts/?.lua;'..package.path
local Choices=dofile(assert(os.getenv('DMM_CHOICES_PATH')))
local Navigation=require('navigation')
local Mapped=require('mapped_presets')
local Slots=require('menu_slots')
local Menu=require('menu_contributions')
assert(Navigation.install(Choices))
assert(Mapped.install(Choices,{build=function() end}))
local logs={}
local function report(event,detail) logs[#logs+1]=event..' '..tostring(detail) end
local controller=assert(Slots.install(Choices,report,Menu))
assert(Slots.install(Choices,report,Menu)==nil,'installs once')

local files={}
Choices.fs={read=function(path) return files[path] end,
    write=function(path,content) files[path]=content end,
    rename=function(a,b) files[b]=assert(files[a]);files[a]=nil end,
    remove=function(path) files[path]=nil end}
local function read(path) return files[path] end

local host=[[
[Mod]
Id=ModCoreControls
Name=Controls
[Setting.MCC_Page]
Id=MCC_Page
Type=picker
Label=Page
Group=Pages
PresetValues=0|1
PresetLabels=Options|Visuals
Default=0
mcNavigation=1
[Category.Visuals]
VisibleWhen=MCC_Page
VisibleValues=1
[Setting.MCC_Visuals_Pending]
Id=MCC_Visuals_Pending
Type=picker
Label=Quickslot templates
Group=Visuals
PresetValues=0|1
PresetLabels=Coming|Coming
Default=0
mcReadOnly=1
mcSlot=visuals
[Setting.Speed]
Id=Speed
Type=picker
Label=Speed
Group=Options
PresetValues=0|1
PresetLabels=Slow|Fast
Default=0
VisibleWhen=MCC_Page
VisibleValues=0
ConfigFile=config.ini
ConfigSection=Main
ConfigKey=Speed
]]
local source=[[
[Mod]
Id=ModCoreTemplates
Name=ModCore Templates
[Setting.MCT_Template]
Id=MCT_Template
Type=picker
Label=Quickslots
Description=Choose a template
Group=Player
PresetValues=0|5|7
PresetLabels=None|Ring|Bar
Default=0
mcHeading=true
ConfigFile=templates.ini
ConfigSection=Templates
ConfigKey=MCT_Template
[Setting.MCT_Other]
Id=MCT_Other
Type=toggle
Label=Other
Group=Player
PresetValues=0|1
Default=0
VisibleWhen=MCT_Template
VisibleValues=5|7
ConfigFile=templates.ini
ConfigSection=Templates
ConfigKey=MCT_Other
]]
files['/mcc/mod_settings.ini']=host
files['/mcc/config.ini']='[Main]\nSpeed=0\n'
files['/mct/templates.ini']='[Templates]\nMCT_Template=5\nMCT_Other=1\n'
local function provider(id,path,content,contributed)
    return {id=id,name=id,path=path,choices=Choices.parse(content),settingsCount=select(2,content:gsub('%[Setting%.',''))
        ,mcManifest=contributed and content or nil,testOnly=false}
end
local mcc=provider('ModCoreControls','/mcc/mod_settings.ini',host)
local mct=provider('ModCoreTemplates','/mct/mod_settings.ini',source,true)
local function ids(list)
    local out={}
    for n,setting in ipairs(list) do out[n]=setting.id end
    return table.concat(out,',')
end
local base=mcc.choices
assert(base[2].mcSlot=='visuals' and base[2].mcReadOnly)

-- Without inserts the page is unchanged and keeps its placeholder.
assert(controller:load(mcc,read)==false and mcc.choices==base)

-- An insert replaces the placeholder in place, takes the slot's group and gating, drops
-- source presentation keys, and later index-based rules still point at the right rows.
local applied={}
controller.applied=function(p,event) applied[#applied+1]={id=p.id,event=event} end
local entry={contributor='ModCoreTemplates',source=mct,settings={'MCT_Template'}}
controller.inserts={controls={visuals={entry}}}
assert(controller:load(mcc,read))
assert(ids(mcc.choices)=='MCC_Page,MCT_Template,Speed',ids(mcc.choices))
local template=mcc.choices[2]
assert(template.group=='Visuals' and template.label=='Quickslots' and template.description=='Choose a template')
assert(template.mcSlotSource==mct and template.mcSlotName=='visuals' and not template.mcHeading and not template.file)
assert(Slots.declares(mcc,'visuals',read) and not Slots.declares(mcc,'other',read))
assert(not Slots.declares(mcc,'visuals',function() error('gone') end) and Slots.declares(mct,'x',read)==false)
assert(controller:declares(mcc,'visuals')==false,'the controller reads with the reader it was installed with')
assert(mcc.settingsCount==3 and mcc.mcSlotBase.choices==base)
assert(controller:load(mcc,read) and ids(mcc.choices)=='MCC_Page,MCT_Template,Speed','reload is idempotent')

local model=Choices.open(mcc)
assert(not model.error,model.error)
assert(model.items==mcc.choices and model.pending[2]==5 and model.committed[2]==5 and model.pending[3]==0)
local visible=model:visibility()
assert(not visible[2] and visible[3],'Options page shows Speed, hides Visuals')
model:set(1,1)
visible=model:visibility()
assert(visible[2] and not visible[3] and not model:dirty(),'navigation gates the inserted row')

-- Inserted rows edit the source model only; Apply writes the source config and publishes
-- the source's own event. The host config never sees them.
model:change(2,2)
assert(model.pending[2]==7 and model.committed[2]==5 and model:dirty())
local ok,err,event=model:apply()
assert(ok and err==nil and event==nil,tostring(err))
assert(files['/mct/templates.ini']=='[Templates]\nMCT_Template=7\nMCT_Other=1\n')
assert(files['/mcc/config.ini']=='[Main]\nSpeed=0\n')
assert(#applied==1 and applied[1].id=='ModCoreTemplates' and applied[1].event.values.MCT_Template==7
    and applied[1].event.values.MCT_Other==1 and applied[1].event.changes.MCT_Template.old==5)
assert(not model:dirty() and model.committed[2]==7)

-- Host rows keep their own Apply event; inserted values never appear in it.
applied={}
model:set(1,0);model:set(3,1);model:set(2,0)
ok,err,event=model:apply()
assert(ok and event.values.Speed==1 and event.values.MCT_Template==nil,tostring(err))
assert(event.values.MCC_Page==nil and event.values.MCC_Visuals_Pending==nil)
assert(files['/mcc/config.ini']=='[Main]\nSpeed=1\n' and files['/mct/templates.ini']:find('MCT_Template=0',1,true))
assert(#applied==1 and applied[1].id=='ModCoreTemplates','DMM publishes the host event; the slot publishes the source')

-- Restore, row reset and page reset reach both models.
model:set(3,0);model:set(2,5)
model:restore()
assert(model.pending[3]==1 and model.pending[2]==0 and not model:dirty())
model:set(2,7);model:reset(2)
assert(model.pending[2]==0)
model:set(2,7);model:set(3,0);model:reset()
assert(model.pending[2]==0 and model.pending[3]==0 and model:dirty())
model:restore()

-- A source failure after a successful host Apply still publishes the host event.
applied={}
model:set(3,0);model:set(2,5)
files['/mct/templates.ini']='[Templates]\nMCT_Template=0\nMCT_Other=0\n'
ok,err=model:apply()
assert(not ok and err:find('ModCoreTemplates',1,true) and err:find('changed externally',1,true),tostring(err))
assert(#applied==1 and applied[1].id=='ModCoreControls' and applied[1].event.values.Speed==0)
assert(files['/mcc/config.ini']=='[Main]\nSpeed=0\n' and model.committed[3]==0 and model:dirty())
model:restore()

-- An unavailable source leaves its rows inert; the host page still works.
local saved=files['/mct/templates.ini']
files['/mct/templates.ini']=nil
logs={}
model=Choices.open(mcc)
assert(not model.error and model.pending[2]==0 and logs[1]:find('SLOT_SOURCE_UNAVAILABLE',1,true))
model:set(2,7)
assert(model.pending[2]==0 and not model:dirty())
model:set(3,1)
assert(model:dirty() and model:apply())
files['/mct/templates.ini']=saved

-- Invalid rows are skipped one by one with a log; the placeholder returns when none remain.
local function rejected(settings,pattern)
    logs={}
    controller.inserts={controls={visuals={{contributor='ModCoreTemplates',source=mct,settings=settings}}}}
    assert(controller:load(mcc,read)==false and mcc.choices==base,pattern)
    assert(logs[1] and logs[1]:find('SLOT_ROW_SKIPPED',1,true) and logs[1]:find(pattern,1,true),tostring(logs[1]))
end
rejected({'Missing'},'not found')
rejected({'MCT_Other'},'inserted earlier')
rejected({'MCT_Other','MCT_Template'},'inserted earlier')
logs={}
controller.inserts={controls={visuals={{contributor='Someone',source=mct,settings={'MCT_Template'}},
    {contributor='ModCoreTemplates',source=mct,settings={'MCT_Other'}}}}}
assert(controller:load(mcc,read) and ids(mcc.choices)=='MCC_Page,MCT_Template,Speed'
    and logs[1]:find('inserted earlier',1,true),'another contributor\'s row is not a visibility source')

-- A row may gate on a row its contributor inserted earlier; DMM ANDs that with the slot Category.
logs={}
controller.inserts={controls={visuals={{contributor='ModCoreTemplates',source=mct,settings={'MCT_Template'}},
    {contributor='ModCoreTemplates',source=mct,settings={'MCT_Other'}}}}}
assert(controller:load(mcc,read) and ids(mcc.choices)=='MCC_Page,MCT_Template,MCT_Other,Speed' and #logs==0,logs[1])
files['/mct/templates.ini']='[Templates]\nMCT_Template=5\nMCT_Other=1\n'
model=Choices.open(mcc)
assert(model.pending[2]==5 and model.pending[3]==1)
visible=model:visibility()
assert(not visible[3],'hidden on the Options page')
model:set(1,1)
assert(model:visibility()[3],'Visuals page with a template selected')
model:set(2,0)
assert(not model:visibility()[3] and model:visibility()[2],'no template selected')
model:restore()
local gated=host:gsub('mcSlot=visuals\n','mcSlot=visuals\nVisibleWhen=MCC_Page\nVisibleValues=1\n')
files['/gated/mod_settings.ini']=gated
local other=provider('Gated','/gated/mod_settings.ini',gated)
logs={}
assert(Slots.load(other,{visuals={{contributor='ModCoreTemplates',source=mct,settings={'MCT_Template','MCT_Other'}}}},
    read,Choices.parse,report)==false and logs[1]:find('own VisibleWhen',1,true),tostring(logs[1]))
rejected({'Speed'},'already on this page')
logs={}
controller.inserts={controls={visuals={{contributor='Bad',source=mct,settings={'Missing'}},entry}}}
assert(controller:load(mcc,read) and ids(mcc.choices)=='MCC_Page,MCT_Template,Speed' and #logs==1)

-- Unknown slots and unreadable manifests leave the page untouched.
controller.inserts={controls={Other={entry}}}
assert(controller:load(mcc,read)==false and mcc.choices==base)
controller.inserts={controls={visuals={entry}}}
logs={}
assert(controller:load(mcc,function() return nil end)==false and mcc.choices==base)
assert(logs[1]:find('SLOT_ROWS_SKIPPED',1,true))

-- A deferred page reloaded by DMM gets a fresh base.
assert(controller:load(mcc,read))
mcc.choices=Choices.parse(host)
assert(controller:load(mcc,read) and mcc.mcSlotBase.choices~=base and #mcc.mcSlotBase.choices==3)

-- A provider storage wrapper installed later (as ModCoreControls does) ends up inside the
-- slot model once outermost() runs, so it only ever sees the host's own settings.
do
    controller.inserts={controls={visuals={entry}}}
    files['/mct/templates.ini']='[Templates]\nMCT_Template=5\nMCT_Other=1\n'
    assert(controller:load(mcc,read))
    local storage,seen={},nil
    local before=Choices.open
    Choices.open=function(p)
        if p.id~='ModCoreControls' then return before(p) end
        local model=before(p)
        seen=p.choices
        function model:apply()
            for i,item in ipairs(self.items) do storage[item.id]=self.pending[i] end
            for i,value in ipairs(self.pending) do self.committed[i]=value end
            return true,nil,{values=storage,changes={}}
        end
        return model
    end
    assert(controller:outermost() and not controller:outermost(),'re-wraps once')
    applied={}
    local composite=Choices.open(mcc)
    assert(seen==mcc.mcSlotBase.choices,'storage sees the unspliced host')
    composite:set(1,1);composite:set(2,7);composite:set(3,1)
    assert(composite:apply())
    assert(storage.Speed==1 and storage.MCT_Template==nil,'inserted rows never reach host storage')
    assert(files['/mct/templates.ini']:find('MCT_Template=7',1,true) and #applied==1)
end

-- Slot declarations are validated with the manifest.
assert(not pcall(Choices.parse,host:gsub('mcReadOnly=1\n','')),'mcSlot requires read-only')
assert(not pcall(Choices.parse,host:gsub('mcSlot=visuals','mcSlot=a-b')),'slot names are words')
print('PASS menu slots splice contributed rows and route them to their source model')
