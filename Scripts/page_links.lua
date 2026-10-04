-- A navigation picker with mcLinkPage=<page id> opens that page instead of saving a value.
local M={version=1}

function M.wrap(page,providers,api)
    if type(page)~='table' or type(page.controls)~='table' then return page end
    local controls,pending=page.controls,nil
    local show,tick=controls.show,controls.tick
    if type(show)~='function' or type(tick)~='function' then return page end
    function controls:show(index)
        local result=show(self,index)
        local model=self.model
        if model and not model.mcPageLinks then
            local set=model.set
            function model:set(settingIndex,value)
                local choice=providers[index].choices[settingIndex]
                if choice and choice.mcLinkPage then pending=choice.mcLinkPage;return end
                return set(self,settingIndex,value)
            end
            model.mcPageLinks=true
        end
        return result
    end
    local function status(message)
        if api.setText and page.controlStatus then api.setText(page.controlStatus,message) end
    end
    function controls:tick(...)
        local result=tick(self,...)
        local target=pending
        pending=nil
        if not target then return result end
        if self.model:dirty() then
            status('Apply or discard changes before leaving this page.')
            return true
        end
        for index,provider in ipairs(providers) do
            if provider.id==target and not provider.noSettings then
                for rowIndex,row in ipairs(page.rows) do
                    if row.providerIndex==index then
                        -- Go through the browser as DMM does. Hiding the source detail restores
                        -- its transient model and clears input state; a direct detail-to-detail
                        -- replacement can leave the activating picker alive and reactivate it.
                        if type(page.showBrowser)=='function' then page:showBrowser() end
                        page:showDetail(rowIndex)
                        return true
                    end
                end
            end
        end
        status(target..' page is unavailable.')
        return true
    end
    return page
end

function M.install(pages)
    assert(type(pages)=='table' and type(pages.build)=='function','DMM pages API unavailable')
    if pages.mcPageLinksVersion then return false end
    local build=pages.build
    pages.build=function(tree,providers,status,api)
        return M.wrap(build(tree,providers,status,api),providers,api)
    end
    pages.mcPageLinksVersion=M.version
    return true
end

return M
