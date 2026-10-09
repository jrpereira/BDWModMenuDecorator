package.path='Scripts/?.lua;Scripts/vendor/?.lua;'..package.path
local Groups=require('browser_groups')

-- Every page is grouped: ModCore (its core pages and the mods that declare it) first, then
-- each group of several mods (its declared group, else its author) by name, then Various
-- Authors. Declared mods sit in a grid ('cell'); any other takes a row of its own.
local providers={
    {id='Other',name='Other',author='Solo'},
    {id='ModCoreControls',name='Controls'},
    {id='Bob.one',name='Bob One',author='Bob'},
    {id='MCT.module.VisualExample',name='Visual Example',mcBrowserGroup='module',mcListGroup='ModCore'},
    {id='ModCoreSettings',name='Visuals'},
    {id='Bob.two',name='Bob Two',author=' Bob '},
    {id='Declared',name='Declared',author='Ann',mcListGroup='alpha'},
    {id='Declared.child',name='Child',mcBrowserLevel=4},
    {id='Detected',name='Folder',detectedKind='ue4ss',noSettings=true,author='Unknown'},
    {id='ExampleOverlay',name='Example Overlay',mcBrowserGroup='module'},
}
Groups.arrange(providers)
local expected={'ModCore.browser.root','ModCoreControls','ModCoreSettings','MCT.module.VisualExample',
    'ModCore.browser.group.alpha','Declared','Declared.child','ModCore.browser.group.Bob','Bob.one','Bob.two',
    'ModCore.browser.group.various','Other','Detected','ExampleOverlay'}
local lines={'head','cell','cell','cell','head','cell','cell','head','row','row','head','row','row','row'}
local function check(list)
    assert(#list==#expected)
    for index,id in ipairs(expected) do
        assert(list[index].id==id,id)
        assert(list[index].mcBrowserLine==lines[index],id..' line')
    end
end
check(providers)
assert(providers[1].name=='ModCore' and providers[1].noSettings)
assert(providers[5].name=='alpha' and providers[5].mcBrowserHeading and providers[11].name=='Various Authors')
assert(providers[2].mcBrowserLevel==4 and providers[9].mcBrowserIndent==20 and providers[8].mcBrowserLevel==2)
Groups.arrange(providers)
check(providers)

local bare={{id='Other',name='Other'}}
Groups.arrange(bare)
assert(#bare==2 and bare[1].name=='Various Authors' and bare[2].id=='Other')

local pages={build=function(_,items) return items end}
assert(Groups.install(pages) and not Groups.install(pages))
local built=pages.build({},{{id='ModCoreSettings',name='Visuals'}},nil,{})
assert(#built==2 and built[1].name=='ModCore' and built[2].name=='Visuals')

-- A mod folder's mod.json gives its group and whether it has settings; a detected folder of
-- a foundation module is ModCore's and has none.
local manifests={['Mods/Grouped/mod.json']='{"id":"G","name":"Grouped Mod","author":"Ann","version":"2.0",'
        ..'"group":"ModCore","dependencies":[{"id":"X","name":"Dependency","version":"9"}]}',
    ['Mods/Quiet/mod.json']='{"id":"Q","settings": false}'}
local function openManifest(path)
    local content=manifests[path]
    return content and {read=function() return content end,close=function() end} or nil
end
local folderManifest=Groups.folderManifest('Mods/',openManifest)
assert(folderManifest('Grouped').group=='ModCore' and folderManifest('Grouped').settings==nil
    and folderManifest('Grouped').name=='Grouped Mod' and folderManifest('Grouped').version=='2.0'
    and folderManifest('Quiet').name==nil
    and folderManifest('Quiet').settings==false and folderManifest('Quiet').group==nil
    and next(folderManifest('Missing'))==nil and not pcall(folderManifest,'../x'))
local folders={
    {id='detected:grouped',name='Grouped',detectedKind='ue4ss',noSettings=true,author='Unknown'},
    {id='detected:quiet',name='Quiet',detectedKind='ue4ss',noSettings=true,author='Unknown'},
    {id='detected:bridge',name='0_ModCore_UE4SSLuaEventBridge',detectedKind='ue4ss',noSettings=true,author='Unknown'},
    {id='Page',name='Page',path='C:/Mods/Grouped/mod_settings.ini'},
}
Groups.arrange(folders,nil,nil,{folderManifest=folderManifest,
    folderVersion=function(folder) return folder=='0_ModCore_UE4SSLuaEventBridge' and '1.0.12' or nil end})
local byId={};for _,provider in ipairs(folders) do byId[provider.id]=provider end
assert(byId['detected:grouped'].mcBrowserLine=='cell' and byId.Page.mcBrowserLine=='cell'
    and byId['detected:bridge'].mcBrowserLine=='cell' and byId['detected:bridge'].mcNoSettingsDeclared
    and byId['detected:bridge'].mcBrowserLabel=='Lua Event Bridge' and byId['detected:bridge'].version=='1.0.12'
    and byId['detected:bridge'].description=='Lua Event Bridge has no settings to change.'
    and byId['detected:bridge'].mcFolder=='0_ModCore_UE4SSLuaEventBridge'
    and byId['detected:grouped'].name=='Grouped Mod' and byId['detected:grouped'].author=='Ann'
    and byId['detected:grouped'].version=='2.0' and byId.Page.name=='Page'
    and byId['detected:quiet'].mcBrowserLine=='row' and byId['detected:quiet'].mcNoSettingsDeclared
    and not byId['detected:grouped'].mcNoSettingsDeclared,'mod.json groups and settings apply')

print('PASS ModCore browser groups Controls, Visuals and module pages')

-- DMM shows each row of its mod list and links its navigation itself.
local function widget()
    local w={visibility=0}
    function w:SetVisibility(v) self.visibility=v end
    function w:SetNavigationRuleExplicit(rule,target) self['rule'..rule]=target end
    function w:SetNavigationRuleBase(rule) self['rule'..rule]='base' end
    return w
end
local currentPages={}
currentPages.build=function(_,items)
    local page={allRows={},rows={},empty=widget(),scroll={ScrollToStart=function() end}}
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
    function page:refreshHint() end
    page:setFilter(true)
    return page
end
assert(Groups.install(currentPages))
local current=currentPages.build({},{{id='ModCoreControls',name='Controls'},{id='Other',name='Other',noSettings=true}},nil,{})
local heading,controls,other=current.allRows[1],current.allRows[2],current.allRows[3]
assert(#current.rows==2 and current.rows[1]==heading and current.rows[2]==controls)
assert(heading.wrapper.visibility==0 and controls.wrapper.visibility==0 and other.wrapper.visibility==1,
    'the ModCore heading stays visible beside its pages')
assert(heading.widget.rule2=='base' and heading.widget.rule3==controls.widget
    and controls.widget.rule2==heading.widget and controls.widget.rule3=='base')
assert(current.empty.visibility==1)
-- A mod that declares it has no settings stays listed, with its group heading.
local quietPages={build=currentPages.build}
assert(Groups.install(quietPages,nil,nil,nil,function(folder)
    return folder=='Quiet' and {settings=false} or {}
end))
local quiet=quietPages.build({},{{id='Quiet',name='Quiet',noSettings=true,detectedKind='ue4ss'},
    {id='Loud',name='Loud',noSettings=true,detectedKind='ue4ss'}},nil,{})
assert(#quiet.rows==2 and quiet.allRows[1].wrapper.visibility==0 and quiet.allRows[2].wrapper.visibility==0
    and quiet.allRows[3].wrapper.visibility==1,'compatible mods keep a declared mod and its heading')
print('PASS compatible-only filtering keeps the ModCore headings visible and linked')

local Tax=require('mcs_taxonomy').new(require('mcs_taxonomy_data'))
-- Use DMM's unwrapped row builder so taxonomy filtering is exercised directly.
local filterPages={build=function(_,items)
    local page={allRows={},rows={},empty=widget(),scroll={ScrollToStart=function() end}}
    for index in ipairs(items) do page.allRows[index]={providerIndex=index,wrapper=widget(),widget=widget()} end
    function page:setFilter(only) self.compatibleOnly=only;self.rows=self.allRows end
    function page:refreshHint() end
    return page
end}
local multi={id='Multi',name='Multi',mcFolder='Multi',choices={{id='same-setting'}}}
local single={id='Single',name='Single',mcFolder='Single',choices={}}
local entries={Multi=Tax:entry({categories={'gear','appearance'},tags={'fix'},icon='♞'}),
    Single=Tax:entry({categories={'audio'},tags={}})}
Groups.install(filterPages,nil,nil,nil,nil,function()
    return {taxonomy=Tax,categoryRegister=entries,preferredMinimum=0,categoryDescriptions=Tax.descriptions}
end)
local placements={multi,single}
local filtered=filterPages.build({},placements,nil,{})
assert(#filtered.rows==5 and filtered.mcModuleCount==2 and multi.mcBrowserLabel=='♞  Multi')
filtered:setTagFilter({'fix'},'all');assert(#filtered.rows==4)
filtered:setCategoryFilter({'audio'},'any');assert(#filtered.rows==0 and filtered.empty.visibility==0)
filtered:setTagFilter({},'any');assert(#filtered.rows==2 and filtered.rows[2].providerIndex==5)
filtered:setCategoryFilter({'gear','appearance'},'all');assert(#filtered.rows==4)
filtered:setCategoryFilter({},'any');filtered:setFilter(false);assert(#filtered.rows==5)
assert(not pcall(filtered.setCategoryFilter,filtered,{'vehicles'},'any'))
assert(placements[2]==placements[4] and placements[2].choices==multi.choices,'placements retain one provider and settings')
print('PASS taxonomy row filtering combines independent category/tag sets, keeps populated headings and shares settings')


-- With a parser, the ModCore heading is its own page: a Modules | Errors | Developer Tools tab
-- picker, then a link to each module page under User Modules and Foundation Modules.
local parsed={}
local linked={
    {id='Other',name='Other'},
    {id='ModCoreControls',name='Controls'},
    {id='ModCoreSettings',name='Visuals'},
    {id='ModCoreTemplates.module.Preymonition',name='Preymonition',mcBrowserGroup='module'},
}
Groups.arrange(linked,function(manifest) parsed[#parsed+1]=manifest;return {{id='ModCore_Page'}} end)
local page=linked[1]
assert(page.id=='ModCore.browser.root' and page.name=='ModCore' and not page.noSettings
    and not page.mcBrowserHeading and page.settingsCount==1 and page.mcManifest==parsed[#parsed],
    'the ModCore entry opens its own page')
local manifest=page.mcManifest
local function at(text) return assert(manifest:find(text,1,true),text) end
assert(at('PresetLabels=Modules|Errors|Developer Tools')<at('[Category.User Modules]')
    and at('[Category.User Modules]')<at('mcLinkPage=ModCoreTemplates.module.Preymonition')
    and at('mcLinkPage=ModCoreTemplates.module.Preymonition')<at('[Category.Foundation Modules]')
    and at('[Category.Foundation Modules]')<at('Label=ModCore Controls')
    and at('Label=ModCore Controls')<at('Label=ModCore Settings')
    and at('Label=ModCore Settings')<at('Label=ModCore Templates')
    and at('Label=ModCore Templates')<at('Label=ModCore Dev Tools')
    and at('Label=ModCore Dev Tools')<at('Label=Lua Event Bridge'),
    'Modules lists user modules, then every foundation module')
assert(not manifest:find('mcLinkPage=ModCoreTemplates\n',1,true) and not manifest:find('mcLinkPage=UE4SSLuaEventBridge',1,true)
    and not manifest:find('mcLinkPage=ModCoreDevelopers\n',1,true)
    and select(2,manifest:gsub('PresetLabels=No settings|No settings',''))==3,
    'a foundation module without a page shows as having no settings instead of a broken link')
assert(manifest:find('[Category.Errors]\nVisibleWhen=ModCore_Page\nVisibleValues=1\nmcHeading=0\n',1,true)
    and manifest:find('Id=ModCore_Errors\n',1,true) and manifest:find('mcReadOnly=1\nmcText=errors\n',1,true),
    'the Errors tab shows the errors text source')
local failures={}
local fallback={{id='ModCoreControls',name='Controls'}}
Groups.arrange(fallback,function() error('bad manifest') end,function(event) failures[#failures+1]=event end)
assert(fallback[1].noSettings and fallback[1].mcBrowserHeading and failures[#failures]=='BROWSER_ROOT_FAILED' and #fallback==2,
    'a page that cannot be built leaves the plain heading')
-- The Visuals page opens from its Modules link and is not listed; Controls still is.
-- MCS's own page is listed in the ModCore grid as Settings.
assert(linked[3].id=='ModCoreSettings' and not linked[3].mcBrowserHidden and linked[3].mcBrowserLabel=='☑  Settings'
    and not linked[2].mcBrowserHidden,'MCS shows as Settings')
print('PASS the ModCore heading opens a Modules, Errors and Developer Tools page')

-- Templates and Controls lead the ModCore grid with their short labels; module pages
-- follow after their icon. Templates' own pages follow it.
local lined={
    {id='ModCoreTemplates.module.Fangdango',name='Fangdango',mcBrowserGroup='module',mcBrowserIcon='F',
        mcListGroup='ModCore'},
    {id='ModCoreControls',name='Controls'},
    {id='ModCoreTemplates',name='ModCore Templates',mcContribution='ModCoreTemplates'},
    {id='ModCoreTemplates.example',name='Example',mcContribution='ModCoreTemplates',mcBrowserLevel=4},
    {id='ModCoreTemplates.module.Plain',name='Plain',mcBrowserGroup='module',mcListGroup='ModCore'},
    {id='Other',name='Other'},
}
Groups.arrange(lined,toolParse)
Groups.arrange(lined,toolParse)
local expectLined={'ModCore.browser.root','ModCoreTemplates','ModCoreControls','ModCoreTemplates.example',
    'ModCoreTemplates.module.Fangdango','ModCoreTemplates.module.Plain','ModCore.browser.group.various','Other'}
assert(#lined==#expectLined)
for index,id in ipairs(expectLined) do assert(lined[index].id==id,id) end
for index=2,6 do assert(lined[index].mcBrowserLine=='cell') end
assert(lined[2].mcBrowserLabel=='⌗  Templates' and lined[3].mcBrowserLabel=='❖  Controls'
    and lined[5].mcBrowserLabel=='F  Fangdango' and lined[6].mcBrowserLabel==nil)
-- A link page (ModCore Templates opening the Visuals slot) is listed, and its Modules
-- row opens that slot.
local linkedTemplates={{id='ModCoreTemplates',name='ModCore Templates',mcContribution='ModCoreTemplates',
    mcLinkSlot={address='controls:visuals'}},{id='ModCoreControls',name='Controls'}}
Groups.arrange(linkedTemplates,function() return {{id='Row'}} end)
assert(linkedTemplates[2].id=='ModCoreTemplates' and linkedTemplates[2].mcBrowserLine=='cell'
    and linkedTemplates[1].mcManifest:find('Label=ModCore Templates\nGroup=Foundation Modules\nType=picker\n'
        ..'Default=0\nPresetValues=0|1\nPresetLabels=Open|Open\nmcNavigation=1\nmcType=tab\nmcLinkPage=controls:visuals\n',1,true),
    'the Templates link page is listed and opens its slot from the Modules tab')
print('PASS the ModCore grid leads with short labels and icons')

-- Developer Tools lists the pages modules publish with group='tool'. They stay among the
-- providers, so links open them, but are never listed in the browser.
local function toolParse() return {{id='Row'}} end
local tooled={{id='ModCoreControls',name='Controls'},{id='Other',name='Other'},
    {id='ModCoreDevTools.sounds',name='Sounds Explorer',mcBrowserGroup='tool'},
    {id='ModCoreDevTools.characters',name='Characters Explorer',mcBrowserGroup='tool'}}
Groups.arrange(tooled,toolParse)
Groups.arrange(tooled,toolParse)
local expectTools={'ModCore.browser.root','ModCoreDevTools.sounds','ModCoreDevTools.characters','ModCoreControls',
    'ModCore.browser.group.various','Other'}
assert(#tooled==#expectTools)
for index,id in ipairs(expectTools) do assert(tooled[index].id==id,id) end
assert(tooled[2].mcBrowserHidden and tooled[3].mcBrowserHidden)
local rootManifest=tooled[1].mcManifest
local function find(text) return assert(rootManifest:find(text,1,true),text) end
assert(find('[Category.Developer Tools]')<find('Label=Sounds Explorer')
    and find('Label=Sounds Explorer')<find('mcLinkPage=ModCoreDevTools.sounds')
    and find('mcLinkPage=ModCoreDevTools.sounds')<find('Label=Characters Explorer')
    and find('Label=Characters Explorer')<find('mcLinkPage=ModCoreDevTools.characters'))
assert(rootManifest:match('%[Category%.Developer Tools%]\nVisibleWhen=ModCore_Page\nVisibleValues=2\nmcHeading=0\n'),
    'Developer Tools shows on its own tab without repeating its name')
local toolsOnly={{id='Other',name='Other'},{id='ModCoreDevTools.sounds',name='Sounds Explorer',mcBrowserGroup='tool'}}
Groups.arrange(toolsOnly,toolParse)
assert(toolsOnly[1].id=='ModCore.browser.root' and toolsOnly[2].mcBrowserHidden,'a tool page alone forms the ModCore group')
local noTools={{id='ModCoreControls',name='Controls'}}
Groups.arrange(noTools,toolParse)
assert(noTools[1].mcManifest:find('PresetLabels=None installed|None installed',1,true),
    'without tool pages Developer Tools says none are installed')
local headingOnly={{id='ModCoreDevTools.sounds',name='Sounds Explorer',mcBrowserGroup='tool'}}
Groups.arrange(headingOnly)
assert(headingOnly[1].noSettings and not headingOnly[2].mcBrowserHidden and headingOnly[2].mcBrowserIndent==20,
    'without the ModCore page a tool page is listed under the heading so it stays reachable')
-- The browser never lists a hidden page, in either filter mode.
local hiddenPages={}
hiddenPages.build=function(_,items)
    local page={allRows={},rows={},empty=widget(),scroll={ScrollToStart=function() end}}
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
    function page:refreshHint() end
    page:setFilter(false)
    return page
end
assert(Groups.install(hiddenPages,nil,toolParse))
local browsing=hiddenPages.build({},{{id='ModCoreControls',name='Controls'},
    {id='ModCoreDevTools.sounds',name='Sounds Explorer',mcBrowserGroup='tool'}},nil,{})
assert(#browsing.allRows==3 and #browsing.rows==2 and browsing.allRows[2].wrapper.visibility==1
    and browsing.rows[2]==browsing.allRows[3],'all mods: tool pages are not listed')
browsing:setFilter(true)
assert(#browsing.rows==2 and browsing.allRows[2].wrapper.visibility==1,'compatible mods: tool pages are not listed')
print('PASS Developer Tools lists published tool pages, which stay out of the browser list')

-- Each module shows its version: its page's, a contributed (even hidden) page's, or its
-- detected folder's VERSION / dlls/main.json.
local versioned={
    {id='ModCoreControls',name='Controls',version='1.0.3'},
    {id='ModCoreSettings',name='Visuals',version='v1.0.1'},
    {id='ModCoreTemplates.module.Preymonition',name='Preymonition',version='0.3.1',mcBrowserGroup='module'},
    {id='detected:ue4ss:0_modcore_ue4ssluaeventbridge',name='0_ModCore_UE4SSLuaEventBridge',
        detectedKind='ue4ss',noSettings=true,version='Unknown'},
}
local files={['Mods/0_ModCore_UE4SSLuaEventBridge/dlls/main.json']='{\n  "schema": 1,\n  "version": "1.0.12"\n}',
    ['Mods/3_ModCore_Templates/VERSION']='1.0.2\n'}
local function open(path)
    local content=files[path]
    if not content then return nil end
    return {read=function() return content end,close=function() end}
end
local folderVersion=Groups.folderVersion('Mods/',open)
assert(folderVersion('3_ModCore_Templates')=='1.0.2' and folderVersion('0_ModCore_UE4SSLuaEventBridge')=='1.0.12'
    and folderVersion('Missing')==nil and not pcall(folderVersion,'../x'))
local versionManifest
Groups.arrange(versioned,function(m) versionManifest=m;return {{id='ModCore_Page'}} end,nil,
    {pageVersions={ModCoreTemplates='1.0.2',ModCoreDevelopers='0.1.0'},folderVersion=folderVersion})
for _,label in ipairs({'Label=Preymonition v0.3.1','Label=ModCore Controls v1.0.3','Label=ModCore Settings v1.0.1',
    'Label=ModCore Templates v1.0.2','Label=Lua Event Bridge v1.0.12','Label=ModCore Dev Tools v0.1.0'}) do
    assert(versionManifest:find(label..'\n',1,true),label)
end
local unversioned
Groups.arrange({{id='ModCoreControls',name='Controls',version='Unknown'}},
    function(m) unversioned=m;return {{id='ModCore_Page'}} end)
assert(unversioned:find('Label=ModCore Controls\n',1,true) and unversioned:find('Label=Lua Event Bridge\n',1,true),
    'a module without a known version shows its name alone')
print('PASS each module on the ModCore page shows its version')

-- Through DMM's real parser the page parses, links resolve and it opens without a config file.
local choicesPath=os.getenv('DMM_CHOICES_PATH')
if not choicesPath then print('SKIP ModCore page parse: DMM_CHOICES_PATH is not set');return end
local Choices=dofile(choicesPath)
assert(require('navigation').install(Choices))
local Presentation=require('presentation')
local items=Presentation.parse(manifest,Choices.parse(manifest))
local byId={};for _,item in ipairs(items) do byId[item.id]=item end
assert(byId.ModCore_Page.mcNavigation and byId.ModCore_Page.mcHeader and byId.ModCore_Page.kind=='picker',
    'the first row is the title-row tab picker')
assert(byId.ModCore_Module_1.mcLinkPage=='ModCoreTemplates.module.Preymonition'
    and byId.ModCore_Module_2.mcLinkPage=='ModCoreControls' and byId.ModCore_Module_3.mcLinkPage=='ModCoreSettings'
    and byId.ModCore_Module_4.mcReadOnly and byId.ModCore_Module_5.mcReadOnly
    and byId.ModCore_Module_5.mcReadOnly and not byId.ModCore_Module_5.mcLinkPage
    and byId.ModCore_Module_6.mcReadOnly and byId.ModCore_Module_6.labels[1]=='No settings'
    and byId.ModCore_NoTools.mcReadOnly and byId.ModCore_Errors.mcText=='errors')
local model=Choices.open({id='ModCore.browser.root',choices=items})
assert(not model.error,model.error)
print('PASS the ModCore page parses through DMM and opens without a config file')
