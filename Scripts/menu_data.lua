-- Compiles a contributed page's menu data into the settings manifest DMM parses. Menu data
-- describes a page without DMM's vocabulary, so contributors never write manifests:
--
-- {storage={file='config.ini',section='Settings'},    -- optional; file is relative to the
--                                                      -- page's configDirectory
--  groups={{id=,label=,heading=false,level=,visible=,relabel=},...},
--  fields={{id=,group=,label=,description=,default=,
--      choices={{value=,label=,note=,module=},...} | range={min=,max=,step=,suffix=},
--      tabs=true,level=,visible=,relabel=,action=true,link=,readOnly=true},...}}
--
-- Groups and fields keep their declared order. A group's heading is its label (its id when
-- absent). visible={field=,values={...}} shows a row or group only while that picker holds
-- one of the values; relabel={field=,values={[value]='text'}} names it after that picker's
-- value. A choice's note is shown under it; module=<mod folder> notes that mod's name.
-- level 1 puts a picker in the page title row (one per page); 0 and 2-6 set the text size.
-- action rows are navigation and are never stored; link=<page id or provider:slot> opens
-- that page. A single choice makes a button or, read-only, a shown value. Errors raise
-- with the offending id.
local M={version=1}

local MAX_FIELDS,MAX_GROUPS,MAX_CHOICES=256,256,64

local function text(value,where,limit)
    assert(type(value)=='string' and value~='' and #value<=(limit or 4096)
        and not value:find('[%c|;%[%]]') and not value:match('^%s') and not value:match('%s$'),
        'invalid '..where)
    return value
end
local function identifier(value,where)
    assert(type(value)=='string' and #value<=128 and value:match('^[%w_.:-]+$'),'invalid '..where)
    return value
end
local function number(value,where)
    assert(type(value)=='number' and value==value and math.abs(value)<=1000000000,'invalid '..where)
    return value
end
local function format(value)
    return math.type(value)=='integer' and tostring(value)
        or value%1==0 and string.format('%d',value) or string.format('%.17g',value)
end
local function allowed(value,keys,where)
    assert(type(value)=='table','invalid '..where)
    for key in pairs(value) do assert(keys[key],where..': unknown field '..tostring(key)) end
end
local function list(value,where,limit)
    assert(type(value)=='table' and #value<=limit,'invalid '..where)
    for key in pairs(value) do
        assert(math.type(key)=='integer' and key>=1 and key<=#value,where..' must be a list')
    end
    return value
end

-- options.moduleName(folder) (optional) names a mod folder for choice notes.
function M.manifest(menu,options)
    options=options or {}
    allowed(menu,{storage=true,groups=true,fields=true},'menu')
    local storage=menu.storage
    if storage~=nil then
        allowed(storage,{file=true,section=true},'menu storage')
        text(storage.file,'storage file',1024)
        assert(not storage.file:match('^[/\\]') and not storage.file:match('^%a:')
            and not storage.file:find('%.%.'),'storage file must be relative to configDirectory')
        identifier(storage.section,'storage section')
    end
    local groups,byGroup={},{}
    for n,group in ipairs(list(menu.groups or {},'menu groups',MAX_GROUPS)) do
        local where='group '..n
        allowed(group,{id=true,label=true,heading=true,level=true,visible=true,relabel=true},where)
        text(group.id,where..' id',128)
        assert(not byGroup[group.id],'duplicate group '..group.id)
        if group.label~=nil then text(group.label,group.id..' label') end
        assert(group.heading==nil or type(group.heading)=='boolean',group.id..': invalid heading')
        groups[n],byGroup[group.id]=group,{used=false}
    end
    local fields,byField,titles={},{},0
    for n,field in ipairs(list(menu.fields or {},'menu fields',MAX_FIELDS)) do
        local where='field '..n
        allowed(field,{id=true,group=true,label=true,description=true,default=true,choices=true,range=true,
            tabs=true,level=true,visible=true,relabel=true,action=true,link=true,readOnly=true},where)
        identifier(field.id,where..' id')
        assert(not byField[field.id],'duplicate field '..field.id)
        where=field.id
        assert(byGroup[field.group],where..': unknown group '..tostring(field.group))
        byGroup[field.group].used=true
        text(field.label,where..' label')
        if field.description~=nil then
            assert(type(field.description)=='string' and #field.description<=4096
                and not field.description:find('%c'),where..': invalid description')
        end
        assert((field.choices==nil)~=(field.range==nil),where..': needs choices or range')
        for _,flag in ipairs({'tabs','action','readOnly'}) do
            assert(field[flag]==nil or type(field[flag])=='boolean',where..': invalid '..flag)
        end
        if field.link~=nil then text(field.link,where..' link',256) end
        local values={}
        if field.choices then
            list(field.choices,where..' choices',MAX_CHOICES)
            assert(#field.choices>=1,where..': needs a choice')
            assert(not field.tabs or #field.choices<=8,where..': tabs take at most eight choices')
            for c,choice in ipairs(field.choices) do
                allowed(choice,{value=true,label=true,note=true,module=true},where..' choice '..c)
                number(choice.value,where..' choice value')
                assert(not values[choice.value],where..': duplicate choice value')
                text(choice.label,where..' choice label')
                assert(choice.note==nil or choice.module==nil,where..': a choice has a note or a module')
                if choice.note~=nil then text(choice.note,where..' choice note',64) end
                if choice.module~=nil then text(choice.module,where..' choice module',255) end
                values[choice.value]=true
            end
        else
            allowed(field.range,{min=true,max=true,step=true,suffix=true},where..' range')
            local range=field.range
            for _,key in ipairs({'min','max','step'}) do
                if key~='step' or range.step~=nil then
                    assert(number(range[key],where..' range '..key)%1==0,where..': range '..key..' must be whole')
                end
            end
            assert(range.min<range.max and (range.step==nil or range.step>=1 and range.step<=range.max-range.min),
                where..': invalid range')
            if range.suffix~=nil then text(range.suffix,where..' suffix',16) end
            assert(not field.tabs,where..': tabs need choices')
        end
        number(field.default,where..' default')
        if field.choices then assert(values[field.default],where..': default is not a choice')
        else assert(field.default>=field.range.min and field.default<=field.range.max
            and field.default%1==0,where..': default outside range') end
        if field.level~=nil then
            assert(math.type(field.level)=='integer' and field.level>=0 and field.level<=6,where..': invalid level')
            assert(field.level~=1 or field.choices,where..': level 1 needs choices')
            if field.level==1 then titles=titles+1 end
        end
        assert(not field.link or field.choices,where..': a link needs choices')
        assert(not field.readOnly or field.choices and not field.action and not field.link,
            where..': a read-only row needs choices and no action')
        fields[n],byField[field.id]=field,values
    end
    assert(titles<=1,'only one level-1 field per page')
    for _,group in ipairs(groups) do
        if group.level~=nil then
            assert(math.type(group.level)=='integer' and group.level>=0 and group.level<=6,group.id..': invalid level')
        end
    end
    -- A rule's source is a picker on this page; its values must be that picker's choices.
    local function rule(value,where,map)
        allowed(value,{field=true,values=true},where)
        local source=byField[value.field]
        assert(source and next(source),where..': source must be a picker on this page')
        local out={}
        if map then
            assert(type(value.values)=='table','invalid '..where..' values')
            for choice,label in pairs(value.values) do
                assert(source[choice],where..': value outside the source choices')
                out[#out+1]={choice,text(label,where..' text')}
            end
            table.sort(out,function(a,b) return a[1]<b[1] end)
            assert(#out>0,where..': needs a value')
        else
            for _,choice in ipairs(list(value.values,where..' values',MAX_CHOICES)) do
                assert(source[choice],where..': value outside the source choices')
                out[#out+1]=format(choice)
            end
            assert(#out>0,where..': needs a value')
        end
        return value.field,out
    end
    local lines={}
    local function section(name,keys)
        lines[#lines+1]='['..name..']'
        for _,pair in ipairs(keys) do
            if pair[2]~=nil then lines[#lines+1]=pair[1]..'='..tostring(pair[2]) end
        end
        lines[#lines+1]=''
    end
    local function visible(value,where)
        if value==nil then return nil,nil end
        local source,values=rule(value,where..' visible')
        return source,table.concat(values,'|')
    end
    local function relabel(value,where)
        if value==nil then return nil,nil end
        local source,pairs=rule(value,where..' relabel',true)
        local out={}
        for n,pair in ipairs(pairs) do out[n]=format(pair[1])..':'..pair[2] end
        return source,table.concat(out,';')
    end
    for _,group in ipairs(groups) do
        if byGroup[group.id].used then
            local when,values=visible(group.visible,group.id)
            local labelWhen,labels=relabel(group.relabel,group.id)
            section('Category.'..group.id,{{'mcLabel',group.label~=nil and group.label~=group.id and group.label or nil},
                {'mcHeading',group.heading==false and 0 or nil},{'mcLevel',group.level},
                {'VisibleWhen',when},{'VisibleValues',values},{'mcLabelWhen',labelWhen},{'mcLabels',labels}})
        end
    end
    for _,field in ipairs(fields) do
        local keys={{'Id',field.id},{'Label',field.label},{'Group',field.group},
            {'Description',field.description}}
        local function add(key,value) keys[#keys+1]={key,value} end
        if field.choices then
            local values,labels,notes={}, {}, {}
            for n,choice in ipairs(field.choices) do
                values[n],labels[n]=format(choice.value),choice.label
                local note=choice.note
                if choice.module then
                    note=options.moduleName and options.moduleName(choice.module) or choice.module
                    note=type(note)=='string' and note:gsub('[%c|;%[%]]',' '):sub(1,64):match('^%s*(.-)%s*$') or ''
                    if note=='' then note=nil end
                end
                if note then notes[#notes+1]=values[n]..':'..note end
            end
            -- DMM needs two choices; a single one (a button or read-only value) repeats.
            if #values==1 then
                values[2],labels[2]=format(field.choices[1].value+1),labels[1]
            end
            add('Type','picker');add('PresetValues',table.concat(values,'|'))
            add('PresetLabels',table.concat(labels,'|'))
            add('mcChoiceNotes',#notes>0 and table.concat(notes,';') or nil)
            add('mcType',field.tabs and 'tab' or nil)
        else
            add('Type','integer');add('Minimum',format(field.range.min));add('Maximum',format(field.range.max))
            add('Step',field.range.step and format(field.range.step) or nil);add('Suffix',field.range.suffix)
        end
        add('Default',format(field.default))
        if field.level==1 then add('mcHeading',1) else add('mcLevel',field.level) end
        local when,values=visible(field.visible,field.id)
        add('VisibleWhen',when);add('VisibleValues',values)
        local labelWhen,labels=relabel(field.relabel,field.id)
        add('mcLabelWhen',labelWhen);add('mcLabels',labels)
        if field.action or field.link then add('mcNavigation',1) end
        add('mcLinkPage',field.link)
        add('mcReadOnly',field.readOnly and 1 or nil)
        if storage and not (field.action or field.link or field.readOnly) then
            add('ConfigFile',storage.file);add('ConfigSection',storage.section);add('ConfigKey',field.id)
        end
        section('Setting.'..field.id,keys)
    end
    local manifest=table.concat(lines,'\n')
    assert(#manifest<=256*1024,'menu exceeds 256 KiB')
    return manifest
end

return M
