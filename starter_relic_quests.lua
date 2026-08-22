-- The three Johto starter relic journeys.
--
-- Assignment is deliberately based on ownership, never on the source that
-- awarded the Pokémon. A starter trial gift, wild catch, event gift, traded
-- save or evolved family member therefore opens the same one-time journey.

return function(mod, opts)
  opts = opts or {}
  local i18n = opts.i18n
  local placement = assert(opts.placement, "runtime NPC placement missing")
  local megaEvolution = assert(opts.megaEvolution, "Mega controller missing")
  local ascendantTyphlosion = assert(
    opts.ascendantTyphlosion, "Ascendant Typhlosion controller missing")
  local R = { game = nil }

  local QUESTS = {
    chikorita = {
      family = { CHIKORITA = true, BAYLEEF = true, MEGANIUM = true },
      title = { en = "VERDANT RELIC", de = "PFLANZEN-RELIKT" },
      stone = "MEGANIUMITE", steps = 1520, wins = 3,
      trialSteps = 251,
      trialMaps = { VIRIDIAN_FOREST = true },
      trial = {
        en = "VIRIDIAN FOREST", de = "VERTANIA-WALD",
      },
      flavor = {
        en = "A leaf-shaped relic\nresponded to your bond.\fLet it drink in Kanto's\noldest forest, then prove\nits resolve in battle.",
        de = "Ein blattförmiges Relikt\nantwortet auf euer Band.\fLasst es Kantos ältesten\nWald spüren und beweist\ndann euren Mut im Kampf.",
      },
      map = "CELADON_CITY", location = {
        en = "CELADON CITY", de = "PRISMANIA CITY",
      },
      npc = "KANTO_ASCENDANT_VERDANT_RELIC_KEEPER",
      text = "MOD_KANTO_ASCENDANT_VERDANT_RELIC",
      sprite = "SPRITE_COOLTRAINER_F",
      preferred = { { 36, 12 }, { 36, 11 }, { 37, 12 } },
    },
    totodile = {
      family = { TOTODILE = true, CROCONAW = true, FERALIGATR = true },
      title = { en = "TORRENT RELIC", de = "FLUT-RELIKT" },
      stone = "FERALIGATRITE", steps = 1580, wins = 5,
      trialSteps = 251,
      trialMaps = {
        SEAFOAM_ISLANDS_1F = true, SEAFOAM_ISLANDS_B1F = true,
        SEAFOAM_ISLANDS_B2F = true, SEAFOAM_ISLANDS_B3F = true,
        SEAFOAM_ISLANDS_B4F = true,
      },
      trial = {
        en = "SEAFOAM ISLANDS", de = "SEESCHAUMINSELN",
      },
      flavor = {
        en = "A fang-shaped relic\ncalls from an ancient\ntorrent.\fCross Seafoam's ice and\ntide, then conquer five\ntrainer battles together.",
        de = "Ein zahnförmiges Relikt\nruft aus uralter Strömung.\fDurchquert Eis und Flut\nder Seeschauminseln und\ngewinnt fünf Trainerkämpfe.",
      },
      map = "CERULEAN_CITY", location = {
        en = "CERULEAN CITY", de = "AZURIA CITY",
      },
      npc = "KANTO_ASCENDANT_TORRENT_RELIC_KEEPER",
      text = "MOD_KANTO_ASCENDANT_TORRENT_RELIC",
      sprite = "SPRITE_SWIMMER",
      preferred = { { 30, 30 }, { 31, 30 }, { 29, 30 } },
    },
    cyndaquil = {
      family = { CYNDAQUIL = true, QUILAVA = true, TYPHLOSION = true },
      title = { en = "BASALT RELIC", de = "BASALT-RELIKT" },
    },
  }
  local ORDER = {
    "chikorita", "totodile", "cyndaquil",
  }

  local function tr(en, de)
    return i18n and i18n.text(en, de) or en
  end

  local function localized(row)
    return tr(row.en, row.de)
  end

  local function rewardStones(def)
    if type(def.stones) == "table" then return def.stones end
    return def.stone and { def.stone } or {}
  end

  local function rewardsOwned(def)
    local rewards = rewardStones(def)
    if #rewards == 0 then return false end
    for _, stone in ipairs(rewards) do
      if not megaEvolution.hasStone(stone) then return false end
    end
    return true
  end

  local function rewardLabel(def)
    local names = {}
    for _, stone in ipairs(rewardStones(def)) do
      names[#names + 1] = stone:gsub("_", " ")
    end
    return table.concat(names, "\n")
  end

  local function state(create)
    local s = mod.save:get("starter_relic_quests")
    if type(s) ~= "table" and create ~= false then
      s = { version = 2, quests = {} }
      mod.save:set("starter_relic_quests", s)
    end
    if type(s) == "table" then
      s.version = 2
      s.quests = type(s.quests) == "table" and s.quests or {}
      for key, def in pairs(QUESTS) do
        local q = s.quests[key]
        if type(q) == "table" then
          q.assigned = q.assigned == true
          q.steps = math.max(0, math.floor(tonumber(q.steps) or 0))
          q.wins = math.max(0, math.floor(tonumber(q.wins) or 0))
          q.trialSteps = math.max(0,
            math.floor(tonumber(q.trialSteps) or 0))
          local entitled = q.claimed == true
            or rewardsOwned(def)
            or (key == "cyndaquil"
              and ascendantTyphlosion.state(false)
              and ascendantTyphlosion.state(false).unlocked)
          q.claimed = entitled == true
          q.introSeen = q.introSeen == true or q.claimed
          if q.claimed then q.assigned = true end
        end
      end
    end
    return s
  end

  local function persist(s)
    if s then mod.save:set("starter_relic_quests", s) end
  end

  local function questState(key, create)
    local s = state(create)
    if not s then return nil end
    local q = s.quests[key]
    if type(q) ~= "table" and create ~= false then
      q = {
        assigned = false, steps = 0, wins = 0, trialSteps = 0,
        claimed = false, introSeen = false,
      }
      s.quests[key] = q
    end
    return q, s
  end

  local function matchingKey(species)
    for key, def in pairs(QUESTS) do
      if def.family[species] then return key end
    end
  end

  local function inspectMon(mon, found)
    local key = mon and not mon.isEgg and matchingKey(mon.species)
    if key then found[key] = true end
  end

  local function ownedFamilies(game)
    local found = {}
    local save = game and game.save or {}
    local owned = save.pokedex and save.pokedex.owned or {}
    for key, def in pairs(QUESTS) do
      for species in pairs(def.family) do
        if owned[species] then found[key] = true break end
      end
    end
    for _, mon in ipairs(save.party or {}) do inspectMon(mon, found) end
    for _, box in ipairs(save.boxes or {}) do
      local mons = type(box) == "table" and (box.mons or box) or {}
      for _, mon in ipairs(mons) do inspectMon(mon, found) end
    end
    return found
  end

  local function assign(game)
    if not game then return false end
    local found, changed = ownedFamilies(game), false
    local s = state()
    for key in pairs(found) do
      local q = questState(key)
      if not q.assigned then
        q.assigned = true
        q.assignedAt = os.time()
        changed = true
      end
    end
    if changed then persist(s) end
    return changed
  end

  local function familyInParty(game, key)
    local def = QUESTS[key]
    for _, mon in ipairs(game and game.save and game.save.party or {}) do
      if not mon.isEgg and def.family[mon.species] then return true end
    end
    return false
  end

  local function ready(key)
    local def, q = QUESTS[key], questState(key, false)
    if not (def and q and q.assigned) then return false end
    if key == "cyndaquil" then return ascendantTyphlosion.ready(R.game) end
    return q.steps >= def.steps and q.wins >= def.wins
      and (not def.trialSteps or q.trialSteps >= def.trialSteps)
  end

  local function statusRight(key)
    local def, q = QUESTS[key], questState(key, false)
    if not (def and q) then return nil end
    if q.claimed then return tr("OWN", "HAT") end
    if not q.introSeen then return tr("NEW", "NEU") end
    if ready(key) then return tr("READY", "BEREIT") end
    if key == "cyndaquil" then return tr("SEALED", "VERS.") end
    return ("%d/%d"):format(math.min(q.wins, def.wins), def.wins)
  end

  local function nextObjective(game, key)
    local def, q = QUESTS[key], questState(key, false)
    if not (def and q and q.assigned) then
      return tr("NEXT: FIND THE RELIC\nOwn this starter family.",
        "NÄCHSTES ZIEL: RELIKT\nBesitze diese\nStarter-Familie.")
    end
    if q.claimed then
      return tr("QUEST COMPLETE", "MISSION BEENDET")
    end
    if key == "cyndaquil" then
      if not ascendantTyphlosion.goldCleared() then
        return tr(
          "NEXT: DEFEAT GOLD\nINDIGO PLATEAU LOBBY\nComplete JOHTO MASTERS.",
          "NÄCHSTES ZIEL: GOLD\nINDIGO-PLATEAU-LOBBY\nBeende JOHTO MASTERS.")
      end
      local count = ascendantTyphlosion.ownedCount(game)
      if count < 251 then
        return tr(
          ("NEXT: COMPLETE POKéDEX\nCaught: %d/251"):format(count),
          ("NÄCHSTES ZIEL: POKéDEX\nGefangen: %d/251"):format(count))
      end
      local mon = ascendantTyphlosion.typhlosion(game)
      if not mon then
        return tr(
          "NEXT: BRING TYPHLOSION\nPut it in your PARTY.",
          "NÄCHSTES ZIEL: TORNUPTO\nNimm es in dein TEAM.")
      end
      local level = math.max(1, math.floor(tonumber(mon.level) or 1))
      if level < 100 then
        return tr(
          ("NEXT: REACH THE SUMMIT\nTYPHLOSION LV%d/100"):format(level),
          ("NÄCHSTES ZIEL: GIPFEL\nTORNUPTO LV%d/100"):format(level))
      end
      return tr(
        "NEXT: BASALT SEAL\nPOKéMON MANSION B1F",
        "NÄCHSTES ZIEL: BASALT-SIEGEL\nPOKéMON-HAUS UG1")
    end
    if not familyInParty(game, key) then
      return tr(
        "NEXT: PREPARE PARTY\nAdd this starter family.",
        "NÄCHSTES ZIEL: TEAM\nNimm diese\nStarter-Familie mit.")
    end
    if def.trialSteps and q.trialSteps < def.trialSteps then
      return tr(
        ("NEXT: %s\nWalk there: %d/%d"):format(
          localized(def.trial), q.trialSteps, def.trialSteps),
        ("NÄCHSTES ZIEL: %s\nSchritte dort: %d/%d"):format(
          localized(def.trial), q.trialSteps, def.trialSteps))
    end
    if q.steps < def.steps then
      return tr(
        ("NEXT: WALK TOGETHER\nSteps: %d/%d"):format(q.steps, def.steps),
        ("NÄCHSTES ZIEL: GEMEINSAM GEHEN\nSchritte: %d/%d")
          :format(q.steps, def.steps))
    end
    if q.wins < def.wins then
      return tr(
        ("NEXT: TRAINER BATTLES\nWins: %d/%d"):format(q.wins, def.wins),
        ("NÄCHSTES ZIEL: TRAINERKÄMPFE\nSiege: %d/%d")
          :format(q.wins, def.wins))
    end
    return tr(
      "NEXT: RELIC KEEPER\n" .. localized(def.location),
      "NÄCHSTES ZIEL: RELIKTHÜTER\n" .. localized(def.location))
  end

  local function statusText(game, key)
    local def, q = QUESTS[key], questState(key, false)
    if not (def and q and q.assigned) then
      return tr("No relic journey\nhas answered yet.",
        "Noch hat keine\nReliktreise geantwortet.")
    end
    if key == "cyndaquil" then
      local intro = tr(
        "BASALT RELIC\fCYNDAQUIL'S family\nawakened this trail.\f",
        "BASALT-RELIKT\fFEURIGELS Familie\nweckte diese Spur.\f")
      if q.claimed then
        return intro .. ascendantTyphlosion.statusText(game)
      end
      return intro .. nextObjective(game, key)
    end
    if q.claimed then
      return tr(
        ("%s\f%s: OWNED\fThe one-time relic\njourney is complete.")
          :format(localized(def.title), rewardLabel(def)),
        ("%s\f%s: ERHALTEN\fDie einmalige\nReliktreise ist beendet.")
          :format(localized(def.title), rewardLabel(def)))
    end
    local progress = tr(
      ("Walk together: %d/%d\nTrainer wins: %d/%d")
        :format(math.min(q.steps, def.steps), def.steps,
          math.min(q.wins, def.wins), def.wins),
      ("Gemeinsame Schritte:\n%d/%d\nTrainer-Siege: %d/%d")
        :format(math.min(q.steps, def.steps), def.steps,
          math.min(q.wins, def.wins), def.wins))
    if def.trialSteps then
      progress = progress .. tr(
        ("\f%s steps:\n%d/%d"):format(
          localized(def.trial),
          math.min(q.trialSteps, def.trialSteps), def.trialSteps),
        ("\fSchritte in %s:\n%d/%d"):format(
          localized(def.trial),
          math.min(q.trialSteps, def.trialSteps), def.trialSteps))
    end
    if def.flavor then
      progress = localized(def.flavor) .. "\f" .. progress
    end
    if ready(key) then
      return localized(def.title) .. "\f" .. progress
        .. "\f" .. nextObjective(game, key)
    end
    return localized(def.title) .. "\f" .. progress
      .. "\f" .. nextObjective(game, key)
  end

  local function runtimeObjectIds(game, def)
    local out = {}
    local map = game and game.data and game.data.maps
      and game.data.maps[def.map]
    for _, obj in ipairs(map and map.objects or {}) do
      if obj.runtime and obj.owner == mod.id and obj.name == def.npc then
        out[#out + 1] = def.map .. "_obj_" .. tostring(obj.index)
      end
    end
    return out
  end

  local function ensureNpc(game, def, should)
    if not (mod.world and def.map) then return end
    local ids = runtimeObjectIds(game, def)
    if not should then
      for _, id in ipairs(ids) do mod.world:removeNpc(id) end
      return
    end
    if #ids > 0 then return end
    local ow = mod.world:overworld()
    if not (ow and ow.map and ow.map.id == def.map) then return end
    local x, y = placement.findWideRandom(ow, def.preferred)
    if not x then return end
    mod.world:spawnNpc(def.map, {
      name = def.npc, sprite = def.sprite, movement = "STAY",
      range = "DOWN", text = def.text, x = x, y = y,
    })
  end

  local function refresh(game, mapId)
    if not game then return end
    assign(game)
    for key, def in pairs(QUESTS) do
      if def.map and (not mapId or mapId == def.map) then
        local q = questState(key, false)
        ensureNpc(game, def, q and q.assigned and not q.claimed)
      end
    end
  end

  local function talk(ow, npc, game, key)
    local def, q = QUESTS[key], questState(key)
    npc.frozen = true
    npc:facePlayer(ow.player)
    local done = function() npc.frozen = false end
    if q.claimed then
      game.stack:push(require("src.render.TextBox").new(
        game, statusText(game, key), done))
      return true
    end
    if not ready(key) then
      game.stack:push(require("src.render.TextBox").new(
        game, statusText(game, key), done))
      return true
    end
    local fresh = false
    for _, stone in ipairs(rewardStones(def)) do
      fresh = megaEvolution.grantStone(stone) or fresh
    end
    q.claimed = true
    q.claimedAt = os.time()
    persist(state())
    game.stack:push(require("src.render.TextBox").new(game, tr(
      ("%s resonated with\nyour partner!\fYou obtained\n%s!\fIt was registered in\nthe MEGA STONE CASE.")
        :format(localized(def.title), rewardLabel(def)),
      ("%s reagiert mit\ndeinem Partner!\fDu erhältst\n%s!\fDer Stein wurde im\nMEGA-STEIN-KOFFER\nregistriert.")
        :format(localized(def.title), rewardLabel(def))),
      function()
        done()
        if fresh then refresh(game, def.map) end
      end))
    return true
  end

  function R.handleTalk(ow, npc, game)
    if not (ow and npc and npc.def) then return false end
    for key, def in pairs(QUESTS) do
      if def.npc and npc.def.name == def.npc then
        return talk(ow, npc, game, key)
      end
    end
    return false
  end

  mod.hooks:wrap("ui.start_menu.items", function(nextItems, game, items)
    local out = nextItems(game, items)
    assign(game)
    local s = state(false)
    local rows, anyNew = {}, false
    for _, key in ipairs(ORDER) do
      local q = s and s.quests and s.quests[key]
      if q and q.assigned then
        if not q.introSeen then anyNew = true end
        rows[#rows + 1] = {
          label = localized(QUESTS[key].title),
          right = statusRight(key),
          value = key,
        }
      end
    end
    if type(out) ~= "table" or #rows == 0 then return out end
    return mod.ui.insertBefore(out, "SAVE", {
      label = tr("RELICS", "RELIKTE"),
      right = anyNew and tr("NEW", "NEU") or nil,
      ascendantMenu = true,
      ascendantFresh = anyNew,
      ascendantLabel = tr("STARTER RELICS", "STARTER-RELIKTE"),
      ascendantOrder = 72,
      ascendantKey = "starter_relics",
      onSelect = function()
        game.stack:push((mod.ui.KantoListMenu or mod.ui.ListMenu).new(game,
          tr("STARTER RELICS", "STARTER-RELIKTE"), rows, {
            onCancel = function() end,
            onChoose = function(item)
              local q = questState(item.value)
              if not q.introSeen then
                q.introSeen = true
                persist(state())
                item.right = statusRight(item.value)
              end
              game.stack:push(require("src.render.TextBox").new(
                game, statusText(game, item.value)))
            end,
          }))
      end,
    })
  end, 268)

  mod.events:on("world.stepped", function(ev)
    local game = R.game
    if not game then return end
    local newAssignment = assign(game)
    local s, changed = state(), false
    for _, key in ipairs({ "chikorita", "totodile" }) do
      local def, q = QUESTS[key], questState(key, false)
      if q and q.assigned and not q.claimed
          and familyInParty(game, key) then
        if q.steps < def.steps then
          q.steps = q.steps + 1
          changed = true
        end
        local mapId = ev and (ev.mapId or ev.map and ev.map.id)
        if def.trialSteps and def.trialMaps
            and def.trialMaps[mapId]
            and q.trialSteps < def.trialSteps then
          q.trialSteps = q.trialSteps + 1
          changed = true
        end
      end
    end
    if changed then persist(s) end
    if newAssignment then
      local ow = mod.world and mod.world:overworld()
      refresh(game, ow and ow.map and ow.map.id)
    end
  end)

  mod.events:on("battle.ended", function(ev)
    local game = ev and ev.battle and ev.battle.game or R.game
    local battle = ev and ev.battle
    if not (game and battle and ev.result == "win") then return end
    local trainer = battle.kind == "trainer" or battle.trainer ~= nil
      or battle.oppClass ~= nil or battle.rematchTrainerClass ~= nil
      or battle.johtoTrial ~= nil or battle.postgameTier ~= nil
    if not trainer then return end
    assign(game)
    local s, changed = state(), false
    for _, key in ipairs({ "chikorita", "totodile" }) do
      local def, q = QUESTS[key], questState(key, false)
      if q and q.assigned and not q.claimed and familyInParty(game, key)
          and q.wins < def.wins then
        q.wins = q.wins + 1
        changed = true
      end
    end
    if changed then persist(s) end
  end)

  mod.events:on("pokemon.caught", function(ev)
    local game = ev and ev.game or R.game
    if not game then return end
    local key = matchingKey(ev and (ev.species
      or ev.mon and ev.mon.species))
    if key then
      local q, s = questState(key)
      if not q.assigned then
        q.assigned, q.assignedAt = true, os.time()
        persist(s)
        local ow = mod.world and mod.world:overworld()
        refresh(game, ow and ow.map and ow.map.id)
      end
    end
  end)

  mod.events:on("map.entered", function(ev)
    local game = ev and ev.game or R.game
    local mapId = ev and (ev.mapId or ev.map and ev.map.id)
    refresh(game, mapId)
  end)

  mod.events:on("save.loaded", function(ev)
    local game = ev and ev.game or R.game
    assign(game)
    local ow = mod.world and mod.world:overworld()
    refresh(game, ow and ow.map and ow.map.id)
  end)

  function R.install(game)
    R.game = game
    assign(game)
    local ow = mod.world and mod.world:overworld()
    refresh(game, ow and ow.map and ow.map.id)
  end

  R.state = state
  R.questState = questState
  R.assign = assign
  R.ready = ready
  R.nextObjective = nextObjective
  R.statusText = statusText
  R.refresh = refresh
  R.quests = QUESTS
  R.order = ORDER
  return R
end
