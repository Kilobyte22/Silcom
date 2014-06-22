fs.TempFS = class('TempFS')
fs.TempFSFilesystem = class('TempFSFilesystem')

local t = fs.TempFS
local f = fs.TempFSFilesystem

function f:initialize()
    self.files = {}
end

function f:open(file, mode)
    return vfs.BasicFileHandle(self, mode, file)
end

function f:write(file, text)
    local f = self.files
    if not f[file] then f[file] = '' end
    f[file] = f[file]..text
end

function f:read(file)
    return self.files[file]
end

function t:makeFileSystem(filehandle, options)
    return f()
end

vfs.registerFileSystem('tempfs', fs.TempFS())