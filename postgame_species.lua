-- Johto content expressed through Gen1 Recomp's native registries.  Crystal
-- battle sprites are optional local files; every species has a distributable
-- Kanto-silhouette fallback so the mod remains self-contained.

local function evolutionRow(row)
  local out = { method = row[1], species = row[2] }
  if row[1] == "LEVEL" or row[1]:match("^TYROGUE_") then
    out.level = row[3]
  elseif row[1] == "ITEM" then
    out.item = row[3]
  end
  return out
end

return function(mod, legends, johto, i18n)
  -- Every Johto species ships with its short legacy cry as a mobile-safe OGG.
  -- Keep the old derived Gen-I definitions as a last-resort recovery path for
  -- incomplete development packages; release packages always contain all 100
  -- files. An externally registered cry remains authoritative.
  local CRY_BASE_BY_TYPE = {
    NORMAL = "RATTATA", FIRE = "CHARMANDER", WATER = "SQUIRTLE",
    ELECTRIC = "PIKACHU", GRASS = "BULBASAUR", ICE = "SEEL",
    FIGHTING = "MACHOP", POISON = "EKANS", GROUND = "SANDSHREW",
    FLYING = "PIDGEY", PSYCHIC = "ABRA", PSYCHIC_TYPE = "ABRA",
    BUG = "CATERPIE", ROCK = "GEODUDE", GHOST = "GASTLY",
    DRAGON = "DRATINI", DARK = "MEOWTH", STEEL = "MAGNEMITE",
  }
  local fallbackCries = {}
  local bundledCries = {}
  for _, id in ipairs(johto.order) do
    local def = assert(johto.species[id], "missing Johto species " .. id)
    local primaryType = def.types and def.types[1]
    fallbackCries[id] = {
      base = CRY_BASE_BY_TYPE[primaryType] or "RHYDON",
      pitch = 96 + (def.dex % 5) * 16,
      length = 112 + (def.dex % 4) * 16,
    }
    local relative = ("assets/audio/johto_cries/%d.ogg"):format(def.dex)
    bundledCries[id] = {
      file = mod.path .. "/" .. relative,
      available = mod:read(relative) ~= nil,
    }
  end

  local audioCompat = {
    bundled = bundledCries,
    fallbacks = fallbackCries,
    -- Shared with every Johto registration below and exposed for the
    -- ROM-free regression suite.
    battleScaleBack = 1,
  }
  local dexTextKeys = {}
  for _, id in ipairs(johto.order) do
    dexTextKeys[id] = "_KantoAscendantJohtoDex" .. id
  end

  -- DexEntryMenu draws the supplied line breaks verbatim; unlike an ordinary
  -- TextBox it does not wrap prose.  Keep every localized line inside the
  -- 152-pixel description column (18 Game Boy glyphs with a small safety
  -- margin), otherwise long Johto entries disappear under the right edge.
  local function glyphLength(text)
    local count = 0
    for i = 1, #tostring(text or "") do
      local byte = tostring(text or ""):byte(i)
      if byte < 128 or byte >= 192 then count = count + 1 end
    end
    return count
  end

  function audioCompat.wrapDexText(text, width)
    width = math.max(1, math.floor(tonumber(width) or 18))
    text = tostring(text or ""):gsub("[\n\v\f]+", " ")
      :gsub("%s+", " "):match("^%s*(.-)%s*$")
    local lines, line = {}, ""
    for word in text:gmatch("%S+") do
      local candidate = line == "" and word or (line .. " " .. word)
      if line ~= "" and glyphLength(candidate) > width then
        lines[#lines + 1], line = line, word
      else
        line = candidate
      end
    end
    if line ~= "" then lines[#lines + 1] = line end
    return table.concat(lines, "\n")
  end

  audioCompat.glyphLength = glyphLength

  -- Johto species are registered before a save slot is loaded. AUTO language
  -- can therefore change afterwards when the matching German translation mod
  -- or a slot-local language choice becomes active. Refresh all visible Dex
  -- metadata at game.ready/save.loaded instead of freezing it at content-load
  -- time. DexEntryMenu also expects `dexEntry.text` to be a key in Data.text,
  -- never the prose itself; using the raw prose made every owned #152-251 entry
  -- fall through to "Data unknown.".
  function audioCompat.refreshLocalization(game, forceGerman)
    local data = game and game.data or game
    if not (data and data.pokemon and data.text) then return 0 end
    local german = forceGerman
    if german == nil then german = i18n and i18n.isGerman() or false end
    local refreshed = 0
    for _, id in ipairs(johto.order) do
      local def = johto.species[id]
      local species = data.pokemon[id]
      if species and def and def.dexEntry then
        species.name = german
          and (johto.germanNames[id] or def.name) or def.name
        species.dexEntry = species.dexEntry or {}
        species.dexEntry.kind = german
          and def.dexEntry.kindDe or def.dexEntry.kindEn
        species.dexEntry.text = dexTextKeys[id]
        data.text[dexTextKeys[id]] = audioCompat.wrapDexText(german
          and def.dexEntry.textDe or def.dexEntry.textEn)
        refreshed = refreshed + 1
      end
    end
    return refreshed
  end

  function audioCompat.install(game)
    local data = game and game.data or game
    if not data then return 0, 0 end
    audioCompat.refreshLocalization(data)
    data.audio = data.audio or {}
    data.audio.cries = data.audio.cries or {}
    data.audio._owners = data.audio._owners or {}
    data.audio._owners.cries = data.audio._owners.cries or {}
    local okSound, Sound = pcall(require, "src.core.Sound")

    local installed, preserved = 0, 0
    for _, id in ipairs(johto.order) do
      local owner = data.audio._owners.cries[id]
      local ownDefinition = owner == mod.manifest.id
      local bundled = bundledCries[id]
      local current = data.audio.cries[id]
      local staleOwnDefinition = ownDefinition and bundled.available
        and (type(current) ~= "table" or current.file ~= bundled.file)
      if current == nil or staleOwnDefinition then
        data.audio.cries[id] = bundled.available
          and { file = bundled.file } or fallbackCries[id]
        data.audio._owners.cries[id] = mod.manifest.id
        installed = installed + 1
      else
        preserved = preserved + 1
      end
      local species = data.pokemon and data.pokemon[id]
      if species then species.cry = id end
      -- Sound remembers a failed lookup as `false`. A follower interaction
      -- or another game.ready listener can ask for a Johto cry before this
      -- late compatibility pass runs, especially when several mods wrap the
      -- Yellow companion. Evict that one negative entry now that the final
      -- merged definition is known.
      if okSound and Sound and type(Sound.invalidate) == "function" then
        Sound.invalidate("cry:" .. id)
      end
    end
    return installed, preserved
  end

  if not mod.content.pokemon:get("MEWTWO") then
    return false, audioCompat
  end

  -- Generation-II types and their original matchup table.
  mod.content.type_chart:register("DARK", {
    name = "DARK", category = "special",
  })
  mod.content.type_chart:register("STEEL", {
    name = "STEEL", category = "physical",
  })
  local chart = {
    { "DARK", "PSYCHIC_TYPE", 20 }, { "DARK", "GHOST", 20 },
    { "DARK", "FIGHTING", 5 }, { "DARK", "DARK", 5 },
    { "DARK", "STEEL", 5 },
    { "STEEL", "ICE", 20 }, { "STEEL", "ROCK", 20 },
    { "STEEL", "FIRE", 5 }, { "STEEL", "WATER", 5 },
    { "STEEL", "ELECTRIC", 5 }, { "STEEL", "STEEL", 5 },
    { "NORMAL", "STEEL", 5 }, { "FIGHTING", "DARK", 20 },
    { "FIGHTING", "STEEL", 20 }, { "FLYING", "STEEL", 5 },
    { "POISON", "STEEL", 0 }, { "GROUND", "STEEL", 20 },
    { "ROCK", "STEEL", 5 }, { "BUG", "DARK", 20 },
    { "BUG", "STEEL", 5 }, { "GHOST", "DARK", 5 },
    { "GHOST", "STEEL", 5 }, { "FIRE", "STEEL", 20 },
    { "GRASS", "STEEL", 5 }, { "ICE", "STEEL", 5 },
    { "PSYCHIC_TYPE", "DARK", 0 }, { "PSYCHIC_TYPE", "STEEL", 5 },
    { "DRAGON", "STEEL", 5 },
  }
  for _, row in ipairs(chart) do
    mod.content.type_chart:register(row[1] .. ">" .. row[2],
      { multiplier = row[3] })
  end

  -- A compact move set gives the new families their defining Gen-II tools
  -- without depending on another mechanics mod.
  local moves = {
    CRUNCH = { "CRUNCH", "DARK", 80, 100, 15, "special" },
    METAL_CLAW = { "METAL CLAW", "STEEL", 50, 95, 35, "physical" },
    IRON_TAIL = { "IRON TAIL", "STEEL", 100, 75, 15, "physical" },
    SHADOW_BALL = { "SHADOW BALL", "GHOST", 80, 100, 15, "physical" },
    FLAME_WHEEL = { "FLAME WHEEL", "FIRE", 60, 100, 25, "special" },
    GIGA_DRAIN = { "GIGA DRAIN", "GRASS", 60, 100, 10, "special" },
    SLUDGE_BOMB = { "SLUDGE BOMB", "POISON", 90, 100, 10, "physical" },
    SPARK = { "SPARK", "ELECTRIC", 65, 100, 20, "special" },
    POWDER_SNOW = { "POWDER SNOW", "ICE", 40, 100, 25, "special" },
    SACRED_FIRE = { "SACRED FIRE", "FIRE", 100, 95, 5, "special",
                    "BURN_SIDE_EFFECT1" },
    AEROBLAST = { "AEROBLAST", "FLYING", 100, 95, 5, "physical" },
  }
  for id, row in pairs(moves) do
    mod.content.moves:register(id, {
      id = id, name = row[1], type = row[2], power = row[3],
      accuracy = row[4], pp = row[5], category = row[6],
      effect = row[7] or "NO_ADDITIONAL_EFFECT",
      highCrit = id == "AEROBLAST" and true or nil,
    })
  end
  mod.content.moves:patch("BITE", { type = "DARK", category = "special" })
  mod.content.moves:patch("GUST", { type = "FLYING", category = "physical" })
  mod.content.moves:patch("SAND_ATTACK", {
    type = "GROUND", category = "status",
  })
  mod.content.moves:patch("KARATE_CHOP", {
    type = "FIGHTING", category = "physical",
  })

  -- Friendship is stored on the individual mon and grows through travel and
  -- victories in johto_research.lua. AUTO follows the computer clock; the
  -- option also lets players force either Eevee branch.
  local function friendship(mon)
    return math.max(0, tonumber(mon and mon.johtoBond) or 0) >= 100
  end
  local function timeMode()
    local selected = mod.options and mod.options:get("johto_time") or "auto"
    if selected ~= "auto" then return selected end
    local hour = tonumber(os.date("*t").hour) or 12
    return (hour >= 18 or hour < 6) and "night" or "day"
  end
  mod.content.evolution_methods:register("FRIENDSHIP", {
    check = function(_, mon, _, trigger)
      return trigger.kind == "levelup" and friendship(mon)
    end,
    describe = function() return "High friendship" end,
  })
  mod.content.evolution_methods:register("FRIENDSHIP_DAY", {
    check = function(_, mon, _, trigger)
      return trigger.kind == "levelup" and friendship(mon)
        and timeMode() == "day"
    end,
    describe = function() return "High friendship by day" end,
  })
  mod.content.evolution_methods:register("FRIENDSHIP_NIGHT", {
    check = function(_, mon, _, trigger)
      return trigger.kind == "levelup" and friendship(mon)
        and timeMode() == "night"
    end,
    describe = function() return "High friendship at night" end,
  })
  local function tyrogueCheck(mode)
    return function(_, mon, evo, trigger)
      if trigger.kind ~= "levelup" or mon.level < (evo.level or 20) then
        return false
      end
      local attack = mon.stats and mon.stats.attack or 0
      local defense = mon.stats and mon.stats.defense or 0
      if mode == "attack" then return attack > defense end
      if mode == "defense" then return defense > attack end
      return attack == defense
    end
  end
  mod.content.evolution_methods:register("TYROGUE_ATTACK", {
    check = tyrogueCheck("attack"), describe = function() return "ATK > DEF" end,
  })
  mod.content.evolution_methods:register("TYROGUE_DEFENSE", {
    check = tyrogueCheck("defense"), describe = function() return "DEF > ATK" end,
  })
  mod.content.evolution_methods:register("TYROGUE_BALANCE", {
    check = tyrogueCheck("balance"), describe = function() return "ATK = DEF" end,
  })

  for _, row in ipairs(johto.items) do
    mod.content.items:register(row.id, {
      id = row.id,
      name = i18n and i18n.isGerman() and row.de or row.name,
      price = 2100, tossable = true, needsTarget = false,
    })
  end

  -- Steel became part of Magnemite's family in Generation II.
  local function replaceTypes(id, types)
    local current = assert(mod.content.pokemon:get(id), "missing " .. id)
    local replacement = {}
    for key, value in pairs(current) do replacement[key] = value end
    replacement.types = types
    mod.content.pokemon:override(id, replacement)
  end
  replaceTypes("MAGNEMITE", { "ELECTRIC", "STEEL" })
  replaceTypes("MAGNETON", { "ELECTRIC", "STEEL" })

  local function sameEvolution(a, b)
    return a.method == b.method
      and a.species == b.species
      and a.level == b.level
      and a.item == b.item
  end

  -- Record patches replace arrays wholesale. Preserve every original Kanto
  -- branch before adding Johto's new alternatives; otherwise Gloom,
  -- Poliwhirl, Eevee and Slowpoke would lose their Gen-I evolutions.
  for id, entries in pairs(johto.kantoEvolutions) do
    local current = assert(mod.content.pokemon:get(id), "missing " .. id)
    local combined = {}
    for _, evolution in ipairs(current.evolutions or {}) do
      local copy = {}
      for key, value in pairs(evolution) do copy[key] = value end
      combined[#combined + 1] = copy
    end
    for _, row in ipairs(entries) do
      local addition = evolutionRow(row)
      local duplicate = false
      for _, existing in ipairs(combined) do
        if sameEvolution(existing, addition) then
          duplicate = true
          break
        end
      end
      if not duplicate then combined[#combined + 1] = addition end
    end
    mod.content.pokemon:patch(id, { evolutions = combined })
  end

  local templateFor = {
    NORMAL = "RATTATA", GRASS = "BULBASAUR", FIRE = "CHARMANDER",
    WATER = "SQUIRTLE", ELECTRIC = "PIKACHU", BUG = "CATERPIE",
    FLYING = "PIDGEY", POISON = "EKANS", GROUND = "SANDSHREW",
    ROCK = "GEODUDE", PSYCHIC_TYPE = "ABRA", GHOST = "GASTLY",
    ICE = "SEEL", FIGHTING = "MACHOP", DARK = "GROWLITHE",
    STEEL = "MAGNEMITE", DRAGON = "DRATINI",
  }
  local iconFor = {
    NORMAL = "MON", GRASS = "GRASS", FIRE = "QUADRUPED",
    WATER = "WATER", ELECTRIC = "QUADRUPED", BUG = "BUG",
    FLYING = "BIRD", POISON = "SNAKE", GROUND = "QUADRUPED",
    ROCK = "MON", PSYCHIC_TYPE = "FAIRY", GHOST = "MON",
    ICE = "MON", FIGHTING = "MON", DARK = "QUADRUPED",
    STEEL = "MON", DRAGON = "SNAKE",
  }
  local specialTemplates = {
    CHIKORITA = "BULBASAUR", BAYLEEF = "IVYSAUR", MEGANIUM = "VENUSAUR",
    CYNDAQUIL = "CHARMANDER", QUILAVA = "CHARMELEON", TYPHLOSION = "CHARIZARD",
    TOTODILE = "SQUIRTLE", CROCONAW = "WARTORTLE", FERALIGATR = "BLASTOISE",
    RAIKOU = "ARCANINE", ENTEI = "ARCANINE", SUICUNE = "ARCANINE",
    LUGIA = "ARTICUNO", HO_OH = "MOLTRES", CELEBI = "MEW",
  }
  -- Party-menu icons deliberately reuse Gen 1's native animated classes.
  -- Custom single-frame thumbnails looked like unrelated Pokémon once the
  -- party menu applied its original mirrored-icon layout.
  local specialIcons = johto.partyIcons or {}
  local originalArt = {
    RAIKOU = "raikou", ENTEI = "entei", SUICUNE = "suicune",
    LUGIA = "lugia", HO_OH = "ho_oh", CELEBI = "crystal/celebi",
  }

  for _, id in ipairs(johto.order) do
    local catalogue = johto.species[id]
    local def = catalogue
    local legendary = legends.species[id]
    if legendary then
      def = {
        dex = def.dex, id = id, name = legendary.name, types = legendary.types,
        stats = legendary.stats, catchRate = legendary.catchRate,
        baseExp = legendary.baseExp, growthRate = "SLOW",
        -- Species-authentic catalogue data remains authoritative for learning,
        -- compatibility and Pokédex presentation.  The post-game profile only
        -- supplies encounter balancing fields.
        level1 = catalogue.level1, learnset = catalogue.learnset,
        tmhm = catalogue.tmhm, dexEntry = catalogue.dexEntry,
        weightKg = catalogue.weightKg,
      }
    end
    local primary = def.types[1]
    local function validMove(move)
      if mod.content.moves:get(move) then return true end
      mod.log:warn("JOHTO skipped unavailable move %s for %s", move, id)
      return false
    end
    local level1 = {}
    for _, move in ipairs(def.level1 or {}) do
      if validMove(move) then level1[#level1 + 1] = move end
    end
    if #level1 == 0 then level1[1] = "TACKLE" end
    local learnset = {}
    for _, row in ipairs(def.learnset or {}) do
      if validMove(row.move) then
        learnset[#learnset + 1] = { level = row.level, move = row.move }
      end
    end
    local tmhm = {}
    for _, move in ipairs(def.tmhm or {}) do
      if validMove(move) then tmhm[#tmhm + 1] = move end
    end
    local evolutions = {}
    for _, row in ipairs(johto.evolutions[id] or {}) do
      evolutions[#evolutions + 1] = evolutionRow(row)
    end
    local templateId = specialTemplates[id] or templateFor[primary] or "RATTATA"
    local template = assert(mod.content.pokemon:get(templateId),
      "missing fallback species " .. templateId)
    local art = originalArt[id]
    local crystalName = id == "HO_OH" and "ho_oh" or id:lower()
    local crystalFront = "assets/crystal/" .. crystalName .. "_front.png"
    local crystalBack = "assets/crystal/" .. crystalName .. "_back.png"
    -- Every public #152-251 package now contains the complete Crystal pair.
    -- Register those species-authentic files as the native data paths too,
    -- so Pokédex/UI mods which read `spriteFront` directly cannot expose the
    -- old Kanto silhouette fallback (for example Rattata on Hoothoot).
    local spriteFront = art and mod.path .. "/assets/" .. art .. "_front.png"
      or (mod:read(crystalFront) and mod.path .. "/" .. crystalFront)
      or template.spriteFront
    local spriteBack = art and mod.path .. "/assets/" .. art .. "_back.png"
      or (mod:read(crystalBack) and mod.path .. "/" .. crystalBack)
      or template.spriteBack
    local icon = specialIcons[id] or (iconFor[primary] or "MON")
    local dex = assert(def.dexEntry, "missing Pokédex entry for " .. id)
    local totalInches = math.floor(dex.heightM * 39.3700787 + 0.5)
    local german = i18n and i18n.isGerman()
    local dexTextKey = dexTextKeys[id]
    mod.content.text:register(
      dexTextKey, german and dex.textDe or dex.textEn)
    -- Do not claim the registry id during content loading. A dedicated
    -- Gen-II audio mod may load before or after Ascendant, so the final
    -- merged cry table is inspected at game.ready instead. Only genuinely
    -- missing entries receive this compact ROM-native derived fallback.
    mod.content.pokemon:register(id, {
      id = id,
      name = i18n and i18n.isGerman()
        and (johto.germanNames[id] or def.name) or def.name,
      dex = def.dex, types = def.types,
      baseStats = def.stats, catchRate = def.catchRate, baseExp = def.baseExp,
      growthRate = def.growthRate, level1Moves = level1,
      tmhm = tmhm, learnset = learnset, evolutions = evolutions,
      spriteFront = spriteFront, spriteBack = spriteBack,
      frontSize = template.frontSize or 7,
      -- Every bundled Crystal back is a complete 56x56 Gen-II picture.
      -- Gen1's native player backs are compact pictures intentionally drawn
      -- at 2x; leaving that default on ordinary Johto species made Natu and
      -- the rest of #152-251 enormous. The six legacy legend cards already
      -- used 1x, and the same rule belongs to the whole Johto roster.
      battleScaleBack = audioCompat.battleScaleBack, icon = icon,
      dexEntry = {
        kind = german and dex.kindDe or dex.kindEn,
        heightFt = math.floor(totalInches / 12),
        heightIn = totalInches % 12,
        weight = math.floor((def.weightKg or 10) * 22.0462262 + 0.5),
        heightM = dex.heightM, weightKg = def.weightKg or 10,
        text = dexTextKey,
      },
    })
    mod.content.icons:register(id, icon)
  end

  mod.content.constants:patch("dexSize", 251)
  mod.content.constants:patch("dexDigits", 3)

  return true, audioCompat
end
