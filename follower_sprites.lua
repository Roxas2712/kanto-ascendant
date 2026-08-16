-- Data-driven, species-authentic sprite registry for the native single
-- follower.  SPRITE_PIKACHU remains only the engine transport slot: every
-- visible sheet is selected from this registry by the active Pokémon's
-- species, never by a generic silhouette or a random replacement.

return function(mod, opts)
  opts = opts or {}
  local spriteAssets = opts.spriteAssets
  local shinySystem = opts.shinySystem
  local extendedRuntime = opts.extendedRuntime
  local R = {
    spriteId = "SPRITE_PIKACHU",
    definitions = {},
    families = {
      kanto = {
        dexFirst = 1, dexLast = 151,
        source = "PokePCFollowers / Crystal Clear (see THIRD_PARTY_NOTICES.md)",
      },
      johto = {
        dexFirst = 152, dexLast = 251,
        source = "PokeWilds follower sprite pack (see THIRD_PARTY_NOTICES.md)",
      },
    },
  }
  local cache, warned = {}, {}

  local function kantoRelative(dex)
    return ("assets/followers_kanto/follower_%03d.png"):format(dex)
  end

  local function runtimeRelative(species, shiny)
    return ("assets/followers_runtime/%s/follower_%s.png")
      :format(shiny and "shiny" or "normal", species)
  end

  local function absolute(relative)
    return mod.path .. "/" .. relative
  end

  local function readable(relative)
    if type(mod.read) ~= "function" then return true end
    local bytes = mod:read(relative)
    return type(bytes) == "string" and #bytes > 0
  end

  local function clone(def)
    local result = {}
    for key, value in pairs(def) do result[key] = value end
    return result
  end

  local function normalize(species, def)
    assert(type(species) == "string" and species ~= "",
      "follower species key is required")
    assert(type(def) == "table", "follower definition is required")
    assert(type(def.normalRelative) == "string" and def.normalRelative ~= "",
      "follower definition needs normalRelative")
    def = clone(def)
    def.species = species
    def.shinyRelative = def.shinyRelative or def.normalRelative
    def.frames = tonumber(def.frames) or 6
    def.width = tonumber(def.width) or 16
    def.height = tonumber(def.height) or 96
    def.walker = def.walker ~= false
    def.trueColor = def.trueColor ~= false
    return def
  end

  -- Public registration point for future custom species.  A custom Pokémon
  -- needs only a six-pose sheet definition; follower transport and movement
  -- require no species-specific source changes.
  function R.register(species, def)
    R.definitions[species] = normalize(species, def)
    cache = {}
    return R.definitions[species]
  end

  local function johtoFallback(species, isShiny)
    if spriteAssets and spriteAssets.follower then
      return spriteAssets.follower(species, isShiny)
    end
  end

  local function johtoDefinition(species)
    return {
      normalRelative = runtimeRelative(species, false),
      shinyRelative = runtimeRelative(species, true),
      frames = 6, width = 16, height = 96, walker = true, trueColor = true,
      source = R.families.johto.source,
      fallback = johtoFallback,
    }
  end

  local function kantoDefinition(species, dex)
    local relative = kantoRelative(dex)
    return {
      species = species,
      normalRelative = relative,
      -- Kanto currently ships one authored PokePCFollowers walker per
      -- species.  A shiny still uses that same species-authentic sheet; it
      -- is deliberately not substituted with a different monster.
      shinyRelative = relative,
      frames = 6, width = 16, height = 96, walker = true, trueColor = true,
      source = R.families.kanto.source,
    }
  end

  -- Johto's full #152-251 table is registered up front.  Keeping concrete
  -- resource paths here makes release coverage auditable and lets future
  -- content add another definition without editing resolution logic.
  local johtoData = opts.johtoData
  if johtoData and type(johtoData.order) == "table" then
    for _, species in ipairs(johtoData.order) do
      R.register(species, johtoDefinition(species))
    end
  end

  -- Private catalogue slots do not imply National-Dex follower numbers.
  -- Register their exact local/bundled runtime sheets after the broad Johto
  -- loop so Azurill (#278 -> nat298), Wynaut (#279 -> nat360) and every
  -- Gen-IV evolution keep the correct visible identity.
  if extendedRuntime and type(extendedRuntime.order) == "table" then
    for _, species in ipairs(extendedRuntime.order) do
      R.register(species, {
        normalRelative = extendedRuntime.followerRelative(species, false),
        shinyRelative = extendedRuntime.followerRelative(species, true),
        frames = 6, width = 16, height = 96,
        walker = true, trueColor = true,
        source = "Ascendant sourceDex runtime boundary",
      })
    end
  end

  -- Gorochu has a dedicated normal + shiny walker derived from Ascendant's
  -- bundled Raichu base.  The shared silhouette preserves Kanto-family gait
  -- quality while its horn, markings and palettes remain species-specific.
  -- It therefore does not fall back at runtime; a missing sheet hides+logs.
  R.register("GOROCHU", {
    normalRelative = runtimeRelative("GOROCHU", false),
    shinyRelative = runtimeRelative("GOROCHU", true),
    frames = 6, width = 16, height = 96, walker = true, trueColor = true,
    source = "Kanto Ascendant Gorochu adaptation of bundled Raichu walker",
  })

  local function shiny(mon)
    return shinySystem and shinySystem.isShiny
      and shinySystem.isShiny(mon) == true or false
  end

  function R.definition(game, species)
    if type(species) ~= "string" or species == "" then return nil end
    local registered = R.definitions[species]
    if registered then return registered end
    local pokemon = game and game.data and game.data.pokemon
    local dex = tonumber(pokemon and pokemon[species] and pokemon[species].dex)
    if dex and dex >= R.families.kanto.dexFirst
        and dex <= R.families.kanto.dexLast then
      return kantoDefinition(species, dex)
    end
    -- This keeps a compatible standalone registry test usable while normal
    -- runtime registers all 100 exact Johto entries from johto_data.lua.
    if dex and dex >= R.families.johto.dexFirst
        and dex <= R.families.johto.dexLast then
      return normalize(species, johtoDefinition(species))
    end
    return nil
  end

  local function resource(def, isShiny)
    local relative = isShiny and def.shinyRelative or def.normalRelative
    if relative and readable(relative) then return absolute(relative) end
    if type(def.fallback) == "function" then
      return def.fallback(def.species, isShiny)
    end
    return nil
  end

  function R.resolve(game, mon)
    if type(mon) ~= "table" or type(mon.species) ~= "string" then return nil end
    local isShiny = shiny(mon)
    local key = mon.species .. (isShiny and ":shiny" or ":normal")
    if cache[key] ~= nil then return cache[key] or nil end

    local def = R.definition(game, mon.species)
    local path = def and resource(def, isShiny)
    if not path then
      if not warned[key] and mod.log and mod.log.warn then
        warned[key] = true
        mod.log:warn(
          "native follower hidden: no species-authentic sheet for %s",
          tostring(mon.species))
      end
      cache[key] = false
      return nil
    end
    cache[key] = path
    return path
  end

  -- A lightweight, inspectable coverage view used by release tests and
  -- maintainers.  It never invents a fallback: each result names the exact
  -- requested species, concrete resource and whether it is readable.
  function R.coverage(game, speciesList, isShiny)
    local report = {}
    for _, species in ipairs(speciesList or {}) do
      local def = R.definition(game, species)
      local relative = def and (isShiny and def.shinyRelative or def.normalRelative)
      report[#report + 1] = {
        species = species,
        definition = def,
        relative = relative,
        readable = relative and readable(relative) or false,
      }
    end
    return report
  end

  local fallback = absolute(kantoRelative(25))
  local content = mod.content and mod.content.sprites
  if content then
    local def = {
      id = R.spriteId, image = fallback, frames = 6,
      walker = true, trueColor = true,
    }
    if content:get(R.spriteId) then content:patch(R.spriteId, def)
    else content:register(R.spriteId, def) end
  end

  function R.configure(game, mon)
    local path = R.resolve(game, mon)
    local def = game and game.data and game.data.sprites[R.spriteId]
    if not (path and def) then return nil end
    local visual = R.definition(game, mon.species)
    def.image, def.frames = path, visual.frames
    def.walker, def.trueColor = visual.walker, visual.trueColor
    return def, path
  end

  function R.invalidate() cache = {} end
  return R
end
