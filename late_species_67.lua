-- Kanto Ascendant 6.7: late evolutions and Rocket-raid contraband species.
--
-- These identities deliberately expose only a placeholder Dex article. Their
-- complete normal/shiny front/back, party, follower, cry and animation
-- surfaces are nevertheless mandatory: unsupported or missing art is a hard
-- registration failure, never a front-sprite fallback for a back view.

return function(mod, opts)
  opts = opts or {}
  local data = assert(opts.data, "late species 6.7 data required")
  local i18n = opts.i18n
  local L = {
    order = {}, bySpecies = {}, byDex = {}, animationDexOrder = {},
    partyIcons = {}, enabled = opts.enabled ~= false,
    CARD_ID = "KASC-67-LATE-SPECIES",
    OWNER = "kasc.species.late-evolutions-and-raid-captures/v1",
    OPTION_KEY = "late_species_67",
    audit = { registered = 0, evolutions = 0, items = 0 },
  }
  local bound = {
    shinySystem = opts.shinySystem,
    crystalAnimation = opts.crystalAnimation,
    pokemonGender = opts.pokemonGender,
  }
  -- Dawn Stone keeps the original ITEM registry schema, but its two
  -- canonical branches must also respect the persistent gender owner.
  local dawnTargets = {
    KIRLIA = { species = "GALLADE", gender = "MALE" },
    SNORUNT = { species = "FROSLASS", gender = "FEMALE" },
  }
  local dawnGuardInstalled = false
  local function healthyNonEgg(mon)
    local hp = type(mon) == "table" and tonumber(mon.hp)
    return hp and hp > 0 and hp < math.huge
      and not mon.isEgg and not mon.eggSpecies and not mon.egg or false
  end
  local function dawnEligible(game, mon)
    local row = type(mon) == "table" and dawnTargets[mon.species]
    local gender = bound.pokemonGender
    return row and healthyNonEgg(mon) and gender
      and type(gender.getMonGender) == "function"
      and gender.getMonGender(mon, game) == row.gender or false
  end

  local ITEM_NAMES = {
    SHINY_STONE = { en = "SHINY STONE", de = "LEUCHTSTEIN" },
    REAPER_CLOTH = { en = "REAPER CLOTH", de = "DÜSTERUMHANG" },
    DAWN_STONE = { en = "DAWN STONE", de = "FUNKELSTEIN" },
    MAGNETIC_CORE = { en = "MAGNETIC CORE", de = "MAGNETKERN" },
    -- AFFECTION_RIBBON and SYLVEON have their own reversible Fairy card in
    -- this combined candidate. This owner must not replace its item effect.
    ANCESTRAL_REINS = { en = "ANCESTRAL REINS", de = "AHNENZÜGEL" },
    BLACK_AUGURITE = { en = "BLACK AUGURITE", de = "SCHWARZER AUGIT" },
    PEAT_BLOCK = { en = "PEAT BLOCK", de = "TORFBLOCK" },
    RAGE_FETTER = { en = "RAGE FETTER", de = "ZORNESFESSEL" },
    TWIN_BEAM_PRISM = { en = "TWIN-BEAM PRISM", de = "DOPPELSTRAHLPRISMA" },
    HYPER_DRILL_CORE = { en = "HYPER-DRILL CORE", de = "HYPERBOHRKERN" },
  }
  local ITEM_EFFECT = "KA_LATE_SPECIES_67_EVOLUTION_ITEM"
  local oldItemEffects = {}

  if opts.supportLog and type(opts.supportLog.registerSegment) == "function" then
    opts.supportLog.registerSegment({
      segmentId=L.CARD_ID, cardId=L.CARD_ID, version="1.0.0",
      schema="kasc.optional-feature-card/v1", owner=L.OWNER,
      active=L.enabled, dependencyStatus="local-reviewed",
      providerStatus=L.enabled and "runtime-loaded" or "cold-disabled",
      buildReceiptId="docs/LATE_SPECIES_CARD_67.md",
      rollbackReceiptId="select-late-species-off",
    })
  end

  local function tr(en, de)
    return i18n and i18n.text and i18n.text(en, de) or en
  end
  local function copy(value)
    if type(value) ~= "table" then return value end
    local out = {}
    for key, child in pairs(value) do out[key] = copy(child) end
    return out
  end
  -- Registration needs a known sprite declaration, not installed optional bytes.
  -- Unknown/missing non-image assets still fail. Actual readers stay unchanged.
  local function declaredOptional(relative)
    local optional = mod.exports and mod.exports.optionalPokemonAssets
    return optional and optional.allowPending(relative) == true or false
  end

  local function readable(relative)
    return type(relative) == "string"
      and (type(mod.read) ~= "function" or type(mod:read(relative)) == "string")
  end
  local function shiny(mon)
    if bound.shinySystem and type(bound.shinySystem.isShiny) == "function" then
      local ok, value = pcall(bound.shinySystem.isShiny, mon)
      if ok then return value == true end
    end
    return type(mon) == "table" and mon.shiny == true
  end
  local function moveAvailable(id)
    return mod.content.moves and mod.content.moves.get
      and mod.content.moves:get(id) ~= nil
  end
  local function projectedMoves(row)
    local out = {}
    for _, move in ipairs(row.level1Moves or {}) do
      if moveAvailable(move) then out[#out + 1] = move end
    end
    assert(#out > 0, row.id .. " has no registered safe move")
    return out
  end
  local function projectedBaseExp(row)
    assert(type(row.baseExp) == "number" and row.baseExp % 1 == 0
      and row.baseExp >= 0, row.id .. " has invalid source baseExp")
    -- Gen1Recomp exposes baseExp through the original one-byte ABI. Keep the
    -- modern source yield in late_species_67_data.lua, but project the value
    -- supplied to the engine exactly as the Hoenn importer already does.
    return math.min(row.baseExp, 255)
  end
  local function normalizeItemArgs(dataArg, save, itemId, target, battle)
    if save == nil and itemId == nil and type(dataArg) == "table"
        and dataArg.data ~= nil and dataArg.itemId ~= nil then
      local context = dataArg
      return context.data, context.save, context.itemId,
        context.target, context.battle
    end
    return dataArg, save, itemId, target, battle
  end

  if L.enabled then
    mod.content.item_effects:register(ITEM_EFFECT, {
      field = true, battle = false, needsTarget = true,
      callStyle = "legacyArgs",
      use = function(dataArg, save, itemId, target, battle)
        dataArg, save, itemId, target, battle = normalizeItemArgs(
          dataArg, save, itemId, target, battle)
        if not battle and type(target) == "table" then
          for _, species in ipairs(data.order or {}) do
            local row = data.species[species]
            if row.parent == target.species and row.evolutionItem == itemId then
              -- Item use must not bypass the engine's generation, gift,
              -- gender or body guards by returning an evolution directly.
              local game = { data = dataArg, save = save }
              local pending = healthyNonEgg(target)
                and require("src.pokemon.Evolution").pendingFor(game, target,
                  { kind = "item", item = itemId })
              if pending ~= species then
                return "failed", { tr("It won't have\nany effect.",
                  "Es hat keine\nWirkung.") }
              end
              return "consumed", nil, {
                evolveTo = species, evolveVia = "ITEM",
                lateSpeciesEvolutionItem = itemId,
              }
            end
          end
        end
        local previous = oldItemEffects[itemId]
        if previous and type(previous.use) == "function" then
          return previous.use(dataArg, save, itemId, target, battle)
        end
        return "failed", { tr("It won't have\nany effect.",
          "Es hat keine\nWirkung.") }
      end,
    })
  end

  local assetKeys = {
    "front", "frontShiny", "back", "backShiny", "icon", "iconShiny",
    "follower", "followerShiny", "cry",
  }
  for _, species in ipairs(data.order or {}) do
    local row = assert(data.species[species], "missing late species " .. species)
    for _, key in ipairs(assetKeys) do
      assert(readable(row.assets[key]) or declaredOptional(row.assets[key]), species .. " missing asset " .. key)
    end
    L.order[#L.order + 1] = species
    L.animationDexOrder[#L.animationDexOrder + 1] = row.dex
    L.bySpecies[species], L.byDex[row.dex] = row, species
    L.partyIcons[species] = {
      normal = row.assets.icon, shiny = row.assets.iconShiny, frames = 2,
    }

    if L.enabled then
      local parent = row.parent and mod.content.pokemon:get(row.parent) or nil
      if row.parent then
        assert(parent, species .. " missing evolution parent " .. row.parent)
      end
      mod.content.cries:register(species, {
        file = mod.path .. "/" .. row.assets.cry,
      })
      local textId = "_KantoAscendantLate67Dex" .. species
      mod.content.text:register(textId, "???")
      local icon = { image = mod.path .. "/" .. row.assets.icon, frames = 2 }
      mod.content.icons:register(species, icon)
      local inches = math.floor(row.heightM * 39.3700787 + 0.5)
      mod.content.pokemon:register(species, {
        id = species, name = tr(row.names.en, row.names.de),
        dex = row.dex, sourceDex = row.dex,
        originGeneration = row.originGeneration,
        types = copy(row.types), baseStats = copy(row.baseStats),
        catchRate = parent and parent.catchRate or 3,
        baseExp = projectedBaseExp(row),
        growthRate = parent and parent.growthRate or "SLOW",
        level1Moves = projectedMoves(row), learnset = {},
        tmhm = copy(parent and parent.tmhm or {}), evolutions = {}, cry = species,
        spriteFront = mod.path .. "/" .. row.assets.front,
        spriteBack = mod.path .. "/" .. row.assets.back,
        frontSize = 7, trueColor = true,
        battleScaleFront = 1, battleScaleBack = 1,
        icon = icon, dexPlaceholder = true, certificateExcluded = true,
        raidCapture = row.parent == nil,
        dexEntry = {
          kind = "???", text = textId,
          heightFt = math.floor(inches / 12), heightIn = inches % 12,
          weight = math.floor(row.weightKg * 22.0462262 + 0.5),
          heightM = row.heightM, weightKg = row.weightKg,
        },
      })
      L.audit.registered = L.audit.registered + 1
    end
  end

  if L.enabled then
    for itemId, labels in pairs(ITEM_NAMES) do
      local item = mod.content.items:get(itemId)
      if item then
        local previous = item.effect and mod.content.item_effects:get(item.effect)
        if previous and item.effect ~= ITEM_EFFECT then
          oldItemEffects[itemId] = previous
        end
        mod.content.items:patch(itemId, {
          needsTarget = true, effect = ITEM_EFFECT,
        })
      else
        mod.content.items:register(itemId, {
          id = itemId, name = tr(labels.en, labels.de), price = 0,
          tossable = true, needsTarget = true, effect = ITEM_EFFECT,
          rocketRaidReward = true,
        })
      end
      L.audit.items = L.audit.items + 1
    end
    for _, species in ipairs(L.order) do
      local row = L.bySpecies[species]
      if row.parent then
        local parent = assert(mod.content.pokemon:get(row.parent))
        local evolutions, duplicate = copy(parent.evolutions or {}), false
        for _, evolution in ipairs(evolutions) do
          if evolution.species == species then duplicate = true break end
        end
        if not duplicate then
          evolutions[#evolutions + 1] = {
            method = "ITEM", item = row.evolutionItem, species = species,
          }
          mod.content.pokemon:patch(row.parent, { evolutions = evolutions })
          L.audit.evolutions = L.audit.evolutions + 1
        end
      end
    end
  end

  if mod.hooks and type(mod.hooks.wrap) == "function" then
    if L.enabled then
      mod.hooks:wrap("evolution.check", function(nextCheck, game, mon, evo, trigger)
        local target = type(evo) == "table" and L.bySpecies[evo.species]
        if target and type(mon) == "table" and target.parent == mon.species
            and evo.method == "ITEM" and evo.item == target.evolutionItem
            and not healthyNonEgg(mon) then return false end
        local row = type(mon) == "table" and dawnTargets[mon.species]
        if row and type(evo) == "table" and evo.species == row.species
            and evo.method == "ITEM" and evo.item == "DAWN_STONE"
            and not dawnEligible(game, mon) then return false end
        return nextCheck(game, mon, evo, trigger)
      end, 9450)
      dawnGuardInstalled = true
    end
    mod.hooks:wrap("pokemon.sprite", function(nextSprite, path, ctx)
      ctx = ctx or {}
      local resolved = nextSprite(path, ctx)
      local row = L.bySpecies[ctx.species or ctx.mon and ctx.mon.species]
      if not row then return resolved end
      local animationRoot = mod.path .. "/assets/crystal_animated/"
      local static2DRoot = mod.path .. "/assets/non_crystal_pixel_2d_67/"
      local neo2DRoot = mod.path .. "/assets/neo_crystal_2d_67/"
      local repairRoot = mod.path .. "/assets/sprite_repair_67/"
      if ctx.kind == "battle" and type(resolved) == "string"
          and resolved:sub(1, #repairRoot) == repairRoot then return resolved end
      if ctx.kind == "battle" and type(resolved) == "string"
          and resolved:sub(1, #neo2DRoot) == neo2DRoot then return resolved end
      if ctx.kind == "battle" and bound.crystalAnimation
          and type(resolved) == "string"
          and resolved:sub(1, #animationRoot) == animationRoot then
        return resolved
      end
      if ctx.kind == "battle" and type(resolved) == "string"
          and resolved:sub(1, #static2DRoot) == static2DRoot then
        return resolved
      end
      local side = ctx.side == "back" and "back" or "front"
      local key = side .. (shiny(ctx.mon) and "Shiny" or "")
      ctx.trueColor = true
      return mod.path .. "/" .. row.assets[key]
    end, 915)
    mod.hooks:wrap("pokemon.icon", function(nextIcon, path, ctx)
      ctx = ctx or {}
      local resolved = nextIcon(path, ctx)
      local row = L.bySpecies[ctx.species or ctx.mon and ctx.mon.species]
      if not row then return resolved end
      return mod.path .. "/" .. row.assets[
        shiny(ctx.mon) and "iconShiny" or "icon"]
    end, 915)
  end

  function L.animationDexes(seed)
    local out = copy(seed or {})
    for _, dex in ipairs(L.animationDexOrder) do out[dex] = true end
    return out
  end

  function L.supportsDawnEvolution(parent, target, gender)
    local row=dawnTargets[parent]
    return L.enabled and dawnGuardInstalled and row and row.species==target
      and row.gender==gender and bound.pokemonGender
      and type(bound.pokemonGender.getMonGender)=='function' or false
  end

  function L.bind(services)
    services = services or {}
    if services.pokemonGender then bound.pokemonGender = services.pokemonGender end
    if services.shinySystem then bound.shinySystem = services.shinySystem end
    if services.crystalAnimation then
      bound.crystalAnimation = services.crystalAnimation
    end
    if L.enabled and services.followerSprites
        and type(services.followerSprites.register) == "function" then
      for _, species in ipairs(L.order) do
        local row = L.bySpecies[species]
        services.followerSprites.register(species, {
          normalRelative = row.assets.follower,
          shinyRelative = row.assets.followerShiny,
          frames = 6, width = 16, height = 96,
          walker = true, trueColor = true,
          source = "Showdown fixed-canvas late-species projection",
        })
      end
    end
    return L
  end

  function L.install(game)
    if not L.enabled then return false, "disabled" end
    if not (game and game.data and game.data.pokemon) then
      return false, "game data"
    end
    for _, species in ipairs(L.order) do
      local live, row = game.data.pokemon[species], L.bySpecies[species]
      assert(live, "late species missing from live registry: " .. species)
      live.name = tr(row.names.en, row.names.de)
      if game.data.text then
        game.data.text["_KantoAscendantLate67Dex" .. species] = "???"
      end
    end
    return true
  end

  function L.raidCaptureAvailable(game, raid)
    if not L.enabled or type(raid) ~= "table" then return false end
    local row = L.bySpecies[raid.species]
    return row ~= nil and row.parent == nil
      and game ~= nil and game.data ~= nil
      and type(game.data.pokemon) == "table"
      and game.data.pokemon[row.id] ~= nil
  end

  L.data = data
  return L
end
