-- Self-contained Kanto completion layer.
--
-- KANTO 151 = REWARDS keeps starters and the mutually exclusive fossil as
-- meaningful post-game prizes.  WILD mirrors the convenience style of an
-- all-catchable hack.  Both modes remove trade/version lockouts; neither
-- places Mew in a random encounter because Kanto Ascendant has a dedicated
-- Mew event.

local STARTER_REWARDS = {
  erika = { species = "BULBASAUR", level = 5 },
  misty = { species = "SQUIRTLE", level = 5 },
  blaine = { species = "CHARMANDER", level = 5 },
}

local FOSSILS = {
  {
    item = "DOME_FOSSIL",
    flag = "EVENT_GOT_DOME_FOSSIL",
    species = { "KABUTO", "KABUTOPS" },
  },
  {
    item = "HELIX_FOSSIL",
    flag = "EVENT_GOT_HELIX_FOSSIL",
    species = { "OMANYTE", "OMASTAR" },
  },
}

local TRADE_EVOLUTIONS = {
  KADABRA = { species = "ALAKAZAM", level = 42 },
  GRAVELER = { species = "GOLEM", level = 42 },
  HAUNTER = { species = "GENGAR", level = 42 },
  MACHOKE = { species = "MACHAMP", level = 45 },
}

local POSTGAME_EEVEE = {
  map = "ROUTE_7",
  level = 25,
  chance = 2,
}

-- An active Legacy Journey lets the three Kanto starters establish a rare
-- early habitat without removing their guaranteed late-game sources.  These
-- are ordinary wild encounters: Randomizer and Nuzlocke process them through
-- their normal public hooks.  A per-habitat pity ceiling prevents a player
-- from being trapped behind an arbitrarily long unlucky streak.
local LEGACY_EARLY_STARTERS = {
  VIRIDIAN_FOREST = {
    terrain = "grass", species = "BULBASAUR", level = 5,
    chance = 2, pity = 50,
  },
  ROUTE_4 = {
    terrain = "grass", species = "CHARMANDER", level = 7,
    chance = 2, pity = 50,
  },
  ROUTE_24 = {
    terrain = "grass", species = "SQUIRTLE", level = 9,
    chance = 2, pity = 50,
  },
}

-- Only the slots needed to remove edition/one-time choice locks are changed.
-- Keeping the remaining native slots makes the routes still feel like Kanto.
local SHARED_ENCOUNTERS = {
  VIRIDIAN_FOREST = {
    [2] = { level = 3, species = "WEEDLE" },
    [4] = { level = 4, species = "WEEDLE" },
    [6] = { level = 5, species = "KAKUNA" },
  },
  ROUTE_5 = {
    [3] = { level = 10, species = "MEOWTH" },
    [5] = { level = 12, species = "ODDISH" },
    [7] = { level = 10, species = "MANKEY" },
    [8] = { level = 12, species = "BELLSPROUT" },
  },
  ROUTE_8 = {
    [4] = { level = 17, species = "EKANS" },
    [5] = { level = 17, species = "SANDSHREW" },
    [6] = { level = 19, species = "GROWLITHE" },
    [7] = { level = 19, species = "VULPIX" },
  },
  SAFARI_ZONE_CENTER = {
    [9] = { level = 23, species = "SCYTHER" },
    [10] = { level = 23, species = "PINSIR" },
  },
  SEAFOAM_ISLANDS_B2F = {
    [2] = { level = 30, species = "SLOWPOKE" },
    [6] = { level = 30, species = "STARYU" },
    [8] = { level = 28, species = "SHELLDER" },
  },
  VICTORY_ROAD_1F = {
    [10] = { level = 42, species = "HITMONLEE" },
  },
  VICTORY_ROAD_2F = {
    [10] = { level = 42, species = "HITMONCHAN" },
  },
  POKEMON_MANSION_B1F = {
    [2] = { level = 31, species = "GRIMER" },
    [5] = { level = 30, species = "GROWLITHE" },
    [9] = { level = 35, species = "MAGMAR" },
    -- Explicitly replaces the other mod's wild-Mew slot when both are active.
    [10] = { level = 35, species = "DITTO" },
  },
  POWER_PLANT = {
    [9] = { level = 33, species = "ELECTABUZZ" },
    [10] = { level = 36, species = "ELECTABUZZ" },
  },
}

-- Yellow removes the Koffing family from every native Mansion floor. Keep
-- the shared B1F completion table intact, then replace only two of Yellow's
-- remaining Raticate slots. Red and Blue retain their native family slots.
local YELLOW_ENCOUNTERS = {
  POKEMON_MANSION_B1F = {
    [4] = { level = 35, species = "KOFFING" },
    [8] = { level = 40, species = "WEEZING" },
  },
}

local WILD_ENCOUNTERS = {
  SAFARI_ZONE_EAST = {
    [10] = { level = 23, species = "BULBASAUR" },
  },
  SEAFOAM_ISLANDS_B2F = {
    [10] = { level = 23, species = "SQUIRTLE" },
  },
  SEAFOAM_ISLANDS_B4F = {
    [8] = { level = 35, species = "OMANYTE" },
    [9] = { level = 35, species = "KABUTO" },
    [10] = { level = 35, species = "KABUTO" },
  },
  VICTORY_ROAD_3F = {
    [9] = { level = 45, species = "AERODACTYL" },
    [10] = { level = 23, species = "CHARMANDER" },
  },
  CERULEAN_CAVE_1F = {
    [7] = { level = 49, species = "ALAKAZAM" },
  },
  CERULEAN_CAVE_2F = {
    [9] = { level = 55, species = "MACHAMP" },
  },
  CERULEAN_CAVE_B1F = {
    [8] = { level = 57, species = "GENGAR" },
    [9] = { level = 57, species = "GOLEM" },
  },
}

-- These explicit native slots make REWARDS authoritative even when an older
-- all-catchable mod is still enabled during migration.
local REWARD_GUARD_ENCOUNTERS = {
  SEAFOAM_ISLANDS_B2F = {
    [10] = { level = 37, species = "SLOWBRO" },
  },
  SEAFOAM_ISLANDS_B4F = {
    [8] = { level = 29, species = "SEEL" },
    [9] = { level = 39, species = "SLOWBRO" },
    [10] = { level = 32, species = "GOLBAT" },
  },
  VICTORY_ROAD_3F = {
    [9] = { level = 42, species = "MACHOKE" },
    [10] = { level = 45, species = "MACHOKE" },
  },
  CERULEAN_CAVE_1F = {
    [7] = { level = 49, species = "KADABRA" },
  },
  CERULEAN_CAVE_2F = {
    [9] = { level = 55, species = "DITTO" },
  },
  CERULEAN_CAVE_B1F = {
    [8] = { level = 65, species = "DITTO" },
    [9] = { level = 63, species = "DITTO" },
  },
}

local CRITICAL_ACQUISITIONS = {
  { family = "Caterpie / Weedle", source = "Viridian Forest" },
  { family = "Oddish / Bellsprout", source = "Route 5" },
  { family = "Mankey / Meowth", source = "Route 5" },
  { family = "Ekans / Sandshrew", source = "Route 8" },
  { family = "Growlithe / Vulpix", source = "Route 8" },
  { family = "Scyther / Pinsir", source = "Safari Zone Center" },
  { family = "Electabuzz / Magmar", source = "Power Plant / Pokémon Mansion" },
  { family = "Hitmonlee / Hitmonchan", source = "Victory Road" },
  { family = "Renewable Eevee", source = "Route 7 after Hall of Fame (2%)" },
  { family = "Kadabra / Graveler / Haunter / Machoke",
    source = "Level evolution (42 / 42 / 42 / 45)" },
  { family = "Bulbasaur / Squirtle / Charmander",
    source = "Master Erika / Misty / Blaine" },
  { family = "Missing Dome / Helix Fossil", source = "Master Brock" },
  { family = "Mew", source = "Kanto Ascendant heritage event" },
}

local function copySlots(rows)
  local out = {}
  for i, row in ipairs(rows or {}) do
    out[i] = { level = row.level, species = row.species }
  end
  return out
end

local function contains(rows, value)
  for _, item in ipairs(rows or {}) do
    if item == value then return true end
  end
  return false
end

return function(mod, opts)
  opts = opts or {}
  local i18n = opts.i18n
  local legacyJourney = opts.legacyJourney or opts.journey
  local gameVersion = opts.gameVersion
  local enabled = opts.contentEnabled ~= false
  local K = { game = nil, enabled = enabled }

  local function tr(en, de)
    return i18n and i18n.text(en, de) or en
  end

  local function configuredMode()
    return mod.options:get("kanto_151") or "ascendant"
  end

  -- Encounter/content patches are applied while the mod is loading. Keep the
  -- loaded value separate from the live option so the status never claims an
  -- option change took effect before the required restart.
  local selected = configuredMode()
  K.mode = function() return selected end
  K.loadedMode = K.mode
  K.configuredMode = configuredMode
  K.restartRequired = function() return configuredMode() ~= selected end
  K.statusText = function()
    local names = {
      ascendant = tr("REWARDS", "BELOHNUNGEN"),
      wild = tr("WILD", "WILD"),
      off = tr("OFF", "AUS"),
    }
    local text = tr("KANTO 151 MODE", "KANTO-151-MODUS")
      .. ("\n%s: %s"):format(tr("LOADED", "GELADEN"),
        names[selected] or tostring(selected):upper())
    local configured = configuredMode()
    if configured ~= selected then
      text = text .. ("\f%s: %s\f%s"):format(
        tr("SELECTED", "GEWÄHLT"),
        names[configured] or tostring(configured):upper(),
        tr("RESTART REQUIRED", "NEUSTART ERFORDERLICH"))
    else
      text = text .. "\f" .. tr(
        "Option changes apply\nafter restarting.",
        "Optionsänderungen gelten\nnach einem Neustart.")
    end
    return text
  end
  K.criticalAcquisitions = CRITICAL_ACQUISITIONS
  K.tradeEvolutions = TRADE_EVOLUTIONS
  K.sharedEncounters = SHARED_ENCOUNTERS
  K.yellowEncounters = YELLOW_ENCOUNTERS
  K.wildEncounters = WILD_ENCOUNTERS
  K.rewardGuardEncounters = REWARD_GUARD_ENCOUNTERS
  K.postgameEevee = POSTGAME_EEVEE
  K.legacyEarlyStarters = LEGACY_EARLY_STARTERS

  local function patchEncounter(mapId, replacements)
    local current = mod.content.encounters:get(mapId)
    if not (current and current.grass and current.grass.slots) then
      mod.log:warn("KANTO 151 could not patch missing encounter table %s", mapId)
      return
    end
    local grass = {
      rate = current.grass.rate,
      slots = copySlots(current.grass.slots),
    }
    for index, row in pairs(replacements) do
      grass.slots[index] = { level = row.level, species = row.species }
    end
    mod.content.encounters:patch(mapId, { grass = grass })
  end

  if enabled and selected ~= "off" then
    mod.content.items:patch("MOON_STONE", { price = 2100 })

    for mapId, replacements in pairs(SHARED_ENCOUNTERS) do
      patchEncounter(mapId, replacements)
    end
    if gameVersion and type(gameVersion.get) == "function"
        and gameVersion.get() == "yellow" then
      for mapId, replacements in pairs(YELLOW_ENCOUNTERS) do
        patchEncounter(mapId, replacements)
      end
    end
    if selected == "wild" then
      for mapId, replacements in pairs(WILD_ENCOUNTERS) do
        patchEncounter(mapId, replacements)
      end
    else
      for mapId, replacements in pairs(REWARD_GUARD_ENCOUNTERS) do
        patchEncounter(mapId, replacements)
      end
    end

    for species, row in pairs(TRADE_EVOLUTIONS) do
      mod.content.pokemon:patch(species, {
        evolutions = {
          { method = "LEVEL", level = row.level, species = row.species },
        },
      })
    end

    for mapId, textId in pairs({
      PewterMart = "TEXT_PEWTERMART_CLERK",
      CeladonMart4F = "TEXT_CELADONMART4F_CLERK",
    }) do
      local pointers = mod.content.text_pointers:get(mapId) or {}
      local clerk = pointers[textId] or {}
      if not contains(clerk.mart, "MOON_STONE") then
        mod.content.text_pointers:patch(mapId, {
          [textId] = { mart = { __append = { "MOON_STONE" } } },
        })
      end
    end
  end

  local function hasHallOfFame(save)
    return save and ((save.hallOfFame and #save.hallOfFame > 0)
      or (save.flags and save.flags.EVENT_BEAT_CHAMPION_RIVAL)) or false
  end

  local function earlyStarterState(create)
    local s = mod.save:get("legacy_early_starters")
    if type(s) ~= "table" and create ~= false then
      s = { version = 1, pity = {} }
      mod.save:set("legacy_early_starters", s)
    end
    if type(s) == "table" then
      s.version = 1
      s.pity = type(s.pity) == "table" and s.pity or {}
    end
    return s
  end

  local function activeLegacy(save)
    return legacyJourney and type(legacyJourney.isActive) == "function"
      and legacyJourney.isActive(save) == true
  end

  function K.rollLegacyEarlyStarter(out, ctx, game)
    game = game or K.game
    if not (out and ctx and game and enabled and activeLegacy(game.save)) then
      return out
    end
    if out.kaProtected or out.kaEncounterSource
        or ctx.kaProtected or ctx.kaEncounterSource then
      return out
    end
    local row = LEGACY_EARLY_STARTERS[ctx.mapId]
    if not row or ctx.terrain ~= row.terrain
        or type(ctx.rng) ~= "function" then return out end

    local s = earlyStarterState(true)
    local count = math.max(0,
      math.floor(tonumber(s.pity[ctx.mapId]) or 0)) + 1
    local rolled = ctx.rng(1, 100) <= row.chance
    if rolled or count >= row.pity then
      s.pity[ctx.mapId] = 0
      return { species = row.species, level = row.level }
    end
    s.pity[ctx.mapId] = count
    return out
  end

  -- Run after the transactional Johto habitat proposal but before the
  -- existing Route-7 Eevee wrapper. Higher-priority roamers and authored
  -- events remain free to replace the ordinary result afterwards.
  mod.hooks:wrap("encounter.roll", function(nextRoll, encDef, ctx)
    local out = nextRoll(encDef, ctx)
    return K.rollLegacyEarlyStarter(out, ctx, K.game)
  end, -15)

  -- Route 7 is close to Eevee's original Celadon gift and provides the
  -- renewable copies required for all five Kanto/Johto branches. This is
  -- two percent of actual grass encounters, and only after the first League
  -- clear. The low priority lets a roaming legendary keep its encounter.
  mod.hooks:wrap("encounter.roll", function(nextRoll, encDef, ctx)
    local out = nextRoll(encDef, ctx)
    if not (out and enabled and selected ~= "off" and K.game
        and hasHallOfFame(K.game.save) and ctx
        and ctx.terrain == "grass" and ctx.mapId == POSTGAME_EEVEE.map) then
      return out
    end
    if ctx.rng(1, 100) <= POSTGAME_EEVEE.chance then
      return { species = "EEVEE", level = POSTGAME_EEVEE.level }
    end
    return out
  end, -10)

  local function state(create)
    local s = mod.save:get("kanto_completion")
    if type(s) ~= "table" and create ~= false then
      s = {
        version = 1, starters = {}, fossils = {},
        pendingMons = {}, pendingItems = {},
      }
      mod.save:set("kanto_completion", s)
    end
    if type(s) == "table" then
      s.version = 1
      for _, key in ipairs({ "starters", "fossils", "pendingMons", "pendingItems" }) do
        s[key] = type(s[key]) == "table" and s[key] or {}
      end
    end
    return s
  end

  local function persist(s)
    if s then mod.save:set("kanto_completion", s) end
  end

  K.state = state

  local function owns(save, species)
    return save and save.pokedex and save.pokedex.owned
      and save.pokedex.owned[species] and true or false
  end

  local function markOwned(game, species)
    game.save.pokedex = game.save.pokedex or { seen = {}, owned = {} }
    game.save.pokedex.seen = game.save.pokedex.seen or {}
    game.save.pokedex.owned = game.save.pokedex.owned or {}
    game.save.pokedex.seen[species] = true
    game.save.pokedex.owned[species] = true
  end

  local function storeMon(game, row)
    local Pokemon = require("src.pokemon.Pokemon")
    local mon = Pokemon.new(game.data, row.species, row.level or 5)
    require("src.battle.BattleState").stampOT(game.save, mon)
    mon.kantoAscendantGift = {
      source = row.source or "KANTO 151",
      receivedAt = os.time(),
    }
    if require("src.pokemon.Party").add(game.save.party, mon) then
      markOwned(game, row.species)
      return "party"
    end
    local box = require("src.pokemon.Boxes").deposit(game.save, mon)
    if box then
      markOwned(game, row.species)
      return "box", box
    end
    return nil
  end

  local function playerName(game)
    return game.save.player and game.save.player.name or "PLAYER"
  end

  local function monMessage(game, row, destination, box)
    local def = game.data.pokemon[row.species]
    local name = def and def.name or row.species
    if destination == "box" then
      return tr(
        ("%s received\n%s!\fIt was sent to\nBOX %d."):format(
          playerName(game), name, box or 1),
        ("%s erhält\n%s!\fEs wurde in BOX %d\ngesendet."):format(
          playerName(game), name, box or 1))
    end
    if destination == "pending" then
      return tr(
        ("%s is reserved.\fFree PARTY or BOX\nspace to claim it."):format(name),
        ("%s ist reserviert.\fSchaffe Platz in\nTEAM oder BOX."):format(name))
    end
    return tr(
      ("%s received\n%s!"):format(playerName(game), name),
      ("%s erhält\n%s!"):format(playerName(game), name))
  end

  local function giveOrReserveMon(game, row)
    local destination, box = storeMon(game, row)
    if destination then return monMessage(game, row, destination, box) end
    local s = state()
    s.pendingMons[#s.pendingMons + 1] = {
      species = row.species, level = row.level or 5, source = row.source,
    }
    persist(s)
    return monMessage(game, row, "pending")
  end

  local function itemMessage(game, itemId, pending)
    local def = game.data.items[itemId]
    local name = def and def.name or itemId
    if pending then
      return tr(
        ("%s is reserved.\fMake room in the\nBAG to claim it."):format(name),
        ("%s ist reserviert.\fSchaffe Platz im\nBEUTEL."):format(name))
    end
    return tr(
      ("BROCK awarded the\n%s!\fIt was put in\nthe BAG."):format(name),
      ("ROCKO überreicht\ndas %s!\fIm BEUTEL\nverstaut."):format(name))
  end

  local function giveOrReserveItem(game, itemId)
    game.save.inventory = game.save.inventory or {}
    if require("src.inventory.Bag").add(
        game.save, itemId, 1, game.data) then
      return itemMessage(game, itemId, false)
    end
    local s = state()
    s.pendingItems[#s.pendingItems + 1] = itemId
    persist(s)
    return itemMessage(game, itemId, true)
  end

  local function fossilAccounted(save, row, s)
    if s.fossils[row.item] then return true end
    if save.inventory and (save.inventory[row.item] or 0) > 0 then return true end
    if save.flags and save.flags[row.flag] then return true end
    for _, species in ipairs(row.species) do
      if owns(save, species) then return true end
    end
    return false
  end

  local function pendingHas(rows, key, value)
    for _, row in ipairs(rows or {}) do
      if type(row) == "table" and row[key] == value then return true end
      if key == "item" and row == value then return true end
    end
    return false
  end

  function K.claimPending(game, announce)
    if not game then return nil end
    local s = state(false)
    if not s then return nil end
    local messages = {}
    for i = #s.pendingMons, 1, -1 do
      local row = s.pendingMons[i]
      local destination, box = storeMon(game, row)
      if destination then
        table.remove(s.pendingMons, i)
        if announce then
          table.insert(messages, 1, monMessage(game, row, destination, box))
        end
      end
    end
    for i = #s.pendingItems, 1, -1 do
      local itemId = s.pendingItems[i]
      if require("src.inventory.Bag").add(
          game.save, itemId, 1, game.data) then
        table.remove(s.pendingItems, i)
        if announce then
          table.insert(messages, 1, itemMessage(game, itemId, false))
        end
      end
    end
    persist(s)
    return #messages > 0 and table.concat(messages, "\f") or nil
  end

  function K.afterBossWin(game, gymKey, tier)
    if not enabled or selected ~= "ascendant" or not game then return nil end
    local messages = {}
    local pending = K.claimPending(game, true)
    if pending then messages[#messages + 1] = pending end
    local s = state()

    local starter = STARTER_REWARDS[gymKey]
    if starter and (tier == "master" or tier == "crown")
        and not s.starters[starter.species] then
      if owns(game.save, starter.species) then
        s.starters[starter.species] = "already_owned"
      elseif not pendingHas(s.pendingMons, "species", starter.species) then
        s.starters[starter.species] = tier
        local row = {
          species = starter.species, level = starter.level,
          source = ("MASTER %s"):format(gymKey:upper()),
        }
        messages[#messages + 1] = tr(
          "Your mastery deserves\na rare Kanto partner.",
          "Deine Meisterschaft\nverdient einen\nseltenen Kanto-\nPartner.")
        messages[#messages + 1] = giveOrReserveMon(game, row)
      end
    end

    if gymKey == "brock" and (tier == "master" or tier == "crown") then
      local missing
      for _, row in ipairs(FOSSILS) do
        if not fossilAccounted(game.save, row, s)
            and not pendingHas(s.pendingItems, "item", row.item) then
          missing = row
          break
        end
      end
      if missing then
        s.fossils[missing.item] = tier
        messages[#messages + 1] = giveOrReserveItem(game, missing.item)
      end
    end

    persist(s)
    return #messages > 0 and table.concat(messages, "\f") or nil
  end

  function K.install(game)
    K.game = game
  end

  mod.events:on("map.entered", function(ev)
    local game = ev and ev.game or K.game
    if not (enabled and game and selected == "ascendant") then return end
    local text = K.claimPending(game, true)
    if text and game.stack then
      local TextBox = require("src.render.TextBox")
      game.stack:push(TextBox.new(game, text))
    end
  end)

  mod.events:on("save.loaded", function()
    state(true)
  end)

  if enabled and selected ~= "off" then
    mod.log:info("KANTO 151 %s mode: version and trade locks removed",
      selected:upper())
  end

  return K
end
