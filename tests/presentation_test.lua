package.path='Scripts/?.lua;'..package.path
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
mcLevel=1
[Setting.Key]
Id=Key
mcType=keybind
mcOptional=1
[Setting.KeyMode]
Id=KeyMode
mcType=tab
Pair=Key
]]
M.parse(schema,items)
assert(items[5].mcKeybind and items[5].mcOptional,'optional key metadata was not parsed')
assert(not pcall(M.parse,schema:gsub('mcOptional=1','mcOptional=2'),items))
assert(not pcall(M.parse,schema:gsub('mcType=keybind','mcType=tab',1),items))
assert(items[1].mcTabs and items[1].mcFont==2 and items[1].mcTabsWidth==440)
assert(items[2].mcLabelRule.values[0]=='Slot 5')
assert(items[2].mcGroup.parent==items[3].mcGroup.parent,'Shared parent labels must share one descriptor')
assert(items[2].mcGroup.parent.label=='Interaction: Independent' and items[2].mcGroup.parent.font==2)
assert(not items[2].mcGroup.heading and items[3].mcGroup.heading)
assert(items[5].mcGroup.parent.label=='Interaction: Selective')
M.parse(schema:gsub('mcType=tab','DecoType=tab'):gsub('mcLevel=2','DecoLevel=2')
    :gsub('mcTabsWidth=440','DecoTabsWidth=440'):gsub('Pair=Key\n',''),items)
assert(not items[1].mcTabs and items[1].mcFont==nil,'noncanonical metadata must be ignored')
M.parse(schema:gsub('mc','amm'):gsub('Pair=Key\n',''),items)
assert(not items[1].mcTabs and items[1].mcFont==nil,'old amm metadata must not be read')
assert(not pcall(M.parse,schema:gsub('mcType=tab','mcType=tabs'),items))
assert(not pcall(M.parse,schema:gsub('mcTabsWidth=440','mcTabsWidth=441'),items))
assert(not pcall(M.parse,schema:gsub('mcType=tab','mcType=keybind'),items))
assert(not pcall(M.parse,schema:gsub('mcLevel=1','mcLevel=9'),items))
M.parse(schema,items)
assert(not pcall(M.parse,schema:gsub('mcLevel=2','mcLevel=9'),items))
assert(not pcall(M.parse,schema:gsub('mcHeading=0','mcHeading=true'),items))
assert(not pcall(M.parse,schema:gsub('mcLabelWhen=Primary','mcLabelWhen=Missing'),items))
local parentItems={{id='One',kind='toggle',group='One',values={0,1}},{id='Two',kind='toggle',group='Two',values={0,1}}}
assert(not pcall(M.parse,'[Category.One]\nmcParent=\n',parentItems))
assert(not pcall(M.parse,'[Category.One]\nmcParentLevel=2\n',parentItems))
assert(not pcall(M.parse,'[Category.One]\nmcParent=Shared\nmcParentLevel=2\n[Category.Two]\nmcParent=Shared\nmcParentLevel=3\n',parentItems))
M.parse(schema,items)
local function widget()
    local w={children={},Font={SkewAmount=0},enabled=true,position=0,visible=0}
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
    function w:SetBrushColor(v) self.BrushColor=v end
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
local pages={build=function(tree,providers,status,a)
    local filterButton,filterLabel=a.button(tree,'Compatible Mods')
    local browserList=widget()
    local filterWrapper=widget();filterWrapper:SetContent(filterButton);browserList:AddChild(filterWrapper)
    local parent=widget()
    local title=a.caption(tree,'Mod Settings');parent:AddChild(title)
    local divider=widget();parent:AddChild(divider)
    parent:AddChild(widget())
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
    for index,provider in ipairs(providers) do
        local button,label=a.button(tree,provider.name)
        label.Slot:SetPadding({Left=20,Top=4,Right=12,Bottom=4})
        allRows[#allRows+1]={widget=button,providerIndex=index}
    end
    local page={filterButton=filterButton,filterLabel=filterLabel,browserList=browserList,allRows=allRows,
        controls={},modTitle=title,mcTestControlArea=parent,mcTestDivider=divider}
    if providers.lazy then
        page.mounted={allRows[1]}
        page.allRows={{providerIndex=1},{providerIndex=2}}
        function page:window(index)
            self.mounted[1].providerIndex=index
            return true
        end
    end
    function page:refresh(compatibleOnly)
        a.setText(self.filterLabel,compatibleOnly and 'Compatible Mods' or 'All Mods')
    end
    return page
end}
local controls={build=function(tree,providers,a)
    local ui={root=widget(),panels={{rows={},headings={},scroll=widget()}},model={items=items,pending={0,0,0,1,49,-1},committed={0,0,0,1,49,-1}}}
    ui.mcTestSetText=a.setText
    ui.mcTestReleasePanel=a.releasePanel
    function ui.model:visibility() return {true,true,true,true,self.pending[1]==1,true} end
    function ui.root:SetActiveWidgetIndex() self.readyEvents=(self.readyEvents or 0)+1 end
    function ui.model:set(i,v) self.pending[i]=v end
    function ui.model:change(i) self.pending[i]=1-self.pending[i] end
    function ui:prepare()
        local p=self.panels[1];if p.built then return end
        for i,s in ipairs(items) do
            local heading=a.caption(tree,s.group);p.scroll:AddChild(heading)
            p.headings[i]={widget=heading,first=i,last=i,visible=true}
            local b,l=a.button(tree,s.label);l.Slot:SetPadding({Left=20,Top=0,Right=8,Bottom=0})
            local box=widget();box:SetContent(b)
            local bg=widget();local overlay=widget();overlay:AddChild(bg);overlay:AddChild(box)
            local value=a.caption(tree,'');overlay:AddChild(value)
            local parts={}
            for n=1,3 do local b2=a.button(tree,'');local size=widget();size:SetContent(b2);overlay:AddChild(size);parts[n]={widget=b2} end
            local wrapper=widget();wrapper:SetContent(overlay);p.scroll:AddChild(wrapper)
            p.rows[i]={widget=b,value=value,background=bg,parts=parts,wrapper=wrapper,nav=widget(),visible=true}
        end
        p.built=true
    end
    function ui:show(i) self.active=i;self:prepare(i);self:refresh() end
    function ui:refresh()
        local visible=self.model:visibility()
        for i,row in ipairs(self.panels[self.active].rows) do row.visible=visible[i] end
    end
    function ui:tick() self.ticks=(self.ticks or 0)+1;return false end
    function ui:clearPresses() end
    function ui:isPressed() return false end
    function ui:select(i) self.current=i end
    return ui
end}
assert(M.install(choices,controls,pages));assert(not M.install(choices,controls,pages))
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
assert(categoryLabel.Slot.Padding.Left==20,
    'Category modules must accept a small browser indentation')
local ui=controls.build(widget(),{{id='ModCoreTemplates.module.VisualExample',choices=items}},api)
ui.mcHeaderHost=widget()
ui:show(1)
local row=ui.panels[1].rows[1]
assert(#row.mcTabs==2 and row.mcLabel.Font.Size==16)
items[1].mcNavigation,items[1].mcLinkProvider=true,'ModCoreControls'
local linked=controls.build(widget(),{{id='ModCoreTemplates.module.VisualExample',choices=items}},api)
linked.mcHeaderHost=widget()
linked:show(1)
assert(#linked.panels[1].rows[1].mcTabs==1
    and linked.panels[1].rows[1].mcTabs[1].label.text=='Consumables'
    and linked.panels[1].rows[1].mcTabs[1].widget:GetParent():GetParent().WidthOverride==160,
    'provider links must display one clickable tab')
local linkSet=linked.model.set
function linked.model:set(index,value)
    if index==1 and value==0 then self.linkActivated=true end
    return linkSet(self,index,value)
end
linked.panels[1].rows[1].mcTabs[1].widget.clicked=true
linked:tick({},function(w) local clicked=w.clicked;w.clicked=false;return clicked,false,false end,false)
assert(linked.model.linkActivated,'the single link tab must activate even at its default value')
items[1].mcNavigation,items[1].mcLinkProvider=nil,nil
assert(row.mcTabs[1].label.Slot.HorizontalAlignment==0 and row.mcTabs[1].label.Slot.VerticalAlignment==2,
    'Tab labels must fill their allocated button slots for centered text justification')
for _,tab in ipairs(row.mcTabs) do
    assert(#tab.outline==4 and tab.outline[1].BrushColor.R==0.55
        and tab.outline[1].BrushColor.A==0.55 and tab.outline[1].visible==3,
        'Every picker option must have a light one-pixel outline')
end
assert(#linked.panels[1].rows[1].mcTabs[1].outline==4,
    'Provider-link picker options must retain the same outline')
assert(row.mcTabs[1].selected and not row.mcTabs[2].selected)
local keyRow,modeRow=ui.panels[1].rows[5],ui.panels[1].rows[6]
assert(modeRow.mcPairHost and modeRow.mcPairHostBox.visible==1 and keyRow.mcPairOwner==6,
    'The mode row must own the composite and hide its key host while the key is logically hidden')
assert(modeRow.mcTabsWidth==150,
    'Paired pickers must use the original 150-pixel mode column')
assert(#modeRow.mcTabs==2 and modeRow.mcTabs[1].toggleValues[1]==0
    and modeRow.mcTabs[1].toggleValues[2]==3 and modeRow.mcTabs[1].label.text=='Tap'
    and modeRow.mcTabs[2].selected,
    'Tap and Hold must share one control while Default remains separate')
assert(modeRow.mcTabs[1].background:GetParent():GetParent().WidthOverride==75,
    'The shared Tap/Hold control must occupy half of the paired mode column')
local toggleBox=modeRow.mcTabs[1].background:GetParent():GetParent()
local toggleContainer=toggleBox:GetParent()
assert(toggleBox.HeightOverride==modeRow.mcPairHostBox.HeightOverride
    and toggleContainer.RenderTranslation.X==-75
    and toggleContainer.RenderTranslation.X-toggleBox.WidthOverride
        -modeRow.mcPairHostBox.RenderTranslation.X==8,
    'The shared mode control must match key height and sit eight pixels to its right')
assert(modeRow.mcPairHostBox.RenderTranslation and modeRow.mcPairHostBox.RenderTranslation.X==-158,
    'All paired rows must keep the key control in the same fixed column')
assert(modeRow.mcDefaultBackground.RenderTranslation and modeRow.mcDefaultBackground.RenderTranslation.X==-262
    and modeRow.mcPairDisablesKey,
    'Default-capable pairs must render only their Default option in the reserved left column')
assert(modeRow.mcTabs[1].background and modeRow.mcTabs[1].background.BrushColor.A==0.18
    and modeRow.mcTabs[2].background.BrushColor.A==0.18,
    'The shared Tap/Hold button must match the Default background')
modeRow.mcTabs[1].widget.hovered=true
ui:tick({},function() return false,false,false end,false)
assert(modeRow.mcTabs[1].background.BrushColor.R==0.95
    and modeRow.mcTabs[1].background.BrushColor.A==0.22
    and modeRow.mcTabs[2].background.BrushColor.R==0.12,
    'The shared control must retain its hover glow')
modeRow.mcTabs[1].widget.hovered=false
ui:tick({},function() return false,false,false end,false)
assert(modeRow.mcTabs[1].background.BrushColor.A==0.18,
    'Individual paired-tab hover styling must clear on pointer exit')
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
assert(modeRow.mcPairHostBox.visible==0 and keyRow.wrapper.visible==1
    and modeRow.widget:GetParent().WidthOverride==330,
    'A visible paired key must render inside the mode row while its original row remains collapsed')
assert(modeRow.mcTabs[2].selected,
    'The mode owner must preserve the negative Default value')
modeRow.mcTabs[1].widget.clicked=true
ui:tick({},function(w) local clicked=w.clicked;w.clicked=false;return clicked,false,false end,false)
assert(ui.model.pending[6]==0 and modeRow.mcTabs[1].selected and modeRow.mcTabs[1].label.text=='Tap',
    'Clicking the shared mode control from Default must select Tap')
assert(modeRow.mcTabs[1].background.BrushColor.A==0.18,
    'Selecting Tap must keep the Default background opacity')
modeRow.mcTabs[1].widget.hovered=true
ui:tick({},function() return false,false,false end,false)
assert(modeRow.mcTabs[1].background.BrushColor.R==0.95
    and modeRow.mcTabs[1].background.BrushColor.A==0.22,
    'The active paired mode must match the key hover background')
modeRow.mcTabs[1].widget.hovered=false
ui:tick({},function() return false,false,false end,false)
modeRow.mcTabs[1].widget.clicked=true
ui:tick({},function(w) local clicked=w.clicked;w.clicked=false;return clicked,false,false end,false)
assert(ui.model.pending[6]==3 and modeRow.mcTabs[1].selected and modeRow.mcTabs[1].label.text=='Hold',
    'Clicking the same control must select and display the declared Hold value')
modeRow.mcTabs[1].widget.clicked=true
ui:tick({},function(w) local clicked=w.clicked;w.clicked=false;return clicked,false,false end,false)
assert(ui.model.pending[6]==0 and modeRow.mcTabs[1].label.text=='Tap',
    'Another click must return to Tap without creating another control')
modeRow.mcTabs[2].widget.clicked=true
ui:tick({},function(w) local clicked=w.clicked;w.clicked=false;return clicked,false,false end,false)
assert(ui.model.pending[6]==-1 and modeRow.mcTabs[2].selected and modeRow.mcTabs[1].label.text=='Tap',
    'Default must remain selectable without losing the shared control')
assert(modeRow.mcTabs[1].background.BrushColor.A==0.18,
    'Selecting Default again must retain the matching background')
modeRow.mcTabs[1].widget.clicked=true
ui:tick({},function(w) local clicked=w.clicked;w.clicked=false;return clicked,false,false end,false)
modeRow.mcTabs[1].widget.clicked=true
ui:tick({},function(w) local clicked=w.clicked;w.clicked=false;return clicked,false,false end,false)
assert(ui.model.pending[6]==3,'Repeated shared-mode clicks must still reach Hold')
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
    if child.text and child.text:match('^KEM_VALUE_DIRTY_1\n') then signal=child end
end
assert(signal and signal.text=='KEM_VALUE_DIRTY_1\n1\nOff')
ui.model.committed[4]=0
ui.mcTestSetText(header.value,'Off')
assert(signal.text=='KEM_VALUE_DIRTY_1\n0\nOff',
    'Apply must signal clean state even when the displayed value text is unchanged')
ui.model:set(1,0);ui:refresh()
assert(modeRow.mcPairHostBox.visible==1 and ui.model.pending[6]==3,
    'Hiding the paired key must preserve the mode picker and its saved value')
assert(ui.panels[1].readyEvents==2,'Visibility and ordering changes must coalesce into one page-ready event')
ui.model.visibilityOverride=true
function ui.model:visibility() return {true,true,true,true,self.visibilityOverride,true} end
ui:refresh()
assert(ui.panels[1].readyEvents==3,'Visibility-only changes must notify decorators after DMM refresh')
ui:refresh();assert(ui.panels[1].readyEvents==3,'Stable visibility must not repeat page-ready events')
ui.active=nil;local calls=0
ui:tick({},function() calls=calls+1 end,false);assert(calls==0,'Closed menus never inspect tabs')
items[6].values,items[6].labels={0,3},{'Tap','Hold'}
local twoMode=controls.build(widget(),{{choices=items}},api)
twoMode.model.pending[6],twoMode.model.committed[6]=0,0
twoMode:show(1)
local toggle=twoMode.panels[1].rows[6].mcTabs
assert(#toggle==1 and not twoMode.panels[1].rows[6].mcDefaultBackground
    and toggle[1].label.text=='Tap' and toggle[1].background:GetParent():GetParent().WidthOverride==75
    and toggle[1].background:GetParent():GetParent():GetParent().RenderTranslation.X==-75,
    'A paired mode without Default must render one full-width Tap/Hold control')
toggle[1].widget.clicked=true
twoMode:tick({},function(w) local clicked=w.clicked;w.clicked=false;return clicked,false,false end,false)
assert(twoMode.model.pending[6]==3 and toggle[1].label.text=='Hold',
    'The two-value pair must toggle to its declared Hold value')
items[1].group='Player';items[1].label='Quickslots'
local pickerHeaderSchema=schema:gsub('Id=Primary\nmcType=tab\nmcLevel=2',
    'Id=Primary\nmcType=tab\nmcLevel=1'):gsub('Id=Enabled\nmcLevel=1',
    'Id=Enabled\nmcLevel=2')
M.parse(pickerHeaderSchema,items)
local templatePage=controls.build(widget(),{{id='ModCoreTemplates',choices=items}},api)
templatePage.mcHeaderHost=page.controls.mcHeaderHost
templatePage.mcHeaderTitle=page.modTitle
templatePage:show(1)
assert(not templatePage.panels[1].rows[1].mcHeader
    and templatePage.panels[1].rows[1].wrapper:GetParent()==templatePage.panels[1].scroll
    and templatePage.panels[1].rows[1].mcLabel.visible~=1
    and templatePage.panels[1].rows[1].mcLabel.Font.Size==16
    and templatePage.panels[1].rows[1].mcLabel.Slot.Padding.Left==0,
    'Template page must keep its level-two picker in an unindented row')
local pickerHeader=controls.build(widget(),{{id='ModCoreControls',choices=items}},api)
pickerHeader.mcHeaderHost=page.controls.mcHeaderHost
pickerHeader.mcHeaderTitle=page.modTitle
pickerHeader:show(1)
assert(pickerHeader.panels[1].rows[1].mcHeader
    and pickerHeader.panels[1].rows[1].mcLabel.Slot.Padding.Left==0
    and pickerHeader.panels[1].rows[1].mcLabel.visible==1
    and page.controls.mcHeaderHost.children[1]==pickerHeader.panels[1].rows[1].wrapper
    and page.controls.mcHeaderHost.children[2]==page.modTitle
    and pickerHeader.panels[1].rows[4].mcLabel.Slot.Padding.Left==0,
    'Level-one picker must share the title row above the divider without a second label')
pickerHeader.mcTestReleasePanel(pickerHeader.panels[1])
assert(not pickerHeader.panels[1].mcHeader and not pickerHeader.panels[1].rows[1].wrapper:GetParent(),
    'Eviction must detach the header that lives outside the panel scroll')
browserProviders.lazy=true
local recycled=pages.build(widget(),browserProviders,nil,api)
local recycledLabel=recycled.mounted[1].widget:GetContent()
assert(recycledLabel.Font.Size==16)
assert(recycled:window(2) and recycledLabel.Font.Size==14 and recycledLabel.Slot.Padding.Left==20,
    'Recycled browser rows must take the new provider style')
assert(recycled:window(1) and recycledLabel.Font.Size==16 and recycledLabel.Slot.Padding.Left==0,
    'Recycling must also clear the previous provider indentation')
print('PASS nested headings, tab clicks, selected state, font levels, dynamic labels/order, page reuse and closed-menu inactivity')
items[1].values,items[1].labels,items[1].default={0},{'Slot 1'},0
M.parse('[Setting.Primary]\nId=Primary\nmcReadOnly=1\nmcReferenceLabel=Slot 1\nmcType=tab\n',items)
local readOnly=controls.build(widget(),{{choices=items}},api)
readOnly:show(1)
local referenceTabs=readOnly.panels[1].rows[1].mcTabs
assert(#referenceTabs==1 and referenceTabs[1].enabled==false and referenceTabs[1].label.text=='Slot 1',
    'Reference mode is a disabled Slot label')
referenceTabs[1].widget.clicked=true
local before=readOnly.model.pending[1]
readOnly:tick({},function(w) local clicked=w.clicked;w.clicked=false;return clicked,false,false end,false)
assert(readOnly.model.pending[1]==before, 'Reference clicks cannot change the pending value')
