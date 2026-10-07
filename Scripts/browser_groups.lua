-- Arrange ModCore providers as a browser tree before DMM builds its rows.
local M = {}
local ROOT_ID = 'ModCore.browser.root'

local FOUNDATION = {'ModCoreControls', 'ModCoreSettings'}
local FOUNDATION_NAMES = {ModCoreControls='ModCore Controls', ModCoreSettings='ModCore Settings'}

local function heading(id, name, level, indent)
    return {id=id, name=name, author='ModCore', version='',
        description=name .. ' groups related ModCore pages.',
        choices={}, settingsCount=0, testOnly=false, noSettings=true, mcBrowserHeading=true,
        mcBrowserLevel=level, mcBrowserIndent=indent}
end

-- The ModCore page: a Modules tab linking to each module's page, and a Developer Tools tab.
-- Every row is navigation, so the page owns no config file.
function M.manifest(corePages, modules)
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
        {'Type', 'picker'}, {'Default', 0}, {'PresetValues', '0|1'}, {'PresetLabels', 'Modules|Developer Tools'},
        {'mcNavigation', 1}, {'mcHeading', 'true'}})
    local count = 0
    local function section(group, list)
        if #list == 0 then return end
        block('Category.' .. group, {{'VisibleWhen', 'ModCore_Page'}, {'VisibleValues', 0}})
        for _, entry in ipairs(list) do
            count = count + 1
            local id = 'ModCore_Module_' .. count
            block('Setting.' .. id, {{'Id', id}, {'Label', label(entry.name)}, {'Group', group},
                {'Type', 'picker'}, {'Default', 0}, {'PresetValues', '0|1'}, {'PresetLabels', 'Open|Open'},
                {'mcNavigation', 1}, {'mcType', 'tab'}, {'mcLinkPage', entry.id}})
        end
    end
    local user, foundation = {}, {}
    for _, provider in ipairs(modules) do user[#user + 1] = {id=provider.id, name=provider.name} end
    for _, id in ipairs(FOUNDATION) do
        if corePages[id] then foundation[#foundation + 1] = {id=id, name=FOUNDATION_NAMES[id]} end
    end
    section('User Modules', user)
    section('Foundation Modules', foundation)
    block('Category.Developer Tools', {{'VisibleWhen', 'ModCore_Page'}, {'VisibleValues', 1}, {'mcHeading', 0}})
    block('Setting.ModCore_DeveloperTools', {{'Id', 'ModCore_DeveloperTools'}, {'Label', 'Developer Tools'},
        {'Group', 'Developer Tools'}, {'Type', 'picker'}, {'Default', 0}, {'PresetValues', '0|1'},
        {'PresetLabels', 'Coming soon|Coming soon'}, {'mcReadOnly', 1}})
    return table.concat(lines, '\n')
end

-- parse(manifest) (optional) turns the ModCore heading into its page; without it, or if the
-- page cannot be built, the heading stays a plain group heading.
local function root(corePages, modules, parse, report)
    if parse then
        local ok, result = pcall(function()
            local manifest = M.manifest(corePages, modules)
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

function M.arrange(providers, parse, report)
    local corePages, modules, remaining = {}, {}, {}
    local first, seen = nil, {}
    for _, provider in ipairs(providers) do
        local id = provider.id
        if id ~= ROOT_ID then
            assert(not seen[id], 'duplicate browser provider: ' .. tostring(id))
            seen[id] = true
            local foundation = id == 'ModCoreControls' or id == 'ModCoreSettings'
            if foundation or provider.mcBrowserGroup == 'module' then
                first = first or #remaining + 1
                if foundation then corePages[id] = provider
                else modules[#modules + 1] = provider end
            else
                remaining[#remaining + 1] = provider
            end
        end
    end
    if not first then return remaining end
    local group = {root(corePages, modules, parse, report)}
    if next(corePages) then
        for _, id in ipairs({'ModCoreControls', 'ModCoreSettings'}) do
            local provider = corePages[id]
            if provider then
                provider.mcBrowserLevel, provider.mcBrowserIndent = 4, 20
                group[#group + 1] = provider
            end
        end
    end
    for _, provider in ipairs(modules) do
        provider.mcBrowserLevel, provider.mcBrowserIndent = 4, 20
        group[#group + 1] = provider
    end
    for index = #group, 1, -1 do table.insert(remaining, first, group[index]) end
    for index, provider in ipairs(remaining) do providers[index] = provider end
    for index = #remaining + 1, #providers do providers[index] = nil end
    return providers
end

-- report(event,detail) (optional) receives failures. parse(manifest) (optional) builds the
-- ModCore page's settings.
function M.install(pages, report, parse)
    if pages.mcBrowserGroupsVersion then return false end
    report = report or function() end
    assert(type(pages)=='table' and type(pages.build)=='function', 'DMM pages API unavailable')
    local build = pages.build
    pages.build = function(tree, providers, status, api)
        M.arrange(providers, parse, report)
        local page = build(tree, providers, status, api)
        if type(page)=='table' and type(page.setFilter)=='function' then
            local setFilter = page.setFilter
            -- Compatible-only filtering keeps the ModCore group headings, which have
            -- no settings of their own. A failure leaves DMM's own filtering in place.
            function page:setFilter(compatibleOnly)
                setFilter(self, compatibleOnly)
                if not self.compatibleOnly then return end
                local ok, err = pcall(function()
                    local rows = {}
                    for _, row in ipairs(self.allRows) do
                        local provider = providers[row.providerIndex]
                        local shown = provider.mcBrowserHeading or not provider.noSettings
                        if shown then
                            rows[#rows + 1] = row
                            row.index = #rows
                        end
                        row.wrapper:SetVisibility(shown and 0 or 1)
                    end
                    self.rows = rows
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
            page:setFilter(page.compatibleOnly)
        end
        return page
    end
    pages.mcBrowserGroupsVersion = 1
    return true
end

return M
