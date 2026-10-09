package.path='Scripts/?.lua;Scripts/vendor/?.lua;'..package.path
local captured={}
local installed=false
local scans=0
package.loaded.mcs_mod_registry={boot=function() scans=scans+1 end}
local originalPrint=print
print=function(value) captured[#captured+1]=value end
package.loaded.dmm_binding={install=function() installed=true;return true end}
package.loaded.dmm_bootstrap={run=function(log) assert(scans==1,'scan precedes DMM bootstrap');log('DMM_REQUIRED','missing DMM') end}
dofile('Scripts/main.lua')
print=originalPrint
assert(#captured==1 and captured[1]:find('DMM_REQUIRED',1,true))
assert(not installed,'DMM readiness must gate MCS initialization')
print('PASS startup explains missing DMM and remains inactive')
package.loaded.dmm_binding={install=function() installed=true;return true end}
package.loaded.dmm_bootstrap={run=function(_,start) assert(scans==2,'one scan per startup');return start() end}
dofile('Scripts/main.lua')
assert(installed,'ready DMM handshake must initialize presentation')
print('PASS ready DMM handshake initializes presentation')

installed=false
package.loaded.mcs_mod_registry={boot=function() error('malformed register') end}
package.loaded.dmm_bootstrap={run=function(_,start) return start() end}
print=function(value) captured[#captured+1]=value end
dofile('Scripts/main.lua')
print=originalPrint
assert(installed,'identification failure must not block presentation')
assert(captured[#captured]:find('MODULE_IDENTIFICATION_FAILED',1,true))
print('PASS identification failure is logged without blocking DMM integration')
