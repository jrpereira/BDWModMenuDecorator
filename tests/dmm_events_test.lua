package.path='Scripts/?.lua;Scripts/vendor/?.lua;'..package.path
local Events=require('dmm_events')
local reports={}
local function report(event,detail) reports[#reports+1]=event..':'..tostring(detail) end
local bus=Events.bus(report)
local seen={}
for _,name in ipairs({'providerPrepared','providerRefreshed','hostClosing'}) do
    bus:on(name,function(context) seen[#seen+1]={name=name,context=context} end)
end

-- A stand-in for DMM's controls.build: page rows are built on first prepare or show.
local tree,pc={name='tree'},{name='pc'}
local providers={{id='A'},{id='B'}}
local controls={build=function(_,list,_)
    local ui={panels={}}
    for i in ipairs(list) do ui.panels[i]={rows={{visible=true},{visible=true}}} end
    function ui:prepare(index) self.panels[index].built=true end
    function ui:show(index) self.panels[index].built=true;self.active=index;return 'shown',index end
    function ui:refresh(hide) if hide then self.panels[self.active].rows[2].visible=false end;return 'refreshed' end
    function ui:hide() self.active=nil end
    return ui
end}
local native={opened=0,closed=0}
function native.new(owner,widgets) native.opened=native.opened+1;return {owner=owner,tree=widgets} end
function native.close() native.closed=native.closed+1 end
Events.attach({controls=controls,nativeactions=native},bus,report)

local ui=controls.build(tree,providers,{pc=pc})
ui:prepare(1)
assert(#seen==1 and seen[1].name=='providerPrepared' and seen[1].context.provider.id=='A'
    and seen[1].context.panel==ui.panels[1] and seen[1].context.tree==tree and seen[1].context.pc==pc)
ui:prepare(1)
assert(#seen==1,'an already built page is not prepared again')
local shown,index=ui:show(2)
assert(shown=='shown' and index==2,'wrapped calls return what DMM returns')
assert(seen[2].name=='providerPrepared' and seen[2].context.provider.id=='B' and seen[3].name=='providerRefreshed')
print('PASS pages report when they are built and shown')

assert(ui:refresh()=='refreshed' and #seen==3,'a refresh that changes no row is quiet')
ui:refresh(true)
assert(#seen==4 and seen[4].name=='providerRefreshed' and seen[4].context.provider.id=='B')
print('PASS a refresh reports only when rows appear or disappear')

ui:hide()
assert(seen[5].name=='hostClosing' and seen[5].context.tree==tree)
local opened=native.new(pc,tree)
assert(opened.owner==pc and opened.tree==tree and native.opened==1)
native.close()
assert(native.closed==1 and seen[6].name=='hostClosing' and seen[6].context.tree==tree and seen[6].context.pc==pc)
native.close()
assert(native.closed==2 and #seen==6,'only a menu that was opened reports closing')
print('PASS leaving a page and closing the menu report hostClosing')

-- A failing listener is reported and never breaks DMM's own call.
bus:on('providerRefreshed',function() error('listener failure') end)
assert(select(1,ui:show(1))=='shown')
assert(reports[#reports]:find('LIFECYCLE_CALLBACK_FAILED:providerRefreshed',1,true))
print('PASS listener failures are isolated from DMM')
