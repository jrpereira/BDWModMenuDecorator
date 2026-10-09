package.path='Scripts/?.lua;'..package.path
local ErrorLog=require('error_log')

-- Which lines are errors.
for _,line in ipairs({
    '[2026-10-07 18:17:21.1] [Lua] [ModCoreControls] ERROR binding failed',
    '[2026-10-07 18:17:21.1] [Lua] [ModCoreSettings] CRITICAL page lost',
    '[2026-10-07 18:17:21.1] [Lua::call_function] lua_pcall returned LUA_ERRRUN => main.lua:3: attempt to index nil',
    '[2026-10-07 18:17:21.1] Error: Crashed calling FName constructor.',
    '[2026-10-07 18:17:21.1] Exception in iterate_directory: denied',
    '[2026-10-07 18:17:21.1] stack traceback:',
}) do assert(ErrorLog.isError(line),line) end
for _,line in ipairs({
    '[2026-10-07 18:17:21.1] FArchiveState::ArIsCriticalError = 0x29',
    '[2026-10-07 18:17:21.1] UWorld::bKismetScriptError = 0x13D',
    '[2026-10-07 18:17:21.1] [Lua] [ModCoreTemplates] INFO 1 templates running',
    '[2026-10-07 18:17:21.1] [Lua] [ModCoreTemplates] WARN slow start',
    '[2026-10-07 18:17:21.1] [Lua] [X] ErrorlessThing loaded',
}) do assert(not ErrorLog.isError(line),line) end
print('PASS error lines are told apart from offsets and ordinary messages')

-- A growing log: new error lines arrive at the bottom, with their stack traces.
local content=''
local function open(path)
    assert(path=='UE4SS.log')
    local position=0
    return {
        seek=function(_,whence,offset)
            if whence=='end' then position=#content else position=offset end
            return position
        end,
        read=function(_,count) local chunk=content:sub(position+1,position+count);position=position+#chunk;return chunk end,
        close=function() end,
    }
end
local reader=ErrorLog.reader('UE4SS.log',open)
local lines,changed=reader.poll()
assert(#lines==0 and not changed and ErrorLog.text(lines)=='No errors logged this session.')
content='[2026-10-07 18:00:00.0] [Lua] [A] INFO fine\n[2026-10-07 18:00:01.0] [Lua] [A] ERROR first\n'
    ..'stack traceback:\n\tmain.lua:3: in main chunk\n\n[2026-10-07 18:00:02.0] [Lua] [A] INFO later\n'
    ..'[2026-10-07 18:00:03.0] [Lua] [B] ERROR par'
lines,changed=reader.poll()
assert(changed and #lines==3 and lines[1]:find('ERROR first',1,true) and lines[2]=='stack traceback:'
    and lines[3]=='\tmain.lua:3: in main chunk','errors keep their untimestamped stack traces')
content=content..'tial\r\n[2026-10-07 18:00:04.0] [Lua] [B] INFO ok\nnot an error: follows INFO\n'
lines,changed=reader.poll()
assert(changed and #lines==4 and lines[4]=='[2026-10-07 18:00:03.0] [Lua] [B] ERROR partial',
    'a line is read once it is complete')
lines,changed=reader.poll()
assert(not changed and #lines==4,'an unchanged log reports no change')
print('PASS new error lines arrive at the bottom with their stack traces')

-- Only the latest lines are kept; long lines are cut; a new session starts over.
local many={}
for n=1,ErrorLog.limit+5 do many[n]='[2026-10-07 18:00:00.0] ERROR '..n..'\n' end
content=content..table.concat(many)..'[2026-10-07 18:00:00.0] ERROR '..string.rep('x',400)..'\n'
lines=reader.poll()
assert(#lines==ErrorLog.limit and lines[#lines-1]:find('ERROR '..(ErrorLog.limit+5),1,true)
    and #lines[#lines]==ErrorLog.width and lines[#lines]:sub(-3)=='...','the latest lines are kept')
content='[2026-10-07 19:00:00.0] [Lua] [A] ERROR new session\n'
lines,changed=reader.poll()
assert(changed and #lines==1 and lines[1]:find('new session',1,true),'a shorter log starts over')
print('PASS only the latest lines are kept, and a new session starts over')

-- A missing or failing log never fails the caller.
local missing=ErrorLog.reader('UE4SS.log',function() return nil end)
lines,changed=missing.poll()
assert(#lines==0 and not changed)
local failing=ErrorLog.reader('UE4SS.log',function() error('locked') end)
lines,changed=failing.poll()
assert(#lines==0 and not changed)
print('PASS a missing or unreadable log shows no errors')
