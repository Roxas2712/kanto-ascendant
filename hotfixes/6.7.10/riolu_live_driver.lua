-- Live Riolu QA: disposable gift receipt, native step events and evolution UI.
return function(game)
  local U = dofile(assert(os.getenv("KA_TEST_UTIL"),
    "KA_TEST_UTIL is required"))
  local SaveData = require("src.core.SaveData")
  local Runtime = require("src.mods.Runtime")
  local Pokemon = require("src.pokemon.Pokemon")
  local BattleState = require("src.battle.BattleState")
  local dir = assert(os.getenv("SHOT_DIR"), "SHOT_DIR is required")
  local edition = assert(os.getenv("POKEPORT_VERSION"),
    "POKEPORT_VERSION is required")
  local api = assert(game.mods and game.mods.exports
    and game.mods.exports.kanto_ascendant, "KASC exports missing")
  local core = assert(api.discoveryCore)
  local discovery = assert(core.hoenn)
  local hoenn = assert(core.Hoenn)
  local access = assert(api.hoennFieldAccess)
  local journey = assert(api.legacyJourney)
  local starters = assert(api.legacyStarters)
  local rules = assert(api.generationRules)
  local acquisition = assert(api.hoennAcquisition67Data)
  local presentation = assert(api.hoennTracePresentation67)
  local prizes = assert(api.hoennTournamentEncounters67)
  local language = type(api.language) == "function" and api.language() or "unknown"

  local pass, fail, report = 0, 0, {
    "scope=PUBLIC-RELEASE-HOENN-DISCOVERY",
    "edition=" .. edition,
    "language=" .. language,
    "authority=production-discovery-trainer-growth-legacy-ball-tournament",
    "combat=deterministic-caught-or-win-after-live-HUD",
  }
  local function check(label, value)
    value = value and true or false
    if value then pass = pass + 1 else fail = fail + 1 end
    report[#report + 1] = (value and "PASS\t" or "FAIL\t") .. label
    U.log(value and "PASS" or "FAIL", label)
    return value
  end
  local function finish()
    report[#report + 1] = "pass=" .. pass
    report[#report + 1] = "fail=" .. fail
    local output = assert(io.open(dir .. "/driver_result.txt", "wb"))
    output:write(table.concat(report, "\n"), "\n")
    output:close()
    love.event.quit(fail == 0 and 0 or 1)
  end
  local function waitFor(predicate, frames)
    for _ = 1, frames or 1200 do
      local value = predicate()
      if value then return value end
      U.wait(1)
    end
  end
  local function dismissToWorld(frames)
    return waitFor(function()
      if game.stack:top() == game.overworld then return true end
      U.tap(game, "a")
    end, frames or 1200)
  end
  local function waitMap(mapId, frames)
    return waitFor(function()
      return game.overworld and game.overworld.map
        and game.overworld.map.id == mapId
        and game.stack:top() == game.overworld
    end, frames or 900)
  end
  local function setGerman()
    game.save.options = game.save.options or {}
    game.save.options.modOptions = game.save.options.modOptions or {}
    local values = game.save.options.modOptions.kanto_ascendant or {}
    game.save.options.modOptions.kanto_ascendant = values
    values.language = "de"
    values.hoenn_encounters = true
    game.mods.modOptions.kanto_ascendant = values
    Runtime.emit("mod.options_changed", {
      game=game, mod="kanto_ascendant", key="language", value="de",
    })
    game:applyOptions(game.save.options)
  end

  local slot = "public_release_hoenn_discovery_" .. edition
  assert(SaveData.setActiveSlot(edition, slot) == slot)
  local source = SaveData.newGame(game:bootConfig())
  game.save = source
  game:adoptSave(source)
  Runtime.emit("save.created", { game=game, save=source })
  source.player.name, source.player.rival = "RED", "BLUE"
  source.party = { Pokemon.new(game.data, "PIKACHU", 50) }
  source.hallOfFame = { { player="RED", source="hoenn-discovery-e2e" } }
  local current, beginWhy = journey.archive.beginJourney(source, {
    pact="public_release_hoenn_discovery",
    runRules=journey.archive.safeRunRulesSnapshot(source),
  })
  check("completed source run starts a Legacy journey", current ~= nil)
  if not current then
    report[#report + 1] = "diagnostic=" .. tostring(beginWhy)
    finish(); return
  end
  local fresh = journey.startFreshGame(game)
  check("Legacy journey creates a fresh run", type(fresh) == "table")
  setGerman()
  assert(journey.archive.setAvatar(game.save, "RED"))
  local run = assert(journey.state(game.save))
  game.save.flags = game.save.flags or {}
  game.save.flags.EVENT_OAK_ASKED_TO_CHOOSE_MON = true
  game.save.flags.KA_LEGACY_RIVAL_BALL_TAKEN = true
  run.rivalBallTaken = true
  check("fresh Legacy run receives its Kanto partner",
    starters.choose(game, "BULBASAUR", "balanced", "catalog", "catalog") == true)
  local beyondChanged, beyondWhy = api.beyondKanto.activate(game, {
    decision="public_hoenn_discovery_e2e",
  })
  check("Beyond Kanto data boundary is active for trainer growth",
    (beyondChanged == true or beyondWhy == "already-active")
      and api.beyondKanto.isActive(game.save) == true)
  local generation = assert(rules.state(game, true, false))
  generation.unlockedEpoch, generation.selectedMode = 6, "auto"
  game.save.options.modOptions.kanto_ascendant.battle_generation_mode = "auto"
  check("Gen III species are active", rules.syncData(game) == true
    and rules.shouldUseEpoch(game, 3, true) == true)




  local edge=assert(api.backendGiftSpecies67.rioluEvolution)
  local E=api.eventArchive
  local profile='backend_shiny_egg_0447'
  game.save.party={}
  local mon=assert(E.deliverGift(game,profile,'QA RIOLU',{version=1,digest=string.rep('a',64),campaignId='qa',eventId='qa-riolu',profileId=profile,buildId='local-test'}))
  U.teleport(game,"ROUTE_1",8,6,"down")
  local function steps(n)
    for i=1,n do game.overworld:onStepComplete();if i%64==0 then U.wait(1) end end
  end
  steps(64);check("egg does not gain friendship",(mon.johtoBond or 0)==0)
  api.daycare.hatchEgg(game,mon)
  check("gift hatched",not mon.isEgg and mon.species==edge.from and mon.hp>0)
  mon.johtoBond=0;mon._kascRioluBondSteps=0
  local hp=mon.hp;mon.hp=0;steps(64);check("fainted Riolu excluded",mon.johtoBond==0 and mon._kascRioluBondSteps==0);mon.hp=hp
  steps(63);check("63-step remainder",mon.johtoBond==0 and mon._kascRioluBondSteps==63)
  assert(game:writeSave());game:restoreSave(assert(SaveData.load(edition)),nil,{freshBoot=true});mon=game.save.party[1]
  check("remainder survives native save/load",mon._kascRioluBondSteps==63)
  U.teleport(game,"ROUTE_1",8,6,"down")
  steps(1);check("64th native step adds friendship",mon.johtoBond==1 and mon._kascRioluBondSteps==0)
  steps(64*99);check("6400 native steps reach friendship 100",mon.johtoBond==100)
  assert(game:writeSave());game:restoreSave(assert(SaveData.load(edition)),nil,{freshBoot=true});mon=game.save.party[1]
  check("friendship 100 survives save/load",mon.johtoBond==100)
  U.teleport(game,"ROUTE_1",8,6,"down")
  local Evolution=require('src.pokemon.Evolution')
  local options=game.mods.modOptions.kanto_ascendant
  options.johto_time='night';check("no evolution at night",Evolution.pendingFor(game,mon,{kind='levelup'})==nil)
  options.johto_time='day';check("day level-up qualifies",Evolution.pendingFor(game,mon,{kind='levelup'})==edge.to)
  check("walking alone does not evolve",Evolution.pendingFor(game,mon,{kind='manual'})==nil)
  mon.level=2
  local done=false
  check("native evolution queued",Evolution.request(game,mon,{kind='levelup'},function()done=true end)==edge.to)
  for i=1,2400 do
    if mon.species==edge.to then break end
    U.tap(game,'a');U.wait(1)
  end
  check("live evolution reaches Lucario",mon.species==edge.to)
  U.shot(game,dir..'/lucario-evolution.png')
  for i=1,1200 do if done then break end;U.tap(game,'a');U.wait(1) end
  check("evolution completes",done)
  check("gift remains valid",E.battleCompatibleGift(mon))
  assert(game:writeSave());local loaded=assert(SaveData.load(edition))
  check("Lucario saved",loaded.party[1].species==edge.to and loaded.party[1].johtoBond==100)
  finish()
end
