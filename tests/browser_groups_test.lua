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
