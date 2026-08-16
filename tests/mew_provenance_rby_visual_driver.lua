-- Package-runnable LÖVE acceptance for the 6.5 Mew provenance repair and
-- the reviewed Battle Art 1.8.3 renderer closure.
--
-- One disposable identity runs one edition.  The driver uses the real Start
-- menu/Journal prompt, both player choices, the live Oak/Fuji/Cinnabar NPCs,
-- the authored Route 24 object, the battle ITEM menu and a native save/load.
-- Run all six cells: Red/Blue/Yellow x 2D/BATTLE_ART_FULL.  Both renderer
-- cells require the reviewed Battle Art package to be installed; 2D proves
-- that its public OFF switch restores the classic battle rather than merely
-- proving the renderer is absent.

return function(game)
  local U = dofile(os.getenv("KA_TEST_UTIL") or "tests/drivers/util.lua")
  local Bag = require("src.inventory.Bag")
  local ChoiceBox = require("src.ui.ChoiceBox")
  local GameVersion = require("src.core.GameVersion")
  local GBCFX = require("src.render.GBCFX")
  local Pipelines = require("src.render.Pipelines")
  local Pokemon = require("src.pokemon.Pokemon")
  local SaveData = require("src.core.SaveData")

  local dir = assert(os.getenv("SHOT_DIR"), "SHOT_DIR is required")
  assert(os.getenv("KA_PACKAGE_GATE") == "1",
    "KA_PACKAGE_GATE=1 is required; source-tree runs are not package proof")
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
  local expectedBattleArtSha =
    "10d7e80a58d9046b41ec446900f2f15aa6021335a1547d9209117f3a22a0604e"
  assert(battleArtSha == expectedBattleArtSha,
    "Battle Art package is not the reviewed immutable 1.8.3 archive")
  local renderer = os.getenv("QA_RENDERER")
  assert(renderer == "2D" or renderer == "BATTLE_ART_FULL",
    "QA_RENDERER must be exactly 2D or BATTLE_ART_FULL")
  local rendererTag = renderer == "2D" and "2d" or "battle_art_full"
  local version = GameVersion.get()
  assert(version == "red" or version == "blue" or version == "yellow",
    "Mew provenance driver requires Red, Blue, or Yellow")

  local exports = assert(game.mods and game.mods.exports
    and game.mods.exports.kanto_ascendant, "current Kanto Ascendant export missing")
  local ascendant = assert(exports.ascendant, "Ascendant controller missing")
  local ascendantData = assert(exports.ascendantData, "Ascendant data missing")
  local postgame = assert(exports.postgame, "postgame controller missing")
  local postgameData = assert(exports.postgameData, "postgame data missing")
  local onboarding = assert(exports.onboarding, "onboarding controller missing")
  local voxelResolver = assert(exports.voxelRendererCompat,
    "shared Voxel renderer resolver export missing")
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
    "scope=RC65-MEW-PROVENANCE-BATTLE-ART",
    "authority=Authority-main/LÖVE/package",
    "edition=" .. version,
    "renderer=" .. renderer,
    "renderer_id=" .. rendererId,
    "renderer_version=" .. tostring(rendererExport.version),
    "engine_payload_sha256=" .. engineSha,
    "authority_package_sha256=" .. authoritySha,
    "deutsch_package_sha256=" .. deutschSha,
    "battle_art_package_sha256=" .. battleArtSha,
    "battle_construction=REAL_ROUTE24_WILD_BATTLE",
    "capture_path=REAL_BATTLESTATE_RENDER",
    "locale=en",
  }

  local function check(label, value)
    value = value and true or false
    if value then pass = pass + 1 else fail = fail + 1 end
    U.log(value and "PASS" or "FAIL", label)
    report[#report + 1] = (value and "PASS\t" or "FAIL\t") .. label
    return value
  end

  local function waitFor(predicate, frames)
    for _ = 1, frames or 1200 do
      local value = predicate()
      if value then return value end
      U.wait(1)
    end
    return nil
  end

  local function writeResult()
    os.execute('mkdir -p "' .. dir .. '" 2>/dev/null')
    report[#report + 1] = "pass=" .. tostring(pass)
    report[#report + 1] = "fail=" .. tostring(fail)
    local f = assert(io.open(dir .. "/driver_result.txt", "wb"))
    f:write(table.concat(report, "\n"), "\n")
    f:close()
  end

  local function finish()
    writeResult()
    U.log(("RESULT %s pass=%d fail=%d"):format(version, pass, fail))
    love.event.quit(fail == 0 and 0 or 1)
  end

  local function currentPage(box)
    if not (box and box.pages) then return "" end
    local page = box.pages[box.pageIndex or 1] or {}
    return table.concat(page, "\n")
  end

  local function pageContains(box, needle)
    return currentPage(box):gsub("%s+", " "):find(needle, 1, true) ~= nil
  end

  local function stableText(frames)
    return waitFor(function()
      local top = game.stack:top()
      return top and top.pages and (top.waiting or top.done) and top or nil
    end, frames or 1400)
  end

  local function waitChoice(frames)
    return waitFor(function()
      local top = game.stack:top()
      if getmetatable(top) == ChoiceBox then return top end
      if top and top.pages then
        if top.waiting then U.tap(game, "a")
        elseif top.done and top.choice then U.wait(1) end
      end
      return nil
    end, frames or 1800)
  end

  local function dismissTextToOverworld(frames)
    return waitFor(function()
      local top = game.stack:top()
      if top == game.overworld then return top end
      if getmetatable(top) == ChoiceBox then return nil end
      if top and top.pages and (top.waiting or top.done) then
        U.tap(game, "a")
      elseif top and type(top.items) == "table" then
        -- The Journal is intentionally an overlay launched from the grouped
        -- KANTO ASCENDANT list.  Closing its pages returns to that list; B
        -- closes it to the Start menu and a second B returns to the field.
        U.tap(game, "b")
      else
        U.wait(1)
      end
      return nil
    end, frames or 6000)
  end

  local function countMew(save)
    local count, external = 0, 0
    local function inspect(mon)
      if mon and mon.species == "MEW" then
        count = count + 1
        if mon.nickname == "EXTMEW" and type(mon.eventDistribution) == "table"
            and mon.eventDistribution.id == "QA_EXTERNAL_MEW" then
          external = external + 1
        end
      end
    end
    for _, mon in ipairs(save.party or {}) do inspect(mon) end
    for _, box in ipairs(save.boxes or {}) do
      for _, mon in ipairs(box or {}) do inspect(mon) end
    end
    return count, external
  end

  local function researchSignature(s)
    local ids = {}
    for _, row in ipairs(ascendantData.research or {}) do
      if s.research.completed[row.id] then ids[#ids + 1] = row.id end
    end
    table.sort(ids)
    return table.concat(ids, ",")
  end

  local function legendSignature(p)
    local ids = {}
    for _, species in ipairs(postgameData.legendOrder or {}) do
      if p.catches[species] then ids[#ids + 1] = species end
    end
    return table.concat(ids, ",")
  end

  local function progressSignature()
    local s, p = ascendant.state(), postgame.state()
    local mewCount, externalCount = countMew(game.save)
    return table.concat({
      tostring(game.save.money), tostring(game.save.inventory.MASTER_BALL),
      tostring(game.save.pokedex.owned.MEW), tostring(game.save.pokedex.seen.MEW),
      tostring(mewCount), tostring(externalCount), tostring(p.crownChampion),
      legendSignature(p), researchSignature(s), tostring(s.rocketStage),
      tostring(s.metrics.qaMewProvenance),
    }, "|")
  end

  local function liveNpc(name)
    for _, npc in ipairs(game.overworld and game.overworld.npcs or {}) do
      if npc.def and npc.def.name == name then return npc end
    end
    return nil
  end

  local FACINGS = {
    { 0, 1, "up" }, { 0, -1, "down" },
    { 1, 0, "left" }, { -1, 0, "right" },
  }

  local function teleportNextTo(mapId, name)
    U.teleport(game, mapId, 0, 0, "down")
    U.wait(30)
    local npc = liveNpc(name)
    if not npc then return nil end
    local chosen
    for _, row in ipairs(FACINGS) do
      local x, y = npc.cellX + row[1], npc.cellY + row[2]
      if game.overworld.map:inBounds(x, y)
          and game.overworld.map:isWalkableCell(x, y)
          and not game.overworld:npcAtCell(x, y) then
        chosen = { x, y, row[3] }
        break
      end
    end
    if not chosen then return nil end
    U.teleport(game, mapId, chosen[1], chosen[2], chosen[3])
    U.wait(40)
    return liveNpc(name)
  end

  local function talkAndCapture(mapId, name, expectedStage, shotName, needle)
    local npc = teleportNextTo(mapId, name)
    if not check(name .. " is a live map NPC", npc ~= nil) then return false end
    game.overworld:talkTo(npc)
    local box = stableText(1800)
    local correct = box and pageContains(box, needle)
    local ok = check(name .. " opens the authored clue", correct)
    ok = check(name .. " clue screenshot",
      box and U.shot(game, dir .. "/" .. shotName)) and ok
    ok = check(name .. " advances only its exact investigation stage",
      ascendant.state().mewStage == expectedStage) and ok
    return dismissTextToOverworld(2600) ~= nil and ok
  end

  local function openJournalRepair()
    local field = waitFor(function()
      local ow = game.overworld
      return game.stack:top() == ow and ow and not ow.transitioning
        and ow.player and not ow.player.inputLocked and not ow.player.moving
        and ow or nil
    end, 1800)
    if not field then return nil end
    U.tap(game, "start")
    local gateway = waitFor(function()
      local top = game.stack:top()
      if not (top and type(top.items) == "table") then return nil end
      for index, row in ipairs(top.items) do
        if row.label == "ASCENDANT" then return { menu = top, index = index } end
      end
      return nil
    end, 1200)
    if not gateway then return nil end
    gateway.menu.index = gateway.index
    if gateway.menu.clampScroll then gateway.menu:clampScroll() end
    U.tap(game, "a")
    local journal = waitFor(function()
      local top = game.stack:top()
      if not (top and top.title == "KANTO ASCENDANT"
          and type(top.items) == "table") then return nil end
      for index, row in ipairs(top.items) do
        if row.label == "JOURNAL" then return { menu = top, index = index } end
      end
      return nil
    end, 1200)
    if not journal then return nil end
    journal.menu.index = journal.index
    U.tap(game, "a")
    return waitChoice(2400)
  end

  U.wait(30)
  game.save.options = game.save.options or {}
  game.save.options.textSpeed = 1
  game.save.options.gbcfx = 0
  game.save.options.pipelines = game.save.options.pipelines or {}
  GBCFX.setLevel(0)
  overworldBattle.setting:setIndex(renderer == "BATTLE_ART_FULL" and 1 or 2,
    game)
  battleArt.setting:setIndex(2, game) -- the package's visible ANIMATED set
  Pipelines.setLevel("voxel", renderer == "BATTLE_ART_FULL" and 1 or 0)
  Pipelines.syncOptions(game.save.options)
  U.wait(8)
  check("requested edition is active", GameVersion.get() == version)
  check("current Kanto Ascendant is the only requested mod export",
    game.mods.exports.kanto_ascendant == exports)
  check("English product dialogue is active",
    exports.language and exports.language() == "en")
  check("GBCFX is hard OFF", game.save.options.gbcfx == 0
    and GBCFX.level == 0 and not GBCFX.active())
  check("reviewed Battle Art package identity is live",
    rendererId == "BATTLE_ART_VOXEL_FORK"
      and rendererExport.version == "1.8.3")
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

  -- A real externally-sourced Mew exists before the repair.  It deliberately
  -- has a distinct provenance marker and nickname so persistence can prove it
  -- is the same collection member, rather than the later authored catch.
  local external = Pokemon.new(game.data, "MEW", 5)
  external.nickname = "EXTMEW"
  external.eventDistribution = {
    id = "QA_EXTERNAL_MEW", name = "EXTERNAL MEW",
    source = "EXTERNAL ARCHIVE", originalLevel = 5,
    originalMoves = { "POUND" }, origin = "EXTERNAL TEST FIXTURE",
  }
  local partner = Pokemon.new(game.data, "MEWTWO", 70)
  game.save.party = { external, partner }
  game.save.boxes = game.save.boxes or {}
  game.save.pokedex = game.save.pokedex or { seen = {}, owned = {} }
  game.save.pokedex.seen = game.save.pokedex.seen or {}
  game.save.pokedex.owned = game.save.pokedex.owned or {}
  game.save.pokedex.seen.MEW = true
  game.save.pokedex.owned.MEW = true
  game.save.inventory = game.save.inventory or {}
  game.save.bagOrder = game.save.bagOrder or {}
  game.save.inventory.MASTER_BALL = nil
  for index = #game.save.bagOrder, 1, -1 do
    if game.save.bagOrder[index] == "MASTER_BALL" then
      table.remove(game.save.bagOrder, index)
    end
  end
  assert(Bag.add(game.save, "MASTER_BALL", 2, game.data),
    "fixture could not add two Master Balls")
  game.save.money = 123456
  game.save.hallOfFame = { { "QA-MEW-PROVENANCE" } }
  game.save.flags = game.save.flags or {}
  game.save.flags.EVENT_GOT_POKEDEX = true
  game.save.flags.EVENT_GOT_STARTER = true
  game.save.objectToggles = game.save.objectToggles or {}
  game.save.objectToggles.OAKS_LAB = game.save.objectToggles.OAKS_LAB or {}
  game.save.objectToggles.OAKS_LAB.OAKSLAB_OAK1 = true
  game.save.objectToggles.OAKS_LAB.OAKSLAB_OAK2 = false
  game.save.objectToggles.MR_FUJIS_HOUSE =
    game.save.objectToggles.MR_FUJIS_HOUSE or {}
  game.save.objectToggles.MR_FUJIS_HOUSE.MRFUJISHOUSE_MR_FUJI = true

  game:adoptSave(game.save)
  -- This row is about the repair prompt, not the unrelated one-time 5.0
  -- orientation.  A fresh Hall-of-Fame fixture would otherwise receive the
  -- legitimate "OAK: Good timing" onboarding on its first map.entered and
  -- cover the Start menu before the driver can choose ASCENDANT.
  onboarding.state().shown = true
  local p = postgame.state()
  p.crownChampion = true
  p.apexChampion = true
  for _, species in ipairs(postgameData.legendOrder or {}) do
    p.catches[species] = true
  end
  local s = ascendant.state()
  for _, row in ipairs(ascendantData.research or {}) do
    s.research.completed[row.id] = true
  end
  s.rocketStage = #ascendantData.rocket
  s.metrics.qaMewProvenance = 650011
  s.mewCaught, s.mewStage = true, 4
  s.mewAuthoredCatch, s.mewRepairDecision = nil, nil

  local baselineLegend = legendSignature(p)
  local baselineResearch = researchSignature(s)

  U.teleport(game, "OAKS_LAB", 5, 3, "up")
  check("ambiguous pre-6.5 completion is eligible for one repair decision",
    ascendant.mewRepairAvailable())
  check("external Mew does not establish authored provenance",
    s.mewCaught and s.mewAuthoredCatch ~= true)
  check("all real quest prerequisites are staged", ascendant.mewEligible(game))
  local beforeRepair = progressSignature()
  check("baseline native save succeeds", game:writeSave())

  -- First exercise KEEP (NO) through the visible Journal choice.
  local choice = openJournalRepair()
  if not check("Journal visibly offers the external-Mew repair", choice ~= nil) then
    finish()
    return
  end
  check("repair choice defaults to explicit YES", choice and choice.index == 1)
  check("external-Mew warning screenshot",
    choice and U.shot(game, dir .. "/01_journal_external_warning.png"))
  if choice then choice.index = 2; U.tap(game, "a") end
  local keepBox = stableText(1800)
  local keepUI = check("KEEP result is product UI",
    keepBox and pageContains(keepBox, "completed quest"))
  check("KEEP result screenshot",
    keepBox and U.shot(game, dir .. "/02_keep_result.png"))
  local keep = ascendant.state()
  local keepState = check("KEEP preserves the completed state and records the decision",
    keep.mewCaught == true and keep.mewStage == 4
      and keep.mewAuthoredCatch ~= true and keep.mewRepairDecision == "kept")
  if not (keepUI and keepState) then finish(); return end
  check("KEEP changes no Pokemon or other progress",
    progressSignature() == beforeRepair)
  local diskKeep = SaveData.load(version)
  local diskKeepState = diskKeep and diskKeep.modData
    and diskKeep.modData.kanto_ascendant
    and diskKeep.modData.kanto_ascendant.ascendant
  check("KEEP is written by the product before its result page",
    diskKeepState and diskKeepState.mewRepairDecision == "kept")
  check("KEEP disk save retains the external Mew",
    diskKeep and select(2, countMew(diskKeep)) == 1)
  check("KEEP result and Journal close through normal UI",
    dismissTextToOverworld(7000) ~= nil)

  -- Stage a second ambiguous legacy completion in the same disposable save,
  -- then exercise RESTORE (YES) through the same real Journal entry.
  s = ascendant.state()
  s.mewCaught, s.mewStage = true, 4
  s.mewAuthoredCatch, s.mewRepairDecision = nil, nil
  check("second legacy fixture is repairable", ascendant.mewRepairAvailable())
  check("second legacy fixture native save succeeds", game:writeSave())
  choice = openJournalRepair()
  if not check("Journal reopens for a distinct ambiguous legacy fixture",
      choice ~= nil) then
    finish()
    return
  end
  if choice then choice.index = 1; U.tap(game, "a") end
  local restoreBox = stableText(1800)
  local restoreUI = check("RESTORE result is product UI",
    restoreBox and pageContains(restoreBox, "investigation was"))
  check("RESTORE result screenshot",
    restoreBox and U.shot(game, dir .. "/03_restore_result.png"))
  local restored = ascendant.state()
  local restoreState = check("RESTORE reopens only the authored investigation",
    restored.mewCaught == false and restored.mewStage == 0
      and restored.mewAuthoredCatch == nil
      and restored.mewRepairDecision == "restored")
  if not (restoreUI and restoreState) then finish(); return end
  check("RESTORE retains the external Mew and every other progress marker",
    progressSignature() == beforeRepair)
  local diskRestore = SaveData.load(version)
  local diskRestoreState = diskRestore and diskRestore.modData
    and diskRestore.modData.kanto_ascendant
    and diskRestore.modData.kanto_ascendant.ascendant
  check("RESTORE is written by the product before its result page",
    diskRestoreState and diskRestoreState.mewRepairDecision == "restored"
      and diskRestoreState.mewCaught == false and diskRestoreState.mewStage == 0)
  check("RESTORE disk save retains the external Mew",
    diskRestore and select(2, countMew(diskRestore)) == 1)
  check("RESTORE result and Journal close through normal UI",
    dismissTextToOverworld(7000) ~= nil)

  check("restored investigation remains eligible with external Mew owned",
    ascendant.mewEligible(game) and game.save.pokedex.owned.MEW == true)

  -- Real current-map NPCs, in the strict authored order.
  if not check("Oak clue flow returns to the field",
      talkAndCapture("OAKS_LAB", "OAKSLAB_OAK1", 1,
        "04_oak_clue.png", "OAK:")) then finish(); return end
  if not check("Fuji clue flow returns to the field",
      talkAndCapture("MR_FUJIS_HOUSE", "MRFUJISHOUSE_MR_FUJI", 2,
        "05_fuji_clue.png", "FUJI:")) then finish(); return end
  if not check("Cinnabar clue flow returns to the field",
      talkAndCapture("CINNABAR_LAB_FOSSIL_ROOM",
        "CINNABARLABFOSSILROOM_SCIENTIST2", 3,
        "06_cinnabar_clue.png", "SCIENTIST:")) then finish(); return end

  -- The authored map-entry hook must create the Route 24 object only now.
  local mewNpc = teleportNextTo("ROUTE_24", ascendantData.mew.name)
  if not check("Route 24 spawns the authored Ascendant Mew object", mewNpc ~= nil
      and mewNpc.def and mewNpc.def.runtime == true
      and mewNpc.def.pokemon == "MEW") then finish(); return end
  check("Route 24 authored Mew screenshot",
    mewNpc and U.shot(game, dir .. "/07_route24_mew.png"))
  if mewNpc then game.overworld:talkTo(mewNpc) end
  local intro = stableText(1800)
  check("Route 24 uses the authored choice-based Mew introduction",
    intro and pageContains(intro, "playful presence"))
  check("authored Mew introduction screenshot",
    intro and U.shot(game, dir .. "/08_mew_intro.png"))
  local introClosed = waitFor(function()
    local top = game.stack:top()
    if top ~= intro then return true end
    if top and top.pages and (top.waiting or top.done) then U.tap(game, "a") end
    return nil
  end, 2400)
  check("Mew introduction closes through normal UI", introClosed ~= nil)

  local battle = waitFor(function()
    local top = game.stack:top()
    return top and top.ascendantMew == true and top or nil
  end, 2400)
  if not check("Route 24 starts a provenance-marked real wild battle",
      battle and battle.kind == "wild" and battle.enemy
        and battle.enemy.mon.species == "MEW"
        and battle.enemy.mon.level == 100) then finish(); return end
  local battleMenu = waitFor(function()
    if not battle then return nil end
    local top = game.stack:top()
    if top == battle and battle.phase == "menu" then return battle end
    if top == battle then U.tap(game, "a")
    elseif top and top.pages and (top.waiting or top.done) then U.tap(game, "a") end
    return nil
  end, 3600)
  if not check("authored battle reaches the real command menu",
      battleMenu ~= nil) then finish(); return end
  local renderedShot
  if renderer == "BATTLE_ART_FULL" then
    renderedShot = waitFor(function()
      local shot = overworldBattle.shot()
      return shot and shot.canvas and battle.dramaticShapeShot and shot or nil
    end, 3600)
    check("Battle Art FULL owns a real Route 24 arena",
      overworldBattle.arena() ~= nil
        and game.overworld.map.id == "ROUTE_24")
    check("Battle Art FULL produces a real rendered battle canvas",
      renderedShot ~= nil and renderedShot.canvas ~= nil
        and battle.dramaticShapeShot ~= nil)
  else
    U.wait(8)
    check("2D battle has no staged Battle Art shot",
      overworldBattle.shot() == nil and battle.dramaticShapeShot == nil)
  end
  check(renderer .. " Mew battle screenshot",
    battleMenu and U.shot(game,
      dir .. "/09_mew_battle_" .. rendererTag .. ".png"))

  local masterBefore = game.save.inventory.MASTER_BALL
  if battleMenu then
    battle.menuIndex = 3 -- ITEM in the real FIGHT/PKMN/ITEM/RUN grid.
    U.tap(game, "a")
  end
  local bag = waitFor(function()
    local top = game.stack:top()
    return top and top.screenId == "BagMenu" and type(top.items) == "table"
      and top or nil
  end, 1200)
  local masterIndex
  for index, row in ipairs(bag and bag.items or {}) do
    if row.value == "MASTER_BALL" then masterIndex = index break end
  end
  if not check("battle ITEM menu visibly contains the staged Master Balls",
      bag and masterIndex ~= nil) then finish(); return end
  if bag and masterIndex then bag.index = masterIndex; U.tap(game, "a") end
  check("real Bag use consumes exactly one Master Ball immediately",
    waitFor(function()
      return game.save.inventory.MASTER_BALL == masterBefore - 1
    end, 1200) ~= nil)

  local toss = waitFor(function()
    local player = battle and battle.animPlayer
    if player and player.__ascendantBallMove == "ULTRATOSS_ANIM"
        and not player:isDone() then return true end
    if battle and battle.current and battle.charIndex >= battle.total then
      U.tap(game, "a")
    end
    return nil
  end, 2400)
  if not check("Master Ball reaches the real tiered toss animation",
      toss ~= nil) then finish(); return end
  if renderer == "BATTLE_ART_FULL" then
    local tossShot = overworldBattle.shot()
    check("Battle Art FULL remains live through Master Ball toss",
      tossShot and tossShot.canvas and battle.dramaticShapeShot)
  end
  check("Master Ball toss screenshot",
    toss and U.shot(game,
      dir .. "/10_master_ball_toss_" .. rendererTag .. ".png"))

  local caughtMessage = waitFor(function()
    if not battle then return nil end
    local text = battle.current and battle.current.text or ""
    if battle.lockedBall and text:find("MEW", 1, true)
        and battle.charIndex >= battle.total then return battle end
    if battle.current and battle.charIndex >= battle.total then U.tap(game, "a") end
    return nil
  end, 3600)
  if not check("Master Ball catch leaves the authentic locked-ball result",
      caughtMessage ~= nil) then finish(); return end
  if renderer == "BATTLE_ART_FULL" then
    local caughtShot = overworldBattle.shot()
    check("Battle Art FULL remains live through the caught result",
      caughtShot and caughtShot.canvas and battle.dramaticShapeShot)
  end
  check("caught-Mew screenshot",
    caughtMessage and U.shot(game,
      dir .. "/11_mew_caught_" .. rendererTag .. ".png"))

  local fieldAfterCatch = waitFor(function()
    local top = game.stack:top()
    if top == game.overworld and battle and battle.result == "caught" then return top end
    if getmetatable(top) == ChoiceBox then
      top.index = 2 -- no nickname for the authored Mew
      U.tap(game, "a")
    elseif top == battle then
      U.tap(game, "a")
    elseif top and top.pages and (top.waiting or top.done) then
      U.tap(game, "a")
    end
    return nil
  end, 7200)
  if not check("real battle resolves caught and returns to Route 24",
      fieldAfterCatch ~= nil) then finish(); return end

  local finalState = ascendant.state()
  local mewCount, externalCount = countMew(game.save)
  check("only the provenance-marked battle completes the investigation",
    finalState.mewCaught == true and finalState.mewStage == 4
      and finalState.mewAuthoredCatch == true
      and finalState.mewRepairDecision == "authored")
  check("authored catch grants the Myth Seeker achievement",
    finalState.achievements.mew_found == true)
  check("external Mew and newly caught authored Mew coexist",
    mewCount == 2 and externalCount == 1)
  check("caught runtime object is removed from the live field",
    liveNpc(ascendantData.mew.name) == nil)
  check("repair/catch path preserved all non-Mew progress",
    game.save.money == 123456
      and legendSignature(postgame.state()) == baselineLegend
      and researchSignature(finalState) == baselineResearch
      and finalState.rocketStage == #ascendantData.rocket
      and finalState.metrics.qaMewProvenance == 650011)

  check("final native save succeeds", game:writeSave())
  local loaded = SaveData.load(version)
  check("final native save reloads", loaded ~= nil)
  if loaded then game:restoreSave(loaded, false); U.wait(40) end
  local reloadedState = ascendant.state()
  mewCount, externalCount = countMew(game.save)
  check("save/reload retains external and authored Mew separately",
    mewCount == 2 and externalCount == 1)
  check("save/reload retains authored provenance and one-time achievement",
    reloadedState.mewCaught == true and reloadedState.mewStage == 4
      and reloadedState.mewAuthoredCatch == true
      and reloadedState.mewRepairDecision == "authored"
      and reloadedState.achievements.mew_found == true)
  check("save/reload retains one consumed Master Ball",
    game.save.inventory.MASTER_BALL == masterBefore - 1)
  check("save/reload does not respawn completed Route 24 Mew",
    game.overworld.map.id == "ROUTE_24" and liveNpc(ascendantData.mew.name) == nil)
  check("post-reload field screenshot",
    U.shot(game, dir .. "/12_post_reload_route24.png"))

  finish()
end
