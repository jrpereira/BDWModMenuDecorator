package.path='Scripts/?.lua;'..package.path
local C=require('module_categories')
local G=require('browser_groups')
local J=require('mcs_module_json')
local T=require('mcs_taxonomy').new(require('mcs_taxonomy_data'))
local function entry(categories,tags,preferred)
 return T:entry({categories=categories,tags=tags or {},preferred=preferred,
 reason=categories[1]=='other' and 'insufficient_evidence' or nil})
end
assert(#T:categories({'content','gear','appearance'})==2,'parents do not consume extra slots')
assert(#T:parents({'gear','items'})==1,'two content selections grant content once')
assert(#T:parents({'gear','appearance'})==2)
assert(not pcall(T.categories,T,{'combat'}) and not pcall(T.categories,T,{'vehicles'}),'no aliases')
assert(not pcall(T.categories,T,{'action','gear','visuals','tools'}),'three category maximum')
assert(not pcall(T.categories,T,{'gear','gear'}))
assert(not pcall(T.tags,T,{'unstable'}))
local index={schema_version=2,taxonomy_version=2,modules={
 A=entry({'gear','appearance'},{'fix'},'Custom'),B=entry({'interface'},{},'Custom')}}
local files={index=J.encode(index),config='[Modules]\nGroupModules=1\nPreferredCategoryMinimum=0\n'}
local errors=0
local reader=C.reader('index','config',function(path) return files[path] end,{report=function() errors=errors+1 end})
local function providers()
 return {{id='A',name='A',mcFolder='A'},{id='A.child',name='Child',mcBrowserLevel=4,mcFolder='A'},
 {id='B',name='B',mcFolder='B'},{id='U',name='U',mcFolder='Unregistered'}}
end
local options=reader();local list=providers();G.arrange(list,nil,nil,options)
local headings,seen,instances={},{},{}
for _,p in ipairs(list) do
 if p.mcBrowserHeading then headings[#headings+1]=p.mcBrowserKind
 else seen[p.id]=(seen[p.id] or 0)+1;instances[p.id]=instances[p.id] or p;assert(instances[p.id]==p) end
end
assert(table.concat(headings,'|')=='Content|Presentation|Other or Specialized')
assert(seen.A==2 and seen['A.child']==2 and seen.B==1,'one placement per parent, same provider and settings')
assert(list.mcModuleCount==3,'placements and child pages do not inflate module count')
local first=#list;G.arrange(list,nil,nil,options);assert(#list==first,'rebuild does not multiply placements')
files.config='[Modules]\nGroupModules=1\nPreferredCategoryMinimum=2\n'
list=providers();G.arrange(list,nil,nil,reader())
-- Top categories come first, then collections.
assert(list[1].mcBrowserKind=='Other or Specialized' and list[2].id=='U'
 and list[3].name=='Custom' and list[3].mcBrowserKind=='Collection'
 and list[4].id=='A' and list[5].id=='A.child' and list[6].id=='B')
local one={{id='A',name='A',mcFolder='A'},{id='A.child',name='Child',mcBrowserLevel=4,mcFolder='A'}}
G.arrange(one,nil,nil,reader());assert(one[1].mcBrowserKind=='Content','children do not meet the preferred-group threshold')
files.config='[Modules]\nGroupModules=0\n'
list=providers();G.arrange(list,nil,nil,reader());assert(#list==4 and list.mcModuleCount==3)
files.index='{invalid';local retained=reader();assert(retained.categoryRegister.A.categories[1]=='gear' and errors==1)
reader();assert(errors==1)
files.index=nil;assert(reader().categoryRegister.A)
files.index=J.encode({schema_version=2,taxonomy_version=2,modules={B=entry({'transport'})}})
assert(reader().categoryRegister.A==nil and reader().categoryRegister.B.parents[1]=='content')
assert(T:matches(index.modules.A,{values={'gear','appearance'},mode='all'},false))
assert(T:matches(index.modules.A,{values={'presentation'},mode='any'},false))
assert(not T:matches(index.modules.A,{values={'gear','audio'},mode='all'},false))
assert(T:matches(index.modules.A,{values={'fix'},mode='all'},true))
assert(not T:matches(index.modules.A,{values={'adult'},mode='any'},true))
print('PASS canonical taxonomy, multi-parent placements, distinct counts, file handoff, preferred groups and independent filters')
