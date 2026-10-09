-- Parse mod.txt as data: colon-separated fields, brace lists and -- comments.
-- No inspected file is loaded as Lua or executed.
local M={}
local Json=require('mcs_module_json')
function M.decode(text)
    assert(type(text)=='string' and #text<=1048576 and utf8.len(text),'invalid mod.txt')
    text=text:gsub('^\239\187\191','')
    local i,n=1,#text
    local function skip()
        while i<=n do
            if text:sub(i,i):match('%s') then i=i+1
            elseif text:sub(i,i+1)=='--' then i=(text:find('\n',i+2,true) or n)+1
            else break end
        end
    end
    local function atom()
        skip()
        local quote=text:sub(i,i)
        if quote=='"' or quote=="'" then
            i=i+1;local parts={}
            while i<=n do
                local c=text:sub(i,i);i=i+1
                if c==quote then return table.concat(parts) end
                assert(c:byte()>=32,'control character in mod.txt')
                if c=='\\' then
                    c=text:sub(i,i);i=i+1
                    c=({n='\n',r='\r',t='\t',['\\']='\\',['"']='"',["'"]="'"})[c]
                    assert(c,'invalid mod.txt escape')
                end
                parts[#parts+1]=c
            end
            error('unterminated mod.txt string')
        end
        local token=text:sub(i):match('^[%w_%.%-]+')
        assert(token,'expected mod.txt value at byte '..i);i=i+#token
        if token=='true' then return true elseif token=='false' then return false end
        return tonumber(token) or token
    end
    local value
    local function fields(close,depth)
        local result={}
        skip()
        while i<=n and (not close or text:sub(i,i)~=close) do
            local key=atom();assert(type(key)=='string','invalid mod.txt field')
            skip();assert(text:sub(i,i)==':','expected mod.txt colon');i=i+1
            assert(result[key]==nil,'duplicate mod.txt field: '..key)
            result[key]=value(depth+1);skip()
            if text:sub(i,i)==',' then i=i+1;skip()
            elseif i<=n and (not close or text:sub(i,i)~=close) then error('expected mod.txt comma') end
        end
        return result
    end
    value=function(depth)
        assert(depth<=64,'mod.txt nesting limit');skip()
        local c=text:sub(i,i)
        if c~='{' and c~='[' then return atom() end
        local close=c=='{' and '}' or ']';i=i+1;skip()
        if text:sub(i,i)==close then i=i+1;return {} end
        local start=i;atom();skip();local object=text:sub(i,i)==':'
        i=start;local result={}
        if object then result=fields(close,depth)
        else
            while true do
                result[#result+1]=value(depth+1);skip()
                if text:sub(i,i)==close then break end
                assert(text:sub(i,i)==',','expected mod.txt list comma');i=i+1;skip()
                if text:sub(i,i)==close then break end
            end
        end
        assert(text:sub(i,i)==close,'unclosed mod.txt container');i=i+1
        return result
    end
    skip()
    local result=text:sub(i,i)=='{' and value(0) or fields(nil,0)
    skip();assert(i>n and type(result)=='table','invalid trailing mod.txt content')
    return result
end
function M.read(folder,read)
    local txt=read(folder..'/mod.txt')
    if txt then return M.decode(txt),'mod.txt' end
    local json=read(folder..'/mod.json')
    return json and Json.decode(json) or {},json and 'mod.json' or nil
end
return M
