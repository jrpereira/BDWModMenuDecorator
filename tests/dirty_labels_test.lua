package.path='Scripts/?.lua;Scripts/vendor/?.lua;'..package.path
local calls=0
local objects,rows={},{ }
local rowLookups=0
local nextId=0
local function widget(kind,text)
    nextId=nextId+1
    local w={id=tostring(nextId),kind=kind,text=text or '',children={},alive=true,
        Font={TypefaceFontName='Regular',SkewAmount=0,FontObject={CompositeFont={DefaultTypeface={Fonts={{Name='Regular'},{Name='Italic'}}}}}}}
    function w:IsValid() return self.alive end
    function w:GetAddress() assert(self.alive,'stale access');return self.id end
    function w:GetParent() return self.parent end
    function w:GetOuter() return self.outer end
    function w:SetVisibility(v) self.visibility=v end
    function w:SetFont(font) calls=calls+1;self.fontWrites=(self.fontWrites or 0)+1;self.Font=font end
    function w:SetText(value)
        calls=calls+1;assert(type(value)=='table' and value.ftext)
        self.text=value.ftext
    end
    function w:AddChildToOverlay(child) self.children[#self.children+1]=child;child.parent=self;local slot={}
        function slot:SetHorizontalAlignment(v) self.horizontal=v end
        function slot:SetVerticalAlignment(v) self.vertical=v end
        function slot:SetPadding(v) self.padding=v end
        child.Slot=slot;return slot end
    objects[w.id]=w;return w
end
local host=widget('Host');host.WidgetTree=widget('WidgetTree')
local textLib=widget('Library')
function textLib:Conv_StringToText(text) return {ftext=text} end
StaticFindObject=function(path)
    if path=='host' then return host end
    if path:find('KismetTextLibrary',1,true) then return textLib end
    return 'TextBlockClass'
end
StaticConstructObject=function(class,outer) local w=widget('TextBlock');w.outer=outer;return w end
FName=function(text) return text end
local routes={}
local Discovery={}
function Discovery.valid(w) return w and w.alive end
function Discovery.address(w) return w and w:GetAddress() end
function Discovery.textOf(w) return w.text end
function Discovery.className(w) return w and w.kind or '' end
function Discovery.isTextBlock(w) return w and w.kind=='TextBlock' end
function Discovery.childCount(w) return #w.children end
function Discovery.childAt(w,i) return w.children[i+1] end
function Discovery.parentOf(w) return w and w.parent end
function Discovery.rowFromWrapper(w) rowLookups=rowLookups+1;return rows[w] end
function Discovery.routeResolver(h,allowed)
    if h~=host or not allowed() then return end
    for _=1,40 do assert(allowed()) end -- A deep route must not repeat owner lookup.
    return function(route) local w=objects[route];if w and w.alive then return w end end
end
package.loaded.widget_discovery=Discovery
local M=require('dirty_labels')
local slider={kind='slider',decimals=0,prefix='',suffix='',minimum=0,maximum=255,step=1}
local picker={kind='picker',labels={'Tap','Hold'},values={0,1}}
local function row(label,text,setting)
    local spec={};for k,v in pairs(setting) do spec[k]=v end;spec.id=label
    local r={labelWidget=widget('TextBlock',label),valueWidget=widget('TextBlock',text),shell=widget('Overlay'),nav=widget('Slider'),dmmSetting=spec,providerId='Example'}
    r.nav.value=setting.kind=='slider' and tonumber(text)/255 or 0
    function r.nav:GetValue() return self.value end
    function r.nav:SetValue(value) self.value=value end
    for _,w in ipairs({r.labelWidget,r.valueWidget,r.shell,r.nav}) do w.outer=host.WidgetTree;routes[w.id]=w.id end
    r.valueWidget.parent=r.shell;rows[r.shell]=r
    -- Presentation puts the star right after the label, in the box both share.
    if not setting.noStar then
        r.line=widget('HorizontalBox');r.line.outer=host.WidgetTree
        r.star=widget('TextBlock','*');r.star.outer=host.WidgetTree;r.star.visibility=2
        r.line.children={r.labelWidget,r.star};r.labelWidget.parent=r.line;r.star.parent=r.line
    end
    return r
end
local key,mode,toggle=row('Ability','82',slider),row('Mode','Tap',picker),row('Enabled','On',{kind='toggle',labels={'Off','On'}})
local literal=row('* Literal label','Option *',{kind='picker',labels={'Option *','Other'}})
local fallback=row('No italic face','1',slider);fallback.labelWidget.Font.FontObject={}
local header=row('Quickslots','None',{kind='picker',labels={'None','Default'},mcHeader=true})
header.providerId='ModCoreTemplates.module.VisualExample'
local template=row('Quickslots','None',{kind='picker',labels={'None','Default'},mcHeader=true})
template.providerId='ModCoreTemplates'
local starless=row('Plain','Tap',{kind='picker',labels={'Tap','Hold'},values={0,1},noStar=true})
local all={key,mode,toggle,literal,fallback,header,template,starless}
local function star(r)
    assert(r.star and r.star.parent==r.line and r.line.children[2]==r.star,'missing star after the label')
    return r.star
end
local active=true
local ownerChecks=0
local function live() ownerChecks=ownerChecks+1;return active end
local errors={}
local controller=M.new(function(e,d) errors[#errors+1]=e..': '..d end)
assert(controller:open('host',function() return active end,live))
controller:bind(all,routes)
assert(#errors==0,table.concat(errors,'\n'))
assert(#header.shell.children==0,'The level-one title row must not show a dirty star')
local function changed(r,text) r.valueWidget:SetText({ftext=text});controller:refresh(host) end

for _,r in ipairs({key,mode,toggle,literal,fallback,template}) do
    assert(star(r).visibility==2,'a clean row hides the star after its label')
    for _,w in ipairs(r.shell.children) do assert(w.text~='*','dirty labels must not add a star of their own') end
end
local count=#key.shell.children
controller:bind(all,routes)
assert(#key.shell.children==count,'rebinding must reuse the star')
local previousFonts=key.labelWidget.fontWrites
changed(key,'49') -- DMM's mapped-preset wrapper suppresses its own dirty suffix.
assert(key.labelWidget.fontWrites==previousFonts,'suppressed preset changes must not restyle unchanged labels')
changed(mode,'Hold')
assert(key.labelWidget.text=='Ability' and mode.labelWidget.text=='Mode')
assert(key.labelWidget.Font.TypefaceFontName=='Regular')
changed(key,'49') -- A repeated refresh must not invent dirty state.
assert(key.labelWidget.text=='Ability')
changed(key,'50 *') -- A new manual edit is visible.
assert(key.labelWidget.text=='Ability' and star(key).visibility==4)
changed(key,'82');changed(mode,'Tap')
assert(key.labelWidget.text=='Ability')
assert(literal.valueWidget.text=='Option *' and literal.labelWidget.text=='* Literal label')
local ownerBefore=ownerChecks
changed(key,'75 *')
assert(ownerChecks==ownerBefore+1,'one fresh owner lookup per signal, not per route node')
assert(key.valueWidget.text=='75' and key.labelWidget.text=='Ability' and star(key).visibility==4 and key.labelWidget.Font.TypefaceFontName=='Italic')
changed(mode,'Hold *')
assert(star(mode).visibility==4,'each row shows its own dirty state')
changed(key,'82')
assert(key.labelWidget.text=='Ability' and star(key).visibility==2 and key.labelWidget.Font.TypefaceFontName=='Regular')
changed(mode,'Tap')
assert(mode.labelWidget.text=='Mode' and mode.labelWidget.Font.TypefaceFontName=='Regular')
changed(toggle,'Off *')
assert(toggle.labelWidget.text=='Enabled' and star(toggle).visibility==4 and toggle.valueWidget.text=='Off')
changed(toggle,'On') -- Restore changes the rendered value and clears the marker.
assert(toggle.labelWidget.text=='Enabled' and star(toggle).visibility==2)
local signal=widget('TextBlock','MC_VALUE_DIRTY_1\n0\nOn')
signal.outer=host.WidgetTree;toggle.shell:AddChildToOverlay(signal)
controller:bind(all,routes)
signal:SetText({ftext='MC_VALUE_DIRTY_1\n1\nOff'})
toggle.valueWidget:SetText({ftext='Off'})
controller:refresh(host)
assert(star(toggle).visibility==4 and toggle.valueWidget.text=='Off',
    'The DMM signal must show dirty state without a value-text suffix')
signal:SetText({ftext='MC_VALUE_DIRTY_1\n0\nOff'})
controller:refresh(host)
assert(star(toggle).visibility==2,
    'Apply must clear the star even when the displayed value stays Off')
changed(fallback,'2 *')
assert(fallback.labelWidget.Font.SkewAmount==0.2)
changed(fallback,'1')
assert(fallback.labelWidget.Font.SkewAmount==0)
changed(literal,'Option * *')
assert(literal.valueWidget.text=='Option *' and literal.labelWidget.text=='* Literal label' and star(literal).visibility==4)
changed(literal,'Option *')
assert(literal.labelWidget.text=='* Literal label')
local unrelated=widget('TextBlock','Other');unrelated.outer=host.WidgetTree
local ownerBeforeUnrelated=ownerChecks
unrelated:SetText({ftext='Literal *'});controller:refresh(host)
assert(ownerChecks==ownerBeforeUnrelated+1,'one active-page check per refresh')
assert(unrelated.text=='Literal *','unowned text must not be intercepted')
assert(#errors==0,table.concat(errors,'\n'))

-- DMM writes restored text synchronously between the page event and row binding.
changed(key,'90 *')
controller:open('host',function() return active end,live)
key.valueWidget:SetText({ftext='82'})
controller:bind(all,routes)
assert(key.labelWidget.text=='Ability' and key.labelWidget.Font.TypefaceFontName=='Regular')
-- Rebinding without a DMM write retains the row-owned signal after suffix stripping.
changed(key,'90 *')
controller:open('host',function() return active end,live)
controller:bind(all,routes)
assert(key.labelWidget.text=='Ability' and star(key).visibility==4)
-- A reused address cannot resolve to an invalid row.
key.shell.alive=false
key.valueWidget:SetText({ftext='91 *'})
controller:refresh(host)
assert(key.valueWidget.text=='91 *')
key.shell.alive=true
active=false
local before=calls
key.valueWidget:SetText({ftext='92 *'})
controller:refresh(host)
assert(calls==before+1 and key.valueWidget.text=='92 *')
controller:close();assert(next(controller.records)==nil)
before=calls
key.valueWidget:SetText({ftext='93 *'})
assert(calls==before+1)
assert(#errors==0,table.concat(errors,'\n'))
active=true;controller:open('host',function() return active end,live);controller:bind(all,routes)
changed(starless,'Hold *')
assert(#errors==0 and starless.labelWidget.Font.TypefaceFontName=='Italic',
    'A row without a star still shows its dirty label: '..table.concat(errors,'\n'))
print('PASS menu-scoped dirty presentation, real-face/skew restoration, literal stars, reopen and cleanup')
