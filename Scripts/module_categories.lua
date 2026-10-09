-- DMM's state reads the MCS-owned file index; no category shared variables.
local M={}
function M.preferences(text)
    local result={groupModules=true,preferredMinimum=2}
    local section=''
    for line in ((text or '')..'\n'):gmatch('([^\n]*)\n') do
        local header=line:match('^%s*%[([^%]]+)%]%s*$')
        if header then section=header end
        if section=='Modules' then
            local key,value=line:match('^%s*([%w_]+)%s*=%s*(%d+)%s*[;#]?.*$')
            value=tonumber(value)
            if key=='GroupModules' and (value==0 or value==1) then result.groupModules=value==1 end
            if key=='PreferredCategoryMinimum' and (value==0 or value==2 or value==3) then result.preferredMinimum=value end
        end
    end
    return result
end
function M.reader(indexPath,configPath,read,dependencies)
    dependencies=dependencies or {}
    local taxonomy=dependencies.taxonomy or require('mcs_taxonomy').new(require('mcs_taxonomy_data'))
    local json=dependencies.json or require('mcs_module_json')
    read=read or function(path)
        local file,err,code=io.open(path,'rb')
        if not file then if code==2 then return nil end;error(err or 'cannot read module browser data') end
        local text=file:read(1048577);file:close()
        assert(text and #text<=1048576,'module browser data exceeds 1 MiB')
        return text
    end
    local previous,index,lastError
    return function()
        local options=M.preferences(read(configPath))
        local ok,text=pcall(read,indexPath)
        if ok and text and text~=previous then
            local decoded,value=pcall(function() return taxonomy:index(json.decode(text)) end)
            if decoded then index=value;previous=text;lastError=nil
            else ok=false;text=value end
        end
        if not ok and text~=lastError then
            lastError=text
            if dependencies.report then dependencies.report('MODULE_INDEX_UNAVAILABLE',tostring(text)) end
        end
        -- Keep the last valid snapshot while a replacement is missing or invalid.
        options.categoryRegister=index and index.modules or {}
        options.categoryDescriptions=taxonomy.descriptions
        options.taxonomy=taxonomy
        return options
    end
end
return M
