package.path='Scripts/?.lua;Scripts/vendor/?.lua;'..package.path
local Manifest=require('mcs_manifest')

local text=table.concat({
    'Loose=ignored before any section',
    '[Mod]',
    'Id=Example',
    '[Setting.Speed]',
    'Id = Speed ',
    '; Id=Commented',
    '# mcLevel=9',
    '',
    'Label=Speed\r',
    'Label=Fast',
    'not an assignment',
    '[Category.General]',
    'mcHeading=0',
    '[Setting]',
    'Type=toggle',
    '',
}, '\n')
local sections,lines=Manifest.sections(text)
assert(#lines==15 and lines[15]=='Type=toggle','the final empty line is dropped')
assert(#sections==4 and sections[1].name=='Mod' and sections[1].fields.Id=='Example' and not sections[1].setting,
    'every section is listed; only settings get a position')
local speed,general,toggle=sections[2],sections[3],sections[4]
assert(speed.setting==1 and speed.id=='Speed' and speed.first==4 and speed.last==11,'a setting has its span and Id')
assert(speed.fields.Label=='Fast' and speed.duplicates.Label and not speed.duplicates.Id,
    'a repeated key keeps its last value and is flagged')
assert(speed.fields['; Id']==nil and speed.fields.mcLevel==nil,'comment lines are skipped')
assert(#speed.malformed==1 and speed.malformed[1]==11,'a line that is not key=value is recorded')
assert(general.name=='Category.General' and general.fields.mcHeading=='0' and not general.setting)
assert(toggle.setting==2 and toggle.id=='setting_2' and toggle.last==15,'an unnamed setting takes DMM\'s fallback id')
local settings=Manifest.settings(text)
assert(#settings==2 and settings[1].id=='Speed' and settings[2].id=='setting_2')
assert(#Manifest.sections('')==0)
print('PASS the manifest reader finds sections, fields, spans and fallback ids')

-- Setting ids match DMM's own parser, including fallback ids after other sections.
local dmm='../Dawnwalker/ue4ss/Mods/DawnwalkerModMenu/Scripts/'
local probe=io.open(dmm..'choices.lua','rb')
if not probe then print('SKIP DawnwalkerModMenu is not installed beside this workspace');return end
probe:close()
local Choices=assert(loadfile(dmm..'choices.lua'))()
local manifest=table.concat({
    '[Mod]','Id=Pinned','',
    '[Setting]','Type=picker','Label=First','Default=0','PresetValues=0|1','PresetLabels=A|B',
    '; [Setting] a commented header is not a section','',
    '[Category.Group]','VisibleWhen=setting_1','VisibleValues=1',
    '[Setting.Second]','Id=Second','Type=picker','Label=Second','Group=Group','Default=0','PresetValues=0|1','PresetLabels=Off|On',
    '[Setting]','Type=integer','Label=Third','Group=Group','Minimum=0','Maximum=9','Step=1','Default=1',
}, '\n')
local items=Choices.parse(manifest)
local ours=Manifest.settings(manifest)
assert(#items==#ours,'the same number of settings')
for n,item in ipairs(items) do
    assert(item.id==ours[n].id,'setting '..n..': DMM '..tostring(item.id)..', manifest reader '..tostring(ours[n].id))
end
print('PASS setting ids match DMM\'s parser')
