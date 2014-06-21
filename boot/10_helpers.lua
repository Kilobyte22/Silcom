function table.find(t, val)
    for k, v in pairs(t) do
        if v == val then
            return k
        end
    end
end

function deepcopy(inp, cache)
    cache = cache or {}
    local t = type(inp)
    if t == 'string' or t == 'number' or t == 'function' or t == 'boolean' or t == 'nil' then
        return inp
    elseif t == 'userdata' then
        if cache[inp] then
            return cache[inp] -- no infinite recursion
        end
        local mt = getmetatable(inp)
        local ret
        if type(mt) == 'table' and mt.__clone then
            ret = mt.__clone(inp)
        else 
            ret = inp
        end
        cache[inp] = ret
        return ret
    elseif t == 'table' then
        if cache[inp] then
            return cache[inp] -- no infinite recursion
        end
        local mt = getmetatable(inp)
        local ret
        if type(mt) == 'table' and mt.__clone then
            ret = mt.__clone(inp)
            cache[inp] = ret
        else 
            ret = {}
            cache[inp] = ret
            for k, v in pairs(inp) do
                ret[deepcopy(k, cache)] = deepcopy(v, cache)
            end
        end
        return ret
    else
        error("unknown type: "..t)
    end
end

function to_s(input, indent, cache)
    indent = indent or ''
    cache = cache or {}
    local t = type(input)
    if t == 'nil' or t == 'number' or t == 'boolean' or t == 'userdata' or t == 'function' then
        return tostring(input)
    elseif t == 'string' then
        return '"'..input:gsub('\\', '\\\\'):gsub('"', '\\"')..'"'
    elseif t == 'table' then
        if cache[input] then
            return '('..tostring(input)..') {...}'
        end
        cache[input] = true
        local ret = '('..tostring(input)..') {'
        for k, v in pairs(input) do
            ret = ret..'\n'..indent..'    '..to_s(k, indent..'    ', cache)..' => '..to_s(v, indent..'    ', cache)..','
        end
        ret = ret..'\n'..indent..'}'
        return ret
    else
        error("unknown type: "..t)
    end
end