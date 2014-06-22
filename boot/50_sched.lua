sched = {}

local pid = nil

local processes = {}
local pids = {}
local nextid = 1
local cthread

sched.Process = class('Process')
sched.Thread = class('Thread')

-- TODO: add weak table for processes, remove from strong on exit. if no other process points to it, it gets killed

function sched.byPid(pid)
    return processes[pid]
end

function sched.current()
    return pid and processes[pid]
end

function sched.currentThread()
    return cthread
end

function sched.run()
    local i = 1
    while true do
        -- os.sleep(0) -- maybe less frequent?
        if #pids == 0 then
            panic('No processes to execute')
        end
        if i > #pids then
            i = 1
        end
        processes[pids[i]]:resume()
        i = i + 1
    end
end

function sched.Process:initialize(parent, envvars, callback)
    self.envvars = envvars
    self.parent = parent
    self.id = nextid
    self.fds = {}
    self.nexttid = 1
    self.mainthread = sched.Thread(self, callback, {})
    self.terminated = false
    self.threads = {self.mainthread}
    self.nextthread = 1
    self._P = {}
    self.handlers = {}
    self.signals = {}
    -- handle environment

    nextid = nextid + 1

    processes[self.id] = self
    table.insert(pids, self.id)
end

function sched.Process:kill(id)
    table.insert(self.signals, id)
    log('Signal '..tostring(id)..' (SIG'..signals[id]..') => PID '..tostring(self.id))
end

function sched.Process:resume()
    pid = self.id
    if #self.signals > 0 then -- signals scheduled?
        if not self.forcethread then -- already handling a signal?
            log('uwot')
            self.forcethread = sched.Thread(self, signal.handle, {self, self.signals[1]})
        end
        if not self.forcethread:resume() then
            self.forcethread = nil
            table.remove(self.signals, 1)
        end
    else
        if #self.threads == 0 then
            panic('Process '..tostring(self.id)..' seems to have no threads')
        end
        if self.nexttid > #self.threads then
            self.nexttid = 1
        end
        status(tostring(self.nexttid))
        self.threads[self.nexttid]:resume()
        self.nexttid = self.nexttid + 1
    end
    pid = nil
end

function sched.Process:exit(code)
    self.exitcode = code

    for i = 1, #self.threads do 
        self.threads[1]:exit() -- each thread removes itself from the list, so next one is always first one
    end
    callHook('sched:process_death', self)

    self.routine = nil
    self.args = nil
    self.env = nil
    self.terminated = true
    for i = 1, #self.fds do
        self.fds[i]:close() -- handle pid recycling of children
    end
    local idx = table.find(pids, self.id)
    if idx then
        table.remove(pids, idx)
    end
end

function sched.Process:dispose()
    callHook('sched:process_disposal', self)
    local idx = table.find(pids, self.id)
    if idx then
        table.remove(pids, idx)
    end
    processes[self.id] = nil
end

-------------------

function sched.Thread:initialize(process, callback, args)
    self.process = process
    self.routine = coroutine.create(callback)
    self.args = args
    self.id = process.nexttid
    self._T = {}

    log('Init thread '..tostring(self.id))

    process.nexttid = process.nexttid + 1
end

function sched.Thread:resume()
    cthread = self
    _CONTEXT = 'process'
    local syscalldata = table.pack(coroutine.resume(self.routine, table.unpack(self.args)))
    _CONTEXT = 'kernel'
    if not syscalldata[1] then
        -- TODO: set process error message
        self:exit()
        self.process:kill(signals.ABRT)
        log('Uncaught error: '..tostring(syscalldata[2]))
        return false
    end
    if coroutine.status(self.routine) == 'dead' then
        self:exit()
        return false
    end
    _CONTEXT = 'syscall'
    self.args = table.pack(syscall.execute(table.unpack(syscalldata, 2))) -- maybe compact even more to improve speed?
    _CONTEXT = 'kernel'
    cthread = nil
    return true
end

function sched.Thread:exit()
    callHook('sched:thread_death', self)
    table.remove(self.process.threads, table.find(self.process.threads, self))
    log('Thread '..tostring(self.id)..' of process '..tostring(self.process.id)..' died. Process termination status: '..tostring(self.process.terminated))
    if self.id == 1 and not self.process.terminated then
        self.process:exit(0)
    end
end

hook(
    'sched:process_death',
    function(process)
        if process.id == 1 then 
            panic('attempt to kill init') 
        end
    end
)