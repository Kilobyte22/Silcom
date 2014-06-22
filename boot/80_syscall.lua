syscall = {}

local syscalls = {}

local function register(name, callback)
    log('registering syscall '..name)
    syscalls[name] = callback
end

function syscall.execute(name, ...)
    log('Running syscall '..name)
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

register('panic', function (...) -- VERY temporary
    panic(...)
end)

register('getpid', function ()
    return sched.current().id
end)

register('log', log)

register('open', function (name, mode)
    return vfs.open(name, mode)
end)

register('write', function (handle, text)
    handle:write('text')
end)

register('read', function (handle)
    return handle:read()
end)