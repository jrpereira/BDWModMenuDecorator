-- MCS-owned module index. Inspected metadata and scripts are never executed.
local Text=require('mcs_fingerprint_text')
local Json=require('mcs_module_json')
local Metadata=require('mcs_mod_metadata')
local Taxonomy=require('mcs_taxonomy').new(require('mcs_taxonomy_data'))
local M={OTHER='other'}

local function safe(path)
    if type(path)~='string' or path=='' or path:find('[%z\r\n]') then return false end
    path=path:gsub('\\','/')
    if path:match('^/') or path:find(':',1,true) then return false end
    for part in (path..'/'):gmatch('(.-)/') do
        local lower=part:lower()
        if part=='' or part=='.' or part=='..' or lower:find('backup',1,true)
            or lower:find('continuity',1,true) or lower:find('audit',1,true)
            or lower:find('archive',1,true) or lower:match('%.bak$') or lower:find('%.bak%.') then return false end
    end
    return true
end
M.safePath=safe

local function quote(s)
    return '"'..s:gsub('[%z\1-\31\\"]',function(c)
        return ({['"']='\\"',['\\']='\\\\',['\b']='\\b',['\f']='\\f',['\n']='\\n',['\r']='\\r',['\t']='\\t'})[c]
            or string.format('\\u%04x',c:byte())
    end)..'"'
end
M.quote=quote
local function key(kind,values)
    local seen,list={},{}
    for _,value in ipairs(values) do
        value=Text.normalize(value)
        if not seen[value] then seen[value]=true;list[#list+1]=value end
    end
    table.sort(list)
    local encoded={}
    for i,value in ipairs(list) do encoded[i]=quote(value) end
    return '['..quote(kind)..',['..table.concat(encoded,',')..']]',list
end
M.key=key
local function modLink(value)
    if type(value)~='string' then return nil end
    value=Text.normalize(value)
    local game,id,suffix=value:match('^https?://www%.nexusmods%.com/([%w_%-]+)/mods/(%d+)(.*)$')
    if not game then game,id,suffix=value:match('^https?://nexusmods%.com/([%w_%-]+)/mods/(%d+)(.*)$') end
    if game and (suffix=='' or suffix:match('^[/?#]')) then
        return 'https://www.nexusmods.com/'..game..'/mods/'..tonumber(id)
    end
    return value~='' and value or nil
end
M.modLink=modLink

function M.read(path)
    local file,err,code=io.open(path,'rb')
    if not file then if code==2 then return nil end;error(err or ('cannot read '..path)) end
    local text,why=file:read(1048577)
    local closed,closeWhy=file:close()
    assert(closed,closeWhy);assert(text or not why,why)
    text=text or '';assert(#text<=1048576,'file exceeds 1 MiB: '..path)
    return text
end
function M.write(path,text)
    local temporary=path..'.tmp'
    local file=assert(io.open(temporary,'wb'))
    local ok,err=file:write(text);local closed,why=file:close()
    assert(ok and closed,err or why)
    local renamed,renameError=os.rename(temporary,path)
    if not renamed and package.config:sub(1,1)=='\\' then
        -- Windows' C rename may refuse replacement. Readers retain their last
        -- good snapshot during this short gap; this generated index is rebuildable.
        assert(os.remove(path),renameError)
        renamed,renameError=os.rename(temporary,path)
    end
    assert(renamed,renameError)
end

-- listFiles supplies relative paths, or {relative_path=...} records. This keeps
-- discovery separate from calculation and allows an existing directory snapshot.
function M.tokens(folder,files,read,options)
    options=options or {};read=read or M.read
    local tokens,singleMemo={},{}
    local function add(kind,values)
        if #values==1 then
            local memo=kind..'\0'..values[1]
            if singleMemo[memo] then return end
            singleMemo[memo]=true
        end
        local encoded,normalized=key(kind,values)
        tokens[encoded]={kind=kind,values=normalized}
    end
    if not options.ignoreFolderName and not options.packageStem then
        local basename=assert(folder:gsub('[/\\]+$',''):match('([^/\\]+)$'))
        add('directory-basename-v1',{basename});add('name-anchor-v1',{Text.anchor(basename)})
    end
    local excluded={['dmm_api.lua']=true,['UE4SSDawnwalkerSettings.lua']=true,
        ['SettingsStore.lua']=true,['SettingsUpgrade.lua']=true}
    for _,entry in ipairs(files) do
        local path=type(entry)=='table' and entry.relative_path or entry
        if safe(path) and not (type(entry)=='table' and entry.is_symlink) then
            local name=path:match('([^/\\]+)$');local stem,ext=name:match('^(.*)(%.[^.]*)$')
            ext=ext and ext:lower()
            if not options.packageStem or stem==options.packageStem then
                if name:lower()=='mod.json' or name:lower()=='mod.txt' then
                    local manifest=options.manifest or (name:lower()=='mod.txt' and Metadata.decode(assert(read(folder..'/'..path))) or Json.decode(assert(read(folder..'/'..path))))
                    if type(manifest.author)=='string' then add('author-v1',{manifest.author}) end
                    local links=type(manifest.links)=='table' and manifest.links or {}
                    for _,value in pairs({manifest.modURL,manifest.modUrl,manifest.nexus,links.nexus,links.mod}) do
                        local link=modLink(value);if link then add('mod-link-v1',{link}) end
                    end
                end
                if ext=='.pak' or ext=='.ucas' or ext=='.utoc' or ext=='.dll' or ext=='.lua' or ext=='.ini' then
                    add('file-basename-v1',{name})
                end
                if ext=='.pak' or ext=='.ucas' or ext=='.utoc' or ext=='.dll' then
                    add('name-anchor-v1',{Text.anchor(stem:gsub('_[pP]$',''):gsub('^[zZ][zZ]+_',''))})
                end
                if ext=='.ini' or ext=='.lua' and not excluded[name] then
                    local content=assert(read(folder..'/'..path),'unreadable mod file: '..path):gsub('^\239\187\191','')
                    assert(utf8.len(content),'invalid mod file UTF-8: '..path)
                    if name:lower()=='mod_settings.ini' then
                        local section=''
                        for line in (content..'\n'):gmatch('([^\n]*)\n') do
                            section=line:match('^%s*%[([^%]]+)%]%s*$') or section
                            local field,value=line:match('^%s*([%w_]+)%s*=%s*(.-)%s*$')
                            if section=='Mod' and field=='Author' and value~='' then add('author-v1',{value})
                            elseif section=='Mod' and (field=='ModURL' or field=='ModUrl') then
                                local link=modLink(value);if link then add('mod-link-v1',{link}) end
                            elseif field=='Label' then add('settings-label-v1',{value})
                            elseif field=='PresetLabels' or field=='Options' or field=='ChoiceLabels' then
                                local choices={};for v in (value..'|'):gmatch('(.-)|') do choices[#choices+1]=v end
                                if #choices>1 then add('settings-choice-set-v1',choices) end
                            end
                        end
                    elseif ext=='.lua' then
                        content=content:gsub('https?://%S+','')
                        -- Identifier presence is a clue, including comments/string literals.
                        local index=1
                        while true do
                            local first,last=content:find('[A-Za-z_0-9]+',index)
                            if not first then break end
                            local word=content:sub(first,last)
                            local before=first>1 and utf8.offset(content,-1,first) or nil
                            local left=before and utf8.codepoint(content,before) or nil
                            local right=last<#content and utf8.codepoint(content,last+1) or nil
                            if word:match('^[A-Za-z_]') and not (left and (left==95 or Text.isAlnum(left)))
                                and not (right and (right==95 or Text.isAlnum(right))) then add('lua-identifier-v1',{word}) end
                            index=last+1
                        end
                    end
                end
            end
        end
    end
    return tokens
end

-- All signals within a group are required; groups are alternatives. Competing
-- best matches with different categories leave the folder in Other or Specialized.
function M.match(tokens,database)
    local best,categories,matched=0,{},{}
    for _,module in ipairs(database.modules) do
        local groups={};local authorMatch=false;local hasLocalAuthor=false
        for _,token in pairs(tokens) do if type(token)=='table' and token.kind=='author-v1' then hasLocalAuthor=true;break end end
        for _,fingerprint in ipairs(module.fingerprints) do
            if fingerprint.kind=='author-v1' and tokens[key(fingerprint.kind,fingerprint.values)] then authorMatch=true end
            local group=groups[fingerprint.group] or {matches=true,any=false,rank=1}
            groups[fingerprint.group]=group
            local present=tokens[key(fingerprint.kind,fingerprint.values)]~=nil
            group.matches=group.matches and present;group.any=group.any or present
            if fingerprint.strength=='structural_candidate' then group.rank=2 end
            if fingerprint.strength=='identity_link' then group.rank=4 end
        end
        local rank=0
        for name,group in pairs(groups) do
            if name~='author' and (group.matches or authorMatch and group.any and group.rank<4) then
                rank=math.max(rank,group.rank)
            end
        end
        if rank>0 and rank<4 then
            if hasLocalAuthor and not authorMatch then rank=0
            elseif authorMatch then rank=3 end
        end
        if rank>0 then
            if rank>best then best=rank;categories={};matched={} end
            if rank==best then
                local definition=assert(database.categories[module.category],'invalid database category')
                local category=type(definition)=='table' and definition.id or definition
                categories[category]=true;matched[#matched+1]=module.id or module.name
            end
        end
    end
    local category
    for name in pairs(categories) do if category then return M.OTHER,matched,'ambiguous' end;category=name end
    return category or M.OTHER,matched,category and 'matched' or 'unmatched'
end

local function emptyIndex()
    return {schema_version=2,taxonomy_version=Taxonomy.data.version,modules={}}
end
function M.encode(index) return Json.encode(Taxonomy:index(index))..'\n' end
function M.decode(text)
    local index=Json.decode(text)
    if index.schema_version==nil then
        -- Old single-category entries are reclassified; no category aliases.
        local preferred={}
        for folder,entry in pairs(index) do
            assert(safe(folder) and not folder:find('[/\\]') and type(entry)=='table','invalid legacy index')
            if entry.preferred~=nil then
                assert(type(entry.preferred)=='string' and #entry.preferred<=120
                    and not entry.preferred:find('%c'),'invalid preferred group')
                preferred[folder]=entry.preferred
            end
        end
        return emptyIndex(),preferred
    end
    return Taxonomy:index(index)
end
local function classify(folder,files,read,database,legacyPreferred)
    local manifest,origin=Metadata.read(folder,read)
    local browser=manifest.browser
    assert(browser==nil or type(browser)=='table' and browser~=Json.null,'invalid browser metadata')
    browser=browser or {}
    local preferred=browser.preferred
    if preferred==nil then preferred=manifest.mcCategory or legacyPreferred end
    if preferred=='author' then
        assert(type(manifest.author)=='string' and manifest.author~='','preferred author requires metadata author')
        preferred=manifest.author
    end
    local icon=browser.icon
    if type(icon)=='table' then icon=icon.utf8 end
    local entry={tags=Taxonomy:tags(browser.tags),preferred=preferred,icon=icon}
    -- Obsolete category labels are not aliases for the new taxonomy.
    local selections=browser.categories
    if selections==nil and Taxonomy.definitions[manifest.category] then selections={manifest.category} end
    if selections~=nil then
        assert(selections~=Json.null,'invalid category selections')
        local declared=Taxonomy:categories(selections)
        if next(selections)~=nil then
            entry.categories=declared
            entry.source=origin;entry.confidence='declared'
            entry.reason=entry.categories[1]=='other' and 'specialized' or nil
            return Taxonomy:entry(entry)
        end
    end
    local tokens=M.tokens(folder,files,read,{manifest=manifest})
    local _,ids,status=M.match(tokens,database)
    entry.identity={ids=ids,status=status}
    -- Identity clues do not establish a category. Use only reviewed catalog selections.
    if #ids==1 then
        for _,module in ipairs(database.modules) do
            if module.id==ids[1] and module.categories and module.categories[1]~='other' then
                entry.categories=Taxonomy:categories(module.categories)
                entry.source='catalog';entry.confidence='reviewed';return Taxonomy:entry(entry)
            end
        end
    end
    local prediction=require('mcs_module_patterns').scan(folder,files,read)
    entry.evidence=prediction.evidence
    entry.source='heuristic';entry.categories=prediction.categories or {'other'}
    entry.reason=entry.categories[1]=='other' and (prediction.reason=='ambiguous' and 'ambiguous' or 'insufficient_evidence') or nil
    entry.confidence=entry.reason and 'abstained' or 'tentative'
    return Taxonomy:entry(entry)
end
-- Successful entries are cached. Malformed declarations stay retryable.
function M.update(options)
    local read,write=options.read or M.read,options.write or M.write
    local text=read(options.path)
    local index,preferred
    if text then index,preferred=M.decode(text) else index=emptyIndex() end
    local changed=not text or preferred~=nil
    for _,folder in ipairs(options.folders) do
        if safe(folder.name) and not folder.name:find('[/\\]') and not index.modules[folder.name] then
            local ok,entry=pcall(classify,folder.path,folder.files,read,options.database,
                preferred and preferred[folder.name])
            if ok then index.modules[folder.name]=entry;changed=true
            elseif options.report then options.report(folder.name,tostring(entry)) end
        end
    end
    if changed then write(options.path,M.encode(index)) end
    return index
end

local function canonical(path) return path:gsub('\\','/'):gsub('/+$',''):lower() end
-- UE4SS supplies a directory snapshot with __absolute_path and __files.
function M.folders(snapshot,mods,registered)
    local wanted=canonical(mods);local found,visited=nil,0
    local function locate(node,depth)
        if type(node)~='table' or depth>64 then return end
        visited=visited+1;assert(visited<=32768,'directory snapshot traversal limit')
        if type(node.__absolute_path)=='string' then
            local absolute=canonical(node.__absolute_path)
            if absolute==wanted then found=node;return end
            if wanted:sub(1,#absolute+1)~=absolute..'/' then return end
        end
        for name,child in pairs(node) do
            if not found and type(name)=='string' and name:sub(1,2)~='__' and safe(name) then locate(child,depth+1) end
        end
    end
    locate(snapshot,0);assert(found,'active Mods directory missing from snapshot')
    local folders={}
    for name,node in pairs(found) do
        if type(name)=='string' and name:sub(1,2)~='__' and safe(name) and type(node)=='table' then
            local files={};local root=mods..'/'..name;local count=0
            local function collect(current,prefix,depth)
                assert(depth<=64,'module directory depth limit')
                for _,file in pairs(current.__files or {}) do
                    if type(file)=='table' and type(file.__name)=='string' then
                        local relative=prefix..file.__name
                        if safe(relative) then files[#files+1]=relative end
                    end
                end
                for key,child in pairs(current) do
                    if type(key)=='string' and key:sub(1,2)~='__' and safe(key) and type(child)=='table' then
                        count=count+1;assert(count<=32768,'module directory traversal limit')
                        collect(child,prefix..key..'/',depth+1)
                    end
                end
            end
            if registered and registered[name] then
                folders[#folders+1]={name=name,path=root,files={}}
            else
            collect(node,'',0)
            if #files>0 and (node.Scripts or node.scripts or node.dlls) then
                table.sort(files);folders[#folders+1]={name=name,path=root,files=files}
            else
                for _,file in ipairs(files) do
                    if file:lower()=='mod.json' or file:lower()=='mod.txt' then folders[#folders+1]={name=name,path=root,files=files};break end
                end
            end
            end
        end
    end
    table.sort(folders,function(a,b) return a.name<b.name end)
    return folders
end
local function mkdir(path)
    local command
    if package.config:sub(1,1)=='\\' then
        assert(not path:find('["%%!\r\n]'),'unsupported cache directory path')
        path=path:gsub('/', '\\')
        command='if not exist "'..path..'" mkdir "'..path..'"'
    else
        command="mkdir -p -- '"..path:gsub("'", "'\\''").."'"
    end
    local ok=os.execute(command)
    assert(ok==true or ok==0,'cannot create module cache: '..path)
end
function M.boot(root,mods,iterator,options)
    options=options or {}
    assert(type(root)=='string' and root~='','MCS root unavailable')
    assert(type(iterator)=='function','IterateGameDirectories unavailable')
    local cache=root:gsub('[/\\]+$','')..'/cache'
    (options.mkdir or mkdir)(cache)
    local path=cache..'/modules_register.json'
    local read,write=options.read or M.read,options.write or M.write
    local text=read(path)
    local index=text and M.decode(text) or emptyIndex()
    return M.update({path=path,folders=M.folders(iterator(),mods,index.modules),
        read=read,write=write,database=options.database or require('mod_fingerprints'),
        report=options.report})
end
return M
