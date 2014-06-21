sandbox = {}

local function plocal()
    local ret = {}
    local mt = {__mt = "Fuck off."}
    setmetatable(ret, mt)

    function mt.__next(tab, idx)
        return next(sched.current()._P, idx)
    end
    function mt.__index(tab, idx)
        return sched.current()._P[idx]
    end
    function mt.__newindex(tab, idx, value)
        sched.current()._P[idx] = value
    end
    return ret
end

local function tlocal()
    local ret = {}
    local mt = {__mt = "Fuck off."}
    setmetatable(ret, mt)

    function mt.__next(tab, idx)
        return next(sched.currentThread()._T, idx)
    end
    function mt.__index(tab, idx)
        return sched.currentThread()._T[idx]
    end
    function mt.__newindex(tab, idx, value)
        sched.currentThread()._T[idx] = value
    end
    return ret
end

function sandbox.create()
    local sbx = {}
    setmetatable(sbx, {__mt = "fuck off."}) -- no usermode metatable tampering...
    sbx.string = deepcopy(string)
    sbx.math = deepcopy(math)
    sbx.bit = deepcopy(bit)
    sbx._G = sbx
    sbx._P = plocal()
    sbx._T = tlocal()
    callHook('sandbox:create', sbx)
    return sbx
end