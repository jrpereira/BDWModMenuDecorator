package.path='Scripts/?.lua;Scripts/vendor/?.lua;'..package.path
local Data=require('menu_data')
local Presentation=require('presentation')

local function fails(pattern,menu,options)
    local ok,err=pcall(Data.manifest,menu,options)
    assert(not ok,'expected failure: '..pattern)
    assert(tostring(err):find(pattern,1,true),'expected '..pattern..', got '..tostring(err))
end
local function menu()
    return {storage={file='config.ini',section='Settings'},
        groups={{id='MCT_1',label='Layout',level=3},{id='Notes',heading=false,visible={field='Style',values={1}}}},
        fields={
            {id='Style',group='MCT_1',label='Style',default=0,tabs=true,level=1,
                choices={{value=0,label='Swap'},{value=1,label='Stack',note='Two rows'},
                    {value=2,label='Ring',module='9_ModCore_Example'}}},
            {id='Size',group='MCT_1',label='Size',default=100,range={min=10,max=200,step=5,suffix='%'},
                description='How large; really.',relabel={field='Style',values={[1]='Stack size',[2]='Ring size'}}},
            {id='Open',group='Notes',label='Open the slot',default=0,link='controls:visuals',
                choices={{value=0,label='Open'}},tabs=true,level=5},
            {id='Info',group='Notes',label='Info',default=0,readOnly=true,choices={{value=0,label='Ready'}}},
        }}
end
local text=Data.manifest(menu(),{moduleName=function(folder) return folder=='9_ModCore_Example' and 'Example Mod' end})
local function section(name)
    return assert((text..'\n'):match('%['..name:gsub('%.','%%.')..'%]\n(.-)\n\n'),'missing section '..name)
end
-- Groups keep their order and only used ones are written; a label differs from the id.
assert(text:find('[Category.MCT_1]',1,true)<text:find('[Category.Notes]',1,true))
assert(section('Category.MCT_1'):find('mcLabel=Layout',1,true) and section('Category.MCT_1'):find('mcLevel=3',1,true))
local notes=section('Category.Notes')
assert(notes:find('mcHeading=0',1,true) and notes:find('VisibleWhen=Style',1,true)
    and notes:find('VisibleValues=1',1,true) and not notes:find('mcLabel',1,true))
local style=section('Setting.Style')
assert(style:find('Type=picker',1,true) and style:find('PresetValues=0|1|2',1,true)
    and style:find('PresetLabels=Swap|Stack|Ring',1,true) and style:find('mcType=tab',1,true)
    and style:find('mcHeading=1',1,true) and style:find('mcChoiceNotes=1:Two rows;2:Example Mod',1,true)
    and style:find('ConfigFile=config.ini',1,true) and style:find('ConfigSection=Settings',1,true)
    and style:find('ConfigKey=Style',1,true))
local size=section('Setting.Size')
assert(size:find('Type=integer',1,true) and size:find('Minimum=10',1,true) and size:find('Maximum=200',1,true)
    and size:find('Step=5',1,true) and size:find('Suffix=%',1,true) and size:find('Default=100',1,true)
    and size:find('mcLabelWhen=Style',1,true) and size:find('mcLabels=1:Stack size;2:Ring size',1,true))
-- Action and read-only rows are never stored.
local open=section('Setting.Open')
assert(open:find('mcNavigation=1',1,true) and open:find('mcLinkPage=controls:visuals',1,true)
    and open:find('mcLevel=5',1,true) and not open:find('ConfigFile',1,true))
local info=section('Setting.Info')
assert(info:find('mcReadOnly=1',1,true) and not info:find('ConfigFile',1,true))
-- DMM needs two choices, so a single one repeats.
assert(open:find('PresetValues=0|1',1,true) and open:find('PresetLabels=Open|Open',1,true)
    and info:find('PresetLabels=Ready|Ready',1,true))
-- Without moduleName a module note names the folder; without storage nothing is stored.
local plain=menu();plain.storage=nil
local other=Data.manifest(plain)
assert(other:find('2:9_ModCore_Example',1,true) and not other:find('ConfigFile',1,true))

-- The manifest is what DMM and ModCoreSettings presentation read.
local choicesPath=os.getenv('DMM_CHOICES_PATH')
if choicesPath then
    local Choices=dofile(choicesPath)
    local items=Choices.parse(text)
    assert(#items==4 and items[1].id=='Style' and items[2].kind=='slider' and items[2].minimum==10,
        'DMM parses the compiled manifest')
    Presentation.parse(text,items)
    assert(items[1].mcHeader and items[1].mcTabs and items[1].mcChoiceNotes[2]=='Example Mod')
    assert(items[1].mcGroup.label=='Layout' and items[3].mcGroup.heading==false)
else
    print('SKIP DMM parse: DMM_CHOICES_PATH is not set')
end

-- Rejected menu data names its problem.
local function with(change) local m=menu();change(m);return m end
fails('unknown field',with(function(m) m.fields[1].Type='picker' end))
fails('needs choices or range',with(function(m) m.fields[2].range=nil end))
fails('default is not a choice',with(function(m) m.fields[1].default=7 end))
fails('default outside range',with(function(m) m.fields[2].default=500 end))
fails('unknown group',with(function(m) m.fields[1].group='Missing' end))
fails('duplicate field',with(function(m) m.fields[2].id='Style' end))
fails('duplicate group',with(function(m) m.groups[2].id='MCT_1' end))
fails('tabs take at most eight',with(function(m)
    for n=3,9 do m.fields[1].choices[#m.fields[1].choices+1]={value=n,label='C'..n} end end))
fails('only one level-1',with(function(m) m.fields[3].level=1 end))
fails('source must be a picker',with(function(m) m.fields[2].relabel.field='Size' end))
fails('value outside the source choices',with(function(m) m.groups[2].visible.values={9} end))
fails('invalid Style label',with(function(m) m.fields[1].label='A|B' end))
fails('storage file must be relative',with(function(m) m.storage.file='../x.ini' end))
fails('a choice has a note or a module',with(function(m) m.fields[1].choices[2].module='X' end))
fails('a read-only row needs choices and no action',with(function(m) m.fields[4].action=true end))
print('PASS menu data compiles to the manifest DMM and presentation read, and rejects invalid data')
