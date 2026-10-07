package.path='Scripts/?.lua;Scripts/vendor/?.lua;'..package.path
local Groups=require('browser_groups')

local providers={
    {id='Other',name='Other'},
    {id='ModCoreTemplates.module.Unmarked',name='Unmarked'},
    {id='ModCoreControls',name='Controls'},
    {id='MCT.module.VisualExample',name='Visual Example',mcBrowserGroup='module'},
    {id='ModCoreSettings',name='Visuals'},
    {id='ExampleOverlay',name='Example Overlay',mcBrowserGroup='module'},
    {id='Last',name='Last'},
}
Groups.arrange(providers)
local expected={'Other','ModCoreTemplates.module.Unmarked','ModCore.browser.root','ModCoreControls','ModCoreSettings',
    'MCT.module.VisualExample','ExampleOverlay','Last'}
for index,id in ipairs(expected) do assert(providers[index].id==id) end
assert(#providers==#expected)
assert(providers[3].name=='ModCore' and providers[3].noSettings)
assert(providers[2].mcBrowserLevel==nil,'only declared module pages are grouped')
assert(providers[4].mcBrowserLevel==4 and providers[4].mcBrowserIndent==20)
assert(providers[5].mcBrowserLevel==4 and providers[5].mcBrowserIndent==20)
assert(providers[6].mcBrowserLevel==4 and providers[7].mcBrowserIndent==20)
Groups.arrange(providers)
assert(#providers==#expected)
for index,id in ipairs(expected) do assert(providers[index].id==id) end

local bare={{id='Other',name='Other'}}
Groups.arrange(bare)
assert(#bare==1 and bare[1].id=='Other')

local pages={build=function(_,items) return items end}
assert(Groups.install(pages) and not Groups.install(pages))
local built=pages.build({},{{id='ModCoreSettings',name='Visuals'}},nil,{})
assert(#built==2 and built[1].name=='ModCore' and built[2].name=='Visuals')

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
print('PASS compatible-only filtering keeps the ModCore headings visible and linked')

-- With a parser, the ModCore heading is its own page: a Modules | Developer Tools tab
-- picker, then a link to each module page under User Modules and Foundation Modules.
local parsed={}
local linked={
    {id='Other',name='Other'},
    {id='ModCoreControls',name='Controls'},
    {id='ModCoreSettings',name='Visuals'},
    {id='ModCoreTemplates.module.Preymonition',name='Preymonition',mcBrowserGroup='module'},
}
Groups.arrange(linked,function(manifest) parsed[#parsed+1]=manifest;return {{id='ModCore_Page'}} end)
local page=linked[2]
assert(page.id=='ModCore.browser.root' and page.name=='ModCore' and not page.noSettings
    and not page.mcBrowserHeading and page.settingsCount==1 and page.mcManifest==parsed[1],
    'the ModCore entry opens its own page')
local manifest=parsed[1]
local function at(text) return assert(manifest:find(text,1,true),text) end
assert(at('PresetLabels=Modules|Developer Tools')<at('[Category.User Modules]')
    and at('[Category.User Modules]')<at('mcLinkPage=ModCoreTemplates.module.Preymonition')
    and at('mcLinkPage=ModCoreTemplates.module.Preymonition')<at('[Category.Foundation Modules]')
    and at('[Category.Foundation Modules]')<at('Label=ModCore Controls')
    and at('Label=ModCore Controls')<at('Label=ModCore Settings'),
    'Modules lists user modules, then foundation modules, each linking to its page')
local failures={}
local fallback={{id='ModCoreControls',name='Controls'}}
Groups.arrange(fallback,function() error('bad manifest') end,function(event) failures[#failures+1]=event end)
assert(fallback[1].noSettings and fallback[1].mcBrowserHeading and failures[1]=='BROWSER_ROOT_FAILED',
    'a page that cannot be built leaves the plain heading')
print('PASS the ModCore heading opens a Modules and Developer Tools page')

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
    and byId.ModCore_DeveloperTools.mcReadOnly)
local model=Choices.open({id='ModCore.browser.root',choices=items})
assert(not model.error,model.error)
print('PASS the ModCore page parses through DMM and opens without a config file')
