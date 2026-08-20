-- Test-owned writable seam for the public plain-Lua Modkit SDK.
--
-- An external absolute mod checkout is aliased through tests.fs_io, while
-- first-run options and AssetTransform output normally target LÖVE's save
-- filesystem. This overlay keeps only explicitly allowed writes in memory;
-- every unrelated path still reaches the underlying FsIo and fails normally.

return function(T, realModPath, opts)
  opts = opts or {}
  assert(T and T.fs and type(T.fs.new) == "function", "Modkit FsIo required")
  assert(type(realModPath) == "string" and realModPath ~= "",
    "absolute or aliased mod path required")

  local originalNew = T.fs.new
  local originalGetInfo = love.filesystem.getInfo
  local originalRead = love.filesystem.read
  local originalNewImage = love.graphics and love.graphics.newImage
  local memory, disk = {}, nil
  local alias = "mods/" .. realModPath:gsub("/+$", ""):match("[^/]+$")
  local exactDerived = opts.exactDerived or {}
  local derivedPrefix = opts.derivedPrefix
  local active = true
  local memoryFiles = {
    ["options.lua"] = true,
    ["options.lua.tmp"] = true,
    ["options.lua.bak"] = true,
    ["mod_option_schemas.json"] = true,
  }

  local function isMemoryPath(path)
    if memoryFiles[path] or exactDerived[path] then return true end
    return type(derivedPrefix) == "string"
      and path:sub(1, #derivedPrefix) == derivedPrefix
  end

  local function realPath(path)
    if path == alias then return realModPath end
    if path:sub(1, #alias + 1) == alias .. "/" then
      return realModPath .. path:sub(#alias + 1)
    end
    return path
  end

  local function isAliasedPath(path)
    return type(path) == "string"
      and (path == alias or path:sub(1, #alias + 1) == alias .. "/")
  end

  T.fs.new = function(root)
    -- The SDK constructs one FsIo per load. Restore its factory immediately,
    -- so a loader exception cannot leak the constructor seam into another
    -- test even before the caller reaches cleanup().
    T.fs.new = originalNew
    disk = originalNew(root)
    local fs = { root = disk.root }
    function fs.read(path)
      if memory[path] ~= nil then return memory[path] end
      return disk.read(path)
    end
    function fs.write(path, body)
      if isMemoryPath(path) then
        memory[path] = body
        return true
      end
      return disk.write(path, body)
    end
    function fs.getInfo(path)
      if memory[path] ~= nil then return { type = "file" } end
      return disk.getInfo(path)
    end
    function fs.load(path) return disk.load(path) end
    function fs.getDirectoryItems(path) return disk.getDirectoryItems(path) end
    return fs
  end

  if opts.bridgeLove then
    function love.filesystem.getInfo(path, filter)
      if memory[path] ~= nil then
        return (not filter or filter == "file") and { type = "file" } or nil
      end
      if disk and isAliasedPath(path) then
        local info = disk.getInfo(realPath(path))
        if info and (not filter or filter == info.type) then return info end
        return nil
      end
      return originalGetInfo(path, filter)
    end

    function love.filesystem.read(path)
      if memory[path] ~= nil then return memory[path] end
      if disk and isAliasedPath(path) then
        return disk.read(realPath(path))
      end
      return originalRead(path)
    end

    if type(originalNewImage) == "function" then
      function love.graphics.newImage(source, ...)
        if isAliasedPath(source) then source = realPath(source) end
        return originalNewImage(source, ...)
      end
    end
  end

  local sink = { writes = memory }
  function sink.cleanup()
    if not active then return end
    active = false
    T.fs.new = originalNew
    love.filesystem.getInfo = originalGetInfo
    love.filesystem.read = originalRead
    if type(originalNewImage) == "function" then
      love.graphics.newImage = originalNewImage
    end
  end
  return sink
end
