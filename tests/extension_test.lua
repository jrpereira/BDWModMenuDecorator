local loaded={}
local installs={}
local fieldTypes={registered={}}
local shared={}
ModRef={SetSharedVariable=function(_,key,value) shared[key]=value end,
    GetSharedVariable=function(_,key) return shared[key] end}
local originalLoadfile=loadfile
debug.getinfo=function() return {source='@C:/Mods/1_ModCore_Settings/Scripts/dmm_extension.lua'} end
loadfile=function(path)
    local name=assert(path:match('([^/\\]+)%.lua$'))
    -- Logging is real: it is loaded from the extension's folder before any module.
    if name=='mc_log' or name=='log_events' then return originalLoadfile('Scripts/'..name..'.lua') end
    loaded[#loaded+1]=path
    return function()
        if name=='menu_pages' then
            return {reader=function() return 'reader' end,install=function(...)
                installs[#installs+1]={name=name,args={...}}
            end}
        end
        if name=='menu_slots' then
            return {install=function(...)
                installs[#installs+1]={name=name,args={...}}
                return 'slots'
            end}
        end
        if name=='page_hooks' then
            return {loader=function() return function() return 'hooks' end end,
                context=function(page) return {page=page.id} end,
                manifest=function(_,context) return 'manifest for '..context.page end,
                install=function(...) installs[#installs+1]={name=name,args={...}} end}
        end
        if name=='field_types' then
            return {new=function()
                return {register=function(_,typeName,editor) fieldTypes.registered[typeName]=editor end,
                    install=function(_,modules) fieldTypes.modules=modules;fieldTypes.order=#installs end}
            end}
        end
        if name=='dmm_lifecycle' then
            return {publisher=function() return {publish=function(_,event) installs[#installs+1]={name='publish',event=event} end} end}
        end
        return {install=function(...)
            installs[#installs+1]={name=name,args={...}}
        end}
    end
end
local extension=assert(originalLoadfile('Scripts/dmm_extension.lua'))()
assert(extension.id=='ModCoreSettings' and extension.apiVersion==1 and type(extension.install)=='function')
local choices,controls,pages={},{},{}
local callbacks={}
local events={on=function(_,name,callback) callbacks[name]=callback end}
local settingsApi={}
extension.install({version=1,choices=choices,controls=controls,pages=pages,events=events,settingsApi=settingsApi})
local order={'mcs_manifest','navigation','mapped_presets','presentation','browser_groups','init_config','dmm_lifecycle',
 'menu_contributions','menu_pages','page_links','menu_slots','page_hooks','field_types','keybind_editor','standard_controls'}
assert(#loaded==#order)
for n,name in ipairs(order) do assert(loaded[n]:match(name..'%.lua$'),'load '..n) end
-- Field types install innermost, before any other wrapper.
assert(fieldTypes.order==0 and fieldTypes.registered.keybind and fieldTypes.modules.choices==choices
 and fieldTypes.modules.controls==controls and fieldTypes.modules.settingsApi==settingsApi
 and fieldTypes.modules.standardControls,'keybind registered and installed on DMM modules first')
assert(installs[1].args[1]==choices)
assert(installs[2].args[1]==choices and installs[2].args[2]==controls)
assert(installs[3].args[1]==choices and installs[3].args[2]==controls and installs[3].args[3]==pages)
assert(installs[4].args[1]==pages)
assert(installs[5].args[1]==choices)
assert(installs[6].name=='page_hooks' and installs[6].args[1]==choices,
 'hooks storage wraps open before the slot model')
assert(installs[7].name=='menu_slots' and installs[7].args[1]==choices and type(installs[7].args[3])=='table',
 'slot open wraps outermost so inner wrappers see the host page unspliced')
assert(installs[8].name=='menu_pages' and installs[8].args[1]==pages and installs[8].args[3]=='reader',
 'menu pages wrap after browser groups so contributions exist before grouping')
assert(installs[8].args[5]=='slots' and type(installs[8].args[6])=='function','menu pages drive slot splicing')
local hooks,manifest,context=installs[8].args[7]({id='MCC',hooks='/m/hooks.lua'})
assert(hooks=='hooks' and manifest=='manifest for MCC' and context.page=='MCC',
 'menu pages receive a hooks resolver for hooks pages')
assert(installs[9].name=='page_links' and installs[9].args[1]==pages)
for _,name in ipairs({'providerPrepared','providerRefreshed','hostClosing'}) do
 assert(type(callbacks[name])=='function');callbacks[name]({});assert(installs[#installs].event==name)
end
assert(shared['MC_DMM_Extension_v1.ready']=='1')
assert(not pcall(extension.install,{version=2,choices=choices,controls=controls,pages=pages,events=events}))
assert(not pcall(extension.install,{version=1,choices=choices,controls=controls,events=events}))
print('PASS pure-Lua DMM extension loads owned modules in order and rejects incompatible APIs')
