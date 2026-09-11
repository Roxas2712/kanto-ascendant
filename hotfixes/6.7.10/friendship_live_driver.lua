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





  local Evolution=require('src.pokemon.Evolution')
  local branches={{'PICHU','PIKACHU'},{'CLEFFA','CLEFAIRY'},{'IGGLYBUFF','JIGGLYPUFF'},{'TOGEPI','TOGETIC'},{'GOLBAT','CROBAT'},{'CHANSEY','BLISSEY'},{'EEVEE','ESPEON','day'},{'EEVEE','UMBREON','night'}}
  local function steps(n)for i=1,n do game.overworld:onStepComplete();if i%32==0 then U.wait(1)end end end
  api.followerConfig.setMode('party');api.singleFollower.setCount(1,game)
  for _,row in ipairs(branches)do
    local id,target,time=row[1],row[2],row[3] or 'day'
    local mon=Pokemon.new(game.data,id,20);local reserve=Pokemon.new(game.data,id,20)
    game.save.party={mon,reserve};mon.johtoBond=0;reserve.johtoBond=0
    U.teleport(game,'ROUTE_1',8,6,'down');api.singleFollower.refresh(game)
    check(id..' is selected follower',api.singleFollower.activeMons(game)[1].mon==mon)
    steps(31);check(id..' has 31-step remainder',mon.johtoBond==0 and mon.johtoBondWalkSteps==31)
    assert(game:writeSave());game:restoreSave(assert(SaveData.load(edition)),nil,{freshBoot=true});mon=game.save.party[1];reserve=game.save.party[2]
    check(id..' remainder saved',mon.johtoBondWalkSteps==31)
    U.teleport(game,'ROUTE_1',8,6,'down');steps(1)
    check(id..' friendship grows on native step',mon.johtoBond==1)
    check(id..' reserve unchanged',(reserve.johtoBond or 0)==0)
    steps(32);check(id..' cadence remains 32',mon.johtoBond==2)
    local options=game.mods.modOptions.kanto_ascendant;options.johto_time=time
    mon.johtoBond=99;check(id..' below threshold blocked',Evolution.pendingFor(game,mon,{kind='levelup'})==nil)
    mon.johtoBond=100;check(id..' correct branch '..target,Evolution.pendingFor(game,mon,{kind='levelup'})==target)
    check(id..' manual trigger blocked',Evolution.pendingFor(game,mon,{kind='manual'})==nil)
    local done=false
    check(id..' evolution queued',Evolution.request(game,mon,{kind='levelup'},function()done=true end)==target)
    for i=1,2400 do if mon.species==target then break end;U.tap(game,'a');U.wait(1)end
    check(id..' evolves live to '..target,mon.species==target)
    if id=='GOLBAT' or target=='UMBREON' then U.shot(game,dir..'/'..target..'.png')end
    for i=1,1200 do if done then break end;U.tap(game,'a');U.wait(1)end
    check(id..' evolution completes',done)
    assert(game:writeSave());local loaded=assert(SaveData.load(edition));check(target..' saved',loaded.party[1].species==target)
  end
  -- Existing Johto research awards party-wide walking friendship postgame.
  local first=Pokemon.new(game.data,'GOLBAT',20);local reserve=Pokemon.new(game.data,'TOGEPI',20)
  first.johtoBond=0;reserve.johtoBond=0;game.save.party={first,reserve}
  game.save.hallOfFame={{player='RED'}}
  game.save.modData.kanto_ascendant.step_clock=0
  U.teleport(game,'ROUTE_1',8,6,'down');steps(64)
  check('postgame research advances reserve',reserve.johtoBond==1)
  check('postgame selected follower retains both cadences',first.johtoBond==3)
  finish()
end
