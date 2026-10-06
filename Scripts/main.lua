local VERSION='1.0.1'
local Bootstrap=require('dmm_bootstrap')
-- The level comes from log_level.txt in the mod folder; WARN without it.
local source=debug.getinfo(1,'S').source:gsub('^@','')
local root=source:match('^(.*)[/\\]Scripts[/\\][^/\\]+$')
local logger=require('mc_log').new({name='ModCoreSettings',path=root and root..'/log_level.txt'})
local log=require('log_events').reporter(logger)
local initialized=false
local function initialize()
    if initialized then return true end
    local Binding=require('dmm_binding')
    local ok,err=Binding.install(log)
    if not ok then log('DMM_BINDING_UNAVAILABLE',tostring(err));return false end
    initialized=true
    logger.info(VERSION,' ready')
    return true
end
Bootstrap.run(log,initialize)
