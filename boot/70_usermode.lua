-- this file provides usermode wrappers for certain kernel functions

-- Concept: put all usermode metatables into a sub entry. Then provide kernel mode wrappers


umode = {}
local mtEntries = {
    '__index', -- todo: custom wrapper
    '__newindex',
    '__tostring',
    '__call',
    '__len',

    '__unm',
    '__add',
    '__sub',
    '__mul',
    '__div',
    '__mod',
    '__pow',
    '__concat',

    '__lt',
    '__le'
}
local __eq

function umode.proxymt(metatable)
    local function mkproxy(name)
        local ret = function(...)
            if _CONTEXT == 'process' and metatable[name] then
                return metatable[name](...)
            end
        end
    end
    local ret = {__data = metatable}
    ret.__index = function (t, idx)
        -- todo
    end
    ret.__eq = __eq
    for i = 1, #mtEntries do
        local v = mtEntries[k]
        ret[v] = mkproxy(v)
    end
    return ret
end

__eq = function (t1, t2)
    if _CONTEXT == 'process' then
        local mt1, mt2 = getmetatable(t1), getmetatable(t2)
        if mt1.__data.__eq and rawequal(mt1.__data.__eq, mt2.__data.__eq) then
            return mt1.__data.__eq(mt1, mt2)
        else
            return rawequal(t1, t2)
        end
    end
end

function umode.setmetatable(tab, mt, ...)
    local currentmt = getmetatable(tab)
    if currentmt and type(currentmt) ~= 'table' then
        error('Metatable locked')
    end
    local lockmt = currentmt.__mt
    if lockmt then
        if type(lockmt) == 'table' and lockmt.set and lockmt.get then
            lockmt.set(tab, mt, ...)
        else
            return lockmt
        end
    else
        setmetatable(tab, mt)
    end
end

function umode.rawset(tab, key, value)
    checkArg(1, tab, 'table')
    local mt = getmetatable(tab)
    if type(mt) == 'table' and mt.__rawset then
        mt.__rawset(tab, key, value)
    else
        rawset(tab, key, value)
    end
end