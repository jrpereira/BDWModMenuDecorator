package.path='Scripts/?.lua;'..package.path
local callback,registered=nil,0
Key={LEFT_MOUSE_BUTTON=1}
RegisterKeyBind=function(key,fn) assert(key==Key.LEFT_MOUSE_BUTTON);callback=fn;registered=registered+1 end
local errors={}
local router=require('click_delivery').new(function(e) errors[#errors+1]=e end)
local function button(id,name)
 local b={id=id,name=name or id}
 function b:GetAddress() return self.id end
 function b:GetFullName() return self.name end
 function b:IsValid() return self.alive~=false end
 function b:IsHovered() return self.hovered==true end
 return b
end
local function emit() callback() end
local i={};local pair=button(1,'pair');i.pair={button=pair}
assert(router:open('hostA'));router:attach(i,pair)
pair.hovered=true;router:sample()
for _=1,3 do emit() end
router:deliver(i);assert(i.pendingClicks==3)
print('PASS sampled pair receives each queued press once')

local clear=button(3,'clear');i.optional={button=clear}
router:attach(i,clear,'pendingOptionalClicks')
pair.hovered=false;clear.hovered=true;router:sample()
emit();router:deliver(i)
assert(i.pendingOptionalClicks==1 and i.pendingClicks==3)
print('PASS optional clear and pair retain distinct click targets')

local j={};local other=button(2,'other');j.pair={button=other}
router:attach(j,other)
clear.hovered=false;pair.hovered=true;router:sample()
emit();pair.hovered=false;other.hovered=true
router:deliver(i);router:deliver(j);router:discard()
assert(i.pendingClicks==3 and j.pendingClicks==nil)
print('PASS movement from pair A to row B cannot deliver A click to B')

router:sample();emit();other.hovered=false;clear.hovered=true
router:deliver(i);router:deliver(j);router:discard()
assert(i.pendingOptionalClicks==1 and j.pendingClicks==nil)
print('PASS movement from another row to optional clear cannot clear the key')

pair.hovered=true;clear.hovered=false;router:sample()
emit();pair.hovered=false;clear.hovered=true
emit();router:deliver(i);router:discard()
assert(i.pendingClicks==3 and i.pendingOptionalClicks==1)
print('PASS alternating clicks between samples are discarded when attribution is ambiguous')

pair.hovered=true;clear.hovered=true;router:sample()
emit();router:deliver(i);router:discard()
assert(i.pendingClicks==3 and i.pendingOptionalClicks==1)
print('PASS overlapping hovered targets do not receive a click')

clear.hovered=false;pair.hovered=true;router:sample()
emit();router:open('hostB');assert(i.pendingClicks==0 and router.pointerClicks==0)
emit();router:open('hostA');router:deliver(i);assert(i.pendingClicks==0)
router:sample();emit();router:deliver(i);assert(i.pendingClicks==1 and registered==1)
router:close();assert(i.pendingClicks==0)
callback();assert(#errors==0)
print('PASS scope changes clear sampled and queued targets without callback UObject access')

router:open('hostA');router:sample();emit();router:forget(i)
router:deliver(i);assert(i.pendingClicks==0 and router.pointerClicks==0)
router:attach(i,pair);router:sample();emit();router:deliver(i);assert(i.pendingClicks==1)
router:retire('foreign');assert(i.pendingClicks==1)
router:retire('hostA');emit();assert(i.pendingClicks==0 and next(router.owners)==nil)
print('PASS forgotten and retired ownership cannot receive queued presses')

router:open('hostA');router:attach(i,pair);router:sample()
for _=1,32 do callback() end
assert(router.pointerClicks==16 and registered==1)
router:close();assert(router.pointerClicks==0)
for _=1,32 do callback() end
assert(router.pointerClicks==0)
print('PASS callback is bounded, inactive outside settings and registered once')

Key=nil;RegisterKeyBind=nil
local unavailable=require('click_delivery').new(function(e) errors[#errors+1]=e end)
assert(not unavailable:open('hostA'))
assert(not pcall(unavailable.attach,unavailable,i,pair))
print('PASS unavailable mouse callback fails closed before proxy ownership')
