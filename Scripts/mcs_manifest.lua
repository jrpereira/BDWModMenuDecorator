-- Reads a settings manifest the way DMM's choices.parse does, so every module that
-- reads its own keys finds the same sections and setting ids. Runs in DMM's Lua state;
-- dmm_extension preloads it as package.loaded.mcs_manifest.
local M={version=1}
local function trim(s) return (s or ''):match('^%s*(.-)%s*$') end
M.trim=trim

-- Returns every [section] in order, and the manifest's lines (a final empty line
-- dropped). Each section has:
--   name        the text between the brackets
--   first,last  its header line and its last line
--   fields      key -> value, both trimmed; a repeated key keeps its last value
--   duplicates  key -> true for each key given more than once
--   malformed   lines that are neither blank, a comment, nor key=value
-- [Setting] and [Setting.*] sections also have setting (their position among
-- setting sections) and id (Id, or DMM's fallback 'setting_<setting>').
-- Lines before the first section, and comment lines (';' or '#'), are skipped.
function M.sections(content)
    local lines={}
    for line in (content..'\n'):gmatch('([^\n]*)\n') do lines[#lines+1]=line end
    if lines[#lines]=='' then lines[#lines]=nil end
    local list,current,settings={},nil,0
    for n,line in ipairs(lines) do
        local clean=trim(line)
        local name=clean:match('^%[([^%]]+)%]$')
        if name then
            if current then current.last=n-1 end
            current={name=name,first=n,fields={},duplicates={},malformed={}}
            if name=='Setting' or name:match('^Setting%.') then
                settings=settings+1
                current.setting=settings
            end
            list[#list+1]=current
        elseif current and clean~='' and not clean:match('^[;#]') then
            local key,value=line:match('^%s*([^=]+)=(.*)$')
            if key then
                key=trim(key)
                if current.fields[key]~=nil then current.duplicates[key]=true end
                current.fields[key]=trim(value)
            else
                current.malformed[#current.malformed+1]=n
            end
        end
    end
    if current then current.last=#lines end
    for _,section in ipairs(list) do
        if section.setting then section.id=section.fields.Id or ('setting_'..section.setting) end
    end
    return list,lines
end

-- Only the [Setting] and [Setting.*] sections, in order.
function M.settings(content)
    local out={}
    for _,section in ipairs((M.sections(content))) do
        if section.setting then out[#out+1]=section end
    end
    return out
end

return M
