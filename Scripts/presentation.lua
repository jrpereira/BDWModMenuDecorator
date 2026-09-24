-- Runs in DMM's Lua state. Uses its existing menu tick and model, never a timer.
local M={version=1}
local pairHostMarkerPrefix='KEM_PAIR_HOST_1\n'
local dirtySignalPrefix='KEM_VALUE_DIRTY_1\n'
local function trim(s) return (s or ''):match('^%s*(.-)%s*$') end
local function identityText(value)
    return tostring(value):gsub('%%','%%25'):gsub('\n','%%0A'):gsub('\r','%%0D')
end
local function settingIdentity(index,provider,setting)
    local values,labels=setting.values or {},setting.labels or {}
    assert(#values==#labels and #values<=64,'invalid setting identity choices')
    local fields={'KEM_SETTING_3',tostring(index),identityText(provider.id),identityText(setting.id),
        setting.kind or '',tostring(setting.minimum or ''),tostring(setting.maximum or ''),
        tostring(setting.step or ''),tostring(setting.decimals or ''),identityText(setting.prefix or ''),
        identityText(setting.suffix or ''),setting.mcKeybind and '1' or '0',
        identityText(setting.mcFixedMode or ''),identityText(setting.mcPairId or ''),
        tostring(setting.mcTabsWidth or ''),identityText(setting.mcPairTargetId or ''),tostring(#values)}
    for _,value in ipairs(values) do fields[#fields+1]=identityText(value) end
    for _,label in ipairs(labels) do fields[#fields+1]=identityText(label) end
    local result=table.concat(fields,'\n')
    assert(#result<=16384,'setting identity exceeds 16 KiB')
    return result
end
local styles={
    [1]={22,'title'},[2]={16,'muted'},[3]={15,'muted'},
    [4]={14,'body'},[5]={12,'muted'},[6]={11,'muted'},
}
function M.parse(content,items)
    local sections,current={},nil
    for line in (content..'\n'):gmatch('([^\n]*)\n') do
        local header=trim(line):match('^%[([^%]]+)%]$')
        if header then current={name=header};sections[#sections+1]=current
        elseif current and not trim(line):match('^[;#]') then
            local key,value=line:match('^%s*([^=]+)=(.*)$')
            if key then current[trim(key)]=trim(value) end
        end
    end
    local byId,groups,parents,seen,count={},{},{},{},0
    for _,s in ipairs(items) do
        byId[s.id]=s
        s.mcPairId,s.mcPairIndex,s.mcPairTargetIndex=nil,nil,nil
    end
    local function level(value)
        if value==nil then return nil end
        return assert(tonumber(value:match('^[0-6]$')),'mcLevel must be an integer from 0 through 6')
    end
    local function flag(value,name)
        if value==nil then return nil end
        assert(value=='0' or value=='1',name..' must be 0 or 1')
        return value=='1'
    end
    local function labelRule(r)
        if not r.mcLabelWhen and not r.mcLabels then return nil end
        local source=assert(byId[r.mcLabelWhen],'unknown mcLabelWhen')
        assert(source.kind~='slider','mcLabelWhen requires a picker or toggle')
        local result={source=source,values={}}
        for entry in ((r.mcLabels or '')..';'):gmatch('(.-);') do
            local value,label=entry:match('^%s*([^:]+):(.+)$')
            value=tonumber(value)
            assert(value and label and not result.values[value],'invalid mcLabels')
            local valid=false
            for _,v in ipairs(source.values) do if v==value then valid=true end end
            assert(valid,'mcLabels value outside source choices')
            result.values[value]=trim(label)
        end
        return result
    end
    for _,r in ipairs(sections) do
        local group=r.name:match('^Category%.(.+)$')
        if group then
            local order=labelRule({mcLabelWhen=r.mcOrderWhen,mcLabels=r.mcOrders})
            if order then
                for value,rank in pairs(order.values) do
                    rank=tonumber(rank)
                    assert(rank and rank==rank and math.abs(rank)<=1000000,'invalid mcOrders rank')
                    order.values[value]=rank
                end
            end
            local parent
            if r.mcParent~=nil then
                local label=trim(r.mcParent)
                assert(label~='','mcParent requires a non-empty label')
                local font=level(r.mcParentLevel) or 2
                parent=parents[label]
                if parent then assert(parent.font==font,'categories sharing mcParent must use the same mcParentLevel')
                else parent={key=label,label=label,font=font};parents[label]=parent end
            elseif r.mcParentLevel~=nil then error('mcParentLevel requires mcParent') end
            groups[group]={font=level(r.mcLevel),help=r.mcHelp,labelRule=labelRule(r),order=order,parent=parent,
                heading=flag(r.mcHeading,'mcHeading')~=false}
        end
        if r.name=='Setting' or r.name:match('^Setting%.') then
            count=count+1
            local id=r.Id or 'setting_'..count
            local s=byId[id]
            if s and not seen[id] then
                seen[id]=true
                s.mcFont=level(r.mcLevel)
                if r.mcMode~=nil then
                    assert(r.mcMode=='Tap' or r.mcMode=='Hold','mcMode must be Tap or Hold')
                    assert(r.mcType=='keybind' and s.kind=='slider','mcMode requires a keybind setting')
                    s.mcFixedMode=r.mcMode
                end
                s.mcLabelRule=labelRule(r)
                s.mcTabs,s.mcTabsWidth,s.mcHeader,s.mcPairTargetId=nil,nil,nil,nil
                local hasLevel=r.mcLevel~=nil
                local decoration=r.mcType
                if decoration~=nil then assert(decoration=='tab' or decoration=='keybind','mcType must be tab or keybind') end
                s.mcKeybind=decoration=='keybind'
                if decoration=='tab' then
                    assert(s.kind=='picker','mcType=tab requires a picker')
                    assert(#s.values<=8,'mcType=tab supports at most eight choices')
                    s.mcTabs=true
                end
                if r.Pair~=nil then
                    assert(decoration=='tab' and s.kind=='picker','Pair must be declared by an mcType=tab picker')
                    assert(trim(r.Pair)~='','Pair requires a setting Id')
                    s.mcPairTargetId=trim(r.Pair)
                end
                if r.mcTabsWidth~=nil then
                    local width=tonumber(r.mcTabsWidth)
                    assert(decoration=='tab','mcTabsWidth requires mcType=tab')
                    assert(width and width%1==0 and width>=160 and width<=440,
                        'mcTabsWidth must be an integer from 160 through 440')
                    s.mcTabsWidth=width
                end
                if r.mcHeader~=nil and not hasLevel then
                    assert(r.mcHeader=='0' or r.mcHeader=='1','mcHeader must be 0 or 1')
                    assert(r.mcHeader=='0' or s.kind=='toggle','mcHeader=1 requires a toggle')
                    s.mcHeader=r.mcHeader=='1'
                end
                if hasLevel then s.mcHeader=s.mcFont==1 end
            end
        end
    end
    local headers=0
    for index,s in ipairs(items) do
        s.mcGroup=groups[s.group]
        if s.mcPairTargetId then
            local target=assert(byId[s.mcPairTargetId],'unknown Pair setting')
            assert(target.kind=='slider' and target.mcKeybind,'Pair target must be an mcType=keybind integer setting')
            assert(not target.mcPairId,'keybind setting cannot belong to more than one Pair')
            target.mcPairId=s.id;target.mcPairIndex=index;s.mcPairTargetIndex=nil
            for i,candidate in ipairs(items) do if candidate==target then s.mcPairTargetIndex=i;break end end
        end
        if s.mcHeader then headers=headers+1 end
    end
    assert(headers<=1,'only one level-one setting per provider')
    return items
end
function M.style(label,level,api)
    local style=styles[level]
    if not style then return end
    api.Theme.font(label,api.theme,style[1])
    api.Theme.textColor(label,style[2])
    if level==5 then label:SetRenderOpacity(0.85) end
end
function M.install(choices,controls,pages)
    if controls.mcPresentationVersion then return false end
    local parse,build=choices.parse,controls.build
    choices.parse=function(content) return M.parse(content,parse(content)) end
    controls.build=function(tree,providers,api)
        local adapted={}
        -- Cached pages may be evicted; do not retain their Lua widget wrappers.
        local labels=setmetatable({},{__mode='k'})
        local helpWidgets=setmetatable({},{__mode='k'})
        local valueSignals=setmetatable({},{__mode='k'})
        local ui
        local constructing,pendingHelp
        for k,v in pairs(api) do adapted[k]=v end
        adapted.releasePanel=function(panel,provider)
            -- A Level 1 row was moved outside the evicted ScrollBox.
            if panel.mcHeader then
                panel.mcHeader.wrapper:RemoveFromParent()
                panel.mcHeader=nil
            end
            if api.releasePanel then api.releasePanel(panel,provider) end
        end
        adapted.setText=function(widget,value)
            local signal=valueSignals[widget]
            if not signal then return api.setText(widget,value) end
            local setting=ui.model and ui.model.items[signal.index]
            local clean=setting and not ui.model.error
                and choices.format(setting,ui.model.pending[signal.index]) or nil
            local dirty=clean~=nil and value==clean..' *'
            local display=dirty and clean or value
            api.setText(signal.marker,dirtySignalPrefix..(dirty and '1' or '0')..'\n'..display)
            return api.setText(widget,display)
        end
        adapted.caption=function(owner,text)
            local label=api.caption(owner,text)
            if constructing then
                for _,s in ipairs(providers[constructing].choices or {}) do
                    if text==s.group and s.mcGroup and s.mcGroup.heading and s.mcGroup.help then
                        pendingHelp={heading=label,text=s.mcGroup.help};break
                    end
                end
            end
            return label
        end
        adapted.button=function(...)
            if pendingHelp then
                local help=api.caption(tree,pendingHelp.text);help:SetAutoWrapText(true)
                M.style(help,5,api)
                local slot=api.need(pendingHelp.heading:GetParent():AddChild(help),'KEM group help')
                slot:SetPadding({Left=20,Top=0,Right=20,Bottom=8})
                helpWidgets[pendingHelp.heading]=help;pendingHelp=nil
            end
            local button,label=api.button(...);labels[button]=label;return button,label
        end
        ui=build(tree,providers,adapted)
        local prepare,show,refresh,tick,clearPresses,isPressed=ui.prepare,ui.show,ui.refresh,ui.tick,ui.clearPresses,ui.isPressed
        local function styleBackground(tab,hovered)
            if not tab.background then return end
            if tab.backgroundHovered==hovered then return end
            tab.background:SetBrushColor(hovered
                and {R=0.95,G=0.63,B=0.08,A=0.22}
                or {R=0.12,G=0.12,B=0.12,A=0.18})
            tab.backgroundHovered=hovered
        end
        local function new(kind) return api.construct('/Script/UMG.'..kind,tree) end
        local function add(parent,child) return api.need(parent:AddChild(child),'KEM presentation child') end
        local function sized(child,width,height)
            local box=new('SizeBox');box:SetWidthOverride(width);box:SetHeightOverride(height or 40)
            local slot=api.need(box:SetContent(child),'KEM presentation size')
            slot:SetHorizontalAlignment(0);slot:SetVerticalAlignment(0)
            return box
        end
        local function decorate(index)
            local panel=ui.panels[index]
            if panel.mcPresented then return end
            for i,row in ipairs(panel.rows) do
                local setting=providers[index].choices[i]
                row.mcLabel=labels[row.widget]
                local identity=api.caption(tree,settingIdentity(i,providers[index],setting))
                identity:SetVisibility(1)
                add(row.wrapper:GetContent(),identity)
                if row.value then
                    local marker=api.caption(tree,dirtySignalPrefix..'0\n')
                    marker:SetVisibility(1)
                    add(row.wrapper:GetContent(),marker)
                    valueSignals[row.value]={marker=marker,index=i}
                end
                if setting.mcFixedMode then
                    row.mcModeState=api.caption(tree,'KEM_MODE\nfixed')
                    row.mcModeState:SetVisibility(1)
                    add(row.wrapper:GetContent(),row.mcModeState)
                end
                local level=setting.mcFont
                if level==1 and providers[index].id=='ModCoreTemplates' then level=2 end
                M.style(row.mcLabel,level,api)
                if level==1 then
                    local slot=setting.kind=='toggle' and row.widget:GetContent().Slot or row.mcLabel.Slot
                    local padding=slot.Padding
                    slot:SetPadding({Left=0,Top=padding.Top,Right=padding.Right,Bottom=padding.Bottom})
                end
                if setting.mcHeader and ui.mcHeaderHost and providers[index].id~="ModCoreTemplates" then
                    assert(not panel.mcHeader,'only one level-one setting per provider')
                    local placeholder=new('SizeBox')
                    local path=assert(row.wrapper:GetFullName():match('^%S+ (.+)$'))
                    local marker=api.caption(tree,'KEM_HEADER_ROW\n'..path)
                    api.need(placeholder:SetContent(marker),'KEM header identity')
                    placeholder:SetVisibility(1)
                    local children={}
                    for n=0,panel.scroll:GetChildrenCount()-1 do
                        local child=panel.scroll:GetChildAt(n)
                        local padding=child.Slot.Padding
                        children[#children+1]={widget=child:GetFullName()==row.wrapper:GetFullName() and placeholder or child,
                            padding={Left=padding.Left,Top=padding.Top,Right=padding.Right,Bottom=padding.Bottom}}
                    end
                    panel.scroll:ClearChildren()
                    for _,child in ipairs(children) do add(panel.scroll,child.widget):SetPadding(child.padding) end
                    row.mcLabel:SetVisibility(1)
                    add(ui.mcHeaderHost,row.wrapper)
                    local title=ui.mcHeaderTitle
                    if title then
                        assert(ui.mcHeaderHost:RemoveChild(title),'KEM page title relocation')
                        local titleSlot=add(ui.mcHeaderHost,title)
                        titleSlot:SetHorizontalAlignment(1);titleSlot:SetVerticalAlignment(2)
                    end
                    row.mcHeader=true;row.mcPlaceholder=placeholder;panel.mcHeader=row
                end
                if setting.mcTabs then
                    -- Keep DMM's original controls alive for navigation, dirty
                    -- notifications and reconstruction. No stock reparenting.
                    local tabs=new('HorizontalBox')
                    row.mcTabs={}
                    local count=#setting.values
                    local paired=setting.mcPairTargetId~=nil
                    local disablesKey=paired and count>=3 and setting.values[3]==-1
                    local totalWidth=paired and 150 or (setting.mcTabsWidth or math.min(384,110*count))
                    local keySpace=paired and 104 or 0
                    local defaultSpace=paired and 104 or 0
                    local choices={}
                    for n,value in ipairs(setting.values) do
                        if not paired or n~=2 or count<2 then
                            local choice={value=value,label=setting.labels[n],isDefault=disablesKey and n==3}
                            if paired and n==1 and count>=2 then
                                choice.toggleValues={setting.values[1],setting.values[2]}
                                choice.toggleLabels={setting.labels[1],setting.labels[2]}
                            end
                            choices[#choices+1]=choice
                        end
                    end
                    local modeCount=#choices-(disablesKey and 1 or 0)
                    local width=totalWidth/modeCount
                    if paired and count>=2 then
                        width=modeCount>1 and (totalWidth/2)/(modeCount-1) or totalWidth/2
                    end
                    local defaultTabs=disablesKey and new('HorizontalBox') or nil
                    if paired then row.mcTabsBackgrounds={} end
                    for _,choice in ipairs(choices) do
                        local button,label=api.button(tree,choice.label);button.IsFocusable=false
                        label:SetJustification(1);label:SetTextOverflowPolicy(1)
                        -- Stretch the text block across the fixed-width button, then
                        -- let centered text justification position its contents.
                        label.Slot:SetHorizontalAlignment(0);label.Slot:SetVerticalAlignment(2)
                        local isDefault=choice.isDefault
                        local visible=button
                        local background
                        if paired then
                            background=new('Border')
                            background:SetBrushColor({R=0.12,G=0.12,B=0.12,A=0.18})
                            api.need(background:SetContent(button),'KEM paired tab background')
                            row.mcTabsBackgrounds[#row.mcTabsBackgrounds+1]=background
                            visible=background
                        end
                        local choiceWidth=choice.toggleValues and totalWidth/2 or width
                        add(isDefault and defaultTabs or tabs,
                            sized(visible,isDefault and 96 or choiceWidth,choice.toggleValues and 32 or nil))
                        row.mcTabs[#row.mcTabs+1]={widget=button,label=label,value=choice.value,
                            toggleValues=choice.toggleValues,toggleLabels=choice.toggleLabels,
                            pressed=false,pointer=false,background=background}
                    end
                    local overlay=row.background:GetParent()
                    if paired and count>=2 and modeCount==1 then
                        tabs:SetRenderTranslation({X=-totalWidth/2,Y=0})
                    end
                    local slot=add(overlay,tabs);slot:SetHorizontalAlignment(3);slot:SetVerticalAlignment(2)
                    if paired then row.mcTabsBackground=row.mcTabsBackgrounds[1] end
                    if defaultTabs then
                        defaultTabs:SetRenderTranslation({X=-(totalWidth+8+96+8),Y=0})
                        row.mcDefaultBackground=defaultTabs
                        local defaultSlot=add(overlay,defaultTabs)
                        defaultSlot:SetHorizontalAlignment(3);defaultSlot:SetVerticalAlignment(2)
                    end
                    row.widget:GetParent():SetWidthOverride(584-totalWidth-keySpace-defaultSpace)
                    if paired then
                        local hostBox=new('SizeBox');hostBox:SetWidthOverride(96);hostBox:SetHeightOverride(32)
                        local host=new('Overlay');api.need(hostBox:SetContent(host),'KEM pair host content')
                        local marker=api.caption(tree,pairHostMarkerPrefix..setting.mcPairTargetId)
                        marker:SetVisibility(1);add(host,marker)
                        hostBox:SetRenderTranslation({X=-(totalWidth+8),Y=0})
                        local hostSlot=add(overlay,hostBox);hostSlot:SetHorizontalAlignment(3);hostSlot:SetVerticalAlignment(2)
                        row.mcPairHost,row.mcPairHostBox,row.mcTabsWidth,row.mcPairDisablesKey=
                            host,hostBox,totalWidth,disablesKey
                        panel.rows[setting.mcPairTargetIndex].mcPairOwner=i
                    end
                    for _,part in ipairs(row.parts) do part.widget:GetParent():SetVisibility(1) end
                end
            end
            local parentWidgets={}
            for _,heading in ipairs(panel.headings) do
                local setting=providers[index].choices[heading.first]
                if setting.mcGroup then
                    M.style(heading.widget,setting.mcGroup.font,api)
                    if not setting.mcGroup.heading then
                        heading.widget:SetVisibility(1);heading.visible=false
                    end
                    local parent=setting.mcGroup.parent
                    if parent then
                        heading.mcParent=parent
                        if not parentWidgets[parent.key] then
                            local label=api.caption(tree,parent.label);M.style(label,parent.font,api)
                            local slot=add(panel.scroll,label)
                            slot:SetPadding({Left=0,Top=18,Right=0,Bottom=6})
                            parentWidgets[parent.key]={widget=label,parent=parent}
                        end
                    end
                end
            end
            -- Capture existing scroll children only once, after construction.
            -- Ordering moves whole category blocks; rows retain their children.
            local ordered=false
            for _,s in ipairs(providers[index].choices) do if s.mcGroup and s.mcGroup.order then ordered=true end end
            if ordered or next(parentWidgets) then
                panel.mcBlocks={}
                local known={}
                local function capture(block,child)
                    local p=child.Slot.Padding
                    block.children[#block.children+1]={widget=child,padding={Left=p.Left,Top=p.Top,Right=p.Right,Bottom=p.Bottom}}
                    known[child]=true
                end
                for _,heading in ipairs(panel.headings) do
                    local block={heading=heading,parent=heading.mcParent,children={}};panel.mcBlocks[#panel.mcBlocks+1]=block
                    capture(block,heading.widget)
                    if helpWidgets[heading.widget] then capture(block,helpWidgets[heading.widget]) end
                    for i=heading.first,heading.last do capture(block,panel.rows[i].mcPlaceholder or panel.rows[i].wrapper) end
                end
                local extra={children={}}
                -- Parent headings were added only to obtain real UMG widgets.
                -- They are rebuilt from mcLayout and must not become extras.
                for _,entry in pairs(parentWidgets) do known[entry.widget]=true end
                for n=0,panel.scroll:GetChildrenCount()-1 do
                    local child=panel.scroll:GetChildAt(n)
                    if not known[child] then capture(extra,child) end
                end
                panel.mcLayout={}
                local entriesByParent={}
                local unparented
                for _,block in ipairs(panel.mcBlocks) do
                    local entry
                    if block.parent then
                        entry=entriesByParent[block.parent.key]
                        if not entry then
                            entry={parent=block.parent,parentWidget=parentWidgets[block.parent.key].widget,blocks={}}
                            entriesByParent[block.parent.key]=entry;panel.mcLayout[#panel.mcLayout+1]=entry
                        end
                        unparented=nil
                    else
                        if not unparented then unparented={blocks={}};panel.mcLayout[#panel.mcLayout+1]=unparented end
                        entry=unparented
                    end
                    entry.blocks[#entry.blocks+1]=block
                end
                if #extra.children>0 then panel.mcLayout[#panel.mcLayout+1]={blocks={extra},extra=true} end
                panel.mcParentWidgets=parentWidgets
            end
            panel.mcPresented=true
        end
        function ui:prepare(index)
            constructing=index;prepare(self,index);constructing=nil;decorate(index)
        end
        function ui:show(index) self:prepare(index);return show(self,index) end
        local function dynamic(rule,model,fallback)
            if not rule then return fallback end
            for i,s in ipairs(model.items) do
                if s.id==rule.source.id then return rule.values[model.pending[i]] or fallback end
            end
            return fallback
        end
        function ui:refresh(...)
            if self.active then decorate(self.active) end
            local result=refresh(self,...)
            local pageReady=false
            local logicalVisibility
            for i,row in ipairs(self.panels[self.active].rows) do
                local setting=self.model.items[i]
                if setting.mcPairTargetIndex then
                    logicalVisibility=logicalVisibility or self.model:visibility()
                    local keyVisible=logicalVisibility[setting.mcPairTargetIndex]==true
                    row.mcPairHostBox:SetVisibility(keyVisible and 0 or 1)
                    row.widget:GetParent():SetWidthOverride(584-row.mcTabsWidth-(keyVisible and 104 or 0))
                    self.panels[self.active].rows[setting.mcPairTargetIndex].wrapper:SetVisibility(1)
                end
                if row.mcModeState then
                    logicalVisibility=logicalVisibility or self.model:visibility()
                    local target=setting.mcPairIndex
                    local editable=target and logicalVisibility[target]==true or false
                    if row.mcModeEditable~=editable then
                        api.setText(row.mcModeState,'KEM_MODE\n'..(editable and 'editable' or 'fixed'))
                        row.mcModeEditable=editable
                    end
                end
                if row.mcHeader then row.wrapper:SetVisibility(row.visible and 0 or 1) end
                if setting.mcLabelRule then
                    local text=dynamic(setting.mcLabelRule,self.model,setting.label)
                    if text~=row.mcLabelText then api.setText(row.mcLabel,text);row.mcLabelText=text end
                end
                for _,tab in ipairs(row.mcTabs or {}) do
                    local mapping=self.model.items[i].mcMapping
                    local enabled=not self.model.error and (not mapping or tab.value~=mapping.custom)
                    local current=self.model.pending[i]
                    local selected=tab.toggleValues and
                        (current==tab.toggleValues[1] or current==tab.toggleValues[2]) or current==tab.value
                    if tab.toggleValues then
                        local display=current==tab.toggleValues[2] and tab.toggleLabels[2] or tab.toggleLabels[1]
                        if tab.display~=display then api.setText(tab.label,display);tab.display=display end
                        styleBackground(tab,tab.hovered==true)
                    end
                    if tab.selected~=selected or tab.enabled~=enabled then
                        api.Theme.textColor(tab.label,selected and 'menuActive' or 'body')
                        tab.widget:SetIsEnabled(enabled)
                        tab.widget:SetRenderOpacity((enabled or selected) and 1 or 0.45)
                        tab.selected,tab.enabled=selected,enabled
                    end
                    tab.pressed,tab.pointer=false,false
                end
            end
            for index,panel in ipairs(self.panels) do
                if index~=self.active and panel.mcHeader then panel.mcHeader.wrapper:SetVisibility(1) end
            end
            for _,heading in ipairs(self.panels[self.active].headings) do
                local setting=self.model.items[heading.first]
                local shown=false
                for i=heading.first,heading.last do
                    local row=self.panels[self.active].rows[i]
                    if row.visible and not row.mcHeader then shown=true;break end
                end
                local group=setting.mcGroup
                heading.mcContentVisible=shown
                local headingShown=shown and (not group or group.heading)
                if heading.visible~=headingShown then
                    heading.widget:SetVisibility(headingShown and 0 or 1);heading.visible=headingShown
                end
                if group and group.labelRule then
                    local text=dynamic(group.labelRule,self.model,setting.group)
                    if heading.mcText~=text then api.setText(heading.widget,text);heading.mcText=text end
                end
                local help=helpWidgets[heading.widget]
                if help and heading.mcHelpVisible~=heading.visible then
                    help:SetVisibility(heading.visible and 4 or 1);heading.mcHelpVisible=heading.visible
                end
            end
            local panel=self.panels[self.active]
            local visible={}
            for i,row in ipairs(panel.rows) do visible[i]=row.visible and '1' or '0' end
            local visibilitySignature=table.concat(visible)
            if panel.mcVisibility and panel.mcVisibility~=visibilitySignature then pageReady=true end
            panel.mcVisibility=visibilitySignature
            if panel.mcBlocks then
                local signatureParts,orderedFlat={},{}
                local function reorder(blocks)
                    local slots,candidates,result={},{},{}
                    for n,block in ipairs(blocks) do
                        result[n]=block
                        local s=block.heading and self.model.items[block.heading.first]
                        local rule=s and s.mcGroup and s.mcGroup.order
                        local rank=dynamic(rule,self.model,n)
                        signatureParts[#signatureParts+1]=(block.heading and tostring(block.heading.first) or 'extra')..'='..tostring(rank)
                        if rule then
                            slots[#slots+1]=n;candidates[#candidates+1]={block=block,rank=rank,original=n}
                        end
                    end
                    table.sort(candidates,function(a,b) return a.rank==b.rank and a.original<b.original or a.rank<b.rank end)
                    for n,position in ipairs(slots) do result[position]=candidates[n].block end
                    return result
                end
                for _,entry in ipairs(panel.mcLayout) do
                    signatureParts[#signatureParts+1]='parent='..(entry.parent and entry.parent.key or '')
                    entry.orderedBlocks=reorder(entry.blocks)
                    for _,block in ipairs(entry.orderedBlocks) do
                        if block.heading then orderedFlat[#orderedFlat+1]=block end
                    end
                end
                local signature=table.concat(signatureParts,':')
                if signature~=panel.mcOrder or not panel.mcLayoutBuilt then
                    panel.scroll:ClearChildren()
                    for _,entry in ipairs(panel.mcLayout) do
                        if entry.parentWidget then
                            add(panel.scroll,entry.parentWidget):SetPadding({Left=0,Top=18,Right=0,Bottom=6})
                        end
                        for _,block in ipairs(entry.orderedBlocks) do
                            for _,child in ipairs(block.children) do add(panel.scroll,child.widget):SetPadding(child.padding) end
                        end
                    end
                    if panel.mcLayoutBuilt then pageReady=true end
                    panel.mcOrder=signature
                    panel.mcLayoutBuilt=true
                end
                panel.mcOrderedBlocks=orderedFlat
                for _,entry in ipairs(panel.mcLayout) do
                    if entry.parentWidget then
                        local shown=false
                        for _,block in ipairs(entry.blocks) do
                            if block.heading and block.heading.mcContentVisible then shown=true;break end
                        end
                        if entry.parentVisible~=shown then
                            entry.parentWidget:SetVisibility(shown and 4 or 1);entry.parentVisible=shown
                        end
                    end
                end
                if self.visibleRows then
                    local visible={}
                    -- Header controls precede scroll content for navigation.
                    for i,row in ipairs(panel.rows) do if row.mcHeader and row.visible and not row.mcPairOwner then visible[#visible+1]=i end end
                    for _,block in ipairs(panel.mcOrderedBlocks or panel.mcBlocks) do
                        if block.heading then
                            for i=block.heading.first,block.heading.last do
                                if panel.rows[i].visible and not panel.rows[i].mcHeader and not panel.rows[i].mcPairOwner then visible[#visible+1]=i end
                            end
                        end
                    end
                    self.visibleRows=visible;self:wireNavigation(self.footer)
                end
            end
            if self.visibleRows and not panel.mcBlocks then
                local navigation={}
                for i,row in ipairs(panel.rows) do
                    if row.visible and not row.mcPairOwner then navigation[#navigation+1]=i end
                end
                self.visibleRows=navigation;self:wireNavigation(self.footer)
            end
            if pageReady then
                -- Cached panels have no stable child index after eviction.
                -- Notify decorators directly without changing the selected widget.
                if api.events then
                    api.events:emit('providerRefreshed',{tree=tree,provider=providers[self.active],panel=panel,pc=api.pc})
                end
            end
            return result
        end
        function ui:tick(queued,released,controller)
            if self.active and not self.model.error then
                for i,row in ipairs(self.panels[self.active].rows) do
                    if row.visible then
                        for _,tab in ipairs(row.mcTabs or {}) do
                            tab.hovered=tab.widget:IsHovered()==true
                            styleBackground(tab,tab.hovered)
                        end
                        for _,tab in ipairs(row.mcTabs or {}) do
                            local clicked
                            clicked,tab.pressed,tab.pointer=released(tab.widget,tab.pressed,tab.pointer,tab.hovered)
                            if clicked and tab.enabled then
                                local value=tab.value
                                if tab.toggleValues then
                                    value=self.model.pending[i]==tab.toggleValues[1]
                                        and tab.toggleValues[2] or tab.toggleValues[1]
                                end
                                self:select(i,false);self.model:set(i,value);self:refresh()
                                if api.feedback then api.feedback('Change') end
                                return tick(self,queued,released,controller)
                            end
                        end
                    end
                end
            end
            return tick(self,queued,released,controller)
        end
        function ui:clearPresses()
            clearPresses(self)
            if self.active then
                for _,row in ipairs(self.panels[self.active].rows) do
                    for _,tab in ipairs(row.mcTabs or {}) do tab.pressed,tab.pointer=false,false end
                end
            end
        end
        function ui:isPressed()
            if isPressed(self) then return true end
            if self.active then
                for _,row in ipairs(self.panels[self.active].rows) do
                    if row.visible then
                        for _,tab in ipairs(row.mcTabs or {}) do if tab.widget:IsPressed() then return true end end
                    end
                end
            end
            return false
        end
        return ui
    end
    controls.mcPresentationVersion=M.version
    if pages then
        local buildPages=pages.build
        pages.build=function(tree,providers,status,api)
            local page=buildPages(tree,providers,status,api)
            local title=assert(page.modTitle,'KEM page title')
            local parent=assert(title:GetParent(),'KEM page header parent')
            local host=api.construct('/Script/UMG.Overlay',tree)
            local children={}
            for n=0,parent:GetChildrenCount()-1 do
                local child=parent:GetChildAt(n)
                local padding=child.Slot.Padding
                children[#children+1]={widget=child,padding={
                    Left=padding.Left,Top=padding.Top,Right=padding.Right,Bottom=padding.Bottom}}
            end
            assert(#children>=2 and children[1].widget:GetFullName()==title:GetFullName(),
                'KEM page header layout')
            parent:ClearChildren()
            for index,child in ipairs(children) do
                api.need(parent:AddChild(index==1 and host or child.widget),'KEM page header child')
                    :SetPadding(child.padding)
            end
            api.need(host:AddChild(title),'KEM page title')
            title:SetVisibility(4)
            M.style(title,1,api)
            M.style(page.filterLabel,1,api)
            page.filterLabel.Slot:SetPadding({Left=0,Top=0,Right=0,Bottom=0})
            local header=assert(page.filterButton:GetParent(),'KEM mod-browser header')
            local list=assert(header:GetParent(),'KEM mod-browser page')
            local headerName=header:GetFullName()
            local children={}
            for n=0,list:GetChildrenCount()-1 do
                local child=list:GetChildAt(n)
                local padding=child.Slot.Padding
                children[#children+1]={widget=child,padding={
                    Left=padding.Left,Top=padding.Top,Right=padding.Right,Bottom=padding.Bottom}}
            end
            list:ClearChildren()
            local inserted=false
            for _,child in ipairs(children) do
                local slot=api.need(list:AddChild(child.widget),'KEM mod-browser child')
                slot:SetPadding(child.padding)
                if child.widget:GetFullName()==headerName then
                    local line=api.construct('/Script/UMG.SizeBox',tree)
                    line:SetWidthOverride(572);line:SetHeightOverride(2)
                    api.need(line:SetContent(api.Theme.image(tree,api.theme,'horizontal',api)),'KEM mod-browser divider')
                    api.need(list:AddChild(line),'KEM mod-browser divider slot')
                    inserted=true
                end
            end
            assert(inserted,'KEM mod-browser header placement')
            local function styleBrowserRows(rows)
                for _,row in ipairs(rows or {}) do
                    if row.widget then
                        local label=api.need(row.widget:GetContent(),'MC mod-list label')
                        local provider=providers[row.providerIndex]
                        local browserLevel=provider and provider.mcBrowserLevel or 2
                        if not styles[browserLevel] then browserLevel=2 end
                        local indent=provider and provider.mcBrowserIndent or 0
                        if type(indent)~='number' or indent< -80 or indent>80 then indent=0 end
                        M.style(label,browserLevel,api)
                        label.Slot:SetPadding({Left=indent,Top=4,Right=12,Bottom=4})
                    end
                end
            end
            styleBrowserRows(page.mounted or page.allRows)
            if type(page.window)=='function' then
                local window=page.window
                function page:window(...)
                    local changed=window(self,...)
                    if changed then styleBrowserRows(self.mounted) end
                    return changed
                end
            end
            page.controls.mcHeaderHost=host
            page.controls.mcHeaderTitle=title
            return page
        end
    end
    return true
end
return M
