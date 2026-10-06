-- Runs inside DMM's Lua state. The launcher that replaces DMM's main.lua calls
-- launch() before running DMM's own main, so every hook is on DMM's module tables
-- before DMM uses them. Keep this file self-contained: the ordinary
-- ModCoreSettings mod runs in a different state.
local source=assert(debug.getinfo(1,'S').source,'extension source unavailable')
local directory=assert(source:match('^@(.+[\\/])[^\\/]+$'),'extension directory unavailable')

local function module(name)
    local chunk,err=loadfile(directory..name..'.lua')
    assert(chunk,err)
    local value=chunk()
    assert(type(value)=='table',name..' did not return a module')
    return value
end

-- Events are written at their level; log_level.txt in the mod folder sets it (WARN without it).
local report=(function()
    local root=directory:match('^(.*)[/\\]Scripts[/\\]$')
    local logger=module('mc_log').new({name='ModCoreSettings',path=root and root..'/log_level.txt'})
    return module('log_events').reporter(logger)
end)()

local extension
extension={
    id='ModCoreSettings',
    apiVersion=1,
    -- Loads DMM's modules ahead of DMM's main, recreates its lifecycle events,
    -- then installs exactly as before.
    launch=function()
        local events=module('dmm_events')
        local controls=require('controls')
        local bus=events.bus(report)
        events.attach({controls=controls,nativeactions=require('nativeactions')},bus,report)
        extension.install({version=1,choices=require('choices'),controls=controls,
            pages=require('pages'),events=bus,settingsApi=require('dmm_api')})
    end,
    install=function(dmm)
        assert(type(dmm)=='table' and dmm.version==1,'unsupported DMM extension API')
        assert(type(dmm.choices)=='table' and type(dmm.controls)=='table' and type(dmm.pages)=='table',
            'DMM extension modules unavailable')
        local navigation=module('navigation')
        local mapped=module('mapped_presets')
        local presentation=module('presentation')
        local browserGroups=module('browser_groups')
        local config=module('init_config')
        local lifecycle=module('dmm_lifecycle')
        local contributions=module('menu_contributions')
        local menuPages=module('menu_pages')
        local pageLinks=module('page_links')
        local menuSlots=module('menu_slots')
        local pageHooks=module('page_hooks')
        assert(type(mapped.install)=='function','mapped preset installer unavailable')
        assert(type(presentation.install)=='function','presentation installer unavailable')
        assert(type(config.install)=='function','configuration installer unavailable')
        assert(type(dmm.events)=='table' and type(dmm.events.on)=='function','DMM lifecycle events unavailable')
        assert(type(lifecycle.publisher)=='function','lifecycle publisher unavailable')
        -- Innermost: every other wrapper sees this module's settings among DMM's own.
        local fieldTypes=module('field_types').new(report)
        local keybind=module('keybind_editor')
        fieldTypes:register('keybind',keybind)
        fieldTypes:install({choices=dmm.choices,controls=dmm.controls,settingsApi=dmm.settingsApi,
            standardControls=module('standard_controls')})
        navigation.install(dmm.choices)
        mapped.install(dmm.choices,dmm.controls)
        presentation.install(dmm.choices,dmm.controls,dmm.pages,{keyColumn=keybind.layout})
        browserGroups.install(dmm.pages,report)
        config.install(dmm.choices)
        assert(ModRef and type(ModRef.GetSharedVariable)=='function','DMM shared variables unavailable')
        local function read(path)
            local file=assert(io.open(path,'rb'))
            local content=file:read('a')
            file:close()
            return assert(content,'unreadable '..path)
        end
        -- Hooks storage sits inside the slot model, which must stay outermost.
        pageHooks.install(dmm.choices)
        local loadHooks=pageHooks.loader()
        local function hooked(page)
            local hooks=loadHooks(page.hooks)
            local context=pageHooks.context(page)
            return hooks,pageHooks.manifest(hooks,context),context
        end
        -- Outermost open: inner wrappers only ever see the host's own unspliced settings.
        local slots=menuSlots.install(dmm.choices,report,contributions,read)
        -- Wrapped after browser groups so contributed pages exist before ModCore grouping runs.
        menuPages.install(dmm.pages,function(content) return dmm.choices.parse(content) end,
            menuPages.reader(contributions,ModRef,read,report),report,slots,read,hooked)
        pageLinks.install(dmm.pages,slots)
        local publisher=lifecycle.publisher(report)
        for _,name in ipairs({'providerPrepared','providerRefreshed','hostClosing'}) do
            dmm.events:on(name,function(context) publisher:publish(name,context) end)
        end
        assert(ModRef and type(ModRef.SetSharedVariable)=='function','DMM extension handshake unavailable')
        ModRef:SetSharedVariable('MC_DMM_Extension_v1.ready','1')
    end,
}
return extension
