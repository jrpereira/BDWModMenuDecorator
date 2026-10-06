-- Arrange ModCore providers as a browser tree before DMM builds its rows.
local M = {}
local ROOT_ID, OLD_FOUNDATIONS_ID = 'ModCore.browser.root', 'ModCore.browser.foundations'

local function heading(id, name, level, indent)
    return {id=id, name=name, author='ModCore', version='',
        description=name .. ' groups related ModCore pages.',
        choices={}, settingsCount=0, testOnly=false, noSettings=true, mcBrowserHeading=true,
        mcBrowserLevel=level, mcBrowserIndent=indent}
end

function M.arrange(providers)
    local corePages, modules, remaining = {}, {}, {}
    local first, seen = nil, {}
    for _, provider in ipairs(providers) do
        local id = provider.id
        if id ~= ROOT_ID and id ~= OLD_FOUNDATIONS_ID then
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
    local group = {heading(ROOT_ID, 'ModCore', 2, 0)}
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

-- report(event,detail) (optional) receives failures.
function M.install(pages, report)
    if pages.mcBrowserGroupsVersion then return false end
    report = report or function(event, detail)
        print('[ModCoreSettings] ' .. event .. ' ' .. tostring(detail) .. '\n')
    end
    assert(type(pages)=='table' and type(pages.build)=='function', 'DMM pages API unavailable')
    local build = pages.build
    pages.build = function(tree, providers, status, api)
        M.arrange(providers)
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
