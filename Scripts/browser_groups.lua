-- Arrange the mod browser into groups before DMM builds its rows. Every mod follows the
-- same rules: a valid collection (browser.preferred shared by enough mods) lists it
-- there only; otherwise it is listed under each top category its categories belong to.
local M = {}

local GROUP_PREFIX = 'ModCore.browser.group.'
local VARIOUS = 'Various Authors'
-- The page that carries the index tabs (Installed, Errors, Developer Tools): MCS's own.
local HOST = 'ModCoreSettings'
-- The MCS_Page values of those tabs, after the page's own three.
local TABS = {installed=3, errors=4, tools=5}
local COLLECTION_ICON = '⁂'
-- Top category icons by id, until the taxonomy data carries them.
local TOP_ICONS = {gameplay='▶', content='◆', presentation='○', support='□', auxiliary='□',
    other='…', unclassified='…'}

-- A group heading: its icon, a small line naming the kind of group, and its title.
local function heading(key, title, kind, icon)
    return {id=GROUP_PREFIX .. key, name=title, author='', version='',
        description=kind and kind ~= '' and kind .. ': ' .. title or title,
        choices={}, settingsCount=0, testOnly=false, noSettings=true, mcBrowserHeading=true,
        mcBrowserKind=kind, mcBrowserIcon=icon, mcBrowserLevel=2, mcBrowserIndent=0}
end

-- The entry that folds a group's mods without settings; selecting it lists them.
local function more(key, count)
    return {id=GROUP_PREFIX .. key .. '.more', name='… and ' .. count .. ' more with no settings',
        author='', version='', description='Show the ' .. count .. ' mods in this group that have no settings.',
        choices={}, settingsCount=0, choicesLoaded=true, deferred=false, testOnly=false,
        mcBrowserMore=key}
end

-- The index tabs' sections, appended to the host page's manifest. Every row is navigation
-- or read-only, so the tabs own no config. openable[id] marks the pages a link can open,
-- or names the slot a link page opens; versions[id] (optional) follows a module's name.
-- modules lists the installed ModCore modules; tools the developer tool pages
-- (group='tool'), which open only from here.
function M.manifest(openable, modules, versions, tools)
    versions = versions or {}
    local lines = {}
    local function block(section, fields)
        lines[#lines + 1] = '[' .. section .. ']'
        for _, field in ipairs(fields) do lines[#lines + 1] = field[1] .. '=' .. tostring(field[2]) end
        lines[#lines + 1] = ''
    end
    local function label(text) return (tostring(text):gsub('[|;%c%[%]]', ' ')) end
    local count = 0
    local function section(group, list, tab, empty)
        block('Category.' .. group, {{'VisibleWhen', 'MCS_Page'}, {'VisibleValues', tab}, {'mcHeading', 0}})
        if #list == 0 then
            block('Setting.MCS_Index_Empty_' .. tab, {{'Id', 'MCS_Index_Empty_' .. tab}, {'Label', group},
                {'Group', group}, {'Type', 'picker'}, {'Default', 0}, {'PresetValues', '0|1'},
                {'PresetLabels', empty .. '|' .. empty}, {'mcReadOnly', 1}, {'mcType', 'tab'}})
            return
        end
        for _, entry in ipairs(list) do
            count = count + 1
            local id = 'MCS_Index_' .. count
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
    section('Installed', modules, TABS.installed, 'None installed')
    -- The latest error lines of UE4SS.log, newest at the bottom (the host's 'errors' source).
    block('Category.Errors', {{'VisibleWhen', 'MCS_Page'}, {'VisibleValues', TABS.errors}, {'mcHeading', 0}})
    block('Setting.MCS_Index_Errors', {{'Id', 'MCS_Index_Errors'}, {'Label', 'Errors'}, {'Group', 'Errors'},
        {'Type', 'picker'}, {'Default', 0}, {'PresetValues', '0|1'}, {'PresetLabels', 'Errors|Errors'},
        {'mcReadOnly', 1}, {'mcText', 'errors'}})
    section('Developer Tools', tools or {}, TABS.tools, 'None installed')
    return table.concat(lines, '\n')
end

local function clean(value)
    if type(value) ~= 'string' then return nil end
    value = value:match('^%s*[vV]?(%d[%w%.%-%+]*)%s*$')
    return value and #value <= 32 and value or nil
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
-- separator): group, its browser group; settings, false when the mod has none to show;
-- name, author, version, icon and description, read before any dependencies list; and
-- requires, the set of dependency ids. open defaults to io.open.
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
            version=text('version', 64), icon=text('icon', 16), description=text('description', 4096),
            requires={}}
        if json:match('"settings"%s*:%s*false') then fields.settings = false end
        local dependencies = json:match('"dependencies"%s*:%s*(%b[])')
        for id in (dependencies or ''):gmatch('"id"%s*:%s*"([^"\\%c]+)"') do fields.requires[id] = true end
        return fields
    end
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

-- "A", "A and B", "A, B and C"; join is the last separator's word.
local function joined(list, join)
    if #list <= 1 then return list[1] end
    return table.concat(list, ', ', 1, #list - 1) .. ' ' .. (join or 'and') .. ' ' .. list[#list]
end

-- Appends the index tabs to the host page's manifest on each build. Returns whether the
-- host now carries them.
local function extend(host, openable, modules, versions, tools, parse, read, report)
    if not host or not parse or not read then return false end
    local ok, err = pcall(function()
        if host.mcBaseManifest == nil then
            host.mcBaseManifest = assert(host.mcManifest or read(host.path), 'host page manifest unreadable')
                :gsub('^\239\187\191', '')
        end
        local manifest = host.mcBaseManifest:gsub('%s*$', '') .. '\n\n' .. M.manifest(openable, modules, versions, tools)
        local choices = parse(manifest)
        host.choices, host.settingsCount, host.mcManifest = choices, #choices, manifest
        host.choicesLoaded, host.deferred = true, false
    end)
    if not ok and report then report('BROWSER_INDEX_FAILED', tostring(err)) end
    return ok
end

-- Every listed mod lands in groups: valid collections, then top categories in taxonomy
-- order (or, without a taxonomy, each mod.json group or author shared by several mods),
-- then Various Authors. Within a group, mods with settings come first, walked by
-- category in taxonomy order and then load order; mods without settings fold into a
-- final entry that lists them when selected.
-- options: folderManifest(folder), folderVersion(folder), pageVersions, categoryRegister,
-- taxonomy, preferredMinimum, groupModules, read(path) (to extend the host page).
function M.arrange(providers, parse, report, options)
    options = options or {}
    local listed, tools, seen = {}, {}, {}
    local host
    local parentOf = {}
    local lastParent
    for _, provider in ipairs(providers) do
        local id = provider.id
        if tostring(id):sub(1, #GROUP_PREFIX) ~= GROUP_PREFIX and seen[id] ~= provider then
            assert(not seen[id], 'duplicate browser provider: ' .. tostring(id))
            seen[id] = provider
            -- A page listed under another (indented by its contributor) stays with it.
            if provider.mcBrowserChild == nil then
                provider.mcBrowserChild = provider.mcBrowserLine == nil and provider.mcBrowserLevel == 4
            end
            if provider.mcListGroup == nil then
                local folder = folderOf(provider)
                local fields = {}
                if folder and options.folderManifest then
                    local ok, read = pcall(options.folderManifest, folder)
                    fields = ok and type(read) == 'table' and read or {}
                end
                provider.mcListGroup = trimmed(fields.group) or false
                provider.mcRequires = fields.requires or {}
                provider.mcFolderAuthor = trimmed(fields.author)
                -- A mod that declares it has no settings is not listed as incompatible.
                provider.mcNoSettingsDeclared = fields.settings == false and provider.noSettings or nil
                -- A mod found on disk, or a contributed page standing in for one, takes its
                -- details from its folder: its mod.json, else the folder's version.
                if (provider.detectedKind or provider.mcModuleEntry) and folder then
                    provider.mcFolder = provider.mcFolder or folder
                    local version
                    if options.folderVersion then
                        local ok, value = pcall(options.folderVersion, folder)
                        version = ok and trimmed(value) or nil
                    end
                    provider.name = fields.name or provider.name
                    provider.author = fields.author or provider.author
                    provider.version = fields.version or version or provider.version
                    provider.mcBrowserIcon = fields.icon or provider.mcBrowserIcon
                    if provider.mcNoSettingsDeclared then
                        provider.description = (fields.description and fields.description .. '\n\n' or '')
                            .. provider.name .. ' has no settings to change.'
                    elseif fields.description then provider.description = fields.description end
                end
            end
            if id == HOST then host = provider end
            if provider.mcBrowserGroup == 'tool' then tools[#tools + 1] = provider
            elseif provider.mcBrowserChild and lastParent then
                parentOf[provider] = lastParent
                lastParent.mcChildren = lastParent.mcChildren or {}
                lastParent.mcChildren[#lastParent.mcChildren + 1] = provider
            else
                provider.mcChildren = nil
                listed[#listed + 1] = provider
                lastParent = provider
            end
        end
    end
    -- Children are re-collected each build.
    for _, provider in ipairs(listed) do
        if provider.mcChildren then
            local kept = {}
            for _, child in ipairs(provider.mcChildren) do if parentOf[child] == provider then kept[#kept + 1] = child end end
            provider.mcChildren = kept
        end
    end
    local order = {}
    for index, provider in ipairs(listed) do order[provider] = index end
    local register, taxonomy = options.categoryRegister, options.taxonomy
    local default = {categories={'other'}, parents={'other'}, tags={}}
    local function entryOf(provider)
        local folder = folderOf(provider)
        return register and folder and register[folder] or default
    end
    -- A collection forms when enough distinct folders prefer it. A preferred main
    -- category or category is not a collection: it counts as declared first.
    local preferredCounts, folderSeen = {}, {}
    if register then
        for _, provider in ipairs(listed) do
            local folder = folderOf(provider)
            local entry = folder and register[folder]
            if entry and entry.preferred and not folderSeen[folder]
                and not (taxonomy and taxonomy.definitions[entry.preferred]) then
                folderSeen[folder] = true
                preferredCounts[entry.preferred] = (preferredCounts[entry.preferred] or 0) + 1
            end
        end
    end
    local minimum = options.preferredMinimum or 2
    local groups, byKey = {}, {}
    local function group(key, title, kind, icon, cells)
        local found = byKey[key]
        if not found then
            found = {key=key, title=title, kind=kind, icon=icon, cells=cells, members={}, has={}}
            byKey[key] = found
            groups[#groups + 1] = found
        end
        return found
    end
    local function join(found, provider)
        if not found.has[provider] then found.has[provider] = true;found.members[#found.members + 1] = provider end
    end
    local collections, sections, plain = {}, {}, {}
    local moduleCount, counted = 0, {}
    for _, provider in ipairs(listed) do
        local folder = folderOf(provider) or provider.id
        if not counted[folder] then counted[folder] = true;moduleCount = moduleCount + 1 end
        provider.mcTaxonomyEntry = nil
        if taxonomy then
            local entry = entryOf(provider)
            provider.mcTaxonomyEntry = entry
            local preferred = entry.preferred
            if options.groupModules == false then
                plain[#plain + 1] = provider
            elseif preferred and not taxonomy.definitions[preferred] and minimum > 0
                and (preferredCounts[preferred] or 0) >= minimum then
                local kind = preferred == provider.mcFolderAuthor and 'Author' or 'Collection'
                local found = group('preferred:' .. preferred, preferred, kind, COLLECTION_ICON, true)
                collections[found] = true
                join(found, provider)
            else
                -- A preferred main category or category counts as declared first.
                local declared = {}
                if preferred and taxonomy.definitions[preferred] then declared[1] = preferred end
                for _, id in ipairs(entry.categories or {}) do declared[#declared + 1] = id end
                provider.mcCategories = declared
                local ok, parents = pcall(taxonomy.parents, taxonomy, declared)
                if not ok then parents = entry.parents or {'other'} end
                for _, section in ipairs(parents) do
                    sections[section] = true
                    local definition = taxonomy.definitions[section] or {}
                    group('section:' .. section, nil, definition.description or section,
                        TOP_ICONS[section] or '…', false)
                end
            end
        else
            local own = trimmed(provider.mcListGroup)
            local key = own or not provider.detectedKind and trimmed(provider.author) or nil
            if options.groupModules == false or not key then plain[#plain + 1] = provider
            else
                local found = group('list:' .. key, key, own and 'Collection' or 'Author', COLLECTION_ICON, own ~= nil)
                join(found, provider)
            end
        end
    end
    -- Top category members, walked by category in taxonomy order then load order.
    if taxonomy then
        local position = {}
        for n, definition in ipairs(taxonomy.data.categories) do position[definition.id] = n end
        for _, found in ipairs(groups) do
            local section = found.key:match('^section:(.+)$')
            if section then
                local ranked = {}
                for _, provider in ipairs(listed) do
                    local best
                    for _, id in ipairs(provider.mcCategories or {}) do
                        local definition = taxonomy.definitions[id]
                        local parent = definition and (definition.parent or id)
                        if parent == section then
                            -- A category walks before its main category declared alone.
                            local rank = (position[id] or 0) + (definition.parent and 0 or 10000)
                            if not best or rank < best then best = rank end
                        end
                    end
                    if best then ranked[#ranked + 1] = {provider=provider, rank=best} end
                end
                table.sort(ranked, function(a, b)
                    if a.rank ~= b.rank then return a.rank < b.rank end
                    return order[a.provider] < order[b.provider]
                end)
                local present, titles = {}, {}
                for _, item in ipairs(ranked) do
                    join(found, item.provider)
                    for _, id in ipairs(item.provider.mcCategories or {}) do
                        local definition = taxonomy.definitions[id]
                        if definition and definition.parent == section then present[id] = true end
                    end
                end
                for _, definition in ipairs(taxonomy.data.categories) do
                    if present[definition.id] then titles[#titles + 1] = definition.description or definition.id end
                end
                found.title = joined(titles, section == 'other' and 'or' or 'and') or found.kind
            end
        end
    end
    -- A list group of one mod joins the plain list.
    local kept = {}
    for _, found in ipairs(groups) do
        if not taxonomy and #found.members < 2 then
            for _, provider in ipairs(found.members) do plain[#plain + 1] = provider end
        elseif #found.members > 0 then kept[#kept + 1] = found end
    end
    -- Top categories in taxonomy order, then collections in the load order of their
    -- first mod.
    local rank = {}
    if taxonomy then
        for n, section in ipairs(taxonomy.data.sections) do rank['section:' .. section.id] = n end
    end
    table.sort(kept, function(a, b)
        local ra, rb = rank[a.key], rank[b.key]
        if (ra ~= nil) ~= (rb ~= nil) then return ra ~= nil end
        if ra and rb then return ra < rb end
        return order[a.members[1]] < order[b.members[1]]
    end)
    -- The index tabs on MCS's own page: every installed module that depends on
    -- ModCoreSettings, and the developer tools.
    local openable = {}
    for _, provider in ipairs(providers) do
        local link = provider.mcLinkSlot
        if link then openable[provider.id] = link.address
        elseif not provider.noSettings then openable[provider.id] = true end
    end
    local modules, moduleFolders, versions = {}, {}, {}
    for _, provider in ipairs(listed) do
        local folder = folderOf(provider) or provider.id
        if not moduleFolders[folder] and (provider == host or (provider.mcRequires or {})[HOST]) then
            moduleFolders[folder] = true
            modules[#modules + 1] = provider
        end
    end
    table.sort(modules, function(a, b) return a.name:lower() < b.name:lower() end)
    for _, provider in ipairs(providers) do
        versions[provider.id] = clean(provider.version) or clean((options.pageVersions or {})[provider.id])
    end
    local indexed = extend(host, openable, modules, versions, tools, parse, options.read, report)
    local result = {}
    local function add(provider, line, label)
        if line ~= 'head' then provider.mcBrowserLevel, provider.mcBrowserIndent = 4, 20 end
        local icon = provider.mcTaxonomyEntry and provider.mcTaxonomyEntry.icon or provider.mcBrowserIcon
        if not label and icon and line ~= 'head' then label = icon .. '  ' .. provider.name end
        -- A mod that declares it has no settings shows its name without DMM's notice.
        if provider.mcNoSettingsDeclared and not label then label = provider.name end
        provider.mcBrowserLine, provider.mcBrowserLabel = line, label
        result[#result + 1] = provider
    end
    local folded = {}
    local function members(found, list, line)
        local without = {}
        local function one(provider)
            if provider.noSettings then without[#without + 1] = provider
            else
                add(provider, line)
                for _, child in ipairs(provider.mcChildren or {}) do add(child, line) end
            end
        end
        for _, provider in ipairs(list) do one(provider) end
        for _, provider in ipairs(without) do
            provider.mcBrowserFolded = found and found.key or 'plain'
            add(provider, line)
            for _, child in ipairs(provider.mcChildren or {}) do add(child, line) end
        end
        if #without > 0 then
            local entry = more(found and found.key or 'plain', #without)
            folded[#folded + 1] = entry
            add(entry, 'row')
        end
    end
    for _, provider in ipairs(listed) do provider.mcBrowserFolded = nil end
    for _, found in ipairs(kept) do
        add(heading(found.key, found.title, found.kind, found.icon), 'head')
        members(found, found.members, found.cells and 'cell' or 'row')
    end
    if #plain > 0 then
        table.sort(plain, function(a, b) return order[a] < order[b] end)
        local headed = options.groupModules ~= false
        local found = headed and {key='various'} or nil
        if headed then add(heading('various', register and 'Other' or VARIOUS, '', '…'), 'head') end
        members(found, plain, 'row')
    end
    -- Tool pages stay among the providers so their links open them; while the index tabs
    -- reach them they are never listed, otherwise they are listed like any mod.
    for _, tool in ipairs(tools) do
        tool.mcBrowserHidden = indexed or nil
        add(tool, 'row')
    end
    for index, provider in ipairs(result) do providers[index] = provider end
    for index = #result + 1, #providers do providers[index] = nil end
    providers.mcModuleCount = moduleCount
    providers.mcFolded = #folded > 0
    return providers
end

-- report(event,detail) (optional) receives failures. parse(manifest) (optional) builds the
-- host page's index tabs. folderVersion(folder) (optional) reads a mod folder's version,
-- folderManifest(folder) (optional) its mod.json fields; read(path) (optional) the host
-- page's manifest.
function M.install(pages, report, parse, folderVersion, folderManifest, groupingOptions, read)
    if pages.mcBrowserGroupsVersion then return false end
    report = report or function() end
    assert(type(pages)=='table' and type(pages.build)=='function', 'DMM pages API unavailable')
    local build = pages.build
    pages.build = function(tree, providers, status, api)
        local options={pageVersions=type(api)=='table' and api.mcPageVersions or nil, folderVersion=folderVersion,
            folderManifest=folderManifest, read=read}
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
            -- links (mcBrowserHidden) are never listed. Mods without settings stay folded
            -- until their group's last entry is selected. A failure leaves DMM's own filtering.
            page.mcModuleCount=providers.mcModuleCount
            page.mcExpanded={}
            local categoryFilter,tagFilter=options.categoryFilter,options.tagFilter
            local hidden = options.taxonomy~=nil or providers.mcFolded
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
                        local folded=provider.mcBrowserFolded
                        if provider.mcBrowserMore then
                            allowed=not self.compatibleOnly and not self.mcExpanded[provider.mcBrowserMore]
                        elseif folded then
                            allowed=allowed and self.mcExpanded[folded]==true
                        end
                        visible[index] = allowed and not provider.mcBrowserHidden and (not self.compatibleOnly
                            or provider.mcBrowserHeading or provider.mcNoSettingsDeclared or not provider.noSettings)
                    end
                    -- A group heading shows only while one of its pages does.
                    for index, row in ipairs(self.allRows) do
                        local provider = providers[row.providerIndex]
                        if provider.mcBrowserHeading and provider.mcBrowserLine == 'head' then
                            local any, next = false, index + 1
                            while self.allRows[next] do
                                local member = providers[self.allRows[next].providerIndex]
                                if member.mcBrowserLine == 'head' or member.mcBrowserLine == nil then break end
                                any = any or visible[next] and not member.mcBrowserMore
                                    or member.mcBrowserMore and visible[next]
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
            -- Selecting a group's "… and X more" entry lists its mods without settings.
            if type(page.showDetail)=='function' then
                local showDetail=page.showDetail
                function page:showDetail(rowIndex)
                    local row=self.rows and self.rows[rowIndex]
                    local provider=row and providers[row.providerIndex]
                    if provider and provider.mcBrowserMore then
                        self.mcExpanded[provider.mcBrowserMore]=true
                        self:setFilter(self.compatibleOnly)
                        return
                    end
                    return showDetail(self,rowIndex)
                end
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
