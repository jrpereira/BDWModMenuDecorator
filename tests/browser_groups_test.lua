package.path='Scripts/?.lua;Scripts/vendor/?.lua;'..package.path
local Groups=require('browser_groups')
local Tax=require('mcs_taxonomy').new(require('mcs_taxonomy_data'))

local function ids(list)
    local out={}
    for n,provider in ipairs(list) do out[n]=provider.id end
    return table.concat(out,',')
end
local function expect(list,wanted,message)
    assert(ids(list)==wanted,(message or 'order')..': '..ids(list)..' ~= '..wanted)
end

-- Without a taxonomy, mods sharing a mod.json group form a collection and mods sharing an
-- author an author group; groups of one join the plain list. Groups follow the load order
-- of their first mod. A child page follows its parent; mods without settings fold into a
-- final entry. Every mod follows the same rules: there is no ModCore group of its own.
local providers={
    {id='Other',name='Other',author='Solo'},
    {id='ModCoreControls',name='Controls',mcListGroup='ModCore'},
    {id='Bob.one',name='Bob One',author='Bob'},
    {id='ModCoreSettings',name='Settings',mcListGroup='ModCore'},
    {id='Bob.two',name='Bob Two',author=' Bob '},
    {id='Declared',name='Declared',author='Ann',mcListGroup='alpha'},
    {id='Declared.child',name='Child',mcBrowserLevel=4},
    {id='Quiet',name='Quiet',mcListGroup='alpha',noSettings=true},
    {id='Detected',name='Folder',detectedKind='ue4ss',noSettings=true,author='Unknown'},
}
Groups.arrange(providers)
local listed='ModCore.browser.group.list:ModCore,ModCoreControls,ModCoreSettings,'
    ..'ModCore.browser.group.list:Bob,Bob.one,Bob.two,'
    ..'ModCore.browser.group.list:alpha,Declared,Declared.child,Quiet,ModCore.browser.group.list:alpha.more,'
    ..'ModCore.browser.group.various,Other,Detected,ModCore.browser.group.various.more'
expect(providers,listed)
local byId={};for _,provider in ipairs(providers) do byId[provider.id]=provider end
local modcore=byId['ModCore.browser.group.list:ModCore']
assert(modcore.name=='ModCore' and modcore.mcBrowserKind=='Collection' and modcore.mcBrowserIcon=='⁂'
    and modcore.mcBrowserHeading and modcore.noSettings,'a shared mod.json group is a collection')
assert(byId['ModCore.browser.group.list:Bob'].mcBrowserKind=='Author','a shared author is an author group')
assert(byId.ModCoreControls.mcBrowserLine=='cell' and byId['Bob.one'].mcBrowserLine=='row'
    and byId['Declared.child'].mcBrowserLine=='cell','declared groups sit in a grid, author groups in rows')
assert(byId.Quiet.mcBrowserFolded=='list:alpha' and byId.Detected.mcBrowserFolded=='various'
    and not byId.Declared.mcBrowserFolded,'mods without settings fold')
local more=byId['ModCore.browser.group.list:alpha.more']
assert(more.mcBrowserMore=='list:alpha' and more.name=='… and 1 more with no settings' and not more.noSettings
    and more.mcBrowserLine=='row','the folded entry closes its group')
assert(byId['ModCore.browser.group.various'].name=='Various Authors' and providers.mcModuleCount==8)
Groups.arrange(providers)
expect(providers,listed,'arranging again is stable')
local single={{id='Other',name='Other'}}
Groups.arrange(single)
expect(single,'ModCore.browser.group.various,Other')
local flat={{id='A',name='A',author='X'},{id='B',name='B',author='X'}}
Groups.arrange(flat,nil,nil,{groupModules=false})
expect(flat,'A,B','without grouping the list is plain')
print('PASS mods group by collection or author, with no ModCore special case')

-- A mod folder's mod.json gives its group, settings, identity and dependencies.
local manifests={['Mods/Grouped/mod.json']='{"id":"G","name":"Grouped Mod","author":"Ann","version":"2.0",'
        ..'"group":"ModCore","icon":"⟴","dependencies":[{"id":"ModCoreSettings","name":"MCS","version":"9"},'
        ..'{"id":"Other"}]}',
    ['Mods/Quiet/mod.json']='{"id":"Q","settings": false}'}
local function openManifest(path)
    local content=manifests[path]
    return content and {read=function() return content end,close=function() end} or nil
end
local folderManifest=Groups.folderManifest('Mods/',openManifest)
local grouped=folderManifest('Grouped')
assert(grouped.group=='ModCore' and grouped.settings==nil and grouped.name=='Grouped Mod' and grouped.version=='2.0'
    and grouped.icon=='⟴' and grouped.requires.ModCoreSettings and grouped.requires.Other
    and folderManifest('Quiet').settings==false and folderManifest('Quiet').group==nil
    and next(folderManifest('Missing'))==nil and not pcall(folderManifest,'../x'))
local folders={
    {id='detected:grouped',name='Grouped',detectedKind='ue4ss',noSettings=true,author='Unknown'},
    {id='detected:quiet',name='Quiet',detectedKind='ue4ss',noSettings=true,author='Unknown'},
    {id='MCT.module.Grouped',name='Grouped',author='ModCoreTemplates',mcContribution='MCT',
        mcFolder='Grouped',mcModuleEntry=true,choices={{id='x'}}},
    {id='MCT.extra',name='Extra',author='ModCoreTemplates',mcContribution='MCT',mcFolder='Quiet',choices={{id='y'}}},
}
Groups.arrange(folders,nil,nil,{folderManifest=folderManifest,
    folderVersion=function(folder) return folder=='Quiet' and '1.0.12' or nil end})
byId={};for _,provider in ipairs(folders) do byId[provider.id]=provider end
assert(byId['detected:grouped'].name=='Grouped Mod' and byId['detected:grouped'].author=='Ann'
    and byId['detected:grouped'].version=='2.0' and byId['detected:grouped'].mcBrowserIcon=='⟴',
    'a detected mod takes its folder identity')
assert(byId['detected:quiet'].mcNoSettingsDeclared and byId['detected:quiet'].version=='1.0.12'
    and byId['detected:quiet'].description=='Quiet has no settings to change.')
assert(byId['MCT.module.Grouped'].name=='Grouped Mod' and byId['MCT.module.Grouped'].version=='2.0',
    'a contributed page standing in for a mod takes its folder identity')
assert(byId['MCT.extra'].name=='Extra' and byId['MCT.extra'].author=='ModCoreTemplates',
    'a page that does not stand in for a mod keeps its own')
print('PASS mod.json gives each folder its group, identity and dependencies')

-- MCS's own page carries the index tabs: Installed (every module depending on
-- ModCoreSettings, and MCS itself), Errors and Developer Tools. Tool pages stay among the
-- providers so links open them, but are not listed while the tabs reach them.
local host='[Mod]\nId=ModCoreSettings\n\n[Setting.MCS_Page]\nId=MCS_Page\nType=picker\n'
local reads=0
local function read(path) reads=reads+1;assert(path=='/mods/1_ModCore_Settings/mod_settings.ini');return host end
local parsed
local function parse(manifest) parsed=manifest;return {{id='MCS_Page'},{id='row'}} end
local dependants={['Mods/2_Controls/mod.json']='{"name":"ModCore Controls","dependencies":[{"id":"ModCoreSettings"}]}',
    ['Mods/9_Fangdango/mod.json']='{"name":"Quickslot Fangdango","dependencies":[{"id":"ModCoreSettings"}]}',
    ['Mods/7_Unrelated/mod.json']='{"name":"Unrelated"}'}
local folderFields=Groups.folderManifest('Mods/',function(path)
    local content=dependants[path]
    return content and {read=function() return content end,close=function() end} or nil
end)
local indexed={
    {id='ModCoreSettings',name='Settings',path='/mods/1_ModCore_Settings/mod_settings.ini',version='1.0.2'},
    {id='ModCoreControls',name='ModCore Controls',path='/mods/2_Controls/mod_settings.ini',version='v1.0.3'},
    {id='detected:fangdango',name='9_Fangdango',detectedKind='ue4ss',noSettings=true},
    {id='Unrelated',name='Unrelated',path='/mods/7_Unrelated/mod_settings.ini'},
    {id='ModCoreDevTools.sounds',name='Sounds Explorer',mcBrowserGroup='tool'},
}
Groups.arrange(indexed,parse,nil,{folderManifest=folderFields,read=read,pageVersions={}})
local mcs=indexed[1].id=='ModCoreSettings' and indexed[1]
for _,provider in ipairs(indexed) do if provider.id=='ModCoreSettings' then mcs=provider end end
assert(mcs.mcManifest==parsed and mcs.settingsCount==2 and mcs.choicesLoaded and not mcs.deferred
    and mcs.mcBaseManifest==host and mcs.mcManifest:sub(1,#host-1)==host:sub(1,-2),'the host page gains the tabs')
local function at(text) return assert(parsed:find(text,1,true),text) end
assert(at('[Category.Installed]\nVisibleWhen=MCS_Page\nVisibleValues=3\n')<at('Label=ModCore Controls v1.0.3')
    and at('Label=ModCore Controls v1.0.3')<at('Label=Quickslot Fangdango')
    and at('Label=Quickslot Fangdango')<at('Label=Settings v1.0.2')
    and not parsed:find('Unrelated',1,true),'Installed lists ModCoreSettings and its dependants by name')
assert(parsed:find('mcLinkPage=ModCoreControls\n',1,true)
    and parsed:find('Label=Quickslot Fangdango\nGroup=Installed\nType=picker\nDefault=0\nPresetValues=0|1\n'
        ..'PresetLabels=No settings|No settings',1,true),'a module without a page shows as having no settings')
assert(at('[Category.Errors]\nVisibleWhen=MCS_Page\nVisibleValues=4\nmcHeading=0\n') and at('mcText=errors'),
    'the Errors tab shows the errors text source')
assert(at('[Category.Developer Tools]\nVisibleWhen=MCS_Page\nVisibleValues=5\n')<at('Label=Sounds Explorer')
    and at('mcLinkPage=ModCoreDevTools.sounds'),'Developer Tools lists the tool pages')
local tool
for _,provider in ipairs(indexed) do if provider.id=='ModCoreDevTools.sounds' then tool=provider end end
assert(tool.mcBrowserHidden and indexed[#indexed]==tool,'tool pages stay listed last, hidden')
Groups.arrange(indexed,parse,nil,{folderManifest=folderFields,read=read})
assert(reads==1 and select(2,mcs.mcManifest:gsub('%[Category%.Installed%]',''))==1,
    'the base manifest is read once and the tabs are never appended twice')
local failures={}
local broken={{id='ModCoreSettings',name='Settings',path='/x'},{id='T',name='Tool',mcBrowserGroup='tool'}}
Groups.arrange(broken,function() error('bad manifest') end,function(event) failures[#failures+1]=event end,
    {read=function() return host end})
assert(failures[1]=='BROWSER_INDEX_FAILED' and not broken[#broken].mcBrowserHidden,
    'without the tabs a tool page is listed so it stays reachable')
print('PASS MCS\'s own page carries the Installed, Errors and Developer Tools tabs')

-- With the taxonomy, a mod is listed under each top category its categories belong to,
-- walked by category in taxonomy order then load order. Collections follow the top
-- categories, in the load order of their first mod; a preferred category is declared first.
local register={
    Gear=Tax:entry({categories={'gear'},tags={}}),
    Audio=Tax:entry({categories={'audio'},tags={}}),
    Both=Tax:entry({categories={'gear','interface'},tags={}}),
    Core1=Tax:entry({categories={'frameworks'},tags={},preferred='ModCore'}),
    Core2=Tax:entry({categories={'tools'},tags={},preferred='ModCore'}),
    Ann=Tax:entry({categories={'tools'},tags={},preferred='Ann'}),
    Ann2=Tax:entry({categories={'tools'},tags={},preferred='Ann'}),
    Lone=Tax:entry({categories={'tools'},tags={},preferred='Lonely'}),
    Prefers=Tax:entry({categories={'audio'},tags={},preferred='frameworks'}),
}
local function mod(id,settings) return {id=id,name=id,mcFolder=id,noSettings=not settings} end
local taxed={mod('Both',true),mod('Audio',true),mod('Gear',true),mod('Core1',true),mod('Ann',true),
    mod('Core2',true),mod('Ann2',true),mod('Lone',true),mod('Prefers',true)}
for _,provider in ipairs(taxed) do provider.choices={{id='x'}} end
local authors={Ann='Ann',Ann2='Ann'}
Groups.arrange(taxed,nil,nil,{taxonomy=Tax,categoryRegister=register,preferredMinimum=2,
    folderManifest=function(folder) return {author=authors[folder]} end})
expect(taxed,'ModCore.browser.group.section:content,Both,Gear,'
    ..'ModCore.browser.group.section:presentation,Both,Audio,Prefers,'
    ..'ModCore.browser.group.section:support,Prefers,Lone,'
    ..'ModCore.browser.group.preferred:ModCore,Core1,Core2,'
    ..'ModCore.browser.group.preferred:Ann,Ann,Ann2','top categories, then collections')
byId={};for _,provider in ipairs(taxed) do byId[provider.id]=provider end
local content=byId['ModCore.browser.group.section:content']
assert(content.mcBrowserKind=='Content' and content.mcBrowserIcon=='◆'
    and content.name==Tax.definitions.gear.description,'a top category heading names its categories present')
local presentation=byId['ModCore.browser.group.section:presentation']
assert(presentation.name==Tax.definitions.interface.description..' and '..Tax.definitions.audio.description,
    'titles join the categories present in taxonomy order')
assert(byId['ModCore.browser.group.preferred:ModCore'].mcBrowserKind=='Collection'
    and byId['ModCore.browser.group.preferred:Ann'].mcBrowserKind=='Author'
    and byId['ModCore.browser.group.preferred:Ann'].mcBrowserIcon=='⁂','collections and author groups')
assert(taxed.mcModuleCount==9,'module totals count distinct folders')
print('PASS top categories walk categories in order, then collections; a preferred category counts first')

-- DMM shows each row of its mod list and links its navigation itself.
local function widget()
    local w={visibility=0}
    function w:SetVisibility(v) self.visibility=v end
    function w:SetNavigationRuleExplicit(rule,target) self['rule'..rule]=target end
    function w:SetNavigationRuleBase(rule) self['rule'..rule]='base' end
    return w
end
local function browserPages()
    local pages={}
    pages.build=function(_,items)
        local page={allRows={},rows={},empty=widget(),scroll={ScrollToStart=function() end},opened={}}
        for index in ipairs(items) do page.allRows[index]={providerIndex=index,wrapper=widget(),widget=widget()} end
        function page:setFilter(compatibleOnly)
            self.compatibleOnly=compatibleOnly
            self.rows={}
            for _,row in ipairs(self.allRows) do
                local visible=not compatibleOnly or not items[row.providerIndex].noSettings
                row.wrapper:SetVisibility(visible and 0 or 1)
                if visible then self.rows[#self.rows+1]=row end
            end
        end
        function page:showDetail(index) self.opened[#self.opened+1]=items[self.rows[index].providerIndex].id end
        function page:refreshHint() end
        page:setFilter(false)
        return page
    end
    return pages
end
-- Mods without settings stay folded until the group's last entry is selected.
local folding=browserPages()
assert(Groups.install(folding) and not Groups.install(folding))
local browsing=folding.build({},{{id='A',name='A',author='X',choices={{id='a'}}},{id='B',name='B',author='X',noSettings=true},
    {id='C',name='C',author='X',noSettings=true}},nil,{})
local function shown(page)
    local out={}
    for _,row in ipairs(page.rows) do out[#out+1]=row end
    return #out
end
assert(shown(browsing)==3 and browsing.allRows[3].wrapper.visibility==1 and browsing.allRows[4].wrapper.visibility==1
    and browsing.allRows[5].wrapper.visibility==0,'a heading, the mod with settings and the folded entry')
assert(browsing.allRows[1].widget.rule3==browsing.allRows[2].widget,'navigation links the shown rows')
browsing:showDetail(3)
assert(#browsing.opened==0 and shown(browsing)==4 and browsing.allRows[3].wrapper.visibility==0
    and browsing.allRows[5].wrapper.visibility==1,'selecting the folded entry lists the mods and opens nothing')
browsing:showDetail(2)
assert(browsing.opened[1]=='A','other entries open their page')
browsing:setFilter(true)
assert(shown(browsing)==2 and browsing.allRows[5].wrapper.visibility==1,'compatible mods: nothing is folded or listed without settings')
-- A mod that declares it has no settings stays listed among compatible mods.
local quietPages=browserPages()
assert(Groups.install(quietPages,nil,nil,nil,function(folder) return folder=='Quiet' and {settings=false} or {} end))
local quiet=quietPages.build({},{{id='Quiet',name='Quiet',noSettings=true,detectedKind='ue4ss'},
    {id='Loud',name='Loud',noSettings=true,detectedKind='ue4ss'}},nil,{})
quiet:showDetail(#quiet.rows)
quiet:setFilter(true)
assert(#quiet.rows==2 and quiet.rows[2].providerIndex==2,'compatible mods keep a declared mod and its heading')
print('PASS the folded entry lists mods without settings and opens nothing')

-- Taxonomy filtering combines independent category and tag sets.
local filterPages={build=function(_,items)
    local page={allRows={},rows={},empty=widget(),scroll={ScrollToStart=function() end}}
    for index in ipairs(items) do page.allRows[index]={providerIndex=index,wrapper=widget(),widget=widget()} end
    function page:setFilter(only) self.compatibleOnly=only;self.rows=self.allRows end
    function page:refreshHint() end
    return page
end}
local multi={id='Multi',name='Multi',mcFolder='Multi',choices={{id='same-setting'}}}
local solo={id='Single',name='Single',mcFolder='Single',choices={{id='s'}}}
local entries={Multi=Tax:entry({categories={'gear','appearance'},tags={'fix'},icon='♞'}),
    Single=Tax:entry({categories={'audio'},tags={}})}
Groups.install(filterPages,nil,nil,nil,nil,function()
    return {taxonomy=Tax,categoryRegister=entries,preferredMinimum=0}
end)
local placements={multi,solo}
local filtered=filterPages.build({},placements,nil,{})
assert(#filtered.rows==5 and filtered.mcModuleCount==2 and multi.mcBrowserLabel=='♞  Multi')
filtered:setTagFilter({'fix'},'all');assert(#filtered.rows==4)
filtered:setCategoryFilter({'audio'},'any');assert(#filtered.rows==0 and filtered.empty.visibility==0)
filtered:setTagFilter({},'any');assert(#filtered.rows==2)
filtered:setCategoryFilter({'gear','appearance'},'all');assert(#filtered.rows==4)
filtered:setCategoryFilter({},'any');filtered:setFilter(false);assert(#filtered.rows==5)
assert(not pcall(filtered.setCategoryFilter,filtered,{'vehicles'},'any'))
print('PASS taxonomy row filtering combines independent category/tag sets')

-- Through DMM's real parser the host page's tabs parse and open without a config file.
local choicesPath=os.getenv('DMM_CHOICES_PATH')
if not choicesPath then print('SKIP index tabs parse: DMM_CHOICES_PATH is not set');return end
local Choices=dofile(choicesPath)
assert(require('navigation').install(Choices))
local Presentation=require('presentation')
local base=assert(io.open('mod_settings.ini','rb')):read('a')
local hostPage={{id='ModCoreSettings',name='Settings',path='/x/mod_settings.ini'},
    {id='ModCoreControls',name='Controls',path='/m/2_Controls/mod_settings.ini'},
    {id='Tool',name='Sounds Explorer',mcBrowserGroup='tool'}}
Groups.arrange(hostPage,function(manifest) return Presentation.parse(manifest,Choices.parse(manifest)) end,nil,
    {read=function() return base end,folderManifest=folderFields})
local page
for _,provider in ipairs(hostPage) do if provider.id=='ModCoreSettings' then page=provider end end
local items={};for _,item in ipairs(page.choices) do items[item.id]=item end
assert(items.MCS_Page and #items.MCS_Page.values==6 and items.MCS_Page.labels[4]=='Installed'
    and items.MCS_Index_Errors.mcText=='errors' and items.MCS_Index_1.mcLinkPage,
    'the tabs parse through DMM beside the page\'s own settings')
print('PASS the index tabs parse through DMM')
