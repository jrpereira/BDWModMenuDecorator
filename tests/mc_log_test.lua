package.path='Scripts/?.lua;'..package.path
local Log=require('mc_log')
local dir=(os.getenv('TMPDIR') or '.'):gsub('/+$','')
local path=dir..'/mc_log_level_'..os.time()..'_'..math.random(1000000000)..'.txt'
local function levelFile(text)
    if text==nil then os.remove(path);return end
    local file=assert(io.open(path,'wb'));file:write(text);file:close()
end
local function capture(options)
    local lines={}
    options.write=function(line) lines[#lines+1]=line end
    options.name=options.name or 'Test'
    return Log.new(options),lines
end

-- Without a level file the default is WARN.
levelFile(nil)
local log,lines=capture({path=path})
assert(log.level=='WARN')
log.trace('t');log.debug('d');log.info('i');log.warn('w');log.error('e');log.critical('c')
assert(#lines==3 and lines[1]=='[Test] WARN w' and lines[2]=='[Test] ERROR e'
    and lines[3]=='[Test] CRITICAL c',table.concat(lines,'|'))

-- The file names the level in any case; arguments are joined with tostring.
levelFile(' debug\n')
log,lines=capture({path=path})
assert(log.level=='DEBUG' and log.enabled('debug') and not log.enabled('TRACE'))
log.trace('hidden');log.debug('count ',3,' ',nil,' ',true)
assert(#lines==1 and lines[1]=='[Test] DEBUG count 3 nil true',lines[1])
-- Method-call syntax works too.
log:info('method');assert(lines[2]=='[Test] INFO method' and log:enabled('info'))

-- TRACE writes everything.
levelFile('TRACE')
log,lines=capture({path=path})
log.trace('x');assert(lines[1]=='[Test] TRACE x')

-- An unknown level never fails: it warns once and uses WARN.
levelFile('chatty')
log,lines=capture({path=path})
assert(log.level=='WARN' and #lines==1 and lines[1]:find('unknown log level "chatty"',1,true))
-- An empty file is the default, silently.
levelFile('   \n')
log,lines=capture({path=path})
assert(log.level=='WARN' and #lines==0)

-- An explicit level overrides the file; arguments are not converted when filtered.
levelFile('TRACE')
log,lines=capture({path=path,level='error'})
local converted=false
log.warn(setmetatable({},{__tostring=function() converted=true;return 'x' end}))
assert(log.level=='ERROR' and #lines==0 and not converted)

-- A failing writer never breaks the caller.
log=Log.new({name='Test',level='INFO',write=function() error('disk full') end})
log.info('safe')

-- wrap turns a plain function into a logger that forwards every level, and keeps loggers.
local seen={}
local wrapped=Log.wrap(function(message) seen[#seen+1]=message end)
wrapped.trace('a ',1);wrapped.critical('b');wrapped:warn('c')
assert(seen[1]=='a 1' and seen[2]=='b' and seen[3]=='c')
assert(Log.wrap(log)==log)
Log.wrap(nil).error('silent')
levelFile(nil)
print('PASS leveled logging filters by level, defaults to WARN and never fails')
