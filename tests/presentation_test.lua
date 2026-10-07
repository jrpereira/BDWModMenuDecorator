package.path='Scripts/?.lua;Scripts/vendor/?.lua;'..package.path
local M=require('presentation')
local items={
    {id='Primary',kind='picker',group='General',label='Primary',values={0,1},labels={'Consumables','Abilities'}},
    {id='Ability',kind='picker',group='Abilities',label='Ability',values={0,1},labels={'Tap','Hold'}},
    {id='Consumable',kind='picker',group='Consumables',label='Consumable',values={0,1},labels={'Tap','Hold'}},
    {id='Enabled',kind='toggle',group='General',label='Enabled',values={0,1},labels={'Off','On'}},
    {id='Key',kind='slider',group='Keys',label='Key'},
    {id='KeyMode',kind='picker',group='Keys',label='Mode',values={0,3,-1},labels={'Tap','Hold','Default'}},
}
local schema=[[
[Setting.Primary]
Id=Primary
mcType=tab
mcLevel=2
mcTabsWidth=440
[Setting.Ability]
Id=Ability
mcLabelWhen=Primary
mcLabels=0:Slot 5;1:Slot 1
[Category.Abilities]
mcHelp=Ability explanation
mcHeading=0
mcParent=Interaction: Independent
mcParentLevel=2
mcLevel=3
mcLabelWhen=Primary
mcLabels=0:Secondary Wheel;1:Primary Wheel
mcOrderWhen=Primary
mcOrders=0:20;1:10
[Category.Consumables]
mcParent=Interaction: Independent
mcParentLevel=2
mcLabelWhen=Primary
mcLabels=0:Primary Wheel;1:Secondary Wheel
mcOrderWhen=Primary
mcOrders=0:10;1:20
[Category.Keys]
mcParent=Interaction: Selective
mcParentLevel=2
mcLevel=3
[Setting.Enabled]
Id=Enabled
mcHeading=true
[Setting.Key]
Id=Key
[Setting.KeyMode]
Id=KeyMode
]]
M.parse(schema,items)
assert(items[1].mcTabs and items[1].mcFont==2 and items[1].mcTabsWidth==440)
assert(items[2].mcLabelRule.values[0]=='Slot 5')
assert(items[2].mcGroup.parent==items[3].mcGroup.parent,'Shared parent labels must share one descriptor')
assert(items[2].mcGroup.parent.label=='Interaction: Independent' and items[2].mcGroup.parent.font==2)
assert(not items[2].mcGroup.heading and items[3].mcGroup.heading)
assert(items[5].mcGroup.parent.label=='Interaction: Selective')
M.parse(schema:gsub('mcType=tab','DecoType=tab'):gsub('mcLevel=2','DecoLevel=2')
    :gsub('mcTabsWidth=440','DecoTabsWidth=440'),items)
assert(not items[1].mcTabs and items[1].mcFont==nil,'noncanonical metadata must be ignored')
M.parse(schema:gsub('mc','amm'),items)
assert(not items[1].mcTabs and items[1].mcFont==nil,'old amm metadata must not be read')
assert(not pcall(M.parse,schema:gsub('mcType=tab','mcType=tabs'),items))
assert(not pcall(M.parse,schema:gsub('mcTabsWidth=440','mcTabsWidth=441'),items))
assert(not pcall(M.parse,schema:gsub('mcType=tab','mcType=keybind'),items))
assert(not pcall(M.parse,schema:gsub('mcHeading=true','mcHeading=invalid'),items))
M.parse(schema,items)
assert(not pcall(M.parse,schema:gsub('mcLevel=2','mcLevel=9'),items))
assert(not pcall(M.parse,schema:gsub('mcHeading=0','mcHeading=invalid'),items))
assert(not pcall(M.parse,schema:gsub('mcLabelWhen=Primary','mcLabelWhen=Missing'),items))
local parentItems={{id='One',kind='toggle',group='One',values={0,1}},{id='Two',kind='toggle',group='Two',values={0,1}}}
assert(not pcall(M.parse,'[Category.One]\nmcParent=\n',parentItems))
assert(not pcall(M.parse,'[Category.One]\nmcParentLevel=2\n',parentItems))
assert(not pcall(M.parse,'[Category.One]\nmcParent=Shared\nmcParentLevel=2\n[Category.Two]\nmcParent=Shared\nmcParentLevel=3\n',parentItems))
M.parse(schema,items)
local function widget()
    local w={children={},Font={SkewAmount=0},enabled=true,position=0,visible=0,
        WidgetStyle={NormalPadding={Left=16,Top=0,Right=0,Bottom=0},
            PressedPadding={Left=16,Top=0,Right=0,Bottom=0}}}
    function w:GetFullName() return 'Widget '..tostring(self) end
    function w:IsValid() return true end
    function w:GetParent() return self.parent end
    function w:GetChildrenCount() return #self.children end
    function w:GetChildAt(n) return self.children[n+1] end
    function w:GetContent() return self.children[1] end
    function w:AddChild(child)
        child.parent=self;self.children[#self.children+1]=child
        child.Slot={Padding={Left=0,Top=0,Right=0,Bottom=0}}
        setmetatable(child.Slot,{__index=function(_,key)
            return function(slot,value) slot[key:sub(4)]=value end
        end})
        return child.Slot
    end
    function w:RemoveChild(child)
        for n,v in ipairs(self.children) do if v==child then table.remove(self.children,n);child.parent=nil;return true end end
        return false
    end
    function w:RemoveFromParent() if self.parent then self.parent:RemoveChild(self) end end
    function w:ClearChildren() for _,child in ipairs(self.children) do child.parent=nil end;self.children={} end
    function w:SetContent(child) self:ClearChildren();return self:AddChild(child) end
    function w:SetVisibility(v) self.visible=v end
    function w:SetValue(v) self.position=v end
    function w:GetValue() return self.position end
    function w:SetIsEnabled(v) self.enabled=v end
    function w:GetIsEnabled() return self.enabled end
    function w:IsPressed() return self.pressed or false end
    function w:IsHovered() return self.hovered or false end
    function w:HasUserFocus() return false end
    function w:SetRenderOpacity(v) assert(type(v)=='number');self.opacity=v end
    function w:SetFont(v) self.Font=v end
    function w:SetWidthOverride(v) self.WidthOverride=v end
    function w:SetHeightOverride(v) self.HeightOverride=v end
    function w:ClearHeightOverride() self.HeightOverride=nil;self.heightCleared=true end
    function w:SetMinDesiredHeight(v) self.MinDesiredHeight=v end
    function w:SetAutoWrapText(v) self.AutoWrapText=v end
    function w:SetBrushColor(v) self.BrushColor=v end
    function w:SetColorAndOpacity(v) self.colorAndOpacity=v;self.color=nil end
    function w:SetRenderTranslation(v) self.RenderTranslation=v end
    return setmetatable(w,{__index=function(_,key)
        if key:match('^Set') or key=='ForceVolatile' or key=='ScrollToStart' or key=='ScrollWidgetIntoView' then return function() end end
    end})
end
local noop=function() end
local theme={font=function(label,_,size) label.Font.Size=size end,textColor=function(label,color) label.color=color end,
    selectionState=function() return 0 end,image=widget,sliderTrack=function() return widget(),widget() end}
setmetatable(theme,{__index=function() return noop end})
local api={construct=widget,need=assert,Theme=theme,theme={assets={}},caption=function(_,text) local w=widget();w.text=text;return w end,
    setText=function(w,text) w.text=text end,describe=noop,actions=noop,status=noop,log=noop}
api.events={emit=function(_,name,context)
    assert(name=="providerRefreshed")
    context.panel.readyEvents=(context.panel.readyEvents or 0)+1
end}
api.button=function(tree,text) local b=widget();local l=api.caption(tree,text);b:SetContent(l);return b,l end
local choices={parse=function() return items end,format=function(setting,value)
    for i,candidate in ipairs(setting.values or {}) do
        if candidate==value then return setting.labels[i] end
    end
    return tostring(value)
end}
function choices.snap(setting,value)
    local steps=math.floor((value-setting.minimum)/setting.step+0.5)
    return math.max(setting.minimum,math.min(setting.maximum,setting.minimum+steps*setting.step))
end
local pages={build=function(tree,providers,status,a)
    local filterButton,filterLabel=a.button(tree,'Compatible Mods')
    local browserList=widget()
    local filterWrapper=widget();filterWrapper:SetContent(filterButton);browserList:AddChild(filterWrapper)
    local parent=widget()
    local title=a.caption(tree,'Mod Settings');parent:AddChild(title)
    local divider=widget();parent:AddChild(divider)
    local status=a.caption(tree,'');parent:AddChild(status)
    status.Slot:SetPadding({Left=0,Top=4,Right=0,Bottom=0})
    -- UE4SS may return another Lua wrapper for the same UMG widget.
    local titleWrapper={Slot=title.Slot,GetFullName=function() return title:GetFullName() end}
    local getChildAt,addChild=parent.GetChildAt,parent.AddChild
    function parent:GetChildAt(n)
        local child=getChildAt(self,n)
        return child==title and titleWrapper or child
    end
    function parent:AddChild(child)
        return addChild(self,child==titleWrapper and title or child)
    end
    local allRows={}
    local browserRows=widget()
    for index,provider in ipairs(providers) do
        local button,label=a.button(tree,provider.name)
        label.Slot:SetPadding({Left=20,Top=4,Right=12,Bottom=4})
        local wrapper=widget();wrapper:SetWidthOverride(584);wrapper:SetContent(button)
        browserRows:AddChild(wrapper)
        wrapper.Slot:SetPadding({Left=0,Top=0,Right=8,Bottom=0})
        allRows[#allRows+1]={widget=button,wrapper=wrapper,providerIndex=index}
    end
    local page={filterButton=filterButton,filterLabel=filterLabel,browserList=browserList,allRows=allRows,
        controls={},modTitle=title,controlStatus=status,mcTestControlArea=parent,mcTestDivider=divider,mcTestApi=a}
    function page:refresh(compatibleOnly)
        a.setText(self.filterLabel,compatibleOnly and 'Compatible Mods' or 'All Mods')
    end
    return page
end}
local controls={build=function(tree,providers,a)
    local ui={root=widget(),panels={{rows={},headings={},scroll=widget()}},model={items=items,pending={0,0,0,1,49,-1},committed={0,0,0,1,49,-1}}}
    ui.mcTestSetText=a.setText
    function ui.model:visibility() return {true,true,true,true,self.pending[1]==1,true} end
    function ui.root:SetActiveWidgetIndex() self.readyEvents=(self.readyEvents or 0)+1 end
    function ui.model:set(i,v) self.pending[i]=v end
    function ui.model:change(i) self.pending[i]=1-self.pending[i] end
    function ui:prepare()
        if self.mcTestFail then local message=self.mcTestFail;self.mcTestFail=nil;error(message,0) end
        local p=self.panels[1];if p.built then return end
        for i,s in ipairs(items) do
            local heading=a.caption(tree,s.group);p.scroll:AddChild(heading)
            p.headings[i]={widget=heading,first=i,last=i,visible=true}
            local b,l=a.button(tree,s.label)
            if s.kind=='toggle' or s.kind=='extension' then
                -- DMM's toggle row: the label sits in a size box in the content, whose
                -- slot carries the 20-pixel inset.
                local content,labelBox=widget(),widget()
                b:SetContent(content);labelBox:SetContent(l);content:AddChild(labelBox)
                content.Slot:SetPadding({Left=20,Top=0,Right=0,Bottom=0})
            else l.Slot:SetPadding({Left=20,Top=0,Right=8,Bottom=0}) end
            local box=widget();box:SetContent(b)
            local bg=widget();local overlay=widget();overlay:AddChild(bg);overlay:AddChild(box)
            local value=a.caption(tree,'');overlay:AddChild(value)
            local parts={}
            -- Like DMM, only a picker adds its left, value and right buttons after the label.
            if s.kind=='picker' then
                for n=1,3 do local b2=a.button(tree,n==1 and '<' or n==3 and '>' or '');local size=widget();size:SetContent(b2);overlay:AddChild(size);parts[n]={widget=b2} end
            end
            local wrapper=widget();wrapper:SetContent(overlay);p.scroll:AddChild(wrapper)
            p.rows[i]={widget=b,value=value,background=bg,parts=parts,wrapper=wrapper,nav=widget(),visible=true}
        end
        p.built=true
    end
    function ui:show(i) self.active=i;self:prepare(i);self:refresh() end
    function ui:refresh()
        local visible=self.model:visibility()
        for i,row in ipairs(self.panels[self.active].rows) do
            row.visible=visible[i]
            row.pressed,row.pointer=false,false
            for _,part in ipairs(row.parts or {}) do part.pressed,part.pointer=false,false end
        end
    end
    function ui:tick() self.ticks=(self.ticks or 0)+1;return false end
    function ui:clearPresses() end
    function ui:isPressed() return false end
    function ui:select(i) self.current=i end
    return ui
end}
assert(M.install(choices,controls,pages,{keyColumn={key=96,keyOffset=408}}));assert(not M.install(choices,controls,pages))
local browserProviders={
    {name='Templates',choices=items},
    {name='Menu Controls',choices=items,mcBrowserLevel=4,mcBrowserIndent=20},
}
local page=pages.build(widget(),browserProviders,nil,api)
assert(#page.browserList.children==2 and page.browserList.children[2]:GetContent(),
    'Mod-browser title must have a themed divider immediately beneath it')
assert(page.filterLabel.Font.Size==page.controls.mcHeaderTitle.Font.Size and
    page.filterLabel.color==page.controls.mcHeaderTitle.color,'Compatible Mods must use the mod-title style')
assert(page.mcTestControlArea.children[1]==page.controls.mcHeaderHost
    and page.mcTestControlArea.children[2]==page.mcTestDivider
    and page.controls.mcHeaderHost.children[1]==page.modTitle
    and page.modTitle.visible==4,
    'Mod title must share the first row with the picker above the divider')
assert(page.controls.mcHeaderHost.Slot.Padding.Bottom==0,'The title row must not add space above the divider')
assert(page.mcTestControlArea.children[3]:GetContent()==page.controls.mcHeaderTabs
    and #page.mcTestControlArea.children==3,
    'The header tab strip must sit directly beneath the divider')
local statusBox=page.controls.mcHeaderStatus.box
assert(#page.controls.mcHeaderTabs.children==1 and page.controls.mcHeaderTabs.children[1]==statusBox
    and statusBox:GetContent()==page.controlStatus and statusBox.WidthOverride==572
    and statusBox.Slot.HorizontalAlignment==1 and statusBox.Slot.VerticalAlignment==1
    and statusBox.Slot.Padding.Top==4,
    'The page status must start the header row beneath the divider, keeping its padding')
-- Unapplied changes show as a * after the page title, not as status text; every other
-- status stays text, and the * follows the model's dirty state.
local dirty,failed=true,nil
page.controls.model={dirty=function() return dirty end}
page.mcTestApi.setText(page.modTitle,'Controls')
page.mcTestApi.setText(page.controlStatus,'Unapplied changes')
assert(page.modTitle.text=='Controls *' and page.controlStatus.text=='','dirty: the title gains a * and the status is empty')
page.mcTestApi.setText(page.controlStatus,'Apply failed: disk full')
assert(page.controlStatus.text=='Apply failed: disk full' and page.modTitle.text=='Controls *',
    'a failed Apply still reads as text, and the page is still dirty')
dirty=false
page.mcTestApi.setText(page.controlStatus,'')
assert(page.modTitle.text=='Controls' and page.controlStatus.text=='','Apply or Restore clears the *')
page.controls.model={dirty=function() return true end,error='config unreadable'}
page.mcTestApi.setText(page.controlStatus,'config unreadable')
assert(page.controlStatus.text=='config unreadable' and page.modTitle.text=='Controls','an error reads as text, without a *')
page.controls.model=nil
page:refresh(false)
assert(page.filterLabel.text=='All Mods' and page.filterLabel.Font.Size==22 and page.filterLabel.color=='title',
    'Filter text changes must retain the mod-title style')
local modLabel=page.allRows[1].widget:GetContent()
assert(modLabel.text=='Templates' and modLabel.Font.Size==16 and modLabel.color=='muted',
    'Mod-list labels must use level-two styling')
assert(page.filterLabel.Slot.Padding.Left==0 and modLabel.Slot.Padding.Left==0,
    'Regular Mod Menu entries must use normal left alignment')
local categoryLabel=page.allRows[2].widget:GetContent()
assert(categoryLabel.text=='Menu Controls' and categoryLabel.Font.Size==14 and categoryLabel.color=='body',
    'Category modules must accept level-four browser styling')
assert(categoryLabel.Slot.Padding.Left==0
    and page.allRows[2].wrapper.Slot.Padding.Left==20
    and page.allRows[2].wrapper.WidthOverride==544,
    'Submodule button and highlight must both start at the browser indentation')
local ui=controls.build(widget(),{{id='ModCoreTemplates.module.VisualExample',choices=items}},api)
ui.mcHeaderHost=widget()
ui:show(1)
local row=ui.panels[1].rows[1]
assert(#row.mcTabs==2 and row.mcLabel.Font.Size==20)
-- Each choice is outlined; the selected choice's outline is drawn at full strength.
local selectedTabs=0
for _,tab in ipairs(row.mcTabs) do
    assert(#tab.outline==4,'every tab choice has a four-sided outline')
    for _,bar in ipairs(tab.outline) do
        assert((bar.BrushColor.A>0.5)==(tab.selected==true),'only the selected choice has a bright outline')
    end
    if tab.selected then selectedTabs=selectedTabs+1 end
end
assert(selectedTabs==1,'exactly one tab choice is selected')
assert(row.mcTabs[1].box.WidthOverride+row.mcTabs[2].box.WidthOverride+4==440,
    'outlined choices share the reserved width with a 4-pixel gap')
items[1].mcNavigation,items[1].mcLinkPage=true,'ModCoreControls'
local linked=controls.build(widget(),{{id='ModCoreTemplates.module.VisualExample',choices=items}},api)
linked.mcHeaderHost=widget()
linked:show(1)
assert(#linked.panels[1].rows[1].mcTabs==1
    and linked.panels[1].rows[1].mcTabs[1].label.text=='Consumables'
    and linked.panels[1].rows[1].mcTabs[1].box.WidthOverride==160,
    'page links must display one clickable tab')
-- A link row's label wraps in its column and the row grows from a 40-pixel minimum.
local linkRow=linked.panels[1].rows[1]
assert(linkRow.mcLabel.AutoWrapText==true,'link labels wrap')
for _,box in ipairs({linkRow.widget:GetParent(),linkRow.wrapper}) do
    assert(box.heightCleared and box.HeightOverride==nil and box.MinDesiredHeight==40,
        'link rows grow to fit their label, from a 40-pixel minimum')
end
assert(linkRow.widget:GetParent().WidthOverride==584-160-24,'the label column keeps its width')
assert(not row.mcLabel.AutoWrapText and not row.wrapper.heightCleared,
    'ordinary tab rows keep a fixed single-line label')
local linkSet=linked.model.set
function linked.model:set(index,value)
    if index==1 and value==0 then self.linkActivated=true end
    return linkSet(self,index,value)
end
linked.panels[1].rows[1].mcTabs[1].widget.clicked=true
linked:tick({},function(w) local clicked=w.clicked;w.clicked=false;return clicked,false,false end,false)
assert(linked.model.linkActivated,'the single link tab must activate even at its default value')
items[1].mcNavigation,items[1].mcLinkPage=nil,nil
assert(row.mcTabs[1].label.Slot.HorizontalAlignment==0 and row.mcTabs[1].label.Slot.VerticalAlignment==2,
    'Tab labels must fill their allocated button slots for centered text justification')
for _,tab in ipairs(row.mcTabs) do
    assert(tab.widget:GetParent():GetParent()==tab.box
        and tab.box:GetParent():GetParent()==row.wrapper:GetContent(),
        'Tab picker options sit in their outline inside the row')
end
local tabSlot=row.mcTabs[1].box:GetParent().Slot
assert(tabSlot.HorizontalAlignment==3 and tabSlot.Padding.Right==24,
    'Tab pickers must align right with a 24-pixel inset')
local linkTab=linked.panels[1].rows[1].mcTabs[1]
assert(#linkTab.outline==4 and linkTab.box:GetParent().Slot.Padding.Right==24,
    'Provider-link pickers must use the same outlined inset')
assert(row.mcTabs[1].selected and not row.mcTabs[2].selected)
assert(ui.panels[1].rows[2].mcLabel.text=='Slot 5')
local scroll=ui.panels[1].scroll
local function position(target)
    for n,child in ipairs(scroll.children) do if child==target then return n end end
end
local function textCount(text)
    local count=0;for _,child in ipairs(scroll.children) do if child.text==text then count=count+1 end end;return count
end
assert(textCount('Interaction: Independent')==1 and textCount('Interaction: Selective')==1,'Each parent heading renders once')
local independent
for _,child in ipairs(scroll.children) do if child.text=='Interaction: Independent' then independent=child end end
assert(position(independent)<position(ui.panels[1].headings[3].widget),'Parent must precede its subgroup headings')
assert(position(ui.panels[1].headings[3].widget)<position(ui.panels[1].headings[2].widget),'Primary category must precede secondary')
assert(ui.panels[1].headings[2].widget.visible==1,'mcHeading=0 must collapse only the category heading')
assert(ui.panels[1].rows[2].visible and independent.visible==4,'Hidden subgroup heading must retain rows and visible parent')
local count=scroll:GetChildrenCount()
row.mcTabs[2].widget.clicked=true
ui:tick({},function(w) local clicked=w.clicked;w.clicked=false;return clicked,false,false end,false)
assert(ui.model.pending[1]==1 and row.mcTabs[2].selected)
assert(ui.panels[1].rows[2].mcLabel.text=='Slot 1')
assert(position(independent)<position(ui.panels[1].headings[2].widget))
assert(position(ui.panels[1].headings[2].widget)<position(ui.panels[1].headings[3].widget))
assert(ui.panels[1].readyEvents==1,'Reordering must notify existing decorators that row paths changed')
ui:refresh();ui:prepare(1);assert(scroll:GetChildrenCount()==count,'No duplicate widgets on reuse')
assert(textCount('Interaction: Independent')==1 and textCount('Interaction: Selective')==1,'Reuse must not duplicate parent headings')
assert(ui.panels[1].readyEvents==1,'Unchanged refresh must not repeat page events')
local header=ui.panels[1].rows[4]
assert(header.mcHeader and header.wrapper:GetParent()==ui.mcHeaderHost)
assert(header.mcPlaceholder.visible==1 and header.mcLabel.Font.Size==22)
assert(header.mcLabel.Slot.Padding.Left==0 and ui.panels[1].rows[1].mcLabel.Slot.Padding.Left==0,
    'Level-one and level-two setting labels must have no stock left indent')
ui.model.pending[4]=0
ui.mcTestSetText(header.value,'Off *')
assert(header.value.text=='Off','Dirty suffix must never flicker in the value text')
local signal
for _,child in ipairs(header.wrapper:GetContent().children) do
    if child.text and child.text:match('^MC_VALUE_DIRTY_1\n') then signal=child end
end
assert(signal and signal.text=='MC_VALUE_DIRTY_1\n1\nOff')
ui.model.committed[4]=0
ui.mcTestSetText(header.value,'Off')
assert(signal.text=='MC_VALUE_DIRTY_1\n0\nOff',
    'Apply must signal clean state even when the displayed value text is unchanged')
ui.model:set(1,0);ui:refresh()
assert(ui.panels[1].readyEvents==2,'Visibility and ordering changes must coalesce into one page-ready event')
ui.model.visibilityOverride=true
function ui.model:visibility() return {true,true,true,true,self.visibilityOverride,true} end
ui:refresh()
assert(ui.panels[1].readyEvents==3,'Visibility-only changes must notify decorators after DMM refresh')
ui:refresh();assert(ui.panels[1].readyEvents==3,'Stable visibility must not repeat page-ready events')
ui.active=nil;local calls=0
ui:tick({},function() calls=calls+1 end,false);assert(calls==0,'Closed menus never inspect tabs')
items[1].group='Player';items[1].label='Quickslots'
local pickerHeaderSchema=schema:gsub('Id=Primary\nmcType=tab\nmcLevel=2',
    'Id=Primary\nmcType=tab\nmcHeading=true'):gsub('Id=Enabled\nmcHeading=true',
    'Id=Enabled\nmcLevel=2')
M.parse(pickerHeaderSchema,items)
local templatePage=controls.build(widget(),{{id='ModCoreTemplates',choices=items}},api)
templatePage.mcHeaderHost=page.controls.mcHeaderHost
templatePage.mcHeaderTitle=page.modTitle
templatePage:show(1)
assert(not templatePage.panels[1].rows[1].mcHeader
    and templatePage.panels[1].rows[1].wrapper:GetParent()==templatePage.panels[1].scroll
    and templatePage.panels[1].rows[1].mcLabel.visible~=1
    and templatePage.panels[1].rows[1].mcLabel.Font.Size==22
    and templatePage.panels[1].rows[1].mcLabel.Slot.Padding.Left==0,
    'Template page must keep its level-one picker in an unindented row')
local pickerHeader=controls.build(widget(),{{id='ModCoreControls',choices=items}},api)
pickerHeader.mcHeaderHost=page.controls.mcHeaderHost
pickerHeader.mcHeaderTitle=page.modTitle
pickerHeader.mcHeaderTabs=page.controls.mcHeaderTabs
pickerHeader.mcHeaderStatus=page.controls.mcHeaderStatus
pickerHeader:show(1)
local headerRow=pickerHeader.panels[1].rows[1]
local headerTabs=headerRow.mcHeaderTabsBox
assert(headerTabs and headerTabs:GetParent()==page.controls.mcHeaderTabs
    and headerTabs.Slot.HorizontalAlignment==3 and headerTabs.Slot.VerticalAlignment==1,
    'Header picker choices must hang right-aligned from the divider')
assert(#headerRow.mcTabs==#items[1].values and #headerTabs.children==2*#items[1].values+1
    and headerRow.value.visible==1 and headerTabs.visible==0,
    'Every header choice must be a tab between separators, replacing the value text')
local tabsWidth=headerRow.mcHeaderTabsWidth
assert(tabsWidth==2*110+3 and statusBox.WidthOverride==572-tabsWidth-12 and statusBox.Slot.Padding.Top==4,
    'The page status must stay beneath the divider, left of the header tabs')
headerRow.mcHeaderTabsWidth=8*70+9;pickerHeader:refresh()
assert(statusBox.WidthOverride==572 and statusBox.Slot.Padding.Top==4+28,
    'A page status without room beside the tabs must drop below them at full width')
headerRow.mcHeaderTabsWidth=tabsWidth;pickerHeader:refresh()
assert(statusBox.WidthOverride==572-tabsWidth-12 and statusBox.Slot.Padding.Top==4,
    'The page status must return beside the tabs when they fit again')
headerRow.mcTabs[2].widget.clicked=true
pickerHeader:tick({},function(w) local clicked=w.clicked;w.clicked=false;return clicked,false,false end,false)
assert(pickerHeader.model.pending[1]==items[1].values[2] and headerRow.mcTabs[2].selected,
    'Clicking a header tab must select its choice')
assert(headerRow.mcTabs[1].label.Font.Size==12 and headerTabs.children[2].HeightOverride==28,
    'Header tabs must use a compact 12-point font and 28-pixel height')
for n,bar in ipairs(headerRow.mcHeaderSeparators) do
    local bright=n==2 or n==3
    assert(#headerRow.mcHeaderSeparators==#items[1].values+1
        and (bar.BrushColor.A>0.5)==bright,
        'Only the separators beside the selected header tab may be bright')
end
for n,tab in ipairs(headerRow.mcTabs) do
    assert((tab.glow.BrushColor.A>0)==(n==2) and tab.widget:GetParent()==tab.glow,
        'Only the selected header tab may glow')
end
assert(pickerHeader.panels[1].rows[1].mcHeader
    and pickerHeader.panels[1].rows[1].mcLabel.Slot.Padding.Left==0
    and pickerHeader.panels[1].rows[1].mcLabel.visible==1
    and page.controls.mcHeaderHost.children[1]==pickerHeader.panels[1].rows[1].wrapper
    and page.controls.mcHeaderHost.children[2]==page.modTitle
    and pickerHeader.panels[1].rows[4].mcLabel.Slot.Padding.Left==0,
    'Level-one picker must share the title row above the divider without a second label')
items[1].values,items[1].labels,items[1].default={0},{'Slot 1'},0
M.parse('[Setting.Primary]\nId=Primary\nmcReadOnly=1\nmcReferenceLabel=Slot 1\nmcType=tab\n',items)
local readOnly=controls.build(widget(),{{choices=items}},api)
readOnly:show(1)
local referenceTabs=readOnly.panels[1].rows[1].mcTabs
assert(not readOnly.panels[1].rows[1].mcStar,'A read-only row is never dirty and gets no star')
assert(#referenceTabs==1 and referenceTabs[1].enabled==false and referenceTabs[1].label.text=='Slot 1',
    'Reference mode is a disabled Slot label')
referenceTabs[1].widget.clicked=true
local before=readOnly.model.pending[1]
readOnly:tick({},function(w) local clicked=w.clicked;w.clicked=false;return clicked,false,false end,false)
assert(readOnly.model.pending[1]==before, 'Reference clicks cannot change the pending value')

for i=#items,1,-1 do items[i]=nil end
for i,group in ipairs({'Before','AlsoBefore','After'}) do
    items[i]={id='Entry'..i,kind=i==1 and 'picker' or 'toggle',group=group,label='Entry '..i,
        values={0,1},labels={'Off','On'}}
end
M.parse('[Category.Before]\nmcHeading=0\n[Category.AlsoBefore]\nmcHeading=0\n',items)
local initial=controls.build(widget(),{{choices=items}},api)
initial:show(1)
for i=1,2 do
    local row=initial.panels[1].rows[i]
    assert(row.mcLabel.Font.Size==16 and row.mcLabel.color=='muted'
        and row.widget:GetContent().Slot.Padding.Left==0
        and row.widget.WidgetStyle.NormalPadding.Left==0
        and row.widget.WidgetStyle.PressedPadding.Left==0
        and row.wrapper.Slot.Padding.Top==12 and row.wrapper.Slot.Padding.Bottom==4,
        'Rows before the first visible category must match its label style and spacing')
end
local after=initial.panels[1].rows[3]
assert(after.mcLabel.Font.Size==14 and after.mcLabel.color=='body'
    and after.widget:GetContent().Slot.Padding.Left==36
    and after.widget.WidgetStyle.NormalPadding.Left==0
    and after.wrapper.Slot.Padding.Top==0 and after.wrapper.Slot.Padding.Bottom==0,
    'Rows after the first category must keep the stock child style')
items[2].mcGroup.heading=true
initial:refresh()
local second=initial.panels[1].rows[2]
assert(second.mcLabel.Font.Size==14 and second.mcLabel.color=='body'
    and second.widget:GetContent().Slot.Padding.Left==36
    and second.widget.WidgetStyle.NormalPadding.Left==0
    and second.wrapper.Slot.Padding.Top==0 and second.wrapper.Slot.Padding.Bottom==0,
    'Showing an earlier category must restore the normal child style')
-- A field-type editor row is built on DMM's toggle row and indents like one,
-- not once on its content and again on its label.
items[4]={id='Entry4',kind='extension',group='After',label='Entry 4',values={0,1},labels={'Off','On'}}
local editorRows=controls.build(widget(),{{choices=items}},api)
editorRows:show(1)
local editorRow=editorRows.panels[1].rows[4]
assert(editorRow.widget:GetContent().Slot.Padding.Left==36 and editorRow.mcLabel.Slot.Padding.Left==0,
    'Editor rows indent once, like toggle rows')
items[4]=nil

-- Row label buttons follow DMM's build order: a picker's arrow and value buttons are
-- never taken for the next row's label, even when that label matches an arrow.
do
    local saved={}
    for i,item in ipairs(items) do saved[i]=item end
    for i=#items,1,-1 do items[i]=nil end
    items[1]={id='Order1',kind='picker',group='Order',label='Mode',values={0,1},labels={'A','B'}}
    items[2]={id='Order2',kind='toggle',group='Order',label='>',values={0,1},labels={'Off','On'}}
    M.parse('',items)
    local ordered=controls.build(widget(),{{choices=items}},api)
    ordered:show(1)
    local picker,toggle=ordered.panels[1].rows[1],ordered.panels[1].rows[2]
    assert(picker.widget.WidgetStyle.NormalPadding.Left==0 and toggle.widget.WidgetStyle.NormalPadding.Left==0
        and picker.parts[3].widget.WidgetStyle.NormalPadding.Left==16,
        'the label after a picker is its own row, not the picker\'s right arrow')
    -- A navigation picker separating colliding keybinds shows its choice and arrows in red,
    -- and returns to DMM's colors when the collision clears.
    ordered.model.mcConflictPickers={[1]=true};ordered:refresh()
    local arrowLeft,arrowRight=picker.parts[1].widget:GetContent(),picker.parts[3].widget:GetContent()
    assert(picker.value.colorAndOpacity.SpecifiedColor.R>0.8 and arrowLeft.colorAndOpacity.SpecifiedColor.R>0.8
        and arrowRight.colorAndOpacity.SpecifiedColor.R>0.8 and not toggle.value.colorAndOpacity,
        'the separating picker turns red, text and arrows')
    ordered.model.mcConflictPickers={};ordered:refresh()
    assert(picker.value.color=='body' and arrowLeft.color=='body' and arrowRight.color=='body',
        'clearing restores the body color')
    -- A failed DMM build leaves no construction state behind; the next build styles normally.
    local failing=controls.build(widget(),{{choices=items}},api)
    failing.mcTestFail='dmm build failed'
    local ok,err=pcall(failing.show,failing,1)
    assert(not ok and err=='dmm build failed','DMM build errors propagate unchanged')
    failing:show(1)
    assert(failing.panels[1].rows[2].widget.WidgetStyle.NormalPadding.Left==0 and failing.panels[1].rows[1].mcStar,
        'after a failed build the page builds and decorates normally')
    for i=#items,1,-1 do items[i]=nil end
    for i,item in ipairs(saved) do items[i]=item end
end

-- An mcCategory row stands in for its hidden group heading: it takes the heading's look
-- and the rest of its group indents beneath it while it shows.
do
    -- The controls fixture always renders the shared items list.
    local saved={}
    for i,item in ipairs(items) do saved[i]=item end
    local list=items
    for i=1,3 do
        list[i]={id='Visual'..i,kind=i==1 and 'picker' or 'toggle',group='Visuals',label='Visual '..i,
            values={0,1},labels={'Off','On'}}
    end
    M.parse('[Category.Visuals]\nmcHeading=0\n[Setting.Visual1]\nId=Visual1\nmcCategory=1\n',list)
    assert(list[1].mcCategory and not list[2].mcCategory)
    local built=controls.build(widget(),{{choices=list}},api)
    built:show(1)
    local heading=built.panels[1].rows[1]
    assert(heading.mcLabel.Font.Size==16 and heading.mcLabel.color=='muted'
        and heading.widget:GetContent().Slot.Padding.Left==0
        and heading.wrapper.Slot.Padding.Top==12,'the category row looks like a category heading')
    for i=2,3 do
        local row=built.panels[1].rows[i]
        assert(row.mcLabel.Font.Size==14 and row.mcLabel.color=='body'
            and row.widget:GetContent().Slot.Padding.Left==36,'rows indent beneath the category row')
    end
    -- The dirty star follows the label text in a box that replaces the label, so an
    -- unindented label never sits under it.
    local line=heading.mcLabel:GetParent()
    assert(line==heading.widget:GetContent() and line.children[1]==heading.mcLabel
        and line.children[2]==heading.mcStar and heading.mcStar.text=='*' and heading.mcStar.visible==2
        and heading.mcLabel.Slot.Padding.Left==0 and heading.mcLabel.Slot.Size.SizeRule==0
        and heading.mcStar.Slot.Padding.Left==4 and heading.mcStar.Slot.Padding.Right==8
        and heading.mcStar.Font.Size==16,'the star follows the category row label, in its font')
    local toggleRow=built.panels[1].rows[2]
    local toggleLine=toggleRow.mcLabel:GetParent()
    assert(toggleLine.children[2]==toggleRow.mcStar and toggleRow.mcStar.Font.Size==14
        and toggleRow.widget:GetContent().children[1]:GetContent()==toggleLine,
        'a toggle row star follows its label inside the label box')
    function built.model:visibility() return {false,true,true} end
    built:refresh()
    local row=built.panels[1].rows[2]
    assert(row.mcLabel.Font.Size==16 and row.widget:GetContent().Slot.Padding.Left==0,
        'a hidden category row indents nothing')
    assert(not pcall(M.parse,'[Setting.Visual1]\nId=Visual1\nmcCategory=1\nmcLevel=2\n',list),
        'mcCategory excludes mcLevel')
    for i=1,3 do items[i]=saved[i] end
end

-- Level-styled labels take their font when built, without waiting for another SetFont.
do
    local saved={}
    for i,item in ipairs(items) do saved[i]=item end
    local list=items
    list[1]={id='Big',kind='picker',group='G',label='Big',values={0,1},labels={'Off','On'}}
    M.parse('[Setting.Big]\nId=Big\nmcLevel=2\n',list)
    local fonts={}
    local plain=api.caption
    api.caption=function(owner,text)
        local w=plain(owner,text)
        function w:SetFont(v) fonts[#fonts+1]=v.Size;self.Font=v end
        return w
    end
    local built=controls.build(widget(),{{choices=list}},api)
    built:show(1)
    api.caption=plain
    local found=false
    for _,size in ipairs(fonts) do if size==20 then found=true end end
    assert(found,'a level-two label applies its 20pt font')
    for i=1,#saved do items[i]=saved[i] end
end

-- A redraw between press and release must not turn one physical click into
-- another new press. The next press in a double click must still be accepted.
local arrow=initial.panels[1].rows[1].parts[1]
local sounds=0
local function pointerStep(pressed,hovered)
    local wasPressed,origin=arrow.pressed,arrow.pointer
    if pressed and not wasPressed then origin=hovered end
    local clicked=wasPressed and not pressed and origin and hovered
    arrow.pressed,arrow.pointer=pressed,origin
    if clicked then sounds=sounds+1;initial:refresh() end
end
pointerStep(true,true)
initial:refresh()
assert(arrow.pressed and arrow.pointer,'refresh must retain an arrow press until release')
pointerStep(false,true)
pointerStep(false,true)
pointerStep(true,true)
initial:refresh()
pointerStep(false,true)
pointerStep(false,true)
assert(sounds==2,'a double click must produce two changes without replaying either release')

local pointerRow=initial.panels[1].rows[1]
pointerRow.lastNavigation=0
pointerRow.nav:SetValue(0.4)
initial:tick({},function() return false,false,false end,false)
assert(pointerRow.nav:GetValue()==0,'mouse drag must not move the hidden picker navigation slider')
pointerRow.nav:SetValue(0.4)
initial:tick({},function() return false,false,false end,true)
assert(pointerRow.nav:GetValue()==0.4,'controller navigation must still reach the picker slider')

local nativeSlider=initial.panels[1].rows[3]
items[3].minimum,items[3].maximum,items[3].step=0,10,2
nativeSlider.slider=widget();nativeSlider.lastValue=0
nativeSlider.slider:SetValue(0.04)
initial:tick({},function() return false,false,false end,false)
assert(nativeSlider.lastValue==0.04,'raw slider movement within one snapped value must be consumed')
nativeSlider.slider:SetValue(0.25)
initial:tick({},function() return false,false,false end,false)
assert(nativeSlider.lastValue==0.04,'a slider move to another snapped value must reach DMM')

print('PASS nested headings, category style before first heading, tabs, font levels, ordering and reuse')

-- mcType=cycle: one button in the keybind key column showing only the current
-- choice at 13pt; a click moves to the next choice and wraps.
for i=#items,1,-1 do items[i]=nil end
items[1]={id='Wheel',kind='picker',group='After',label='Swap back to default',values={1,2},
    labels={'Abilities','Consumables'}}
assert(not pcall(M.parse,'[Setting.Wheel]\nId=Wheel\nmcType=wheel\n',items),'unknown mcType is refused')
M.parse('[Setting.Wheel]\nId=Wheel\nmcType=cycle\n',items)
assert(items[1].mcCycle and not items[1].mcTabs)
local cycling=controls.build(widget(),{{choices=items}},api)
cycling.model.pending[1]=2
cycling:show(1)
local cycleRow=cycling.panels[1].rows[1]
local cycleButton=cycleRow.mcTabs[1]
assert(#cycleRow.mcTabs==1 and cycleButton.label.text=='Consumables','only the current choice is shown')
assert(cycleButton.label.Font.Size==13,'cycle text is 13pt')
assert(cycleButton.box.WidthOverride==96 and cycleButton.box.HeightOverride==32,'the key box width')
local cycleSlot=cycleButton.box.Slot
assert(cycleSlot.HorizontalAlignment==1 and cycleSlot.Padding.Left==20+16+408,
    'it sits in the key column, after the row indent')
cycleButton.widget.clicked=true
cycling:tick({},function(w) local clicked=w.clicked;w.clicked=false;return clicked,false,false end,false)
assert(cycling.model.pending[1]==1 and cycleButton.label.text=='Abilities','a click moves to the next choice and wraps')
print('PASS cycle pickers show one choice in the key column and advance on click')

-- mcWrap: a read-only value in a wider 13pt column, broken at commas below 34
-- characters; the row grows with its lines.
local wrapped,lineCount=M.wrapList('Attack, Block, Dodge, Heavy Attack, Interact, Quickslot Left',34)
assert(wrapped=='Attack, Block, Dodge,\nHeavy Attack, Interact,\nQuickslot Left' and lineCount==3,wrapped)
for line in wrapped:gmatch('[^\n]+') do assert(#line<34,line) end
assert(select(1,M.wrapList('Unassigned',34))=='Unassigned' and select(2,M.wrapList('',34))==1)
for i=#items,1,-1 do items[i]=nil end
items[1]={id='Pad',kind='picker',group='After',label='Face Button Bottom',values={0},
    labels={'Attack, Block, Dodge, Heavy Attack, Interact, Quickslot Left'}}
assert(not pcall(M.parse,'[Setting.Pad]\nId=Pad\nmcWrap=1\n',items),'mcWrap requires a read-only row')
M.parse('[Setting.Pad]\nId=Pad\nmcReadOnly=1\nmcWrap=1\n',items)
local padUi=controls.build(widget(),{{choices=items}},api)
padUi:show(1)
local padRow=padUi.panels[1].rows[1]
assert(padRow.mcWrapped.text==wrapped and padRow.mcWrapped.Font.Size==13,'the wrapped value is 13pt')
assert(padRow.mcWrapped:GetParent().WidthOverride==584-230-24 and padRow.widget:GetParent().WidthOverride==230,
    'the value column is wider than DMM\'s picker value')
assert(padRow.wrapper.HeightOverride==66,'the row grows to fit three lines')
print('PASS wrapped read-only values break at commas in a wider column')

-- mcChoiceNotes: a picker choice's note shows on a small muted second line under
-- DMM's value, which moves up while the current choice has a note.
for i=#items,1,-1 do items[i]=nil end
items[1]={id='Template',kind='picker',group='Visuals',label='Quickslots',values={0,7,9},
    labels={'None','Wheels','Underbar'}}
local notes='[Setting.Template]\nId=Template\nmcChoiceNotes=7:Fangdango;9: Fangdango \n'
for _,bad in ipairs({'7:Fangdango;7:Other','8:Fangdango','7:','7:'..('x'):rep(65),'Fangdango'}) do
    assert(not pcall(M.parse,'[Setting.Template]\nId=Template\nmcChoiceNotes='..bad..'\n',items),bad)
end
local toggleItems={{id='Flag',kind='toggle',group='G',label='Flag',values={0,1},labels={'Off','On'}}}
assert(not pcall(M.parse,'[Setting.Flag]\nId=Flag\nmcChoiceNotes=1:On\n',toggleItems),'pickers only')
M.parse(notes,items)
assert(items[1].mcChoiceNotes[7]=='Fangdango' and items[1].mcChoiceNotes[9]=='Fangdango'
    and items[1].mcChoiceNotes[0]==nil,'notes are trimmed; None has none')
local noteUi=controls.build(widget(),{{choices=items}},api)
noteUi:show(1)
local noteRow=noteUi.panels[1].rows[1]
local noteBox=noteRow.mcNoteBox
-- The note overlays the row with the value's width and place, read from DMM's
-- size boxes; these test rows have none, so DMM's 330+32 and 190 pixels apply.
local noteSlot=noteBox.Slot
assert(noteBox:GetParent()==noteRow.background:GetParent() and noteBox.WidthOverride==190
    and noteSlot.HorizontalAlignment==1 and noteSlot.Padding.Left==362 and noteSlot.VerticalAlignment==3,
    'the note takes the value\'s width, under it')
assert(noteRow.mcNote.Slot.HorizontalAlignment==2 and noteRow.mcNote.Slot.VerticalAlignment==2,
    'the note is centered in that space')
assert(noteRow.mcNote.Font.Size==11 and noteRow.mcNote.color=='muted','the note is small and muted')
assert(#noteRow.parts==3 and noteRow.value.parent~=noteBox,'DMM\'s value keeps its place')
-- None has no note: one line, as today.
assert(noteBox.visible==1 and noteRow.value.Slot.Padding.Bottom==0)
noteUi.model.pending[1]=7;noteUi:refresh()
assert(noteBox.visible==3 and noteRow.mcNote.text=='Fangdango' and noteRow.value.Slot.Padding.Bottom==4
    and noteBox.Slot.Padding.Bottom==4,
    'a noted choice shows its note without taking clicks, and the value moves up')
noteUi.model.pending[1]=0;noteUi:refresh()
assert(noteBox.visible==1 and noteRow.value.Slot.Padding.Bottom==0,'back to one line')
-- A tab picker shows every choice itself and gets no note line.
M.parse(notes..'mcType=tab\n',items)
local tabUi=controls.build(widget(),{{choices=items}},api)
tabUi:show(1)
assert(tabUi.panels[1].rows[1].mcNote==nil,'tab pickers are not covered')
print('PASS picker choice notes show on a second line under the value')
