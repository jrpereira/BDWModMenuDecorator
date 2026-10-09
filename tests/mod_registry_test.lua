package.path='Scripts/?.lua;'..package.path
local R=require('mcs_mod_registry')
local T=require('mcs_fingerprint_text')
assert(T.normalize('E\204\129 STRA\225\186\158E\t\234\176\128')=='é strasse 가')
assert(T.anchor('É X²_１２')=='éx²１２')
assert(R.key('settings-label-v1',{' Keep blood red ','KEEP BLOOD RED'})=='["settings-label-v1",["keep blood red"]]')
local db=require('mod_fingerprints')
local files={'mod_settings.ini','Scripts/main.lua','Scripts/dmm_api.lua','backup/main.lua','x.bak/main.lua'}
local contents={['/mods/Renamed/mod_settings.ini']='[Mod]\nId=694\nName=ignored\nAuthor=oOCamilleOo\nUrl=ignored\n'
    ..'PresetLabels=Radius|Fullscreen|Natural\nLabel=Keep blood red\n',
    ['/mods/Renamed/Scripts/main.lua']='local AutoExposureBias=1',
    ['/mods/Renamed/Scripts/dmm_api.lua']='unreadable excluded helper'}
local read=function(path) assert(contents[path]~=nil,'unexpected read: '..path);return contents[path] end
local tokens=R.tokens('/mods/Renamed',files,read,{ignoreFolderName=true})
local category,ids,status=R.match(tokens,db)
assert(category=='visuals' and #ids==1 and ids[1]==694 and status=='matched','distinctive controls beat the shared weak clue')
assert(not tokens[R.key('lua-identifier-v1',{'unreadable'})],'helpers and backup files were not read')
local synthetic=R.tokens('/mods/Random',{'zzz_FastTravelAnywhere_P.pak','zzz_FastTravelAnywhere_P.utoc'},read)
assert(R.match(synthetic,db)=='other','title anchor remains a weak candidate')
synthetic=R.tokens('/mods/Random',{'zzz_FastTravelAnywhere_P.pak','zzz_FastTravelAnywhere_P.utoc','zzz_FastTravelAnywhere_P.ucas'},read)
local _,_,complete=R.match(synthetic,db);assert(complete=='matched')
local ambiguous={categories={'other','gear','items'},modules={
    {id=1,category=2,fingerprints={{kind='settings-label-v1',values={'shared'},group='x',strength='weak'}}},
    {id=2,category=3,fingerprints={{kind='settings-label-v1',values={'shared'},group='x',strength='weak'}}}}}
assert(R.match({[R.key('settings-label-v1',{'shared'})]=true},ambiguous)=='other')
local skipped=setmetatable({__absolute_path='/mods/Known'}, {__pairs=function() error('registered folder traversed') end})
local snapshot={__absolute_path='/mods',Known=skipped,New={Scripts={__files={{__name='main.lua'}}}}}
local folders=R.folders(snapshot,'/mods',{Known={category='Utilities'}})
assert(#folders==2 and #folders[1].files==0 and folders[2].files[1]=='Scripts/main.lua','known folders skip traversal')
local authorOnly=R.tokens('/mods/Renamed',{'mod_settings.ini'},function()
    return '[Mod]\nAuthor=oOCamilleOo\n'
end,{ignoreFolderName=true})
local _,_,authorStatus=R.match(authorOnly,db);assert(authorStatus=='unmatched','author alone is insufficient')
local direct=R.tokens('/mods/Renamed',{'mod.json'},function()
    return '{"author":"different","links":{"nexus":"http://nexusmods.com/thebloodofdawnwalker/mods/694?tab=files"}}'
end,{ignoreFolderName=true})
local _,directIds,directStatus=R.match(direct,db)
assert(directStatus=='matched' and #directIds==1 and directIds[1]==694,'canonical direct link alone identifies a module')
local relaxed=R.tokens('/mods/Renamed',{'mod_settings.ini','Scripts/main.lua'},function(path)
    return path:match('%.ini$') and '[Mod]\nAuthor=oOCamilleOo\nLabel=Keep blood red\n' or ''
end,{ignoreFolderName=true})
local _,relaxedIds=R.match(relaxed,db);assert(#relaxedIds==1 and relaxedIds[1]==694,'author relaxes a compound group to one matching clue')
local wrong=R.tokens('/mods/Renamed',{'mod_settings.ini','Scripts/main.lua'},function(path)
    return path:match('%.ini$') and '[Mod]\nAuthor=unrelated author\n' or 'local AutoExposureBias=0'
end,{ignoreFolderName=true})
local _,_,wrongStatus=R.match(wrong,db);assert(wrongStatus=='unmatched','conflicting author rejects weak clues')
local nested=R.tokens('/mods/Renamed',{'mod.json'},function()
    return '{"dependencies":[{"links":{"nexus":"https://www.nexusmods.com/thebloodofdawnwalker/mods/694"}}]}'
end,{ignoreFolderName=true})
local _,_,nestedStatus=R.match(nested,db);assert(nestedStatus=='unmatched','dependency links are not identity')
print('PASS category fingerprints, manifest priority, cache persistence, ambiguity and skipped folders')


local Metadata=require('mcs_mod_metadata')
local manifest=Metadata.decode([[-- Declarative author metadata
browser: {preferred: author, categories: {'content','gear','appearance'}, tags: {'adult','fix'}, icon: {utf8: '♞'}},
author: 'Example Author'
]])
assert(manifest.browser.categories[2]=='gear' and manifest.browser.preferred=='author')
assert(not pcall(Metadata.decode,'browser: os.execute("anything")'),'metadata is never executable Lua')
assert(not pcall(Metadata.decode,"browser: {tags: {'adult'}}, browser: {}"),'duplicate metadata fields rejected')
local cache='/mods/1_ModCore_Settings/cache/modules_register.json'
local bootDisk={
 ['/mods/New/mod.txt']=[[browser: {categories: {'gear','appearance'}, tags: {'fix'}, preferred: author, icon: {utf8: '♞'}}, author: 'Example Author']],
 ['/mods/Bad/mod.json']='{"browser":{"categories":["combat"]}}',
 ['/mods/Heuristic/Scripts/main.lua']='SkillTimeCost=0',
 ['/mods/Unknown/Scripts/main.lua']='local object={}',
 ['/mods/New/Scripts/main.lua']='error("never execute inspected scripts")',
}
local writes,enumerations,issues=0,0,0
local opts={database=db,mkdir=function(path) assert(path=='/mods/1_ModCore_Settings/cache') end,
 read=function(path) return bootDisk[path] end,
 write=function(path,value) assert(path==cache);writes=writes+1;bootDisk[path]=value end,
 report=function(folder) assert(folder=='Bad');issues=issues+1 end}
local function enumerate()
 enumerations=enumerations+1
 return {__absolute_path='/mods',New={__files={{__name='mod.txt'}},Scripts={__files={{__name='main.lua'}}}},
 Bad={__files={{__name='mod.json'}}},Heuristic={Scripts={__files={{__name='main.lua'}}}},
 Unknown={Scripts={__files={{__name='main.lua'}}}}}
end
local index=R.boot('/mods/1_ModCore_Settings','/mods',enumerate,opts)
assert(writes==1 and issues==1 and enumerations==1)
assert(index.modules.New.parents[1]=='content' and index.modules.New.parents[2]=='presentation')
assert(index.modules.New.preferred=='Example Author' and index.modules.New.icon=='♞')
assert(index.modules.New.tags[1]=='fix' and index.modules.Heuristic.categories[1]=='progression')
assert(index.modules.Unknown.reason=='insufficient_evidence' and not index.modules.Bad)
local before=writes;R.boot('/mods/1_ModCore_Settings','/mods',enumerate,opts)
assert(writes==before and issues==2,'cache entries persist and malformed declarations retry')
bootDisk[cache]='{"Heuristic":{"category":"combat","preferred":"Old custom group"}}'
index=R.boot('/mods/1_ModCore_Settings','/mods',enumerate,opts)
assert(index.schema_version==2 and index.modules.Heuristic.categories[1]=='progression')
assert(index.modules.Heuristic.preferred=='Old custom group','migration preserves a custom preferred group')
assert(R.decode(bootDisk[cache]).modules.New.categories[1]=='gear')
print('PASS data-only mod.txt, author preference, canonical metadata, multi-category cache, heuristics, retries and legacy reclassification')
