package.path='Scripts/?.lua;'..package.path
local Groups=require('browser_groups')

local providers={
    {id='Other',name='Other'},
    {id='ModCoreControls',name='Controls'},
    {id='Preymonition',name='Preymonition'},
    {id='ModCoreSettings',name='Visuals'},
    {id='ModCoreTemplates.module.Fangdango',name='Fangdango'},
    {id='Last',name='Last'},
}
Groups.arrange(providers)
local expected={'Other','ModCore.browser.root','ModCoreControls','ModCoreSettings',
    'ModCoreTemplates.module.Fangdango','Preymonition','Last'}
for index,id in ipairs(expected) do assert(providers[index].id==id) end
assert(#providers==#expected)
assert(providers[2].name=='ModCore' and providers[2].noSettings)
assert(providers[3].mcBrowserLevel==4 and providers[3].mcBrowserIndent==20)
assert(providers[4].mcBrowserLevel==4 and providers[4].mcBrowserIndent==20)
assert(providers[5].mcBrowserLevel==4 and providers[6].mcBrowserIndent==20)
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

local MctExtension=dofile('../ModCoreTemplates/Scripts/mc/dmm_extension.lua')
local Choices=dofile(assert(os.getenv('DMM_CHOICES_PATH')))
local pageManifest='[Mod]\nId=ModCoreTemplates.module.Fangdango\nName=Fangdango\n'
    ..'[Setting.Template]\nId=Template\nType=picker\nPresetValues=0|1\nPresetLabels=None|Wheels\nDefault=0\n'
local menu={aggregate={manifest='[Mod]\nId=ModCoreTemplates\nName=ModCore Templates\n'},
    pages={{id='ModCoreTemplates.module.Fangdango',name='Fangdango',module='Fangdango',manifest=pageManifest}}}
local api={choices=Choices,pages={build=function(_,items) return items end}}
Groups.install(api.pages)
MctExtension.new('/tmp/mct-browser-group-test',menu).install(api)
local combined=api.pages.build({},{{id='ModCoreTemplates',name='ModCore Templates',testOnly=false},
    {id='ModCoreControls',name='Controls',testOnly=false},
    {id='ModCoreSettings',name='Visuals',testOnly=false},
    {id='Preymonition',name='Preymonition',testOnly=false}},nil,{})
local combinedIds={'ModCore.browser.root','ModCoreControls','ModCoreSettings',
    'ModCoreTemplates.module.Fangdango','Preymonition'}
assert(#combined==#combinedIds)
for index,id in ipairs(combinedIds) do assert(combined[index].id==id) end
print('PASS ModCore browser groups Controls, Visuals and module pages')
