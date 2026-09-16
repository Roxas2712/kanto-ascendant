-- Kanto Ascendant 6.7: complete Hoenn #252-386 runtime authority.
--
-- Source identity, localized Dex prose and support assets are pinned in
-- hoenn_species_67_data.lua. The source catalogue marks 120 identities as
-- normally unowned and 15 as normally supplied by earlier gameplay cards.
-- Reuse is decided from the merged registry, not from that historical hint:
-- a supported engine without one of those earlier owners must still receive
-- the complete #252-386 runtime instead of reaching a real map with an
-- `unknown species` failure.

return function(mod, opts)
  opts = opts or {}
  local data = assert(opts.data, "Hoenn species source data required")
  local runtime = assert(opts.runtimeData, "Hoenn runtime data required")
  local breedingData = assert(opts.breedingData, "shared breeding data required")
  local eggMoves = assert(opts.eggMoves, "shared egg-move table required")
  local i18n = opts.i18n
  local hevoPackages = opts.hevoPackages
  local H = {
    order = {}, registeredOrder = {}, reusedOrder = {}, animationDexOrder = {},
    bySpecies = {}, bySourceDex = {}, byRuntimeDex = {}, partyIcons = {},
    eggMoves = eggMoves,
    source = data._meta, runtimeSource = runtime._meta,
    enabled = opts.enabled ~= false,
    audit = {
      registered = 0, reused = 0, missingAssets = 0,
      projectedMoves = {}, externalEvolutionBranches = {},
      breedingMerged = 0, breedingReused = 0, shedinjaAwards = 0,
      eggMovesMerged = 0, eggMovesUnavailable = 0,
    },
  }
  local bound = { shinySystem = opts.shinySystem }
  local installedGames = setmetatable({}, { __mode = "k" })

  local function tr(en, de)
    return i18n and type(i18n.text) == "function" and i18n.text(en, de) or en
  end

  local function moveAvailable(move)
    return mod.content.moves and mod.content.moves.get
      and mod.content.moves:get(move) ~= nil
  end

  -- Day-Care captures this table by reference.  Reconcile once now and once
  -- after all later move authorities have registered, so a move such as
  -- TWISTER (owned by the legend module) cannot be silently omitted merely
  -- because its owner loads later in main.lua.
  function H.reconcileEggMoves()
    local projectedCount, unavailableCount, sourceCount = 0, 0, 0
    for _, species in ipairs(data.order) do
      local row = assert(data.species[species])
      local sourceEggs = assert(runtime.eggMoves[row.runtimeDex],
        "missing Hoenn egg-move row " .. species)
      assert(sourceEggs.species == species, "Hoenn egg-move identity drift")
      local projected = eggMoves[row.runtimeDex] or {}
      local seen = {}
      for _, move in ipairs(projected) do seen[move] = true end
      for _, move in ipairs(sourceEggs.moves or {}) do
        sourceCount = sourceCount + 1
        if moveAvailable(move) then
          projectedCount = projectedCount + 1
          if not seen[move] then
            projected[#projected + 1], seen[move] = move, true
          end
        else
          unavailableCount = unavailableCount + 1
        end
      end
      if #projected > 0 then eggMoves[row.runtimeDex] = projected end
    end
    H.audit.eggMovesSource = sourceCount
    H.audit.eggMovesMerged = projectedCount
    H.audit.eggMovesUnavailable = unavailableCount
    return projectedCount, unavailableCount
  end
  H.reconcileEggMoves()

  local function copy(value, seen)
    if type(value) ~= "table" then return value end
    seen = seen or {}
    if seen[value] then return seen[value] end
    local out = {}; seen[value] = out
    for key, child in pairs(value) do out[copy(key, seen)] = copy(child, seen) end
    return out
  end

  -- Registration needs a known sprite declaration, not installed optional bytes.
  -- Unknown/missing non-image assets still fail. Actual readers stay unchanged.
  local function declaredOptional(relative)
    local optional = mod.exports and mod.exports.optionalPokemonAssets
    return optional and optional.allowPending(relative) == true or false
  end

  local function readable(relative)
    if type(mod.read) ~= "function" then return true end
    local ok, body = pcall(mod.read, mod, relative)
    return ok and type(body) == "string" and #body > 24
  end

  local function wrapDex(text)
    local lines, line = {}, ""
    for word in tostring(text or ""):gmatch("%S+") do
      local nextLine = line == "" and word or line .. " " .. word
      if #nextLine > 18 and line ~= "" then
        lines[#lines + 1], line = line, word
      else
        line = nextLine
      end
    end
    if line ~= "" then lines[#lines + 1] = line end
    return table.concat(lines, "\n")
  end

  local function ensureFairy()
    local chart = mod.content.type_chart
    if chart and chart.get and not chart:get("FAIRY") then
      chart:register("FAIRY", { name = tr("FAIRY", "FEE"), category = "special" })
    end
  end
  ensureFairy()

  -- Hoenn introduces the two Gen-III experience curves which the reviewed
  -- Gen-I clients deliberately do not ship.  Keep the original integer
  -- formulas (including their inner floors) instead of silently projecting
  -- these species onto a Kanto curve.
  local function erraticExperience(level)
    local n = math.max(1, math.min(100, math.floor(tonumber(level) or 1)))
    local cube = n * n * n
    if n <= 50 then return math.floor(cube * (100 - n) / 50) end
    if n <= 68 then return math.floor(cube * (150 - n) / 100) end
    if n <= 98 then
      return math.floor(cube * math.floor((1911 - 10 * n) / 3) / 500)
    end
    return math.floor(cube * (160 - n) / 100)
  end

  local function fluctuatingExperience(level)
    local n = math.max(1, math.min(100, math.floor(tonumber(level) or 1)))
    local cube = n * n * n
    if n <= 15 then
      return math.floor(cube * (math.floor((n + 1) / 3) + 24) / 50)
    end
    if n <= 35 then return math.floor(cube * (n + 14) / 50) end
    return math.floor(cube * (math.floor(n / 2) + 32) / 50)
  end
  H.growthExperience = {
    ERRATIC = erraticExperience,
    FLUCTUATING = fluctuatingExperience,
  }
  for id, expForLevel in pairs(H.growthExperience) do
    if not mod.content.growth_rates:get(id) then
      mod.content.growth_rates:register(id, { expForLevel = expForLevel })
    end
  end
  -- Reviewed 0.1.96/0.1.98 Pokemon.new still calls Growth without passing the
  -- merged registry.  Mirror the same function objects into its public CURVES
  -- table so creation, Rare Candy, daycare and registry-aware consumers agree.
  local okGrowth, Growth = pcall(require, "src.pokemon.Growth")
  if okGrowth and type(Growth) == "table" and type(Growth.CURVES) == "table" then
    for id, expForLevel in pairs(H.growthExperience) do
      Growth.CURVES[id] = expForLevel
    end
    H.audit.legacyGrowthBridge = true
  else
    H.audit.legacyGrowthBridge = false
  end

  local function breedingEqual(left, right)
    if not (left and right) then return false end
    if left.gender ~= right.gender or left.hatch ~= right.hatch then return false end
    if #(left.groups or {}) ~= #(right.groups or {}) then return false end
    for index, group in ipairs(left.groups or {}) do
      if right.groups[index] ~= group then return false end
    end
    return true
  end

  -- The existing shared table is captured by Day-Care and gender services,
  -- so merge in place.  Collision rows must be byte-semantic equals; a
  -- private slot can never silently change an older species' breeding rules.
  for _, species in ipairs(data.order) do
    local row = assert(data.species[species], "missing Hoenn row " .. species)
    local breed = assert(runtime.breeding[row.runtimeDex],
      "missing Hoenn breeding row " .. species)
    local projected = {
      gender = breed.gender, hatch = breed.hatch, groups = copy(breed.groups),
    }
    if breedingData[row.runtimeDex] then
      assert(breedingEqual(breedingData[row.runtimeDex], projected),
        "Hoenn breeding slot collision " .. tostring(row.runtimeDex))
      H.audit.breedingReused = H.audit.breedingReused + 1
    else
      breedingData[row.runtimeDex] = projected
      H.audit.breedingMerged = H.audit.breedingMerged + 1
    end
  end

  local function stableWurmpleBranch(mon)
    local dvs = type(mon) == "table" and mon.dvs or {}
    local value = (tonumber(dvs.attack) or 0) * 4096
      + (tonumber(dvs.defense) or 0) * 256
      + (tonumber(dvs.speed) or 0) * 16
      + (tonumber(dvs.special) or 0)
    return value % 10 < 5 and "SILCOON" or "CASCOON"
  end
  H.stableWurmpleBranch = stableWurmpleBranch

  local function registerWurmpleMethod(id, target)
    local registry = mod.content.evolution_methods
    if registry:get(id) then return end
    registry:register(id, {
      check = function(_, mon, evolution, trigger)
        return type(trigger) == "table" and trigger.kind == "levelup"
          and (tonumber(mon and mon.level) or 0) >= (evolution.level or 7)
          and stableWurmpleBranch(mon) == target
      end,
      describe = function(evolution)
        return tr("Level " .. tostring(evolution.level or 7),
          "Level " .. tostring(evolution.level or 7))
      end,
    })
  end
  registerWurmpleMethod("KA_HOENN_WURMPLE_SILCOON", "SILCOON")
  registerWurmpleMethod("KA_HOENN_WURMPLE_CASCOON", "CASCOON")

  local customItems = {
    PRISM_SCALE = { en = "PRISM SCALE", de = "SCHÖNSCHUPPE" },
    DEEP_SEA_TOOTH = { en = "DEEP SEA TOOTH", de = "ABYSSZAHN" },
    DEEP_SEA_SCALE = { en = "DEEP SEA SCALE", de = "ABYSSPLATTE" },
  }
  local itemEffect = "KA_HOENN_EVOLUTION_ITEM_EFFECT"
  if not mod.content.item_effects:get(itemEffect) then
    mod.content.item_effects:register(itemEffect, {
      field = true, battle = false, needsTarget = true,
      use = function(dataArg, save, itemId, target, battle)
        if save == nil and itemId == nil and type(dataArg) == "table"
            and dataArg.data ~= nil and dataArg.itemId ~= nil then
          local context = dataArg
          dataArg, save, itemId, target, battle = context.data, context.save,
            context.itemId, context.target, context.battle
        end
        if battle or type(target) ~= "table" or target.isEgg or target.egg
            or target.eggSpecies or (tonumber(target.hp) or 0) <= 0 then
          return "failed", { tr("It won't have\nany effect.",
            "Es hat keine\nWirkung.") }
        end
        -- The registered ITEM row alone is not permission to evolve. Use
        -- the same generation/gift and target checks as the native offer,
        -- including when the later gift adapter is absent or yields.
        local pending = require("src.pokemon.Evolution").pendingFor(
          {data=dataArg,save=save}, target, {kind="item",item=itemId})
        if pending then
          return "consumed", nil, {
            evolveTo = pending, evolveVia = "ITEM", hoennEvolutionItem = itemId,
          }
        end
        return "failed", { tr("It won't have\nany effect.",
          "Es hat keine\nWirkung.") }
      end,
    })
  end
  for id, labels in pairs(customItems) do
    if not mod.content.items:get(id) then
      mod.content.items:register(id, {
        id = id, name = tr(labels.en, labels.de), price = 2100,
        tossable = true, needsTarget = true, effect = itemEffect,
        originEpoch = 3,
      })
    end
  end

  local function projectMoves(row)
    local level1, learnset, machines = {}, {}, {}
    local levelRows, seenLevel1, seenLearn, seenMachine = {}, {}, {}, {}
    local audit = { unavailable = {}, excluded = {}, fallback = nil }
    for _, source in ipairs(row.sourceMoves or {}) do
      if source.kind == "breed" or source.kind == "evolution" then
        audit.excluded[#audit.excluded + 1] = copy(source)
      elseif not moveAvailable(source.move) then
        audit.unavailable[#audit.unavailable + 1] = copy(source)
      elseif source.kind == "level" then
        levelRows[#levelRows + 1] = source
        if source.level == 1 and not seenLevel1[source.move] then
          level1[#level1 + 1], seenLevel1[source.move] = source.move, true
        elseif source.level > 1 then
          local key = tostring(source.level) .. ":" .. source.move
          if not seenLearn[key] then
            learnset[#learnset + 1] = { level = source.level, move = source.move }
            seenLearn[key] = true
          end
        end
      elseif source.kind == "machine" or source.kind == "tutor" then
        if not seenMachine[source.move] then
          machines[#machines + 1], seenMachine[source.move] = source.move, true
        end
      end
    end
    if #level1 == 0 and #levelRows > 0 then
      level1[1] = levelRows[1].move
      audit.fallback = copy(levelRows[1])
    end
    assert(#level1 > 0, row.species .. " has no available canonical level move")
    return level1, learnset, machines, audit
  end
  H.projectMoves = projectMoves

  local assetKeys = {
    "frontAnimation", "frontShinyAnimation", "backAnimation",
    "backShinyAnimation", "icon", "iconShiny", "follower",
    "followerShiny", "cry",
  }
  local pending = {}
  for _, species in ipairs(data.order) do
    local row = data.species[species]
    H.order[#H.order + 1] = species
    H.animationDexOrder[#H.animationDexOrder + 1] = row.runtimeDex
    H.bySpecies[species] = row
    H.bySourceDex[row.sourceDex] = species
    H.byRuntimeDex[row.runtimeDex] = species
    for _, key in ipairs(assetKeys) do
      if not readable(row.assets[key]) and not declaredOptional(row.assets[key]) then
        H.audit.missingAssets = H.audit.missingAssets + 1
        error(species .. " missing Hoenn runtime asset " .. key)
      end
    end
    local existing = mod.content and mod.content.pokemon
      and type(mod.content.pokemon.get) == "function"
      and mod.content.pokemon:get(species) or nil
    if not existing then
      pending[species] = true
      H.registeredOrder[#H.registeredOrder + 1] = species
      if row.registrationStatus ~= "pending_full_hoenn_registration" then
        H.audit.missingHistoricalOwners = H.audit.missingHistoricalOwners or {}
        H.audit.missingHistoricalOwners[#H.audit.missingHistoricalOwners + 1]
          = species
      end
    else
      H.reusedOrder[#H.reusedOrder + 1] = species
    end
  end

  local function publicBranches(species)
    local out = {}
    for _, branch in ipairs(runtime.evolutions[species] or {}) do
      if branch.authority == "hevo_package" then
        H.audit.externalEvolutionBranches[#H.audit.externalEvolutionBranches + 1] = {
          parent = species, target = branch.species, authority = branch.authority,
        }
      else
        local value = {
          method = branch.method, species = branch.species,
        }
        if branch.level then value.level = branch.level end
        if branch.item then value.item = branch.item end
        out[#out + 1] = value
      end
    end
    return out
  end

  if H.enabled then
    -- Register cries before species so strict reference validation sees the
    -- complete graph regardless of species order.
    for _, species in ipairs(H.registeredOrder) do
      local row = data.species[species]
      mod.content.cries:register(species, {
        file = mod.path .. "/" .. row.assets.cry,
      })
    end
    for _, species in ipairs(H.registeredOrder) do
      local row = data.species[species]
      local level1, learnset, tmhm, moveAudit = projectMoves(row)
      H.audit.projectedMoves[species] = moveAudit
      local textId = "_KantoAscendantHoenn67Dex" .. species
      mod.content.text:register(textId,
        wrapDex(tr(row.dexText.en, row.dexText.de)))
      local inches = math.floor(row.heightM * 39.3700787 + 0.5)
      local icon = { image = mod.path .. "/" .. row.assets.icon, frames = 2 }
      H.partyIcons[species] = {
        normal = row.assets.icon, shiny = row.assets.iconShiny, frames = 2,
      }
      mod.content.icons:register(species, icon)
      mod.content.pokemon:register(species, {
        id = species, name = tr(row.names.en, row.names.de),
        dex = row.runtimeDex, sourceDex = row.sourceDex,
        types = copy(row.types), baseStats = copy(row.baseStats),
        catchRate = row.catchRate, baseExp = row.runtimeBaseExp,
        growthRate = row.growthRate,
        level1Moves = level1, learnset = learnset, tmhm = tmhm,
        evolutions = publicBranches(species), cry = species,
        spriteFront = mod.path .. "/" .. row.assets.frontAnimation,
        spriteBack = mod.path .. "/" .. row.assets.backAnimation,
        frontSize = 7, trueColor = true,
        battleScaleFront = 7 / 12, battleScaleBack = 7 / 12,
        icon = icon,
        dexEntry = {
          kind = tr(row.kind.en, row.kind.de), text = textId,
          heightFt = math.floor(inches / 12), heightIn = inches % 12,
          weight = math.floor(row.weightKg * 22.0462262 + 0.5),
          heightM = row.heightM, weightKg = row.weightKg,
        },
      })
      H.audit.registered = H.audit.registered + 1
    end
  end
  H.audit.reused = #H.reusedOrder

  -- HEVO packages already own these progression gates. Their targets were
  -- registered before the Hoenn parents existed, so append their exact rows
  -- now instead of inventing ungated Dawn/Shiny-stone shortcuts.
  function H.reconcileHevo()
    if not (H.enabled and hevoPackages
        and type(hevoPackages.evolutionRows) == "function") then return 0 end
    local appended = 0
    for _, row in ipairs(hevoPackages.evolutionRows()) do
      local parent = mod.content.pokemon:get(row.parent)
      if parent and pending[row.parent] then
        local evolutions, duplicate = copy(parent.evolutions or {}), false
        for _, branch in ipairs(evolutions) do
          if branch.species == row.target then duplicate = true break end
        end
        if not duplicate then
          local branch = { method = row.method, species = row.target }
          if row.item then branch.item = row.item end
          evolutions[#evolutions + 1] = branch
          mod.content.pokemon:patch(row.parent, { evolutions = evolutions })
          appended = appended + 1
        end
      end
    end
    H.audit.hevoBranches = appended
    return appended
  end
  H.reconcileHevo()

  local function shiny(mon)
    if bound.shinySystem and type(bound.shinySystem.isShiny) == "function" then
      local ok, value = pcall(bound.shinySystem.isShiny, mon)
      if ok then return value == true end
    end
    return type(mon) == "table" and mon.shiny == true
  end

  if mod.hooks and type(mod.hooks.wrap) == "function" then
    mod.hooks:wrap("pokemon.sprite", function(nextSprite, path, ctx)
      ctx = ctx or {}; local resolved = nextSprite(path, ctx)
      local row = pending[ctx.species] and data.species[ctx.species] or nil
      if not row or ctx.mon and (ctx.mon._ascMegaForm or ctx.mon.ascMegaForm) then
        return resolved
      end
      local static2DRoot = mod.path .. "/assets/non_crystal_pixel_2d_67/"
      local neo2DRoot = mod.path .. "/assets/neo_crystal_2d_67/"
      local repairRoot = mod.path .. "/assets/sprite_repair_67/"
      if ctx.kind == "battle" and type(resolved) == "string"
          and resolved:sub(1, #repairRoot) == repairRoot then return resolved end
      if ctx.kind == "battle" and type(resolved) == "string"
          and resolved:sub(1, #neo2DRoot) == neo2DRoot then return resolved end
      if ctx.kind == "battle" and type(resolved) == "string"
          and resolved:sub(1, #static2DRoot) == static2DRoot then
        return resolved
      end
      local side = ctx.side == "back" and "back" or "front"
      local key = side .. (shiny(ctx.mon) and "ShinyAnimation" or "Animation")
      ctx.trueColor = true
      return mod.path .. "/" .. row.assets[key]
    end, 835)
    mod.hooks:wrap("pokemon.icon", function(nextIcon, path, ctx)
      ctx = ctx or {}; local resolved = nextIcon(path, ctx)
      local species = ctx.species or ctx.mon and ctx.mon.species
      local row = pending[species] and data.species[species] or nil
      if not row then return resolved end
      local relative = shiny(ctx.mon) and row.assets.iconShiny or row.assets.icon
      return mod.path .. "/" .. relative
    end, 835)
  end

  function H.animationDexes(seed)
    local out = copy(seed or {})
    for _, dex in ipairs(H.animationDexOrder) do out[dex] = true end
    return out
  end

  function H.bind(services)
    services = services or {}
    if services.shinySystem then bound.shinySystem = services.shinySystem end
    if services.followerSprites and type(services.followerSprites.register) == "function" then
      for _, species in ipairs(H.registeredOrder) do
        local row = data.species[species]
        services.followerSprites.register(species, {
          normalRelative = row.assets.follower,
          shinyRelative = row.assets.followerShiny,
          frames = 6, width = 16, height = 96,
          walker = true, trueColor = true,
          source = "Pinned complete Hoenn #252-386 support catalogue",
        })
      end
    end
    return H
  end

  local function awardShedinja(game, evolved)
    local rule = runtime.shedinja
    if not (H.enabled and game and game.data and game.save and type(evolved)=="table"
        and evolved.fromSpecies == rule.source
        and evolved.toSpecies == rule.evolved
        and (evolved.via==nil or evolved.via=="LEVEL")) then return false, "event" end
    local source=evolved.mon
    if type(source)~="table" or source.species~=rule.evolved
        or source.isEgg or source.egg or source.eggSpecies
        or source.form or source.formId or source.baseSpecies
        or source._ascMegaForm or source.ascMegaForm
        or type(source.level)~="number" or source.level%1~=0
        or source.level<rule.level or source.level>100
        or type(source.hp)~="number" or not(source.hp>0 and source.hp<math.huge)
        or type(game.save.party)~="table" or type(game.save.inventory)~="table" then
      return false,"source"
    end
    local inParty=false
    for _,mon in ipairs(game.save.party)do if mon==source then inParty=true;break end end
    if not inParty then return false,"source-not-in-party"end
    if #game.save.party >= 6 then return false, "party-full" end
    local balls=game.save.inventory[rule.ball]
    if type(balls)~="number" or balls%1~=0 or balls<1 or balls==math.huge then return false,"ball"end
    -- Durable per-parent receipt: a duplicated event must not award again
    -- just because another Ball remains. Rejected/full-party attempts do not
    -- stamp anything; only the completed award below commits this marker.
    if source._kascShedinjaAward67~=nil then return false,"already-awarded"end
    local okPokemon, Pokemon = pcall(require, "src.pokemon.Pokemon")
    local okBag, Bag = pcall(require, "src.inventory.Bag")
    if not (okPokemon and okBag) then return false, "engine" end
    local order, cursor = { "attack", "defense", "speed", "special" }, 0
    local bonus = Pokemon.new(game.data, rule.bonus, source.level, function()
      cursor = cursor + 1
      return tonumber(source.dvs and source.dvs[order[cursor]]) or 0
    end)
    bonus.ot, bonus.otId = source.ot, source.otId
    bonus.met = copy(source.met)
    local special=mod.exports and mod.exports.wave1Shedinja67
    if special and special.ready and not special.prepareBonus(game,source,bonus)then
      return false,"bonus-provenance"
    end
    game.save.party[#game.save.party + 1] = bonus
    Bag.remove(game.save, rule.ball, 1)
    source._kascShedinjaAward67={version=1,species=rule.bonus}
    game.save.pokedex = game.save.pokedex or { seen = {}, owned = {} }
    game.save.pokedex.seen = game.save.pokedex.seen or {}
    game.save.pokedex.owned = game.save.pokedex.owned or {}
    game.save.pokedex.seen[rule.bonus] = true
    game.save.pokedex.owned[rule.bonus] = true
    H.audit.shedinjaAwards = H.audit.shedinjaAwards + 1
    return true, bonus
  end
  H.awardShedinja = awardShedinja

  if mod.events and type(mod.events.on) == "function" then
    mod.events:on("pokemon.evolved", function(event)
      awardShedinja(event and event.game or H.game, event)
    end)
  end

  function H.install(game)
    if not (H.enabled and game and game.data) then return false end
    H.game = game
    local special=mod.exports and mod.exports.wave1Shedinja67
    if special and special.ready then special.install(game)end
    if installedGames[game] then return true end
    installedGames[game] = true
    local live = game.data
    live.audio = live.audio or {}; live.audio.cries = live.audio.cries or {}
    for _, species in ipairs(H.registeredOrder) do
      local row = data.species[species]
      live.audio.cries[species] = live.audio.cries[species] or {
        file = mod.path .. "/" .. row.assets.cry,
      }
      if live.pokemon and live.pokemon[species] then
        live.pokemon[species].cry = species
      end
    end
    return true
  end

  assert(#H.order == 135, "Hoenn authority identity count drift")
  assert(#H.registeredOrder + #H.reusedOrder == 135,
    "Hoenn ownership partition drift")
  return H
end
