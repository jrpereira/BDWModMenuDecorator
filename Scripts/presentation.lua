-- Runs in DMM's Lua state. Uses its existing menu tick and model, never a timer.
local M={version=1}
local Manifest=require('mcs_manifest')
local dirtySignalPrefix='MC_VALUE_DIRTY_1\n'
local function trim(s) return (s or ''):match('^%s*(.-)%s*$') end
local function identityText(value)
    return tostring(value):gsub('%%','%%25'):gsub('\n','%%0A'):gsub('\r','%%0D')
end
local function settingIdentity(index,provider,setting)
    local values,labels=setting.values or {},setting.labels or {}
    assert(#values==#labels and #values<=64,'invalid setting identity choices')
    local fields={'MC_SETTING_6',tostring(index),identityText(provider.id),identityText(setting.id),
        setting.kind or '',tostring(setting.minimum or ''),tostring(setting.maximum or ''),
        tostring(setting.step or ''),tostring(setting.decimals or ''),identityText(setting.prefix or ''),
        identityText(setting.suffix or ''),tostring(#values)}
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
-- A level-2 setting label is larger than a level-2 heading: it names the page's main
-- choice, while the heading groups rows.
local settingLabelSizes={[2]=20}
local headerSeparatorDim={R=0.62,G=0.55,B=0.42,A=0.25}
local headerSeparatorBright={R=0.62,G=0.55,B=0.42,A=0.9}
local headerGlowOn={R=0.95,G=0.63,B=0.08,A=0.10}
local headerGlowOff={R=0,G=0,B=0,A=0}
-- The page status shares the header tab row, left of the tabs, while it has
-- this much width; otherwise it drops below them at full width.
local headerStatusMinWidth,headerStatusGap,headerTabHeight=160,12,28
-- A cycle button's background matches the keybind editor's Mode control.
local cycleBackground={R=0.12,G=0.12,B=0.12,A=0.09}
-- A navigation picker's choice while it separates two colliding keybinds.
local conflictRed={R=0.85,G=0.2,B=0.16,A=1}
function M.parse(content,items)
    local sections=Manifest.sections(content)
    local byId,groups,parents,seen={},{},{},{}
    for _,s in ipairs(items) do byId[s.id]=s end
    local function level(value)
        if value==nil then return nil end
        return assert(tonumber(value:match('^[0-6]$')),'mcLevel must be an integer from 0 through 6')
    end
    local function flag(value,name)
        if value==nil then return nil end
        assert(value=='0' or value=='1' or value=='true' or value=='false',
            name..' must be 0, 1, true, or false')
        return value=='1' or value=='true'
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
    -- mcChoiceNotes=<value>:<text>;... gives a picker's choices a second line.
    local function choiceNotes(r,s)
        if r.mcChoiceNotes==nil then return nil end
        assert(s.kind=='picker','mcChoiceNotes requires a picker')
        local notes={}
        for entry in (r.mcChoiceNotes..';'):gmatch('(.-);') do
            local value,note=entry:match('^%s*([^:]+):(.+)$')
            value,note=tonumber(value),trim(note)
            assert(value and note~='' and #note<=64 and notes[value]==nil,'invalid mcChoiceNotes')
            local valid=false
            for _,v in ipairs(s.values) do if v==value then valid=true end end
            assert(valid,'mcChoiceNotes value outside picker choices')
            notes[value]=note
        end
        return notes
    end
    for _,section in ipairs(sections) do
        local r=section.fields
        local group=section.name:match('^Category%.(.+)$')
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
        if section.setting then
            local id=section.id
            local s=byId[id]
            if s and not seen[id] then
                seen[id]=true
                s.mcFont=level(r.mcLevel)
                s.mcHeading=flag(r.mcHeading,'mcHeading') or false
                s.mcReadOnly=flag(r.mcReadOnly,'mcReadOnly')
                s.mcCategory=flag(r.mcCategory,'mcCategory')
                assert(not s.mcCategory or r.mcLevel==nil and not s.mcHeading,
                    'mcCategory cannot be combined with mcLevel or mcHeading')
                s.mcWrap=flag(r.mcWrap,'mcWrap')
                assert(not s.mcWrap or s.kind=='picker' and r.mcReadOnly=='1','mcWrap requires a read-only picker')
                s.mcReferenceLabel=r.mcReferenceLabel
                s.mcLabelRule=labelRule(r)
                s.mcChoiceNotes=choiceNotes(r,s)
                s.mcTabs,s.mcCycle,s.mcTabsWidth,s.mcHeader=nil,nil,nil,nil
                local hasLevel=r.mcLevel~=nil
                local decoration=r.mcType
                if decoration~=nil then assert(decoration=='tab' or decoration=='cycle','mcType must be tab or cycle') end
                if decoration=='tab' then
                    assert(s.kind=='picker','mcType=tab requires a picker')
                    assert(#s.values<=8,'mcType=tab supports at most eight choices')
                    s.mcTabs=true
                elseif decoration=='cycle' then
                    assert(s.kind=='picker','mcType=cycle requires a picker')
                    s.mcCycle=true
                end
                if r.mcTabsWidth~=nil then
                    local width=tonumber(r.mcTabsWidth)
                    assert(decoration=='tab','mcTabsWidth requires mcType=tab')
                    assert(width and width%1==0 and width>=160 and width<=440,
                        'mcTabsWidth must be an integer from 160 through 440')
                    s.mcTabsWidth=width
                end
                if hasLevel then s.mcHeader=s.mcFont==1 end
                if s.mcHeading then s.mcHeader=true end
            end
        end
    end
    local headers=0
    for _,s in ipairs(items) do
        s.mcGroup=groups[s.group]
        if s.mcHeader then headers=headers+1 end
    end
    assert(headers<=1,'only one level-one setting per provider')
    return items
end
-- Breaks a comma-separated list into lines shorter than limit characters, each
-- continued line ending in its comma. Returns the text and its line count.
function M.wrapList(text,limit)
    local lines,line={},nil
    for item in (text..','):gmatch('%s*(.-)%s*,') do
        if item~='' then
            if line and #line+2+#item<limit then line=line..', '..item
            else
                if line then lines[#lines+1]=line..',' end
                line=item
            end
        end
    end
    if line then lines[#lines+1]=line end
    return table.concat(lines,'\n'),math.max(#lines,1)
end

function M.style(label,level,api)
    local style=styles[level]
    if not style then return end
    api.Theme.font(label,api.theme,style[1])
    api.Theme.textColor(label,style[2])
    if level==5 then label:SetRenderOpacity(0.85) end
end
-- options.keyColumn (optional): the keybind editor's layout; cycle buttons align
-- with its key column, and otherwise sit at the right like tabs.
function M.install(choices,controls,pages,options)
    if controls.mcPresentationVersion then return false end
    local keyColumn=options and options.keyColumn
    local parse,build=choices.parse,controls.build
    choices.parse=function(content) return M.parse(content,parse(content)) end
    controls.build=function(tree,providers,api)
        local adapted={}
        -- Cached pages may be evicted; do not retain their Lua widget wrappers.
        local labels=setmetatable({},{__mode='k'})
        local rowButtonInset=setmetatable({},{__mode='k'})
        local helpWidgets=setmetatable({},{__mode='k'})
        local valueSignals=setmetatable({},{__mode='k'})
        local ui
        -- While DMM builds a page: the provider, the last row whose label button was
        -- seen, and how many of that row's value buttons follow before the next label.
        local constructing,pendingHelp,buttonSettingIndex,buttonsToSkip
        for k,v in pairs(api) do adapted[k]=v end
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
                local slot=api.need(pendingHelp.heading:GetParent():AddChild(help),'MCS group help')
                slot:SetPadding({Left=20,Top=0,Right=20,Bottom=8})
                helpWidgets[pendingHelp.heading]=help;pendingHelp=nil
            end
            local button,label=api.button(...)
            -- DMM builds each row's label button first; a picker then adds its left,
            -- value and right buttons. The label text only confirms the position: a
            -- page whose buttons fall out of step gets no further row styling.
            if constructing and buttonsToSkip>0 then buttonsToSkip=buttonsToSkip-1
            elseif constructing then
                local nextSetting=providers[constructing].choices[buttonSettingIndex+1]
                if not nextSetting or select(2,...)~=nextSetting.label then buttonsToSkip=math.huge
                else
                    buttonSettingIndex=buttonSettingIndex+1
                    buttonsToSkip=nextSetting.kind=='picker' and 3 or 0
                    if nextSetting.mcFont==nil and not nextSetting.mcHeader then
                        local style=button.WidgetStyle
                        local normal,pressed=style.NormalPadding,style.PressedPadding
                        rowButtonInset[button]=normal.Left
                        style.NormalPadding={Left=0,Top=normal.Top,
                            Right=normal.Right,Bottom=normal.Bottom}
                        style.PressedPadding={Left=0,Top=pressed.Top,
                            Right=pressed.Right,Bottom=pressed.Bottom}
                    end
                end
            end
            labels[button]=label
            return button,label
        end
        ui=build(tree,providers,adapted)
        local prepare,show,refresh,tick,clearPresses,isPressed=ui.prepare,ui.show,ui.refresh,ui.tick,ui.clearPresses,ui.isPressed
        local function new(kind) return api.construct('/Script/UMG.'..kind,tree) end
        local function add(parent,child) return api.need(parent:AddChild(child),'MCS presentation child') end
        local function sized(child,width,height)
            local box=new('SizeBox');box:SetWidthOverride(width);box:SetHeightOverride(height or 40)
            local slot=api.need(box:SetContent(child),'MCS presentation size')
            slot:SetHorizontalAlignment(0);slot:SetVerticalAlignment(0)
            return box
        end
        local pickerRightMargin=24
        -- Label column of a wrapped read-only row; the value takes the rest.
        local wrapLabelWidth=230
        -- Field-type editors are built on DMM's toggle row, whose label sits in the
        -- row content; its indent belongs on that content's slot, not the label's.
        local function toggleShell(setting) return setting.kind=='toggle' or setting.kind=='extension' end
        -- The dirty star follows the label text: label and star share a box in the
        -- label's place, so the star moves with the text and never overlaps it.
        -- ModCoreSettings' dirty labels show and hide it. The box clips, so a label
        -- longer than its column is cut there instead of reaching the controls.
        local function starAfter(label)
            local padding=label.Slot.Padding
            local line=new('HorizontalBox');line:SetClipping(1)
            local lineSlot=api.need(label:GetParent():SetContent(line),'MCS label line')
            lineSlot:SetHorizontalAlignment(0);lineSlot:SetVerticalAlignment(2)
            lineSlot:SetPadding({Left=0,Top=0,Right=0,Bottom=0})
            local labelSlot=add(line,label)
            labelSlot:SetSize({SizeRule=0,Value=1});labelSlot:SetVerticalAlignment(2)
            labelSlot:SetPadding({Left=padding.Left,Top=padding.Top,Right=0,Bottom=padding.Bottom})
            local star=api.caption(tree,'*')
            star:SetVisibility(2)
            local starSlot=add(line,star)
            starSlot:SetSize({SizeRule=0,Value=1});starSlot:SetVerticalAlignment(2)
            starSlot:SetPadding({Left=4,Top=0,Right=padding.Right,Bottom=0})
            return star
        end
        -- A navigation picker that separates two colliding keybinds shows its choice,
        -- text and arrows, in red. DMM gives that text the body color and leaves arrow
        -- art untinted, so clearing restores exactly those.
        local function conflictStyle(row,red)
            local function text(widget)
                if red then widget:SetColorAndOpacity({SpecifiedColor=conflictRed,ColorUseRule=0})
                else api.Theme.textColor(widget,'body') end
            end
            if row.value then text(row.value) end
            for _,part in ipairs({row.parts[1],row.parts[3]}) do
                local content=part and part.widget:GetContent()
                if content then
                    -- Arrow art sits in a size box; without art the arrow is a text label.
                    local ok,art=pcall(function() return content:GetContent() end)
                    if ok and art then art:SetColorAndOpacity(red and conflictRed or {R=1,G=1,B=1,A=1})
                    else text(content) end
                end
            end
        end
        -- The star matches its label's font and color whenever the label is restyled.
        local function starStyle(row)
            if not row.mcStar then return end
            row.mcStar:SetFont(row.mcLabel.Font)
            pcall(function() row.mcStar:SetColorAndOpacity(row.mcLabel.ColorAndOpacity) end)
        end
        -- A 1-pixel frame of four bars around a tab choice. The fill stays clear so
        -- the row's own background shows through.
        local function outlined(child)
            local overlay=new('Overlay')
            local slot=add(overlay,child);slot:SetHorizontalAlignment(0);slot:SetVerticalAlignment(0)
            local bars={}
            for _,edge in ipairs({{h=0,v=1},{h=0,v=3},{h=1,v=0},{h=3,v=0}}) do
                local bar=new('Border');bar:SetBrushColor(headerSeparatorDim)
                local box=new('SizeBox')
                if edge.h==0 then box:SetHeightOverride(1) else box:SetWidthOverride(1) end
                api.need(box:SetContent(bar),'MCS tab outline')
                local barSlot=add(overlay,box);barSlot:SetHorizontalAlignment(edge.h);barSlot:SetVerticalAlignment(edge.v)
                bars[#bars+1]=bar
            end
            return overlay,bars
        end
        local function decorate(index)
            local panel=ui.panels[index]
            if panel.mcPresented then return end
            for i,row in ipairs(panel.rows) do
                local setting=providers[index].choices[i]
                row.mcLabel=labels[row.widget]
                -- Navigation and read-only rows are never dirty.
                if row.mcLabel and not setting.mcNavigation and not setting.mcReadOnly then
                    row.mcStar=starAfter(row.mcLabel)
                end
                local identity=api.caption(tree,settingIdentity(i,providers[index],setting))
                identity:SetVisibility(1)
                add(row.wrapper:GetContent(),identity)
                if row.value then
                    local marker=api.caption(tree,dirtySignalPrefix..'0\n')
                    marker:SetVisibility(1)
                    add(row.wrapper:GetContent(),marker)
                    valueSignals[row.value]={marker=marker,index=i}
                end
                local level=setting.mcHeading and 1 or setting.mcFont
                M.style(row.mcLabel,level,api)
                if settingLabelSizes[level] then api.Theme.font(row.mcLabel,api.theme,settingLabelSizes[level]) end
                -- Theme.font only writes the property; a built label shows it after SetFont.
                if level then row.mcLabel:SetFont(row.mcLabel.Font) end
                starStyle(row)
                if level==1 or level==2 then
                    local slot=toggleShell(setting) and row.widget:GetContent().Slot or row.mcLabel.Slot
                    local padding=slot.Padding
                    slot:SetPadding({Left=0,Top=padding.Top,Right=padding.Right,Bottom=padding.Bottom})
                end
                if setting.mcHeader and ui.mcHeaderHost and providers[index].id~="ModCoreTemplates" then
                    assert(not panel.mcHeader,'only one level-one setting per provider')
                    local placeholder=new('SizeBox')
                    local path=assert(row.wrapper:GetFullName():match('^%S+ (.+)$'))
                    local marker=api.caption(tree,'MC_HEADER_ROW\n'..path)
                    api.need(placeholder:SetContent(marker),'MCS header identity')
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
                        assert(ui.mcHeaderHost:RemoveChild(title),'MCS page title relocation')
                        local titleSlot=add(ui.mcHeaderHost,title)
                        titleSlot:SetHorizontalAlignment(1);titleSlot:SetVerticalAlignment(2)
                    end
                    row.mcHeader=true;row.mcPlaceholder=placeholder;panel.mcHeader=row
                    row.mcHeaderTabs=setting.kind=='picker' and ui.mcHeaderTabs~=nil
                end
                if row.mcHeaderTabs then
                    -- A header picker shows every choice as a tab hanging from the
                    -- divider, right-aligned, separated by thin vertical bars. Only
                    -- the bars beside the selected tab are drawn at full strength.
                    local tabs=new('HorizontalBox')
                    row.mcTabs={};row.mcHeaderSeparators={}
                    local count=#setting.values
                    local width=math.floor(math.min(110,(572-(count+1))/count))
                    local function separator()
                        local bar=new('Border');bar:SetBrushColor(headerSeparatorDim)
                        add(tabs,sized(bar,1,headerTabHeight))
                        row.mcHeaderSeparators[#row.mcHeaderSeparators+1]=bar
                    end
                    separator()
                    for n,value in ipairs(setting.values) do
                        local button,label=api.button(tree,setting.labels[n]);button.IsFocusable=false
                        local style=button.WidgetStyle
                        style.NormalPadding={Left=4,Top=0,Right=4,Bottom=0}
                        style.PressedPadding={Left=4,Top=0,Right=4,Bottom=0}
                        api.Theme.font(label,api.theme,12)
                        label:SetJustification(1);label:SetTextOverflowPolicy(1)
                        label.Slot:SetHorizontalAlignment(0);label.Slot:SetVerticalAlignment(2)
                        local glow=new('Border');glow:SetBrushColor(headerGlowOff)
                        api.need(glow:SetContent(button),'MCS header tab glow')
                        add(tabs,sized(glow,width,headerTabHeight))
                        row.mcTabs[#row.mcTabs+1]={widget=button,label=label,value=value,
                            pressed=false,pointer=false,glow=glow}
                        separator()
                    end
                    local slot=add(ui.mcHeaderTabs,tabs)
                    slot:SetHorizontalAlignment(3);slot:SetVerticalAlignment(1)
                    row.mcHeaderTabsBox=tabs
                    row.mcHeaderTabsWidth=count*width+count+1
                    if row.value then row.value:SetVisibility(1) end
                    for _,part in ipairs(row.parts) do part.widget:GetParent():SetVisibility(1) end
                elseif setting.mcTabs then
                    -- Keep DMM's original controls alive for navigation, dirty
                    -- notifications and reconstruction. No stock reparenting.
                    local tabs=new('HorizontalBox')
                    row.mcTabs={}
                    local count=#setting.values
                    local providerLink=setting.mcNavigation and setting.mcLinkPage
                    local totalWidth=providerLink and 160 or
                        (setting.mcReferenceLabel and 150 or (setting.mcTabsWidth or math.min(384,110*count)))
                    local choices={}
                    for n,value in ipairs(setting.values) do
                        if not providerLink or n==1 then choices[#choices+1]={value=value,label=setting.labels[n]} end
                    end
                    -- Outlined choices sit 4 pixels apart within the reserved width.
                    local width=(totalWidth-4*(#choices-1))/#choices
                    for n,choice in ipairs(choices) do
                        local button,label=api.button(tree,choice.label);button.IsFocusable=false
                        label:SetJustification(1);label:SetTextOverflowPolicy(1)
                        -- Stretch the text block across the fixed-width button, then
                        -- let centered text justification position its contents.
                        label.Slot:SetHorizontalAlignment(0);label.Slot:SetVerticalAlignment(2)
                        local frame,outline=outlined(button)
                        local box=sized(frame,width,32)
                        local boxSlot=add(tabs,box)
                        boxSlot:SetVerticalAlignment(2)
                        if n>1 then boxSlot:SetPadding({Left=4,Top=0,Right=0,Bottom=0}) end
                        row.mcTabs[#row.mcTabs+1]={widget=button,label=label,value=choice.value,pressed=false,pointer=false,
                            box=box,outline=outline}
                    end
                    local overlay=row.background:GetParent()
                    local slot=add(overlay,tabs);slot:SetHorizontalAlignment(3);slot:SetVerticalAlignment(2)
                    slot:SetPadding({Left=0,Top=0,Right=pickerRightMargin,Bottom=0})
                    if setting.mcReadOnly and setting.mcReferenceLabel then
                        local reference,text=api.button(tree,setting.mcReferenceLabel)
                        reference.IsFocusable=false;reference:SetIsEnabled(false)
                        text:SetJustification(1)
                        local box=sized(reference,96,32)
                        box:SetRenderTranslation({X=-(totalWidth+8),Y=0})
                        local referenceSlot=add(overlay,box)
                        referenceSlot:SetHorizontalAlignment(3);referenceSlot:SetVerticalAlignment(2)
                        referenceSlot:SetPadding({Left=0,Top=0,Right=pickerRightMargin,Bottom=0})
                    end
                    row.widget:GetParent():SetWidthOverride(584-totalWidth-pickerRightMargin)
                    if providerLink then
                        -- A link row's label wraps within its column and the row grows to
                        -- fit; one line keeps DMM's 40-pixel row. The button stays centred.
                        row.mcLabel:SetAutoWrapText(true)
                        for _,box in ipairs({row.widget:GetParent(),row.wrapper}) do
                            box:ClearHeightOverride();box:SetMinDesiredHeight(40)
                        end
                    end
                    for _,part in ipairs(row.parts) do part.widget:GetParent():SetVisibility(1) end
                elseif setting.mcCycle then
                    -- One button showing only the current choice; a click moves to the
                    -- next, like the keybind editor's Mode. It sits in the key column,
                    -- under the keys, at the key box's width.
                    local width=keyColumn and keyColumn.key or 96
                    local button,label=api.button(tree,'');button.IsFocusable=false
                    api.Theme.font(label,api.theme,13)
                    label:SetJustification(1);label:SetTextOverflowPolicy(1)
                    label.Slot:SetHorizontalAlignment(0);label.Slot:SetVerticalAlignment(2)
                    local frame=new('Border');frame:SetBrushColor(cycleBackground)
                    api.need(frame:SetContent(button),'MCS cycle frame')
                    local box=sized(frame,width,32)
                    local overlay=row.background:GetParent()
                    local slot=add(overlay,box);slot:SetVerticalAlignment(2)
                    if keyColumn then
                        slot:SetHorizontalAlignment(1)
                        row.mcCyclePlace=function(indent)
                            slot:SetPadding({Left=indent+keyColumn.keyOffset,Top=0,Right=0,Bottom=0})
                        end
                        row.mcCyclePlace(20+(rowButtonInset[row.widget] or 0))
                        row.widget:GetParent():SetWidthOverride(keyColumn.keyOffset)
                    else
                        slot:SetHorizontalAlignment(3)
                        slot:SetPadding({Left=0,Top=0,Right=pickerRightMargin,Bottom=0})
                        row.widget:GetParent():SetWidthOverride(584-width-pickerRightMargin)
                    end
                    row.mcTabs={{widget=button,label=label,value=setting.values[1],pressed=false,pointer=false,
                        cycle=true,box=box}}
                    for _,part in ipairs(row.parts) do part.widget:GetParent():SetVisibility(1) end
                elseif setting.mcWrap then
                    -- A read-only value too long for DMM's picker: 13pt text in a wider
                    -- column, broken at commas below 34 characters; the row grows to fit.
                    local text,lines=M.wrapList(setting.labels[1] or '',34)
                    local value=api.caption(tree,text)
                    api.Theme.font(value,api.theme,13)
                    value:SetJustification(0);value:SetAutoWrapText(true)
                    local box=new('SizeBox');box:SetWidthOverride(584-wrapLabelWidth-pickerRightMargin)
                    api.need(box:SetContent(value),'MCS wrapped value')
                    local overlay=row.background:GetParent()
                    local slot=add(overlay,box);slot:SetHorizontalAlignment(3);slot:SetVerticalAlignment(2)
                    slot:SetPadding({Left=0,Top=0,Right=pickerRightMargin,Bottom=0})
                    row.widget:GetParent():SetWidthOverride(wrapLabelWidth)
                    row.wrapper:SetHeightOverride(math.max(40,lines*18+12))
                    for _,part in ipairs(row.parts) do part.widget:GetParent():SetVisibility(1) end
                    row.mcWrapped=value
                elseif setting.mcChoiceNotes and row.value and not row.mcHeaderTabs then
                    -- A choice's note sits under DMM's value, small and muted like the
                    -- keybind editor's "default", inside the 40-pixel row. It overlays
                    -- the row so DMM's value button keeps its structure, aligned with
                    -- that button: left of the 32-pixel right arrow, at its 190-pixel width.
                    local note=api.caption(tree,'')
                    api.Theme.font(note,api.theme,10);note:SetFont(note.Font)
                    api.Theme.textColor(note,'muted')
                    note:SetJustification(1);note:SetTextOverflowPolicy(1)
                    local box=sized(note,190,14)
                    local slot=add(row.background:GetParent(),box)
                    slot:SetHorizontalAlignment(3);slot:SetVerticalAlignment(3)
                    slot:SetPadding({Left=0,Top=0,Right=32,Bottom=3})
                    -- Never in the way of the value button underneath.
                    box:SetVisibility(1)
                    row.mcNote,row.mcNoteBox=note,box
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
        -- Construction state never outlives DMM's build, even when the build fails.
        function ui:prepare(index,...)
            constructing,buttonSettingIndex,buttonsToSkip,pendingHelp=index,0,0,nil
            local results=table.pack(pcall(prepare,self,index,...))
            constructing,pendingHelp=nil,nil
            if not results[1] then error(results[2],0) end
            decorate(index)
            return table.unpack(results,2,results.n)
        end
        function ui:show(index,...) self:prepare(index);return show(self,index,...) end
        local function dynamic(rule,model,fallback)
            if not rule then return fallback end
            for i,s in ipairs(model.items) do
                if s.id==rule.source.id then return rule.values[model.pending[i]] or fallback end
            end
            return fallback
        end
        function ui:refresh(...)
            if self.active then decorate(self.active) end
            -- DMM refreshes controls while a native press may still be held. Keep
            -- the press origin until the release handler observes the release.
            local pressed={}
            if self.active then
                for i,row in ipairs(self.panels[self.active].rows) do
                    local state={row.pressed,row.pointer,parts={}}
                    for n,part in ipairs(row.parts or {}) do
                        state.parts[n]={part.pressed,part.pointer}
                    end
                    pressed[i]=state
                end
            end
            local result=refresh(self,...)
            for i,state in ipairs(pressed) do
                local row=self.panels[self.active].rows[i]
                if row.visible then
                    row.pressed,row.pointer=state[1],state[2]
                    for n,part in ipairs(row.parts or {}) do
                        local old=state.parts[n]
                        if old then part.pressed,part.pointer=old[1],old[2] end
                    end
                end
            end
            local pageReady=false
            for i,row in ipairs(self.panels[self.active].rows) do
                local setting=self.model.items[i]
                if row.mcHeader then row.wrapper:SetVisibility(row.visible and 0 or 1) end
                if row.mcHeaderTabsBox then row.mcHeaderTabsBox:SetVisibility(row.visible and 0 or 1) end
                if setting.mcLabelRule then
                    local text=dynamic(setting.mcLabelRule,self.model,setting.label)
                    if text~=row.mcLabelText then api.setText(row.mcLabel,text);row.mcLabelText=text end
                end
                if row.mcNote then
                    -- The value moves up to make room while its choice has a note.
                    local note=setting.mcChoiceNotes[self.model.pending[i]]
                    if note~=row.mcNoteText then
                        if note then api.setText(row.mcNote,note) end
                        row.mcNoteBox:SetVisibility(note and 3 or 1)
                        local padding=row.value.Slot.Padding
                        row.value.Slot:SetPadding({Left=padding.Left,Top=padding.Top,
                            Right=padding.Right,Bottom=note and 12 or 0})
                        row.mcNoteText=note
                    end
                end
                for _,tab in ipairs(row.mcTabs or {}) do
                    if tab.cycle then
                        local current,shown=self.model.pending[i],1
                        for n,value in ipairs(setting.values) do if value==current then shown=n end end
                        if tab.shown~=shown then api.setText(tab.label,setting.labels[shown]);tab.shown=shown end
                        tab.value=setting.values[shown%#setting.values+1]
                    end
                    local mapping=self.model.items[i].mcMapping
                    local enabled=not setting.mcReadOnly and not self.model.error and (not mapping or tab.value~=mapping.custom)
                    local current=self.model.pending[i]
                    local selected=current==tab.value
                    if tab.selected~=selected or tab.enabled~=enabled then
                        api.Theme.textColor(tab.label,selected and 'menuActive' or 'body')
                        tab.widget:SetIsEnabled(enabled)
                        tab.widget:SetRenderOpacity((enabled or selected) and 1 or 0.45)
                        for _,bar in ipairs(tab.outline or {}) do
                            bar:SetBrushColor(selected and headerSeparatorBright or headerSeparatorDim)
                        end
                        tab.selected,tab.enabled=selected,enabled
                    end
                    if not row.visible or not enabled then tab.pressed,tab.pointer=false,false end
                end
                if row.mcHeaderSeparators then
                    local selected
                    for n,tab in ipairs(row.mcTabs) do if tab.selected then selected=n;break end end
                    if row.mcHeaderSelected~=selected then
                        for n,bar in ipairs(row.mcHeaderSeparators) do
                            local bright=selected and (n==selected or n==selected+1)
                            bar:SetBrushColor(bright and headerSeparatorBright or headerSeparatorDim)
                        end
                        for n,tab in ipairs(row.mcTabs) do
                            tab.glow:SetBrushColor(n==selected and headerGlowOn or headerGlowOff)
                        end
                        row.mcHeaderSelected=selected
                    end
                end
            end
            for index,panel in ipairs(self.panels) do
                if index~=self.active and panel.mcHeader then
                    panel.mcHeader.wrapper:SetVisibility(1)
                    if panel.mcHeader.mcHeaderTabsBox then panel.mcHeader.mcHeaderTabsBox:SetVisibility(1) end
                end
            end
            local status=self.mcHeaderStatus
            if status then
                local header=self.panels[self.active].mcHeader
                local used=header and header.visible and header.mcHeaderTabsWidth or 0
                local free=572-used-headerStatusGap
                local beside=used==0 or free>=headerStatusMinWidth
                local width=(used==0 or not beside) and 572 or free
                local top=beside and 0 or headerTabHeight
                if status.width~=width or status.top~=top then
                    status.box:SetWidthOverride(width)
                    local p=status.padding
                    status.slot:SetPadding({Left=p.Left,Top=p.Top+top,Right=p.Right,Bottom=p.Bottom})
                    status.width,status.top=width,top
                end
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
            end
            local categoryAdded=false
            local function alignRows(heading)
                if heading.visible then categoryAdded=true end
                for i=heading.first,heading.last do
                    local row,setting=panel.rows[i],self.model.items[i]
                    if row.mcLabel and setting.mcFont==nil and not setting.mcHeader then
                        -- An mcCategory row stands in for its group's heading: it takes
                        -- the heading's look, and the rows after it indent beneath it.
                        local beforeCategory=setting.mcCategory or not categoryAdded
                        if setting.mcCategory and row.visible then categoryAdded=true end
                        if row.mcCategoryStyle~=beforeCategory then
                            api.Theme.font(row.mcLabel,api.theme,beforeCategory and 16 or 14)
                            row.mcLabel:SetFont(row.mcLabel.Font)
                            api.Theme.textColor(row.mcLabel,beforeCategory and 'muted' or 'body')
                            starStyle(row)
                            row.mcCategoryStyle=beforeCategory
                        end
                        local labelSlot=toggleShell(setting) and row.widget:GetContent().Slot
                            or row.mcLabel.Slot
                        local labelPadding=labelSlot.Padding
                        local indent=beforeCategory and 0 or 20+(rowButtonInset[row.widget] or 0)
                        if row.mcCyclePlace then row.mcCyclePlace(indent) end
                        if labelPadding.Left~=indent then
                            labelSlot:SetPadding({Left=indent,Top=labelPadding.Top,
                                Right=labelPadding.Right,Bottom=labelPadding.Bottom})
                        end
                        local wrapperSlot=row.wrapper.Slot
                        local wrapperPadding=wrapperSlot.Padding
                        local top,bottom=beforeCategory and 12 or 0,beforeCategory and 4 or 0
                        if wrapperPadding.Top~=top or wrapperPadding.Bottom~=bottom then
                            wrapperSlot:SetPadding({Left=wrapperPadding.Left,Top=top,
                                Right=wrapperPadding.Right,Bottom=bottom})
                        end
                    end
                end
            end
            if panel.mcLayout then
                for _,entry in ipairs(panel.mcLayout) do
                    if entry.parentWidget and entry.parentVisible then categoryAdded=true end
                    for _,block in ipairs(entry.orderedBlocks) do
                        if block.heading then alignRows(block.heading) end
                    end
                end
            else
                for _,heading in ipairs(panel.headings) do alignRows(heading) end
            end
            if panel.mcBlocks then
                if self.visibleRows then
                    local visible={}
                    -- Header controls precede scroll content for navigation.
                    for i,row in ipairs(panel.rows) do if row.mcHeader and row.visible then visible[#visible+1]=i end end
                    for _,block in ipairs(panel.mcOrderedBlocks or panel.mcBlocks) do
                        if block.heading then
                            for i=block.heading.first,block.heading.last do
                                if panel.rows[i].visible and not panel.rows[i].mcHeader then visible[#visible+1]=i end
                            end
                        end
                    end
                    self.visibleRows=visible;self:wireNavigation(self.footer)
                end
            end
            if self.visibleRows and not panel.mcBlocks then
                local navigation={}
                for i,row in ipairs(panel.rows) do
                    if row.visible then navigation[#navigation+1]=i end
                end
                self.visibleRows=navigation;self:wireNavigation(self.footer)
            end
            -- Field types mark the pickers separating colliding keybinds on each refresh.
            local separating=not self.model.error and self.model.mcConflictPickers or {}
            for i,row in ipairs(panel.rows) do
                local red=separating[i]==true
                if row.parts and #row.parts==3 and not row.mcTabs and (row.mcConflictRed or false)~=red then
                    conflictStyle(row,red)
                    row.mcConflictRed=red
                end
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
                        -- The transparent navigation slider sits behind picker
                        -- buttons. A mouse drag can move it without a new picker
                        -- choice; only controller navigation may drive that slider.
                        if not controller and not row.slider and row.lastNavigation~=nil then
                            if row.nav:GetValue()~=row.lastNavigation then
                                row.nav:SetValue(row.lastNavigation)
                            end
                        end
                        -- Native sliders expose raw floats, while the model stores
                        -- snapped values. Do not replay Change for a different raw
                        -- float that resolves to the already selected value.
                        if row.slider and row.lastValue~=nil then
                            local value=row.slider:GetValue()
                            local setting=self.model.items[i]
                            if value~=row.lastValue and setting.step and
                                choices.snap(setting,setting.minimum+value*(setting.maximum-setting.minimum))
                                    ==self.model.pending[i] then
                                row.lastValue=value
                            end
                        end
                        for _,tab in ipairs(row.mcTabs or {}) do tab.hovered=tab.widget:IsHovered()==true end
                        for _,tab in ipairs(row.mcTabs or {}) do
                            local clicked
                            clicked,tab.pressed,tab.pointer=released(tab.widget,tab.pressed,tab.pointer,tab.hovered)
                            if clicked and tab.enabled then
                                self:select(i,false);self.model:set(i,tab.value);self:refresh()
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
            -- Unapplied changes show as a * after the page title instead of DMM's status
            -- text. The status line keeps every other message: errors, failed Applies, hints.
            local page,titleText
            local adapted={}
            for key,value in pairs(api) do adapted[key]=value end
            local function unapplied()
                local model=page and page.controls and page.controls.model
                return model and not model.error and type(model.dirty)=='function' and model:dirty() or false
            end
            local function showTitle()
                if titleText then api.setText(page.modTitle,unapplied() and titleText..' *' or titleText) end
            end
            adapted.setText=function(widget,text)
                if page and widget==page.modTitle then titleText=text;return showTitle() end
                if page and widget==page.controlStatus then
                    local T=api.t or function(copy) return copy end
                    if text==T('Unapplied changes') then text='' end
                    local result=api.setText(widget,text)
                    showTitle()
                    return result
                end
                return api.setText(widget,text)
            end
            page=buildPages(tree,providers,status,adapted)
            local title=assert(page.modTitle,'MCS page title')
            local parent=assert(title:GetParent(),'MCS page header parent')
            local host=api.construct('/Script/UMG.Overlay',tree)
            local children={}
            for n=0,parent:GetChildrenCount()-1 do
                local child=parent:GetChildAt(n)
                local padding=child.Slot.Padding
                children[#children+1]={widget=child,padding={
                    Left=padding.Left,Top=padding.Top,Right=padding.Right,Bottom=padding.Bottom}}
            end
            assert(#children>=2 and children[1].widget:GetFullName()==title:GetFullName(),
                'MCS page header layout')
            local pageStatus=assert(page.controlStatus,'MCS page status')
            local statusName,statusPadding=pageStatus:GetFullName()
            parent:ClearChildren()
            -- A header picker's choices hang as tabs from the divider under the
            -- title. The page status shares that row, so it stays beneath the
            -- divider whether or not tabs are shown.
            local strip=api.construct('/Script/UMG.Overlay',tree)
            local stripBox=api.construct('/Script/UMG.SizeBox',tree)
            stripBox:SetWidthOverride(572)
            api.need(stripBox:SetContent(strip),'MCS header tabs strip')
            for index,child in ipairs(children) do
                if child.widget:GetFullName()==statusName then
                    statusPadding=child.padding
                else
                    api.need(parent:AddChild(index==1 and host or child.widget),'MCS page header child')
                        :SetPadding(child.padding)
                end
                if index==2 then
                    api.need(parent:AddChild(stripBox),'MCS header tabs slot')
                        :SetPadding({Left=0,Top=0,Right=0,Bottom=0})
                end
            end
            assert(statusPadding,'MCS page status placement')
            local statusBox=api.construct('/Script/UMG.SizeBox',tree)
            statusBox:SetWidthOverride(572)
            api.need(statusBox:SetContent(pageStatus),'MCS page status box')
            local statusSlot=api.need(strip:AddChild(statusBox),'MCS page status slot')
            statusSlot:SetHorizontalAlignment(1);statusSlot:SetVerticalAlignment(1)
            statusSlot:SetPadding(statusPadding)
            api.need(host:AddChild(title),'MCS page title')
            title:SetVisibility(4)
            M.style(title,1,api)
            M.style(page.filterLabel,1,api)
            page.filterLabel.Slot:SetPadding({Left=0,Top=0,Right=0,Bottom=0})
            local header=assert(page.filterButton:GetParent(),'MCS mod-browser header')
            local list=assert(header:GetParent(),'MCS mod-browser page')
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
                local slot=api.need(list:AddChild(child.widget),'MCS mod-browser child')
                slot:SetPadding(child.padding)
                if child.widget:GetFullName()==headerName then
                    local line=api.construct('/Script/UMG.SizeBox',tree)
                    line:SetWidthOverride(572);line:SetHeightOverride(2)
                    api.need(line:SetContent(api.Theme.image(tree,api.theme,'horizontal',api)),'MCS mod-browser divider')
                    api.need(list:AddChild(line),'MCS mod-browser divider slot')
                    inserted=true
                end
            end
            assert(inserted,'MCS mod-browser header placement')
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
                        if row.wrapper then
                            row.wrapper:SetWidthOverride(584-2*indent)
                            local slot=row.wrapper.Slot
                            local padding=slot.Padding
                            slot:SetPadding({Left=indent,Top=padding.Top,
                                Right=padding.Right,Bottom=padding.Bottom})
                        end
                        label.Slot:SetPadding({Left=row.wrapper and 0 or indent,
                            Top=4,Right=12,Bottom=4})
                        if provider and provider.mcBrowserHeading then api.setText(label,provider.name) end
                    end
                end
            end
            styleBrowserRows(page.allRows)
            page.controls.mcHeaderHost=host
            page.controls.mcHeaderTitle=title
            page.controls.mcHeaderTabs=strip
            page.controls.mcHeaderStatus={box=statusBox,slot=statusSlot,padding=statusPadding,width=572,top=0}
            return page
        end
    end
    return true
end
return M
