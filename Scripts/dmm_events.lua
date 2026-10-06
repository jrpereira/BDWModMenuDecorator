-- Runs in DMM's Lua state. Recreates DMM's lifecycle boundaries without editing
-- DMM: it wraps the settings panel that controls.build returns and DMM's
-- native-actions owner, whose close() is the first step of closing the menu host.
-- Every emission is guarded so a failing listener never breaks DMM.
local M={version=1}
local names={providerPrepared=true,providerRefreshed=true,hostClosing=true}

function M.bus(report)
    report=report or function() end
    local bus={handlers={}}
    function bus:on(name,callback)
        assert(names[name],'unsupported lifecycle event')
        assert(type(callback)=='function','lifecycle callback must be a function')
        local handlers=self.handlers[name] or {}
        self.handlers[name]=handlers
        handlers[#handlers+1]=callback
    end
    function bus:emit(name,context)
        for _,callback in ipairs(self.handlers[name] or {}) do
            local ok,err=pcall(callback,context)
            if not ok then report('LIFECYCLE_CALLBACK_FAILED',name..': '..tostring(err)) end
        end
    end
    return bus
end

-- Returns every value of a call, so wrappers stay transparent.
local function pass(...) return select('#',...),{...} end

function M.attach(modules,bus,report)
    report=report or function() end
    local function emit(name,context)
        local ok,err=pcall(bus.emit,bus,name,context)
        if not ok then report('LIFECYCLE_EMIT_FAILED',name..': '..tostring(err)) end
    end
    local controls=assert(modules.controls,'DMM controls unavailable')
    local build=assert(controls.build,'DMM controls.build unavailable')
    controls.build=function(tree,providers,api)
        local ui=build(tree,providers,api)
        local pc=api and api.pc
        local function context(index)
            return {tree=tree,provider=index and providers[index],panel=index and ui.panels[index],pc=pc}
        end
        local function built(index) local panel=ui.panels[index];return panel and panel.built==true end
        local prepare,show,refresh,hide=ui.prepare,ui.show,ui.refresh,ui.hide
        -- A page's rows exist once prepare or show has built them.
        function ui:prepare(index,...)
            local before=built(index)
            local n,results=pass(prepare(self,index,...))
            if not before and built(index) then emit('providerPrepared',context(index)) end
            return table.unpack(results,1,n)
        end
        function ui:show(index,...)
            local before=built(index)
            local n,results=pass(show(self,index,...))
            if not before and built(index) then emit('providerPrepared',context(index)) end
            emit('providerRefreshed',context(index))
            return table.unpack(results,1,n)
        end
        -- Rows that appear or disappear change the page DMM shows.
        function ui:refresh(...)
            local panel=self.active and self.panels[self.active]
            local before={}
            for i,row in ipairs(panel and panel.rows or {}) do before[i]=row.visible end
            local n,results=pass(refresh(self,...))
            if panel and self.panels[self.active]==panel then
                for i,row in ipairs(panel.rows) do
                    if row.visible~=before[i] then emit('providerRefreshed',context(self.active));break end
                end
            end
            return table.unpack(results,1,n)
        end
        function ui:hide(...)
            local n,results=pass(hide(self,...))
            emit('hostClosing',{tree=tree,pc=pc})
            return table.unpack(results,1,n)
        end
        return ui
    end
    local native=modules.nativeactions
    if native and type(native.new)=='function' and type(native.close)=='function' then
        local new,close=native.new,native.close
        local host
        native.new=function(pc,tree,...)
            host={pc=pc,tree=tree}
            return new(pc,tree,...)
        end
        native.close=function(...)
            local n,results=pass(close(...))
            if host then emit('hostClosing',{tree=host.tree,pc=host.pc});host=nil end
            return table.unpack(results,1,n)
        end
    else
        report('LIFECYCLE_PARTIAL','DMM native actions unavailable; menu close is not reported')
    end
end

return M
