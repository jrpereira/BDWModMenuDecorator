package.path='Scripts/?.lua;'..package.path
local classes={}
local function class(name) classes[name]=classes[name] or {name=name,IsValid=function() return true end};return classes[name] end
local count=0
local function widget(kind,fields)
    count=count+1
    local w=fields or {}
    w.kind,w.id,w.children,w.visibility,w.enabled=kind,kind..count,w.children or {},0,true
    function w:IsValid() return true end
    function w:GetAddress() return self.id end
    function w:IsA(c) return c.name==self.kind end
    function w:GetChildAt(i) return self.children[i+1] end
    function w:GetChildrenCount() return #self.children end
    function w:GetContent() return self.content end
    function w:GetText() return self.text end
    function w:SetText(t) self.text=t end
    function w:SetVisibility(v) self.visibility=v end
    function w:SetIsEnabled(v) self.enabled=v end
    function w:SetFont() end
    function w:SetRenderTransformPivot() end
    function w:SetRenderScale() end
    function w:SetColorAndOpacity(c) self.color=c end
    function w:GetOuter() return self.outer end
    function w:AddChildToOverlay(child)
        self.children[#self.children+1]=child
        local slot={IsValid=function() return true end}
        function slot:SetHorizontalAlignment(v) child.h=v end
        function slot:SetVerticalAlignment(v) child.v=v end
        function slot:SetPadding() end
        return slot
    end
    return w
end
local tree=widget('WidgetTree')
StaticFindObject=function(path)
    if path=='/Script/Engine.Default__KismetTextLibrary' then
        return {IsValid=function() return true end,Conv_StringToText=function(_,s) return s end}
    end
    return class(path:match('^/Script/UMG%.(.+)$'))
end
StaticConstructObject=function(c) return widget(c.name) end

local RowError=require('row_error')

-- A numeric row: label | surface | value, inside the shell overlay with its identity caption.
local labelText=widget('TextBlock',{text='Quickslot 1'})
local labelBox=widget('SizeBox',{content=widget('Button',{content=labelText})})
local slider=widget('Slider')
local surfaceBox=widget('SizeBox',{content=widget('Overlay',{children={slider}})})
local valueBox=widget('SizeBox',{content=widget('TextBlock',{text='0'})})
local line=widget('HorizontalBox',{children={labelBox,surfaceBox,valueBox}})
local caption=widget('TextBlock',{text='MC_SETTING_5\n...'});caption.visibility=1
local overlay=widget('Overlay',{children={line,caption}})
local wrapper=widget('SizeBox',{content=overlay,outer=tree})
local row={kind='slider',wrapper=wrapper,overlay=overlay,line=line,labelBox=labelBox,labelWidget=labelText,
    surfaceBox=surfaceBox,valueBox=valueBox,slider=slider,nav=slider,tree=tree}

assert(RowError.mark(row,'Error: no identity'))
assert(labelBox.visibility==0,'the label stays visible')
assert(surfaceBox.visibility==2 and valueBox.visibility==2,'value controls are hidden')
assert(slider.enabled==false,'the value cannot change')
assert(caption.visibility==1,'identity captions are left alone')
assert(#overlay.children==4,'marker and message added once')
local message=overlay.children[4]
assert(message.text=='Error: no identity' and message.h==3 and message.visibility==3)

assert(RowError.mark(row,'Error: duplicate id'))
assert(#overlay.children==4,'marking again reuses the message')
assert(message.text=='Error: duplicate id','marking again updates the message')

-- A picker row hides its arrows, value and pair host but keeps its label.
local pLabel=widget('SizeBox',{content=widget('Button',{content=widget('TextBlock',{text='Mode'})})})
local left,center,right=widget('SizeBox'),widget('SizeBox'),widget('SizeBox')
local lane=widget('HorizontalBox',{children={pLabel,left,center,right}})
local pairHost=widget('SizeBox')
local content=widget('Overlay',{children={lane,pairHost}})
local nav=widget('Slider')
local shell=widget('Overlay',{children={nav,content}})
local picker={kind='picker',wrapper=widget('SizeBox',{content=shell,outer=tree}),shell=shell,nav=nav,content=content,
    lane=lane,labelBox=pLabel,labelWidget=pLabel.content.content}
assert(RowError.mark(picker,'Error: pair unavailable'))
assert(pLabel.visibility==0 and left.visibility==2 and center.visibility==2 and right.visibility==2 and pairHost.visibility==2)
assert(nav.enabled==false and shell.children[4].text=='Error: pair unavailable')
print('PASS an inconsistent row shows only its label and one error message')
