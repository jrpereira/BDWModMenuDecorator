-- Resolve the keyboard key currently assigned to a standard Enhanced Input action.
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

function M.resolve(actionId,environment)
    assert(type(actionId)=='string' and actionId:match('%S'),'standard control ID required')
    local e=environment or {unwrap=unwrap,valid=valid,full=full,path=path,property=property,
        each=each,name=name,controllers=function()
            local ok,items=pcall(FindAllOf,'BP_PlayerController_C')
            return ok and type(items)=='table' and items or {}
        end}
    local found={}
    for _,controller in ipairs(e.controllers()) do
        if e.valid(controller) then
            local playerInput=e.property(controller,'PlayerInput')
            if e.valid(playerInput) then
                e.each(e.property(playerInput,'AppliedInputContexts') or {},function(context)
                    if not (e.path(context) or ''):match('^/Game/') then return end
                    e.each(e.property(context,'Mappings') or {},function(mapping)
                        local action=e.property(mapping,'Action')
                        local id=(e.full(action) or ''):match('([^%.:/%s]+)$')
                        if id~=actionId then return end
                        local key=e.property(e.property(mapping,'Key'),'KeyName')
                        local keyName=e.name(key)
                        if keyName and keyName~='' and not keyName:find('^Gamepad_') then
                            found[keyName]=true
                        end
                    end)
                end)
            end
        end
    end
    local result
    for keyName in pairs(found) do
        if result and result~=keyName then return nil,'multiple keyboard bindings: '..actionId end
        result=keyName
    end
    if result then return result end
    return nil,'standard control unavailable: '..actionId
end

return M
