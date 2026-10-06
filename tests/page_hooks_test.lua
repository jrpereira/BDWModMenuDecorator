package.path='Scripts/?.lua;'..package.path
-- Needs the real DMM parser, which CI does not have; skip without it.
local choicesPath=os.getenv('DMM_CHOICES_PATH')
if not choicesPath then print('SKIP page hooks: DMM_CHOICES_PATH is not set');return end
local Choices=dofile(choicesPath)
local Hooks=require('page_hooks')
local Menu=require('menu_contributions')
local Pages=require('menu_pages')
local Slots=require('menu_slots')
assert(require('navigation').install(Choices))

local function fails(f,pattern,message)
    local ok,err=pcall(f)
    assert(not ok and tostring(err):find(pattern,1,true),message..': '..tostring(err))
end

-- Validation and transport: hooks pages need an absolute .lua path and a configDirectory,
-- carry no manifest or link, and select contract 3.
local hooksPage={id='MCC',name='Controls',attach='2_ModCore_Controls',
    hooks='/mods/mcc/Scripts/mcs_page.lua',configDirectory='/mods/mcc'}
assert(Menu.validate('MCC',{pages={hooksPage}}))
for _,case in ipairs({
    {{hooks='relative.lua',configDirectory='/c'},'absolute .lua path'},
    {{hooks='/mods/x.txt',configDirectory='/c'},'absolute .lua path'},
    {{hooks='/mods/x.lua'},'configDirectory'},
    {{hooks='/mods/x.lua',configDirectory='/c',manifest='[Setting.A]\n'},'cannot have a manifest'},
}) do
    local page={id='MCC',name='Controls'}
    for key,value in pairs(case[1]) do page[key]=value end
    local ok,err=Menu.validate('MCC',{pages={page}})
    assert(not ok and err:find(case[2],1,true),'hooks validation: '..tostring(err))
end
local descriptor,files=Menu.encode('MCC',4,{pages={hooksPage}})
assert(descriptor:find('contract=3',1,true) and #files==0,'A hooks page publishes contract 3 without manifest files')
local decoded=Menu.decode(descriptor,function() error('no manifest files') end)
assert(decoded.pages[1].hooks==hooksPage.hooks and decoded.pages[1].configDirectory=='/mods/mcc')
assert(Menu.encode('MCT',1,{pages={{id='MCT',name='T'}}}):find('contract=1',1,true),
    'Pages without hooks or rows keep contract 1')
fails(function() Menu.decode(descriptor:gsub('contract=3','contract=2'),function() end) end,
    'unsupported contract','A hooks descriptor must declare contract 3')

-- Loader: validates the returned table, caches by path (failures too), and lets the file
-- require modules beside it.
local sources={
    ['/m/ok/hooks.lua']=function() return {contract=1,manifest=function() return '' end} end,
    ['/m/old/hooks.lua']=function() return {contract=0,manifest=function() return '' end} end,
    ['/m/half/hooks.lua']=function() return {contract=1,manifest=function() end,load=function() end} end,
}
local loads=0
local load=Hooks.loader(function(path)
    loads=loads+1
    local chunk=sources[path]
    if not chunk then return nil,'cannot open '..path end
    return chunk
end)
local before=package.path
assert(load('/m/ok/hooks.lua')==load('/m/ok/hooks.lua') and loads==1,'Hooks files load once per path')
assert(package.path:sub(1,#'/m/ok/?.lua;')=='/m/ok/?.lua;','Hooks files can require modules beside them')
fails(function() load('/m/old/hooks.lua') end,'unsupported hooks contract','The hooks contract is checked')
fails(function() load('/m/half/hooks.lua') end,'both load() and apply()','Storage hooks come in pairs')
fails(function() load('/m/missing/hooks.lua') end,'cannot open','A missing file fails')
local count=loads
fails(function() load('/m/missing/hooks.lua') end,'cannot open','A failed file stays failed')
assert(loads==count,'A failed hooks file is not re-run on every build')
package.path=before

-- Page generation: the manifest hook runs on every build and its text becomes the page's
-- settings and manifest. A failing hook skips the contributor and keeps the menu.
local gamepad=false
local manifestCalls,loaded,applied={},nil,nil
local storage={MCC_Mode=1,MCC_Mirror=1}
local mccHooks={contract=1,
    manifest=function(context)
        manifestCalls[#manifestCalls+1]=context
        local text=[[
[Setting.MCC_Mode]
Id=MCC_Mode
Type=picker
Label=Mode
PresetValues=0|1|2
PresetLabels=A|B|C
Default=0
[Setting.MCC_Mirror]
Id=MCC_Mirror
Type=picker
Label=Mirror
PresetValues=0|1|2
PresetLabels=A|B|C
Default=0
[Setting.MCC_View]
Id=MCC_View
Type=picker
Label=View
PresetValues=0|1
PresetLabels=One|Two
Default=0
mcNavigation=1
]]
        if gamepad then text=text..[[
[Setting.MCC_Pad]
Id=MCC_Pad
Type=picker
Label=Gamepad
PresetValues=0|1
PresetLabels=Off|On
Default=0
]] end
        return text
    end,
    load=function(context) loaded=context;return storage end,
    apply=function(context,values,changes)
        applied={context=context,values=values,changes=changes}
        if values.MCC_Mode==2 and values.MCC_Mirror==0 then error('Mode and Mirror disagree') end
        -- Mirror follows Mode, as MCC's mirrored settings do.
        local saved={MCC_Mode=values.MCC_Mode,MCC_Mirror=values.MCC_Mode}
        storage=saved
        return saved,changes.MCC_Mode and 'restart required' or nil
    end}
local function hooked(page)
    assert(page.hooks==hooksPage.hooks)
    local context=Hooks.context(page)
    return mccHooks,Hooks.manifest(mccHooks,context),context
end
local function placeholder(folder)
    return {id='detected:ue4ss:'..folder:lower(),name=folder,testOnly=false,noSettings=true,detectedKind='ue4ss'}
end
local logs={}
local function report(event,detail) logs[#logs+1]=event..' '..tostring(detail) end
local providers={placeholder('2_ModCore_Controls')}
local state={}
local contribution={id='MCC',generation=1,pages={hooksPage}}
Pages.apply(providers,{contribution},Choices.parse,state,report,nil,hooked)
local page=providers[1]
assert(#providers==1 and page.id=='MCC' and #page.choices==3 and page.mcManifest:find('MCC_Mirror',1,true)
    and page.mcHooks==mccHooks and page.mcHookContext.directory=='/mods/mcc' and not page.noSettings,
    'A hooks page replaces its placeholder with the settings its manifest hook generates')
assert(manifestCalls[1].page=='MCC' and manifestCalls[1].directory=='/mods/mcc','The manifest hook gets the page context')
gamepad=true
Pages.apply(providers,{contribution},Choices.parse,state,report,nil,hooked)
assert(#manifestCalls==2 and #providers[1].choices==4,'The manifest hook runs again on each build')
local broken={id='Broken',generation=1,pages={{id='Broken',name='Broken',
    hooks='/mods/broken/hooks.lua',configDirectory='/mods/broken'}}}
local failing=function(p)
    if p.id=='Broken' then error('hooks file failed',0) end
    return hooked(p)
end
Pages.apply(providers,{broken,contribution},Choices.parse,state,report,nil,failing)
assert(#providers==1 and providers[1].id=='MCC' and logs[#logs]:find('Broken: hooks file failed',1,true),
    'A failing hooks page skips only its contributor')
Pages.apply(providers,{contribution},Choices.parse,state,report,nil,nil)
assert(providers[1].id=='detected:ue4ss:2_modcore_controls' and logs[#logs]:find('page hooks unavailable',1,true),
    'Without a hooks loader the page is skipped')
gamepad=false
Pages.apply(providers,{contribution},Choices.parse,state,report,nil,hooked)
page=providers[1]

-- Storage: values come from load(), Apply goes to apply() and never to a DMM config file,
-- the values apply() returns become committed, and its error rejects the Apply.
local writes=0
Choices.fs={read=function() error('DMM must not read a hooks page config') end,
    write=function() writes=writes+1 end,rename=function() writes=writes+1 end,remove=function() end}
assert(Hooks.install(Choices,report) and not Hooks.install(Choices,report),'installs once')
local slots=assert(Slots.install(Choices,report,Menu))
local model=Choices.open(page)
assert(not model.error and model.provider==page and model.pending[1]==1 and model.committed[2]==1
    and loaded.page=='MCC' and loaded.directory=='/mods/mcc','Load fills the model from the hooks')
model:set(3,1)
assert(model.committed[3]==1,'Navigation rows stay clean')
model.pending[1]=2
local ok,warning,event=model:apply()
assert(applied.values.MCC_View==nil and not applied.changes.MCC_View and event.values.MCC_View==nil
    and model.pending[3]==1,'Navigation rows are neither stored nor published, and keep their view')
assert(ok and warning=='restart required' and applied.values.MCC_Mode==2 and applied.values.MCC_Mirror==1
    and applied.changes.MCC_Mode.old==1 and applied.changes.MCC_Mode.new==2 and not applied.changes.MCC_Mirror,
    'Apply passes every value and the edited ones')
assert(model.committed[1]==2 and model.pending[2]==2 and model.committed[2]==2 and not model:dirty()
    and event.values.MCC_Mirror==2 and event.changes.MCC_Mode.new==2 and writes==0,
    'Saved values become committed and published, without DMM writing a config')
model.pending[1],model.pending[2]=2,0
ok,warning=model:apply()
assert(not ok and warning:find('Mode and Mirror disagree',1,true) and model.committed[2]==2,
    'A rejected Apply keeps the committed values')
local failingLoad={}
for key,value in pairs(page) do failingLoad[key]=value end
failingLoad.mcHooks={contract=1,manifest=mccHooks.manifest,
    load=function() error('config unreadable') end,apply=mccHooks.apply}
model=Choices.open(failingLoad)
ok,warning=model:apply()
assert(model.error:find('config unreadable',1,true) and not ok,'A failing load shows the page error and blocks Apply')
-- Stored values the page cannot show fall back to defaults instead of breaking the menu;
-- a value the setting's type can normalize is kept in canonical form.
local invalid={}
for key,value in pairs(page) do invalid[key]=value end
invalid.mcHooks={contract=1,manifest=mccHooks.manifest,apply=mccHooks.apply,
    load=function() return {MCC_Mode=7,MCC_Mirror='2'} end}
logs={}
Choices.mcNormalize=function(item,value) if item.id=='MCC_Mirror' then return tonumber(value) end end
model=Choices.open(invalid)
Choices.mcNormalize=nil
assert(not model.error and model.pending[1]==0 and model.committed[1]==0
    and model.pending[2]==2 and model.committed[2]==2 and not model:dirty(),
    'An invalid stored value keeps the default; a normalizable one is kept canonical')
assert(#logs==1 and logs[1]:find('HOOK_VALUES_SKIPPED MCC: MCC_Mode=7; defaults kept',1,true),
    'Skipped stored values are reported: '..table.concat(logs,'\n'))
local plain=Choices.open({id='Plain',choices={},testOnly=true})
assert(not plain.error and plain.provider.id=='Plain','Pages without hooks keep DMM storage')
assert(slots and Choices.open~=nil)
print('PASS page hooks: validation, contract 3, loader, per-build manifests, storage and Apply')
