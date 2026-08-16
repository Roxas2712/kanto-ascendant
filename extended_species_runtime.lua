-- Runtime identity and presentation boundary for Ascendant's private
-- catalogue slots #252-279.
--
-- #252-260 are the three Hoenn starter families and use their National Dex
-- numbers directly. #261-279 are private, save-stable catalogue slots: their
-- artwork / Wilds / voxel identity is the National Dex `sourceDex`, never the
-- private slot. Species keys remain the authoritative serialized identity.

return function(mod, opts)
  opts = opts or {}
  -- Deterministic QA JSON without reaching into the launcher's private
  -- network/JSON implementation.
  local function encodeJson(value)
    local function quote(text)
      return '"' .. tostring(text):gsub('[%z\1-\31\\"]', function(char)
        local escapes = { ['"'] = '\\"', ['\\'] = '\\\\', ['\b'] = '\\b',
          ['\f'] = '\\f', ['\n'] = '\\n', ['\r'] = '\\r', ['\t'] = '\\t' }
        return escapes[char] or ('\\u%04x'):format(char:byte())
      end) .. '"'
    end
    local seen = {}
    local function encode(node)
      local kind = type(node)
      if kind == "nil" then return "null" end
      if kind == "boolean" then return node and "true" or "false" end
      if kind == "number" then
        return node == node and node ~= math.huge and node ~= -math.huge
          and tostring(node) or "null"
      end
      if kind == "string" then return quote(node) end
      assert(kind == "table", "unsupported JSON value: " .. kind)
      assert(not seen[node], "cyclic JSON value")
      seen[node] = true
      local count, maximum, array = 0, 0, true
      for key in pairs(node) do
        count = count + 1
        if type(key) ~= "number" or key < 1 or key % 1 ~= 0 then
          array = false
        elseif key > maximum then maximum = key end
      end
      array = array and maximum == count
      local parts = {}
      if array then
        for index = 1, maximum do parts[index] = encode(node[index]) end
        seen[node] = nil
        return "[" .. table.concat(parts, ",") .. "]"
      end
      local keys = {}
      for key in pairs(node) do keys[#keys + 1] = key end
      table.sort(keys, function(a, b) return tostring(a) < tostring(b) end)
      for _, key in ipairs(keys) do
        parts[#parts + 1] = quote(key) .. ":" .. encode(node[key])
      end
      seen[node] = nil
      return "{" .. table.concat(parts, ",") .. "}"
    end
    return encode(value)
  end
  local legacy = assert(opts.legacyHoenn, "legacy Hoenn runtime is required")
  local hevo = assert(opts.hevoSpecies, "HEVO runtime is required")
  local hevoData = assert(opts.hevoData, "HEVO source-Dex data is required")

  local R = {
    schemaVersion = 1,
    order = {},
    bySpecies = {},
    byInternalRuntimeDex = {},
    privateDexFirst = 261,
    privateDexLast = 279,
    migrationBoundary = "species-key-authoritative/source-dex-visual-only",
  }
  local bound = {}

  local function add(species, internalDex, sourceDex, family)
    internalDex, sourceDex = tonumber(internalDex), tonumber(sourceDex)
    assert(type(species) == "string" and species ~= "", "species required")
    assert(internalDex and sourceDex, species .. " needs both Dex identities")
    local row = {
      species = species,
      internalRuntimeDex = internalDex,
      sourceDex = sourceDex,
      family = family,
      privateDex = internalDex ~= sourceDex,
    }
    R.order[#R.order + 1] = species
    R.bySpecies[species] = row
    R.byInternalRuntimeDex[internalDex] = row
  end

  for _, species in ipairs(legacy.order or {}) do
    local row = assert(legacy.species and legacy.species[species], species)
    add(species, row.dex, row.dex, "legacy_hoenn")
  end
  for _, species in ipairs(hevo.order or {}) do
    local row = assert(hevoData[species], species)
    add(species, row.dex, row.sourceDex, "hevo_19")
  end

  -- Preserve the private slot in saves and menus, while making the National
  -- identity explicit to every resolver that consumes the merged Pokemon
  -- record. These are additive top-level metadata fields; battle data,
  -- learnsets, evolutions and Pokédex prose are deliberately untouched.
  for _, species in ipairs(R.order) do
    local row = R.bySpecies[species]
    if mod.content and mod.content.pokemon
        and mod.content.pokemon:get(species) then
      mod.content.pokemon:patch(species, {
        internalRuntimeDex = row.internalRuntimeDex,
        sourceDex = row.sourceDex,
      })
    end
  end

  local function speciesKey(value)
    if type(value) == "table" then value = value.species end
    if type(value) == "string" and value ~= "" then return value end
    return nil
  end

  function R.identity(value, data)
    local key = speciesKey(value)
    if key and R.bySpecies[key] then return R.bySpecies[key] end
    local number = tonumber(value)
    if number then return R.byInternalRuntimeDex[math.floor(number)] end
    if key and data and data.pokemon then
      local def = data.pokemon[key]
      local internalDex = def and tonumber(def.internalRuntimeDex or def.dex)
      local sourceDex = def and tonumber(def.sourceDex)
      if internalDex and sourceDex
          and R.byInternalRuntimeDex[internalDex] then
        return R.byInternalRuntimeDex[internalDex]
      end
    end
    return nil
  end

  function R.internalRuntimeDex(value, data)
    local row = R.identity(value, data)
    return row and row.internalRuntimeDex or nil
  end

  function R.sourceDex(value, data)
    local row = R.identity(value, data)
    return row and row.sourceDex or nil
  end

  function R.sourceDexForInternal(internalDex)
    local row = R.byInternalRuntimeDex[tonumber(internalDex)]
    return row and row.sourceDex or nil
  end

  function R.battleRelative(value, side, shiny)
    local row = R.identity(value)
    if not row then return nil end
    side = side == "back" and "back" or "front"
    return ("assets/crystal_animated/%s/%s/%d/001.png"):format(
      side, shiny and "shiny" or "normal", row.internalRuntimeDex)
  end

  function R.battlePath(value, side, shiny)
    local relative = R.battleRelative(value, side, shiny)
    return relative and (mod.path .. "/" .. relative) or nil
  end

  function R.followerRelative(value, shiny)
    local row = R.identity(value)
    if not row then return nil end
    local localRelative = ("assets/followers_runtime/%s/follower_%s.png")
      :format(shiny and "shiny" or "normal", row.species)
    if mod:read(localRelative) ~= nil then return localRelative end
    return ("vendor/wilds_1_12_2/assets/bundled_runtime/"
      .. "followsprites_runtime/%03d-%s.png"):format(
        row.sourceDex, shiny and "shiny" or "normal")
  end

  function R.followerPath(value, shiny)
    local relative = R.followerRelative(value, shiny)
    return relative and (mod.path .. "/" .. relative) or nil
  end

  function R.wildsRuntimeRelative(value, shiny)
    local row = R.identity(value)
    if not row then return nil end
    return ("vendor/wilds_1_12_2/assets/bundled_runtime/"
      .. "followsprites_runtime/%03d-%s.png"):format(
        row.sourceDex, shiny and "shiny" or "normal")
  end

  function R.cryRelative(value)
    local row = R.identity(value)
    if not row then return nil end
    local root = row.family == "legacy_hoenn"
      and "assets/audio/legacy_hoenn_cries/"
      or "assets/audio/hevo_19_cries/"
    return root .. tostring(row.internalRuntimeDex) .. ".ogg"
  end

  function R.bind(components)
    for key, value in pairs(components or {}) do bound[key] = value end
    return R
  end

  function R.install(game)
    R.game = game
    local pokemon = game and game.data and game.data.pokemon
    if not pokemon then return false end
    for _, species in ipairs(R.order) do
      local def, row = pokemon[species], R.bySpecies[species]
      if def then
        def.internalRuntimeDex = row.internalRuntimeDex
        def.sourceDex = row.sourceDex
      end
    end
    return true
  end

  local function vanillaIconPath(data, species)
    local icons = data and data.icons
    local def = data and data.pokemon and data.pokemon[species]
    local entry = icons and icons.bySpecies and icons.bySpecies[species]
      or def and def.icon
    if type(entry) == "table" then return entry.image end
    if type(entry) == "string" then
      return icons and icons.icons and icons.icons[entry]
    end
    local name = def and def.dex and icons and icons.byDex
      and icons.byDex[def.dex]
    return name and icons.icons and icons.icons[name] or nil
  end

  local function surface(Sprites, data, species, side, kind, shiny)
    local mon = { species = species, shiny = shiny and true or nil }
    local path, trueColor = Sprites.path(data, species, side, {
      kind = kind, mon = mon,
    })
    return { path = path, trueColor = trueColor == true }
  end

  local function wildsExport(game)
    local ok, handle = false, nil
    if mod and type(mod.find) == "function" then
      ok, handle = pcall(function() return mod.find("overworld_wild_spawns") end)
    end
    local public = ok and type(handle) == "table" and handle.exports or nil
    if public then return public end
    local internal = mod.exports and mod.exports.internalWilds
    return internal and internal.exports or nil
  end

  -- Machine-readable runtime matrix. Every UI path below is obtained through
  -- the engine's live Sprites resolver/hook chain; Wilds uses its live
  -- AnimatedSprites/provider instances. It is not a file-existence report.
  function R.matrix(game, deps)
    game = game or R.game
    deps = deps or {}
    local Sprites = deps.Sprites or require("src.pokemon.Sprites")
    local data = assert(game and game.data, "runtime matrix needs merged game data")
    local wilds = wildsExport(game)
    local animated = wilds and (wilds.animated
      or wilds.render and wilds.render.animated)
    local providers = wilds and (wilds.spriteProviders
      or wilds.render and wilds.render.spriteProviders)
    local resolveSpeciesId
    if wilds and wilds.lib and type(wilds.lib.require) == "function" then
      local ok, module = pcall(wilds.lib.require, "animated_sprites")
      if ok and module then resolveSpeciesId = module.resolveSpeciesId end
    end

    local matrix = {
      schemaVersion = R.schemaVersion,
      migrationBoundary = R.migrationBoundary,
      generatedBy = "extended_species_runtime.matrix/live-resolvers",
      rows = {},
    }
    for _, species in ipairs(R.order) do
      local identity = R.bySpecies[species]
      local row = {
        species = species,
        internalRuntimeDex = identity.internalRuntimeDex,
        sourceDex = identity.sourceDex,
        privateDex = identity.privateDex,
        animation = { mode = "static", authoredTiming = false },
        surfaces = {},
      }
      for _, shiny in ipairs({ false, true }) do
        local variant = shiny and "shiny" or "normal"
        row.surfaces[variant] = {
          battleEnemy = surface(Sprites, data, species, "front", "battle", shiny),
          battlePlayer = surface(Sprites, data, species, "back", "battle", shiny),
          dex = surface(Sprites, data, species, "front", "dex", shiny),
          summary = surface(Sprites, data, species, "front", "summary", shiny),
          box = surface(Sprites, data, species, "front", "box", shiny),
        }
        local mon = { species = species, shiny = shiny and true or nil }
        row.surfaces[variant].partyIcon = {
          path = Sprites.iconPath(data, mon,
            vanillaIconPath(data, species), { name = species }),
        }
        row.surfaces[variant].follower = {
          path = bound.followerSprites
            and bound.followerSprites.resolve(game, mon) or nil,
        }
        local resolvedSource = resolveSpeciesId
          and resolveSpeciesId(species, game, nil) or identity.sourceDex
        local providerResult = providers and providers.resolve
          and providers:resolve("followers", resolvedSource, variant, game)
        local variantMap = animated and animated.getVariantMapping
          and animated:getVariantMapping(resolvedSource, variant) or nil
        row.surfaces[variant].wilds = {
          sourceDex = resolvedSource,
          path = providerResult and providerResult.def
            and providerResult.def.image or nil,
          provider = providerResult and providerResult.providerId or nil,
        }
        row.surfaces[variant].voxel = {
          sourceDex = resolvedSource,
          path = variantMap and variantMap.relPath or nil,
          valid = variantMap and variantMap.valid == true or false,
          frames = variantMap and variantMap.usableFrameCount or 0,
        }
      end
      local crystal = bound.crystalAnimation
      local dex = identity.internalRuntimeDex
      local authored = crystal and (
        crystal.available[dex] == true
        or crystal.shinyAvailable[dex] == true) or false
      row.animation.authoredTiming = authored
      row.animation.mode = authored and "animated" or "static"
      local cry = data.audio and data.audio.cries
        and data.audio.cries[species]
      row.cry = {
        id = data.pokemon[species] and data.pokemon[species].cry,
        file = type(cry) == "table" and cry.file or nil,
        base = type(cry) == "table" and cry.base or nil,
      }
      matrix.rows[#matrix.rows + 1] = row
    end
    return matrix
  end

  function R.validate(matrix)
    local findings = {}
    local function fail(species, surface, message)
      findings[#findings + 1] = {
        severity = "error", species = species,
        surface = surface, message = message,
      }
    end
    local seen = {}
    for _, row in ipairs(matrix and matrix.rows or {}) do
      seen[row.species] = true
      local expected = R.bySpecies[row.species]
      if not expected then
        fail(row.species, "identity", "unexpected species")
      else
        if row.internalRuntimeDex ~= expected.internalRuntimeDex then
          fail(row.species, "identity", "internalRuntimeDex mismatch")
        end
        if row.sourceDex ~= expected.sourceDex then
          fail(row.species, "identity", "sourceDex mismatch")
        end
        local crystal = bound.crystalAnimation
        local expectedAnimated = crystal and (
          crystal.available[expected.internalRuntimeDex] == true
          or crystal.shinyAvailable[expected.internalRuntimeDex] == true)
          or false
        if row.animation.mode ~= (expectedAnimated and "animated" or "static")
            or row.animation.authoredTiming ~= expectedAnimated then
          fail(row.species, "animation",
            "reported motion does not match identity-correct authored assets")
        end
        for variant, surfaces in pairs(row.surfaces or {}) do
          for _, key in ipairs({
            "battleEnemy", "battlePlayer", "dex", "summary", "box",
            "partyIcon", "follower", "wilds",
          }) do
            if not (surfaces[key] and type(surfaces[key].path) == "string"
                and surfaces[key].path ~= "") then
              fail(row.species, variant .. "." .. key,
                "live resolver returned no path")
            end
          end
          local frontFragment = ("/front/%s/%d/001.png"):format(
            variant, expected.internalRuntimeDex)
          local backFragment = ("/back/%s/%d/001.png"):format(
            variant, expected.internalRuntimeDex)
          for _, key in ipairs({ "battleEnemy", "dex", "summary", "box" }) do
            local path = surfaces[key] and surfaces[key].path
            if type(path) ~= "string"
                or not path:find(frontFragment, 1, true) then
              fail(row.species, variant .. "." .. key,
                "resolver escaped the exact internal front-art card")
            end
          end
          local playerPath = surfaces.battlePlayer
            and surfaces.battlePlayer.path
          if type(playerPath) ~= "string"
              or not playerPath:find(backFragment, 1, true) then
            fail(row.species, variant .. ".battlePlayer",
              "resolver escaped the exact internal back-art card")
          end
          if not (surfaces.voxel and surfaces.voxel.valid
              and surfaces.voxel.sourceDex == expected.sourceDex) then
            fail(row.species, variant .. ".voxel",
              "voxel resolver did not retain National-Dex identity")
          end
          if surfaces.wilds
              and surfaces.wilds.sourceDex ~= expected.sourceDex then
            fail(row.species, variant .. ".wilds",
              "Wilds resolved the private catalogue slot")
          end
        end
        if not (row.cry and row.cry.id == row.species
            and (row.cry.file or row.cry.base)) then
          fail(row.species, "cry", "merged cry resolver is incomplete")
        end
      end
    end
    for _, species in ipairs(R.order) do
      if not seen[species] then fail(species, "matrix", "row missing") end
    end
    return { ok = #findings == 0, findings = findings, rows = #R.order }
  end

  function R.matrixJson(game, deps)
    return encodeJson(R.matrix(game, deps))
  end

  function R.encodeJson(value)
    return encodeJson(value)
  end

  return R
end
