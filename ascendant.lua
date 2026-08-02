-- Long-form Kanto Ascendant systems layered on top of postgame.lua:
-- ranks, research assignments, Leader missions, adaptive boss teams,
-- Grand Tournament, Rocket Resurgence, the Mew finale, achievements and
-- a save-safe New Game Plus cycle.

local LEGENDARY = {
  ARTICUNO = true, ZAPDOS = true, MOLTRES = true, MEWTWO = true, MEW = true,
  RAIKOU = true, ENTEI = true, SUICUNE = true,
  LUGIA = true, HO_OH = true, CELEBI = true,
}

local COUNTERS = {
  NORMAL = {
    species = "MACHAMP",
    moves = { "SUBMISSION", "EARTHQUAKE", "ROCK_SLIDE", "BODY_SLAM" },
  },
  FIRE = {
    species = "STARMIE",
    moves = { "SURF", "PSYCHIC_M", "THUNDERBOLT", "RECOVER" },
  },
  WATER = {
    species = "JOLTEON",
    moves = { "THUNDERBOLT", "PIN_MISSILE", "DOUBLE_KICK", "AGILITY" },
  },
  GRASS = {
    species = "NINETALES",
    moves = { "FIRE_BLAST", "CONFUSE_RAY", "BODY_SLAM", "REFLECT" },
  },
  BUG = {
    species = "NINETALES",
    moves = { "FIRE_BLAST", "CONFUSE_RAY", "BODY_SLAM", "REFLECT" },
  },
  ELECTRIC = {
    species = "RHYDON",
    moves = { "EARTHQUAKE", "ROCK_SLIDE", "THUNDER", "SUBMISSION" },
  },
  ICE = {
    species = "ARCANINE",
    moves = { "FIRE_BLAST", "BODY_SLAM", "DIG", "AGILITY" },
  },
  ROCK = {
    species = "STARMIE",
    moves = { "SURF", "PSYCHIC_M", "THUNDERBOLT", "RECOVER" },
  },
  FIGHTING = {
    species = "ALAKAZAM",
    moves = { "PSYCHIC_M", "RECOVER", "REFLECT", "THUNDER_WAVE" },
  },
  POISON = {
    species = "GENGAR",
    moves = { "PSYCHIC_M", "THUNDERBOLT", "HYPNOSIS", "EXPLOSION" },
  },
  GROUND = {
    species = "CLOYSTER",
    moves = { "BLIZZARD", "SURF", "CLAMP", "EXPLOSION" },
  },
  FLYING = {
    species = "JOLTEON",
    moves = { "THUNDERBOLT", "PIN_MISSILE", "DOUBLE_KICK", "AGILITY" },
  },
  GHOST = {
    species = "TAUROS",
    moves = { "BODY_SLAM", "HYPER_BEAM", "EARTHQUAKE", "BLIZZARD" },
  },
  PSYCHIC_TYPE = {
    species = "TAUROS",
    moves = { "BODY_SLAM", "HYPER_BEAM", "EARTHQUAKE", "BLIZZARD" },
  },
  PSYCHIC = {
    species = "TAUROS",
    moves = { "BODY_SLAM", "HYPER_BEAM", "EARTHQUAKE", "BLIZZARD" },
  },
  DRAGON = {
    species = "CLOYSTER",
    moves = { "BLIZZARD", "SURF", "CLAMP", "EXPLOSION" },
  },
}

local function countKeys(bucket)
  local count = 0
  for _, value in pairs(type(bucket) == "table" and bucket or {}) do
    if value then count = count + 1 end
  end
  return count
end

local function copyTeam(team)
  local out = {}
  for i, slot in ipairs(team or {}) do
    out[i] = {
      species = slot.species,
      level = slot.level,
      moves = slot.moves and {
        slot.moves[1], slot.moves[2], slot.moves[3], slot.moves[4],
      } or nil,
    }
  end
  return out
end

local function rotateTeam(team, amount)
  local out = {}
  local n = #team
  if n == 0 then return out end
  for i = 1, n do
    out[i] = team[((i + amount - 1) % n) + 1]
  end
  return out
end

local function reverseTeam(team)
  local out = {}
  for i = #team, 1, -1 do out[#out + 1] = team[i] end
  return out
end

return function(mod, baseData, opts)
  opts = opts or {}
  local data = opts.data
  local base = opts.postgame
  local i18n = opts.i18n
  local trainerStates = opts.trainerStates or function() return {} end
  local E = { game = nil }

  local function tr(en, de)
    return i18n and i18n.text(en, de) or en
  end

  local function localized(row)
    if type(row) ~= "table" then return row end
    return tr(row.en, row.de)
  end

  local function state(create)
    local s = mod.save:get("ascendant")
    if type(s) ~= "table" and create ~= false then
      s = {
        research = { completed = {} },
        gymQuests = {},
        achievements = {},
        metrics = {},
        bossBattles = {},
        tournament = { runs = 0, wins = 0, best = 0 },
        rocketStage = 0,
        mewStage = 0,
        cycle = 0,
      }
      mod.save:set("ascendant", s)
    end
    if type(s) == "table" then
      s.research = type(s.research) == "table" and s.research
        or { completed = {} }
      s.research.completed = type(s.research.completed) == "table"
        and s.research.completed or {}
      s.gymQuests = type(s.gymQuests) == "table" and s.gymQuests or {}
      s.achievements = type(s.achievements) == "table"
        and s.achievements or {}
      s.metrics = type(s.metrics) == "table" and s.metrics or {}
      s.bossBattles = type(s.bossBattles) == "table" and s.bossBattles or {}
      s.tournament = type(s.tournament) == "table" and s.tournament
        or { runs = 0, wins = 0, best = 0 }
      s.tournament.runs = math.max(0,
        math.floor(tonumber(s.tournament.runs) or 0))
      s.tournament.wins = math.max(0,
        math.floor(tonumber(s.tournament.wins) or 0))
      s.tournament.best = math.max(0,
        math.floor(tonumber(s.tournament.best) or 0))
      s.rocketStage = math.max(0, math.min(#data.rocket,
        math.floor(tonumber(s.rocketStage) or 0)))
      s.mewStage = math.max(0, math.min(4,
        math.floor(tonumber(s.mewStage) or 0)))
      s.cycle = math.max(0, math.floor(tonumber(s.cycle) or 0))
    end
    return s
  end

  local function persist(s)
    if s then mod.save:set("ascendant", s) end
  end

  local function rankFor(progress)
    progress = math.max(0, math.floor(tonumber(progress) or 0))
    local rank = data.ranks[1]
    for _, candidate in ipairs(data.ranks) do
      if progress >= candidate.threshold then rank = candidate end
    end
    return rank
  end

  local function rematchTotal()
    local count = 0
    for _, row in pairs(trainerStates()) do
      count = count + math.max(0, math.floor(tonumber(row.rematches) or 0))
    end
    return count
  end

  local function expertTrainerCount()
    local count = 0
    for _, row in pairs(trainerStates()) do
      local progress = math.max(0, math.floor(tonumber(row.rematches) or 0))
        + math.max(0, math.floor(tonumber(row.trainingCycles) or 0))
      if rankFor(progress).threshold >= 5 then count = count + 1 end
    end
    return count
  end

  local function enabledLegendCount()
    return base and base.events and base.events.enabledLegendCount() or 0
  end

  local function caughtLegendCount(game)
    return base and base.events
      and base.events.caughtLegendCount(base.state(), game and game.save) or 0
  end

  local function allEnabledLegendsCaught(game)
    local s = base and base.state()
    for _, species in ipairs(baseData.legendOrder or {}) do
      if base.legendSetting(species) ~= "off"
          and not base.caught(s, game and game.save, species) then
        return false
      end
    end
    return true
  end

  local function questDoneCount(s)
    local count = 0
    for key in pairs(data.gymQuests) do
      if s.gymQuests[key] and s.gymQuests[key].done then count = count + 1 end
    end
    return count
  end

  local function metricValue(metric, game, s)
    local p = base and base.state()
    if metric == "rematches" then return rematchTotal()
    elseif metric == "expertTrainers" then return expertTrainerCount()
    elseif metric == "masterWins" then return countKeys(p and p.masterWins)
    elseif metric == "legends" then return caughtLegendCount(game)
    elseif metric == "gymQuests" then return questDoneCount(s)
    elseif metric == "tournamentRounds" then
      return math.max(0, math.floor(tonumber(s.metrics.tournamentRounds) or 0))
    elseif metric == "rocketWins" then return s.rocketStage
    elseif metric == "crownChampion" then
      return p and p.crownChampion and 1 or 0
    end
    return 0
  end

  local function researchEnabled(row)
    if row.id == "rocket" and mod.options:get("rocket_story") == false then
      return false
    end
    if row.id == "tournament"
        and mod.options:get("grand_tournament") == false then return false end
    if row.id == "legend_signals" and enabledLegendCount() == 0 then
      return false
    end
    return true
  end

  local function activeResearch(s)
    for _, row in ipairs(data.research) do
      if researchEnabled(row) and not s.research.completed[row.id] then
        return row
      end
    end
    return nil
  end

  local function researchComplete(s)
    return activeResearch(s) == nil
  end

  local function researchCounts(s)
    local done, total = 0, 0
    for _, row in ipairs(data.research) do
      if researchEnabled(row) then
        total = total + 1
        if s.research.completed[row.id] then done = done + 1 end
      end
    end
    return done, total
  end

  local function itemName(game, item)
    return game and game.data and game.data.items and game.data.items[item]
      and game.data.items[item].name or item
  end

  local function addItem(game, item)
    game.save.inventory = game.save.inventory or {}
    return require("src.inventory.Bag").add(game.save, item, 1, game.data)
  end

  local function rewardText(game, item)
    return tr(
      ("%s received\n%s!"):format(game.save.player.name, itemName(game, item)),
      ("%s erhält\n%s!"):format(game.save.player.name, itemName(game, item)))
  end

  local function giveOrHold(game, s, item)
    if addItem(game, item) then return rewardText(game, item) end
    s.pendingReward = item
    persist(s)
    return tr(
      ("The BAG is full.\f%s is reserved\nfor you."):format(itemName(game, item)),
      ("Der BEUTEL ist voll.\f%s wird für\ndich aufbewahrt."):format(
        itemName(game, item)))
  end

  local function deliverPending(game, s)
    if not s.pendingReward then return nil end
    local item = s.pendingReward
    if not addItem(game, item) then
      return tr(
        ("The BAG is still full.\f%s remains\nreserved."):format(
          itemName(game, item)),
        ("Der BEUTEL ist noch\nvoll.\f%s bleibt\naufbewahrt."):format(
          itemName(game, item)))
    end
    s.pendingReward = nil
    persist(s)
    return rewardText(game, item)
  end

  local function unlock(id, s)
    if s.achievements[id] then return false end
    s.achievements[id] = true
    s.latestAchievement = id
    persist(s)
    return true
  end

  local function achievementTitle(id)
    for _, row in ipairs(data.achievements) do
      if row.id == id then return localized(row.title) end
    end
    return id
  end

  local function evaluateAchievements(game)
    local s = state()
    local p = base and base.state()
    local total = rematchTotal()
    if total >= 10 then unlock("rematch_10", s) end
    if total >= 50 then unlock("rematch_50", s) end
    if base and base.allMaster(p) then unlock("master_circuit", s) end
    if p and p.apexChampion then unlock("apex_champion", s) end
    if p and base.caught(p, game and game.save, "RAIKOU")
        and base.caught(p, game and game.save, "ENTEI")
        and base.caught(p, game and game.save, "SUICUNE") then
      unlock("beast_tracker", s)
    end
    if p and base.caught(p, game and game.save, "LUGIA")
        and base.caught(p, game and game.save, "HO_OH") then
      unlock("sky_pair", s)
    end
    if questDoneCount(s) >= 8 then unlock("leader_confidant", s) end
    if s.tournament.wins > 0 then unlock("tournament_champ", s) end
    if p and p.crownChampion then unlock("crown_champion", s) end
    if s.rocketStage >= #data.rocket then unlock("rocket_breaker", s) end
    if s.mewCaught then unlock("mew_found", s) end
    if s.achievements.crown_champion
        and (mod.options:get("rocket_story") == false
          or s.achievements.rocket_breaker)
        and (mod.options:get("legend_mew") == false
          or s.achievements.mew_found)
        and s.achievements.leader_confidant
        and (mod.options:get("grand_tournament") == false
          or s.achievements.tournament_champ) then
      unlock("ascendant", s)
    end
    persist(s)
    return s
  end

  local function showMessage(ow, npc, game, message, done)
    if npc then
      npc.frozen = true
      npc:facePlayer(ow.player)
    end
    game.stack:push(require("src.render.TextBox").new(game, message,
      done or function() if npc then npc.frozen = false end end))
    return true
  end

  local function researchStatus(game, s)
    local row = activeResearch(s)
    if not row then
      local _, total = researchCounts(s)
      return tr(
        ("ASCENDANT RESEARCH\nALL %d REPORTS FILED"):format(total),
        ("ASCENDANT-FORSCHUNG\nALLE %d BERICHTE FERTIG"):format(total))
    end
    local value = math.min(row.target, metricValue(row.metric, game, s))
    return tr("ACTIVE ASSIGNMENT", "AKTIVER AUFTRAG")
      .. "\n" .. localized(row.title)
      .. "\f" .. localized(row.task)
      .. ("\f%s: %d/%d\n%s: %s"):format(
        tr("PROGRESS", "FORTSCHRITT"), value, row.target,
        tr("REWARD", "BELOHNUNG"), itemName(game, row.reward))
  end

  local function handleResearch(ow, npc, game)
    local s = evaluateAchievements(game)
    local pending = deliverPending(game, s)
    if pending then return showMessage(ow, npc, game, pending) end
    local row = activeResearch(s)
    if row and metricValue(row.metric, game, s) >= row.target then
      s.research.completed[row.id] = true
      local reward = giveOrHold(game, s, row.reward)
      persist(s)
      local nextRow = activeResearch(s)
      local message = tr("RESEARCH COMPLETE!", "FORSCHUNG BEENDET!")
        .. "\n" .. localized(row.title) .. "\f" .. reward
      if nextRow then
        message = message .. "\f" .. researchStatus(game, s)
      else
        message = message .. "\f" .. tr(
          "Every report is\ncomplete.\fOne final origin\nremains unexplained.",
          "Alle Berichte sind\nfertig.\fEin letzter Ursprung\nbleibt ungeklärt.")
      end
      return showMessage(ow, npc, game, message)
    end
    local baseLog = base and base.events
      and base.events.researchLog(base.state(), game.save)
    local message = researchStatus(game, s)
    if baseLog then message = message .. "\f" .. baseLog end
    return showMessage(ow, npc, game, message)
  end

  local function gymForNpc(ow, npc)
    for _, gym in ipairs(baseData.gyms or {}) do
      if ow.map.id == gym.map and npc.def.trainerClass == gym.class then
        return gym
      end
    end
    return nil
  end

  local function handleGymQuest(ow, npc, game, gym)
    local p = base.state()
    if not (p.apexChampion and p.masterWins[gym.key]) then return false end
    local def = data.gymQuests[gym.key]
    if not def then return false end
    local s = state()
    local q = s.gymQuests[gym.key]
    if type(q) ~= "table" then
      q = { active = true, progress = 0, done = false }
      s.gymQuests[gym.key] = q
      persist(s)
      return showMessage(ow, npc, game, localized(def.intro)
        .. ("\f%s: 0/%d"):format(tr("PROGRESS", "FORTSCHRITT"), def.target))
    end
    if q.done then return false end
    if q.progress < def.target then
      return showMessage(ow, npc, game,
        localized(def.progress):format(q.progress)
          .. "\f" .. localized(def.intro))
    end
    q.done = true
    local reward = giveOrHold(game, s, def.reward)
    persist(s)
    evaluateAchievements(game)
    return showMessage(ow, npc, game,
      localized(def.complete) .. "\f" .. reward)
  end

  local function dominantPlayerType(game)
    local counts = {}
    for _, pokemon in ipairs(game and game.save and game.save.party or {}) do
      local def = game.data.pokemon[pokemon.species]
      for _, kind in ipairs(def and def.types or {}) do
        counts[kind] = (counts[kind] or 0) + 1
      end
    end
    local winner, best
    for kind, value in pairs(counts) do
      if not best or value > best or (value == best and kind < winner) then
        winner, best = kind, value
      end
    end
    return winner
  end

  local function selectBossTeam(team, context, game)
    local s = state()
    local key = (context.kind or "boss") .. ":" .. (context.key or "unknown")
      .. ":" .. (context.tier or "open")
    local fought = math.max(0, math.floor(tonumber(s.bossBattles[key]) or 0))
    local variant = (fought + s.cycle) % 3
    local out = copyTeam(team)
    if variant == 1 then out = rotateTeam(out, 1)
    elseif variant == 2 then out = reverseTeam(out) end

    local quest = context.kind == "gym" and s.gymQuests[context.key]
    local signature = data.signature[context.key]
    if quest and quest.done and signature and #out > 0 then
      local replacement = copyTeam({ signature })[1]
      replacement.level = context.tier == "crown" and 100
        or out[#out].level
      out[#out] = replacement
    end

    if context.kind == "elite" and context.key == "OPP_RIVAL3"
        and #out > 0 then
      local counter = COUNTERS[dominantPlayerType(game)]
      if counter then
        out[1] = {
          species = counter.species,
          level = context.tier == "crown" and 100 or out[1].level,
          moves = {
            counter.moves[1], counter.moves[2],
            counter.moves[3], counter.moves[4],
          },
        }
      end
    end
    return out
  end

  local function markBossBattle(context)
    local s = state()
    local key = (context.kind or "boss") .. ":" .. (context.key or "unknown")
      .. ":" .. (context.tier or "open")
    s.bossBattles[key] = math.max(0,
      math.floor(tonumber(s.bossBattles[key]) or 0)) + 1
    persist(s)
  end

  local function runtimeObjectIds(game, mapId, name)
    local out = {}
    local map = game and game.data and game.data.maps and game.data.maps[mapId]
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

  local function removeLiveNpc(ow, npc)
    if not (ow and npc) then return end
    for _, list in ipairs({ ow.npcs or {}, ow.entities or {} }) do
      for i = #list, 1, -1 do
        if list[i] == npc then table.remove(list, i) end
      end
    end
    if ow.npcPool then ow.npcPool[npc.id] = nil end
  end

  local function ensureRuntimeNpc(game, def, shouldExist)
    local ids = runtimeObjectIds(game, def.map, def.name)
    if not shouldExist then
      for _, id in ipairs(ids) do mod.world:removeNpc(id) end
      return
    end
    if #ids > 0 then return end
    local ow = mod.world:overworld()
    if not (ow and ow.map and ow.map.id == def.map) then return end
    local x, y = findSpawnCell(ow, def.preferred)
    if not x then
      mod.log:warn("no free spawn cell for %s on %s", def.name, def.map)
      return
    end
    mod.world:spawnNpc(def.map, {
      name = def.name, sprite = def.sprite, movement = "STAY", range = "DOWN",
      text = def.textId or def.text, trainerClass = def.class,
      pokemon = def.pokemon,
      level = def.level, x = x, y = y,
    })
  end

  local function rocketEnabled()
    return mod.options:get("rocket_story") ~= false
  end

  local function ensureRocketNpc(game, mapId)
    local s = state()
    local p = base.state()
    for index, def in ipairs(data.rocket) do
      if not def.existing then
        ensureRuntimeNpc(game, def, rocketEnabled() and p.apexChampion
          and s.rocketStage == index - 1 and mapId == def.map)
      end
    end
  end

  local function newForcedBattle(game, class, team, tier)
    return base.newForcedBattle(game, class, team, tier)
  end

  local function startRocketBattle(ow, npc, game, index, def)
    local TextBox = require("src.render.TextBox")
    npc.frozen = true
    npc:facePlayer(ow.player)
    local done = function() npc.frozen = false end
    game.stack:push(TextBox.new(game, localized(def.before), nil, {
      choice = function(yes)
        if not yes then
          game.stack:push(TextBox.new(game,
            tr("Rocket will be\nwaiting.", "Rocket wird warten."), done))
          return
        end
        local battle = newForcedBattle(game, def.class, def.team, "rocket")
        battle.rematch = true
        battle.ascendantRocket = index
        if state().cycle > 0
            and mod.options:get("ascendant_rules") ~= "normal" then
          battle.ascendantNoItems = true
        end
        battle.endBattleText = localized(def.win)
        battle.onFinish = function(result)
          if result == "win" then
            local s = state()
            s.rocketStage = math.max(s.rocketStage, index)
            persist(s)
          end
          ow:afterBattle(result, battle)
          if result == "win" then
            game.stack:push(TextBox.new(game, localized(def.after), function()
              if not def.existing then removeLiveNpc(ow, npc) end
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

  local function handleRocketTalk(ow, npc, game)
    if not rocketEnabled() then return false end
    local s = state()
    local p = base.state()
    if not p.apexChampion or s.rocketStage >= #data.rocket then return false end
    local index = s.rocketStage + 1
    local def = data.rocket[index]
    if def.existing then
      if ow.map.id == def.map and npc.def.name == def.existing then
        return startRocketBattle(ow, npc, game, index, def)
      end
    elseif npc.def.name == def.name then
      return startRocketBattle(ow, npc, game, index, def)
    end
    return false
  end

  local function tournamentEnabled()
    return mod.options:get("grand_tournament") ~= false
  end

  local function ensureTournamentHost(game, mapId)
    local def = data.tournament
    local p = base.state()
    ensureRuntimeNpc(game, def, tournamentEnabled() and p.crownChampion
      and mapId == def.map)
  end

  local tournamentLock
  local function restrictParty(game)
    tournamentLock = {}
    for i = 4, #(game.save.party or {}) do
      local mon = game.save.party[i]
      tournamentLock[#tournamentLock + 1] = {
        mon = mon, hp = mon.hp, status = mon.status,
      }
      mon.hp = 0
    end
  end

  local function restoreParty()
    for _, row in ipairs(tournamentLock or {}) do
      row.mon.hp, row.mon.status = row.hp, row.status
    end
    tournamentLock = nil
  end

  local function healParty(game, limit)
    local Pokemon = require("src.pokemon.Pokemon")
    for index, mon in ipairs(game.save.party or {}) do
      if not limit or index <= limit then Pokemon.heal(mon) end
    end
  end

  local function startTournament(ow, npc, game, rule)
    local TextBox = require("src.render.TextBox")
    local s = state()
    local runSeed = s.tournament.runs
    local round = 0
    local noFaints = true
    if rule.id == "trio" then restrictParty(game) end

    local function finishRun(won)
      restoreParty()
      local current = state()
      current.tournament.runs = current.tournament.runs + 1
      current.tournament.best = math.max(current.tournament.best, round)
      local message
      if won then
        current.tournament.wins = current.tournament.wins + 1
        local item = current.tournament.wins % 5 == 0
          and "MASTER_BALL" or "PP_UP"
        message = tr(
          "GRAND TOURNAMENT\nCHAMPION!\fKanto records your\nthree-round victory.",
          "GROSSES TURNIER\nGEWONNEN!\fKanto verzeichnet\ndeinen Dreifach-Sieg.")
          .. "\f" .. giveOrHold(game, current, item)
        if noFaints then unlock("untouchable", current) end
      else
        message = tr(
          ("Tournament run ended\nat round %d.\fThe bracket will\nchange next time."):format(
            math.max(1, round)),
          ("Turnierlauf endete in\nRunde %d.\fDer Plan ändert sich\nbeim nächsten Mal."):format(
            math.max(1, round)))
      end
      persist(current)
      evaluateAchievements(game)
      npc.frozen = false
      if won then game.stack:push(TextBox.new(game, message)) end
    end

    local function nextRound()
      round = round + 1
      local opponentCount = #data.tournament.opponents
      local start = (runSeed * 2) % opponentCount
      local step = runSeed % 2 == 0 and 1 or opponentCount - 1
      local opponent = data.tournament.opponents[
        ((start + (round - 1) * step) % opponentCount) + 1]
      local battle = newForcedBattle(game, opponent.class,
        opponent.team, "tournament")
      battle.rematch = true
      battle.ascendantTournament = true
      battle.ascendantTournamentRound = round
      battle.ascendantRule = rule.id
      battle.ascendantNoItems = rule.id == "no_items"
        or (state().cycle > 0
          and mod.options:get("ascendant_rules") ~= "normal")
      battle.trainer = setmetatable({ name = localized(opponent.name) },
        { __index = battle.trainer })
      battle.introText = tr(
        ("ROUND %d\n%s wants to fight!"):format(
          round, localized(opponent.name)),
        ("RUNDE %d\n%s fordert dich!"):format(
          round, localized(opponent.name)))
      battle.onFinish = function(result)
        if (battle.ascendantPlayerFaints or 0) > 0 then noFaints = false end
        if result == "win" then
          local current = state()
          current.metrics.tournamentRounds =
            math.max(0, tonumber(current.metrics.tournamentRounds) or 0) + 1
          persist(current)
        end
        if result ~= "win" then
          -- Restore temporarily locked party slots before the normal
          -- blackout handler heals the whole team.
          restoreParty()
          ow:afterBattle(result, battle)
          finishRun(false)
          return
        end
        ow:afterBattle(result, battle)
        if round >= 3 then
          finishRun(true)
          return
        end
        if rule.id ~= "endurance" then
          healParty(game, rule.id == "trio" and 3 or nil)
        end
        game.stack:push(TextBox.new(game, tr(
          ("Round %d cleared!\fPrepare for the next\nopponent."):format(round),
          ("Runde %d geschafft!\fBereite dich auf den\nnächsten Gegner vor."):format(
            round)), nextRound))
      end
      ow:pushBattle(battle)
    end
    nextRound()
  end

  local function handleTournament(ow, npc, game)
    local p = base.state()
    if not (tournamentEnabled() and p.crownChampion) then return false end
    local s = state()
    local rule = data.tournament.rules[
      (s.tournament.runs % #data.tournament.rules) + 1]
    npc.frozen = true
    npc:facePlayer(ow.player)
    local message = tr(
      "KANTO GRAND\nTOURNAMENT",
      "GROSSES KANTO-\nTURNIER")
      .. "\n" .. localized(rule.name)
      .. "\f" .. localized(rule.intro)
      .. "\f" .. tr("Enter the bracket?", "Am Turnier teilnehmen?")
    game.stack:push(require("src.render.TextBox").new(game, message, nil, {
      choice = function(yes)
        if yes then
          startTournament(ow, npc, game, rule)
        else
          npc.frozen = false
        end
      end,
    }))
    return true
  end

  local function mewEnabled()
    return mod.options:get("legend_mew") ~= false
  end

  local function mewEligible(game)
    local s = state()
    local p = base.state()
    return mewEnabled() and p.crownChampion and allEnabledLegendsCaught(game)
      and researchComplete(s)
      and (not rocketEnabled() or s.rocketStage >= #data.rocket)
  end

  local function clueForNpc(ow, npc)
    for key, clue in pairs(data.mew.clues) do
      if ow.map.id == clue.map and clue.names[npc.def.name] then
        return key, clue
      end
    end
  end

  local MEW_CLUE_STAGE = { oak = 0, fuji = 1, lab = 2 }
  local function handleMewClue(ow, npc, game)
    if not mewEligible(game) then return false end
    local key, clue = clueForNpc(ow, npc)
    if not clue then return false end
    local s = state()
    if s.mewCaught or s.mewStage ~= MEW_CLUE_STAGE[key] then return false end
    s.mewStage = s.mewStage + 1
    persist(s)
    local message = localized(clue.text)
    if s.mewStage == 3 then
      message = message .. "\f" .. tr(
        "A final signal now\nflickers on ROUTE 24.",
        "Ein letztes Signal\nflackert nun auf\nROUTE 24.")
    end
    return showMessage(ow, npc, game, message)
  end

  local function ensureMew(game, mapId)
    local def = data.mew
    local s = state()
    ensureRuntimeNpc(game, {
      map = def.map, name = def.name, textId = def.textId,
      sprite = def.sprite, pokemon = "MEW", level = def.level,
      preferred = def.preferred,
    }, mewEnabled() and s.mewStage >= 3 and not s.mewCaught
      and mapId == def.map)
  end

  local function startMewEncounter(game, ow, npc, done)
    local TextBox = require("src.render.TextBox")
    local function battle()
      local b = require("src.battle.BattleState").newWild(game, "MEW",
        data.mew.level)
      b.ascendantMew = true
      b.onFinish = function(result)
        if result == "caught" then
          local s = state()
          s.mewCaught, s.mewStage = true, 4
          persist(s)
          unlock("mew_found", s)
          if npc and npc.def and npc.def.runtime then mod.world:removeNpc(npc.id) end
        end
        ow:afterBattle(result, b)
        done()
      end
      ow:pushBattle(b)
    end
    game.stack:push(TextBox.new(game, localized(data.mew.intro), function()
      pcall(require("src.core.Sound").playCry, game.data, "MEW")
      local ok, Transition = pcall(require, "src.render.Transition")
      if ok and Transition then
        game.stack:push(Transition.whiteFlash(game, 10, battle))
      else
        battle()
      end
    end))
  end

  local function ensureNewGamePlus(game, mapId)
    local def = data.newGamePlus
    local s = state()
    local p = base.state()
    local ready = s.achievements.ascendant
    if ready and s.cycle > 0 then
      ready = p.crownChampion and researchComplete(s)
        and (not rocketEnabled() or s.rocketStage >= #data.rocket)
        and questDoneCount(s) >= 8
        and s.tournament.wins > math.max(0,
          tonumber(s.cycleTournamentStartWins) or 0)
    end
    ensureRuntimeNpc(game, def, ready and mapId == def.map)
  end

  local function beginNewGamePlus(game)
    local s = state()
    local permanentAchievements = s.achievements
    local permanentMew = s.mewCaught
    local records = {
      wins = s.tournament.wins,
      best = s.tournament.best,
    }
    local cycle = s.cycle + 1
    s = {
      research = { completed = {} },
      gymQuests = {},
      achievements = permanentAchievements,
      metrics = {},
      bossBattles = {},
      tournament = { runs = 0, wins = records.wins, best = records.best },
      rocketStage = 0,
      mewStage = permanentMew and 4 or 0,
      mewCaught = permanentMew,
      cycle = cycle,
      cycleTournamentStartWins = records.wins,
      latestAchievement = "ascendant",
    }
    mod.save:set("ascendant", s)

    local p = base.state()
    p.masterWins, p.crownWins = {}, {}
    p.eliteApexWins, p.eliteCrownWins = {}, {}
    p.apexChampion, p.crownChampion = nil, nil
    p.huntRivalWon, p.bossRest = nil, {}
    mod.save:set("postgame", p)

    for _, row in pairs(trainerStates()) do
      row.ascendantCycles = cycle
    end
    return cycle
  end

  local function handleNewGamePlus(ow, npc, game)
    local s = state()
    if not s.achievements.ascendant then return false end
    if s.cycle > 0 then
      local p = base.state()
      local ready = p.crownChampion and researchComplete(s)
        and (not rocketEnabled() or s.rocketStage >= #data.rocket)
        and questDoneCount(s) >= 8
        and s.tournament.wins > math.max(0,
          tonumber(s.cycleTournamentStartWins) or 0)
      if not ready then
        return showMessage(ow, npc, game, tr(
          "Complete this Ascendant\nCycle before beginning\nanother.",
          "Beende diesen\nAscendant-Zyklus, bevor\nein neuer beginnt."))
      end
    end
    local TextBox = require("src.render.TextBox")
    npc.frozen = true
    npc:facePlayer(ow.player)
    local first = tr(
      "ASCENDANT CYCLE\nNEW GAME PLUS\fReplay every mod\ncircuit with adaptive\nteams and stricter\nbattle rules?\fBase story progress,\nPOKéMON, items and\ncaptured legends stay.",
      "ASCENDANT-ZYKLUS\nNEW GAME PLUS\fAlle Mod-Prüfungen mit\nadaptiven Teams und\nstrengeren Regeln\nwiederholen?\fBasis-Story, POKéMON,\nItems und gefangene\nLegenden bleiben.")
    game.stack:push(TextBox.new(game, first, nil, {
      choice = function(yes)
        if not yes then npc.frozen = false return end
        game.stack:push(TextBox.new(game, tr(
          "Reset MASTER, APEX,\nCROWN, research and\nRocket progress now?\fThis cannot be undone\ninside this save.",
          "MEISTER-, APEX-,\nKRONEN-, Forschungs-\nund Rocket-Fortschritt\njetzt zurücksetzen?\fIm Spielstand nicht\nrückgängig machbar."), nil, {
          choice = function(confirm)
            if not confirm then npc.frozen = false return end
            local cycle = beginNewGamePlus(game)
            game.stack:push(TextBox.new(game, tr(
              ("ASCENDANT CYCLE %d\nhas begun.\fAll captured legends\nand permanent titles\nremain yours."):format(cycle),
              ("ASCENDANT-ZYKLUS %d\nhat begonnen.\fAlle gefangenen\nLegenden und Titel\nbleiben erhalten."):format(cycle)),
              function() npc.frozen = false end))
          end,
        }))
      end,
    }))
    return true
  end

  local function worldPhase(game)
    local s = state()
    local p = base.state()
    if s.mewCaught then return "complete" end
    if mewEligible(game) and s.mewStage > 0 then return "mew" end
    if rocketEnabled() and p.apexChampion and s.rocketStage < #data.rocket then
      return "rocket"
    end
    return nil
  end

  local function worldReaction(ow, npc, game)
    if not (ow and ow.map and npc and npc.def and npc.def.name) then return nil end
    local row = data.world[ow.map.id .. ":" .. npc.def.name]
    local phase = row and worldPhase(game)
    return row and phase and localized(row[phase])
  end

  local function showWorldMoment(mapId)
    if not (mapId and E.game and E.game.stack) then return end
    local s = state()
    s.worldMoments = type(s.worldMoments) == "table" and s.worldMoments or {}
    local p = base.state()
    for _, row in ipairs(data.worldMoments or {}) do
      local ready = row.map == mapId and not s.worldMoments[row.id]
      if ready and row.legend then
        ready = base.caught(p, E.game.save, row.legend)
      elseif ready and row.rocket then
        ready = s.rocketStage >= row.rocket
      elseif ready and row.mew then
        ready = s.mewCaught and true or false
      end
      if ready then
        s.worldMoments[row.id] = true
        persist(s)
        E.game.stack:push(require("src.render.TextBox").new(
          E.game, localized(row.message)))
        return
      end
    end
  end

  function E.handleTalk(ow, npc, game)
    E.game = game or E.game
    if not (npc and npc.def and game) then return false end
    if baseData.huntRival and npc.def.name == baseData.huntRival.name then
      return false
    end
    if ow.map.id == "OAKS_LAB"
        and npc.def.name == "OAKSLAB_SCIENTIST1"
        and base.hasHallOfFame(game.save) then
      return handleResearch(ow, npc, game)
    end
    if handleRocketTalk(ow, npc, game) then return true end
    if npc.def.name == data.tournament.name then
      return handleTournament(ow, npc, game)
    end
    if npc.def.name == data.newGamePlus.name then
      return handleNewGamePlus(ow, npc, game)
    end
    if npc.def.name == data.mew.name then
      npc.frozen = true
      npc:facePlayer(ow.player)
      startMewEncounter(game, ow, npc, function() npc.frozen = false end)
      return true
    end
    if handleMewClue(ow, npc, game) then return true end
    local reaction = worldReaction(ow, npc, game)
    if reaction then return showMessage(ow, npc, game, reaction) end
    local gym = gymForNpc(ow, npc)
    if gym and handleGymQuest(ow, npc, game, gym) then return true end
    return false
  end

  local function registerTalks()
    if not (mod.content and mod.content.map_scripts) then return end
    for _, def in ipairs(data.rocket) do
      if not def.existing then
        local row = def
        mod.content.map_scripts:register(row.map, {
          priority = 1200,
          talk = {
            [row.textId] = function(game, ow, npc)
              handleRocketTalk(ow, npc, game)
            end,
          },
        })
      end
    end
    mod.content.map_scripts:register(data.tournament.map, {
      priority = 1200,
      talk = {
        [data.tournament.text] = function(game, ow, npc)
          handleTournament(ow, npc, game)
        end,
      },
    })
    mod.content.map_scripts:register(data.mew.map, {
      priority = 1200,
      talk = {
        [data.mew.textId] = function(game, ow, npc, done)
          startMewEncounter(game, ow, npc, done)
        end,
      },
    })
    mod.content.map_scripts:register(data.newGamePlus.map, {
      priority = 1200,
      talk = {
        [data.newGamePlus.textId] = function(game, ow, npc)
          handleNewGamePlus(ow, npc, game)
        end,
      },
    })
  end

  registerTalks()

  mod.events:on("battle.fainted", function(ev)
    local battle = ev and ev.battle
    if battle and ev.battler and ev.battler.isPlayer
        and (battle.ascendantTournament or battle.postgameTier
          or battle.ascendantRocket) then
      battle.ascendantPlayerFaints =
        math.max(0, tonumber(battle.ascendantPlayerFaints) or 0) + 1
    end
  end)

  mod.events:on("battle.ended", function(ev)
    local battle = ev and ev.battle
    if not battle then return end
    if battle.rematchTrainerClass and ev.result == "win" then
      local s = state()
      for key, def in pairs(data.gymQuests) do
        local q = s.gymQuests[key]
        if q and q.active and not q.done
            and def.classes[battle.rematchTrainerClass] then
          q.progress = math.min(def.target,
            math.max(0, math.floor(tonumber(q.progress) or 0)) + 1)
        end
      end
      persist(s)
    end
    if ev.result == "win" and battle.postgameTier then
      markBossBattle({
        kind = battle.postgameGym and "gym" or "elite",
        key = battle.postgameGym or battle.oppClass,
        tier = battle.postgameTier,
      })
      if battle.postgameTier == "crown"
          and battle.oppClass == "OPP_RIVAL3" then
        local clean = true
        for _, mon in ipairs(E.game and E.game.save.party or {}) do
          if LEGENDARY[mon.species] then clean = false break end
        end
        if clean then unlock("purist", state()) end
      end
      if (battle.ascendantPlayerFaints or 0) == 0 then
        unlock("untouchable", state())
      end
    end
    evaluateAchievements(E.game)
  end)

  mod.events:on("pokemon.caught", function(ev)
    if ev and ev.species == "MEW" then
      local s = state()
      s.mewCaught, s.mewStage = true, 4
      persist(s)
      unlock("mew_found", s)
    end
    if E.game then evaluateAchievements(E.game) end
  end)

  local function refreshMap(mapId)
    if not E.game then return end
    evaluateAchievements(E.game)
    ensureRocketNpc(E.game, mapId)
    ensureTournamentHost(E.game, mapId)
    ensureMew(E.game, mapId)
    ensureNewGamePlus(E.game, mapId)
    showWorldMoment(mapId)
    if E.refreshRankMarkers then E.refreshRankMarkers() end
  end

  mod.events:on("map.entered", function(ev)
    refreshMap(ev and ev.mapId)
  end)

  mod.events:on("save.loaded", function()
    local ow = mod.world and mod.world:overworld()
    refreshMap(ow and ow.map and ow.map.id)
  end)

  mod.events:on("mod.options_changed", function(ev)
    if ev and ev.mod == mod.id then
      local ow = mod.world and mod.world:overworld()
      refreshMap(ow and ow.map and ow.map.id)
    end
  end)

  mod.events:on("game.ready", function(ev)
    E.game = ev.game
    local ow = mod.world and mod.world:overworld()
    refreshMap(ow and ow.map and ow.map.id)
  end)

  function E.install(game, deps)
    E.game = game or E.game
    local BattleState = deps and deps.battleState
      or require("src.battle.BattleState")
    if BattleState._ascendantItemsWrapped then return end
    BattleState._ascendantItemsWrapped = true
    local openItems = BattleState.openItems
    BattleState.openItems = function(battle)
      if not battle.ascendantNoItems then return openItems(battle) end
      battle.phase = "messages"
      battle.afterQueue = "menu"
      battle:say(tr(
        "Battle items are\nsealed by this rule!",
        "Kampfitems sind durch\ndiese Regel gesperrt!"))
    end

    local NPC = deps and deps.npc or require("src.world.NPC")
    if not NPC._ascendantRankWrapped then
      NPC._ascendantRankWrapped = true
      local drawNpc = NPC.draw
      NPC.draw = function(npc, camX, camY)
        drawNpc(npc, camX, camY)
        local rank = npc.ascendantRankMarker
        if not rank or not (love and love.graphics) then return end
        local x, y = npc.px - camX + 7, npc.py - camY - 3
        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.rectangle("fill", x, y - 1, 2, 4)
        love.graphics.rectangle("fill", x - 1, y, 4, 2)
        if rank == "legend" then
          love.graphics.rectangle("fill", x + 4, y, 1, 1)
        end
        love.graphics.setColor(1, 1, 1, 1)
      end
    end
  end

  function E.refreshRankMarkers()
    local ow = mod.world and mod.world:overworld()
    if not ow then return end
    local states = trainerStates()
    for _, npc in ipairs(ow.npcs or {}) do
      local row = states[npc.id]
      local progress = row and (
        math.max(0, math.floor(tonumber(row.rematches) or 0))
        + math.max(0, math.floor(tonumber(row.trainingCycles) or 0))) or 0
      local rank = rankFor(progress)
      npc.ascendantRankMarker =
        rank.threshold >= 10 and rank.key or nil
    end
  end

  function E.rematchRank(progress)
    return rankFor(progress)
  end

  function E.rankLine(progress)
    local rank = rankFor(progress)
    return ("★ %s: %s"):format(tr("TRAINER RANK", "TRAINER-RANG"),
      localized(rank.name))
  end

  function E.applyRematchRank(battle, rank)
    local key = type(rank) == "table" and rank.key or rank
    if key == "expert" then
      battle.enemyAIMods = { 1, 3 }
    elseif key == "master" or key == "legend" then
      battle.enemyAIMods = { 1, 2, 3 }
    end
    battle.ascendantRank = key
    return battle
  end

  function E.rankBonusLoot(roll, rank, averageLevel)
    local key = type(rank) == "table" and rank.key or rank
    local level = tonumber(averageLevel) or 0
    roll = math.floor(tonumber(roll) or 10000)
    if roll >= 7401 and roll <= 7900
        and key ~= "rookie" then return "NUGGET" end
    if roll >= 7901 and roll <= 8400
        and (key == "expert" or key == "master" or key == "legend")
        and level >= 20 then return "RARE_CANDY" end
    if roll >= 8401 and roll <= 8900
        and (key == "master" or key == "legend")
        and level >= 35 then return "PP_UP" end
    if roll >= 8901 and roll <= 9100 and key == "legend"
        and level >= 50 then return "MAX_REVIVE" end
    return nil
  end

  function E.selectBossTeam(team, context, game)
    return selectBossTeam(team, context, game)
  end

  function E.applyBossRules(battle)
    local s = state()
    if s.cycle > 0 and mod.options:get("ascendant_rules") ~= "normal" then
      battle.ascendantNoItems = true
      battle.ascendantCycle = s.cycle
    end
    return battle
  end

  function E.archiveText(game)
    local s = evaluateAchievements(game)
    local unlocked = countKeys(s.achievements)
    local researchDone, researchTotal = researchCounts(s)
    local title = s.latestAchievement
      and achievementTitle(s.latestAchievement) or tr("CHAMPION", "CHAMP")
    local researchDone = countKeys(s.research.completed)
    return ("\f%s\n%s"):format(tr("CURRENT TITLE", "AKTIVER TITEL"), title)
      .. ("\f%s: %d/%d\n%s: %d/%d"):format(
        tr("ACHIEVEMENTS", "ERFOLGE"), unlocked, #data.achievements,
        tr("RESEARCH", "FORSCHUNG"), researchDone, researchTotal)
      .. ("\f%s: %d\n%s: %d"):format(
        tr("TOURNAMENT WINS", "TURNIERSIEGE"), s.tournament.wins,
        tr("ROCKET UNITS", "ROCKET-EINHEITEN"), s.rocketStage)
      .. ("\fMEW: %s\n%s: %d"):format(
        s.mewCaught and tr("CAUGHT", "GEFANGEN") or tr("UNKNOWN", "UNBEKANNT"),
        tr("ASCENDANT CYCLE", "ASCENDANT-ZYKLUS"), s.cycle)
  end

  E.state = state
  E.rankFor = rankFor
  E.rematchTotal = rematchTotal
  E.expertTrainerCount = expertTrainerCount
  E.metricValue = metricValue
  E.activeResearch = activeResearch
  E.researchComplete = researchComplete
  E.questDoneCount = questDoneCount
  E.allEnabledLegendsCaught = allEnabledLegendsCaught
  E.mewEligible = mewEligible
  E.worldPhase = worldPhase
  E.evaluateAchievements = evaluateAchievements
  E.beginNewGamePlus = beginNewGamePlus
  E.copyTeam = copyTeam
  return E
end
