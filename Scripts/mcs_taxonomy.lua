-- Validate taxonomy selections and the file index in both Lua states.
local M={}
local function array(values)
    assert(type(values)=='table','expected a category/tag list')
    local n=0
    for key in pairs(values) do
        assert(type(key)=='number' and key%1==0 and key>=1,'expected a list')
        n=n+1
    end
    assert(n==#values,'sparse list')
    return values
end
local function plain(value,limit)
    assert(type(value)=='string' and #value>0 and #value<=limit
        and utf8.len(value) and not value:find('%c'),'invalid browser text')
    return value
end
function M.new(data)
    assert(type(data)=='table' and data.version==2,'unsupported taxonomy')
    local T={data=data,definitions={},tagDefinitions={},descriptions={},sections={}}
    for _,section in ipairs(data.sections) do T.sections[section.id]=true end
    for _,definition in ipairs(data.categories) do
        assert(not T.definitions[definition.id],'duplicate category')
        T.definitions[definition.id]=definition
        T.descriptions[definition.id]=definition.description
    end
    for _,definition in ipairs(data.tags) do T.tagDefinitions[definition.id]=definition end
    function T:categories(values)
        local seen,result={},{}
        for _,id in ipairs(array(values==nil and {} or values)) do
            assert(type(id)=='string' and self.definitions[id],'unknown category: '..tostring(id))
            assert(not seen[id],'duplicate category: '..id)
            seen[id]=true
        end
        -- A selected child already grants its parent.
        for id in pairs(seen) do
            local parent=self.definitions[id].parent
            if parent then seen[parent]=nil end
        end
        for _,definition in ipairs(data.categories) do
            if seen[definition.id] then result[#result+1]=definition.id end
        end
        assert(#result<=data.max_categories,'at most three categories are allowed')
        assert(not seen.other or #result==1,'other cannot accompany a substantive category')
        if #result==0 then result={'other'} end
        return result
    end
    function T:parents(values)
        local seen,result={},{}
        for _,id in ipairs(self:categories(values)) do
            seen[self.definitions[id].parent or id]=true
        end
        for _,section in ipairs(data.sections) do
            if seen[section.id] then result[#result+1]=section.id end
        end
        return result
    end
    function T:tags(values)
        local seen,result={},{}
        for _,id in ipairs(array(values==nil and {} or values)) do
            assert(self.tagDefinitions[id],'unknown tag: '..tostring(id))
            assert(not seen[id],'duplicate tag: '..id);seen[id]=true
        end
        for _,definition in ipairs(data.tags) do
            if seen[definition.id] then result[#result+1]=definition.id end
        end
        return result
    end
    function T:entry(entry)
        assert(type(entry)=='table','invalid index entry')
        entry.categories=self:categories(entry.categories)
        entry.parents=self:parents(entry.categories)
        entry.tags=self:tags(entry.tags)
        if entry.preferred~=nil then plain(entry.preferred,120) end
        if entry.icon~=nil then plain(entry.icon,16) end
        if entry.categories[1]=='other' then
            assert(entry.reason=='specialized' or entry.reason=='insufficient_evidence'
                or entry.reason=='ambiguous','other requires a classification reason')
        end
        return entry
    end
    function T:index(index)
        assert(index.schema_version==2 and index.taxonomy_version==data.version
            and type(index.modules)=='table','unsupported module index')
        for folder,entry in pairs(index.modules) do
            plain(folder,255)
            assert(not folder:find('[/\\]') and folder~='.' and folder~='..','invalid index folder')
            self:entry(entry)
        end
        return index
    end
    function T:matches(entry,filter,isTag)
        if not filter or not filter.values or #filter.values==0 then return true end
        assert(filter.mode==nil or filter.mode=='any' or filter.mode=='all','invalid filter mode')
        local requested=isTag and self:tags(filter.values) or self:categories(filter.values)
        local present={}
        for _,id in ipairs(entry.categories or {}) do present[id]=true end
        for _,id in ipairs(entry.parents or {}) do present[id]=true end
        if isTag then present={};for _,id in ipairs(entry.tags or {}) do present[id]=true end end
        for _,id in ipairs(requested) do
            if filter.mode=='all' and not present[id] then return false end
            if filter.mode~='all' and present[id] then return true end
        end
        return filter.mode=='all'
    end
    return T
end
return M
