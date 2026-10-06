-- Runs the DMM-side launch against the real DawnwalkerModMenu modules.
local dmm='../Dawnwalker/ue4ss/Mods/DawnwalkerModMenu/Scripts/'
local probe=io.open(dmm..'choices.lua','rb')
if not probe then print('SKIP DawnwalkerModMenu is not installed beside this workspace');return end
probe:close()
package.path=dmm..'?.lua;'..package.path
local shared={}
ModRef={SetSharedVariable=function(_,key,value) shared[key]=value end,
    GetSharedVariable=function(_,key) return shared[key] end}
local extension=assert(loadfile('Scripts/dmm_extension.lua'))()
local choices,controls,pages,native=require('choices'),require('controls'),require('pages'),require('nativeactions')
local originals={parse=choices.parse,open=choices.open,build=controls.build,pagesBuild=pages.build,close=native.close}
extension.launch()
assert(shared['MC_DMM_Extension_v1.ready']=='1','launch completes the readiness handshake')
-- DMM's main gets these same tables from require, already hooked.
assert(require('choices')==choices and require('controls')==controls and require('pages')==pages)
assert(choices.parse~=originals.parse and choices.open~=originals.open and controls.build~=originals.build
    and pages.build~=originals.pagesBuild and native.close~=originals.close,'hooks sit on the DMM module tables')
local items=choices.parse('[Setting]\nId=Speed\nLabel=Speed\nType=picker\nDefault=1\nPresetValues=1|2\nPresetLabels=Slow|Fast\n'
    ..'ConfigFile=config.ini\nConfigKey=speed\nmcLevel=2\n')
assert(#items==1 and items[1].id=='Speed' and items[1].kind=='picker' and items[1].mcFont==2,
    'DMM parses the manifest and ModCoreSettings presentation reads its metadata')
print('PASS launch hooks the real DawnwalkerModMenu modules before DMM main uses them')

-- A keybind among DMM's own settings keeps its place, and DMM's references move with it.
local manifest=table.concat({
    '[Setting]','Id=Mode','Label=Mode','Type=picker','Default=1','PresetValues=1|2','PresetLabels=One|Two',
    'ConfigFile=config.ini','ConfigKey=mode','',
    '[Setting]','Id=Jump','Label=Jump','Type=keybind','Triggers=Tap|Hold','Default=SpaceBar','Optional=1',
    'DefaultControl=IA_Jump','VisibleWhen=Mode','VisibleValues=2','ConfigFile=config.ini','ConfigKey=jump','',
    '[Setting]','Id=Speed','Label=Speed','Type=integer','Minimum=0','Maximum=9','Default=3',
    'VisibleWhen=Mode','VisibleValues=1','ConfigFile=config.ini','ConfigKey=speed',''},'\n')
items=choices.parse(manifest)
assert(#items==3 and items[1].id=='Mode' and items[2].id=='Jump' and items[3].id=='Speed')
local jump=items[2]
assert(jump.kind=='extension' and jump.editor=='keybind' and jump.default=='SpaceBar|Tap' and jump.optional
    and jump.defaultControl=='IA_Jump' and #jump.triggers==2)
assert(jump.visibility[1].target==1 and jump.visibility[1].values[2],'the keybind is shown by its own rule')
assert(items[3].visibility[1].target==1,'DMM rules still point at the right setting after the merge')
assert(choices.index(jump,'LeftAlt|Hold')==1 and choices.index(jump,'LeftAlt|Push')==nil and choices.index(jump,1)==nil)
assert(choices.format(jump,'LeftAlt|Hold')=='')
-- A page that saves through DMM's own file cannot hold text values.
local model=choices.open({id='Plain',choices=items,settingsCount=#items,testOnly=false,path='C:/none/mod_settings.ini'})
assert(model.error,'pages using DMM file storage refuse keybind settings')
-- Hooks pages keep the text in DMM's model like any other value.
model=choices.open({id='Hooked',choices=items,settingsCount=#items,testOnly=true})
assert(not model.error and model.pending[2]=='SpaceBar|Tap')
model:set(2,'LeftAlt|Hold')
assert(model.pending[2]=='LeftAlt|Hold' and model:dirty())
model:set(2,3)
assert(model.pending[2]=='LeftAlt|Hold','a number is not a keybind value')
model:reset(2)
assert(model.pending[2]=='SpaceBar|Tap')
print('PASS keybind settings sit among DMM settings with text values in its model')
