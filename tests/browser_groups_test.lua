package.path='Scripts/?.lua;'..package.path
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

local filteredPages={build=function(_,items)
    local page={allRows={},rows={},scroll={ScrollToStart=function() end}}
    for index in ipairs(items) do page.allRows[index]={providerIndex=index} end
    function page:setFilter(compatibleOnly)
        self.compatibleOnly=compatibleOnly
        self.rows={}
        for _,row in ipairs(self.allRows) do
            if not compatibleOnly or not items[row.providerIndex].noSettings then
                self.rows[#self.rows+1]=row
            end
        end
    end
    function page:refreshHint() end
    function page:window() end
    page:setFilter(true)
    return page
end}
Groups.install(filteredPages)
local filtered=filteredPages.build({},{{id='ModCoreControls',name='Controls'}},nil,{})
assert(#filtered.rows==2 and filtered.rows[1].providerIndex==1
    and filtered.rows[2].providerIndex==2)

print('PASS ModCore browser groups Controls, Visuals and module pages')
