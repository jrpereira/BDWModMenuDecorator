-- Accept metadata emitted by mods built for AdaptiveModMenu while they move to KEM.
local M = {version = 1}
local supported = {
    BrowserIndent=true, BrowserLevel=true, Heading=true, Help=true,
    LabelWhen=true, Labels=true, Level=true, Mode=true, Navigation=true,
    OrderWhen=true, Orders=true, Parent=true, ParentLevel=true,
    TabsWidth=true, Type=true,
}

local function linesOf(content)
    local lines = {}
    content = content:gsub('\r\n', '\n'):gsub('\r', '\n')
    for line in (content .. '\n'):gmatch('(.-)\n') do lines[#lines + 1] = line end
    return lines
end

function M.normalize(content)
    local lines = linesOf(content)
    local canonical, section = {}, 0
    for _, line in ipairs(lines) do
        if line:match('^%s*%[[^%]]+%]%s*$') then
            section = section + 1
            canonical[section] = {}
        else
            local key = line:match('^%s*(kem[%a]+)%s*=')
            if key and canonical[section] then canonical[section][key] = true end
        end
    end
    section = 0
    for index, line in ipairs(lines) do
        if line:match('^%s*%[[^%]]+%]%s*$') then
            section = section + 1
        else
            local before, suffix, after = line:match('^(%s*)amm([%u][%a]+)(%s*=.*)$')
            if suffix and supported[suffix] then
                local key = 'kem' .. suffix
                lines[index] = canonical[section] and canonical[section][key]
                    and '' or before .. key .. after
            end
        end
    end
    return table.concat(lines, '\n')
end

function M.install(choices)
    if choices.kemLegacyMetadataVersion then return false end
    local parse = choices.parse
    choices.parse = function(content) return parse(M.normalize(content)) end
    choices.kemLegacyMetadataVersion = M.version
    return true
end

return M
