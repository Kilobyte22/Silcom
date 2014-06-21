syscall = {}

local syscalls = {}

local function register(name, callback)
    syscalls[name] = callback
end

local function syscall.execute(name, ...)
    local call = syscalls[name]
    if call then
        return call(...)
    else
        sched.current():kill(signals.SYS)
    end
end

register('print', function (...) -- VERY temporary
    print('[PID: '..tostring(sched.current().id)..'] ', ...)
end)