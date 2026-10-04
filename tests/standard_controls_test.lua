package.path='Scripts/?.lua;'..package.path
local function object(class,path)
    local value={valid=true,full=class..' '..path,path=path}
    function value:IsValid() return self.valid end
    function value:GetFullName() return self.full end
    return value
end
local action=object('InputAction','/Game/Input.IA_Combat_ToggleQuickslots')
local context=object('InputMappingContext','/Game/Input.IMC_Combat.Runtime')
local transient=object('InputMappingContext','/Engine/Transient.IMC_MCC')
context.Mappings={{Action=action,Key={KeyName='LeftAlt'}},
    {Action=action,Key={KeyName='Gamepad_FaceButton_Top'}}}
transient.Mappings={{Action=action,Key={KeyName='Z'}}}
local input=object('PlayerInput','/Engine/Transient.Input')
input.AppliedInputContexts={[context]=5,[transient]=1000}
local controller=object('PlayerController','/Engine/Transient.Controller');controller.PlayerInput=input
local e={controllers=function() return {controller} end,
    valid=function(value) return value and value.valid end,
    unwrap=function(value) return value end,
    full=function(value) return value and value.full end,
    path=function(value) return value and value.path end,
    property=function(value,key) return value and value[key] end,
    name=function(value) return value end,
    each=function(values,callback)
        for key,value in pairs(values or {}) do
            if type(key)=='number' then callback(value,key) else callback(key,value) end
        end
        return true
    end}
local key,why=require('standard_controls').resolve('IA_Combat_ToggleQuickslots',e)
assert(key=='LeftAlt' and why==nil,'standard keyboard control was not resolved')
context.Mappings[1].Key.KeyName='None'
assert(require('standard_controls').resolve('IA_Combat_ToggleQuickslots',e)=='None')
print('PASS standard control keyboard binding resolution')
