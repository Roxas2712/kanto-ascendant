-- One authoritative next-objective tracker for the Atlas and Journal.
--
-- The main path deliberately ends with the Silver/Kris/Gold trial. Battle
-- Factory and S.S. Anne clears remain visible prestige goals, but never block
-- the first or a later Ascendant Cycle.

return function(mod, opts)
  opts = opts or {}
  local i18n = opts.i18n
  local postgame = assert(opts.postgame, "postgame controller missing")
  local postgameData = opts.postgameData or {}
  local ascendant = assert(opts.ascendant, "ascendant controller missing")
  local ascendantData = opts.ascendantData or {}
  local johtoResearch = opts.johtoResearch
  local johtoData = opts.johtoData or {}
  local johtoMasters = opts.johtoMasters
  local grandTour = opts.grandTour
  local ascendantTyphlosion = opts.ascendantTyphlosion
  local starterRelicQuests = opts.starterRelicQuests
  local signalsHub = opts.signalsHub
  local Q = { game = nil }

  local function tr(en, de)
    return i18n and i18n.text(en, de) or en
  end

  local function localized(row)
    if type(row) ~= "table" then return row end
    return tr(row.en or row.de or "", row.de or row.en or "")
  end

  local function countKeys(bucket, rows, field)
    local count = 0
    bucket = type(bucket) == "table" and bucket or {}
    for _, row in ipairs(rows or {}) do
      if bucket[row[field or "key"]] then count = count + 1 end
    end
    return count
  end

  local function countTrue(bucket)
    local count = 0
    for _, value in pairs(type(bucket) == "table" and bucket or {}) do
      if value then count = count + 1 end
    end
    return count
  end

  local function row(id, title, location, current, target, detail)
    return {
      id = id,
      title = title,
      location = location,
      current = current,
      target = target,
      detail = detail,
    }
  end

  local function replacePlain(text, needle, replacement)
    text, needle = tostring(text or ""), tostring(needle or "")
    if needle == "" then return text end
    local out, from = {}, 1
    while true do
      local first, last = text:find(needle, from, true)
      if not first then
        out[#out + 1] = text:sub(from)
        return table.concat(out)
      end
      out[#out + 1] = text:sub(from, first - 1)
      out[#out + 1] = replacement
      from = last + 1
    end
  end

  local function speciesKnown(game, species)
    local pokedex = game and game.save and game.save.pokedex or {}
    local seen = type(pokedex.seen) == "table" and pokedex.seen or {}
    local owned = type(pokedex.owned) == "table" and pokedex.owned or {}
    return seen[species] == true or owned[species] == true
  end

  local function signalText(game, objective, value, fallback)
    local text = tostring(value or fallback or "")
    local species = objective and objective.species
    if species and not speciesKnown(game, species) then
      text = replacePlain(text, species, "???")
    end
    return text
  end

  local function signalsObjective(game)
    game = game or Q.game
    if not (signalsHub and type(signalsHub.objective) == "function") then
      return nil
    end
    local source = signalsHub.objective(game)
    if type(source) ~= "table" then return nil end

    local location = source.location
    if type(signalsHub.atlasLocations) == "function" then
      local locations = signalsHub.atlasLocations(game)
      if type(locations) == "table" and locations[location] then
        location = locations[location]
      end
    end

    local current = math.max(0,
      math.floor(tonumber(source.current) or 0))
    local target = tonumber(source.total)
    if target == nil then target = tonumber(source.target) end
    if target ~= nil then
      target = math.max(0, math.floor(target))
      current = math.min(current, target)
    end
    return row("signals:" .. tostring(source.key or source.id or "next"),
      signalText(game, source, source.title,
        tr("SIGNAL OBJECTIVE", "SIGNALZIEL")),
      signalText(game, source, location, tr("KANTO", "KANTO")),
      current, target,
      signalText(game, source, source.detail,
        tr("Consult the receiver.", "Prüfe den Empfänger.")))
  end

  local function optionEnabled(key)
    return not (mod.options and mod.options.get
      and mod.options:get(key) == false)
  end

  local function johtoEnabled()
    if not johtoResearch then return false end
    if type(johtoResearch.enabled) == "function" then
      return johtoResearch.enabled()
    end
    return johtoResearch.enabled ~= false
  end

  local function mapLocation(map)
    local names = {
      POWER_PLANT = { en = "POWER PLANT", de = "KRAFTWERK" },
      SILPH_CO_11F = { en = "SILPH CO. 11F", de = "SILPH CO. 11F" },
      POKEMON_TOWER_7F = {
        en = "POKéMON TOWER 7F", de = "POKéMON-TURM 7F",
      },
      VIRIDIAN_GYM = {
        en = "VIRIDIAN GYM", de = "VERTANIA-ARENA",
      },
    }
    local known = names[map]
    if known then return tr(known.en, known.de) end
    return tostring(map or tr("KANTO", "KANTO")):gsub("_", " ")
  end

  local function johtoProgress()
    local s = johtoResearch and johtoResearch.state
      and johtoResearch.state(false) or {}
    local starters = 0
    for _, key in ipairs(johtoData.starterOrder or {}) do
      if s.starters and s.starters[key] then starters = starters + 1 end
    end
    local rewards = johtoResearch and johtoResearch.rewardCount
      and johtoResearch.rewardCount(s) or 0
    return s, starters, rewards
  end

  local function mastersProgress()
    local s = johtoMasters and johtoMasters.state
      and johtoMasters.state(false) or {}
    return math.max(0, math.floor(tonumber(s.clears) or 0))
  end

  local function mainObjective(game)
    game = game or Q.game
    if not (game and postgame.hasHallOfFame(game.save)) then
      return row("champion",
        tr("BECOME CHAMPION", "WERDE CHAMP"),
        tr("INDIGO PLATEAU", "INDIGO-PLATEAU"), 0, 1,
        tr("Defeat the Pokémon\nLeague and enter the\nHall of Fame.",
          "Besiege die POKéMON-\nLIGA und betrete die\nRuhmeshalle."))
    end

    local p = postgame.state()
    local phase = postgame.phaseFor(p, game.save)
    if phase == "master_gyms" then
      local n = countKeys(p.masterWins, postgameData.gyms)
      return row("master_gyms",
        tr("MASTER CIRCUIT", "MEISTER-ZIRKEL"),
        tr("KANTO GYMS", "KANTO-ARENEN"), n, 8,
        tr("Defeat all eight\nMASTER Leaders.",
          "Besiege alle acht\nMEISTER-Leiter."))
    elseif phase == "apex_elite" then
      return row("apex_elite",
        tr("APEX ELITE FOUR", "APEX-TOP VIER"),
        tr("INDIGO PLATEAU", "INDIGO-PLATEAU"),
        countTrue(p.eliteApexWins) + (p.apexChampion and 1 or 0), 5,
        tr("Clear Lorelei, Bruno,\nAgatha, Lance and the\nAPEX Champion.",
          "Besiege Lorelei, Bruno,\nAgatha, Siegfried und\nden APEX-Champ."))
    elseif phase == "legend_hunt" then
      local caught = postgame.events and postgame.events.caughtLegendCount
        and postgame.events.caughtLegendCount(p, game.save) or 0
      local enabled = postgame.events and postgame.events.enabledLegendCount
        and postgame.events.enabledLegendCount() or 0
      return row("legend_hunt",
        tr("AWAKEN THE SKY PAIR", "WECKE DAS HIMMELSPAAR"),
        tr("JOURNAL / KANTO", "JOURNAL / KANTO"), caught, enabled,
        tr("Catch the birds and\nbeasts, then find\nLUGIA and HO-OH.",
          "Fange Vögel und Bestien,\ndann finde LUGIA und\nHO-OH."))
    elseif phase == "crown_gyms" then
      local n = countKeys(p.crownWins, postgameData.gyms)
      return row("crown_gyms",
        tr("CROWN CIRCUIT", "KRONEN-ZIRKEL"),
        tr("KANTO GYMS", "KANTO-ARENEN"), n, 8,
        tr("Defeat all eight\nlevel-100 CROWN Leaders.",
          "Besiege alle acht\nKRONEN-Leiter auf\nLevel 100."))
    elseif phase == "crown_elite" then
      return row("crown_elite",
        tr("CROWN ELITE FOUR", "KRONEN-TOP VIER"),
        tr("INDIGO PLATEAU", "INDIGO-PLATEAU"),
        countTrue(p.eliteCrownWins) + (p.crownChampion and 1 or 0), 5,
        tr("Win Kanto's final\nCROWN League.",
          "Gewinne Kantos letzte\nKRONEN-Liga."))
    end

    local a = ascendant.evaluateAchievements(game)
    local research = ascendant.activeResearch(a)
    if research then
      local value = ascendant.metricValue(research.metric, game, a)
      return row("research:" .. research.id,
        localized(research.title),
        tr("OAK'S LAB", "EICHS LABOR"),
        math.min(value, research.target), research.target,
        localized(research.task))
    end

    local quests = ascendant.questDoneCount(a)
    if quests < 8 then
      return row("leader_quests",
        tr("LEADER MISSIONS", "LEITER-MISSIONEN"),
        tr("KANTO GYMS", "KANTO-ARENEN"), quests, 8,
        tr("Complete every Gym\nLeader's personal\nmission.",
          "Beende die persönliche\nMission jedes\nArena-Leiters."))
    end

    if johtoEnabled() then
      local jr, starters, rewards = johtoProgress()
      if not jr.finalReward then
        local target = #(johtoData.rewards or {})
        if starters < 3 then
          return row("johto_starters",
            tr("ELM'S STARTER TRIALS", "LINDS STARTER-PRÜFUNGEN"),
            tr("CERULEAN / CELADON / CINNABAR",
              "AZURIA / PRISMANIA / ZINNOBER"),
            starters, 3,
            tr("Win all three starter\ntrials to open Elm's\nresearch tracks.",
              "Gewinne alle drei\nStarter-Prüfungen für\nLinds Forschungsreihen."))
        elseif rewards >= target then
          return row("johto_finale",
            tr("ELM'S FINAL SPECIMEN", "LINDS LETZTES EXEMPLAR"),
            tr("FIELD TRAINER REMATCH", "TRAINER-REVANCHE"),
            0, 1,
            tr("Win one more field\nrematch to complete every\ntrack and release LARVITAR.",
              "Gewinne eine weitere\nTrainer-Revanche, um\nLARVITAR freizugeben."))
        end
        return row("johto_research",
          tr("ELM'S KANTO RESEARCH", "LINDS KANTO-FORSCHUNG"),
          tr("OAK'S LAB / ROUTE 5", "EICHS LABOR / ROUTE 5"),
          rewards, target,
          tr("Win field rematches;\neach trainer class reveals\nits own Johto specimen.",
            "Gewinne Trainer-\nRevanchen; jede Klasse\nenthüllt eine Johto-Art."))
      end
    end

    if optionEnabled("rocket_story")
        and a.rocketStage < #(ascendantData.rocket or {}) then
      local operation = ascendantData.rocket[a.rocketStage + 1]
      return row("rocket",
        tr("ROCKET RESURGENCE", "ROCKET-RÜCKKEHR"),
        mapLocation(operation and operation.map),
        a.rocketStage, #(ascendantData.rocket or {}),
        tr("Stop the next Rocket\noperation.",
          "Stoppe die nächste\nRocket-Operation."))
    end

    if optionEnabled("grand_tournament") and a.tournament.wins < 1 then
      return row("frontier",
        tr("ASCENDANT FRONTIER", "ASCENDANT-FRONTIER"),
        tr("INDIGO PLATEAU", "INDIGO-PLATEAU"),
        a.tournament.wins, 1,
        tr("Win one three-round\nFrontier bracket.",
          "Gewinne ein Turnier\nmit drei Runden."))
    end

    if optionEnabled("legend_mew") and not a.mewCaught then
      local locations = {
        tr("OAK'S LAB", "EICHS LABOR"),
        tr("MR. FUJI / LAVENDER", "MR. FUJI / LAVANDIA"),
        tr("CINNABAR LAB", "ZINNOBER-LABOR"),
        tr("ROUTE 24", "ROUTE 24"),
      }
      return row("mew",
        tr("ORIGIN INVESTIGATION", "URSPRUNGSFORSCHUNG"),
        locations[math.min(4, a.mewStage + 1)],
        a.mewStage, 4,
        tr("Follow Oak, Fuji and\nthe Cinnabar records\nto MEW.",
          "Folge Eich, Fuji und\nden Zinnober-Akten\nzu MEW."))
    end

    local clears = mastersProgress()
    local baseline = a.cycle > 0
      and math.max(0, math.floor(
        tonumber(a.cycleJohtoMastersStartClears) or 0)) or 0
    if clears <= baseline then
      return row("gold",
        tr("FINAL MAIN BATTLE: GOLD", "LETZTER HAUPTKAMPF: GOLD"),
        tr("INDIGO PLATEAU LOBBY", "INDIGO-PLATEAU-LOBBY"),
        clears - baseline, 1,
        tr("Defeat SILVER, KRIS\nand finally GOLD with\nthe Bag sealed.",
          "Besiege SILBER, KRIS\nund zuletzt GOLD bei\ngesperrtem Beutel."))
    end

    if ascendant.newGamePlusReady
        and ascendant.newGamePlusReady(game) then
      return row("new_game_plus",
        tr("ASCENDANT CYCLE READY", "ASCENDANT-ZYKLUS BEREIT"),
        tr("HALL OF FAME", "RUHMESHALLE"), 1, 1,
        tr("Speak to Oak's Steward\nto begin New Game+.",
          "Sprich mit Eichs Hüter,\num New Game+ zu starten."))
    end

    return row("review",
      tr("REVIEW THE JOURNAL", "PRÜFE DAS JOURNAL"),
      tr("ASCENDANT MENU", "ASCENDANT-MENÜ"), 0, 1,
      tr("One required record is\nstill incomplete.",
        "Ein Pflicht-Eintrag ist\nnoch unvollständig."))
  end

  local function objectiveText(game)
    local objective = mainObjective(game)
    local progress = ""
    if objective.target then
      progress = ("\n%s: %d/%d"):format(
        tr("PROGRESS", "FORTSCHRITT"),
        math.max(0, objective.current or 0), objective.target)
    end
    return tr("NEXT MAIN OBJECTIVE", "NÄCHSTES HAUPTZIEL")
      .. "\n" .. objective.title
      .. "\f" .. tr("LOCATION: ", "ORT: ") .. objective.location
      .. progress
      .. "\f" .. objective.detail
  end

  local function signalsObjectiveText(game)
    local objective = signalsObjective(game)
    if not objective then return nil end
    local progress = ""
    if objective.target then
      progress = ("\n%s: %d/%d"):format(
        tr("PROGRESS", "FORTSCHRITT"),
        objective.current, objective.target)
    end
    return tr("OPTIONAL SIGNAL\nGOAL", "FREIWILLIGES\nSIGNALZIEL")
      .. "\n" .. objective.title
      .. "\f" .. tr("LOCATION: ", "ORT: ") .. objective.location
      .. progress
      .. "\f" .. objective.detail
  end

  local function prestigeText()
    local p = postgame.state(false)
    local text
    if not (p and p.crownChampion) then
      text = tr(
        "OPTIONAL PRESTIGE\nLocked until the CROWN\nChampion is defeated.",
        "OPTIONALES PRESTIGE\nGesperrt bis zum Sieg\nüber den KRONEN-Champ.")
    else
      local tour = grandTour and grandTour.state
        and grandTour.state(false) or {}
      local factory = tour.factory or {}
      local cruise = tour.cruise or {}
      text = tr("OPTIONAL PRESTIGE", "OPTIONALES PRESTIGE")
        .. ("\f%s\n%s: %d\n%s"):format(
          tr("BATTLE FACTORY", "KAMPFFABRIK"),
          tr("CLEARS", "SIEGE"), factory.wins or 0,
          tr("INDIGO PLATEAU LOBBY", "INDIGO-PLATEAU-LOBBY"))
        .. ("\fS.S. ANNE GRAND TOUR\n%s: %d\n%s"):format(
          tr("CLEARS", "SIEGE"), cruise.clears or 0,
          tr("VERMILION HARBOR", "ORANIA-HAFEN"))
    end
    local secret = ascendantTyphlosion and ascendantTyphlosion.state
      and ascendantTyphlosion.state(false)
    if secret and secret.clueSeen then
      local progress = ascendantTyphlosion.ownedCount
        and ascendantTyphlosion.ownedCount(Q.game) or 0
      text = text .. ("\f%s\n%s\n%s: %d/251"):format(
        secret.unlocked
          and tr("ASCENDANT TYPHLOSION", "ASCENDANT-TORNUPTO") or "???",
        secret.unlocked
          and tr("BASALT CORE: AWAKE", "BASALT-KERN: WACH")
          or tr("POKéMON MANSION B1F", "POKéMON-HAUS UG1"),
        tr("POKéDEX", "POKéDEX"), progress)
    end
    local relicState = starterRelicQuests and starterRelicQuests.state
      and starterRelicQuests.state(false)
    for _, key in ipairs(
        starterRelicQuests and starterRelicQuests.order or {}) do
      local q = relicState and relicState.quests
        and relicState.quests[key]
      local def = starterRelicQuests.quests[key]
      if q and q.assigned and not q.claimed then
        if key == "cyndaquil" then
          text = text .. "\f" .. starterRelicQuests.nextObjective(Q.game, key)
          break
        end
        text = text .. ("\f%s\n%s %d/%d  %s %d/%d\n%s"):format(
          tr("STARTER RELIC", "STARTER-RELIKT"),
          tr("STEPS", "SCHRITTE"), math.min(q.steps, def.steps), def.steps,
          tr("WINS", "SIEGE"), math.min(q.wins, def.wins), def.wins,
          tr("ASCENDANT MENU", "ASCENDANT-MENÜ"))
        if def.trialSteps then
          text = text .. ("\f%s\n%s %d/%d"):format(
            key == "chikorita"
              and tr("VIRIDIAN FOREST", "VERTANIA-WALD")
              or tr("SEAFOAM ISLANDS", "SEESCHAUMINSELN"),
            tr("TRIAL STEPS", "PRÜFSCHRITTE"),
            math.min(q.trialSteps or 0, def.trialSteps), def.trialSteps)
        end
        text = text .. "\f" .. starterRelicQuests.nextObjective(Q.game, key)
        break
      end
    end
    return text
  end

  function Q.install(game)
    Q.game = game
  end

  Q.nextObjective = mainObjective
  Q.objectiveText = objectiveText
  Q.signalsObjective = signalsObjective
  Q.signalsObjectiveText = signalsObjectiveText
  Q.prestigeText = prestigeText
  Q.statusText = function(game)
    local text = objectiveText(game)
    local signals = signalsObjectiveText(game)
    if signals then text = text .. "\f" .. signals end
    return text .. "\f" .. prestigeText()
  end
  Q.setSignalsHub = function(controller) signalsHub = controller end
  return Q
end
