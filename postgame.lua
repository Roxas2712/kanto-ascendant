-- Post-game controller:
--   Hall of Fame -> eight Master Leaders -> Apex Elite Four
--   -> legendary hunt -> level-100 Crown Circuit.

local ELITE_CLASSES = {
  OPP_LORELEI = true, OPP_BRUNO = true, OPP_AGATHA = true,
  OPP_LANCE = true, OPP_RIVAL3 = true,
}
local ELITE_FOUR = { "OPP_LORELEI", "OPP_BRUNO", "OPP_AGATHA", "OPP_LANCE" }
local STATIC_LEGEND_OPTIONS = {
  ARTICUNO = "legend_articuno", ZAPDOS = "legend_zapdos",
  MOLTRES = "legend_moltres", MEWTWO = "legend_mewtwo",
}
local ADDED_LEGEND_OPTIONS = {
  RAIKOU = "legend_raikou", ENTEI = "legend_entei",
  SUICUNE = "legend_suicune", LUGIA = "legend_lugia",
  HO_OH = "legend_ho_oh", CELEBI = "legend_celebi",
}
local GYM_CROWN_LEGENDS = {
  misty = "SUICUNE", surge = "RAIKOU", erika = "CELEBI",
  sabrina = "LUGIA", blaine = "ENTEI",
}
local ELITE_CROWN_LEGENDS = {
  OPP_LORELEI = { "SUICUNE" },
  OPP_LANCE = { "LUGIA", "HO_OH" },
  OPP_RIVAL3 = {
    "MEWTWO", "RAIKOU", "ENTEI", "SUICUNE", "LUGIA", "HO_OH",
  },
}
local LEGEND_ALTERNATES = {
  MEWTWO = {
    species = "ALAKAZAM",
    moves = { "PSYCHIC_M", "RECOVER", "REFLECT", "THUNDER_WAVE" },
  },
  RAIKOU = {
    species = "JOLTEON",
    moves = { "THUNDER", "BODY_SLAM", "REFLECT", "THUNDER_WAVE" },
  },
  ENTEI = {
    species = "ARCANINE",
    moves = { "FIRE_BLAST", "BODY_SLAM", "REFLECT", "AGILITY" },
  },
  SUICUNE = {
    species = "LAPRAS",
    moves = { "HYDRO_PUMP", "BLIZZARD", "REST", "BODY_SLAM" },
  },
  LUGIA = {
    species = "DRAGONITE",
    moves = { "HYPER_BEAM", "BLIZZARD", "THUNDER_WAVE", "AGILITY" },
  },
  HO_OH = {
    species = "MOLTRES",
    moves = { "FIRE_BLAST", "SKY_ATTACK", "REFLECT", "AGILITY" },
  },
  CELEBI = {
    species = "EXEGGUTOR",
    moves = { "PSYCHIC_M", "MEGA_DRAIN", "SLEEP_POWDER", "EXPLOSION" },
  },
}

local function randomInt(lo, hi)
  if love and love.math and love.math.random then return love.math.random(lo, hi) end
  return math.random(lo, hi)
end

local function hasHallOfFame(save)
  return save and ((save.hallOfFame and #save.hallOfFame > 0)
    or (save.flags and save.flags.EVENT_BEAT_CHAMPION_RIVAL)) or false
end

local function owns(save, species)
  return save and save.pokedex and save.pokedex.owned
    and save.pokedex.owned[species] and true or false
end

local function allKeys(bucket, rows, keyField)
  bucket = type(bucket) == "table" and bucket or {}
  for _, row in ipairs(rows) do
    if not bucket[row[keyField]] then return false end
  end
  return true
end

return function(mod, data, opts)
  opts = opts or {}
  local i18n = opts.i18n
  local function tr(english, german)
    return i18n and i18n.text(english, german) or english
  end
  local function localized(row)
    if type(row) ~= "table" then return row end
    return tr(row.en, row.de)
  end
  local legendSetting
  local function gymDialogue(gym, tier, key)
    local root = data.dialogue and data.dialogue.gyms
      and data.dialogue.gyms[gym.key]
    local row = tier and root and root[tier] or root
    local legend = tier == "crown" and GYM_CROWN_LEGENDS[gym.key]
    if key == "intro" and legend and legendSetting
        and legendSetting(legend) == "off" and row and row.introNoLegend then
      key = "introNoLegend"
    end
    return row and localized(row[key]) or nil
  end
  local function gymRestDialogue(gym, tier, steps)
    local root = data.dialogue and data.dialogue.gyms
      and data.dialogue.gyms[gym.key]
    local row = root and root[tier] and root[tier].rest
    if not row then return nil end
    steps = math.max(1, math.floor(tonumber(steps) or 1))
    if steps == 1 then return localized(row.one) end
    local many = localized(row.many)
    return many and many:format(steps) or nil
  end
  local function eliteDialogue(class, tier, key)
    local root = data.dialogue and data.dialogue.elite
      and data.dialogue.elite[class]
    local row = root and root[tier]
    if tier == "crown" and key == "before" and row
        and row.beforeNoLegend and legendSetting then
      for _, species in ipairs(ELITE_CROWN_LEGENDS[class] or {}) do
        if legendSetting(species) == "off" then
          key = "beforeNoLegend"
          break
        end
      end
    end
    return row and localized(row[key]) or nil
  end
  local oakStoryBase = setmetatable({}, { __mode = "k" })
  local function anyLegendEnabled()
    for _, species in ipairs(data.legendOrder or {}) do
      if not legendSetting or legendSetting(species) ~= "off" then return true end
    end
    return false
  end
  local function applyStoryOakDialogue(mapId, game)
    if mapId ~= "CHAMPIONS_ROOM"
        or not (game and game.data and game.data.text) then return false end
    local label = "_ChampionsRoomOakComeWithMeText"
    local textData = game.data.text
    if oakStoryBase[textData] == nil then
      oakStoryBase[textData] = textData[label] or false
    end
    local base = oakStoryBase[textData]
    if base then textData[label] = base end
    if hasHallOfFame(game.save) then return false end
    local story = data.dialogue and data.dialogue.story
    local row = story and story[
      anyLegendEnabled() and "oakLegendEvent" or "oakNoLegendEvent"]
    local value = localized(row)
    if not value then return false end
    textData[label] = value
    return true
  end
  local controller = { game = nil, contentEnabled = opts.contentEnabled and true or false }
  local forcedTeam
  local pendingRoamer

  local function state(create)
    local s = mod.save:get("postgame")
    if type(s) ~= "table" and create ~= false then
      s = {
        masterWins = {}, crownWins = {}, eliteApexWins = {},
        eliteCrownWins = {}, catches = {}, roamers = {}, bossRest = {},
      }
      mod.save:set("postgame", s)
    end
    if type(s) == "table" then
      s.masterWins = type(s.masterWins) == "table" and s.masterWins or {}
      s.crownWins = type(s.crownWins) == "table" and s.crownWins or {}
      s.eliteApexWins = type(s.eliteApexWins) == "table" and s.eliteApexWins or {}
      s.eliteCrownWins = type(s.eliteCrownWins) == "table" and s.eliteCrownWins or {}
      s.catches = type(s.catches) == "table" and s.catches or {}
      s.roamers = type(s.roamers) == "table" and s.roamers or {}
      s.bossRest = type(s.bossRest) == "table" and s.bossRest or {}
    end
    return s
  end

  local function persist(s)
    if s then mod.save:set("postgame", s) end
  end

  local function allMaster(s)
    return allKeys(s and s.masterWins, data.gyms, "key")
  end

  local function allCrown(s)
    return allKeys(s and s.crownWins, data.gyms, "key")
  end

  local function caught(s, save, species)
    return (s and s.catches and s.catches[species]) or owns(save, species) or false
  end

  legendSetting = function(species)
    local staticKey = STATIC_LEGEND_OPTIONS[species]
    if staticKey then
      local value = mod.options:get(staticKey)
      if value == "vanilla" or value == "off" then return value end
      return "apex"
    end
    local addedKey = ADDED_LEGEND_OPTIONS[species]
    if addedKey and mod.options:get(addedKey) == false then return "off" end
    return "apex"
  end

  local function requiredCaught(s, save, list)
    for _, species in ipairs(list) do
      if legendSetting(species) ~= "off"
          and not caught(s, save, species) then return false end
    end
    return true
  end

  local function birdsCaught(s, save)
    return requiredCaught(s, save, { "ARTICUNO", "ZAPDOS", "MOLTRES" })
  end

  local function beastsCaught(s, save)
    return requiredCaught(s, save, { "RAIKOU", "ENTEI", "SUICUNE" })
  end

  local function crownUnlocked(s, save)
    return s and s.apexChampion
      and requiredCaught(s, save, { "LUGIA", "HO_OH" })
  end

  local function legendaryAvailable(species, s, save)
    local setting = legendSetting(species)
    if setting == "off" then return false end
    if setting == "vanilla" then return true end
    if not (s and s.apexChampion) then return false end
    if data.staticLegends[species] or data.roamers[species] then return true end
    if species == "LUGIA" then return birdsCaught(s, save) end
    if species == "HO_OH" then return beastsCaught(s, save) end
    if species == "CELEBI" then return crownUnlocked(s, save) end
    return false
  end

  local function enabledTeam(team)
    if type(team) ~= "table" then return team end
    local out
    for i, slot in ipairs(team) do
      local replacement = LEGEND_ALTERNATES[slot.species]
      if replacement and legendSetting(slot.species) == "off" then
        if not out then
          out = {}
          for j = 1, i - 1 do out[j] = team[j] end
        end
        out[i] = {
          species = replacement.species,
          level = slot.level,
          moves = replacement.moves,
        }
      elseif out then
        out[i] = slot
      end
    end
    return out or team
  end

  local function phaseFor(s, save)
    if not hasHallOfFame(save) then return "story" end
    if not allMaster(s) then return "master_gyms" end
    if not s.apexChampion then return "apex_elite" end
    if not crownUnlocked(s, save) then return "legend_hunt" end
    if not allCrown(s) then return "crown_gyms" end
    if not s.crownChampion then return "crown_elite" end
    return "complete"
  end

  local function eliteTier(s, save)
    if not (hasHallOfFame(save) and allMaster(s)) then return nil end
    if crownUnlocked(s, save) and allCrown(s) then return "crown" end
    return "apex"
  end
  local events = opts.makeEvents and opts.makeEvents(data, {
    tr = tr,
    localized = localized,
    legendSetting = legendSetting,
    legendaryAvailable = legendaryAvailable,
    caught = caught,
    phaseFor = phaseFor,
  })

  -- The first clear adds Oak's one-time legendary-sighting story bridge.
  -- Once a circuit is active, replace the current Elite/Champion room's text
  -- immediately before its map script runs.  This preserves all original
  -- door, flag and Hall-of-Fame choreography while adding the new voices.
  local function applyEliteDialogue(mapId, game, progression)
    if not (game and game.data and game.data.text) then return false end
    local storyOakApplied = applyStoryOakDialogue(mapId, game)
    local tier = eliteTier(progression or state(), game.save)
    if not tier then return storyOakApplied end
    for class, root in pairs(data.dialogue and data.dialogue.elite or {}) do
      if root.map == mapId then
        for key, label in pairs(root.labels or {}) do
          local value = eliteDialogue(class, tier, key)
          if value then game.data.text[label] = value end
        end
        return true
      end
    end
    return false
  end

  local function syncOwned(save)
    local s = state()
    for _, species in ipairs(data.legendOrder) do
      if owns(save, species) then s.catches[species] = true end
    end
    persist(s)
    return s
  end

  local function routePool(game)
    local routes = {}
    for _, mapId in ipairs(data.roamerRoutes) do
      local enc = game and game.data and game.data.encounters
        and game.data.encounters[mapId]
      if enc and enc.grass then routes[#routes + 1] = mapId end
    end
    return routes
  end

  local function relocateRoamer(species, game, avoid)
    local s = state()
    local routes = routePool(game or controller.game)
    if #routes == 0 then return nil end
    local candidates = {}
    for _, mapId in ipairs(routes) do
      if mapId ~= avoid then candidates[#candidates + 1] = mapId end
    end
    if #candidates == 0 then candidates = routes end
    local route = candidates[randomInt(1, #candidates)]
    s.roamers[species] = route
    persist(s)
    return route
  end

  local function initRoamers(game)
    local s = state()
    if not s.apexChampion then return end
    for species in pairs(data.roamers) do
      if legendaryAvailable(species, s, game.save)
          and not caught(s, game.save, species) and not s.roamers[species] then
        relocateRoamer(species, game)
      end
    end
  end

  local function setObjectToggle(save, mapId, name, visible)
    save.objectToggles = save.objectToggles or {}
    save.objectToggles[mapId] = save.objectToggles[mapId] or {}
    local old = save.objectToggles[mapId][name]
    save.objectToggles[mapId][name] = visible and true or false
    return old ~= (visible and true or false)
  end

  -- Recover legends that old vanilla scripts hid after a KO or flee.  In
  -- this expansion only a successful capture is permanent.
  local function syncPersistentObjects(game, activeMap)
    if not game or not game.save then return end
    local s = syncOwned(game.save)
    local reloadObject
    for species, def in pairs(data.staticLegends) do
      local setting = legendSetting(species)
      local visible
      if setting == "off" then
        visible = false
      elseif setting == "vanilla" then
        visible = not owns(game.save, species)
          and not (game.save.flags and game.save.flags[def.flag])
      else
        visible = not caught(s, game.save, species)
      end
      if setObjectToggle(game.save, def.map, def.object, visible)
          and activeMap == def.map then
        reloadObject = {
          map = def.map, object = def.object, visible = visible,
        }
      end
      if setting == "apex" and game.save.flags then
        game.save.flags[def.flag] = not visible
      end
    end
    if hasHallOfFame(game.save) then
      local changed = setObjectToggle(game.save, "VIRIDIAN_GYM",
        "VIRIDIANGYM_GIOVANNI", true)
      if changed and activeMap == "VIRIDIAN_GYM" then
        reloadObject = {
          map = "VIRIDIAN_GYM", object = "VIRIDIANGYM_GIOVANNI",
          visible = true,
        }
      end
    end
    if reloadObject and mod.world then
      -- The event fires before map scripts but after object instantiation.
      -- One seamless reload applies the repaired toggle; the second entry
      -- sees no change and therefore cannot recurse.
      mod.world:toggleObject(reloadObject.map, reloadObject.object,
        reloadObject.visible)
    end
  end

  local function removeLiveNpc(ow, npc)
    if not (ow and npc) then return end
    for _, list in ipairs({ ow.npcs or {}, ow.entities or {} }) do
      for i = #list, 1, -1 do
        if list[i] == npc then table.remove(list, i) end
      end
    end
    if ow.npcPool then ow.npcPool[npc.id] = nil end
  end

  local function markCaught(species, save)
    local s = state()
    s.catches[species] = true
    s.roamers[species] = nil
    persist(s)
    if save and save.pokedex and save.pokedex.owned then
      save.pokedex.owned[species] = true
    end
  end

  local function findSpawnCell(ow, preferred)
    local function free(x, y)
      return ow.map:inBounds(x, y) and ow.map:isWalkableCell(x, y)
        and not ow.map:warpAtCell(x, y) and not ow:npcAtCell(x, y)
        and not (ow.player.cellX == x and ow.player.cellY == y)
    end
    for _, cell in ipairs(preferred or {}) do
      if free(cell[1], cell[2]) then return cell[1], cell[2] end
    end
    for y = 0, ow.map.heightCells - 1 do
      for x = 0, ow.map.widthCells - 1 do
        if free(x, y) then return x, y end
      end
    end
  end

  local function findRoamerCell(ow)
    local cells = {}
    for y = 0, ow.map.heightCells - 1 do
      for x = 0, ow.map.widthCells - 1 do
        if ow.map:isGrassCell(x, y) and ow.map:isWalkableCell(x, y)
            and not ow.map:warpAtCell(x, y) and not ow:npcAtCell(x, y)
            and not (ow.player.cellX == x and ow.player.cellY == y) then
          cells[#cells + 1] = { x, y }
        end
      end
    end
    if #cells == 0 then return findSpawnCell(ow) end
    local cell = cells[randomInt(1, #cells)]
    return cell[1], cell[2]
  end

  local function runtimeObjectIdsAt(game, mapId, name)
    local out = {}
    local map = game and game.data and game.data.maps and game.data.maps[mapId]
    for _, obj in ipairs(map and map.objects or {}) do
      if obj.runtime and obj.owner == mod.id and obj.name == name then
        out[#out + 1] = mapId .. "_obj_" .. tostring(obj.index)
      end
    end
    return out
  end

  local function runtimeObjectIds(game, def)
    return runtimeObjectIdsAt(game, def.map, def.name)
  end

  local function allRuntimeObjectIds(game, name)
    local out = {}
    for mapId in pairs(game and game.data and game.data.maps or {}) do
      for _, id in ipairs(runtimeObjectIdsAt(game, mapId, name)) do
        out[#out + 1] = { id = id, map = mapId }
      end
    end
    return out
  end

  local function removeRoamerObjects(game, species)
    local def = data.roamers[species]
    if not def then return end
    for _, live in ipairs(allRuntimeObjectIds(game, def.name)) do
      mod.world:removeNpc(live.id)
    end
  end

  local function ensureSpawnedLegend(game, mapId)
    local def
    local species
    for id, row in pairs(data.spawnedLegends) do
      if row.map == mapId then species, def = id, row break end
    end
    if not def then return end
    local s = syncOwned(game.save)
    local shouldExist = legendaryAvailable(species, s, game.save)
      and not caught(s, game.save, species)
    local ids = runtimeObjectIds(game, def)
    if not shouldExist then
      for _, id in ipairs(ids) do mod.world:removeNpc(id) end
      return
    end
    if #ids > 0 then return end
    local ow = mod.world:overworld()
    if not (ow and ow.map and ow.map.id == mapId) then return end
    local x, y = findSpawnCell(ow, def.preferred)
    if not x then
      mod.log:warn("no free spawn cell for %s on %s", species, mapId)
      return
    end
    mod.world:spawnNpc(mapId, {
      name = def.name, sprite = def.sprite, movement = "STAY", range = "DOWN",
      text = def.text, pokemon = species, level = def.level, x = x, y = y,
    })
  end

  local function ensureRoamerObjects(game, mapId)
    if not controller.contentEnabled then return end
    local ow = mod.world:overworld()
    if not (ow and ow.map and ow.map.id == mapId) then return end
    local s = syncOwned(game.save)
    for species, def in pairs(data.roamers) do
      local desiredMap = s.apexChampion
        and legendaryAvailable(species, s, game.save)
        and not caught(s, game.save, species) and s.roamers[species] or nil
      local currentId
      for _, live in ipairs(allRuntimeObjectIds(game, def.name)) do
        if live.map == desiredMap and not currentId then
          currentId = live.id
        else
          mod.world:removeNpc(live.id)
        end
      end
      if desiredMap == mapId and not currentId then
        local x, y = findRoamerCell(ow)
        if x then
          mod.world:spawnNpc(mapId, {
            name = def.name, sprite = def.sprite, movement = "STAY",
            range = "DOWN", text = def.text, pokemon = species,
            level = def.level, x = x, y = y,
          })
        else
          mod.log:warn("no free spawn cell for %s on %s", species, mapId)
        end
      end
    end
  end

  local function ensureHuntRival(game, mapId)
    local def = data.huntRival
    if not (events and def and controller.contentEnabled and game) then return end
    local ids = runtimeObjectIds(game, def)
    local shouldExist = events.huntRivalAvailable(state(), game.save)
    if not shouldExist then
      for _, id in ipairs(ids) do mod.world:removeNpc(id) end
      return
    end
    if #ids > 0 or mapId ~= def.map then return end
    local ow = mod.world:overworld()
    if not (ow and ow.map and ow.map.id == mapId) then return end
    local x, y = findSpawnCell(ow, def.preferred)
    if not x then
      mod.log:warn("no free spawn cell for the legendary-hunt Rival")
      return
    end
    mod.world:spawnNpc(mapId, {
      name = def.name, sprite = def.sprite, movement = "STAY", range = "DOWN",
      text = def.text, trainerClass = def.class, x = x, y = y,
    })
  end

  local function bossRestRemaining(key)
    local s = state()
    local ready = tonumber(s.bossRest[key]) or 0
    local clock = tonumber(mod.save:get("step_clock", 0)) or 0
    return math.max(0, math.floor(ready - clock))
  end

  local function scheduleBossRest(key)
    local lo = math.max(1, math.floor(tonumber(mod.options:get("rest_min")) or 128))
    local hi = math.max(1, math.floor(tonumber(mod.options:get("rest_max")) or 256))
    if lo > hi then lo, hi = hi, lo end
    local s = state()
    s.bossRest[key] = (tonumber(mod.save:get("step_clock", 0)) or 0)
      + randomInt(lo, hi)
    persist(s)
  end

  local function offerGymBattle(ow, npc, gym, tier)
    local game = controller.game
    local TextBox = require("src.render.TextBox")
    local BattleState = require("src.battle.BattleState")
    local Runtime = require("src.mods.Runtime")
    local key = tier .. ":" .. gym.key
    local left = bossRestRemaining(key)
    npc.frozen = true
    npc:facePlayer(ow.player)
    local done = function() npc.frozen = false end
    if left > 0 then
      local status = gymRestDialogue(gym, tier, left)
      if not status and i18n and i18n.isGerman() then
        status = ("Mein Team trainiert\nnoch.\nKomm in %d\n%s zurück."):format(
          left, left == 1 and "Schritt" or "Schritten")
      elseif not status then
        status = ("My team is still\ntraining.\nReturn in %d\nstep%s."):format(
          left, left == 1 and "" or "s")
      end
      game.stack:push(TextBox.new(game,
        status, done))
      return true
    end

    local challenge = gymDialogue(gym, tier, "intro")
    local prompt
    if i18n and i18n.isGerman() then
      prompt = tier == "crown"
        and "LEVEL 100 KRONEN-\nKampf. Annehmen?"
        or ("LEVEL %d-%d MEISTER-\nKampf. Annehmen?"):format(
          gym.master[1].level, gym.master[#gym.master].level)
    else
      local levelText = tier == "crown" and "LEVEL 100"
        or ("LEVEL %d-%d"):format(gym.master[1].level,
          gym.master[#gym.master].level)
      prompt = tier == "crown"
        and (levelText .. " CROWN\nbattle. Accept?")
        or (levelText .. " MASTER\nbattle. Accept?")
    end
    if challenge then prompt = challenge .. "\f" .. prompt end
    game.stack:push(TextBox.new(game, prompt, nil, {
      choice = function(yes)
        if not yes then
          game.stack:push(TextBox.new(game,
            gymDialogue(gym, tier, "decline")
              or tr("Train well.\nI will be here.",
                "Trainiere gut.\nIch warte hier."), done))
          return
        end
        Runtime.emit("world.trainer_engaged", {
          npc = npc, trainerClass = gym.class, partyIndex = 1,
        })
        forcedTeam = { class = gym.class, team = gym[tier], tier = tier }
        local battle = BattleState.newTrainer(game, gym.class, 1)
        forcedTeam = nil
        battle.rematch = true
        battle.postgameTier = tier
        battle.postgameGym = gym.key
        battle.endBattleText = gymDialogue(gym, tier, "win")
        battle.onFinish = function(result)
          scheduleBossRest(key)
          if result == "win" then
            local s = state()
            if tier == "master" then s.masterWins[gym.key] = true
            else s.crownWins[gym.key] = true end
            persist(s)
          end
          ow:afterBattle(result, battle)
          done()
        end
        ow:pushBattle(battle)
      end,
    }))
    return true
  end

  local function showNpcMessage(ow, npc, game, text)
    if not text then return false end
    npc.frozen = true
    npc:facePlayer(ow.player)
    game.stack:push(require("src.render.TextBox").new(game, text,
      function() npc.frozen = false end))
    return true
  end

  local function offerHuntRival(ow, npc, game)
    local def = data.huntRival
    if not (events and def and events.huntRivalAvailable(state(), game.save)) then
      return false
    end
    local TextBox = require("src.render.TextBox")
    npc.frozen = true
    npc:facePlayer(ow.player)
    local done = function() npc.frozen = false end
    game.stack:push(TextBox.new(game,
      events.huntRivalDialogue("before"), nil, {
        choice = function(yes)
          if not yes then
            game.stack:push(TextBox.new(game,
              events.huntRivalDialogue("decline"), done))
            return
          end
          require("src.mods.Runtime").emit("world.trainer_engaged", {
            npc = npc, trainerClass = def.class, partyIndex = 1,
          })
          forcedTeam = { class = def.class, team = def.team, tier = "hunt" }
          local battle = require("src.battle.BattleState")
            .newTrainer(game, def.class, 1)
          forcedTeam = nil
          battle.rematch = true
          battle.postgameHuntRival = true
          battle.endBattleText = events.huntRivalDialogue("win")
          battle.onFinish = function(result)
            if result == "win" then
              local s = state()
              s.huntRivalWon = true
              persist(s)
            end
            ow:afterBattle(result, battle)
            if result == "win" then
              game.stack:push(TextBox.new(game,
                events.huntRivalDialogue("after"), function()
                  removeLiveNpc(ow, npc)
                  done()
                end))
            else
              done()
            end
          end
          ow:pushBattle(battle)
        end,
      }))
    return true
  end

  function controller.handleTalk(ow, npc, game)
    controller.game = game or controller.game
    if not (npc and npc.def and hasHallOfFame(game.save)) then return false end
    local s = state()
    if events and ow.map.id == "OAKS_LAB"
        and npc.def.name == "OAKSLAB_SCIENTIST1" then
      return showNpcMessage(ow, npc, game, events.researchLog(s, game.save))
    end
    if data.huntRival and npc.def.name == data.huntRival.name then
      return offerHuntRival(ow, npc, game)
    end
    if events then
      local reaction = events.worldReaction(
        ow.map.id, npc.def.name, s, game.save)
      if reaction then return showNpcMessage(ow, npc, game, reaction) end
    end
    local gym
    for _, candidate in ipairs(data.gyms) do
      if npc.def.trainerClass == candidate.class and ow.map.id == candidate.map then
        gym = candidate
        break
      end
    end
    if not gym then return false end
    if not allMaster(s) then
      return offerGymBattle(ow, npc, gym, "master")
    end
    if not crownUnlocked(s, game.save) then
      npc.frozen = true
      npc:facePlayer(ow.player)
      local text
      if not s.apexChampion then
        text = gymDialogue(gym, nil, "apexGate")
          or tr("All eight crests!\nThe APEX ELITE\nawaits at INDIGO.",
            "Alle acht Wappen!\nDie APEX-LIGA\nwartet am INDIGO.")
      else
        text = gymDialogue(gym, nil, "legendGate")
          or tr("The legends have\nawakened. Find\nLUGIA and HO-OH.",
            "Die Legenden sind\nerwacht. Finde\nLUGIA und HO-OH.")
      end
      game.stack:push(require("src.render.TextBox").new(game, text,
        function() npc.frozen = false end))
      return true
    end
    return offerGymBattle(ow, npc, gym, "crown")
  end

  local function showLegendTalk(game, ow, npc, done, species, level)
    local s = state()
    local setting = legendSetting(species)
    local static = data.staticLegends[species]
    if setting == "off" then
      game.stack:push(require("src.render.TextBox").new(game,
        tr("This legend is\ndisabled in the\nmod options.",
          "Diese Legende ist\nin den Mod-Optionen\nausgeschaltet."), done))
      return
    end
    if static and setting == "vanilla" then
      level = static.vanillaLevel or level
    end
    if caught(s, game.save, species) then
      game.stack:push(require("src.render.TextBox").new(game,
        tr("Only a quiet trace\nof power remains.",
          "Nur eine stille\nSpur ihrer Kraft\nist geblieben."), done))
      return
    end
    if not legendaryAvailable(species, s, game.save) then
      local text
      if not allMaster(s) then
        text = tr("A strange seal\nholds its power.\fWin all eight\nMASTER crests.",
          "Ein seltsames Siegel\nhält seine Kraft.\fErringe alle acht\nMEISTER-Wappen.")
      elseif not s.apexChampion then
        text = tr("A strange seal\nholds its power.\fDefeat the\nAPEX ELITE.",
          "Ein seltsames Siegel\nhält seine Kraft.\fBesiege die\nAPEX-LIGA.")
      else
        text = tr("Its power is near,\nbut another legend\nmust answer first.",
          "Seine Kraft ist nah,\ndoch zuerst muss\neine andere Legende\nantworten.")
      end
      game.stack:push(require("src.render.TextBox").new(game, text, done))
      return
    end

    local TextBox = require("src.render.TextBox")
    local function startBattle()
      local battle = require("src.battle.BattleState").newWild(game, species, level)
      battle.postgameLegend = species
      if data.roamers[species] then battle.postgameRoamer = species end
      battle.onFinish = function(result)
        if result == "caught" then
          markCaught(species, game.save)
          if static then
            setObjectToggle(game.save, static.map, static.object, false)
            if game.save.flags then game.save.flags[static.flag] = true end
            removeLiveNpc(ow, npc)
          elseif npc and npc.def and npc.def.runtime then
            mod.world:removeNpc(npc.id)
          end
        elseif data.roamers[species] and npc and npc.def
            and npc.def.runtime then
          -- The battle-ended event has moved this beast to another route.
          -- Remove its old visible body; it will be re-created on entry.
          mod.world:removeNpc(npc.id)
        elseif static and setting == "vanilla" and result == "win" then
          -- Vanilla static encounters disappear after a knockout as well
          -- as a capture. APEX mode deliberately persists until caught.
          setObjectToggle(game.save, static.map, static.object, false)
          if game.save.flags then game.save.flags[static.flag] = true end
          removeLiveNpc(ow, npc)
        end
        ow:afterBattle(result, battle)
        done()
      end
      ow:pushBattle(battle)
    end
    local function showChallenge()
      game.stack:push(TextBox.new(game,
        tr(("%s's power\nfills the air!"):format(data.species[species]
            and data.species[species].name or species),
          ("Die Kraft von %s\nerfüllt die Luft!"):format(data.species[species]
            and data.species[species].name or species)), startBattle))
    end
    local intro = events and events.legendIntro(species)
    if not intro then
      showChallenge()
      return
    end
    game.stack:push(TextBox.new(game, intro, function()
      pcall(require("src.core.Sound").playCry, game.data, species)
      local ok, Transition = pcall(require, "src.render.Transition")
      if ok and Transition and game.stack then
        game.stack:push(Transition.whiteFlash(game, 10, showChallenge))
      else
        showChallenge()
      end
    end))
  end

  local ARCHIVE_TEXT = "MOD_KANTO_ASCENDANT_CROWN_ARCHIVE"
  local function showTrophyArchive(game, done)
    local text = events and events.trophyText(
      state(), game.save, mod.save:get("trainers")) or
      tr("The archive is\nnot available.",
        "Das Archiv ist\nnicht verfügbar.")
    game.stack:push(require("src.render.TextBox").new(game, text, done))
  end

  local function ensureTrophySign(game, mapId)
    if mapId ~= "HALL_OF_FAME" or not game then return end
    local ow = mod.world:overworld()
    if not (ow and ow.map and ow.map.id == mapId) then return end
    local signs = ow.map.def.signs or {}
    ow.map.def.signs = signs
    local archive
    for _, sign in ipairs(signs) do
      if sign.x == 5 and sign.y == 1 then
        sign.text = ARCHIVE_TEXT
        archive = sign
        break
      end
    end
    if not archive then
      archive = { x = 5, y = 1, text = ARCHIVE_TEXT }
      signs[#signs + 1] = archive
    end
    ow.map.signAt = ow.map.signAt or {}
    ow.map.signAt[archive.y * ow.map.widthCells + archive.x] = archive
  end

  local function registerLegendTalks()
    if not controller.contentEnabled then return end
    -- The base Hall-of-Fame onEnter script normally adds two identical PC
    -- signs. Seed both here so it keeps the left return-home terminal while
    -- the right terminal remains the Crown Archive.
    mod.content.maps:patch("HALL_OF_FAME", {
      signs = {
        { x = 4, y = 1, text = "TEXT_HALLOFFAME_PC" },
        { x = 5, y = 1, text = ARCHIVE_TEXT },
      },
    })
    mod.content.map_scripts:register("HALL_OF_FAME", {
      priority = 1100,
      talk = {
        [ARCHIVE_TEXT] = function(game, _, _, done)
          showTrophyArchive(game, done)
        end,
      },
    })
    if data.huntRival then
      mod.content.map_scripts:register(data.huntRival.map, {
        priority = 1100,
        talk = {
          [data.huntRival.text] = function(game, ow, npc)
            offerHuntRival(ow, npc, game)
          end,
        },
      })
    end
    for species, def in pairs(data.staticLegends) do
      local id, row = species, def
      mod.content.map_scripts:register(row.map, {
        priority = 1000,
        talk = {
          [row.text] = function(game, ow, npc, done)
            showLegendTalk(game, ow, npc, done, id, row.level)
          end,
        },
      })
    end
    for species, def in pairs(data.spawnedLegends) do
      local id, row = species, def
      mod.content.map_scripts:register(row.map, {
        priority = 1000,
        talk = {
          [row.text] = function(game, ow, npc, done)
            showLegendTalk(game, ow, npc, done, id, row.level)
          end,
        },
      })
    end
    for _, mapId in ipairs(data.roamerRoutes) do
      local talk = {}
      for species, def in pairs(data.roamers) do
        local id, row = species, def
        talk[row.text] = function(game, ow, npc, done)
          showLegendTalk(game, ow, npc, done, id, row.level)
        end
      end
      mod.content.map_scripts:register(mapId, {
        priority = 1000,
        talk = talk,
      })
    end
  end

  registerLegendTalks()

  mod.hooks:wrap("trainer.party", function(nextParty, oppClass, partyIndex, party)
    if forcedTeam and forcedTeam.class == oppClass then
      return enabledTeam(forcedTeam.team)
    end
    if not ELITE_CLASSES[oppClass] or not controller.game then
      return nextParty(oppClass, partyIndex, party)
    end
    local s = state()
    local tier = eliteTier(s, controller.game.save)
    if tier == "crown" then return enabledTeam(data.crown[oppClass]) end
    if tier == "apex" then return enabledTeam(data.apex[oppClass]) end
    return nextParty(oppClass, partyIndex, party)
  end)

  mod.hooks:wrap("encounter.roll", function(nextRoll, encDef, ctx)
    if not (controller.contentEnabled and controller.game and ctx.terrain == "grass") then
      return nextRoll(encDef, ctx)
    end
    local s = state()
    if s.apexChampion then
      for species, roamer in pairs(data.roamers) do
        if legendaryAvailable(species, s, controller.game.save)
            and not caught(s, controller.game.save, species)
            and s.roamers[species] == ctx.mapId
            and ctx.rng(1, 32) == 1 then
          pendingRoamer = species
          return { species = species, level = roamer.level }
        end
      end
    end
    return nextRoll(encDef, ctx)
  end)

  mod.events:on("battle.started", function(ev)
    local battle = ev and ev.battle
    if not battle then return end
    if pendingRoamer and battle.kind == "wild"
        and battle.enemy and battle.enemy.mon.species == pendingRoamer then
      battle.postgameRoamer = pendingRoamer
      pendingRoamer = nil
    end
    if battle.kind == "trainer" and ELITE_CLASSES[battle.oppClass]
        and controller.game then
      local tier = eliteTier(state(), controller.game.save)
      if tier then
        battle.postgameTier = tier
        battle.rematch = true
        battle.endBattleText =
          eliteDialogue(battle.oppClass, tier, "win")
            or battle.endBattleText
      end
    end
  end)

  mod.events:on("battle.ended", function(ev)
    local battle = ev and ev.battle
    if not battle then return end
    if battle.postgameRoamer and ev.result ~= "caught" then
      relocateRoamer(battle.postgameRoamer, controller.game,
        controller.game and controller.game.overworld
          and controller.game.overworld.map.id)
      removeRoamerObjects(controller.game, battle.postgameRoamer)
    end
    if ev.result ~= "win" or not battle.postgameTier
        or not ELITE_CLASSES[battle.oppClass] then return end
    local s = state()
    local wins = battle.postgameTier == "crown"
      and s.eliteCrownWins or s.eliteApexWins
    wins[battle.oppClass] = true
    local fourWon = true
    for _, class in ipairs(ELITE_FOUR) do
      if not wins[class] then fourWon = false break end
    end
    if battle.oppClass == "OPP_RIVAL3" and fourWon then
      if battle.postgameTier == "crown" then s.crownChampion = true
      else s.apexChampion = true end
    end
    persist(s)
    if s.apexChampion then
      initRoamers(controller.game)
      syncPersistentObjects(controller.game)
    end
  end)

  mod.events:on("pokemon.caught", function(ev)
    if not (ev and ev.species) then return end
    for _, species in ipairs(data.legendOrder) do
      if species == ev.species then
        markCaught(species, ev.game and ev.game.save)
        removeRoamerObjects(controller.game or (ev.game and ev.game), species)
        return
      end
    end
  end)

  mod.events:on("map.entered", function(ev)
    if not controller.game then return end
    applyEliteDialogue(ev.mapId, controller.game)
    syncPersistentObjects(controller.game, ev.mapId)
    initRoamers(controller.game)
    ensureTrophySign(controller.game, ev.mapId)
    ensureHuntRival(controller.game, ev.mapId)
    -- Roamers are not pinned forever: changing maps gives each uncaught
    -- beast a one-in-four chance to move somewhere else.
    local s = state()
    if s.apexChampion then
      for species in pairs(data.roamers) do
        if legendaryAvailable(species, s, controller.game.save)
            and not caught(s, controller.game.save, species)
            and randomInt(1, 4) == 1 then
          relocateRoamer(species, controller.game, ev.mapId)
        end
      end
    end
    ensureSpawnedLegend(controller.game, ev.mapId)
    ensureRoamerObjects(controller.game, ev.mapId)
  end)

  mod.events:on("save.loaded", function(ev)
    if ev and ev.save then
      syncOwned(ev.save)
      if controller.game then
        syncPersistentObjects(controller.game)
        initRoamers(controller.game)
        local ow = mod.world:overworld()
        local mapId = ow and ow.map and ow.map.id
        ensureTrophySign(controller.game, mapId)
        ensureHuntRival(controller.game, mapId)
      end
    end
  end)

  mod.events:on("mod.options_changed", function(ev)
    if not (ev and ev.mod == mod.id and controller.game) then return end
    local ow = mod.world:overworld()
    local mapId = ow and ow.map and ow.map.id
    if mapId then applyEliteDialogue(mapId, controller.game) end
    syncPersistentObjects(controller.game, mapId)
    initRoamers(controller.game)
    ensureTrophySign(controller.game, mapId)
    ensureHuntRival(controller.game, mapId)
    if mapId then
      ensureSpawnedLegend(controller.game, mapId)
      ensureRoamerObjects(controller.game, mapId)
    end
  end)

  mod.events:on("game.ready", function(ev)
    controller.game = ev.game
    local ow = mod.world:overworld()
    local mapId = ow and ow.map and ow.map.id
    if mapId then applyEliteDialogue(mapId, ev.game) end
    syncPersistentObjects(ev.game)
    initRoamers(ev.game)
    ensureTrophySign(ev.game, mapId)
    ensureHuntRival(ev.game, mapId)
  end)

  controller.state = state
  controller.hasHallOfFame = hasHallOfFame
  controller.allMaster = allMaster
  controller.allCrown = allCrown
  controller.caught = caught
  controller.legendSetting = legendSetting
  controller.legendaryAvailable = legendaryAvailable
  controller.enabledTeam = enabledTeam
  controller.phaseFor = phaseFor
  controller.eliteTier = eliteTier
  controller.gymDialogue = gymDialogue
  controller.gymRestDialogue = gymRestDialogue
  controller.eliteDialogue = eliteDialogue
  controller.applyStoryOakDialogue = applyStoryOakDialogue
  controller.applyEliteDialogue = applyEliteDialogue
  controller.events = events
  controller.ensureTrophySign = ensureTrophySign
  controller.ensureHuntRival = ensureHuntRival
  controller.crownUnlocked = crownUnlocked
  controller.birdsCaught = birdsCaught
  controller.beastsCaught = beastsCaught
  return controller
end
