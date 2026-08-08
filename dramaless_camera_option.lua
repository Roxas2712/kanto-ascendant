-- Put the Dramaless-only camera choice beside the renderer controls in the
-- regular OPTIONS screen.  It intentionally stays out of Kanto Ascendant's
-- per-mod manager page: it has no effect without Dramaless Shape.

return function(mod, labels)
  local C = {}
  local key = "dramaless_battle_camera"
  local fork = "fork"
  local classic = "classic"

  local function selected()
    if not (mod.options and type(mod.options.get) == "function") then
      return fork
    end
    return mod.options:get(key) == classic and classic or fork
  end

  local function hasDramaless(game)
    return game and game.mods and game.mods.exports
      and game.mods.exports.DRAMALESS_SHAPE ~= nil
  end

  local function set(value, game)
    if not game then return false end
    local options = game.save and game.save.options
    if options then
      options.modOptions = options.modOptions or {}
      options.modOptions[mod.id] = options.modOptions[mod.id] or {}
      options.modOptions[mod.id][key] = value
    end
    local loader = game.mods
    if loader then
      loader.modOptions = loader.modOptions or {}
      loader.modOptions[mod.id] = loader.modOptions[mod.id] or {}
      loader.modOptions[mod.id][key] = value
    end
    if game.writeOptions then pcall(game.writeOptions, game) end
    if loader and loader.events then
      loader.events:emit("mod.options_changed", {
        mod = mod.id, key = key, value = value,
      })
    end
    return true
  end

  function C.row()
    return {
      id = mod.id .. ":" .. key,
      label = labels.camera,
      value = function()
        return selected() == classic and labels.classic or labels.fork
      end,
      step = function(game)
        set(selected() == classic and fork or classic, game)
        return true
      end,
    }
  end

  local function contains(rows, id)
    for _, row in ipairs(rows) do
      if type(row) == "table" and row.id == id then return true end
    end
    return false
  end

  local function insertNearVoxel(rows, row)
    local anchor
    for i, existing in ipairs(rows) do
      local id = type(existing) == "table" and existing.id or ""
      if id == "pipeline:voxel" or id:find("^DRAMALESS_SHAPE:") then
        anchor = i
      end
    end
    table.insert(rows, (anchor or #rows) + 1, row)
    return rows
  end

  function C.install()
    mod.hooks:wrap("ui.options.rows", function(next, game, rows)
      local out = next(game, rows)
      if type(out) ~= "table" or not hasDramaless(game) then return out end
      local row = C.row()
      if contains(out, row.id) then return out end
      return insertNearVoxel(out, row)
    end, 1000)
  end

  C.key = key
  C.set = set
  return C
end
