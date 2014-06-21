signal = {}

local default = {}

function signal.handle(process, signal)
    if not (signal == signals.STOP or signal == signals.CONT or signal == signals.KILL) then
        local h = process.handlers[signal]
        if h then
            h(signal)
            return
        end
    end
    if default[signal] then
        sefault[signal](process, signal)
    end
end

signals = {
    'HUP',  -- TTY died.
    'INT',  -- ^C
    'QUIT', -- user quit request
    'ILL',  -- who knows if this is even needed...
    'TRAP', -- maybe if we get into debugging
    'ABRT', -- in case stuff goes wrong (process can send this using abort(), abnormal exit)
    'IOT',  -- IOT trap (idk what it is)
    'EMT',  -- ???
    'BUS',  -- another version of segfault?
    'FPE',  -- doesn't really make sense, we have errors for that after all
    'KILL', -- *shoots process*
    'USR1',
    'SEGV', -- shouldn't have any use either
    'USR2',
    'PIPE', -- me might use this?
    'ALRM', -- idk if we need this
    'TERM', -- would you please exit :) *holds gun*
    'CHLD', -- child status changed
    'CONT', -- resumes execution
    'STOP', -- pauses process execution
    'STP',  -- user sent stop from kb
    'TIN',  -- tty background input
    'TOU',  -- tty background output
    'SYS'   -- invalid system call
}

for i = 1, #signals do
    local v = signals[i]
    signals[v] = i
end

local function exitfunc(process, signal)
    process:exit(128 + signal)
end

local exitsig = {'HUP', 'INT', 'QUIT', 'ILL', 'ABRT', 'BUS', 'KILL', 'SEGV', 'PIPE', 'TERM', 'SYS'}
for i = 1, #exitsig do
    local v = exitsig[i]
    default[v] = exitfunc
end