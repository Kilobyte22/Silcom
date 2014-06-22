local function main(...)
    _OSVERSION = "Silcom 0.0.1"
    do
        _CONTEXT = 'init'
        local component = component
        local computer = computer
        local unicode = unicode

        -- Low level dofile implementation to read filesystem libraries.
        local rom = {}
        function rom.invoke(method, ...)
            return component.invoke(computer.getBootAddress(), method, ...)
        end
        function rom.open(file) return rom.invoke("open", file) end
        function rom.read(handle) return rom.invoke("read", handle, math.huge) end
        function rom.close(handle) return rom.invoke("close", handle) end
        function rom.inits(file) return ipairs(rom.invoke("list", "boot")) end
        function rom.isDirectory(path) return rom.invoke("isDirectory", path) end

        logfile = rom.invoke('open', '/boot.log', 'w')
        function log(message)
            rom.invoke('write', logfile, message..'\n')
        end
        function closelog()
            rom.invoke('close', logfile)
        end

        -- Report boot progress if possible.
        local gpu, screen = component.list("gpu")(), component.list("screen")()
        local w, h
        if gpu and screen then
            component.invoke(gpu, "bind", screen)
            w, h = component.invoke(gpu, "getResolution")
            component.invoke(gpu, "setResolution", w, h)
            component.invoke(gpu, "setBackground", 0x000000)
            component.invoke(gpu, "setForeground", 0xFFFFFF)
            component.invoke(gpu, "fill", 1, 1, w, h, " ")
        end
        local y = 1
        function status(msg)
            log(msg)
            if gpu and screen then
                component.invoke(gpu, "set", 1, y, msg)
                if y == h then
                    component.invoke(gpu, "copy", 1, 2, w, h - 1, 0, -1)
                    component.invoke(gpu, "fill", 1, h, w, 1, " ")
                else
                    y = y + 1
                end
            end
        end

        status("Booting " .. _OSVERSION .. "...")

        -- Custom low-level loadfile/dofile implementation reading from our ROM.
        local function loadfile(file)
            status("> " .. file)
            local handle, reason = rom.open(file)
            if not handle then
                error("Could not load "..file..": "..tostring(reason))
            end
            local buffer = ""
            repeat
                local data, reason = rom.read(handle)
                if not data and reason then
                    error(reason)
                end
                buffer = buffer .. (data or "")
            until not data
            rom.close(handle)
            return load(buffer, "=" .. file)
        end

        local function dofile(file)
            local program, reason = loadfile(file)
            if program then
                local result = table.pack(pcall(program))
                if result[1] then
                    return table.unpack(result, 2, result.n)
                else
                    error(result[2])
                end
            else
                error(reason)
            end
        end

        status("Initializing package management...")

        -- Load file system related libraries we need to load other stuff moree
        -- comfortably. This is basically wrapper stuff for the file streams
        -- provided by the filesystem components.
        local package = dofile("/lib/package.lua")

        do
            -- Unclutter global namespace now that we have the package module.
            _G.component = nil
            _G.computer = nil
            _G.process = nil
            _G.unicode = nil

            -- Initialize the package module with some of our own APIs.
            package.preload["buffer"] = loadfile("/lib/buffer.lua")
            package.preload["component"] = function() return component end
            package.preload["computer"] = function() return computer end
            package.preload["filesystem"] = loadfile("/lib/filesystem.lua")
            package.preload["io"] = loadfile("/lib/io.lua")
            package.preload["unicode"] = function() return unicode end

            -- Inject the package and io modules into the global namespace, as in Lua.
            _G.package = package
            _G.io = require("io")
        end

        status("Initializing file system...")

        -- Mount the ROM and temporary file systems to allow working on the file
        -- system module from this point on.
        local filesystem = require("filesystem")
        filesystem.mount(computer.getBootAddress(), "/")

        status("Running boot scripts...")

        -- Run library startup scripts. These mostly initialize event handlers.
        local scripts = {}
        for _, file in rom.inits() do
            local path = "boot/" .. file
            if not rom.isDirectory(path) then
                table.insert(scripts, path)
            end
        end
        table.sort(scripts)
        for i = 1, #scripts do
            dofile(scripts[i])
        end

        -- Initialize process module.
        -- require("process").install("/init.lua", "init")

        status("Initializing components...")

        for c, t in component.list() do
            computer.pushSignal("component_added", c, t)
        end
        -- os.sleep(0.5) -- Allow signal processing by libraries.
        computer.pushSignal("init") -- so libs know components are initialized.

    end

    local computer = require("computer") -- TODO: remove require
    --local event = require("event")

    _CONTEXT = 'kernel'

    local test, initcb
    do
        local _ENV = {syscall = coroutine.yield, tostring = tostring}
        initcb = function()
            syscall('panic', 'test')
        end
        test = function()
            local pid = syscall('getpid')
            for i = 1, 5 do
                syscall('log', 'Hello from process '..tostring(pid))
            end
        end
    end

    init = sched.Process(nil, {}, test)
    init2 = sched.Process(nil, {}, test)
    init3 = sched.Process(nil, {}, test)

    status('Starting scheduler')

    local free, total = math.floor(computer.freeMemory() / 1024), math.floor(computer.totalMemory() / 1024)
    local used = total - free
    log('Memory used: '..used..'k of '..total..'k | Free: '..free..'k')

    sched.run()

    return
--[[
    while true do
        require("term").clear()
        io.write(_OSVERSION .. " (" .. math.floor(computer.totalMemory() / 1024) .. "k RAM)\n")
        local result, reason = os.execute(os.getenv("SHELL"))
        if not result then
            io.stderr:write((tostring(reason) or "unknown error") .. "\n")
            print("Press any key to continue.")
            os.sleep(0.5)
            event.pull("key")
        end
    end
    ]]
end

-- todo: fancy handling
local args = {...}

local function runmain()
    return main(table.unpack(args))
end

local function ehdl(m)
    if type(m) == 'table' then
        local text = m.message..'\n'..m.bt
        return text
    else
        return 'Uncaught error: '..m..'\n'..debug.traceback()
    end
end

local s, m = xpcall(runmain, ehdl)
pcall(function() 
    log('~~ERROR~~')
    log(m)
    closelog()
end)
if not s then
    error(m)
end

error('Computer terminated unexpectedly')