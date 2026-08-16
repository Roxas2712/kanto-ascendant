-- Installed-package acceptance for the two remaining Legacy Journey release
-- surfaces.  The same frozen harness runs in two isolated identities:
--
--   * pact4x4: every Pact x Bank rule pair crosses the real archive/new-game
--     transaction, partner choice, save/reload and policy gate;
--   * three_journeys: three uninterrupted New Game+ hand-offs retain their
--     exact Pokemon/item/money archive while RED -> BLUE -> GREEN remains the
--     active avatar sequence.
--
-- Champion progress and the already-claimed rival ball are deliberately
-- staged inputs: their physical stories have separate package drivers.  This
-- driver never writes archive/current/Bank state and never calls seedNewSave
-- or markRunStarted.  beginJourney, the engine's save.new_game hook,
-- legacyStarters.choose and ordinary save/load own every tested transition.

return function(game)
  local U = dofile(os.getenv("KA_TEST_UTIL") or "tests/drivers/util.lua")
  local SaveData = require("src.core.SaveData")
  local GameVersion = require("src.core.GameVersion")
  local Pokemon = require("src.pokemon.Pokemon")
  local TextBox = require("src.render.TextBox")
  local mode = assert(os.getenv("KA_LEGACY_ACCEPTANCE_MODE"),
    "KA_LEGACY_ACCEPTANCE_MODE is required")
  local identity = assert(os.getenv("POKEPORT_IDENTITY"),
    "POKEPORT_IDENTITY is required")
  local dir = assert(os.getenv("SHOT_DIR"), "SHOT_DIR is required")
  local version = GameVersion.get()
  local expectedIdentity = mode == "pact4x4"
      and ("ka-legacy-pact-4x4-%s-package"):format(version)
    or mode == "three_journeys"
      and "ka-legacy-three-journeys-package" or nil
  assert(expectedIdentity and identity == expectedIdentity,
    "refusing a non-isolated Legacy package identity")
  assert(mode ~= "three_journeys" or version == "red",
    "connected three-Journey receipt is authored for Red edition")

  local api = assert(game.mods and game.mods.exports
      and game.mods.exports.kanto_ascendant,
    "Kanto Ascendant export is missing")
  local journey = assert(api.legacyJourney, "Legacy Journey export missing")
  local archive = assert(journey.archive, "Legacy archive export missing")
  local starters = assert(api.legacyStarters, "Legacy partner export missing")
  local checks = 0

  local function check(label, value, detail)
    if not value then
      error("FAIL: " .. label .. (detail and (" (" .. detail .. ")") or ""), 2)
    end
    checks = checks + 1
    U.log("PASS", label, detail or "")
    return value
  end

  local function clearUi()
    while game.stack:top() and game.stack:top() ~= game.overworld do
      game.stack:pop()
    end
  end

  local function shotHint(stem)
    clearUi()
    local box = TextBox.new(game, journey.bankPolicyHint(game.save))
    game.stack:push(box)
    U.wait(35)
    check(stem .. " policy capture", U.shot(game, dir .. "/" .. stem .. ".png"))
    clearUi()
  end

  local function restoreFresh(index)
    local fresh = SaveData.newGame(game:bootConfig())
    local run = fresh.modData and fresh.modData.kanto_ascendant
      and fresh.modData.kanto_ascendant.legacy_journey
    check(("cycle %d crossed the engine save.new_game hook"):format(index),
      type(run) == "table" and run.cycle == index and run.runId ~= nil)
    fresh.player.id = 64500 + index
    fresh.player.name = "LEGACY" .. tostring(index)
    fresh.player.rival = "RIVAL" .. tostring(index)
    fresh.pcItems = {}
    game:restoreSave(fresh, false)
    U.wait(12)
    clearUi()
    return game.save
  end

  local function roundTrip(index)
    check(("cycle %d wrote through the real save boundary"):format(index),
      game:writeSave())
    local loaded = assert(SaveData.load(), "Legacy package save did not reload")
    game:restoreSave(loaded, false)
    U.wait(12)
    clearUi()
    local run = assert(journey.state(game.save), "reloaded Legacy state missing")
    check(("cycle %d survived save/reload"):format(index),
      run.cycle == index and run.runId == archive.current().runId)
    return run
  end

  local function choosePartner(index, avatar, species)
    check(("cycle %d selects %s through archive avatar API"):format(index, avatar),
      archive.setAvatar(game.save, avatar))
    local run = assert(game.save.modData
      and game.save.modData.kanto_ascendant
      and game.save.modData.kanto_ascendant.legacy_journey)
    -- STAGED_POST_RIVAL_BALL_PRE_PARTNER_BOUNDARY: the rival-ball animation
    -- and laboratory navigation are independently covered.  The actual Oak
    -- choice and its save/archive mirror below remain production code.
    game.save.flags = game.save.flags or {}
    game.save.flags.EVENT_OAK_ASKED_TO_CHOOSE_MON = true
    game.save.flags.KA_LEGACY_RIVAL_BALL_TAKEN = true
    run.rivalBallTaken = true
    local ok, mon = starters.choose(game, species, "balanced", "catalog",
      "catalog")
    check(("cycle %d crosses real legacyStarters.choose"):format(index),
      ok == true and type(mon) == "table" and mon.species == species)
    check(("cycle %d partner is mirrored into external archive"):format(index),
      archive.current().partnerChosen == true
        and archive.current().partnerSpecies == species)
    mon.nickname = ("LIFE%02d"):format(index)
    return mon
  end

  local function stageChampion(index, potion, money)
    game.save.inventory = { POTION = potion }
    game.save.bagOrder = { "POTION" }
    game.save.pcItems = {}
    game.save.money = money
    game.save.flags = game.save.flags or {}
    game.save.flags.EVENT_BEAT_CHAMPION_RIVAL = true
    game.save.hallOfFame = { { cycle = index, team = game.save.party } }
    check(("cycle %d owns a current-run Hall of Fame"):format(index),
      archive.isEligible(game.save))
    check(("cycle %d outgoing source is saved before archive"):format(index),
      game:writeSave())
  end

  local function begin(index, pact, policy, avatar)
    local current, stored = archive.beginJourney(game.save, {
      pact = pact, bankPolicy = policy, playerAvatar = avatar,
      runRules = archive.safeRunRulesSnapshot(game.save),
    })
    check(("cycle %d crosses real archive.beginJourney"):format(index),
      type(current) == "table" and type(stored) == "table")
    check(("cycle %d persists exact %s/%s"):format(index, pact, policy),
      current.pact == pact and current.bankPolicy == policy
        and stored.hallOfLegacy[index].pact == pact
        and stored.hallOfLegacy[index].bankPolicy == policy)
    return current, stored
  end

  local badges = {
    "BOULDERBADGE", "CASCADEBADGE", "THUNDERBADGE", "RAINBOWBADGE",
  }

  local function verifyPolicy(index, pact, policy)
    local allowed, why, actualPolicy, actualPact = archive.bankAccess(game.save)
    check(("%s/%s waits for the real partner"):format(pact, policy),
      allowed == false and why == "partner"
        and actualPolicy == policy and actualPact == pact)
    choosePartner(index, ({ "RED", "BLUE", "GREEN" })[((index - 1) % 3) + 1],
      ({ "BULBASAUR", "CHARMANDER", "SQUIRTLE" })[((index - 1) % 3) + 1])
    allowed, why, actualPolicy, actualPact = archive.bankAccess(game.save)
    check(("%s/%s keeps its immutable external identity"):format(pact, policy),
      actualPolicy == policy and actualPact == pact)
    if policy == "open" then
      check(("%s/OPEN unlocks after partner"):format(pact),
        allowed == true and why == "open")
    elseif policy == "badges4" then
      check(("%s/4 BADGES remains closed at zero"):format(pact),
        allowed == false and why == "badges4")
      for _, badge in ipairs(badges) do game.save.inventory[badge] = 1 end
      allowed, why = archive.bankAccess(game.save)
      check(("%s/4 BADGES opens at exactly four"):format(pact),
        allowed == true and why == "badges")
    elseif policy == "league" then
      check(("%s/LEAGUE ignores earlier archived Halls"):format(pact),
        allowed == false and why == "league_required")
      game.save.flags.EVENT_BEAT_CHAMPION_RIVAL = true
      game.save.hallOfFame = { { cycle = index } }
      allowed, why = archive.bankAccess(game.save)
      check(("%s/LEAGUE opens only for this run's Hall"):format(pact),
        allowed == true and why == "league")
    else
      game.save.flags.EVENT_BEAT_CHAMPION_RIVAL = true
      game.save.hallOfFame = { { cycle = index } }
      allowed, why = archive.bankAccess(game.save)
      check(("%s/SEALED stays closed after the League"):format(pact),
        allowed == false and why == "sealed")
    end
    shotHint(("%02d_%s_%s"):format(index, pact, policy))
    local run = roundTrip(index)
    check(("%s/%s reload retains its exact pair"):format(pact, policy),
      run.pact == pact and run.bankPolicy == policy)
  end

  local function initialSource(species, potion, money)
    game.save.party = { Pokemon.new(game.data, species, 50) }
    game.save.party[1].nickname = "LIFE00"
    game.save.box, game.save.boxes = {}, { {} }
    game.save.modData = game.save.modData or {}
    game.save.inventory = { POTION = potion }
    game.save.pcItems = {}
    game.save.money = money
    game.save.player.id = 64499
    game.save.player.name = "LEGACY0"
    stageChampion(0, potion, money)
  end

  local function runPact4x4()
    initialSource("PIKACHU", 1, 100)
    local pacts = { "journey", "trainer", "legacy", "ascendant" }
    local policies = { "open", "badges4", "league", "sealed" }
    local seen, index = {}, 0
    for _, pact in ipairs(pacts) do
      for _, policy in ipairs(policies) do
        index = index + 1
        local avatar = ({ "RED", "BLUE", "GREEN" })[((index - 1) % 3) + 1]
        begin(index, pact, policy, avatar)
        restoreFresh(index)
        verifyPolicy(index, pact, policy)
        seen[pact .. "/" .. policy] = true
        if index < 16 then
          stageChampion(index, index, index * 10)
        end
      end
    end
    local snapshot = archive.load()
    check("4x4 matrix crossed all sixteen distinct pairs",
      index == 16 and #snapshot.hallOfLegacy == 16)
    for _, pact in ipairs(pacts) do
      for _, policy in ipairs(policies) do
        check(pact .. "/" .. policy .. " appears exactly once",
          seen[pact .. "/" .. policy] == true)
      end
    end
    check("sixteen archive transactions retained sixteen Pokemon",
      snapshot.cycle == 16 and #snapshot.bank == 16)
    check("matrix item and money archive is exact",
      snapshot.locker.items.POTION == 121
        and snapshot.locker.money == 1300)
    local receipt = table.concat({
      "LEGACY PACT 4X4 PACKAGE PASS",
      "edition=" .. version,
      "matrix=16/16 pacts=4/4 policies=4/4",
      "partner_gate=16/16 save_reload=16/16 bank_rules=16/16",
      "hall=16 bank=16 locker_items=121 locker_money=1300",
      "transaction_boundary=REAL_LEGACY_ARCHIVE_BEGIN_JOURNEY",
      "new_game_boundary=ENGINE_SAVE_NEW_GAME_HOOK",
      "partner_boundary=REAL_LEGACY_STARTERS_CHOOSE",
      "progression_setup=STAGED_HOF_AND_RIVAL_BALL_BOUNDARIES",
      "direct_archive_state_writes=false",
    }, "\n")
    U.log(receipt)
    local out = assert(io.open(dir .. "/driver_result.txt", "wb"))
    out:write(receipt, "\nchecks=", tostring(checks), "\n")
    out:close()
  end

  local function runThreeJourneys()
    initialSource("PIKACHU", 1, 100)
    local rows = {
      { pact = "journey", policy = "open", avatar = "RED",
        partner = "BULBASAUR", potion = 2, money = 200 },
      { pact = "trainer", policy = "badges4", avatar = "BLUE",
        partner = "CHARMANDER", potion = 3, money = 300 },
      { pact = "legacy", policy = "league", avatar = "GREEN",
        partner = "SQUIRTLE", potion = 4, money = 400 },
    }
    for index, row in ipairs(rows) do
      begin(index, row.pact, row.policy, row.avatar)
      restoreFresh(index)
      local before, why = archive.bankAccess(game.save)
      check(("journey %d starts before partner and Bank"):format(index),
        before == false and why == "partner")
      choosePartner(index, row.avatar, row.partner)
      local run = roundTrip(index)
      check(("journey %d keeps %s active"):format(index, row.avatar),
        archive.activeCharacter(game.save) == row.avatar
          and run.pact == row.pact and run.bankPolicy == row.policy)
      shotHint(("journey_%d_%s"):format(index, row.avatar:lower()))
      if index < #rows then
        stageChampion(index, row.potion, row.money)
      end
    end
    local snapshot = archive.load()
    check("three journeys form one uninterrupted archive history",
      snapshot.cycle == 3 and #snapshot.hallOfLegacy == 3
        and #snapshot.bank == 3)
    local species = {}
    for _, held in ipairs(snapshot.bank) do
      species[held.mon.species] = (species[held.mon.species] or 0) + 1
    end
    check("three outgoing lives retain their exact distinct Pokemon",
      species.PIKACHU == 1 and species.BULBASAUR == 1
        and species.CHARMANDER == 1 and species.SQUIRTLE == nil)
    check("three journeys retain exact item and money totals",
      snapshot.locker.items.POTION == 6
        and snapshot.locker.money == 600)
    local finalRun = assert(journey.state(game.save))
    check("third fresh journey remains active after final reload",
      finalRun.cycle == 3 and archive.activeCharacter(game.save) == "GREEN"
        and #game.save.party == 1 and game.save.party[1].species == "SQUIRTLE")
    local receipt = table.concat({
      "LEGACY THREE JOURNEYS PACKAGE PASS",
      "edition=" .. version,
      "journeys=3/3 fresh_new_game_hooks=3/3 save_reload=3/3",
      "avatars=RED,BLUE,GREEN active_cycle=3",
      "hall=3 bank=3 locker_items=6 locker_money=600",
      "archived_species=PIKACHU,BULBASAUR,CHARMANDER",
      "active_partner=SQUIRTLE",
      "transaction_boundary=REAL_LEGACY_ARCHIVE_BEGIN_JOURNEY",
      "new_game_boundary=ENGINE_SAVE_NEW_GAME_HOOK",
      "partner_boundary=REAL_LEGACY_STARTERS_CHOOSE",
      "progression_setup=STAGED_HOF_AND_RIVAL_BALL_BOUNDARIES",
      "direct_archive_state_writes=false",
    }, "\n")
    U.log(receipt)
    local out = assert(io.open(dir .. "/driver_result.txt", "wb"))
    out:write(receipt, "\nchecks=", tostring(checks), "\n")
    out:close()
  end

  U.wait(20)
  if not game.overworld then U.newGame(game) end
  check("fresh package identity reached the overworld", game.overworld ~= nil)
  check("fresh package identity owns an empty Legacy archive",
    archive.profile().cycle == 0 and archive.current().runId == nil)
  game.save.options = game.save.options or {}
  game.save.options.textSpeed = 1
  if mode == "pact4x4" then runPact4x4() else runThreeJourneys() end
  love.event.quit(0)
end
