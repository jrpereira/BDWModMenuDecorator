-- Resolve the keyboard keys the player assigned to a standard Enhanced Input action.
local M={}

local function unwrap(value)
    if value==nil then return nil end
    local ok,result=pcall(function() return value:get() end)
    return ok and result or value
end
local function valid(value)
    local ok,result=pcall(function() return value~=nil and value:IsValid() end)
    return ok and result==true
end
local function full(value)
    local ok,result=pcall(function() return value:GetFullName() end)
    return ok and tostring(result) or nil
end
local function path(value)
    local name=full(value)
    return name and (name:match('^%S+%s+(.+)$') or name) or nil
end
local function property(object,name)
    if object==nil then return nil end
    local ok,value=pcall(function() return object[name] end)
    return ok and unwrap(value) or nil
end
local function each(values,callback)
    if type(values)=='table' then
        for key,value in pairs(values) do
            if type(key)=='number' then callback(unwrap(value),key)
            else callback(unwrap(key),unwrap(value)) end
        end
        return true
    end
    return pcall(function()
        values:ForEach(function(key,value)
            key,value=unwrap(key),unwrap(value)
            if type(key)=='number' then callback(value,key) else callback(key,value) end
        end)
    end)
end
local function name(value)
    value=unwrap(value)
    if value==nil then return nil end
    if type(value)=='string' then return value end
    local ok,result=pcall(function() return value:ToString() end)
    return ok and tostring(result) or tostring(value)
end

-- Returns the sorted keyboard keys the player bound to the action in the Settings
-- key profile. The profile holds them whether or not an applied context maps the
-- action, as for the combat toggle outside combat or in the pause menu.
function M.resolve(actionId,environment)
    assert(type(actionId)=='string' and actionId:match('%S'),'standard control ID required')
    local e=environment or {unwrap=unwrap,valid=valid,full=full,path=path,property=property,
        each=each,name=name,
        subsystems=function()
            local ok,items=pcall(FindAllOf,'EnhancedInputLocalPlayerSubsystem')
            return ok and type(items)=='table' and items or {}
        end,
        actions=function()
            local ok,items=pcall(FindAllOf,'InputAction')
            return ok and type(items)=='table' and items or {}
        end,
        call=function(object,method) return object[method](object) end}
    local function shortName(object) return (e.full(object) or ''):match('([^%.:/%s]+)$') end
    local profile
    for _,subsystem in ipairs(e.subsystems()) do
        if e.valid(subsystem) then
            local ok,candidate=pcall(function()
                local settings=e.unwrap(e.call(subsystem,'GetUserSettings'))
                return e.valid(settings) and e.unwrap(e.call(settings,'GetCurrentKeyProfile')) or nil
            end)
            if ok and e.valid(candidate) then profile=candidate;break end
        end
    end
    if not profile then return nil,'key profile unavailable: '..actionId end
    local function collect(matches)
        local found={}
        e.each(e.property(profile,'PlayerMappedKeys') or {},function(_,row)
            e.each(e.property(row,'Mappings') or {},function(entry)
                if matches(entry) then
                    local keyName=e.name(e.property(e.property(entry,'CurrentKey'),'KeyName'))
                    if keyName and keyName~='' and keyName~='None' and not keyName:find('^Gamepad_') then
                        found[keyName]=true
                    end
                end
            end)
        end)
        local result={}
        for keyName in pairs(found) do result[#result+1]=keyName end
        table.sort(result)
        return result
    end
    local result=collect(function(entry)
        return shortName(e.property(entry,'AssociatedInputAction'))==actionId
    end)
    if #result==0 then
        -- Profile rows may name the action only through its mappable key settings.
        local mappingName
        for _,action in ipairs(e.actions()) do
            if e.valid(action) and shortName(action)==actionId then
                mappingName=e.name(e.property(e.property(action,'PlayerMappableKeySettings'),'Name'))
                break
            end
        end
        if mappingName and mappingName~='' then
            result=collect(function(entry) return e.name(e.property(entry,'MappingName'))==mappingName end)
        end
    end
    if #result>0 then return result end
    return nil,'standard control unavailable: '..actionId
end

return M
