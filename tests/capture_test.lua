package.path='Scripts/?.lua;'..package.path
local function obj(fields)
    fields=fields or {}
    function fields:IsValid() return self.alive~=false end
    return fields
end
local function fName(name) return {ToString=function() return name end} end
FName=fName
local function chord(name,flags)
    flags=flags or {}
    return {Key={KeyName=fName(name)},bShift=flags.shift or false,bCtrl=flags.ctrl or false,
        bAlt=flags.alt or false,bCmd=flags.cmd or false}
end
local function textWidget(text)
    local w=obj({text=text})
    function w:SetRenderOpacity(value) self.opacity=value end
    function w:SetText(value) assert(type(value)=='table' and value.ftext,'raw string sent to SetText'); self.text=value.value end
    return w
end
local lib=obj()
function lib:Conv_StringToText(text) return {ftext=true,value=text} end
StaticFindObject=function() return lib end
package.loaded.widget_discovery={valid=function(o) return o and o:IsValid() end,textOf=function(w) return w.text end}
local M=require('key_selector')
local events={}
local function log(event,detail) events[#events+1]=event..' '..detail end
local function fixture(value,dirty)
    events={}
    local slider=obj({value=value/254,writes=0})
    function slider:GetValue() return self.value end
    function slider:SetValue(v) self.value=v;self.writes=self.writes+1 end
    local selector=obj({SelectedKey=chord('None'),selecting=false})
    function selector:SetSelectedKey(c) self.SelectedKey=c end
    function selector:GetIsSelectingKey() return self.selecting end
    function selector:IsHovered() return self.hovered==true end
    function selector:SetIsEnabled(v) self.enabled=v end
    -- Deliberately no GetSelectedKey: match the reflected UE 5.5 API.
    local wrapper=obj();function wrapper:GetParent() return obj() end
    local surface=obj();function surface:SetBrushColor(c) self.color=c end
    local pc=obj();function pc:IsInputKeyDown() return false end
    local host=obj();function host:GetOwningPlayer() return pc end
    local tree=obj();function tree:GetOuter() return host end
    local instance={row={tree=tree,slider=slider,wrapper=wrapper,valueWidget=textWidget(tostring(value)..(dirty and ' *' or '')),labelWidget=textWidget('Ability')},
        selector=selector,keyBox=textWidget(''),keyText=textWidget(''),keyInner=surface,keyEdges={},baseLabel='Ability',
        descriptor={providerId='Test',settingId='Ability',minimum=0,maximum=254}}
    assert(M.tick(instance,log));assert(slider.writes==0,'initialization changed stock state')
    return instance,selector,slider
end
local function capture(i,s,name,flags)
    s.selecting=true;assert(M.tick(i,log))
    s.selecting=false;s.SelectedKey=chord(name,flags);assert(M.tick(i,log))
end
local i,s,slider=fixture(82,false)
capture(i,s,'K')
assert(slider.writes==1 and math.abs(slider.value-75/254)<1e-8)
assert(i.row.labelWidget.text=='Ability','invented dirty state before DMM acknowledgement')
i.row.valueWidget.text='75 *';assert(M.tick(i,log))
assert(i.row.labelWidget.text=='Ability','key capture must leave dirty styling to dirty_labels')
print('PASS reflected capture writes stock slider once; global dirty presentation has one owner')
for _,dirty in ipairs({false,true}) do
    i,s,slider=fixture(82,dirty)
    local label=i.row.labelWidget.text
    capture(i,s,'R') -- native EscapeKeys leaves previous SelectedKey untouched
    assert(slider.writes==0 and i.row.labelWidget.text==label)
    assert(i.keyText.text=='R')
end
print('PASS cancellation preserves clean and pre-existing dirty state')
i,s,slider=fixture(82,true);capture(i,s,'Escape')
assert(slider.writes==0 and i.keyText.text=='R')
print('PASS defensive Escape never becomes a binding')
i,s,slider=fixture(82,false);capture(i,s,'None')
assert(slider.writes==0 and i.keyText.text=='R' and s.SelectedKey.Key.KeyName:ToString()=='R')
print('PASS empty key capture is rejected and cannot replace an existing binding')
i,s,slider=fixture(82,false);capture(i,s,'K')
slider.value=82/254;i.row.valueWidget.text='82';M.tick(i,log)
assert(slider.writes==1 and i.keyText.text=='R')
print('PASS Restore supersedes outstanding capture without stale reassertion')
i,s,slider=fixture(82,false);capture(i,s,'F25')
assert(slider.writes==0 and i.keyText.text=='R')
print('PASS unsupported capture fails closed')
i,s,slider=fixture(82,false);capture(i,s,'F24')
assert(slider.writes==1 and math.abs(slider.value-0x87/254)<1e-8 and i.keyText.text=='F24')
print('PASS extended function keys can be captured')
for _,case in ipairs({
    {'LeftShift',0xA0,'Left Shift'},{'RightShift',0xA1,'Right Shift'},
    {'LeftControl',0xA2,'Left Ctrl'},{'RightControl',0xA3,'Right Ctrl'},
    {'LeftAlt',0xA4,'Left Alt'},{'RightAlt',0xA5,'Right Alt'},
    {'LeftCommand',0x5B,'Left Win'},{'RightCommand',0x5C,'Right Win'},
}) do
    i,s,slider=fixture(82,false);capture(i,s,case[1],{ctrl=true})
    assert(slider.writes==1 and math.abs(slider.value-case[2]/254)<1e-8 and i.keyText.text==case[3])
end
print('PASS left/right modifier keys are captured as distinct virtual-key values')
for value=0,9 do
    local names={'Zero','One','Two','Three','Four','Five','Six','Seven','Eight','Nine'}
    i,s,slider=fixture(0x30+value,false)
    assert(i.keyText.text==tostring(value),'saved digit key must display as a digit')
    capture(i,s,names[value+1])
    assert(i.keyText.text==tostring(value),'captured digit key must display as a digit')
end
print('PASS top-row digit keys display as digits')
i,s,slider=fixture(82,false);capture(i,s,'K',{ctrl=true})
assert(slider.writes==0 and i.keyText.text=='R' and events[#events]:find('UNSUPPORTED_KEY_CHORD',1,true))
print('PASS modifier chords are rejected instead of silently storing their primary key')
i,s,slider=fixture(0,false)
assert(i.keyText.text=='Unbound' and i.keyText.opacity==0.45 and slider.writes==0)
capture(i,s,'K');assert(slider.writes==1)
assert(i.keyText.opacity==1)
print('PASS zero/unbound initializes without writes and can be rebound')

i,s,slider=fixture(82,false)
local optionalButton=obj({enabled=false});function optionalButton:SetIsEnabled(v) self.enabled=v end
local function visibilityBox()
    local box=obj();function box:SetVisibility(v) self.visibility=v end
    function box:SetRenderOpacity(v) self.opacity=v end
    return box
end
local optionalText=textWidget('X')
local optionalBox=visibilityBox()
i.descriptor.optional=true;i.optional={box=optionalBox,button=optionalButton,text=optionalText,lastText='X'}
i.fixedBox=visibilityBox()
local modeBox=visibilityBox()
local modeButton=obj({enabled=false});function modeButton:SetIsEnabled(v) self.enabled=v end
function modeButton:IsHovered() return self.hovered==true end
i.pair={box=modeBox,button=modeButton,text=textWidget('Tap'),inner=obj({SetBrushColor=function(self,color) self.color=color end})}
assert(M.tick(i,log) and optionalText.text=='X' and optionalButton.enabled and optionalBox.visibility==0)
assert(i.keyText.text=='R' and i.fixedBox.visibility==0 and modeBox.visibility==0 and modeButton.enabled)
i.pendingOptionalClicks=1
assert(M.tick(i,log) and slider.writes==1 and slider.value==0 and i.keyText.text=='(none)')
assert(optionalBox.visibility==1 and optionalButton.enabled==false and i.fixedBox.visibility==0)
assert(modeBox.visibility==0 and modeButton.enabled==false and i.pair.text.text=='Optional')
assert(i.keyText.opacity==0.45 and i.keyBox.opacity==0.65)
capture(i,s,'Escape')
assert(slider.writes==1 and i.keyText.text=='(none)' and optionalBox.visibility==1)
s.selecting=true;assert(M.tick(i,log) and i.keyText.text=='...')
s.selecting=false;s.SelectedKey=chord('K');assert(M.tick(i,log))
assert(slider.writes==2 and i.keyText.text=='K' and i.keyText.opacity==1)
assert(optionalBox.visibility==0 and optionalButton.enabled and i.fixedBox.visibility==0 and i.fixedBox.opacity==1)
assert(modeBox.visibility==0 and modeBox.opacity==1 and modeButton.enabled and i.pair.text.opacity==1)
slider.value=0;assert(M.tick(i,log))
assert(slider.writes==2 and i.keyText.text=='(none)' and optionalBox.visibility==1)
print('PASS optional placeholder, clear, cancellation, capture and Restore switch presentation together')

i,s,slider=fixture(0,false)
i.descriptor.optional=true;i.descriptor.defaultControl='IA_Combat_ToggleQuickslots'
i.descriptor.defaultName='LeftAlt'
i.optional={box=visibilityBox(),button=optionalButton,text=textWidget('X'),lastText='X'}
i.pair={box=visibilityBox(),button=modeButton,text=textWidget('Tap'),
    inner=obj({SetBrushColor=function(self,color) self.color=color end})}
assert(M.tick(i,log) and i.keyText.text=='(Left Alt)' and i.pair.text.text=='Default')
assert(i.optional.box.visibility==1 and not optionalButton.enabled
    and i.pair.box.visibility==0 and not modeButton.enabled)
print('PASS optional standard-control default is distinct from an empty optional binding')

-- A held click must not be reused when X disappears or a capture completes.
local mouseDown=true
local pc=obj()
function pc:IsInputKeyDown(key) assert(key.KeyName:ToString()=='LeftMouseButton');return mouseDown end
local host=obj()
function host:GetOwningPlayer() return pc end
local tree=obj()
function tree:GetOuter() return host end
i,s,slider=fixture(82,false)
i.row.tree=tree;i.descriptor.optional=true
local clearButton=obj();function clearButton:SetIsEnabled(v) self.enabled=v end
i.optional={box=visibilityBox(),button=clearButton,text=textWidget('X'),lastText='X'}
s.hovered=true;i.pendingOptionalClicks=1
assert(M.tick(i,log) and i.pointerLatch and s.enabled==false and slider.value==0)
s.hovered=false
for _=1,4 do assert(M.tick(i,log) and i.pointerLatch and s.enabled==false) end
s.hovered=true;assert(M.tick(i,log) and i.pointerLatch and s.enabled==false)
mouseDown=false
assert(M.tick(i,log) and not i.pointerLatch and s.enabled==true)
mouseDown=true;s.hovered=true;s.selecting=true;assert(M.tick(i,log))
s.selecting=false;s.SelectedKey=chord('K')
assert(M.tick(i,log) and i.pointerLatch and s.enabled==false and slider.writes==2)
s.hovered=false
for _=1,4 do assert(M.tick(i,log) and i.pointerLatch and s.enabled==false and slider.writes==2) end
s.hovered=true;assert(M.tick(i,log) and i.pointerLatch and s.enabled==false)
mouseDown=false
assert(M.tick(i,log) and not i.pointerLatch and s.enabled==true and slider.writes==2)
print('PASS clear and capture keep the selector blocked through a moving held click')
i,s,slider=fixture(82,false);capture(i,s,'K')
for n=1,30 do M.tick(i,log) end
assert(slider.writes==1 and i.keyText.text=='K' and i.row.labelWidget.text=='Ability')
assert(#events==0,'unchanged DMM text triggered an acknowledgement diagnostic')
slider.value=84/254 -- Stock Restore/Reset wins even while displayed text is stale.
M.tick(i,log)
assert(slider.writes==1 and i.keyText.text=='T')
capture(i,s,'R');assert(slider.writes==2 and i.keyText.text=='R')
print('PASS stale DMM text neither blocks stock synchronization nor retries submission')
i,s,slider=fixture(254,false)
M.tick(i,log);assert(slider.writes==0,'unmapped backing value was automatically overwritten')
print('PASS unsupported existing backing value is not overwritten')

i,s,slider=fixture(82,false)
local modeNav=obj({value=2});function modeNav:GetValue() return self.value end
i.modeNav=modeNav;i.descriptor.modeValues={0,3,-1};i.descriptor.disabledMode=-1
assert(M.tick(i,log) and s.enabled==false and i.keyBox.opacity==0.45 and i.keyInner.color.A==0.12,
    'Default mode must disable and visibly dim key capture')
s.selecting=true;s.SelectedKey=chord('K');assert(M.tick(i,log) and slider.writes==0,
    'Disabled Default mode must ignore key capture while keeping the mode picker independent')
s.selecting=false;modeNav.value=0
assert(M.tick(i,log) and s.enabled==true and i.keyBox.opacity==1,
    'Tap mode must re-enable key capture')
capture(i,s,'K');assert(slider.writes==1)
modeNav.value=1;assert(M.tick(i,log) and s.enabled==true,
    'Hold mode must leave key capture enabled')
print('PASS Default disables key capture with visible styling; Tap and Hold re-enable it')

i,s,slider=fixture(82,false)
local groupSlider=obj({value=164/254})
function groupSlider:GetValue() return self.value end
local groupedEdge=obj()
function groupedEdge:SetRenderOpacity(value) self.opacity=value end
local groupedPairBox=obj()
function groupedPairBox:SetVisibility(value) self.visibility=value end
i.keyEdges={groupedEdge}
i.pair={box=groupedPairBox}
i.descriptor.groupedLabel='Slot 1'
i.descriptor.groupToggleRow={slider=groupSlider,dmmSetting={maximum=254}}
assert(M.tick(i,log) and s.enabled==false and i.keyBox.opacity==0.30
    and groupedEdge.opacity==0 and groupedPairBox.visibility==1 and i.keyText.text=='Slot 1',
    'bound group must replace the slot editor with a dim, borderless semantic slot')
groupSlider.value=0
assert(M.tick(i,log) and s.enabled==true and i.keyBox.opacity==1 and groupedEdge.opacity==1
    and i.keyText.text=='R','unbinding the group must restore the slot editor and key display')
print('PASS grouped slot is a static, borderless semantic alias while its group is bound')

i,s,slider=fixture(82,false)
local edge=obj();function edge:SetBrushColor(c) self.color=c end
i.keyEdges={edge}
s.hovered=true;M.tick(i,log)
assert(i.keyInner.color.R==0.95 and i.keyInner.color.A==0.22)
assert(edge.color.A==0.85 and slider.writes==0)
s.selecting=true;M.tick(i,log)
assert(i.keyInner.color.A==0.16 and edge.color.A==1)
s.hovered=false;M.tick(i,log)
assert(i.keyInner.color.A==0.16 and edge.color.A==1,'hover exit overwrote capture styling')
s.selecting=false;M.tick(i,log)
assert(i.keyInner.color.A==0.30 and edge.color.A==0.85)
s.hovered=true;s.selecting=true;M.tick(i,log)
s.selecting=false;M.tick(i,log)
assert(i.keyInner.color.A==0.22 and edge.color.A==0.85)
s.hovered=false;M.tick(i,log)
assert(i.keyInner.color.A==0.30 and slider.writes==0)
print('PASS key hover matches Mode fill, preserves outline, defers to capture, restores pointer state')

i,s,slider=fixture(82,false)
local nav=obj({value=0,writes=0})
function nav:GetValue() return self.value end
function nav:SetValue(v) self.value=v;self.writes=self.writes+1 end
local button=obj();function button:IsHovered() return false end
function button:IsPressed() error('press-state polling forbidden') end
local inner=obj();function inner:SetBrushColor() end
i.pair={button=button,inner=inner,nav=nav,valueWidget=textWidget('Tap'),text=textWidget('Tap'),lastText='Tap',count=2}
i.pendingClicks=3;M.tick(i,log);assert(nav.value==1 and nav.writes==1 and i.pendingClicks==0)
M.tick(i,log);assert(nav.writes==1)
print('PASS queued short clicks consumed exactly once without IsPressed; net mode preserved')
function button:SetIsEnabled(value) self.enabled=value end
i.descriptor.fixedMode='Tap';i.row.modeState=textWidget('MC_MODE\nfixed')
i.pair.valueWidget.text='Hold';i.pendingClicks=2
assert(M.tick(i,log) and i.pair.text.text=='Tap' and button.enabled==false)
assert(i.pair.text.opacity==0.45,'fixed mode must appear unavailable')
assert(nav.value==1 and nav.writes==1 and i.pendingClicks==0)
capture(i,s,'K');assert(slider.writes==1,'Fixed-mode display must not block key capture')
i.row.modeState.text='MC_MODE\neditable';i.pendingClicks=1
assert(M.tick(i,log) and button.enabled and i.pair.text.text=='Hold' and nav.writes==1,'Transition discards stale clicks')
assert(i.pair.text.opacity==1,'editable mode must regain normal contrast')
i.pendingClicks=1;assert(M.tick(i,log) and nav.value==0 and nav.writes==2)
i.row.modeState.text='MC_MODE\nfixed';i.pendingClicks=1
assert(M.tick(i,log) and nav.writes==2 and i.pair.text.text=='Tap')
assert(i.pair.text.opacity==0.45)
i.row.modeState.alive=false;i.pendingClicks=1
assert(not M.tick(i,log) and nav.writes==2 and i.pendingClicks==0,'Stale ownership must not submit clicks')
print('PASS fixed/editable mode switches preserve saved mode, discard stale clicks and allow key capture')

i,s,slider=fixture(82,false)
s.SelectedKey={Key={}}
for attempt=1,3 do
    assert(M.tick(i,log)==false and slider.writes==0)
end
assert(events[1]:find('SELECTED_KEY_READ_FAILED',1,true),'missing FKey name was treated as a literal key')
assert(#events==1,'persistent unreadable key repeated its warning')
s.SelectedKey=chord('R')
assert(M.tick(i,log) and not i.readWarning and slider.writes==0)
print('PASS unreadable key reports failure without writes; readable key recovers')

local function failNextText(widget)
    local original=widget.SetText
    local fail=true
    function widget:SetText(value)
        if fail then fail=false;error('transient text failure') end
        return original(self,value)
    end
end
i,s,slider=fixture(82,false)
failNextText(i.keyText)
s.SelectedKey=chord('K')
assert(not pcall(M.tick,i,log))
assert(i.keyText.text=='R' and slider.writes==1)
assert(M.tick(i,log) and i.keyText.text=='K' and slider.writes==1)
assert(M.tick(i,log) and slider.writes==1)
print('PASS failed key presentation recovers without resubmitting the accepted key')

i,s,slider=fixture(82,false)
failNextText(i.keyText)
s.SelectedKey=chord('K');assert(not pcall(M.tick,i,log))
slider.value=84/254
assert(M.tick(i,log) and i.keyText.text=='T' and slider.writes==1)
print('PASS stock Restore supersedes a failed key presentation without stale resubmission')

i,s,slider=fixture(82,false)
slider.value=254/254
assert(M.tick(i,log) and i.keyText.text=='254' and slider.writes==0)
slider.value=253/254
assert(M.tick(i,log) and i.keyText.text=='253' and slider.writes==0)
s.selecting=true;assert(M.tick(i,log) and i.keyText.text=='...')
s.selecting=false;assert(M.tick(i,log) and i.keyText.text=='253' and slider.writes==0)
slider.value=84/254
assert(M.tick(i,log) and i.keyText.text=='T' and slider.writes==0)
capture(i,s,'K');assert(i.keyText.text=='K' and slider.writes==1)
print('PASS unmapped backing values display numerically through changes and cancellation')

i,s,slider=fixture(82,false)
i.row.valueWidget.text='82 *'
assert(M.tick(i,log) and i.row.labelWidget.text=='Ability','key capture must not compete with global dirty styling')
i.pair={valueWidget=textWidget('Hold'),text=textWidget('Tap'),lastText='Tap'}
failNextText(i.pair.text)
assert(not pcall(M.tick,i,log) and i.pair.lastText=='Tap')
assert(M.tick(i,log) and i.pair.text.text=='Hold' and i.pair.lastText=='Hold')
print('PASS mode label writes remain retryable; dirty styling has one owner')

-- Minimal owned subtree, exercising the production save/adopt implementation.
local function ownRow(instance)
    instance.stateWidget=textWidget('')
    local discovery=package.loaded.widget_discovery
    discovery.childCount=function(w) return #(w.children or {}) end
    discovery.childAt=function(w,n) return (w.children or {})[n+1] end
    discovery.contentOf=function(w) return w and w.content end
    instance.keyInner.content=instance.keyText
    local overlay={children={{content=instance.keyInner},{content=obj()},
        {content=obj()},{content=obj()},{content=obj()},instance.selector,instance.stateWidget}}
    instance.row.surface={children={{content=overlay}}}
    instance.row.label='Ability'
    M.save(instance)
end
do
    i,s,slider=fixture(82,false)
    ownRow(i)
    failNextText(i.keyText)
    s.SelectedKey=chord('K');assert(not pcall(M.tick,i,log))
    assert(slider.writes==1)
    slider.value=84/254;i.row.valueWidget.text='84'
    local adopted=assert(M.adopt(i.row,i.descriptor,nil,{}))
    assert(adopted.lastName=='K','rendering failure lost accepted row state')
    assert(M.tick(adopted,log))
    assert(slider.writes==1 and math.abs(slider.value-84/254)<1e-8 and adopted.keyText.text=='T')
end
print('PASS failed key rendering followed by Restore and real row adoption never replays a stale key')

for _,cancel in ipairs({false,true}) do
    i,s,slider=fixture(82,false)
    ownRow(i)
    slider.value=254/254;assert(M.tick(i,log))
    assert(s.SelectedKey.Key.KeyName:ToString()=='None' and slider.writes==0)
    local adopted=assert(M.adopt(i.row,i.descriptor,nil,{}))
    assert(adopted.lastName=='None')
    if cancel then
        capture(adopted,s,'None') -- Native Escape leaves the neutral key unchanged.
        assert(slider.writes==0 and slider.value==1 and adopted.keyText.text=='254')
        capture(adopted,s,'Escape') -- Defensive explicit Escape path.
        assert(slider.writes==0 and slider.value==1)
    end
    capture(adopted,s,'R')
    assert(slider.writes==1 and math.abs(slider.value-82/254)<1e-8 and adopted.keyText.text=='R')
end
print('PASS unmapped row adoption preserves cancellation and allows recapturing its previous key')
