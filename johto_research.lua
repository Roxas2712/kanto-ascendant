-- Elm's Kanto research programme: three starter trials, deterministic
-- no-duplicate rematch specimens, step-hatched baby eggs and a laboratory
-- for the five Generation-II evolution items.

return function(mod, opts)
  opts = opts or {}
  local data = assert(opts.data, "Johto research data missing")
  local postgame = assert(opts.postgame, "postgame controller missing")
  local i18n = opts.i18n
  local daycare = opts.daycare
  local enabled = opts.contentEnabled ~= false
  local R = { game = nil, enabled = enabled }
  local activeTrial
  local researchItems = {}
  for _, row in ipairs(data.items or {}) do researchItems[row.id] = true end

  local function tr(en, de)
    return i18n and i18n.text(en, de) or en
  end

  local function localized(row)
    if type(row) ~= "table" then return row end
    return tr(row.en, row.de)
  end

  local function state(create)
    local s = mod.save:get("johto_research")
    if type(s) ~= "table" and create ~= false then
      s = {
        version = 2, starters = {}, rewards = {}, trackWins = {},
        eggsQueued = {}, eggsHatched = {}, itemsClaimed = {},
        eggQueue = {}, pendingMons = {}, pendingItems = {},
      }
      mod.save:set("johto_research", s)
    end
    if type(s) == "table" then
      -- v2 derives permanent habitat access from existing v1 progression
      -- flags.  No player has to repeat a trial or research reward, and no
      -- extra species is marked seen merely by loading an old save.
      s.version = 2
      for _, key in ipairs({
        "starters", "rewards", "trackWins", "eggsQueued", "eggsHatched",
        "itemsClaimed", "partnersClaimed", "eggQueue", "pendingMons",
        "pendingItems",
      }) do
        s[key] = type(s[key]) == "table" and s[key] or {}
      end
    end
    return s
  end

  local function persist(s)
    if s then mod.save:set("johto_research", s) end
  end

  local function allStarters(s)
    s = s or state()
    for _, key in ipairs(data.starterOrder) do
      if not s.starters[key] then return false end
    end
    return true
  end

  local function rewardCount(s)
    local count = 0
    for _, row in ipairs(data.rewards) do
      if s.rewards[row.species] then count = count + 1 end
    end
    return count
  end

  local rewardSpecies, starterForSpecies, eggSpecies = {}, {}, {}
  for _, row in ipairs(data.rewards or {}) do rewardSpecies[row.species] = true end
  for key, row in pairs(data.starters or {}) do
    starterForSpecies[row.species] = key
  end
  for _, row in ipairs(data.eggs or {}) do eggSpecies[row.species] = true end

  local function baseResearched(base, s)
    s = s or state()
    local habitat = data.habitats and data.habitats[base]
    if habitat and habitat.unlock == "starter" then
      return s.starters[habitat.key] == true
    end
    if habitat and habitat.unlock == "final" then
      return s.finalReward == true
    end
    local starter = starterForSpecies[base]
    if starter then return s.starters[starter] == true end
    if rewardSpecies[base] then return s.rewards[base] == true end
    if eggSpecies[base] then
      return s.eggsQueued[base] == true or s.eggsHatched[base] == true
    end
    if base == data.finalReward then return s.finalReward == true end
    return false
  end

  local function speciesResearched(species, s)
    s = s or state()
    local mappedBase = data.researchBase and data.researchBase[species]
    if mappedBase then
      -- Families owned by Elm's programme are unlocked only by their actual
      -- trial/reward/finale flag. Merely seeing Skarmory, Heracross, etc. on
      -- a boss team must not activate or advertise its wild habitat.
      return baseResearched(mappedBase, s)
    end
    -- Johto evolutions branching from Kanto families are researched when the
    -- player actually records them.  Reading this status never writes a Dex
    -- flag and therefore cannot reveal a silhouette ahead of discovery.
    local dex = R.game and R.game.save and R.game.save.pokedex
    return dex and ((dex.seen and dex.seen[species])
      or (dex.owned and dex.owned[species])) or false
  end

  local function itemUnlocked(itemId, s)
    s = s or state()
    local claimed = type(s.itemsClaimed) == "table" and s.itemsClaimed or {}
    for _, row in ipairs(data.itemMilestones or {}) do
      if row.item == itemId
          and claimed[tostring(row.at) .. ":" .. row.item] then
        return true
      end
    end
    return false
  end

  local function habitatCandidates(mapId, terrain, s)
    local out = {}
    s = s or state()
    for species, row in pairs(data.habitats or {}) do
      if row.map == mapId and row.terrain == terrain
          and baseResearched(species, s) then
        out[#out + 1] = {
          species = species, map = row.map, terrain = row.terrain,
          level = row.level, chance = row.chance or 2,
        }
      end
    end
    table.sort(out, function(a, b)
      return data.species[a.species].dex < data.species[b.species].dex
    end)
    return out
  end

  local function ownedJohto(game)
    local count = 0
    local owned = game.save.pokedex and game.save.pokedex.owned or {}
    for _, id in ipairs(data.order) do
      if owned[id] then count = count + 1 end
    end
    return count
  end

  local function playerName(game)
    return game.save.player and game.save.player.name or "PLAYER"
  end

  local function markOwned(game, species)
    local dex = game.save.pokedex
    if not dex then return end
    dex.seen[species] = true
    dex.owned[species] = true
  end

  local function makeMon(game, species, level, origin)
    local mon = require("src.pokemon.Pokemon").new(
      game.data, species, level or 5)
    require("src.battle.BattleState").stampOT(game.save, mon)
    mon.johtoBond = 60
    mon.johtoResearch = {
      origin = origin or "ELM'S KANTO RESEARCH",
      receivedAt = os.time(),
    }
    return mon
  end

  local function storeMon(game, species, level, origin)
    local mon = makeMon(game, species, level, origin)
    if require("src.pokemon.Party").add(game.save.party, mon) then
      markOwned(game, species)
      return "party"
    end
    local box = require("src.pokemon.Boxes").deposit(game.save, mon)
    if box then
      markOwned(game, species)
      return "box", box
    end
    return nil
  end

  local function giftMessage(game, species, destination, box)
    local name = game.data.pokemon[species].name
    if destination == "box" then
      return tr(
        ("%s received\n%s!\fIt was sent to\nBOX %d."):format(
          playerName(game), name, box or 1),
        ("%s erhält\n%s!\fEs wurde in BOX %d\ngesendet."):format(
          playerName(game), name, box or 1))
    elseif destination == "pending" then
      return tr(
        ("%s is reserved at\nELM'S RESEARCH.\fFree PARTY or BOX\nspace to claim it."):format(name),
        ("%s wartet bei\nLINDs FORSCHUNG.\fSchaffe Platz in\nTEAM oder BOX."):format(name))
    end
    return tr(
      ("%s received\n%s!"):format(playerName(game), name),
      ("%s erhält\n%s!"):format(playerName(game), name))
  end

  local function giveOrReserve(game, species, level, origin)
    local destination, box = storeMon(game, species, level, origin)
    if destination then return giftMessage(game, species, destination, box) end
    local s = state()
    s.pendingMons[#s.pendingMons + 1] = {
      species = species, level = level or 5, origin = origin,
    }
    persist(s)
    return giftMessage(game, species, "pending")
  end

  local function giveItem(game, itemId)
    game.save.inventory = game.save.inventory or {}
    local name = game.data.items[itemId] and game.data.items[itemId].name or itemId
    if require("src.inventory.Bag").add(game.save, itemId, 1, game.data) then
      return tr(
        ("Research reward:\n%s!\fIt was put in\nthe BAG."):format(name),
        ("Forschungsbonus:\n%s!\fIm BEUTEL\nverstaut."):format(name))
    end
    local s = state()
    s.pendingItems[#s.pendingItems + 1] = itemId
    persist(s)
    return tr(
      ("Research reward:\n%s!\fThe BAG is full;\nELM keeps it safe."):format(name),
      ("Forschungsbonus:\n%s!\fBEUTEL voll;\nLIND bewahrt es."):format(name))
  end

  local function startNextEgg(s)
    if s.activeEgg or #s.eggQueue == 0 then return end
    s.activeEgg = table.remove(s.eggQueue, 1)
  end

  local function queueMilestones(s, count)
    for _, egg in ipairs(data.eggs) do
      if count >= egg.at and not s.eggsQueued[egg.species] then
        s.eggsQueued[egg.species] = true
        s.eggQueue[#s.eggQueue + 1] = {
          species = egg.species, steps = egg.steps, remaining = egg.steps,
        }
      end
    end
    startNextEgg(s)
  end

  local function milestoneItems(game, s, count)
    local messages = {}
    for _, row in ipairs(data.itemMilestones) do
      local key = tostring(row.at) .. ":" .. row.item
      if count >= row.at and not s.itemsClaimed[key] then
        s.itemsClaimed[key] = true
        messages[#messages + 1] = giveItem(game, row.item)
      end
    end
    return messages
  end

  local function milestonePartners(game, s, count)
    local messages = {}
    for index, row in ipairs(data.partnerMilestones or {}) do
      if count >= row.at and not s.partnersClaimed[index] then
        s.partnersClaimed[index] = true
        messages[#messages + 1] = tr(
          ("ELM assigned a %s\nresearch partner."):format(
            game.data.pokemon[row.species].name),
          ("LIND teilt dir %s\nals Forschungspartner zu."):format(
            game.data.pokemon[row.species].name))
        messages[#messages + 1] = giveOrReserve(
          game, row.species, 25, "ELM EVOLUTION RESEARCH")
      end
    end
    return messages
  end

  local function nextReward(s, track)
    for _, row in ipairs(data.rewards) do
      if row.track == track and not s.rewards[row.species] then return row end
    end
    for _, row in ipairs(data.rewards) do
      if not s.rewards[row.species] then return row end
    end
  end

  function R.afterRematch(game, battle)
    if not (enabled and game and battle and battle.rematchTrainerClass
        and postgame.hasHallOfFame(game.save)) then return nil end
    local s = state()
    if not allStarters(s) then return nil end
    local track = data.classTracks[battle.rematchTrainerClass] or "nature"
    s.trackWins[track] = math.max(0,
      math.floor(tonumber(s.trackWins[track]) or 0)) + 1
    local row = nextReward(s, track)
    local messages = {}
    if row then
      s.rewards[row.species] = true
      messages[#messages + 1] = tr(
        ("ELM RESEARCH: %s's\ntraining revealed a\n%s specimen!"):format(
          battle.trainer and battle.trainer.name or "the trainer",
          game.data.pokemon[row.species].name),
        ("LIND-FORSCHUNG:\nDie Revanche enthüllt\n%s!"):format(
          game.data.pokemon[row.species].name))
      messages[#messages + 1] = giveOrReserve(
        game, row.species, 10, "THEMED TRAINER REMATCH")
    elseif not s.finalReward then
      s.finalReward = true
      messages[#messages + 1] = tr(
        "Every research track\nis complete!\fELM releases his\nfinal rare specimen.",
        "Alle Forschungsreihen\nsind vollständig!\fLIND gibt sein\nseltenstes Exemplar frei.")
      messages[#messages + 1] = giveOrReserve(
        game, data.finalReward, 15, "JOHTO RESEARCH FINALE")
    end
    local count = rewardCount(s)
    queueMilestones(s, count)
    for _, message in ipairs(milestoneItems(game, s, count)) do
      messages[#messages + 1] = message
    end
    for _, message in ipairs(milestonePartners(game, s, count)) do
      messages[#messages + 1] = message
    end
    for _, mon in ipairs(game.save.party or {}) do
      mon.johtoBond = math.min(255,
        math.max(0, tonumber(mon.johtoBond) or 0) + 10)
    end
    persist(s)
    return #messages > 0 and table.concat(messages, "\f") or nil
  end

  local function healParty(game)
    for _, mon in ipairs(game.save.party or {}) do
      require("src.pokemon.Pokemon").heal(mon)
    end
  end

  local function nameTrainer(battle, name)
    if battle and battle.trainer then
      battle.trainer = setmetatable({ name = name }, { __index = battle.trainer })
    end
  end

  local function startTrialRound(game, ow, npc, key, round)
    local trial = data.starters[key]
    local foe = trial.opponents[round]
    local battle = postgame.newForcedBattle(
      game, foe.class, foe.team, "johto_trial")
    battle.rematch = true
    battle.johtoTrial = key
    nameTrainer(battle, foe.name)
    battle.onFinish = function(result)
      ow:afterBattle(result, battle)
      if result ~= "win" then
        activeTrial = nil
        npc.frozen = false
        game.stack:push(require("src.render.TextBox").new(game, tr(
          "The trial ends here.\nReturn when ready.",
          "Die Prüfung endet hier.\nVersuche es erneut.")))
        return
      end
      if round < #trial.opponents then
        healParty(game)
        game.stack:push(require("src.render.TextBox").new(game, tr(
          ("ROUND %d WON!\nYour team was healed.\fNext examiner!"):format(round),
          ("RUNDE %d GEWONNEN!\nDein Team ist geheilt.\fNächste Prüfung!"):format(round)
        ), function()
          startTrialRound(game, ow, npc, key, round + 1)
        end))
        return
      end
      activeTrial = nil
      local s = state()
      s.starters[key] = true
      persist(s)
      local message = tr(
        ("%s CLEARED!\f"):format(localized(trial.title)),
        ("%s BESTANDEN!\f"):format(localized(trial.title)))
        .. giveOrReserve(game, trial.species, 5, localized(trial.title))
      npc.frozen = false
      game.stack:push(require("src.render.TextBox").new(game, message))
      R.refresh(game, trial.map)
    end
    ow:pushBattle(battle)
  end

  local function handleTrial(ow, npc, game, key)
    local trial = data.starters[key]
    local s = state()
    npc.frozen = true
    npc:facePlayer(ow.player)
    local done = function() npc.frozen = false end
    if s.starters[key] then
      game.stack:push(require("src.render.TextBox").new(game, tr(
        "This trial is already\nrecorded as complete.",
        "Diese Prüfung ist bereits\nals bestanden vermerkt."), done))
      return true
    end
    if activeTrial then
      game.stack:push(require("src.render.TextBox").new(game, tr(
        "Another starter trial\nis already active.",
        "Eine andere Starter-\nPrüfung läuft bereits."), done))
      return true
    end
    game.stack:push(require("src.render.TextBox").new(game,
      localized(trial.intro) .. "\f" .. tr("BEGIN THE TRIAL?", "PRÜFUNG STARTEN?"),
      nil, {
        choice = function(yes)
          if not yes then done() return end
          activeTrial = key
          healParty(game)
          startTrialRound(game, ow, npc, key, 1)
        end,
      }))
    return true
  end

  local function applicableItemEvolution(game)
    local inventory = game.save.inventory or {}
    for _, mon in ipairs(game.save.party or {}) do
      local def = game.data.pokemon[mon.species]
      for _, evo in ipairs(def and def.evolutions or {}) do
        if evo.method == "ITEM" and researchItems[evo.item]
            and inventory[evo.item] then
          return mon, evo
        end
      end
    end
  end

  local function deliverPending(game)
    local s = state()
    local pages = {}
    while #s.pendingItems > 0 do
      local item = s.pendingItems[1]
      if not require("src.inventory.Bag").add(
          game.save, item, 1, game.data) then break end
      table.remove(s.pendingItems, 1)
      pages[#pages + 1] = tr(
        ("ELM returned your\n%s."):format(game.data.items[item].name),
        ("LIND gibt dir\n%s."):format(game.data.items[item].name))
    end
    while #s.pendingMons > 0 do
      local row = s.pendingMons[1]
      local destination, box = storeMon(
        game, row.species, row.level, row.origin)
      if not destination then break end
      table.remove(s.pendingMons, 1)
      pages[#pages + 1] = giftMessage(
        game, row.species, destination, box)
    end
    persist(s)
    return #pages > 0 and table.concat(pages, "\f") or nil
  end

  local function handleAide(ow, npc, game)
    npc.frozen = true
    npc:facePlayer(ow.player)
    local done = function() npc.frozen = false end
    local delivered = deliverPending(game)
    if delivered then
      game.stack:push(require("src.render.TextBox").new(game, delivered, done))
      return true
    end
    local s = state()
    if not allStarters(s) then
      local missing = {}
      for _, key in ipairs(data.starterOrder) do
        if not s.starters[key] then
          missing[#missing + 1] = data.starters[key].species
        end
      end
      local text = tr(
        "PROF. ELM opened three\nKanto field trials.\f",
        "PROF. LIND eröffnete drei\nKanto-Prüfungen.\f")
        .. table.concat(missing, " / ")
        .. tr("\fVisit CERULEAN,\nCELADON and CINNABAR.",
              "\fBesuche AZURIA,\nPRISMANIA und ZINNOBER.")
      game.stack:push(require("src.render.TextBox").new(game, text, done))
      return true
    end
    local count = rewardCount(s)
    local egg = s.activeEgg
    if daycare then
      local species, remaining, location = daycare.researchEggStatus(game)
      if species then
        egg = { species = species, remaining = remaining, location = location }
      end
    end
    local eggText = egg and tr(
      egg.location == "reserved"
        and ("\fEGG: %s\nwaiting at ROUTE 5."):format(
          game.data.pokemon[egg.species].name)
        or ("\fEGG: %s\n%d steps remain."):format(
          game.data.pokemon[egg.species].name, egg.remaining),
      egg.location == "reserved"
        and ("\fEI: %s\nwartet auf ROUTE 5."):format(
          game.data.pokemon[egg.species].name)
        or ("\fEI: %s\nNoch %d Schritte."):format(
          game.data.pokemon[egg.species].name, egg.remaining)) or ""
    local final = s.finalReward and tr("\fALL TRACKS COMPLETE!",
      "\fALLE REIHEN KOMPLETT!") or ""
    game.stack:push(require("src.render.TextBox").new(game, tr(
      ("JOHTO RESEARCH\n%d/%d specimens.\fWin field rematches;\neach class reveals its\nown habitat.\fThe evolution machine\nis at ROUTE 5."):format(
        count, #data.rewards),
      ("JOHTO-FORSCHUNG\n%d/%d Exemplare.\fGewinne Revanchen;\njede Klasse erforscht\neinen Lebensraum.\fDie Entwicklungsmaschine\nsteht auf ROUTE 5."):format(
        count, #data.rewards)) .. eggText .. final, done))
    return true
  end

  function R.handleTalk(ow, npc, game)
    if not (enabled and ow and npc and npc.def
        and postgame.hasHallOfFame(game.save)) then return false end
    if npc.def.name == data.aide.name then return handleAide(ow, npc, game) end
    for key, trial in pairs(data.starters) do
      if npc.def.name == trial.name then return handleTrial(ow, npc, game, key) end
    end
    return false
  end

  local function runtimeObjectIds(game, mapId, name)
    local out = {}
    local map = game and game.data and game.data.maps
      and game.data.maps[mapId]
    for _, obj in ipairs(map and map.objects or {}) do
      if obj.runtime and obj.owner == mod.id and obj.name == name then
        out[#out + 1] = mapId .. "_obj_" .. tostring(obj.index)
      end
    end
    return out
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

  local function ensureNpc(game, def, should)
    local ids = runtimeObjectIds(game, def.map, def.name)
    if not should then
      for _, id in ipairs(ids) do mod.world:removeNpc(id) end
      return
    end
    if #ids > 0 then return end
    local ow = mod.world:overworld()
    if not (ow and ow.map and ow.map.id == def.map) then return end
    local x, y = findSpawnCell(ow, def.preferred)
    if not x then return end
    mod.world:spawnNpc(def.map, {
      name = def.name, sprite = def.sprite, movement = "STAY", range = "DOWN",
      text = def.textId, x = x, y = y,
    })
  end

  function R.refresh(game, mapId)
    if not (enabled and game) then return end
    local unlocked = postgame.hasHallOfFame(game.save)
    if not mapId or data.aide.map == mapId then
      ensureNpc(game, data.aide, unlocked)
    end
    local s = state()
    for _, key in ipairs(data.starterOrder) do
      local trial = data.starters[key]
      if not mapId or trial.map == mapId then
        ensureNpc(game, trial, unlocked and not s.starters[key])
      end
    end
  end

  local function stepEgg(game)
    local s = state(false)
    if not s then return end
    startNextEgg(s)
    local egg = s.activeEgg
    if not egg then return end
    if daycare then
      daycare.reserveEgg(
        egg.species, egg.steps, "ELM RESEARCH EGG", egg.species)
      s.activeEgg = nil
      persist(s)
      startNextEgg(s)
      persist(s)
      return
    end
    egg.remaining = math.max(0, math.floor(tonumber(egg.remaining)
      or egg.steps or 1) - 1)
    if egg.remaining > 0 then persist(s) return end
    local species = egg.species
    s.activeEgg = nil
    s.eggsHatched[species] = true
    persist(s)
    local message = tr(
      ("The research EGG is\nhatching!\f%s emerged!"):format(
        game.data.pokemon[species].name),
      ("Das Forschungs-EI\nschlüpft!\f%s ist da!"):format(
        game.data.pokemon[species].name))
      .. "\f" .. giveOrReserve(game, species, 5, "ELM RESEARCH EGG")
    game.stack:push(require("src.render.TextBox").new(game, message))
    startNextEgg(s)
    persist(s)
  end

  local function raiseBond(game)
    for _, mon in ipairs(game.save.party or {}) do
      mon.johtoBond = math.min(255,
        math.max(0, tonumber(mon.johtoBond) or 0) + 1)
    end
  end

  if mod.content and mod.content.screens then
    mod.content.screens:register("JohtoResearchDex", {
      new = function(game)
        local rows, totalSeen, totalOwned = {}, 0, 0
        local seen = game.save.pokedex and game.save.pokedex.seen or {}
        local owned = game.save.pokedex and game.save.pokedex.owned or {}
        for _, id in ipairs(data.order) do
          local recorded = seen[id] or owned[id]
          if recorded then totalSeen = totalSeen + 1 end
          if owned[id] then totalOwned = totalOwned + 1 end
          local def = game.data.pokemon[id]
          rows[#rows + 1] = {
            -- Match the original Pokédex: an unseen slot exposes only its
            -- number, while an owned species uses the Poké Ball marker
            -- supplied by ListMenu instead of a pre-filled "OWN/HAT" label.
            label = recorded and ("%03d %s"):format(def.dex, def.name)
              or ("%03d -----"):format(def.dex),
            ball = owned[id] or nil,
            value = recorded and id or nil,
          }
        end
        return mod.ui.ListMenu.new(game, tr("JOHTO POKéDEX", "JOHTO-POKéDEX"),
          rows, {
            footer = tr(
              ("SEEN %d  OWNED %d"):format(totalSeen, totalOwned),
              ("GESEHEN %d  GEF. %d"):format(totalSeen, totalOwned)),
            pageJump = true,
            onChoose = function(item)
              if not item.value then return end
              local def = game.data.pokemon[item.value]
              local status = owned[item.value] and tr("OWNED", "GEFANGEN")
                or (seen[item.value] and tr("SEEN", "GESEHEN")
                  or tr("NOT RECORDED", "NICHT ERFASST"))
              game.stack:push(require("src.render.TextBox").new(game,
                ("%03d %s\f%s\f%s"):format(
                  def.dex, def.name, table.concat(def.types, "/"), status)))
            end,
          })
      end,
    })
  end

  mod.hooks:wrap("ui.start_menu.items", function(nextItems, game, items)
    local out = nextItems(game, items)
    if type(out) ~= "table" or not enabled
        or not postgame.hasHallOfFame(game.save) then return out end
    return mod.ui.insertBefore(out, "SAVE", {
      label = tr("JOHTO", "JOHTO"),
      ascendantMenu = true,
      ascendantLabel = tr("JOHTO POKéDEX", "JOHTO-POKéDEX"),
      ascendantOrder = 30,
      onSelect = function() mod.ui.push(game, "JohtoResearchDex") end,
    })
  end, 260)

  -- Shared habitat selector for ordinary random encounters and companion
  -- mods that materialize those encounters directly in the overworld.
  function R.rollHabitat(mapId, terrain, rng, fallbackLevel, s)
    if not (enabled and R.game and mapId and terrain
        and postgame.hasHallOfFame(R.game.save)) then return nil end
    rng = type(rng) == "function" and rng or math.random
    local candidates = habitatCandidates(mapId, terrain, s or state(false))
    if #candidates == 0 then return nil end
    local chance = 0
    for _, row in ipairs(candidates) do
      chance = math.max(chance, math.max(0, math.min(100, row.chance or 2)))
    end
    if rng(1, 100) > chance then return nil end
    local row = candidates[rng(1, #candidates)]
    return { species = row.species, level = row.level or fallbackLevel }
  end

  -- Once Elm has recorded a base specimen, that family establishes a rare,
  -- permanent Kanto habitat.  The replacement happens after a native roll so
  -- encounter frequency, Repel and ordinary map behavior remain untouched.
  -- A low priority intentionally lets roaming legends, outbreaks and authored
  -- world events replace this result.
  mod.hooks:wrap("encounter.roll", function(nextRoll, encDef, ctx)
    local out = nextRoll(encDef, ctx)
    if not (out and ctx) then return out end
    return R.rollHabitat(
      ctx.mapId, ctx.terrain, ctx.rng, out.level, state(false)) or out
  end, -20)

  mod.events:on("world.stepped", function()
    if not (enabled and R.game and postgame.hasHallOfFame(R.game.save)) then return end
    stepEgg(R.game)
    local clock = math.max(0,
      math.floor(tonumber(mod.save:get("step_clock", 0)) or 0))
    if clock % 64 == 0 then raiseBond(R.game) end
  end)

  mod.events:on("map.entered", function(ev)
    local game = ev and ev.game or R.game
    local mapId = ev and (ev.mapId or ev.map and ev.map.id)
    if game then R.refresh(game, mapId) end
  end)

  mod.events:on("save.loaded", function()
    state()
  end)

  function R.install(game)
    R.game = game
    state()
    local ow = mod.world and mod.world:overworld()
    R.refresh(game, ow and ow.map and ow.map.id)
  end

  R.state = state
  R.enabled = enabled
  R.allStarters = allStarters
  R.starterTrialsComplete = function(s) return allStarters(s or state()) end
  R.rewardCount = rewardCount
  R.ownedJohto = ownedJohto
  R.finaleUnlocked = function(s)
    s = s or state()
    return s.finalReward == true
  end
  R.larvitarUnlocked = R.finaleUnlocked
  R.isSpeciesResearched = speciesResearched
  R.itemUnlocked = itemUnlocked
  R.habitatCandidates = habitatCandidates
  R.habitatFor = function(species)
    return data.habitats and data.habitats[species] or nil
  end
  return R
end
