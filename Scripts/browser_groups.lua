-- Arrange ModCore providers as a browser tree before DMM builds its rows.
local M = {}
local ROOT_ID = 'ModCore.browser.root'

-- Every foundation module is listed; one without a page to open shows as having no settings.
local FOUNDATION = {
    {id='ModCoreControls', name='ModCore Controls'},
    {id='ModCoreSettings', name='ModCore Settings'},
    {id='ModCoreTemplates', name='ModCore Templates'},
    {id='ModCoreDevelopers', name='ModCore Dev Tools'},
    {id='UE4SSLuaEventBridge', name='Lua Event Bridge'},
}

-- The pages listed beside the ModCore entry in the browser, in order, with their short
-- labels. A module page shows its own icon (mcBrowserIcon) before its name.
local CORE = {
    {id='ModCoreTemplates', label='⌗  Templates'},
    {id='ModCoreControls', label='❖  Controls'},
    {id='ModCoreSettings', label='☑  Settings'},
}

local GROUP_PREFIX = 'ModCore.browser.group.'
local VARIOUS = 'Various Authors'

local function heading(id, name, level, indent, description)
    return {id=id, name=name, author='ModCore', version='',
        description=description or name .. ' groups related ModCore pages.',
        choices={}, settingsCount=0, testOnly=false, noSettings=true, mcBrowserHeading=true,
        mcBrowserLevel=level, mcBrowserIndent=indent}
end

-- The ModCore page: a Modules tab linking to each module's page, an Errors tab, and a
-- Developer Tools tab.
-- Every row is navigation, so the page owns no config file. openable[id] marks the pages
-- a link can open, or names the slot a link page opens; versions[id] (optional) is shown
-- after a module's name.
-- tools lists the developer tool pages (group='tool'), which open only from here.
function M.manifest(openable, modules, versions, tools)
    versions = versions or {}
    local lines = {}
    local function block(section, fields)
        lines[#lines + 1] = '[' .. section .. ']'
        for _, field in ipairs(fields) do lines[#lines + 1] = field[1] .. '=' .. tostring(field[2]) end
        lines[#lines + 1] = ''
    end
    local function label(text) return (tostring(text):gsub('[|;%c]', ' ')) end
    block('Mod', {{'Id', ROOT_ID}, {'Name', 'ModCore'}})
    block('Category.Pages', {{'mcHeading', 0}})
    block('Setting.ModCore_Page', {{'Id', 'ModCore_Page'}, {'Label', 'Page'}, {'Group', 'Pages'},
        {'Type', 'picker'}, {'Default', 0}, {'PresetValues', '0|1|2'},
        {'PresetLabels', 'Modules|Errors|Developer Tools'}, {'mcNavigation', 1}, {'mcHeading', 'true'}})
    local count = 0
    local function section(group, list, tab)
        if #list == 0 then return end
        -- A tab of its own (tab, the Page value) needs no heading repeating the tab's name.
        local fields = {{'VisibleWhen', 'ModCore_Page'}, {'VisibleValues', tab or 0}}
        if tab then fields[3] = {'mcHeading', 0} end
        block('Category.' .. group, fields)
        for _, entry in ipairs(list) do
            count = count + 1
            local id = 'ModCore_Module_' .. count
            local version = versions[entry.id]
            local name = version and entry.name .. ' v' .. version or entry.name
            local fields = {{'Id', id}, {'Label', label(name)}, {'Group', group},
                {'Type', 'picker'}, {'Default', 0}, {'PresetValues', '0|1'}}
            if openable[entry.id] then
                for _, field in ipairs({{'PresetLabels', 'Open|Open'}, {'mcNavigation', 1}, {'mcType', 'tab'},
                    {'mcLinkPage', type(openable[entry.id]) == 'string' and openable[entry.id] or entry.id}}) do
                    fields[#fields + 1] = field
                end
            else
                for _, field in ipairs({{'PresetLabels', 'No settings|No settings'}, {'mcReadOnly', 1}, {'mcType', 'tab'}}) do
                    fields[#fields + 1] = field
                end
            end
            block('Setting.' .. id, fields)
        end
    end
    local user, foundation = {}, {}
    for _, provider in ipairs(modules) do user[#user + 1] = {id=provider.id, name=provider.name} end
    for _, entry in ipairs(FOUNDATION) do foundation[#foundation + 1] = entry end
    section('User Modules', user)
    section('Foundation Modules', foundation)
    -- The latest error lines of UE4SS.log, newest at the bottom (the host's 'errors' source).
    block('Category.Errors', {{'VisibleWhen', 'ModCore_Page'}, {'VisibleValues', 1}, {'mcHeading', 0}})
    block('Setting.ModCore_Errors', {{'Id', 'ModCore_Errors'}, {'Label', 'Errors'}, {'Group', 'Errors'},
        {'Type', 'picker'}, {'Default', 0}, {'PresetValues', '0|1'}, {'PresetLabels', 'Errors|Errors'},
        {'mcReadOnly', 1}, {'mcText', 'errors'}})
    local listed = {}
    for _, provider in ipairs(tools or {}) do listed[#listed + 1] = {id=provider.id, name=provider.name} end
    if #listed > 0 then section('Developer Tools', listed, 2)
    else
        block('Category.Developer Tools', {{'VisibleWhen', 'ModCore_Page'}, {'VisibleValues', 2}, {'mcHeading', 0}})
        block('Setting.ModCore_NoTools', {{'Id', 'ModCore_NoTools'}, {'Label', 'Developer Tools'},
            {'Group', 'Developer Tools'}, {'Type', 'picker'}, {'Default', 0}, {'PresetValues', '0|1'},
            {'PresetLabels', 'None installed|None installed'}, {'mcReadOnly', 1}, {'mcType', 'tab'}})
    end
    return table.concat(lines, '\n')
end

-- parse(manifest) (optional) turns the ModCore heading into its page; without it, or if the
-- page cannot be built, the heading stays a plain group heading.
-- A module's version: its listed page's, else its contributed page's (pageVersions, hidden
-- pages included), else read by folderVersion(folder) from the folder of the detected mod
-- whose folder name ends with the module id.
function M.versions(ids, providers, pageVersions, folderVersion)
    local function clean(value)
        if type(value) ~= 'string' then return nil end
        value = value:match('^%s*[vV]?(%d[%w%.%-%+]*)%s*$')
        return value and #value <= 32 and value or nil
    end
    local byId = {}
    for _, provider in ipairs(providers) do byId[provider.id] = provider end
    local result = {}
    for _, id in ipairs(ids) do
        local version = clean(byId[id] and byId[id].version) or clean((pageVersions or {})[id])
        if not version and folderVersion then
            local suffix = id:lower()
            for _, provider in ipairs(providers) do
                local folder = provider.detectedKind == 'ue4ss' and tostring(provider.mcFolder or provider.name or '') or ''
                if folder:lower():sub(-#suffix) == suffix then
                    local ok, value = pcall(folderVersion, folder)
                    version = ok and clean(value) or nil
                    break
                end
            end
        end
        result[id] = version
    end
    return result
end

-- A reader for a mod folder's version under mods (the Mods folder, ending in a separator):
-- its VERSION file, else the version in a native mod's dlls/main.json. open defaults to io.open.
function M.folderVersion(mods, open)
    if type(mods) ~= 'string' then return nil end
    open = open or io.open
    local function read(path)
        local file = open(path, 'rb')
        if not file then return nil end
        local content = file:read(4096)
        file:close()
        return content
    end
    return function(folder)
        assert(not folder:find('[/\\]') and folder ~= '..' and folder ~= '.', 'invalid mod folder')
        local version = read(mods .. folder .. '/VERSION')
        if version then return version:match('^%s*(.-)%s*$') end
        local json = read(mods .. folder .. '/dlls/main.json')
        return json and json:match('"version"%s*:%s*"([^"]+)"')
    end
end

-- A reader for a mod folder's mod.json fields under mods (the Mods folder, ending in a
-- separator): group, its browser group; settings, false when the mod has none to show; and
-- name, author, version and description, read before any dependencies list.
-- open defaults to io.open.
function M.folderManifest(mods, open)
    if type(mods) ~= 'string' then return nil end
    open = open or io.open
    return function(folder)
        assert(type(folder) == 'string' and not folder:find('[/\\]') and folder ~= '..' and folder ~= '.',
            'invalid mod folder')
        local file = open(mods .. folder .. '/mod.json', 'rb')
        if not file then return {} end
        local json = file:read(65536) or ''
        file:close()
        local top = json:match('^(.-)"dependencies"') or json
        local function text(key, limit)
            local value = top:match('"' .. key .. '"%s*:%s*"([^"\\%c]+)"')
            return value and #value <= limit and value or nil
        end
        local fields = {group=text('group', 64), name=text('name', 200), author=text('author', 120),
            version=text('version', 64), description=text('description', 4096)}
        if json:match('"settings"%s*:%s*false') then fields.settings = false end
        return fields
    end
end

local function root(openable, modules, tools, parse, report, versions)
    if parse then
        local ok, result = pcall(function()
            local manifest = M.manifest(openable, modules, versions, tools)
            local choices = parse(manifest)
            return {id=ROOT_ID, name='ModCore', author='ModCore', version='',
                description='ModCore modules and developer tools.',
                authorURL='', modURL='', logoFile='', logoAsset='', testOnly=false,
                choices=choices, settingsCount=#choices, choicesLoaded=true, deferred=false,
                mcManifest=manifest, mcBrowserLevel=2, mcBrowserIndent=0}
        end)
        if ok then return result end
        if report then report('BROWSER_ROOT_FAILED', result) end
    end
    return heading(ROOT_ID, 'ModCore', 2, 0)
end

local function trimmed(value)
    value = type(value) == 'string' and value:match('^%s*(.-)%s*$') or ''
    return value ~= '' and value or nil
end

-- The folder a provider's mod lives in: a contributed page's attach folder, a detected
-- UE4SS folder's name, or the folder holding its settings manifest.
local function folderOf(provider)
    if provider.mcFolder then return provider.mcFolder end
    if provider.detectedKind == 'ue4ss' then return provider.name end
    local path = type(provider.path) == 'string' and provider.path:gsub('\\', '/') or nil
    return path and path:match('([^/]+)/[^/]+$')
end

-- Every page is listed in a group: ModCore first, then each group of several mods (its
-- mod.json group, else its author) in name order, then Various Authors, one mod per row.
-- options.pageVersions and options.folderVersion (optional): see M.versions.
-- options.folderManifest(folder) (optional): see M.folderManifest.
function M.arrange(providers, parse, report, options)
    options = options or {}
    local corePages, modules, tools, others = {}, {}, {}, {}
    local seen, core = {}, {}
    for _, entry in ipairs(CORE) do core[entry.id] = true end
    local children, contributions = {}, {}
    for _, provider in ipairs(providers) do
        local id = provider.id
        if id ~= ROOT_ID and tostring(id):sub(1, #GROUP_PREFIX) ~= GROUP_PREFIX and seen[id]~=provider then
            assert(not seen[id], 'duplicate browser provider: ' .. tostring(id))
            seen[id] = provider
            -- A page listed under another (indented by its contributor) stays with it.
            if provider.mcBrowserChild == nil then
                provider.mcBrowserChild = provider.mcBrowserLine == nil and provider.mcBrowserLevel == 4
            end
            if provider.mcListGroup == nil then
                local folder = folderOf(provider)
                local fields, foundationName = {}, nil
                if folder and options.folderManifest then
                    local ok, read = pcall(options.folderManifest, folder)
                    fields = ok and type(read) == 'table' and read or {}
                end
                -- A detected folder of a foundation module (named <prefix><id>) is ModCore's,
                -- and has no settings of its own to show.
                if provider.detectedKind == 'ue4ss' and type(folder) == 'string' then
                    for _, entry in ipairs(FOUNDATION) do
                        if folder:lower():sub(-#entry.id) == entry.id:lower() then
                            foundationName = entry.name
                            if fields.group == nil then fields.group = 'ModCore' end
                            if fields.settings == nil then fields.settings = false end
                        end
                    end
                end
                provider.mcListGroup = trimmed(fields.group) or false
                -- A mod that declares it has no settings is not listed as incompatible.
                provider.mcNoSettingsDeclared = fields.settings == false and provider.noSettings or nil
                -- A mod found on disk takes its details from its folder: its mod.json, else a
                -- foundation module's name and the folder's version.
                if provider.detectedKind and folder then
                    provider.mcFolder = provider.mcFolder or folder
                    local version
                    if options.folderVersion then
                        local ok, value = pcall(options.folderVersion, folder)
                        version = ok and trimmed(value) or nil
                    end
                    provider.name = fields.name or foundationName or provider.name
                    provider.author = fields.author or provider.author
                    provider.version = fields.version or version or provider.version
                    if provider.mcNoSettingsDeclared then
                        provider.description = (fields.description and fields.description .. '\n\n' or '')
                            .. provider.name .. ' has no settings to change.'
                    elseif fields.description then provider.description = fields.description end
                end
            end
            local foundation = core[id]
            local group = provider.mcBrowserGroup
            local child = not foundation and group == nil and provider.mcBrowserChild
                and contributions[provider.mcContribution]
            if foundation and provider.mcContribution then contributions[provider.mcContribution] = true end
            if child then children[#children + 1] = provider
            elseif foundation then corePages[id] = provider
            elseif group == 'tool' then tools[#tools + 1] = provider
            else
                if group == 'module' then modules[#modules + 1] = provider end
                others[#others + 1] = provider
            end
        end
    end
    -- Each remaining page's group; a page listed under another takes its group.
    local named, order, various, members = {}, {}, {}, {}
    local register=options.categoryRegister
    local preferredCounts,folderSeen={},{}
    if register then
        for _,provider in ipairs(others) do
            local folder=folderOf(provider)
            local entry=folder and register[folder]
            if entry and entry.preferred and not folderSeen[folder] then
                folderSeen[folder]=true
                preferredCounts[entry.preferred]=(preferredCounts[entry.preferred] or 0)+1
            end
        end
    end
    -- A mod that declares its group sits in the group's grid; any other takes a whole row,
    -- as its name may be long.
    local taxonomy=options.taxonomy
    local parentKeys,parentDeclared
    local declared={}
    local counted={};local moduleCount=0
    for _,provider in ipairs(others) do
        provider.mcTaxonomyEntry=nil
        local folder=folderOf(provider) or provider.id
        if not counted[folder] then counted[folder]=true;moduleCount=moduleCount+1 end
        local keys
        if provider.mcBrowserChild and parentKeys then keys=parentKeys
        else
            if taxonomy then
                local entry=register and register[folder] or {categories={'other'},parents={'other'},tags={}}
                provider.mcTaxonomyEntry=entry
                keys=taxonomy:parents(entry.categories)
                local minimum=options.preferredMinimum or 2
                if minimum>0 and entry.preferred and (preferredCounts[entry.preferred] or 0)>=minimum then
                    if taxonomy.definitions[entry.preferred] then keys=taxonomy:parents({entry.preferred})
                    else keys={'preferred:'..entry.preferred} end
                end
                parentDeclared=false
                if options.groupModules==false then keys={false} end
            else
                parentDeclared=trimmed(provider.mcListGroup)~=nil
                keys={trimmed(provider.mcListGroup) or not provider.detectedKind and trimmed(provider.author) or false}
            end
            if folder then
                for _,foundation in ipairs(FOUNDATION) do
                    if folder:lower():sub(-#foundation.id)==foundation.id:lower() then
                        keys={'ModCore'};parentDeclared=true;break
                    end
                end
            end
            parentKeys=keys
        end
        if taxonomy and not provider.mcTaxonomyEntry then
            provider.mcTaxonomyEntry=register and register[folder] or {categories={'other'},parents={'other'},tags={}}
        end
        declared[provider]=parentDeclared
        for _,key in ipairs(keys) do
            if key=='ModCore' then members[#members+1]=provider
            else
                local list=key and named[key]
                if key and not list then list={};named[key]=list;order[#order+1]=key end
                if list then list[#list+1]=provider else various[#various+1]=provider end
            end
        end
    end
    local result = {}
    local function add(provider, line, label)
        if line ~= 'head' then provider.mcBrowserLevel, provider.mcBrowserIndent = 4, 20 end
        local icon=provider.mcTaxonomyEntry and provider.mcTaxonomyEntry.icon
        if not label and icon then label=icon..'  '..provider.name end
        -- A mod that declares it has no settings shows its name without DMM's notice.
        if provider.mcNoSettingsDeclared and not label then label = provider.name end
        provider.mcBrowserLine, provider.mcBrowserLabel = line, label
        result[#result + 1] = provider
    end
    if next(corePages) or #tools > 0 or #members > 0 then
        local openable = {}
        for _, provider in ipairs(providers) do
            local link = provider.mcLinkSlot
            if link then openable[provider.id] = link.address
            elseif not provider.noSettings then openable[provider.id] = true end
        end
        local versions
        if parse then
            local ids = {}
            for _, provider in ipairs(modules) do ids[#ids + 1] = provider.id end
            for _, entry in ipairs(FOUNDATION) do ids[#ids + 1] = entry.id end
            versions = M.versions(ids, providers, options.pageVersions, options.folderVersion)
        end
        local head = root(openable, modules, tools, parse, report, versions)
        add(head, 'head')
        -- Tool pages stay among the providers so their links open them, but are never listed;
        -- without the ModCore page to reach them, they are listed in its grid instead.
        local reachable = head.mcManifest ~= nil
        for _, tool in ipairs(tools) do
            tool.mcBrowserHidden = reachable or nil
            add(tool, 'cell')
        end
        for _, entry in ipairs(CORE) do
            local provider = corePages[entry.id]
            if provider then
                add(provider, 'cell', entry.label)
            end
        end
        for _, provider in ipairs(children) do add(provider, 'cell') end
        for _, provider in ipairs(members) do
            local icon = provider.mcBrowserIcon
            add(provider, declared[provider] and 'cell' or 'row', icon and icon .. '  ' .. provider.name or nil)
        end
    else
        for _, provider in ipairs(children) do various[#various + 1] = provider end
    end
    -- A group of one mod joins Various Authors.
    local groups = {}
    for _, key in ipairs(order) do
        if register or #named[key] > 1 then groups[#groups + 1] = key
        else various[#various + 1] = named[key][1] end
    end
    local sectionOrder={}
    if taxonomy then
        for n,section in ipairs(taxonomy.data.sections) do sectionOrder[section.id]=n end
    end
    table.sort(groups, function(a,b)
        local na=sectionOrder[a] or 4.5;local nb=sectionOrder[b] or 4.5
        if na~=nb then return na<nb end
        return a:lower()<b:lower()
    end)
    for _, key in ipairs(groups) do
        local label=(options.categoryDescriptions or {})[key] or key:match('^preferred:(.*)$') or (key=='other' and 'Other or Specialized') or key
        add(heading(GROUP_PREFIX .. key, label, 2, 0, label .. ' mods.'), 'head')
        for _, provider in ipairs(named[key]) do add(provider, declared[provider] and 'cell' or 'row') end
    end
    if #various > 0 then
        local listed = {}
        for index, provider in ipairs(others) do listed[provider] = index end
        table.sort(various, function(a, b) return listed[a] < listed[b] end)
        if not register or options.groupModules~=false then
            add(heading(GROUP_PREFIX .. 'various', register and 'Other or Specialized' or VARIOUS, 2, 0, 'Other modules.'), 'head')
        end
        for _, provider in ipairs(various) do add(provider, 'row') end
    end
    for index, provider in ipairs(result) do providers[index] = provider end
    for index = #result + 1, #providers do providers[index] = nil end
    providers.mcModuleCount=moduleCount
    return providers
end

-- report(event,detail) (optional) receives failures. parse(manifest) (optional) builds the
-- ModCore page's settings. folderVersion(folder) (optional) reads a mod folder's version,
-- folderManifest(folder) (optional) its mod.json fields.
function M.install(pages, report, parse, folderVersion, folderManifest, groupingOptions)
    if pages.mcBrowserGroupsVersion then return false end
    report = report or function() end
    assert(type(pages)=='table' and type(pages.build)=='function', 'DMM pages API unavailable')
    local build = pages.build
    pages.build = function(tree, providers, status, api)
        local options={pageVersions=type(api)=='table' and api.mcPageVersions or nil, folderVersion=folderVersion,
            folderManifest=folderManifest}
        if groupingOptions then
            local ok,value=pcall(groupingOptions)
            if ok then for key,setting in pairs(value) do options[key]=setting end
            else report('BROWSER_GROUPS_FAILED',value) end
        end
        M.arrange(providers, parse, report,options)
        local page = build(tree, providers, status, api)
        if type(page)=='table' and type(page.setFilter)=='function' then
            local setFilter = page.setFilter
            -- Compatible-only filtering keeps the group headings, which have no settings of
            -- their own, and mods that declare they have none; pages opened only through
            -- links (mcBrowserHidden) are never listed. A failure leaves DMM's own filtering.
            page.mcModuleCount=providers.mcModuleCount
            local categoryFilter,tagFilter=options.categoryFilter,options.tagFilter
            local hidden = options.taxonomy~=nil
            for _, provider in ipairs(providers) do
                hidden = hidden or provider.mcBrowserHidden == true or provider.mcNoSettingsDeclared == true
                    or provider.mcBrowserHeading == true
            end
            function page:setFilter(compatibleOnly)
                setFilter(self, compatibleOnly)
                if not self.compatibleOnly and not hidden then return end
                local ok, err = pcall(function()
                    local rows, visible = {}, {}
                    for index, row in ipairs(self.allRows) do
                        local provider = providers[row.providerIndex]
                        local entry=provider.mcTaxonomyEntry
                        local allowed=not options.taxonomy or not entry or (options.taxonomy:matches(entry,categoryFilter,false)
                            and options.taxonomy:matches(entry,tagFilter,true))
                        visible[index] = allowed and not provider.mcBrowserHidden and (not self.compatibleOnly
                            or provider.mcBrowserHeading or provider.mcNoSettingsDeclared or not provider.noSettings)
                    end
                    -- A plain group heading shows only while one of its pages does.
                    for index, row in ipairs(self.allRows) do
                        local provider = providers[row.providerIndex]
                        if provider.mcBrowserHeading and provider.mcBrowserLine == 'head' then
                            local any, next = false, index + 1
                            while self.allRows[next] do
                                local member = providers[self.allRows[next].providerIndex]
                                if member.mcBrowserLine == 'head' or member.mcBrowserLine == nil then break end
                                any = any or visible[next]
                                next = next + 1
                            end
                            visible[index] = any
                        end
                    end
                    for index, row in ipairs(self.allRows) do
                        local shown = visible[index]
                        if shown then
                            rows[#rows + 1] = row
                            row.index = #rows
                        end
                        row.wrapper:SetVisibility(shown and 0 or 1)
                    end
                    self.rows = rows
                    if type(self.mcLayoutGroups) == 'function' then
                        local shown = {}
                        for index, row in ipairs(self.allRows) do shown[row] = visible[index] end
                        self:mcLayoutGroups(function(row) return shown[row] == true end)
                    end
                    self:refreshHint()
                    self.scroll:ScrollToStart()
                    self.empty:SetVisibility(#rows == 0 and 0 or 1)
                    for i, row in ipairs(rows) do
                        if i > 1 then row.widget:SetNavigationRuleExplicit(2, rows[i - 1].widget)
                        else row.widget:SetNavigationRuleBase(2, 3) end
                        if i < #rows then row.widget:SetNavigationRuleExplicit(3, rows[i + 1].widget)
                        else row.widget:SetNavigationRuleBase(3, 3) end
                    end
                end)
                if not ok then report('BROWSER_GROUPS_FAILED', err) end
            end
            function page:setCategoryFilter(values,mode)
                if options.taxonomy then options.taxonomy:matches({categories={},parents={},tags={}}, {values=values,mode=mode},false) end
                categoryFilter={values=values,mode=mode};self:setFilter(self.compatibleOnly)
            end
            function page:setTagFilter(values,mode)
                if options.taxonomy then options.taxonomy:matches({categories={},parents={},tags={}}, {values=values,mode=mode},true) end
                tagFilter={values=values,mode=mode};self:setFilter(self.compatibleOnly)
            end
            page:setFilter(page.compatibleOnly)
        end
        return page
    end
    pages.mcBrowserGroupsVersion = 1
    return true
end

return M
