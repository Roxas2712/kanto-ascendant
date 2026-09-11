-- Instrumented live test: seeded clue, controlled missed trace RNG, native step/battle events.
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


  U.teleport(game, "ROUTE_1", 9, 6, "down")
  local root=core.state.root(true)
  root=select(1,hoenn.planIntroduction(root,{eligible=true,mapId="ROUTE_1",registeredFamilies={"POOCHYENA"},chanceRoll=1,familyRoll=1,token="live-route1"}))
  core.state.replace(root)
  check("test clue created",core.state.status("hoenn","POOCHYENA")=="trace")
  local function pity()return core.State and core.State.sightingPity(core.state.root(false),"hoenn","POOCHYENA") end
  local originalCommit=hoenn.commitStarted
  hoenn.commitStarted=function(...)
    local a,b,c=originalCommit(...)
    print("LIVE_COMMIT",tostring(b),tostring(c))
    local f=assert(io.open(dir.."/commit-results.txt","a"));f:write(tostring(b).." "..tostring(c).."\n");f:close()
    return a,b,c
  end
  local lastBattle
  local originalNewWild=BattleState.newWild
  BattleState.newWild=function(...)lastBattle=originalNewWild(...);return lastBattle end
  local grass
  for y=1,30 do for x=1,18 do
    if game.overworld.map:isGrassCell(x,y) then grass=grass or {x=x,y=y} end
  end end
  assert(grass,"no grass cell")
  U.teleport(game,"ROUTE_1",grass.x,grass.y,"down")
  local originalRandom=love.math.random
  love.math.random=function(a,b)
    if a==1 and b==10000 then return 1 end
    return originalRandom(a,b)
  end
  for i=1,50 do
    U.teleport(game,"ROUTE_1",grass.x,grass.y,"down")
    check("mod save API bound before encounter "..i,game.mods.modSave==game.save.modData)
    local before=core.state.root(false)
    lastBattle=nil
    for j=1,1000 do
      game.overworld.wildEncounterGraceSteps=0
      game.overworld:onStepComplete()
      if lastBattle then break end
      U.wait(1)
    end
    local battle=assert(lastBattle,"no natural step battle")
    local enc={species=battle.enemy.mon.species}
    U.wait(3)
    local live=waitFor(function()if battle.phase=="menu" then return true end;U.tap(game,"a") end,1200)
    local Json=require("src.link.Json")
    local f=assert(io.open(dir.."/encounter-"..i..".json","w"))
    f:write(Json.encode({before=before,after=core.state.root(false),species=enc.species,kind=battle.kind,source=battle.encounterSource or "NIL",discovery=battle.kaHoennDiscoveryFamily or "NIL"}));f:close()
    check("live wild battle "..i,live)
    check("mod save API bound after encounter "..i,game.mods.modSave==game.save.modData)
    check("engine omits optional source "..i,battle.encounterSource==nil)
    if i<50 then
      check("natural encounter increments pity "..i,core.state.sightingPity("hoenn","POOCHYENA")==i)
      check("controlled RNG misses until deadline "..i,enc.species~="POOCHYENA")
    else
      check("guaranteed exact species at encounter 50",enc.species=="POOCHYENA")
      check("trace battle committed",battle.kaHoennDiscoveryFamily=="POOCHYENA")
    end
    if i==1 or i==25 or i==50 then U.shot(game,dir.."/battle-"..i..".png") end
    battle.result="run";battle:finish();dismissToWorld()
    if i==25 then
      assert(game:writeSave())
      local loaded=assert(SaveData.load(edition))
      game:restoreSave(loaded,nil,{freshBoot=true})
      check("pity survives disk save/load",core.state.sightingPity("hoenn","POOCHYENA")==25)
    end
  end
  finish()
end
