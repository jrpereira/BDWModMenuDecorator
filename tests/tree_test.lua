package.path='Scripts/?.lua;'..package.path
local function widget(name,class,children)
 local o={}
 function o:IsValid() return true end
 function o:GetFName() return {ToString=function() return name end} end
 function o:GetAddress() return name end
 function o:GetClass() error('unsafe GetClass path') end
 function o:IsA(targetClass) assert(type(targetClass)=='table','string IsA lookup forbidden');local path=targetClass.path;return path=='/Script/UMG.'..class or (children and path=='/Script/UMG.PanelWidget') or false end
 function o:GetChildrenCount() assert(children);return #children end
 function o:GetChildAt(i) assert(children);return children[i+1] end
 function o:GetParent() return self.parent end
 for _,child in ipairs(children or {}) do child.parent=o end
 return o
end
local leaf=widget('Text_1','TextBlock')
local scroll=widget('Scroll_1','ScrollBox',{leaf})
local root=widget('Overlay_1','Overlay',{scroll})
local host=widget('CommonActivatableWidget_1','CommonActivatableWidget')
host.WidgetTree={IsValid=function() return true end,RootWidget=root}
local active=true
function host:IsInViewport() return true end
function host:IsActivated() return active end
function host:IsVisible() return self.visible~=false end
function host:GetIsEnabled() return self.enabled~=false end
FindAllOf=function() error('global enumeration forbidden') end
local finds=0
StaticFindObject=function(path) finds=finds+1;return {path=path,IsValid=function() return true end} end
local M=require('widget_discovery')
local snapshots=M.activeTrees(host,function() return true end)
assert(#snapshots==1 and #snapshots[1].scrolls==1 and snapshots[1].widgets.Text_1==leaf)
assert(M.className(leaf)=='TextBlock')
local targeted=assert(M.routesFor(host,{scroll,leaf},function() return true end))
assert(M.routeResolver(host,function() return true end)(targeted.Text_1)==leaf)
assert(targeted.Text_1.parent==targeted.Scroll_1 and targeted.Scroll_1.parent==targeted.Overlay_1)
print('PASS targeted routes follow exact control ancestry without a full-tree snapshot')
active=false;assert(#M.activeTrees(host,function() return true end)==0)
print('PASS fresh activated host tree traversal and class checks without GetClass')

assert(#M.activeTrees(nil,function() return false end)==0)
print("PASS revoked scope does not access host or enumerate objects")

active=true
local snapshot=M.activeTrees(host,function() return true end)[1]
local before=finds
for i=1,100 do
 local resolve=assert(M.routeResolver(host,function() return true end))
 assert(resolve(snapshot.routes.Text_1)==leaf)
 assert(resolve(snapshot.routes.Scroll_1)==scroll)
end
assert(finds==before,'route refresh performed global object lookup')
M.activeTrees(host,function() return true end)
assert(finds==before,'cached IsA class lookups repeated')
print('PASS 100 fresh route updates and repeat tree walk add zero global lookups')
local replacement=widget('Text_1','TextBlock')
function scroll:GetChildAt(i) assert(i==0);return replacement end
leaf.IsValid=function() error('stale widget accessed') end
assert(M.routeResolver(host,function() return true end)(snapshot.routes.Text_1)==replacement)
local foreign=widget('Other_2','TextBlock')
function scroll:GetChildAt() return foreign end
assert(not M.routeResolver(host,function() return true end)(snapshot.routes.Text_1))
assert(not M.routeResolver(nil,function() return false end))
print('PASS route refresh uses fresh wrappers, rejects replaced identities, respects revoked scope')


host.visible=false;assert(#M.activeTrees(host,function() return true end)==0)
host.visible=true;host.enabled=false;assert(#M.activeTrees(host,function() return true end)==0)
print('PASS structural traversal rejects hidden or disabled hosts even if activated')

host.enabled=true
local backing=widget('CollapsedMode','Slider')
local shown=widget('VisibleProvider','ScrollBox',{backing})
local hidden=widget('HiddenProvider','ScrollBox',{})
function hidden:GetAddress() error('inactive provider traversed') end
local picker=widget('Providers','WidgetSwitcher',{hidden,shown})
function picker:GetActiveWidgetIndex() return 1 end
local browser=widget('Browser','ScrollBox',{})
local outer=widget('Pages','WidgetSwitcher',{browser,picker})
local selected=1
function outer:GetActiveWidgetIndex() return selected end
host.WidgetTree.RootWidget=outer
local activeSnapshot=assert(M.activeTrees(host,function() return true end)[1])
assert(#activeSnapshot.scrolls==1 and activeSnapshot.scrolls[1]==shown)
assert(activeSnapshot.widgets.CollapsedMode==backing,'collapsed backing controls must remain reachable')
assert(M.routeResolver(host,function() return true end)(activeSnapshot.routes.CollapsedMode)==backing)
selected=0
local browserSnapshot=M.activeTrees(host,function() return true end)[1]
assert(#browserSnapshot.scrolls==1 and browserSnapshot.scrolls[1]==browser and not browserSnapshot.widgets.VisibleProvider)
print('PASS nested switchers traverse only selected page; paired backing controls remain reachable')

-- Reordered categories retain schema identity through a marker owned by each row.
local originalRow=M.rowFromWrapper
local function marked(index)
 local marker=widget('Marker'..index,'TextBlock')
 function marker:GetText() return table.concat({'MC_SETTING_6',tostring(index),'Provider','Row'..index,'slider','0','254','1','0','','','0'},'\n') end
 local shell=widget('Shell'..index,'Overlay',{marker})
 local wrapper=widget('Wrapper'..index,'SizeBox')
 function wrapper:GetContent() return shell end
 wrapper.row={label='Row'..index}
 return wrapper
end
local first,second=marked(1),marked(2)
M.rowFromWrapper=function(w) return w.row end
local ordered=M.rowsFromScroll(widget('Ordered','ScrollBox',{second,first}))
assert(ordered[1]==second.row and ordered[2]==first.row)
local placeholderText=widget('HeaderIdentity','TextBlock')
function placeholderText:GetText() return 'MC_HEADER_ROW\nOwned.Header' end
local placeholder=widget('Placeholder','SizeBox')
function placeholder:GetContent() return placeholderText end
local originalFind=StaticFindObject
StaticFindObject=function(path) if path=='Owned.Header' then return first end;return originalFind(path) end
ordered=M.rowsFromScroll(widget('Promoted','ScrollBox',{placeholder,second}))
assert(ordered[1]==first.row and ordered[2]==second.row,'Promoted headers retain schema identity')
StaticFindObject=originalFind
local modern=M.childAt(first:GetContent(),0)
 function modern:GetText() return table.concat({'MC_SETTING_6','1','Provider%25Name','PrimaryX','picker','','','','','','','2','0','1','Off','On%0A'},'\n') end
ordered=M.rowsFromScroll(widget('Grouped','ScrollBox',{second,first}))
assert(ordered[2].identityProviderId=='Provider%Name' and ordered[2].settingId=='PrimaryX')
assert(ordered[2].settingIndex==1,'DMM index is informational; visual order is retained')
local identity=ordered[2].dmmSetting
assert(identity.kind=='picker' and identity.values[1]==0 and identity.values[2]==1
 and identity.labels[1]=='Off' and identity.labels[2]=='On\n','values and escaped labels survive the identity')
M.rowFromWrapper=originalRow
print('PASS category reordering preserves schema row identity')

-- Presentation puts each label in a box with the dirty star after it; rows are still found.
local function boxed(name,class,child)
 local o=widget(name,class,{child})
 function o:GetContent() return child end
 return o
end
local function labelLine(prefix)
 local label=widget(prefix..'Label','TextBlock')
 return widget(prefix..'Line','HorizontalBox',{label,widget(prefix..'Star','TextBlock')}),label
end
local pickerLine,pickerLabel=labelLine('Picker')
local value=widget('PickerValue','TextBlock')
local lane=widget('PickerLane','HorizontalBox',{
 boxed('PickerLabelBox','SizeBox',boxed('PickerLabelButton','Button',pickerLine)),
 boxed('PickerLeftBox','SizeBox',widget('PickerLeft','Button',{})),
 boxed('PickerCenterBox','SizeBox',boxed('PickerCenter','Button',value)),
 boxed('PickerRightBox','SizeBox',widget('PickerRight','Button',{}))})
local pickerShell=widget('PickerShell','Overlay',{widget('PickerNav','Slider'),widget('PickerContent','Overlay',{lane})})
local pickerRow=assert(M.choiceRowFromWrapper(boxed('PickerWrapper','SizeBox',pickerShell)))
assert(pickerRow.kind=='picker' and pickerRow.labelWidget==pickerLabel and pickerRow.valueWidget==value,
 'a picker label beside its star is the row label')
local toggleLine,toggleLabel=labelLine('Toggle')
local toggleLane=widget('ToggleLane','HorizontalBox',{boxed('ToggleLabelBox','SizeBox',toggleLine),
 boxed('ToggleValueBox','SizeBox',widget('ToggleValue','TextBlock'))})
local toggleShell=widget('ToggleShell','Overlay',{widget('ToggleNav','Slider'),boxed('ToggleButton','Button',toggleLane)})
local toggleRow=assert(M.choiceRowFromWrapper(boxed('ToggleWrapper','SizeBox',toggleShell)))
assert(toggleRow.kind=='toggle' and toggleRow.labelWidget==toggleLabel,'a toggle label beside its star is the row label')
assert(M.parentOf(toggleLabel)==toggleLine)
-- A keybind row: DMM's value caption sits first in the editor's overlay, beside its controls.
local editorLine,editorLabel=labelLine('Editor')
local caption=widget('EditorCaption','TextBlock')
local host=widget('EditorHost','Overlay',{caption,widget('EditorControls','HorizontalBox',{})})
local editorLane=widget('EditorLane','HorizontalBox',{boxed('EditorLabelBox','SizeBox',editorLine),
 boxed('EditorValueBox','SizeBox',host)})
local editorShell=widget('EditorShell','Overlay',{widget('EditorNav','Slider'),boxed('EditorButton','Button',editorLane)})
local editorRow=assert(M.choiceRowFromWrapper(boxed('EditorWrapper','SizeBox',editorShell)),'a keybind row is found')
assert(editorRow.labelWidget==editorLabel and editorRow.valueWidget==caption,'its value is DMM\'s caption in the editor overlay')
print('PASS rows are found when the label shares a box with its dirty star')
