-- Package-runnable LÖVE acceptance for the Legacy Oak finale.
--
-- Run all twelve cells from physically materialized Battle Art closures:
-- Red/Blue/Yellow x English/German x 2D/BATTLE_ART_FULL.  English cells use
-- legacy_oak_finale_language_setup_driver.lua as a first process so the
-- edition's installed German package is disabled through the native launcher,
-- then this process proves the actual product language after a clean boot.
-- The driver writes an all-three-path endgame fixture inside its disposable
-- identity, but every team choice, confirmation, loss, retry, reward, rematch
-- and battle result passes through the live product UI/BattleState.

return function(game)
  assert(os.getenv("KA_PACKAGE_GATE") == "1",
    "KA_PACKAGE_GATE=1 is required; source-tree runs are not package proof")
  assert(os.getenv("KA_CLOSURE_PROFILE") == "battle_art",
    "Oak finale requires the reviewed Battle Art closure")
  local utilPath = assert(os.getenv("KA_TEST_UTIL"),
    "KA_TEST_UTIL package path is required")
  local U = dofile(utilPath)
  local SaveData = require("src.core.SaveData")
  local Pokemon = require("src.pokemon.Pokemon")
  local ChoiceBox = require("src.ui.ChoiceBox")
  local GameVersion = require("src.core.GameVersion")
  local GBCFX = require("src.render.GBCFX")
  local Pipelines = require("src.render.Pipelines")
  local Runtime = require("src.mods.Runtime")
  local dir = assert(os.getenv("SHOT_DIR"), "SHOT_DIR is required")
  local locale = assert(os.getenv("QA_LANGUAGE"),
    "QA_LANGUAGE is required")
  assert(locale == "en" or locale == "de",
    "QA_LANGUAGE must be en or de")
  local renderer = assert(os.getenv("QA_RENDERER"),
    "QA_RENDERER is required")
  assert(renderer == "2D" or renderer == "BATTLE_ART_FULL",
    "QA_RENDERER must be exactly 2D or BATTLE_ART_FULL")
  local rendererTag = renderer == "2D" and "2d" or "battle_art_full"
  local version = GameVersion.get()
  assert(version == "red" or version == "blue" or version == "yellow",
    "Oak finale requires Red, Blue, or Yellow")
  local languageId = ({
    red = "deutsch", blue = "deutsch-blau", yellow = "deutsch-gelb",
  })[version]

  local function requiredSha(name)
    local value = os.getenv(name)
    assert(type(value) == "string" and value:match("^[0-9a-f]+$")
        and #value == 64, name .. " must be a lowercase SHA256 receipt")
    return value
  end
  local engineSha = requiredSha("KA_ENGINE_PAYLOAD_SHA256")
  local authoritySha = requiredSha("KA_AUTHORITY_PACKAGE_SHA256")
  local deutschSha = requiredSha("KA_DEUTSCH_PACKAGE_SHA256")
  local battleArtSha = requiredSha("KA_BATTLE_ART_PACKAGE_SHA256")
  local receiptSha = requiredSha("KA_PACKAGE_GATE_RECEIPT_SHA256")
  local expectedBattleArtSha =
    "10d7e80a58d9046b41ec446900f2f15aa6021335a1547d9209117f3a22a0604e"
  assert(battleArtSha == expectedBattleArtSha,
    "Battle Art package is not the reviewed immutable 1.8.3 archive")

  local loaded = assert(game.mods and game.mods.mods,
    "installed package registry is unavailable")
  local expectedPackages = {
    kanto_ascendant = true,
    [languageId] = true,
    BATTLE_ART_VOXEL_FORK = true,
  }
  local loadedCount = 0
  for id in pairs(loaded) do
    loadedCount = loadedCount + 1
    assert(expectedPackages[id],
      "unexpected package leaked into Oak closure: " .. tostring(id))
  end
  assert(loadedCount == 3,
    "Oak Battle Art closure must contain exactly three packages")
  local authorityPackage = assert(loaded.kanto_ascendant,
    "installed Authority package is missing")
  local languagePackage = assert(loaded[languageId],
    "edition-matched language package is not physically installed")
  local battleArtPackage = assert(loaded.BATTLE_ART_VOXEL_FORK,
    "reviewed Battle Art package is not physically installed")

  local function packagePath(value)
    value = tostring(value or "")
    assert(value ~= "" and not value:find(".worktrees", 1, true)
        and not value:find("/Documents/Recompile/", 1, true)
        and not value:find("/tests/", 1, true)
        and not value:find("/tools/", 1, true),
      "source/worktree path is not package evidence: " .. value)
  end
  packagePath(love.filesystem.getSource())
  packagePath(authorityPackage.path)
  packagePath(languagePackage.path)
  packagePath(battleArtPackage.path)

  local exports = assert(game.mods.exports.kanto_ascendant,
    "current Kanto Ascendant export missing")
  local oak = assert(exports.legacyOakFinale)
  local journey = assert(exports.legacyJourney)
  local paths = assert(exports.legacyPaths)
  local archive = assert(journey.archive)
  local voxelResolver = assert(exports.voxelRendererCompat,
    "shared renderer resolver export missing")
  local rendererExport, rendererId, rendererReason = voxelResolver.resolve(game)
  assert(rendererExport and rendererId == "BATTLE_ART_VOXEL_FORK",
    "reviewed Battle Art closure did not resolve: " .. tostring(rendererReason))
  assert(rendererExport.version == "1.8.3"
      and type(rendererExport.lib) == "table"
      and type(rendererExport.lib.require) == "function",
    "Battle Art 1.8.3 public lib.require export is malformed")
  local overworldBattle, overworldId, overworldReason =
    voxelResolver.module(game, "OverworldBattle")
  assert(overworldBattle and overworldId == rendererId,
    "Battle Art OverworldBattle seam missing: " .. tostring(overworldReason))
  local battleArt, battleArtId, battleArtReason =
    voxelResolver.module(game, "BattleArt")
  assert(battleArt and battleArtId == rendererId,
    "Battle Art art-selection seam missing: " .. tostring(battleArtReason))
  local pass, fail = 0, 0
  local report = {
    "scope=RC65-OAK-FINALE",
    "driver_state=RUNNING",
    "authority=Authority-main/LÖVE/package",
    "edition=" .. version,
    "renderer=" .. renderer,
    "renderer_id=" .. rendererId,
    "renderer_version=" .. tostring(rendererExport.version),
    "locale=" .. locale,
    "engine_payload_sha256=" .. engineSha,
    "authority_package_sha256=" .. authoritySha,
    "deutsch_package_sha256=" .. deutschSha,
    "battle_art_package_sha256=" .. battleArtSha,
    "package_gate_receipt_sha256=" .. receiptSha,
    "battle_construction=REAL_KA_OAK_BETA_TRAINER_BATTLE",
    "battle_outcomes=REAL_BATTLESTATE_ACTIONS",
    "save_reload=NATIVE_SLOT_WRITE_LOAD_RESTORE",
  }

  local function check(label, value)
    value = value and true or false
    if value then pass = pass + 1 else fail = fail + 1 end
    U.log(value and "PASS" or "FAIL", label)
    report[#report + 1] = (value and "PASS\t" or "FAIL\t") .. label
    return value
  end
  local function waitFor(predicate, frames)
    for _ = 1, frames or 900 do
      local value = predicate()
      if value then return value end
      U.wait(1)
    end
    return nil
  end
  local function isList(value)
    if not (value and type(value.items) == "table") then return false end
    local title = tostring(value.title or "")
    return title:find("OAK TEAM", 1, true) ~= nil
      or title:find("EICH%-TEAM") ~= nil
  end
  local function waitList()
    return waitFor(function()
      local top = game.stack:top()
      return isList(top) and top or nil
    end)
  end
  local function waitChoice()
    return waitFor(function()
      local top = game.stack:top()
      if getmetatable(top) == ChoiceBox then return top end
      if top and top.waiting then U.tap(game, "a")
      elseif top and top.done then U.tap(game, "a")
      else
        game.input.state.a = true
        U.wait(1)
        game.input.state.a = false
      end
      return nil
    end, 1400)
  end
  local function clearTextToList()
    return waitFor(function()
      local top = game.stack:top()
      if isList(top) then return top end
      if top and top.waiting then U.tap(game, "a")
      elseif top and top.done then U.tap(game, "a")
      else
        game.input.state.a = true
        U.wait(1)
        game.input.state.a = false
      end
      return nil
    end, 1400)
  end
  local function chooseYes(choice)
    assert(getmetatable(choice) == ChoiceBox
        and game.stack:top() == choice,
      "expected the current default-NO ChoiceBox")
    if choice.index == 2 then U.tap(game, "up") end
    U.tap(game, "a")
    assert(waitFor(function()
      return game.stack:top() ~= choice and true or nil
    end, 120), "confirmed ChoiceBox did not finish its answer hold")
    return choice
  end
  local function makeMon(species, level, moves)
    local mon = Pokemon.new(game.data, species, level)
    mon.moves = {}
    for _, id in ipairs(moves) do
      mon.moves[#mon.moves + 1] = { id = id, pp = game.data.moves[id].pp }
    end
    return mon
  end
  local weakRoster = {
    { "PIKACHU", { "THUNDERSHOCK", "GROWL" } },
    { "EEVEE", { "TACKLE", "SAND_ATTACK" } },
    { "CHARMANDER", { "SCRATCH", "GROWL" } },
    { "BULBASAUR", { "TACKLE", "GROWL" } },
    { "SQUIRTLE", { "TACKLE", "TAIL_WHIP" } },
    { "CATERPIE", { "TACKLE", "STRING_SHOT" } },
  }
  local strongRoster = {
    { "MEWTWO", { "PSYCHIC_M", "RECOVER" } },
    { "ZAPDOS", { "THUNDERBOLT", "DRILL_PECK" } },
    { "MOLTRES", { "FIRE_BLAST", "SKY_ATTACK" } },
    { "ARTICUNO", { "BLIZZARD", "ICE_BEAM" } },
    { "DRAGONITE", { "HYPER_BEAM", "THUNDERBOLT" } },
    { "SNORLAX", { "BODY_SLAM", "EARTHQUAKE" } },
  }
  local function roster(rows, level)
    local out = {}
    for _, row in ipairs(rows) do out[#out + 1] = makeMon(row[1], level, row[2]) end
    return out
  end
  local function partySignature()
    local out = {}
    for _, mon in ipairs(game.save.party or {}) do
      out[#out + 1] = mon.species .. ":" .. tostring(mon.level)
    end
    return table.concat(out, ",")
  end
  local function archiveSignature()
    local out = {}
    for _, row in ipairs((archive.load() or {}).bank or {}) do
      local mon = row.mon or {}
      out[#out + 1] = table.concat({ tostring(row.id),
        tostring(mon.species), tostring(mon.level) }, ":")
    end
    return table.concat(out, ",")
  end
  local function ghostIsQuarantined()
    local held = (((archive.load() or {}).quarantine or {}).bank or {})
      ["OAK-QA-GHOST"]
    local row = type(held) == "table" and held.row or nil
    return type(row) == "table" and type(row.mon) == "table"
      and row.mon.species == "GHOST" and held.reason == "unknown_species"
  end
  local function selectSix()
    local list = assert(waitList(), "Oak builder did not open")
    for _ = 1, 6 do
      U.tap(game, "a")
      list = assert(waitList(), "Oak builder did not refresh after selection")
    end
    -- Lawful archive rows can remain after six picks, so locate the authored
    -- action instead of assuming it sits at a fixed visible index.
    local review
    for index, row in ipairs(list.items or {}) do
      if row.value == "review" then review = index break end
    end
    assert(review, "REVIEW SIX action missing")
    list.index = review
    U.tap(game, "a")
  end
  local function advanceBattleToMenu(battle, maximum)
    for _ = 1, maximum or 1800 do
      if game.stack:top() ~= battle then return nil end
      if battle.phase == "menu" and not battle.showEnemyTrainer then return battle end
      U.tap(game, "a")
      U.wait(1)
    end
    return nil
  end
  local function driveBattle(battle, maximum)
    for _ = 1, maximum or 5000 do
      -- Fight / move / replacement screens temporarily sit above BattleState.
      -- Only the settled result ends the actual battle; returning merely
      -- because a legal battle sub-menu is open would fake an outcome.
      if battle.result then return battle.result end
      local top = game.stack:top()
      -- Drive the *actual* menu, rather than mashing A globally.  The
      -- latter can accidentally select RECOVER after a shift prompt and make
      -- an otherwise deterministic acceptance battle look stalled.
      if top and top.forceSwitch then
        for index, mon in ipairs(game.save.party or {}) do
          if mon.hp and mon.hp > 0 then top.index = index break end
        end
        U.tap(game, "a")
      elseif getmetatable(top) == ChoiceBox then
        -- Decline optional SHIFT switches; forced switches are handled above.
        top.index = 2
        U.tap(game, "a")
      elseif top == battle and battle.phase == "menu" then
        battle.menuIndex = 1 -- FIGHT
        U.tap(game, "a")
      elseif top == battle and battle.phase == "moveSelect" then
        local bestIndex, bestDamage = 1, -1
        for index, move in ipairs(battle.player.curMoves or {}) do
          if move.pp and move.pp > 0 then
            local ok, damage = pcall(battle.computeDamage, battle,
              battle.player, battle.enemy, move)
            damage = ok and tonumber(damage) or 0
            if damage > bestDamage then bestIndex, bestDamage = index, damage end
          end
        end
        battle.moveIndex = bestIndex
        U.tap(game, "a")
      else
        -- Text boxes and the battle queue still advance through normal A
        -- presses; no result or HP state is written by this driver.
        U.tap(game, "a")
      end
      U.wait(1)
    end
    U.log("battle timeout", tostring(battle.phase), tostring(battle.result),
      tostring(game.stack:top()), tostring(battle.player and battle.player.mon
        and battle.player.mon.species), tostring(battle.player and battle.player.mon
          and battle.player.mon.hp), tostring(battle.turnCount),
      tostring(battle.enemy and battle.enemy.mon and battle.enemy.mon.species),
      tostring(battle.enemy and battle.enemy.mon and battle.enemy.mon.hp))
    return nil
  end
  local function waitForMessage(frames)
    return waitFor(function()
      local top = game.stack:top()
      -- A text box exists one frame before its typewriter has drawn a single
      -- glyph.  A capture is evidence only once the current page has settled;
      -- do not press A here, since that would silently advance it.
      if top and top.pages and (top.done or top.waiting) then return top end
      if top and top.ascendantOakBeta then U.tap(game, "a") end
      return nil
    end, frames or 1200)
  end
  local function nextStableMessage()
    local top = assert(game.stack:top(), "expected text box to advance")
    assert(top.pages, "expected text box to advance")
    U.tap(game, "a")
    return assert(waitForMessage(1200), "next text page did not settle")
  end
  local function proveLiveRenderer(battle, phase, requireTrainerIntro)
    if renderer == "BATTLE_ART_FULL" then
      local shot = waitFor(function()
        local current = overworldBattle.shot()
        if current and current.canvas and battle.dramaticShapeShot
            and overworldBattle.battle() == battle
            and (not requireTrainerIntro or battle.showEnemyTrainer) then
          return current
        end
        return nil
      end, 3600)
      return check(phase .. " uses a real Battle Art FULL Oak Lab canvas",
        shot ~= nil and shot.canvas ~= nil
          and overworldBattle.arena() ~= nil
          and overworldBattle.battle() == battle
          and battle.dramaticShapeShot ~= nil
          and game.overworld.map.id == "OAKS_LAB"
          and (not requireTrainerIntro or battle.showEnemyTrainer))
    end
    U.wait(8)
    return check(phase .. " stays on the native 2D BattleState",
      overworldBattle.arena() == nil
        and overworldBattle.shot() == nil
        and battle.dramaticShapeShot == nil)
  end

  -- Every matrix cell owns a native slot inside its already-disposable
  -- process identity.  This prevents a prior default slot from deciding which
  -- checkpoint the later SaveData.load observes.
  local slot = ("slot65oak_%s_%s_%s"):format(
    version, locale, rendererTag)
  assert(SaveData.setActiveSlot(version, slot) == slot,
    "could not reserve isolated Oak finale slot")
  local fresh = SaveData.newGame(game:bootConfig())
  game.save = fresh
  game:adoptSave(fresh)
  Runtime.emit("save.created", { save = fresh })

  U.wait(30)
  game.save.options = game.save.options or {}
  game.save.options.gbcfx = 0
  game.save.options.pipelines = game.save.options.pipelines or {}
  GBCFX.setLevel(0)
  overworldBattle.setting:setIndex(
    renderer == "BATTLE_ART_FULL" and 1 or 2, game)
  battleArt.setting:setIndex(2, game) -- reviewed package's ANIMATED set
  Pipelines.setLevel("voxel", renderer == "BATTLE_ART_FULL" and 1 or 0)
  Pipelines.syncOptions(game.save.options)
  U.wait(8)
  check("requested edition is active", GameVersion.get() == version)
  check("reviewed package manifests are live",
    authorityPackage.manifest.id == "kanto_ascendant"
      and languagePackage.manifest.id == languageId
      and battleArtPackage.manifest.id == "BATTLE_ART_VOXEL_FORK"
      and battleArtPackage.manifest.version == "1.8.3")
  local languageChoice = SaveData.modEnabled(SaveData.loadOptions(),
    languageId, SaveData.modScope(version))
  check("language package enablement matches the requested locale",
    locale == "de" and languagePackage.enabled == true
        and languageChoice ~= false
      or locale == "en" and languagePackage.enabled == false
        and languagePackage.state == "disabled" and languageChoice == false)
  check("requested translation is active",
    exports.language and exports.language() == locale)
  check("GBCFX is hard OFF for Oak finale evidence",
    game.save.options.gbcfx == 0 and GBCFX.level == 0
      and not GBCFX.active())
  check("Battle Art uses its visible animated Pokemon collection",
    battleArt.setting:get() == "animated")
  if renderer == "BATTLE_ART_FULL" then
    check("Battle Art FULL public switch and pipeline are active",
      overworldBattle.setting:get() == true
        and Pipelines.level("voxel") == 1
        and Pipelines.levelLabel("voxel") == "FULL"
        and Pipelines.worldPipeline() == "voxel")
  else
    check("Battle Art is installed but explicitly OFF for 2D evidence",
      overworldBattle.setting:get() == false
        and Pipelines.level("voxel") == 0
        and Pipelines.worldPipeline() ~= "voxel")
  end
  local runId = "love-oak-final-" .. tostring(os.time())
  local stored = archive.load()
  stored.completedPaths = { red = true, blue = true, green = true }
  stored.pathSealCycles = { red = 1, blue = 2, green = 3 }
  stored.legacyPass = false
  stored.current = {
    cycle = 99, runId = runId, avatar = "RED", avatarQuestStage = 5,
    pathComplete = true, status = "active", bankUnlocked = true,
    wanderersEnabled = true,
  }
  -- One current party member plus five lawful archived members proves the
  -- product requirement through the real list UI.  The sixth archive row is
  -- deliberately corrupt and must never appear.
  local archivedRows = {
    { "EEVEE", { "TACKLE", "SAND_ATTACK" } },
    { "CHARMANDER", { "SCRATCH", "GROWL" } },
    { "BULBASAUR", { "TACKLE", "GROWL" } },
    { "SQUIRTLE", { "TACKLE", "TAIL_WHIP" } },
    { "CATERPIE", { "TACKLE", "STRING_SHOT" } },
  }
  stored.bank = {}
  for index, row in ipairs(archivedRows) do
    stored.bank[#stored.bank + 1] = {
      id = "OAK-QA-ARCHIVE-" .. tostring(index),
      mon = makeMon(row[1], 54 + index, row[2]),
    }
  end
  stored.bank[#stored.bank + 1] = {
    id = "OAK-QA-GHOST", mon = { species = "GHOST", level = 80,
      moves = { { id = "TACKLE", pp = 35 } } },
  }
  check("clean all-three-path archive writes", archive.write(stored))
  local cleanArchiveSignature

  game.save.modData = game.save.modData or {}
  game.save.modData.kanto_ascendant = game.save.modData.kanto_ascendant or {}
  game.save.modData.kanto_ascendant.legacy_journey = {
    version = 6, cycle = 99, runId = runId, avatar = "RED",
    avatarQuestStage = 5, pathComplete = true,
    completedPaths = { red = true, blue = true, green = true },
    legacyPass = false, bankUnlocked = true, wanderersEnabled = true,
  }
  game.save.party = { makeMon(weakRoster[1][1], 55, weakRoster[1][2]) }
  game.save.player.name, game.save.player.rival = "RED", "BLUE"
  game.save.options.textSpeed = 1
  game:adoptSave(game.save)
  U.teleport(game, "OAKS_LAB", 5, 5, "up")
  local npc = { frozen = false, facePlayer = function() end }
  local weakSignature = partySignature()
  check("runtime profile has all three completed paths",
    paths.allPathsComplete() and not paths.profile().legacyPass)
  check("Oak boss is a deterministic six-mon legal roster", oak.validateBoss(game.data))

  check("Oak opens the real team builder", oak.start(game, game.overworld, npc))
  local initial = clearTextToList()
  local initialTitle = tostring(initial and initial.title or "")
  check("requested locale is visible in the live Oak builder",
    locale == "de" and initialTitle:find("EICH%-TEAM") ~= nil
      or locale == "en" and initialTitle:find("OAK TEAM", 1, true) ~= nil)
  check("team-builder UI screenshot", initial and U.shot(game, dir .. "/01_team_builder.png"))
  local ghostOffered = false
  local archiveOffered = false
  for _, row in ipairs(initial and initial.items or {}) do
    if tostring(row.label):find("GHOST", 1, true) then ghostOffered = true end
    if tostring(row.right):match("^A L%d+$") then archiveOffered = true end
  end
  check("illegal ghost archive row is not selectable", not ghostOffered)
  check("real builder visibly offers lawful archived Pokemon", archiveOffered)
  -- `availableMons` intentionally moves an unknown species to the durable
  -- quarantine before returning player-facing rows.  Establish the rollback
  -- baseline after that authored fail-closed reconciliation, then prove both
  -- the five lawful rows and the quarantined foreign row survive the trial.
  cleanArchiveSignature = archiveSignature()
  check("five lawful archive rows survive fail-closed reconciliation",
    select(2, cleanArchiveSignature:gsub("OAK%-QA%-ARCHIVE%-", "")) == 5)
  check("illegal ghost row is durably quarantined, never silently deleted",
    ghostIsQuarantined())
  U.tap(game, "a")
  local afterFirst = assert(waitList(), "selection did not refresh builder")
  local duplicateOffered = false
  for _, row in ipairs(afterFirst.items or {}) do
    if tostring(row.label):find("PIKACHU", 1, true) then duplicateOffered = true end
  end
  check("chosen source cannot be selected a second time", not duplicateOffered)
  check("duplicate-denial screenshot", U.shot(game, dir .. "/02_duplicate_denied.png"))
  U.tap(game, "b")
  U.wait(12)
  check("builder cancel leaves party byte-for-byte selection-equivalent",
    partySignature() == weakSignature and not npc.frozen)

  check("Oak builder reopens after cancellation", oak.start(game, game.overworld, npc))
  assert(clearTextToList(), "Oak builder did not open")
  selectSix()
  local first = assert(waitChoice(), "first Oak confirmation missing")
  check("first confirmation is default NO", first.index == 2)
  check("first confirmation screenshot", U.shot(game, dir .. "/03_confirm_lock.png"))
  chooseYes(first)
  local second = assert(waitChoice(), "second Oak confirmation missing")
  check("second confirmation is independently default NO", second.index == 2)
  check("second confirmation screenshot", U.shot(game, dir .. "/04_confirm_begin.png"))
  chooseYes(second)
  local battle = assert(waitFor(function()
    local top = game.stack:top()
    return top and top.ascendantOakBeta and top or nil
  end, 1200), "Oak beta battle did not start")
  check("battle has dedicated KA_OAK_BETA context",
    battle.oppClass == "KA_OAK_BETA" and battle.noPrizeMoney == true)
  check("battle actually uses one current plus five archived projections",
    #game.save.party == 6 and game.save.party[1].species == "PIKACHU"
      and game.save.party[2].species == "EEVEE"
      and partySignature()
        == "PIKACHU:55,EEVEE:55,CHARMANDER:56,BULBASAUR:57,SQUIRTLE:58,CATERPIE:59")
  local introReady = waitFor(function()
    return game.stack:top() == battle and battle.showEnemyTrainer
      and battle.introBalls and battle
  end, 1200)
  check("Oak trainer intro is actually rendered", introReady ~= nil)
  check("requested locale owns the live Oak trainer intro",
    introReady and (locale == "de"
      and battle.introText:find("EICH", 1, true) ~= nil
      and battle.introText:find("VERMÄCHTNIS", 1, true) ~= nil
      or locale == "en"
        and battle.introText:find("OAK", 1, true) ~= nil
        and battle.introText:find("LEGACY", 1, true) ~= nil))
  proveLiveRenderer(battle, "Oak trainer intro", true)
  -- `showEnemyTrainer` becomes true at the start of the real GB-style
  -- slide-in.  Let that authored 24-frame animation settle before capture;
  -- otherwise a valid trainer image is still just beyond the screen edge.
  if introReady then U.wait(80) end
  -- Battle dialogue is rendered by BattleState itself, not TextBox.  Do not
  -- send A while this first queue item settles: an input queued during the
  -- slide can legitimately dismiss the introductory page before capture.
  local introText = introReady and waitFor(function()
    if battle.current and battle.current.text == battle.introText
        and battle.charIndex >= (battle.total or math.huge)
        and battle.msgPrompt then return battle end
    return nil
  end, 1200)
  local introStable = introText and game.stack:top() == battle
    and battle.current and battle.current.text == battle.introText
    and battle.charIndex >= (battle.total or math.huge) and battle.msgPrompt
  check("Oak trainer intro text is fully revealed", introStable)
  check("Oak trainer-intro screenshot", introStable and U.shot(game,
    dir .. "/05_oak_intro_" .. locale .. "_" .. rendererTag .. ".png"))
  local menuReady = advanceBattleToMenu(battle, 1800)
  check("Oak reaches actual battle menu", menuReady ~= nil)
  proveLiveRenderer(battle, "weak Oak battle menu", false)
  check("Oak battle screenshot", menuReady and U.shot(game,
    dir .. "/06_oak_battle_" .. locale .. "_" .. rendererTag .. ".png"))
  check("weak legal team reaches a real loss", driveBattle(battle, 4200) == "lose")
  local lossText = waitForMessage(1200)
  check("loss restores the original legal party", partySignature() == weakSignature)
  check("loss leaves every archive row byte-for-byte selection-equivalent",
    archiveSignature() == cleanArchiveSignature and ghostIsQuarantined())
  check("loss/retry screenshot", lossText and U.shot(game, dir .. "/07_loss_retry.png"))

  -- The retry fixture is a normal six-species level-100 team with legal
  -- learn/TM moves.  No battle stats, catch rates, money, or trainer data are
  -- altered; the player simply enters with a stronger legal roster.
  game.save.party = roster(strongRoster, 100)
  local strongSignature = partySignature()
  check("six legal player Pokémon form the difficulty comparison team",
    #game.save.party == 6 and strongSignature:find("MEWTWO:100", 1, true) ~= nil)
  check("Oak retry opens", oak.start(game, game.overworld, npc))
  assert(clearTextToList(), "Oak retry builder did not open")
  selectSix()
  chooseYes(assert(waitChoice(), "first Oak retry confirmation missing"))
  chooseYes(assert(waitChoice(), "second Oak retry confirmation missing"))
  battle = assert(waitFor(function()
    local top = game.stack:top()
    return top and top.ascendantOakBeta and top or nil
  end, 1200), "Oak retry battle did not start")
  local strongMenu = advanceBattleToMenu(battle, 1800)
  check("strong retry reaches the real battle menu", strongMenu ~= nil)
  proveLiveRenderer(battle, "strong Oak retry menu", false)
  check("strong legal retry battle screenshot",
    strongMenu and U.shot(game, dir .. "/10_strong_retry_battle_"
      .. locale .. "_" .. rendererTag .. ".png"))
  check("strong legal team wins by real battle actions", driveBattle(battle, 30000) == "win")
  local rewardText = waitForMessage(1400)
  check("first victory records legacy pass exactly once", paths.profile().legacyPass == true)
  check("victory/reward screenshot", rewardText and U.shot(game, dir .. "/08_victory_reward.png"))
  local rewardRule = nextStableMessage()
  check("reward rematch-rule screenshot",
    rewardRule and U.shot(game, dir .. "/08b_victory_rematch_rule.png"))
  U.tap(game, "a")
  U.wait(4)
  check("save after reward succeeds", game:writeSave())
  local reloaded = assert(SaveData.load(version))
  game:restoreSave(reloaded, false)
  U.wait(30)
  check("native reload used the reserved edition slot",
    SaveData.activeSlot(version) == slot)
  check("reload preserves the one-time pass", paths.profile().legacyPass == true)
  check("reward save/reload preserves the complete archive roster",
    archiveSignature() == cleanArchiveSignature and ghostIsQuarantined())

  -- A rematch deliberately uses the same legal roster and live UI, then its
  -- completion message must name the no-prize rule instead of re-awarding it.
  U.teleport(game, "OAKS_LAB", 5, 5, "up")
  check("Oak rematch opens after reload", oak.start(game, game.overworld, npc))
  assert(clearTextToList(), "Oak rematch builder did not open")
  selectSix()
  chooseYes(assert(waitChoice(), "first Oak rematch confirmation missing"))
  chooseYes(assert(waitChoice(), "second Oak rematch confirmation missing"))
  battle = assert(waitFor(function()
    local top = game.stack:top()
    return top and top.ascendantOakBeta and top or nil
  end, 1200), "Oak rematch battle did not start")
  local rematchMenu = advanceBattleToMenu(battle, 1800)
  check("Oak rematch reaches the real battle menu", rematchMenu ~= nil)
  proveLiveRenderer(battle, "Oak no-prize rematch menu", false)
  check("rematch resolves through real battle", driveBattle(battle, 30000) == "win")
  local rematchText = waitForMessage(1400)
  check("rematch grants no second reward", paths.profile().legacyPass == true)
  check("rematch screenshot", rematchText and U.shot(game, dir .. "/09_rematch_no_reward.png"))
  local noRewardRule = nextStableMessage()
  check("no-reward rematch-rule screenshot",
    noRewardRule and U.shot(game, dir .. "/09b_rematch_no_reward_rule.png"))

  local completed = fail == 0 and "1/1" or "0/1"
  report[#report + 1] = "status=" .. (fail == 0 and "PASS" or "FAIL")
  report[#report + 1] = "oak_finale=" .. completed
  report[#report + 1] = "native_save_reload=" .. completed
  report[#report + 1] = "real_loss_retry_win_rematch=" .. completed
  report[#report + 1] = "pass=" .. tostring(pass)
  report[#report + 1] = "fail=" .. tostring(fail)
  local result = assert(io.open(dir .. "/driver_result.txt", "wb"),
    "could not write driver_result.txt")
  result:write(table.concat(report, "\n"), "\n")
  result:close()
  U.log(("LEGACY OAK E2E RESULT locale=%s pass=%d fail=%d")
    :format(locale, pass, fail))
  love.event.quit(fail == 0 and 0 or 1)
end
