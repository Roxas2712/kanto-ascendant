-- Kanto Ascendant 6.7: complete Generation IV--VII starter families.
--
-- Data and assets are generated from one pinned PokemonWorkshop/GameDataPacks
-- commit (see docs/STARTER_SPECIES_67_PROVENANCE.md). This module is the only
-- live registration boundary: habitats consume its public completeness API,
-- while battle, party, follower and Wilds surfaces all resolve the same exact
-- species identity.

return function(mod, opts)
  opts = opts or {}
  local data = assert(opts.data, "starter species 6.7 data required")
  local beyondKanto = opts.beyondKanto
  local generationRules = opts.generationRules
  local i18n = opts.i18n
  local S = {
    order = {}, starters = {}, evolutions = {}, families = {},
    familyById = {}, familyBySpecies = {}, byDex = {},
    source = data._meta, audit = { species = {}, skippedFamilies = {} },
    battleScale = 7 / 12,
  }
  local bound = {
    shinySystem = opts.shinySystem,
    crystalAnimation = opts.crystalAnimation,
  }
  local installedGames = setmetatable({}, { __mode = "k" })
  local wildsBindings = setmetatable({}, { __mode = "k" })

  local function tr(en, de)
    if i18n and type(i18n.text) == "function" then
      return i18n.text(en, de)
    end
    return en
  end

  local function copy(value)
    if type(value) ~= "table" then return value end
    local result = {}
    for key, child in pairs(value) do result[key] = copy(child) end
    return result
  end

  local function u32(bytes, at)
    local a, b, c, d = bytes:byte(at, at + 3)
    if not d then return nil end
    return a * 16777216 + b * 65536 + c * 256 + d
  end

  local function read(relative)
    if type(mod.read) ~= "function" then return true end
    local ok, bytes = pcall(mod.read, mod, relative)
    if not ok then return nil end
    return bytes
  end

  local function png(relative, width, height)
    local bytes = read(relative)
    if bytes == true then return true end
    return type(bytes) == "string" and #bytes >= 24
      and bytes:sub(1, 8) == "\137PNG\r\n\26\n"
      and bytes:sub(13, 16) == "IHDR"
      and u32(bytes, 17) == width and u32(bytes, 21) == height
  end

  local function ogg(relative)
    local bytes = read(relative)
    if bytes == true then return true end
    return type(bytes) == "string" and #bytes > 64
      and bytes:sub(1, 4) == "OggS" and bytes:find("vorbis", 1, true) ~= nil
  end

  local function sourceRow(relative)
    local bytes = read(relative)
    return bytes == true or type(bytes) == "string" and #bytes > 100
  end

  local function assetHealth(row)
    local a = row.assets
    local normal = png(a.front, 96, 96) and png(a.back, 96, 96)
      and png(a.icon, 16, 32) and png(a.walker, 16, 96)
      and ogg(a.cry) and sourceRow(a.sourceJson)
    local shiny = png(a.frontShiny, 96, 96) and png(a.backShiny, 96, 96)
      and png(a.iconShiny, 16, 32) and png(a.walkerShiny, 16, 96)
    return { core = normal and true or false, shiny = shiny and true or false }
  end

  -- Ordinary full loads already receive Dark/Steel from postgame_species,
  -- but minimal/vanilla registry loads may legitimately skip that optional
  -- block.  Own only missing rows here: an earlier type or matchup authority
  -- is preserved byte-for-byte, while every starter definition remains free
  -- of dangling references in either load order.
  local function ensureBattleTypes()
    local registry = mod.content.type_chart
    if not registry:get("DARK") then
      registry:register("DARK", { name = "DARK", category = "special" })
    end
    if not registry:get("STEEL") then
      registry:register("STEEL", { name = "STEEL", category = "physical" })
    end
    if not registry:get("FAIRY") then
      registry:register("FAIRY", { name = tr("FAIRY", "FEE"), category = "special" })
    end
    local matchups = {
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
      { "PSYCHIC_TYPE", "DARK", 0 },
      { "PSYCHIC_TYPE", "STEEL", 5 }, { "DRAGON", "STEEL", 5 },
      { "FAIRY", "FIGHTING", 20 }, { "FAIRY", "DRAGON", 20 },
      { "FAIRY", "DARK", 20 }, { "FAIRY", "FIRE", 5 },
      { "FAIRY", "POISON", 5 }, { "FAIRY", "STEEL", 5 },
      { "FIGHTING", "FAIRY", 5 }, { "BUG", "FAIRY", 5 },
      { "DARK", "FAIRY", 5 }, { "POISON", "FAIRY", 20 },
      { "STEEL", "FAIRY", 20 }, { "DRAGON", "FAIRY", 0 },
    }
    for _, matchup in ipairs(matchups) do
      local id = matchup[1] .. ">" .. matchup[2]
      if not registry:get(id) then
        registry:register(id, { multiplier = matchup[3] })
      end
    end
  end
  ensureBattleTypes()

  local function moveAvailable(game, move)
    local moves = game and game.data and game.data.moves
    if type(moves) == "table" then return moves[move] ~= nil end
    return mod.content.moves:get(move) ~= nil
  end

  local function beyondActive(game)
    if not (beyondKanto and type(beyondKanto.isActive) == "function") then
      return false
    end
    local ok, active = pcall(beyondKanto.isActive, game or nil)
    if ok then return active == true end
    return false
  end

  -- Only rows actually present in the Studio source can enter this result.
  -- Generation 3+ rows have no generation marker and always fail closed.
  local function projectMoves(row, game, maximumEpoch)
    if maximumEpoch == true then maximumEpoch = 2 end
    if maximumEpoch == false then maximumEpoch = 1 end
    local level1, learnset, tmhm = {}, {}, {}
    local seenLevel1, seenLearn, seenMachine = {}, {}, {}
    local audit = {
      source = #row.sourceMoves, level1 = {}, learnset = {}, tmhm = {},
      blockedGeneration = {}, unavailable = {}, excludedKind = {},
    }
    for _, source in ipairs(row.sourceMoves) do
      local origin = type(generationRules) == "table"
          and type(generationRules.moveEpoch) == "function"
          and generationRules.moveEpoch(source.move, game and game.data)
        or tonumber(source.generation) or 99
      local generationAllowed = origin <= math.max(1,
        math.floor(tonumber(maximumEpoch) or 1))
      if source.kind == "breed" or source.kind == "evolution" then
        audit.excludedKind[#audit.excludedKind + 1] = source
      elseif not generationAllowed then
        audit.blockedGeneration[#audit.blockedGeneration + 1] = source
      elseif not moveAvailable(game, source.move) then
        audit.unavailable[#audit.unavailable + 1] = source
      elseif source.kind == "level" then
        if source.level == 1 then
          if not seenLevel1[source.move] then
            seenLevel1[source.move] = true
            level1[#level1 + 1] = source.move
            audit.level1[#audit.level1 + 1] = source
          end
        else
          local key = tostring(source.level) .. ":" .. source.move
          if not seenLearn[key] then
            seenLearn[key] = true
            learnset[#learnset + 1] = { level = source.level, move = source.move }
            audit.learnset[#audit.learnset + 1] = source
          end
        end
      elseif source.kind == "machine" or source.kind == "tutor" then
        if not seenMachine[source.move] then
          seenMachine[source.move] = true
          tmhm[#tmhm + 1] = source.move
          audit.tmhm[#audit.tmhm + 1] = source
        end
      end
    end
    return level1, learnset, tmhm, audit
  end
  S.projectMoves = projectMoves

  local healthBySpecies = {}
  for _, family in ipairs(data.families) do
    local complete = #family.species == 3
    for _, species in ipairs(family.species) do
      local row = data.species[species]
      local health = row and assetHealth(row) or { core = false, shiny = false }
      healthBySpecies[species] = health
      complete = complete and row ~= nil and health.core
    end
    if complete then
      local publicFamily = copy(family)
      S.families[#S.families + 1] = publicFamily
      S.familyById[family.id] = publicFamily
      S.familyById[family.starter] = publicFamily
      S.starters[#S.starters + 1] = family.starter
      for _, species in ipairs(family.species) do
        S.familyBySpecies[species] = publicFamily
      end
    else
      S.audit.skippedFamilies[#S.audit.skippedFamilies + 1] = family.id
      if mod.log and type(mod.log.warn) == "function" then
        mod.log:warn("starter family disabled: incomplete production assets for %s",
          tostring(family.id))
      end
    end
  end

  local function familyEnabled(species)
    return S.familyBySpecies[species] ~= nil
  end

  local function dexText(row)
    local en = ("Starter family.\nFirst recorded in\n%s."):format(row.region)
    local de = ("Starter-Familie.\nErfasst in der\nRegion %s."):format(row.region)
    return tr(en, de)
  end

  for _, species in ipairs(data.order) do
    local row = assert(data.species[species], "missing starter row " .. species)
    if familyEnabled(species) then
      S.order[#S.order + 1] = species
      S.byDex[row.sourceDex] = species
      local health = healthBySpecies[species]
      local level1, learnset, tmhm, moveAudit = projectMoves(row, nil, 1)
      local evolutions = {}
      if row.evolution then
        evolutions[1] = copy(row.evolution)
        S.evolutions[#S.evolutions + 1] = {
          from = species, method = row.evolution.method,
          level = row.evolution.level, species = row.evolution.species,
        }
      end
      local textId = "_KantoAscendantStarter67Dex" .. species
      mod.content.text:register(textId, dexText(row))
      mod.content.cries:register(species, { file = mod.path .. "/" .. row.assets.cry })
      local icon = { image = mod.path .. "/" .. row.assets.icon, frames = 2 }
      mod.content.icons:register(species, icon)
      local inches = math.floor(row.heightM * 39.3700787 + 0.5)
      mod.content.pokemon:register(species, {
        id = species, name = tr(row.names.en, row.names.de),
        dex = row.sourceDex, types = copy(row.types),
        baseStats = copy(row.baseStats), catchRate = row.catchRate,
        baseExp = row.baseExp, growthRate = row.growthRate,
        level1Moves = level1, learnset = learnset, tmhm = tmhm,
        evolutions = evolutions, cry = species,
        spriteFront = mod.path .. "/" .. row.assets.front,
        spriteBack = mod.path .. "/" .. row.assets.back,
        frontSize = 7, trueColor = true,
        battleScaleFront = S.battleScale, battleScaleBack = S.battleScale,
        icon = icon,
        dexEntry = {
          kind = tr("STARTER", "STARTER"), text = textId,
          heightFt = math.floor(inches / 12), heightIn = inches % 12,
          weight = math.floor(row.weightKg * 22.0462262 + 0.5),
          heightM = row.heightM, weightKg = row.weightKg,
        },
      })
      S.audit.species[species] = {
        sourceDex = row.sourceDex, sourceBlob = row.sourceBlob,
        coreAssets = true, shinyAssets = health.shiny,
        moves = moveAudit, beyondKanto = false,
      }
    end
  end

  local function shiny(mon)
    local system = bound.shinySystem
    if system and type(system.isShiny) == "function" then
      local ok, value = pcall(system.isShiny, mon)
      if ok then return value == true end
    end
    return type(mon) == "table" and mon.shiny == true
  end

  local function speciesFrom(value, game)
    if type(value) == "string" and familyEnabled(value) then return value end
    local dex = tonumber(value)
    if dex then return S.byDex[math.floor(dex)] end
    if type(value) == "table" then
      if familyEnabled(value.species) then return value.species end
      if value.mon then return speciesFrom(value.mon, game) end
    end
    local pokemon = game and game.data and game.data.pokemon
    if dex and type(pokemon) == "table" then
      for id, def in pairs(pokemon) do
        if familyEnabled(id) and tonumber(def.dex) == dex then return id end
      end
    end
    return nil
  end

  local function assetFor(species, kind, isShiny)
    local row = data.species[species]
    if not row then return nil end
    local health = healthBySpecies[species]
    if isShiny and health and health.shiny then
      return row.assets[kind .. "Shiny"]
    end
    return row.assets[kind]
  end

  if mod.hooks and type(mod.hooks.wrap) == "function" then
    mod.hooks:wrap("pokemon.sprite", function(nextSprite, path, ctx)
      ctx = ctx or {}
      path = nextSprite(path, ctx)
      local species = speciesFrom(ctx.species or ctx.mon, ctx.game)
      if not species then return path end
      if ctx.mon and (ctx.mon._ascMegaForm or ctx.mon.ascMegaForm) then
        return path
      end
      -- main.lua's lower-priority final resolver has already selected and
      -- armed a generated frame-one path at this point. Yielding here is
      -- essential: returning the old 96x96 still would make every timing
      -- clock look green headlessly while silently disabling live motion.
      local animationRoot = mod.path .. "/assets/crystal_animated/"
      local static2DRoot = mod.path .. "/assets/non_crystal_pixel_2d_67/"
      local neo2DRoot = mod.path .. "/assets/neo_crystal_2d_67/"
      local repairRoot = mod.path .. "/assets/sprite_repair_67/"
      if ctx.kind == "battle" and type(path) == "string"
          and path:sub(1, #repairRoot) == repairRoot then return path end
      if ctx.kind == "battle" and type(path) == "string"
          and path:sub(1, #neo2DRoot) == neo2DRoot then return path end
      if ctx.kind == "battle" and bound.crystalAnimation
          and type(path) == "string"
          and path:sub(1, #animationRoot) == animationRoot then
        return path
      end
      -- The final classic-2D resolver owns every non-Mega #252+ battle pic.
      -- Yield only to its reviewed Gen-II-style tree so VASC and every other
      -- presentation keep this provider's established assets.
      if ctx.kind == "battle" and type(path) == "string"
          and path:sub(1, #static2DRoot) == static2DRoot then
        return path
      end
      local side = ctx.side == "back" and "back" or "front"
      local relative = assetFor(species, side, shiny(ctx.mon))
      if not relative then return path end
      ctx.trueColor = true
      return mod.path .. "/" .. relative
    end, 900)

    mod.hooks:wrap("pokemon.icon", function(nextIcon, path, ctx)
      ctx = ctx or {}
      path = nextIcon(path, ctx)
      local species = speciesFrom(ctx.species or ctx.mon, ctx.game)
      if not species then return path end
      local relative = assetFor(species, "icon", shiny(ctx.mon))
      return relative and mod.path .. "/" .. relative or path
    end, 900)
  end

  function S.speciesAvailable(game, species)
    species = speciesFrom(species, game)
    if not species then return false end
    local pokemon = game and game.data and game.data.pokemon
    if type(pokemon) == "table" then return pokemon[species] ~= nil end
    return mod.content.pokemon:get(species) ~= nil
  end

  local function resolveFamily(familyDef)
    if type(familyDef) == "string" then
      return S.familyById[familyDef] or S.familyBySpecies[familyDef]
    end
    if type(familyDef) == "table" then
      if familyDef.id and S.familyById[familyDef.id] then
        return S.familyById[familyDef.id]
      end
      if familyDef.starter and S.familyById[familyDef.starter] then
        return S.familyById[familyDef.starter]
      end
      if type(familyDef.species) == "table" then return familyDef end
    end
    return nil
  end

  function S.completeFamily(game, familyDef)
    local family = resolveFamily(familyDef)
    if not (family and type(family.species) == "table" and #family.species == 3) then
      return false, { "family" }
    end
    local missing = {}
    for _, species in ipairs(family.species) do
      if not S.speciesAvailable(game, species) then missing[#missing + 1] = species end
    end
    return #missing == 0, missing
  end

  function S.habitatSpeciesAvailable(game)
    local result = {}
    for _, starter in ipairs(S.starters) do
      result[starter] = S.speciesAvailable(game, starter)
    end
    return result
  end

  function S.animationDexes(seed)
    local result = type(seed) == "table" and seed or {}
    for _, species in ipairs(S.order) do
      result[data.species[species].sourceDex] = true
    end
    return result
  end

  local function bindHabitat(habitat)
    if type(habitat) ~= "table" then return false, "habitat" end
    if type(habitat.setSpeciesAuthority) == "function" then
      habitat.setSpeciesAuthority(S)
      return true
    end
    if type(habitat.bindSpeciesAuthority) == "function" then
      habitat.bindSpeciesAuthority(S)
      return true
    end
    if type(habitat.bind) == "function" then
      habitat.bind({ speciesAuthority = S, starterSpecies67 = S })
      return true
    end
    return false, "unsupported"
  end
  S.bindHabitat = bindHabitat

  local function installPartyPaletteCompat()
    local okMenu, PartyMenu = pcall(require, "src.ui.PartyMenu")
    local okPalette, PaletteFX = pcall(require, "src.render.PaletteFX")
    if not (okMenu and okPalette and PartyMenu and PaletteFX
        and type(PartyMenu.sgbPalettes) == "function"
        and type(PaletteFX.trueColorZone) == "function") then
      return false
    end
    PartyMenu._kantoAscendantStarter67TrueColorSpecies =
      PartyMenu._kantoAscendantStarter67TrueColorSpecies or {}
    for _, species in ipairs(S.order) do
      PartyMenu._kantoAscendantStarter67TrueColorSpecies[species] = true
    end
    if not PartyMenu._kantoAscendantStarter67PaletteWrapped then
      local original = PartyMenu.sgbPalettes
      PartyMenu.sgbPalettes = function(menu, game)
        local zones = original(menu, game) or {}
        local party = menu.party or game and game.save and game.save.party or {}
        local authored = PartyMenu._kantoAscendantStarter67TrueColorSpecies or {}
        for index, mon in ipairs(party) do
          if mon and authored[mon.species] then
            local top = index * 2 - 1
            zones[#zones + 1] = PaletteFX.trueColorZone(
              1, top, 2, math.min(11, top + 1))
          end
        end
        return zones
      end
      PartyMenu._kantoAscendantStarter67PaletteWrapped = true
    end
    return true
  end
  S.installPartyPaletteCompat = installPartyPaletteCompat

  function S.bind(values)
    values = type(values) == "table" and values or {}
    if values.shinySystem then bound.shinySystem = values.shinySystem end
    if values.crystalAnimation then
      bound.crystalAnimation = values.crystalAnimation
    end
    if values.followerSprites and bound.followerSprites ~= values.followerSprites then
      bound.followerSprites = values.followerSprites
      if type(values.followerSprites.register) == "function" then
        for _, species in ipairs(S.order) do
          local row = data.species[species]
          values.followerSprites.register(species, {
            normalRelative = row.assets.walker,
            shinyRelative = healthBySpecies[species].shiny
              and row.assets.walkerShiny or row.assets.walker,
            frames = 6, width = 16, height = 96,
            walker = true, trueColor = true,
            source = "PokemonWorkshop GameDataPacks pinned starter block",
          })
        end
      end
    end
    if values.habitat then bindHabitat(values.habitat) end
    installPartyPaletteCompat()
    return S
  end

  function S.attachWilds(wilds)
    if type(wilds) ~= "table" or type(wilds.registerSpriteProvider) ~= "function" then
      return false, "wilds provider API unavailable"
    end
    if wildsBindings[wilds] then return true, "already attached" end
    local original = type(wilds.getSpriteProvider) == "function"
      and wilds.getSpriteProvider("pokemmo") or nil
    if type(original) == "table" and original._kaStarterSpecies67 then
      wildsBindings[wilds] = original
      return true, "already attached"
    end
    local provider = {
      id = "pokemmo", builtin = true, modId = mod.id,
      _kaStarterSpecies67 = true, _fallback = original,
    }
    function provider:isAvailable(game)
      if #S.order > 0 then return true, "KASC 6.7 starter walkers" end
      if original and type(original.isAvailable) == "function" then
        return original:isAvailable(game)
      end
      return false, "no starter or fallback walker provider"
    end
    function provider:resolve(speciesId, variant, game)
      local species = speciesFrom(speciesId, game)
      if species then
        local isShiny = tostring(variant):lower() == "shiny"
        local relative = assetFor(species, "walker", isShiny)
        if relative then
          local path = mod.path .. "/" .. relative
          return {
            id = "SPRITE_OW_WILD_" .. species, image = path,
            frames = 6, walker = true, trueColor = true,
          }, {
            providerId = "pokemmo", usedVariant = isShiny and "shiny" or "normal",
            relativePath = relative, loadPath = path, frames = 6,
            walker = true, bodyRenderer = "NATIVE_SPRITE_RENDERER",
            source = "kanto_ascendant_starter_species_67",
          }, nil
        end
      end
      if original and type(original.resolve) == "function" then
        return original:resolve(speciesId, variant, game)
      end
      return nil, nil, "species outside KASC starter provider"
    end
    local ok, why = wilds.registerSpriteProvider("pokemmo", provider)
    if ok == false then return false, why end
    wildsBindings[wilds] = provider
    return true
  end

  local function refreshLocalization(game)
    local live = game and game.data
    if not live then return 0 end
    local count = 0
    for _, species in ipairs(S.order) do
      local row, pokemon = data.species[species], live.pokemon and live.pokemon[species]
      if pokemon then
        pokemon.name = tr(row.names.en, row.names.de)
        if pokemon.dexEntry then pokemon.dexEntry.kind = tr("STARTER", "STARTER") end
        if live.text then
          live.text["_KantoAscendantStarter67Dex" .. species] = dexText(row)
        end
        count = count + 1
      end
    end
    return count
  end
  S.refreshLocalization = refreshLocalization

  function S.refreshMoves(game, forcedEpoch)
    if not (game and game.data and game.data.pokemon) then return false, "game data" end
    local resolved = type(generationRules) == "table"
        and type(generationRules.resolve) == "function"
        and generationRules.resolve(game) or nil
    local activeEpoch = tonumber(forcedEpoch) or resolved and resolved.activeEpoch
      or (beyondActive(game) and 2 or 1)
    for _, species in ipairs(S.order) do
      local live = game.data.pokemon[species]
      if live then
        local level1, learnset, tmhm, moveAudit =
          projectMoves(data.species[species], game, activeEpoch)
        live.level1Moves, live.learnset, live.tmhm = level1, learnset, tmhm
        S.audit.species[species].moves = moveAudit
        S.audit.species[species].activeEpoch = activeEpoch
      end
    end
    return true, activeEpoch
  end

  function S.install(game)
    if not (game and game.data) then return false, "game data" end
    refreshLocalization(game)
    S.refreshMoves(game)
    installedGames[game] = true
    return true
  end

  if beyondKanto and type(beyondKanto.onChanged) == "function" then
    beyondKanto.onChanged(function(_, changedGame)
      if changedGame and changedGame.data then
        S.install(changedGame)
      end
    end)
  end

  S.data = data
  S.assetHealth = healthBySpecies
  return S
end
