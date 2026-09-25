package.path='Scripts/?.lua;'..package.path
local Choices=dofile(assert(os.getenv('DMM_CHOICES_PATH')))
local Navigation=require('navigation')
local InitConfig=require('init_config')
assert(Navigation.install(Choices))
local manifest=[[
[Mod]
Id=NavigationTest
[Category.Options]
mcHeading=0
[Setting.View]
Id=View
Type=picker
Label=View
Group=Options
PresetValues=0|1|2
PresetLabels=More|Primary|Secondary
Default=0
mcNavigation=1
mcType=tab
[Setting.Real]
Id=Real
Type=integer
Label=Real
Group=Options
Minimum=0
Maximum=10
Step=1
Default=4
ConfigFile=config.ini
ConfigSection=Settings
ConfigKey=Real
VisibleWhen=View
VisibleValues=1
]]
local items=Choices.parse(manifest)
assert(#items==2 and items[1].mcNavigation and not items[2].mcNavigation)
local path='/tmp/kem-navigation-test/config.ini'
local files={[path]='[Settings]\nReal=4\n'}
Choices.fs={
    read=function(p) return files[p] end,
    write=function(p,value) files[p]=value end,
    rename=function(a,b) assert(files[a]);files[b],files[a]=files[a],nil end,
    remove=function(p) files[p]=nil end,
}
local provider={id='NavigationTest',path='/tmp/kem-navigation-test/mod_settings.ini',choices=items}
local model=Choices.open(provider)
assert(not model.error,model.error)
assert(not model:dirty() and not model:visibility()[2])
model:set(1,1)
assert(not model:dirty() and model.pending[1]==1 and model:visibility()[2])
assert(model:apply() and files[path]=='[Settings]\nReal=4\n')
model:set(2,5)
assert(model:dirty())
local ok,why,event=model:apply()
assert(ok,why)
assert(files[path]=='[Settings]\nReal=5\n')
assert(event.values.Real==5 and event.values.View==nil and event.changes.View==nil)
assert(not model:dirty())
model:restore()
assert(model.pending[1]==1,'Restore must retain the navigation view')
model:reset()
assert(model.pending[1]==1 and model.committed[1]==1,
    'Reset must retain the current navigation view')
assert(model.pending[2]==4 and model:dirty(),
    'Reset must still reset persistent settings')
model:restore()
assert(model.pending[1]==1 and model.pending[2]==5 and not model:dirty())
local unsupported=manifest:gsub('%[Setting.View%]',
    '[Setting.Ignored]\nType=unsupported\nId=Ignored\n[Setting.View]')
local withIgnored=Choices.parse(unsupported)
assert(#withIgnored==2 and withIgnored[1].mcNavigation,
    'Unsupported settings ignored by DMM must not break navigation parsing')
local plan=assert(InitConfig.plan(provider,manifest,Choices,Choices.fs,items))
assert(not plan.content:find('View=',1,true),'config initialization must omit navigation')
print('Navigation picker remains transient, controls visibility and never writes a config key')
local references=manifest
for slot=1,4 do
    references=references..('\n[Setting.Reference%d]\nId=Reference%d\nType=picker\nLabel=Slot %d\nGroup=References\nDefault=0\nPresetValues=0|1\nPresetLabels=Slot %d|Slot %d\nmcReadOnly=1\n'):format(slot,slot,slot+4,slot,slot)
end
local displayItems=Choices.parse(references)
local displayProvider={id=provider.id,path=provider.path,choices=displayItems}
local displayModel=Choices.open(displayProvider)
assert(not displayModel.error,displayModel.error)
for i=3,6 do
    displayModel:set(i,1)
    assert(displayModel.pending[i]==0 and not displayModel:dirty())
end
displayModel:set(2,7)
assert(displayModel:apply())
assert(files[path]=='[Settings]\nReal=7\n' and #displayModel.items==6,
    'Apply must omit every reference and restore model indices')
displayModel:reset();displayModel:restore()
assert(displayModel.pending[2]==7 and displayModel.pending[6]==0)
local displayPlan=assert(InitConfig.plan(displayProvider,references,Choices,Choices.fs,displayItems))
assert(not displayPlan.content:find('Reference',1,true),'references never receive persistent keys')
