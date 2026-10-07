package.path='Scripts/?.lua;Scripts/vendor/?.lua;'..package.path
local function object(class,path)
    local value={valid=true,full=class..' '..path,path=path}
    function value:IsValid() return self.valid end
    function value:GetFullName() return self.full end
    return value
end
local action=object('InputAction','/Game/Input.IA_Combat_ToggleQuickslots')
local other=object('InputAction','/Game/Input.IA_Jump')
-- The Settings key profile: rows of player mappings, each naming its action.
local toggleRow={Mappings={
    {AssociatedInputAction=action,MappingName='ToggleQuickslots',CurrentKey={KeyName='LeftAlt'}},
    {AssociatedInputAction=action,MappingName='ToggleQuickslots',CurrentKey={KeyName='Gamepad_FaceButton_Top'}},
    {AssociatedInputAction=action,MappingName='ToggleQuickslots',CurrentKey={KeyName='Q'}}}}
local jumpRow={Mappings={{AssociatedInputAction=other,MappingName='Jump',CurrentKey={KeyName='SpaceBar'}}}}
local profile=object('KeyProfile','/Engine/Transient.Profile')
profile.PlayerMappedKeys={ToggleQuickslots=toggleRow,Jump=jumpRow}
local settings=object('UserSettings','/Engine/Transient.Settings')
function settings:GetCurrentKeyProfile() return profile end
local subsystem=object('EnhancedInputLocalPlayerSubsystem','/Engine/Transient.Subsystem')
function subsystem:GetUserSettings() return settings end
local actions={action,other}
local e={subsystems=function() return {subsystem} end,
    actions=function() return actions end,
    call=function(o,method) return o[method](o) end,
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
local Controls=require('standard_controls')
local keys,why=Controls.resolve('IA_Combat_ToggleQuickslots',e)
assert(keys and why==nil and #keys==2 and keys[1]=='LeftAlt' and keys[2]=='Q',
    'every keyboard key in the profile is resolved, gamepad keys are not')
-- A row that names the action only through its mappable key settings still resolves.
for _,entry in ipairs(toggleRow.Mappings) do entry.AssociatedInputAction=nil end
action.PlayerMappableKeySettings={Name='ToggleQuickslots'}
keys=Controls.resolve('IA_Combat_ToggleQuickslots',e)
assert(keys and #keys==2,'mapping name fallback')
-- Unbound and missing profiles report why.
for _,entry in ipairs(toggleRow.Mappings) do entry.CurrentKey={KeyName='None'} end
keys,why=Controls.resolve('IA_Combat_ToggleQuickslots',e)
assert(keys==nil and why:find('unavailable',1,true))
subsystem.valid=false
keys,why=Controls.resolve('IA_Combat_ToggleQuickslots',e)
assert(keys==nil and why:find('key profile unavailable',1,true))
print('PASS standard control keys resolve from the Settings key profile')
