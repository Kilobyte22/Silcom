vfs = {}

local mounts = {}
local mountCache = {}
local filesystems = {}
fs = {} -- namespace for file system classes
setmetatable(mountCache, {__mode = 'k'})

function vfs.resolveMount(path) -- if anyone wants to increase performance, go ahead
    local parts = vfs.split(path)
    for i = #parts, 1, -1 do
        local path1 = "/"..table.concat(parts, '/', 1, i)
        local m = mounts[path]
        if m then
            local path2 = "/" + table.concat(parts, i + 1)
            return m, path2
        end
    end
    return mounts['/'], path
end

function vfs.open(file, mode)
    local driver, path = vfs.resolveMount(file)
    return driver.fs:open(path, mode)
end

function vfs.split(path) -- shamelessly stolen from OpenOS :P
    repeat local n; path, n = path:gsub("//", "/") until n == 0
    local parts = {}
    for part in path:gmatch("[^/]+") do
        table.insert(parts, part)
    end
    local i = 1
    while i <= #parts do
        if parts[i] == "." then
            table.remove(parts, i)
        elseif parts[i] == ".." then
            table.remove(parts, i)
            i = i - 1
            if i > 0 then
                table.remove(parts, i)
            else
                i = 1
            end
        else
            i = i + 1
        end
    end
    return parts
end

--[[
    @param driver a reference to the file system driver
    @param filehandle a file handle (the object, not the id) of whatever should be mounted. nil for things like devfs or tempfs
    @param mountpoint the directory to mount the device in
    @param options mount options
]]
function vfs.mount(driver, filehandle, mountpoint, options)
    if mounts[mountpoint] then
        return false, 'Mountpoint occupied'
    end
    local fs = driver:makeFileSystem(filehandle, options)
    mounts[mountpoint] = {
        fs = fs,
        driver = driver,
        options = options
    }
    return true
end

function vfs.registerFileSystem(name, driver)
    filesystems[name] = driver
end

function vfs.fsFromName(name)
    return filesystems[name]
end

vfs.BasicFileHandle = class('BasicFileHandle')

function vfs.BasicFileHandle:initialize(driver, mode, descriptor)
    self.driver = driver
    self.mode = mode
    self.handle = descriptor
end

function vfs.BasicFileHandle:write(text)
    self.driver:write(self.handle, text)
end

function vfs.BasicFileHandle:read()
    return self.driver:read(self.handle)
end