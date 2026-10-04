package.path='Scripts/?.lua;'..package.path
local Links=require('page_links')

local function setup(dirty)
    local calls,texts={}, {}
    local providers={
        {id='Source',choices={{id='Link',mcNavigation=true,mcLinkPage='Target'},{id='Plain'}}},
        {id='Empty',noSettings=true,choices={}},
        {id='Target',choices={{id='X'}}},
    }
    local page={rows={{providerIndex=1},{providerIndex=3}},controlStatus={}}
    local model={saved={}}
    function model:set(index,value) self.saved[index]=value end
    function model:dirty() return dirty end
    page.controls={show=function(self) self.model=model;calls[#calls+1]='show' end,
        tick=function() calls[#calls+1]='tick';return false end}
    function page:showBrowser() calls[#calls+1]='browser' end
    function page:showDetail(row) calls[#calls+1]='detail '..row end
    local pages={build=function() return page end}
    assert(Links.install(pages) and not Links.install(pages))
    local built=pages.build({},providers,nil,{setText=function(_,copy) texts[#texts+1]=copy end})
    return built,model,calls,texts,providers
end

local page,model,calls,texts=setup(false)
page.controls:show(1)
model:set(2,1)
assert(model.saved[2]==1,'ordinary settings still save')
model:set(1,0)
assert(model.saved[1]==nil,'link activation saves nothing')
assert(page.controls:tick()==true)
assert(table.concat(calls,',')=='show,tick,browser,detail 2','links open through the browser')
assert(page.controls:tick()==false,'a link fires once')

page,model,calls,texts=setup(true)
page.controls:show(1)
model:set(1,0)
assert(page.controls:tick()==true and texts[1]=='Apply or discard changes before leaving this page.')
assert(not table.concat(calls,','):find('detail'))

local providers
page,model,calls,texts,providers=setup(false)
providers[1].choices[1].mcLinkPage='Empty'
page.controls:show(1)
model:set(1,0)
assert(page.controls:tick()==true and texts[1]=='Empty page is unavailable.')
-- A slot link opens its host page and sets the navigation pickers that gate the slot.
do
    local calls={}
    local items={
        {id='MCC_Page',mcNavigation=true,values={0,1,2},visibility={}},
        {id='Gate',mcNavigation=true,values={0,1},visibility={{target=1,values={[1]=true}}}},
        {id='Speed',visibility={}},
        {id='MCT_Template',mcSlotName='visuals',visibility={{target=2,values={[1]=true}}}},
    }
    local model={items=items,pending={0,0,3,5},sets={}}
    function model:set(index,value) self.pending[index]=value;self.sets[#self.sets+1]=items[index].id..'='..value end
    local providers={{id='Fangdango',mcLinkSlot={host='ModCoreControls',slot='visuals'},choices={}},
        {id='ModCoreControls',choices=items},{id='Other',mcLinkSlot={address='x:y'},choices={}}}
    local page={rows={{providerIndex=1},{providerIndex=2},{providerIndex=3}},controlStatus={}}
    page.controls={model=model,show=function() end,tick=function() return false end,
        refresh=function() calls[#calls+1]='refresh' end,
        select=function(_,index,keyboard) calls[#calls+1]='select '..index..tostring(keyboard) end}
    function page:showDetail(row) calls[#calls+1]='detail '..row end
    local pages={build=function() return page end}
    Links.install(pages)
    local built=pages.build({},providers,nil,{})
    built:showDetail(1)
    assert(table.concat(calls,',')=='detail 2,refresh,select 4true',table.concat(calls,','))
    assert(table.concat(model.sets,',')=='MCC_Page=1,Gate=1','parents first, smallest allowed value')
    calls,model.sets={},{}
    built:showDetail(1)
    assert(#model.sets==0,'already visible: nothing changes')
    calls={}
    built:showDetail(3)
    assert(table.concat(calls,',')=='detail 3','an unresolved link opens normally')
    calls={}
    built:showDetail(2)
    assert(table.concat(calls,',')=='detail 2','ordinary pages are untouched')
    page.rows={{providerIndex=1}}
    calls={}
    built:showDetail(1)
    assert(table.concat(calls,',')=='detail 1','missing host row falls back to the ordinary open')
end

print('PASS page links open targets through the browser and refuse dirty pages')
