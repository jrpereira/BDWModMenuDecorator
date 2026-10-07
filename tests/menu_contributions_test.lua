package.path='Scripts/?.lua;Scripts/vendor/?.lua;'..package.path
local Menu=require('menu_contributions')

local function shared()
    local values={}
    return {values=values,
        GetSharedVariable=function(_,key) return values[key] end,
        SetSharedVariable=function(_,key,value) values[key]=value end}
end
local function files()
    local store={}
    return store,function(path,content) store[path]=content end,
        function(path) local had=store[path]~=nil;store[path]=nil;return had end
end
local function fails(pattern,contributor,contribution)
    local ok,err=Menu.validate(contributor,contribution)
    assert(not ok and err:find(pattern,1,true),'expected '..pattern..', got '..tostring(err))
end

local manifest='[Setting.Speed]\nId=Speed\nType=picker\nConfigFile=config.ini\n'
local pages={
    {id='MCT',name='ModCore Templates',attach='3_ModCore_Templates',description='Line one\nLine \\two'},
    {id='MCT.vehicles',name='Vehicles',under='MCT',manifest=manifest,configDirectory='C:/Mods/MCT/Scripts/cache'},
    {id='MCT.module.Visual',name='Visual',attach='Visual',group='module',author='A',version='1.2',
        manifest=manifest,configDirectory='/mods/visual',visible=false},
}
assert(Menu.validate('MCT',{pages=pages}))
fails('not owned','MCT',{pages={{id='Other',name='x'}}})
fails('not owned','MCT',{pages={{id='MCTX',name='x'}}})
fails('duplicate page id','MCT',{pages={{id='MCT',name='a'},{id='MCT',name='b'}}})
fails('unknown field mcLinkProvider','MCT',{pages={{id='MCT',name='a',mcLinkProvider='x'}}})
fails('under must name an earlier page','MCT',{pages={{id='MCT.a',name='a',under='MCT'},{id='MCT',name='b'}}})
fails('exclusive','MCT',{pages={{id='MCT',name='a'},{id='MCT.b',name='b',under='MCT',attach='x'}}})
fails('configDirectory','MCT',{pages={{id='MCT',name='a',manifest=manifest}}})
fails('must be absolute','MCT',{pages={{id='MCT',name='a',manifest=manifest,configDirectory='cache'}}})
fails('configDirectory needs a manifest','MCT',{pages={{id='MCT',name='a',configDirectory='/x'}}})
fails('folder name','MCT',{pages={{id='MCT',name='a',attach='Mods/x'}}})
fails('invalid page 1 group','MCT',{pages={{id='MCT',name='a',group='core'}}})
fails('invalid page 1 name','MCT',{pages={{id='MCT',name='a\nb'}}})
fails('unknown contribution field','MCT',{pages={},aggregate={}})

-- Round trip through descriptor and manifest files.
local descriptor,written=Menu.encode('MCT',4,{pages=pages})
assert(#written==2 and written[1].name=='mcs_menu.4.1.ini' and written[2].name=='mcs_menu.4.2.ini')
local byName={}
for _,file in ipairs(written) do byName[file.name]=file.content end
local decoded=Menu.decode(descriptor,function(name) return assert(byName[name]) end)
assert(decoded.id=='MCT' and decoded.generation==4 and #decoded.pages==3)
for n,page in ipairs(pages) do
    for key,value in pairs(page) do
        assert(decoded.pages[n][key]==value,'round trip '..n..'.'..key)
    end
end
assert(not pcall(Menu.decode,descriptor:gsub('contract=1','contract=2'),function() end))
assert(not pcall(Menu.decode,descriptor:gsub('%[Page%.2%]','[Page.3]'),function(name) return byName[name] end))
assert(not pcall(Menu.decode,descriptor:gsub('mcs_menu%.4%.1','../x'),function(name) return byName[name] end))

-- Rows target another provider's slot from one of the contributor's own manifest pages.
local rows={{page='MCT.vehicles',slot='controls:visuals',settings={'MCT_Template','Other one'}}}
assert(Menu.validate('MCT',{pages=pages,rows=rows}))
local function row(fields)
    local out={page='MCT.vehicles',slot='ModCoreControls:visuals',settings={'A'}}
    for key,value in pairs(fields) do out[key]=value end
    return {pages=pages,rows={out}}
end
fails('page must name a page with a manifest','MCT',row({page='MCT'}))
fails('page must name a page with a manifest','MCT',row({page='Other'}))
fails('slot must belong to another provider','MCT',row({slot='MCT.vehicles:x'}))
fails('invalid row 1 slot address','MCT',row({slot='controls:a-b'}))
fails('invalid row 1 slot address','MCT',row({slot='visuals'}))
fails('invalid row 1 slot address','MCT',row({slot='a:b:c'}))
assert(Menu.address('controls:visuals')=='controls' and select(2,Menu.address('ModCoreControls:visuals'))=='visuals')
assert(Menu.address('ModCoreControls:visuals')=='controls' and Menu.address('Fangdango:x')=='Fangdango')
assert(Menu.provider('ModCoreTemplates.player')=='ModCoreTemplates.player','only whole ModCore<Name> ids shorten')
fails('slot must belong to another provider','ModCoreControls',
    {pages={{id='ModCoreControls',name='C',manifest=manifest,configDirectory='/c'}},
     rows={{page='ModCoreControls',slot='controls:visuals',settings={'A'}}}})
fails('settings must list','MCT',row({settings={}}))
fails('duplicate setting A','MCT',row({settings={'A','A'}}))
fails('cannot contain |','MCT',row({settings={'A|B'}}))
fails('unknown field label','MCT',row({label='x'}))
fails('rows must be a list','MCT',{pages=pages,rows={x={}}})
descriptor,written=Menu.encode('MCT',5,{pages=pages,rows=rows})
assert(descriptor:find('contract=2',1,true),'rows need contract 2')
byName={}
for _,file in ipairs(written) do byName[file.name]=file.content end
decoded=Menu.decode(descriptor,function(name) return assert(byName[name]) end)
assert(#decoded.rows==1 and decoded.rows[1].slot=='controls:visuals'
    and table.concat(decoded.rows[1].settings,',')=='MCT_Template,Other one' and decoded.rows[1].page=='MCT.vehicles')
assert(not pcall(Menu.decode,descriptor:gsub('contract=2','contract=1'),function(name) return byName[name] end))
assert(not pcall(Menu.decode,descriptor:gsub('%[Row%.1%]','[Row.2]'),function(name) return byName[name] end))
assert(not pcall(Menu.decode,descriptor..'[Page.4]\nid=MCT.late\nname=Late\n',function(name) return byName[name] end),
    'pages come before rows')
assert(Menu.decode(Menu.encode('MCT',6,{pages={pages[1]}}),function() end).rows==nil)

-- Link pages open another provider's slot; they carry no manifest or children.
local linked={pages={{id='MCT',name='Templates'},
    {id='MCT.module.Fangdango',name='Fangdango',attach='Fangdango',group='module',link='controls:visuals'}}}
assert(Menu.validate('MCT',linked))
fails('invalid page 1 link address','MCT',{pages={{id='MCT',name='a',link='visuals'}}})
fails('cannot have a manifest','MCT',{pages={{id='MCT',name='a',link='controls:visuals',
    manifest=manifest,configDirectory='/c'}}})
fails('link must open another provider','ModCoreControls',{pages={{id='ModCoreControls',name='a',link='controls:x'}}})
fails('a link page cannot have children','MCT',{pages={{id='MCT',name='a',link='controls:visuals'},
    {id='MCT.b',name='b',under='MCT'}}})
descriptor=Menu.encode('MCT',7,linked)
assert(descriptor:find('contract=2',1,true) and descriptor:find('link=controls:visuals',1,true))
decoded=Menu.decode(descriptor,function() end)
assert(decoded.pages[2].link=='controls:visuals' and decoded.rows==nil)
assert(not pcall(Menu.decode,descriptor:gsub('contract=2','contract=1'),function() end))

-- Publishing flips the channel only after files are written and keeps one older generation.
local host=shared()
local store,write,remove=files()
local writes={}
local publisher=Menu.publisher(host,{id='MCT',directory='/mods/MCT/cache/',write=function(path,content)
    writes[#writes+1]=path
    local generation=path:match('mcs_menu%.(%d+)%.')
    assert(Menu.slot(host.values[Menu.prefix..Menu.hex('MCT')])~=tonumber(generation),'channel moved early')
    write(path,content)
end,remove=remove})
assert(publisher:publish({pages=pages})==1)
local key=Menu.prefix..Menu.hex('MCT')
assert(host.values[key]=='1\n/mods/MCT/cache/mcs_menu.1.ini')
assert(host.values[Menu.index]==Menu.hex('MCT'))
assert(writes[#writes-1]=='/mods/MCT/cache/mcs_menu.1.ini' and writes[#writes]=='/mods/MCT/cache/mcs_menu.generation',
    'descriptor is written after manifests, the counter after the channel moves')
assert(publisher:publish({pages=pages})==2 and publisher:publish({pages={pages[1]}})==3)
assert(store['/mods/MCT/cache/mcs_menu.1.ini']==nil and store['/mods/MCT/cache/mcs_menu.1.1.ini']==nil)
assert(store['/mods/MCT/cache/mcs_menu.2.ini'] and store['/mods/MCT/cache/mcs_menu.3.ini'])
assert(host.values[Menu.index]==Menu.hex('MCT'),'index registers each contributor once')
local before=host.values[key]
assert(not pcall(publisher.publish,publisher,{pages={{id='Other',name='x'}}}))
assert(host.values[key]==before,'a failed publish leaves the previous generation')

-- A restarted publisher continues the generation sequence; withdraw keeps it monotonic.
local again=Menu.publisher(host,{id='MCT',directory='/mods/MCT/cache',write=write,remove=remove})
assert(again:publish({pages={pages[1]}})==4)
again:withdraw()
assert(host.values[key]=='4\n' and store['/mods/MCT/cache/mcs_menu.4.ini']==nil)
assert(again:publish({pages={pages[1]}})==5)
assert(Menu.slot('5\n/x')==5 and select(2,Menu.slot('4\n'))=='' and Menu.slot('junk')==nil)

-- A new launch resets shared variables; the counter file continues generations and cleanup.
local fresh=shared()
local relaunch=Menu.publisher(fresh,{id='MCT',directory='/mods/MCT/cache',write=write,remove=remove,
    read=function(path) return store[path] end})
assert(store['/mods/MCT/cache/mcs_menu.generation']=='5')
assert(relaunch:publish({pages={pages[1]}})==6 and relaunch:publish({pages={pages[1]}})==7)
assert(store['/mods/MCT/cache/mcs_menu.5.ini']==nil,'earlier launch files are cleaned up')
local blank=Menu.publisher(shared(),{id='MCT',directory='/nowhere',write=function() end,remove=remove,
    read=function() return 'garbage' end})
assert(blank:publish({pages={pages[1]}})==1,'an unreadable counter starts from scratch')

local other=Menu.publisher(host,{id='MCC',directory='C:\\Mods\\MCC',write=write,remove=remove})
other:publish({pages={{id='MCC',name='Controls'}}})
assert(host.values[Menu.index]==Menu.hex('MCT')..' '..Menu.hex('MCC'))
assert(not pcall(Menu.publisher,host,{id='MCT',directory='relative'}))
print('PASS menu contribution client validates, round-trips and publishes generations')
