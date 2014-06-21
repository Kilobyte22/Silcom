function class(name, super)
    local class = {}
    class.__index = class
    local function init(self, ...)
        local o = {}
        setmetatable(o, self)
        if self.initialize then o:initialize(...) end
        return o
    end
    return setmetatable(class, {__index = super, __call = init})
end