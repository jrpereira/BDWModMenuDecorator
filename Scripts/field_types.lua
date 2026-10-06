-- Runs in DMM's Lua state. Adds setting types DMM does not know. DMM still
-- builds each row as its toggle shell (label, row, navigation, description);
-- the type's editor supplies the controls and owns the value, which stays text in
-- DMM's model. Settings of DMM's own types pass through untouched.
--
-- An editor is a table:
--   declare(fields) -> extra fields for the setting (fields: the raw section)
--   normalize(setting,raw) -> canonical value, or nil when raw is invalid
--   valid(setting,value) -> true for a canonical value
--   format(setting,value) -> text DMM shows in the row's value caption
--   build(row,setting,context) -> instance with set(value,committed) and
--       tick() -> new value or nil; context has tree, api and modules
local M={version=1}
local MAX_SETTINGS=256
local dmmKinds={slider=true,integer=true,percent=true,stepped=true,toggle=true,picker=true,preset=true}
local function trim(s) return (s or ''):match('^%s*(.-)%s*$') end
local function split(s)
    local out={};for part in ((s or '')..'|'):gmatch('(.-)|') do out[#out+1]=trim(part) end
    return out
end

-- The raw [Setting] and [Category.*] sections, in DMM's own reading order.
local function sections(content)
    local raw,categories,current={},{},nil
    for line in (content..'\n'):gmatch('([^\n]*)\n') do
        local name=trim(line):match('^%[([^%]]+)%]$')
        if name then
            current=nil
            if name=='Setting' or name:match('^Setting%.') then current={};raw[#raw+1]=current
            elseif name:match('^Category%.') then current={};categories[name:sub(10)]=current end
        elseif current and not trim(line):match('^[;#]') and trim(line)~='' then
            local k,v=line:match('^%s*([^=]+)=(.*)$')
            if k and current[trim(k)]==nil then current[trim(k)]=trim(v) end
        end
    end
    return raw,categories
end

function M.new(report)
    report=report or function() end
    local registry={editors={}}

    function registry:register(name,editor)
        assert(type(name)=='string' and name:match('^%l[%w_]*$') and not dmmKinds[name],'invalid setting type name')
        for _,method in ipairs({'declare','normalize','valid','format','build'}) do
            assert(type(editor[method])=='function','setting type '..name..' needs '..method..'()')
        end
        self.editors[name]=editor
    end
    local function editorOf(setting)
        return setting and setting.kind=='extension' and registry.editors[setting.editor] or nil
    end
    registry.editorOf=editorOf

    local function item(index,r,editor,name)
        local id=r.Id or ('setting_'..index)
        local s={id=id,kind='extension',editor=name,label=r.Label or id,description=r.Description or '',
            group=r.Group or r.Section or r.Category or 'Settings',
            -- DMM's toggle shell sizes its navigation from two values; they are never stored.
            values={0,1},labels={'',''},file=r.ConfigFile,key=r.ConfigKey or id,section=r.ConfigSection,visibility={}}
        for key,value in pairs(editor.declare(r) or {}) do
            assert(s[key]==nil,'setting type '..name..' cannot redefine '..key)
            s[key]=value
        end
        s.default=assert(editor.normalize(s,r.Default),'invalid '..name..' default: '..id)
        return s
    end

    -- DMM rejects a category without settings of its own types, so it gets the
    -- manifest without categories only this module's settings use.
    function registry:forDMM(content)
        local raw,categories=sections(content)
        local used,typed={},false
        for _,r in ipairs(raw) do
            local group=r.Group or r.Section or r.Category or 'Settings'
            if self.editors[trim(r.Type):lower()] then typed=true else used[group]=true end
        end
        if not typed then return content end
        local drop={}
        for group in pairs(categories) do if not used[group] then drop[group]=true end end
        if next(drop)==nil then return content end
        local out,skipping={},false
        for line in (content..'\n'):gmatch('([^\n]*)\n') do
            local name=trim(line):match('^%[([^%]]+)%]$')
            if name then skipping=name:match('^Category%.') and drop[name:sub(10)] or false end
            if not skipping then out[#out+1]=line end
        end
        return table.concat(out,'\n')
    end

    -- Puts this module's settings back at their manifest positions among DMM's.
    function registry:merge(content,items)
        local raw,categories=sections(content)
        local any=false
        for _,r in ipairs(raw) do if self.editors[trim(r.Type):lower()] then any=true;break end end
        if not any then return items end
        local merged,remap,from,mine={},{},0,{}
        for index,r in ipairs(raw) do
            local kind=trim(r.Type):lower()
            local editor=self.editors[kind]
            if editor then
                merged[#merged+1]=item(index,r,editor,kind)
                mine[#merged]=r
            elseif dmmKinds[kind] then
                from=from+1
                remap[from]=#merged+1
                merged[#merged+1]=assert(items[from],'DMM settings out of step with the manifest')
            end
        end
        assert(from==#items,'DMM settings out of step with the manifest')
        assert(#merged<=MAX_SETTINGS,'more than '..MAX_SETTINGS..' settings')
        local byId={}
        for index,s in ipairs(merged) do
            assert(not byId[s.id],'duplicate setting Id '..s.id)
            byId[s.id]=index
        end
        for index,s in ipairs(merged) do
            if not mine[index] then
                for _,rule in ipairs(s.visibility or {}) do rule.target=remap[rule.target] end
                for n,target in ipairs(s.targets or {}) do s.targets[n]=remap[target] end
            end
        end
        -- The same row and category visibility DMM applies to its own settings.
        local function condition(r)
            if not r or (r.VisibleWhen==nil and r.VisibleValues==nil) then return nil end
            local target=byId[r.VisibleWhen]
            assert(target and r.VisibleValues,'visibility requires a setting Id and VisibleValues')
            local source=merged[target]
            assert(source.kind=='toggle' or source.kind=='picker','visibility source must be a toggle or picker')
            local values={}
            for _,rawValue in ipairs(split(r.VisibleValues)) do
                local value=tonumber(rawValue)
                local known=false
                for _,v in ipairs(source.values) do if v==value then known=true end end
                assert(value and known and not values[value],'invalid/duplicate visibility value')
                values[value]=true
            end
            return {target=target,values=values}
        end
        for index,r in pairs(mine) do
            local s=merged[index]
            local rowRule,groupRule=condition(r),condition(categories[s.group])
            if rowRule then s.visibility[#s.visibility+1]=rowRule end
            if groupRule then s.visibility[#s.visibility+1]=groupRule end
        end
        return merged
    end

    -- Wraps DMM's modules. Every editor call is guarded: a failing editor reports
    -- and leaves DMM's own behavior in place.
    function registry:install(modules)
        local choices,controls=modules.choices,modules.controls
        local parse,index,format,open=choices.parse,choices.index,choices.format,choices.open
        choices.parse=function(content)
            return registry:merge(content,parse(registry:forDMM(content)))
        end
        choices.index=function(setting,value)
            local editor=editorOf(setting)
            if not editor then return index(setting,value) end
            local ok,valid=pcall(editor.valid,setting,value)
            return ok and valid and 1 or nil
        end
        choices.format=function(setting,value)
            local editor=editorOf(setting)
            if not editor then return format(setting,value) end
            local ok,text=pcall(editor.format,setting,value)
            return ok and text or ''
        end
        choices.open=function(provider)
            local model=open(provider)
            if not model.error and not provider.testOnly then
                for _,s in ipairs(model.items or {}) do
                    if editorOf(s) then
                        model.error='"'..s.label..'" needs a page that stores its own settings'
                        break
                    end
                end
            end
            return model
        end
        -- Applied notifications carry numbers only; text values stay with the page's storage.
        local api=modules.settingsApi
        if api and type(api.publish)=='function' then
            local publish=api.publish
            api.publish=function(id,event,...)
                if type(event)=='table' and type(event.values)=='table' then
                    local values,changes={},{}
                    for key,value in pairs(event.values) do
                        if type(value)=='number' then values[key]=value;changes[key]=event.changes and event.changes[key] end
                    end
                    if next(values)==nil then return true end
                    event={values=values,changes=changes}
                end
                return publish(id,event,...)
            end
        end
        local build=controls.build
        controls.build=function(tree,providers,uiApi)
            local ui=build(tree,providers,uiApi)
            local instances={}
            local function attach(index)
                local panel=ui.panels[index]
                if not panel or not panel.built or instances[index] then return end
                local list={}
                instances[index]=list
                for i,setting in ipairs(providers[index].choices or {}) do
                    local editor=editorOf(setting)
                    local row=panel.rows[i]
                    if editor and row then
                        local ok,instance=pcall(editor.build,row,setting,{tree=tree,api=uiApi,modules=modules})
                        if ok and instance then list[i]=instance
                        else report('FIELD_EDITOR_FAILED',setting.id..': '..tostring(ok and 'no editor' or instance)) end
                    end
                end
            end
            local function each(callback)
                local list=ui.active and instances[ui.active]
                if not list or not ui.model then return end
                for i,instance in pairs(list) do
                    local ok,err=pcall(callback,i,instance)
                    if not ok then report('FIELD_EDITOR_FAILED',tostring(err)) end
                end
            end
            local prepare,show,refresh,tick=ui.prepare,ui.show,ui.refresh,ui.tick
            function ui:prepare(index,...)
                local results=table.pack(prepare(self,index,...))
                attach(index)
                return table.unpack(results,1,results.n)
            end
            function ui:show(index,...)
                local results=table.pack(show(self,index,...))
                attach(index)
                self:refresh()
                return table.unpack(results,1,results.n)
            end
            -- The setter: every refresh puts the model's value into the editor.
            function ui:refresh(...)
                local results=table.pack(refresh(self,...))
                local model=self.model
                each(function(i,instance)
                    if not model.error then instance:set(model.pending[i],model.committed[i]) end
                end)
                return table.unpack(results,1,results.n)
            end
            -- The getter: an editor's change goes into DMM's model like any other edit.
            function ui:tick(...)
                local results=table.pack(tick(self,...))
                local changed=false
                local model=self.model
                each(function(i,instance)
                    local value=instance:tick()
                    if value~=nil and not model.error and value~=model.pending[i] then
                        model:set(i,value)
                        changed=true
                    end
                end)
                if changed then self:refresh() end
                return table.unpack(results,1,results.n)
            end
            return ui
        end
    end
    return registry
end

M._test={sections=sections}
return M
