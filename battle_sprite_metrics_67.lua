-- Fixed full-animation extents, verified against the actual source bytes.
-- Unknown/replaced artwork fails open to the renderer's own measured fallback.
return function(mod, data)
  local M = { apiVersion = 1 }
  local verified = {}
  local images = setmetatable({}, { __mode = 'k' })
  local function relative(path)
    if type(path) ~= 'string' then return nil end
    local prefix = tostring(mod.path or '') .. '/'
    if path:sub(1, #prefix) == prefix then path = path:sub(#prefix + 1) end
    if path:sub(1, 7) ~= 'assets/' or path:find('..', 1, true) then return nil end
    return path
  end
  function M.forPath(path)
    path = relative(path)
    if not path then return nil end
    if verified[path] ~= nil then return verified[path] or nil end
    local root, name = path:match("^(.*)/([^/]+)$")
    local values = root and data[root]
    if not values then return nil end
    local line = ("\n" .. values):match("\n" .. name:gsub("([^%w])", "%%%1") .. "|([^\n]+)")
    if not line then return nil end
    local expected, extent = line:match("^([a-f0-9]+)|(%d+)$")
    extent = tonumber(extent)
    if not expected or not extent then return nil end
    if verified[path] == nil then
      local optional = mod.exports and mod.exports.optionalPokemonAssets
      local raw = mod:read(path)
      local digest
      if type(raw) == 'string' and optional and optional.imageHash then
        local ok, value = pcall(optional.imageHash, raw)
        if ok then digest = value end
      elseif optional and optional.metadata then
        -- The optional-content resolver validates the downloaded file against
        -- this manifest before returning its Image. No download is requested.
        local meta = optional.metadata(path)
        digest = meta and meta.sha256
      end
      if digest then verified[path] = digest == expected and extent or false end
    end
    if verified[path] then return verified[path] end
    return nil
  end
  function M.bindImage(image, path)
    if image then images[image] = M.forPath(path) end
    return image
  end
  function M.forImage(image)
    return image and images[image] or nil
  end
  return M
end
