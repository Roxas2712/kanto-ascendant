-- Kanto Ascendant 5.0 Grand Tour.
--
-- Two Crown-Champion facilities share one save-safe controller:
--   * the Indigo Battle Factory drafts three of six level-100 rentals;
--   * the S.S. Anne Grand Tour runs five rotating level-100 battles.
--
-- The Factory stores the player's exact original party in mod save data
-- before installing rentals. Normal completion, defeat and recovery of an
-- interrupted old save restore that party before play continues. The global
-- save hotkey is vetoed during a live run so BattleState and the saved party
-- can never diverge.

local LEGENDARY = {
  ARTICUNO = true, ZAPDOS = true, MOLTRES = true,
  MEWTWO = true, MEW = true,
  RAIKOU = true, ENTEI = true, SUICUNE = true,
  LUGIA = true, HO_OH = true, CELEBI = true,
}

local function integer(value, fallback, minimum, maximum)
  value = math.floor(tonumber(value) or fallback or 0)
  if minimum then value = math.max(minimum, value) end
  if maximum then value = math.min(maximum, value) end
  return value
end

local function copyMoves(moves)
  local out = {}
  for i, move in ipairs(moves or {}) do out[i] = move end
  return out
end

local function copyTeam(team)
  local out = {}
  for i, slot in ipairs(team or {}) do
    out[i] = {
      species = slot.species,
      level = integer(slot.level, 100, 1, 100),
      moves = copyMoves(slot.moves),
    }
  end
  return out
end

local function copyOpponent(row)
  return {
    key = row.key, name = row.name, class = row.class,
    intro = row.intro, win = row.win, team = copyTeam(row.team),
  }
end

local function gcd(a, b)
  while b ~= 0 do a, b = b, a % b end
  return math.abs(a)
end

-- Deterministic rotation with a coprime stride: every requested slot is
-- unique even when a content pack changes the pool size later.
local function rotatingSelection(pool, count, seed)
  local out, n = {}, #(pool or {})
  if n == 0 or count <= 0 then return out end
  count = math.min(integer(count, 0, 0), n)
  seed = integer(seed, 1, 1)
  local strides = { 5, 7, 3, 11, 13, 1 }
  local stride = 1
  for offset = 0, #strides - 1 do
    local candidate = strides[((seed + offset - 1) % #strides) + 1]
    if candidate < n and gcd(candidate, n) == 1 then
      stride = candidate
      break
    end
  end
  local start = (seed * 3 + math.floor(seed / 2) - 1) % n
  for i = 0, count - 1 do
    out[#out + 1] = pool[((start + i * stride) % n) + 1]
  end
  return out
end

local function normalizeState(s)
  s = type(s) == "table" and s or {}
  s.version = 1
  s.factory = type(s.factory) == "table" and s.factory or {}
  s.factory.attempts = integer(s.factory.attempts, 0, 0)
  s.factory.wins = integer(s.factory.wins, 0, 0)
  s.factory.bestRound = integer(s.factory.bestRound, 0, 0, 3)
  s.factory.cleanWins = integer(s.factory.cleanWins, 0, 0)
  s.factory.title = s.factory.title == true
  if type(s.factory.activeDraft) ~= "table" then
    s.factory.activeDraft = nil
  end
  s.factory.activeRound = integer(s.factory.activeRound, 0, 0, 3)
  if type(s.factory.backupParty) ~= "table" then
    s.factory.backupParty = nil
    s.factory.activeDraft = nil
    s.factory.activeRound = 0
  end

  s.cruise = type(s.cruise) == "table" and s.cruise or {}
  s.cruise.attempts = integer(s.cruise.attempts, 0, 0)
  s.cruise.clears = integer(s.cruise.clears, 0, 0)
  s.cruise.bestRound = integer(s.cruise.bestRound, 0, 0, 5)
  s.cruise.nextAt = integer(s.cruise.nextAt, 0, 0)
  s.cruise.title = s.cruise.title == true
  return s
end

local function rawBucket(save, modId)
  if type(save) ~= "table" then return nil end
  save.modData = type(save.modData) == "table" and save.modData or {}
  save.modData[modId] = type(save.modData[modId]) == "table"
    and save.modData[modId] or {}
  return save.modData[modId]
end

local function recoverRawParty(save, modId)
  local bucket = rawBucket(save, modId)
  if not bucket then return false end
  local s = normalizeState(bucket.grand_tour)
  local backup = s.factory.backupParty
  if backup then
    save.party = backup
    s.factory.backupParty = nil
    s.factory.activeDraft = nil
    s.factory.activeRound = 0
  end
  bucket.grand_tour = s
  return backup ~= nil
end

return function(mod, opts)
  opts = opts or {}
  local data = assert(opts.data, "Grand Tour data missing")
  local postgame = assert(opts.postgame, "postgame controller missing")
  local i18n = opts.i18n
  local G = { game = nil }
  local activeFactory

  local function tr(en, de)
    return i18n and i18n.text(en, de) or en
  end

  local function localized(row)
    return type(row) == "table" and tr(row.en, row.de) or row
  end

  local function reconcileTitleFlags(s)
    local ascendant = mod.save:get("ascendant")
    local achievements = type(ascendant) == "table"
      and type(ascendant.achievements) == "table"
      and ascendant.achievements or {}
    local changed = false
    if achievements.factory_architect and not s.factory.title then
      s.factory.title = true
      changed = true
    end
    if achievements.sea_champion and not s.cruise.title then
      s.cruise.title = true
      changed = true
    end
    return changed
  end

  local function state(create)
    local s = mod.save:get("grand_tour")
    if type(s) ~= "table" and create ~= false then
      s = normalizeState(nil)
      mod.save:set("grand_tour", s)
    elseif type(s) == "table" then
      s = normalizeState(s)
    end
    if s and reconcileTitleFlags(s) then mod.save:set("grand_tour", s) end
    return s
  end

  local function persist(s)
    if s then mod.save:set("grand_tour", s) end
  end

  local function realSteps()
    if type(opts.stepClock) == "function" then
      return integer(opts.stepClock(), 0, 0)
    end
    return integer(mod.save:get("step_clock", 0), 0, 0)
  end

  local function eligible()
    local p = postgame.state(false)
    return p and p.crownChampion == true or false
  end

  local function isFinalEvolution(game, species)
    local def = game and game.data and game.data.pokemon
      and game.data.pokemon[species]
    if not def then return false end
    local dex = tonumber(def.dex)
    if not dex or dex < 1 or dex > 251 or LEGENDARY[species] then return false end
    for _, evo in ipairs(def.evolutions or {}) do
      local target = game.data.pokemon[evo.species]
      local targetDex = target and tonumber(target.dex)
      if targetDex and targetDex >= 1 and targetDex <= 251 then return false end
    end
    return true
  end

  local function availableCandidates(game)
    local out = {}
    for _, row in ipairs(data.factory.candidates or {}) do
      if isFinalEvolution(game, row.species) then out[#out + 1] = row end
    end
    return out
  end

  local function draftCandidates(game, attempt)
    local selected = rotatingSelection(availableCandidates(game), 6, attempt)
    return copyTeam(selected)
  end

  local function factoryBracket(attempt)
    local out = {}
    for _, row in ipairs(rotatingSelection(
        data.factory.opponents, data.factory.rounds or 3, attempt)) do
      out[#out + 1] = copyOpponent(row)
    end
    return out
  end

  local function cruiseBracket(attempt)
    local out = {}
    for _, row in ipairs(rotatingSelection(
        data.cruise.opponents, data.cruise.rounds or 5, attempt + 17)) do
      out[#out + 1] = copyOpponent(row)
    end
    return out
  end

  local function applyMoves(game, mon, moves)
    local built = {}
    for _, id in ipairs(moves or {}) do
      local def = game.data.moves and game.data.moves[id]
      if def then built[#built + 1] = { id = id, pp = def.pp or 0 } end
    end
    if #built > 0 then mon.moves = built end
  end

  local function buildRental(game, row)
    local Pokemon = require("src.pokemon.Pokemon")
    local mon = Pokemon.new(game.data, row.species, 100)
    applyMoves(game, mon, row.moves)
    mon.factoryRental = true
    mon.factoryLevel = 100
    local ok, BattleState = pcall(require, "src.battle.BattleState")
    if ok and BattleState and BattleState.stampOT then
      BattleState.stampOT(game.save, mon)
    end
    Pokemon.heal(mon)
    return mon
  end

  local function buildRentalTeam(game, draft)
    local out, seen = {}, {}
    for _, row in ipairs(draft or {}) do
      if row and not seen[row.species] and isFinalEvolution(game, row.species) then
        seen[row.species] = true
        out[#out + 1] = buildRental(game, row)
      end
    end
    return out
  end

  local function healParty(game)
    local Pokemon = require("src.pokemon.Pokemon")
    for _, mon in ipairs(game.save.party or {}) do Pokemon.heal(mon) end
  end

  local function partyHasFaint(game)
    for _, mon in ipairs(game.save.party or {}) do
      if (tonumber(mon.hp) or 0) <= 0 then return true end
    end
    return false
  end

  local function restoreFactoryParty(game)
    local s = state()
    local backup = activeFactory and activeFactory.backup
      or s.factory.backupParty
    if backup then game.save.party = backup end
    s.factory.backupParty = nil
    s.factory.activeDraft = nil
    s.factory.activeRound = 0
    persist(s)
    activeFactory = nil
    return backup ~= nil
  end

  local function frontierBalance()
    local ascendant = mod.save:get("ascendant")
    if type(ascendant) ~= "table" then return nil end
    return integer(ascendant.frontierPoints, 0, 0)
  end

  local function awardPoints(count, reason)
    if type(opts.awardFrontierPoints) ~= "function" then return 0 end
    local before = frontierBalance()
    local ok, result = pcall(opts.awardFrontierPoints, count, reason)
    if not ok then
      if mod.log then mod.log:warn("Grand Tour point award failed: %s", result) end
      return 0
    end
    local after = frontierBalance()
    if after ~= nil then
      return math.max(0, after - (before or 0))
    end
    -- Third-party controllers without the Ascendant wallet cannot expose a
    -- multiplier here; the requested base award remains the truthful fallback.
    return integer(count, 0, 0)
  end

  local function unlockTitle(id)
    if type(opts.unlockTitle) ~= "function" then return false end
    local ok, result = pcall(opts.unlockTitle, id)
    if not ok then
      if mod.log then mod.log:warn("Grand Tour title unlock failed: %s", result) end
      return false
    end
    return result ~= false
  end

  local function namedBattle(game, opponent, tier)
    local battle = postgame.newForcedBattle(
      game, opponent.class, copyTeam(opponent.team), tier)
    battle.rematch = true
    battle.grandTour = true
    battle.ascendantNoItems = true
    battle.noPrizeMoney = true
    battle.enemyAIMods = { 1, 2, 3 }
    if battle.trainer then
      battle.trainer = setmetatable({ name = localized(opponent.name) },
        { __index = battle.trainer })
    end
    battle.introText = localized(opponent.intro)
    battle.endBattleText = localized(opponent.win)
    return battle
  end

  local function safeAfterBattle(ow, result, battle)
    -- A facility defeat ends the run without a blackout or money loss.
    ow:afterBattle(result == "win" and "win" or "run", battle)
  end

  local function normalizeDraft(game, selected)
    local catalog = {}
    for _, row in ipairs(availableCandidates(game)) do catalog[row.species] = row end
    local out, seen = {}, {}
    for _, value in ipairs(selected or {}) do
      local species = type(value) == "table" and value.species or value
      local row = catalog[species]
      if row and not seen[species] then
        seen[species] = true
        out[#out + 1] = row
      end
    end
    return out
  end

  local function startFactoryRun(game, ow, npc, selected)
    local draft = normalizeDraft(game, selected)
    if #draft ~= 3 then return false, "draft" end
    -- An impossible stale run is repaired before a new party is backed up.
    if state().factory.backupParty then restoreFactoryParty(game) end

    local s = state()
    s.factory.attempts = s.factory.attempts + 1
    local attempt = s.factory.attempts
    local backup = game.save.party
    s.factory.backupParty = backup
    s.factory.activeDraft = {
      draft[1].species, draft[2].species, draft[3].species,
    }
    s.factory.activeRound = 0
    persist(s)

    local function rollbackFactory(code, detail, announce)
      restoreFactoryParty(game)
      if npc then npc.frozen = false end
      if mod.log then
        mod.log:warn("Grand Tour Factory %s failed: %s",
          tostring(code), tostring(detail))
      end
      if announce and game.stack then
        game.stack:push(require("src.render.TextBox").new(game, tr(
          "FACTORY SYSTEM ERROR\fThe run was cancelled.\nYour original team\nhas been restored.",
          "FABRIK-SYSTEMFEHLER\fDer Lauf wurde beendet.\nDein ursprüngliches\nTeam ist zurück.")))
      end
      return false, code
    end

    local rentalsOk, rentals = pcall(buildRentalTeam, game, draft)
    if not rentalsOk then
      return rollbackFactory("rental_error", rentals, false)
    end
    if type(rentals) ~= "table" or #rentals ~= 3 then
      return rollbackFactory("rental_error",
        "rental builder did not return exactly three Pokemon", false)
    end
    game.save.party = rentals
    activeFactory = { backup = backup, attempt = attempt }
    local bracket = factoryBracket(attempt)
    local round, clean = 0, true

    local function nextRound()
      round = round + 1
      local current = state()
      current.factory.activeRound = round
      persist(current)
      local opponent = bracket[round]
      local battleOk, battle = pcall(function()
        local prepared = namedBattle(game, opponent, "battle_factory")
        prepared.grandTourFacility = "factory"
        prepared.grandTourRound = round
        return prepared
      end)
      if not battleOk then
        return rollbackFactory("battle_error", battle, round > 1)
      end
      battle.onFinish = function(result)
        if partyHasFaint(game) or (battle.ascendantPlayerFaints or 0) > 0 then
          clean = false
        end
        if result ~= "win" then
          restoreFactoryParty(game)
          safeAfterBattle(ow, result, battle)
          npc.frozen = false
          game.stack:push(require("src.render.TextBox").new(game, tr(
            ("FACTORY RUN ENDED\nafter round %d.\fYour original team\nhas been restored.")
              :format(math.max(0, round - 1)),
            ("FABRIK-LAUF ENDE\nnach Runde %d.\fDein ursprüngliches\nTeam ist zurück.")
              :format(math.max(0, round - 1)))))
          return
        end

        local progress = state()
        progress.factory.bestRound = math.max(progress.factory.bestRound, round)
        persist(progress)
        if round < #bracket then
          safeAfterBattle(ow, "win", battle)
          healParty(game)
          game.stack:push(require("src.render.TextBox").new(game, tr(
            ("FACTORY ROUND %d WON!\fThe rentals are fully\nrestored.")
              :format(round),
            ("FABRIK-RUNDE %d SIEG!\fDie Leih-POKéMON sind\nvollständig geheilt.")
              :format(round)), nextRound))
          return
        end

        restoreFactoryParty(game)
        safeAfterBattle(ow, "win", battle)
        local completed = state()
        completed.factory.wins = completed.factory.wins + 1
        if clean then completed.factory.cleanWins = completed.factory.cleanWins + 1 end
        local firstTitle = not completed.factory.title
        local baseGain = clean and 6 or 4
        local credited = awardPoints(baseGain, clean and "BATTLE FACTORY CLEAN"
          or "BATTLE FACTORY CLEAR")
        if firstTitle and unlockTitle("factory_architect") then
          completed.factory.title = true
        end
        persist(completed)
        npc.frozen = false
        local message = tr(
          "BATTLE FACTORY\nCLEARED!\fYour original team\nhas been restored.",
          "KAMPFFABRIK\nGESCHAFFT!\fDein ursprüngliches\nTeam ist zurück.")
          .. ("\f+%d %s"):format(credited,
            tr("FRONTIER POINTS", "FRONTIER-PUNKTE"))
        if clean then
          message = message .. "\f" .. tr(
            "CLEAN DRAFT BONUS!\nNo rental fainted.",
            "SAUBERER ENTWURF!\nKein Leih-POKéMON\nwurde besiegt.")
        end
        game.stack:push(require("src.render.TextBox").new(game, message))
      end
      ow:pushBattle(battle)
      return true
    end

    local started, err = nextRound()
    if not started then return false, err end
    return true
  end

  local function draftDetails(game, row)
    local species = game.data.pokemon[row.species]
    local names = {}
    for _, id in ipairs(row.moves or {}) do
      local move = game.data.moves and game.data.moves[id]
      names[#names + 1] = move and move.name or id:gsub("_", " ")
    end
    return (species and species.name or row.species)
      .. "  L100\f" .. table.concat(names, "\n")
  end

  local function openFactoryDraft(game, ow, npc)
    local s = state()
    local candidates = draftCandidates(game, s.factory.attempts + 1)
    if #candidates < 6 then
      npc.frozen = false
      game.stack:push(require("src.render.TextBox").new(game, tr(
        "The Factory could not\nprepare six legal\nrentals.",
        "Die Fabrik konnte keine\nsechs gültigen Leih-\nPOKéMON vorbereiten.")))
      return false
    end
    local picked, pickedSet, rows = {}, {}, {}
    for index, candidate in ipairs(candidates) do
      local def = game.data.pokemon[candidate.species]
      rows[#rows + 1] = {
        label = def and def.name or candidate.species,
        right = "--", value = { kind = "candidate", index = index },
      }
    end
    local startRow = {
      label = tr("BEGIN", "START"), right = "0/3", value = { kind = "start" },
    }
    rows[#rows + 1] = startRow
    rows[#rows + 1] = {
      label = tr("CANCEL", "ZURÜCK"), value = { kind = "cancel" },
    }

    local function refreshMarks()
      for index = 1, 6 do rows[index].right = "--" end
      for order, index in ipairs(picked) do rows[index].right = tostring(order) end
      startRow.right = tostring(#picked) .. "/3"
    end

    game.stack:push(mod.ui.ListMenu.new(game,
      tr("FACTORY DRAFT", "FABRIK-AUSWAHL"), rows, {
        footer = tr("A PICK  SELECT INFO", "A WAHL  SELECT INFO"),
        onCancel = function() npc.frozen = false end,
        onSelectKey = function(item)
          if item.value.kind == "candidate" then
            game.stack:push(require("src.render.TextBox").new(game,
              draftDetails(game, candidates[item.value.index])))
          end
        end,
        onChoose = function(item, menu)
          local value = item.value
          if value.kind == "candidate" then
            local index = value.index
            if pickedSet[index] then
              pickedSet[index] = nil
              for i = #picked, 1, -1 do
                if picked[i] == index then table.remove(picked, i) break end
              end
            elseif #picked < 3 then
              pickedSet[index] = true
              picked[#picked + 1] = index
            end
            refreshMarks()
          elseif value.kind == "start" then
            if #picked < 3 then
              game.stack:push(require("src.render.TextBox").new(game, tr(
                "Choose exactly three\nrentals first.",
                "Wähle zuerst genau\ndrei Leih-POKéMON.")))
              return
            end
            local selected = {}
            for _, index in ipairs(picked) do selected[#selected + 1] = candidates[index] end
            menu:close()
            local ok = startFactoryRun(game, ow, npc, selected)
            if not ok then
              npc.frozen = false
              game.stack:push(require("src.render.TextBox").new(game, tr(
                "The rental team could\nnot be prepared.",
                "Das Leihteam konnte\nnicht vorbereitet werden.")))
            end
          else
            menu:close()
            npc.frozen = false
          end
        end,
      }))
    return true
  end

  local function handleFactory(game, ow, npc)
    if not eligible() then return false end
    npc.frozen = true
    npc:facePlayer(ow.player)
    local s = state()
    local message = tr(
      "BATTLE FACTORY\fDraft three of six\nLEVEL 100 rentals.\fWin three battles.\nThe BAG is sealed.\fYour original team is\nalways returned.\fEnter?",
      "KAMPFFABRIK\fWähle drei von sechs\nLEVEL-100-Leih-POKéMON.\fGewinne drei Kämpfe.\nDer BEUTEL ist gesperrt.\fDein eigenes Team kehrt\nimmer zurück.\fAntreten?")
      .. ("\f%s: %d  %s: %d"):format(
        tr("WINS", "SIEGE"), s.factory.wins,
        tr("BEST", "BESTE"), s.factory.bestRound)
    game.stack:push(require("src.render.TextBox").new(game, message, nil, {
      choice = function(yes)
        if yes then openFactoryDraft(game, ow, npc)
        else npc.frozen = false end
      end,
    }))
    return true
  end

  local function cruiseRemaining()
    return math.max(0, state().cruise.nextAt - realSteps())
  end

  local function startCruise(game, ow, npc)
    local s = state()
    if cruiseRemaining() > 0 then return false, "cooldown" end
    s.cruise.attempts = s.cruise.attempts + 1
    local attempt = s.cruise.attempts
    persist(s)
    local bracket = cruiseBracket(attempt)
    local round = 0
    healParty(game)

    local function nextRound()
      round = round + 1
      local opponent = bracket[round]
      local battle = namedBattle(game, opponent, "ss_anne_grand_tour")
      battle.grandTourFacility = "ss_anne"
      battle.grandTourRound = round
      battle.onFinish = function(result)
        if result ~= "win" then
          healParty(game)
          safeAfterBattle(ow, result, battle)
          npc.frozen = false
          game.stack:push(require("src.render.TextBox").new(game, tr(
            ("GRAND TOUR ENDED\nafter round %d.\fThe ship will welcome\nyou back anytime.")
              :format(math.max(0, round - 1)),
            ("GROSSE FAHRT ENDE\nnach Runde %d.\fDas Schiff empfängt\ndich jederzeit wieder.")
              :format(math.max(0, round - 1)))))
          return
        end

        local progress = state()
        progress.cruise.bestRound = math.max(progress.cruise.bestRound, round)
        persist(progress)
        safeAfterBattle(ow, "win", battle)
        if round < #bracket then
          local restored = round == 2 or round == 4
          if restored then healParty(game) end
          local message = tr(
            ("DECK %d CLEARED!"):format(round),
            ("DECK %d GESCHAFFT!"):format(round))
          if restored then
            message = message .. "\f" .. tr(
              "Your team is fully\nrestored.",
              "Dein Team wird\nvollständig geheilt.")
          else
            message = message .. "\f" .. tr(
              "The voyage continues\nwithout a rest.",
              "Die Fahrt geht ohne\nPause weiter.")
          end
          game.stack:push(require("src.render.TextBox").new(
            game, message, nextRound))
          return
        end

        local completed = state()
        completed.cruise.clears = completed.cruise.clears + 1
        local cooldown = integer(data.cruise.cooldown, 4096, 1)
        completed.cruise.nextAt = realSteps()
          + cooldown
        local firstTitle = not completed.cruise.title
        local credited = awardPoints(8, "S.S. ANNE GRAND TOUR")
        if firstTitle and unlockTitle("sea_champion") then
          completed.cruise.title = true
        end
        persist(completed)
        npc.frozen = false
        local message = tr(
          "S.S. ANNE GRAND TOUR\nCLEARED!",
          "S.S. ANNE-FAHRT\nGESCHAFFT!")
          .. ("\f+%d %s"):format(credited,
            tr("FRONTIER POINTS", "FRONTIER-PUNKTE"))
          .. "\f" .. tr(
            ("The next voyage departs\nafter %d real steps."):format(cooldown),
            ("Die nächste Fahrt startet\nnach %d echten Schritten."):format(
              cooldown))
        game.stack:push(require("src.render.TextBox").new(game, message))
      end
      ow:pushBattle(battle)
    end

    nextRound()
    return true
  end

  local function handleCruise(game, ow, npc)
    if not eligible() then return false end
    npc.frozen = true
    npc:facePlayer(ow.player)
    local remaining = cruiseRemaining()
    if remaining > 0 then
      game.stack:push(require("src.render.TextBox").new(game, tr(
        ("The S.S. ANNE is\nresupplying.\fNext departure in\n%d real steps."):format(remaining),
        ("Die S.S. ANNE wird\nversorgt.\fNächste Abfahrt in\n%d echten Schritten."):format(remaining)),
        function() npc.frozen = false end))
      return true
    end
    local s = state()
    local message = tr(
      "S.S. ANNE GRAND TOUR\fFive LEVEL 100 battles.\nHealing follows decks\ntwo and four.\fThe BAG is sealed.\nNo prize money.\fBoard the tour?",
      "S.S. ANNE-FAHRT\fFünf LEVEL-100-Kämpfe.\nHeilung folgt nach Deck\nzwei und vier.\fDer BEUTEL ist gesperrt.\nKein Preisgeld.\fAn Bord gehen?")
      .. ("\f%s: %d  %s: %d"):format(
        tr("CLEARS", "SIEGE"), s.cruise.clears,
        tr("BEST", "BESTE"), s.cruise.bestRound)
    game.stack:push(require("src.render.TextBox").new(game, message, nil, {
      choice = function(yes)
        if yes then
          local ok = startCruise(game, ow, npc)
          if not ok then npc.frozen = false end
        else
          npc.frozen = false
        end
      end,
    }))
    return true
  end

  local function runtimeObjectIds(game, def)
    local out = {}
    local map = game and game.data and game.data.maps
      and game.data.maps[def.map]
    for _, obj in ipairs(map and map.objects or {}) do
      if obj.runtime and obj.owner == mod.id and obj.name == def.name then
        out[#out + 1] = def.map .. "_obj_" .. tostring(obj.index)
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

  local function ensureHost(game, mapId, def)
    local ids = runtimeObjectIds(game, def)
    local should = eligible() and mapId == def.map
    if not should then
      for _, id in ipairs(ids) do mod.world:removeNpc(id) end
      return
    end
    if #ids > 0 then return end
    local ow = mod.world:overworld()
    if not (ow and ow.map and ow.map.id == def.map) then return end
    local x, y = findSpawnCell(ow, def.preferred)
    if not x then
      if mod.log then mod.log:warn("no free Grand Tour host cell on %s", def.map) end
      return
    end
    mod.world:spawnNpc(def.map, {
      name = def.name, sprite = def.sprite, movement = "STAY", range = "DOWN",
      text = def.textId, x = x, y = y,
    })
  end

  local function refresh(game, mapId)
    if not (mod.world and game) then return end
    local ow = mod.world:overworld()
    mapId = mapId or (ow and ow.map and ow.map.id)
    ensureHost(game, mapId, data.factory)
    ensureHost(game, mapId, data.cruise)
  end

  if mod.content and mod.content.map_scripts then
    mod.content.map_scripts:register(data.factory.map, {
      priority = 2400,
      talk = {
        [data.factory.textId] = function(game, ow, npc)
          return handleFactory(game, ow, npc)
        end,
      },
    })
    mod.content.map_scripts:register(data.cruise.map, {
      priority = 2400,
      talk = {
        [data.cruise.textId] = function(game, ow, npc)
          return handleCruise(game, ow, npc)
        end,
      },
    })
  end

  if mod.migrations and mod.migrations.add then
    mod.migrations:add("5.0.0", function(bucket, save)
      bucket.grand_tour = normalizeState(bucket.grand_tour)
      local backup = bucket.grand_tour.factory.backupParty
      if backup then
        save.party = backup
        bucket.grand_tour.factory.backupParty = nil
        bucket.grand_tour.factory.activeDraft = nil
        bucket.grand_tour.factory.activeRound = 0
      end
    end)
  end

  mod.events:on("save.loading", function(ev)
    activeFactory = nil
    recoverRawParty(ev and ev.raw, mod.id)
  end, 3000)

  mod.hooks:wrap("save.write", function(nextWrite, game)
    local s = state(false)
    if s and s.factory and s.factory.backupParty then
      -- F1 can call Game:writeSave even while BattleState is active. Swapping
      -- the live party inside save.writing would leave the current battle and
      -- its round callbacks pointing at the rentals while later rounds used
      -- the restored team. Refuse that write instead; normal completion or
      -- defeat restores the party, and save.loading still repairs any stale
      -- pre-5.0 interrupted run before validation.
      if game and game.stack then
        local ok, TextBox = pcall(require, "src.render.TextBox")
        if ok and TextBox then
          game.stack:push(TextBox.new(game, tr(
            "Saving is unavailable\nduring a FACTORY run.\fFinish the run first;\nyour team is safe.",
            "Speichern ist während\nder FABRIK gesperrt.\fBeende zuerst den Lauf;\ndein Team ist sicher.")))
        end
      end
      return false
    end
    return nextWrite(game)
  end, 3000)

  mod.events:on("save.loaded", function(ev)
    activeFactory = nil
    local game = G.game
    if game and state(false) and state(false).factory.backupParty then
      restoreFactoryParty(game)
    end
    local ow = mod.world and mod.world:overworld()
    if game then refresh(game, ow and ow.map and ow.map.id) end
  end)

  mod.events:on("map.entered", function(ev)
    local game = ev and ev.game or G.game
    local mapId = ev and (ev.mapId or ev.map and ev.map.id)
    if game then refresh(game, mapId) end
  end)

  function G.install(game)
    G.game = game
    state()
    if state().factory.backupParty then restoreFactoryParty(game) end
    local ow = mod.world and mod.world:overworld()
    refresh(game, ow and ow.map and ow.map.id)
  end

  function G.statusText()
    local s = state()
    local remaining = cruiseRemaining()
    local cruiseReady = remaining == 0 and tr("READY", "BEREIT")
      or (tostring(remaining) .. " " .. tr("STEPS", "SCHRITTE"))
    return tr("GRAND TOUR", "GROSSE FAHRT")
      .. ("\f%s\n%s: %d/%d\n%s: %d\n%s: %d"):format(
        tr("BATTLE FACTORY", "KAMPFFABRIK"),
        tr("WINS", "SIEGE"), s.factory.wins, s.factory.attempts,
        tr("BEST ROUND", "BESTE RUNDE"), s.factory.bestRound,
        tr("CLEAN WINS", "SAUBERE SIEGE"), s.factory.cleanWins)
      .. ("\fS.S. ANNE\n%s: %d/%d\n%s: %d\n%s: %s"):format(
        tr("CLEARS", "SIEGE"), s.cruise.clears, s.cruise.attempts,
        tr("BEST ROUND", "BESTE RUNDE"), s.cruise.bestRound,
        tr("DEPARTURE", "ABFAHRT"), cruiseReady)
  end

  G.state = state
  G.eligible = eligible
  G.realSteps = realSteps
  G.cruiseRemaining = cruiseRemaining
  G.isFinalEvolution = isFinalEvolution
  G.availableCandidates = availableCandidates
  G.draftCandidates = draftCandidates
  G.factoryBracket = factoryBracket
  G.cruiseBracket = cruiseBracket
  G.buildRental = buildRental
  G.buildRentalTeam = buildRentalTeam
  G.restoreFactoryParty = restoreFactoryParty
  G.startFactoryRun = startFactoryRun
  G.startCruise = startCruise
  G.openFactoryDraft = openFactoryDraft
  G.handleFactory = handleFactory
  G.handleCruise = handleCruise
  G.refresh = refresh
  G.normalizeState = normalizeState
  G.recoverRawParty = function(save) return recoverRawParty(save, mod.id) end
  G.rotatingSelection = rotatingSelection
  return G
end
