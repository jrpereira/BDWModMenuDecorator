local loaded={}
local installs={}
local shared={}
ModRef={SetSharedVariable=function(_,key,value) shared[key]=value end,
    GetSharedVariable=function(_,key) return shared[key] end}
local originalLoadfile=loadfile
debug.getinfo=function() return {source='@C:/Mods/_ModCore_1_Settings/Scripts/dmm_extension.lua'} end
loadfile=function(path)
    loaded[#loaded+1]=path
    local name=assert(path:match('([^/\\]+)%.lua$'))
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
extension.install({version=1,choices=choices,controls=controls,pages=pages,events=events})
local order={'navigation','mapped_presets','presentation','browser_groups','init_config','dmm_lifecycle',
 'menu_contributions','menu_pages','page_links','menu_slots'}
assert(#loaded==#order)
for n,name in ipairs(order) do assert(loaded[n]:match(name..'%.lua$'),'load '..n) end
assert(installs[1].args[1]==choices)
assert(installs[2].args[1]==choices and installs[2].args[2]==controls)
assert(installs[3].args[1]==choices and installs[3].args[2]==controls and installs[3].args[3]==pages)
assert(installs[4].args[1]==pages)
assert(installs[5].args[1]==choices)
assert(installs[6].name=='menu_slots' and installs[6].args[1]==choices and type(installs[6].args[3])=='table',
 'slot open wraps outermost so inner wrappers see the host page unspliced')
assert(installs[7].name=='menu_pages' and installs[7].args[1]==pages and installs[7].args[3]=='reader',
 'menu pages wrap after browser groups so contributions exist before grouping')
assert(installs[7].args[5]=='slots' and type(installs[7].args[6])=='function','menu pages drive slot splicing')
assert(installs[8].name=='page_links' and installs[8].args[1]==pages)
for _,name in ipairs({'providerPrepared','providerRefreshed','hostClosing'}) do
 assert(type(callbacks[name])=='function');callbacks[name]({});assert(installs[#installs].event==name)
end
assert(shared['KEM_DMM_Extension_v1.ready']=='1')
assert(not pcall(extension.install,{version=2,choices=choices,controls=controls,pages=pages,events=events}))
assert(not pcall(extension.install,{version=1,choices=choices,controls=controls,events=events}))
print('PASS pure-Lua DMM extension loads owned modules in order and rejects incompatible APIs')
