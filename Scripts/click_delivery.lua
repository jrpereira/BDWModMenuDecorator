-- Queue left-button input as primitive Lua state. The key callback performs no
-- UObject work; the existing menu-only game-thread update resolves the current
-- button and delivers the click to the hovered owned control.
local M={}
function M.new(log)
    local self={owners={},path=nil,pointerClicks=0,available=nil}
    local function install()
        if self.available~=nil then return self.available end
        local ok,err=pcall(function()
            assert(type(RegisterKeyBind)=='function','RegisterKeyBind unavailable')
            assert(type(Key)=='table' and Key.LEFT_MOUSE_BUTTON~=nil,'left mouse key unavailable')
            RegisterKeyBind(Key.LEFT_MOUSE_BUTTON,function()
                if self.path and self.pointerClicks<16 then self.pointerClicks=self.pointerClicks+1 end
            end)
        end)
        self.available=ok
        if not ok then log('CLICK_INPUT_FAILED',tostring(err)) end
        return ok
    end
    function self:close()
        self.path=nil;self.pointerClicks=0
        for _,owner in pairs(self.owners) do owner.instance[owner.queue]=0 end
    end
    function self:open(path)
        self.path=path;self.pointerClicks=0
        for _,owner in pairs(self.owners) do owner.instance[owner.queue]=0 end
        if not install() then self.path=nil;return false,'left mouse callback unavailable' end
        return true
    end
    function self:attach(instance,button,queue)
        assert(self.path and self.available,'click input unavailable')
        local address=tostring(button:GetAddress())
        if type(queue)~='string' then queue=nil end
        queue=queue or 'pendingClicks'
        self.owners[address]={instance=instance,path=self.path,full=button:GetFullName(),
            source=queue=='pendingOptionalClicks' and 'optional' or 'pair',queue=queue}
    end
    function self:deliver(instance)
        if self.pointerClicks==0 or not self.path or not instance then return end
        for address,owner in pairs(self.owners) do
            if owner.instance==instance and owner.path==self.path then
                local source=instance[owner.source]
                local button=source and source.button
                if button and button:IsValid() and tostring(button:GetAddress())==address
                    and button:GetFullName()==owner.full and button:IsHovered()==true then
                    instance[owner.queue]=(instance[owner.queue] or 0)+self.pointerClicks
                    self.pointerClicks=0
                    return
                end
            end
        end
    end
    function self:discard() self.pointerClicks=0 end
    function self:retire(path)
        for address,owner in pairs(self.owners) do
            if not path or owner.path==path then
                owner.instance[owner.queue]=0
                self.owners[address]=nil
            end
        end
        if not path or path==self.path then self.pointerClicks=0 end
    end
    function self:forget(instance)
        for address,owner in pairs(self.owners) do
            if owner.instance==instance then instance[owner.queue]=0;self.owners[address]=nil end
        end
    end
    return self
end
return M
