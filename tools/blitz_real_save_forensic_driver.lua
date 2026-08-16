-- Read-only forensic run against a workspace clone of BLITZ' packaged slot 7.
-- The source path must never point at the live pokemon-love2d identity.  All
-- mutations below are process-local and the run uses a disposable LÖVE
-- identity, so migration/archive writes cannot touch the player's originals.

return function(game)
  local U = dofile(assert(os.getenv("KA_TEST_UTIL"), "KA_TEST_UTIL required"))
  local source = assert(os.getenv("KA_SOURCE_SAVE"), "KA_SOURCE_SAVE required")
  local optionSource = assert(os.getenv("KA_SOURCE_OPTIONS"),
    "KA_SOURCE_OPTIONS required")
  local outDir = assert(os.getenv("SHOT_DIR"), "SHOT_DIR required")
  local identity = assert(os.getenv("POKEPORT_IDENTITY"), "POKEPORT_IDENTITY required")
  assert(identity:find("ka%-blitz%-real%-save%-authority", 1, false),
    "refusing to run outside the disposable BLITZ forensic identity")
  assert(not source:find("Application Support/pokemon%-love2d/saves", 1, false),
    "refusing to load the player's live slot path")
  assert(not optionSource:find("Application Support/pokemon%-love2d/options", 1, false),
    "refusing to load the player's live options path")
  local snapshotRoot = "/qa/blitz_real_save_forensic_20260812/source_snapshot/"
  assert(source:find(snapshotRoot .. "slot7_original_readonly.lua", 1, true),
    "refusing any save input except the immutable QA slot7 snapshot")
  assert(optionSource:find(
      snapshotRoot .. "options_original_readonly.lua", 1, true),
    "refusing any options input except the immutable QA options snapshot")

  local checks, failures, rows = 0, 0, {}
  local function check(label, ok, detail)
    checks = checks + 1
    ok = ok and true or false
    if not ok then failures = failures + 1 end
    rows[#rows + 1] = table.concat({
      ok and "PASS" or "FAIL", label, tostring(detail or ""),
    }, "|")
    return ok
  end
  local function info(label, detail)
    rows[#rows + 1] = table.concat({ "INFO", label, tostring(detail or "") }, "|")
  end

  local engineVersion = require("src.core.Version").engine
  local runtimeSource = love and love.filesystem
    and love.filesystem.getSource and love.filesystem.getSource() or nil
  local function receiptSha(name)
    local value = tostring(os.getenv(name) or "")
    return value:match("^[0-9a-f][0-9a-f]+$") and #value == 64
      and value or nil
  end
  check("immutable package gate requested",
    os.getenv("KA_PACKAGE_GATE") == "1", os.getenv("KA_PACKAGE_GATE"))
  check("engine payload is stamped 0.1.79",
    engineVersion == "0.1.79", engineVersion)
  check("engine runs from materialized package root",
    type(runtimeSource) == "string"
      and runtimeSource:find("/private/tmp/ka%-blitz%-package%-gate%.") ~= nil,
    runtimeSource)
  for _, name in ipairs({
    "KA_ENGINE_PAYLOAD_SHA256", "KA_AUTHORITY_PACKAGE_SHA256",
    "KA_DEUTSCH_PACKAGE_SHA256", "KA_DRAMALESS_PACKAGE_SHA256",
    "KA_FIRST_PERSON_PACKAGE_SHA256",
  }) do
    check(name .. " receipt present", receiptSha(name) ~= nil,
      os.getenv(name))
  end

  local loaded = assert(loadfile(source))()
  assert(type(loaded) == "table", "cloned slot did not return a save table")
  game:restoreSave(loaded, false)
  -- Options are identity-global in the product and therefore are not part of
  -- slot7.lua. Apply the separately cloned options in memory so this run uses
  -- BLITZ' actual Crystal/Full-Voxel choices. Any controller reacting by
  -- persisting derived state can write only inside the disposable identity;
  -- the player's packaged identity is neither selected nor opened for write.
  local clonedOptions = assert(loadfile(optionSource))()
  local clonedAscendant = clonedOptions.modOptions
    and clonedOptions.modOptions.kanto_ascendant
  assert(type(clonedAscendant) == "table", "cloned Ascendant options missing")
  local function copy(value, seen)
    if type(value) ~= "table" then return value end
    seen = seen or {}
    if seen[value] then return seen[value] end
    local out = {}; seen[value] = out
    for key, item in pairs(value) do out[copy(key, seen)] = copy(item, seen) end
    return out
  end
  -- The follower editor persists its per-save selection/count and then
  -- mirrors those rows into identity-global options on save.loaded. Preserve
  -- that already-restored authority instead of letting a stale global count
  -- (the packaged file says 3; BLITZ' slot says 1) change this forensic run.
  local restoredAscendant = copy(game.mods.modOptions.kanto_ascendant or {})
  local effectiveClone = copy(clonedAscendant)
  for _, key in ipairs({
    "follower_count", "follower_order", "yellow_partner_presentation",
  }) do
    if restoredAscendant[key] ~= nil then
      effectiveClone[key] = restoredAscendant[key]
    end
  end
  game.mods.modOptions.kanto_ascendant = effectiveClone
  game.save.options = game.save.options or {}
  game.save.options.modOptions = game.save.options.modOptions or {}
  game.save.options.modOptions.kanto_ascendant = copy(effectiveClone)
  for key, value in pairs(effectiveClone) do
    game.mods.events:emit("mod.options_changed", {
      mod = "kanto_ascendant", key = key, value = value, game = game,
    })
  end
  U.wait(180)

  local exports = assert(game.mods and game.mods.exports, "mod exports missing")
  local ascendant = assert(exports.kanto_ascendant,
    "Kanto Ascendant did not load")
  local mods = assert(game.mods.mods, "loader inventory missing")
  local authority = assert(mods.kanto_ascendant, "Authority inventory missing")
  check("single Authority path", authority.path == "mods/0000_kanto_ascendant",
    authority.path)
  check("German closure loaded", exports.deutsch ~= nil
      or (mods.deutsch and mods.deutsch.enabled and not mods.deutsch.failed),
    mods.deutsch and mods.deutsch.path)
  check("FULL-Voxel dependency loaded", exports.DRAMALESS_SHAPE ~= nil,
    mods.DRAMALESS_SHAPE and mods.DRAMALESS_SHAPE.path)
  check("approved First-Person compatibility dependency loaded",
    mods.ds_fp_ceiling and mods.ds_fp_ceiling.enabled
      and not mods.ds_fp_ceiling.failed,
    mods.ds_fp_ceiling and mods.ds_fp_ceiling.path)
  check("standalone Wilds physically absent", mods.overworld_wild_spawns == nil)
  check("standalone shiny indicators physically absent", mods.shiny_indicators == nil)
  check("mod loader has no boot failures", #(game.mods.errors or {}) == 0,
    table.concat(game.mods.errors or {}, ";"))
  check("source slot restored at Pallet",
    game.overworld and game.overworld.map.id == "PALLET_TOWN"
      and game.overworld.player.cellX == 5 and game.overworld.player.cellY == 6,
    game.overworld and (game.overworld.map.id .. ":"
      .. tostring(game.overworld.player.cellX) .. ","
      .. tostring(game.overworld.player.cellY)))

  -- Natural restore only: no teleport, onMapEntered call or controller refresh
  -- is allowed before this observation.
  local NativeFollower = require("src.world.PikachuFollower")
  local native = assert(ascendant.singleFollower,
    "Ascendant follower controller missing")
  local function followerReceipt()
    local current = NativeFollower.current(game.overworld)
    local count = 0
    for _, npc in ipairs(game.overworld and game.overworld.npcs or {}) do
      if npc.pikachuFollower then count = count + 1 end
    end
    return current, count
  end
  check("CrystalAnimation.install reached",
    ascendant.crystalAnimation and ascendant.crystalAnimation.game == game,
    ascendant.crystalAnimation and ascendant.crystalAnimation.game)
  check("johtoMasters.install reached",
    ascendant.johtoMasters and ascendant.johtoMasters.game == game,
    ascendant.johtoMasters and ascendant.johtoMasters.game)
  check("singleFollower.install reached",
    native.active == true and native.game == game,
    tostring(native.active) .. ":" .. tostring(native.game))
  local selected, selectedSlot, selectedReason =
    ascendant.followerSelection.active(game)
  local follower, followerCount = followerReceipt()
  check("natural follower controller active", native.active == true,
    native.external)
  check("natural follower selection is healthy lead",
    selected == game.save.party[1] and selectedSlot == 1
      and selectedReason == "party_first_healthy",
    selected and selected.species)
  check("natural restore spawned exactly one follower",
    follower ~= nil and followerCount == 1,
    (follower and follower.followerSpecies or "nil") .. ":" .. followerCount)
  check("natural follower is Alakazam",
    follower and follower.followerSpecies == "ALAKAZAM",
    follower and follower.followerSpecies)
  check("natural follower screenshot",
    U.shot(game, outDir .. "/01_natural_pallet_follower.png"))

  -- Real save + untouched saved Crystal options on two real UI screens.
  local effective = game.mods.modOptions
    and game.mods.modOptions.kanto_ascendant or {}
  check("cloned global Crystal style active",
    effective.pokemon_sprite_style == "crystal",
    effective.pokemon_sprite_style)
  check("saved Crystal motion active", effective.crystal_animation ~= false,
    effective.crystal_animation)

  local SummaryMenu = require("src.ui.SummaryMenu")
  local lead = assert(game.save.party[1], "BLITZ save has no lead")
  local summary = SummaryMenu.new(game, lead)
  local summaryState = summary.__ascendantCrystalV15
  check("summary attached Crystal animation", summaryState ~= nil,
    lead.species)
  if summaryState then
    local first = summaryState.frame
    game.stack:push(summary)
    check("summary frame A", U.shot(game, outDir .. "/02_summary_frame_a.png"))
    for _ = 1, 360 do
      if summaryState.frame ~= first then break end
      U.wait(1)
    end
    check("summary animation advanced", summaryState.frame ~= first,
      tostring(first) .. "->" .. tostring(summaryState.frame))
    check("summary frame B", U.shot(game, outDir .. "/03_summary_frame_b.png"))
    while game.stack:top() and game.stack:top() ~= game.overworld do
      game.stack:pop()
    end
  end

  local DexEntryMenu = require("src.ui.DexEntryMenu")
  local dex = DexEntryMenu.new(game, lead.species)
  local dexState = dex.__ascendantCrystalV15
  check("Pokedex attached Crystal animation", dexState ~= nil, lead.species)
  if dexState then
    local first = dexState.frame
    game.stack:push(dex)
    check("Pokedex frame A", U.shot(game, outDir .. "/04_dex_frame_a.png"))
    for _ = 1, 360 do
      if dexState.frame ~= first then break end
      U.wait(1)
    end
    check("Pokedex animation advanced", dexState.frame ~= first,
      tostring(first) .. "->" .. tostring(dexState.frame))
    check("Pokedex frame B", U.shot(game, outDir .. "/05_dex_frame_b.png"))
    while game.stack:top() and game.stack:top() ~= game.overworld do
      game.stack:pop()
    end
  end

  -- Title is a separate scene surface. Select the first authored animated
  -- witness from the real title cycle instead of manufacturing a species.
  -- The cloned packaged options remain the authority for all style toggles.
  local TitleState = require("src.ui.TitleState")
  while game.stack:top() do game.stack:pop() end
  local title = TitleState.new(game, { onNewGame = function() end })
  title.phase = "loop"
  title.scrollPhase = "hold"
  title.timer = 0
  game.stack:push(title)
  local function titleBeat(label, trainer)
    local image = title:currentSprite()
    return check(label,
      title.kaTitlePhase == "pair"
        and title.kaTitleTrainerId == trainer
        and title.player ~= nil and image ~= nil,
      table.concat({ tostring(title.kaTitlePhase),
        tostring(title.kaTitleTrainerId), tostring(title.player ~= nil),
        tostring(image ~= nil) }, ":"))
  end
  local function nextTitleBeat()
    -- The real engine's 240-frame HOLD reset is the title movie's only
    -- synchronization edge. Place it on frame 239 and call the fully wrapped
    -- update once; no controller API or phase field is toggled directly.
    title.phase = "loop"
    title.scrollPhase = "hold"
    title.timer = 239
    title:update(1 / 60)
  end
  titleBeat("title rhythm starts GREEN + Pokemon", "GREEN")
  check("title GREEN pair screenshot",
    U.shot(game, outDir .. "/10b_title_green_first_beat.png"))
  nextTitleBeat()
  titleBeat("title rhythm GREEN pair -> BLUE pair", "BLUE")

  local titleIndex, titleDiagnostics
  titleDiagnostics = {}
  for index in ipairs(title.cycleSpecies or {}) do
    title.cycleIndex = index
    title.__ascendantCrystalV15Title = nil
    title:currentSprite()
    local candidate = title.__ascendantCrystalV15Title
    titleDiagnostics[#titleDiagnostics + 1] = table.concat({
      tostring(title.cycleSpecies[index]),
      candidate and tostring(candidate.dex) or "nil",
      candidate and tostring(candidate.animated) or "nil",
    }, ":")
    if candidate and candidate.animated then titleIndex = index break end
  end
  check("title cycle has an authored Crystal animation", titleIndex ~= nil,
    table.concat(titleDiagnostics, ","))
  if titleIndex then
    title.cycleIndex = titleIndex
    title.__ascendantCrystalV15Title = nil
    title.timer = 0
    local firstImage, titleTrueColor = title:currentSprite()
    local titleState = title.__ascendantCrystalV15Title
    check("title attached Crystal animation", titleState ~= nil,
      title.cycleSpecies[titleIndex])
    check("title Crystal frame is true colour",
      firstImage ~= nil and titleTrueColor == true
        and titleState and titleState.trueColor == true,
      titleTrueColor)
    if titleState then
      local firstFrame = titleState.frame
      local firstDuration = tonumber(titleState.durations
        and titleState.durations[firstFrame])
      local expectedFrames = firstDuration
        and math.max(1, math.ceil(firstDuration / (1000 / 60))) or nil
      check("title uses authored Crystal rhythm",
        titleState.authoredTiming == true
          and type(titleState.durations) == "table"
          and #titleState.durations > 1
          and firstDuration and firstDuration > 0,
        tostring(firstDuration) .. "ms/" .. tostring(expectedFrames) .. "f")
      if firstDuration then title:update((firstDuration - 1) / 1000) end
      check("title holds frame until authored dwell boundary",
        titleState.frame == firstFrame,
        tostring(firstFrame) .. "->" .. tostring(titleState.frame)
          .. " before " .. tostring(firstDuration) .. "ms")
      title:update(2 / 1000)
      check("title advances at authored dwell boundary",
        titleState.frame ~= firstFrame,
        tostring(firstFrame) .. "->" .. tostring(titleState.frame)
          .. " near " .. tostring(firstDuration) .. "ms")
      check("title frame A",
        U.shot(game, outDir .. "/11_title_crystal_frame_a.png"))
      local shownFrame = titleState.frame
      local shownDuration = tonumber(titleState.durations[shownFrame]) or 100
      title:update((shownDuration + 1) / 1000)
      check("title Crystal animation advanced",
        titleState.frame ~= shownFrame,
        tostring(shownFrame) .. "->" .. tostring(titleState.frame))
      check("title frame B",
        U.shot(game, outDir .. "/12_title_crystal_frame_b.png"))
    end
  end
  check("title BLUE pair screenshot",
    U.shot(game, outDir .. "/12b_title_blue_second_beat.png"))
  nextTitleBeat()
  titleBeat("title rhythm BLUE pair -> RED pair", "RED")
  check("title RED pair screenshot",
    U.shot(game, outDir .. "/12d_title_red_third_beat.png"))
  nextTitleBeat()
  titleBeat("title rhythm loops RED pair -> GREEN pair", "GREEN")
  check("title GREEN pair loop screenshot",
    U.shot(game, outDir .. "/12c_title_green_loop_beat.png"))
  while game.stack:top() do game.stack:pop() end

  -- Real Indigo transition with no direct host registration call.
  U.teleport(game, "INDIGO_PLATEAU_LOBBY", 9, 7, "up")
  U.wait(120)
  local masterData = assert(ascendant.johtoMastersData,
    "Johto Masters data missing")
  local function hostReceipt()
    local definitions, liveHosts = 0, 0
    for _, obj in ipairs(game.data.maps[masterData.map].objects or {}) do
      if obj.name == masterData.name or obj.text == masterData.textId then
        definitions = definitions + 1
      end
    end
    for _, npc in ipairs(game.overworld.npcs or {}) do
      local def = npc.def or {}
      if def.name == masterData.name or def.text == masterData.textId then
        liveHosts = liveHosts + 1
      end
    end
    return definitions, liveHosts
  end
  local definitions, liveHosts = hostReceipt()
  check("Johto host has one map definition", definitions == 1, definitions)
  check("Johto host spawned once after real map transition", liveHosts == 1,
    liveHosts)
  local transitionFollower, transitionFollowerCount = followerReceipt()
  check("follower survives the real Indigo transition",
    transitionFollower and transitionFollower.followerSpecies == "ALAKAZAM"
      and transitionFollowerCount == 1,
    (transitionFollower and transitionFollower.followerSpecies or "nil")
      .. ":" .. transitionFollowerCount)
  local cadence = ascendant.johtoMasters.state(false)
  local johtoCadenceReceipt = type(cadence) == "table" and table.concat({
    "attempts=" .. tostring(cadence.attempts),
    "clears=" .. tostring(cadence.clears),
    "gifts=" .. tostring(cadence.gifts),
    "title=" .. tostring(cadence.title == true),
    "silver=" .. tostring(cadence.passages
      and cadence.passages.silver and cadence.passages.silver.status),
    "kris=" .. tostring(cadence.passages
      and cadence.passages.kris and cadence.passages.kris.status),
    "gold=" .. tostring(cadence.passages
      and cadence.passages.gold and cadence.passages.gold.status),
  }, ";") or "unavailable"
  check("current Johto cadence state is readable",
    type(cadence) == "table"
      and type(cadence.attempts) == "number"
      and type(cadence.clears) == "number",
    johtoCadenceReceipt)
  check("Johto host screenshot",
    U.shot(game, outDir .. "/06_indigo_johto_host.png"))

  -- Exercise the engine's actual map reload seam. It rebuilds the NPC pool,
  -- emits both map.entered and map.reloaded, and is therefore a stronger
  -- follower/host lifecycle receipt than directly calling either controller.
  game.overworld:reloadMap(masterData.map, "blitz-authority-forensic")
  U.wait(120)
  local reloadedDefinitions, reloadedHosts = hostReceipt()
  local reloadedFollower, reloadedFollowerCount = followerReceipt()
  check("Johto host remains singular after map reload",
    reloadedDefinitions == 1 and reloadedHosts == 1,
    tostring(reloadedDefinitions) .. ":" .. tostring(reloadedHosts))
  check("follower respawns exactly once after map reload",
    reloadedFollower and reloadedFollower.followerSpecies == "ALAKAZAM"
      and reloadedFollowerCount == 1,
    (reloadedFollower and reloadedFollower.followerSpecies or "nil")
      .. ":" .. reloadedFollowerCount)
  check("Indigo reload screenshot",
    U.shot(game, outDir .. "/06b_indigo_reload_host_follower.png"))

  -- FULL-Voxel battle proof with the save's actual Alakazam. This proves the
  -- battle clock independently of the dedicated Gorochu renderer.
  local BattleState = require("src.battle.BattleState")
  local Pipelines = require("src.render.Pipelines")
  local dramatic = assert(exports.DRAMALESS_SHAPE,
    "FULL-Voxel export missing")
  local overworldBattle = assert(dramatic.lib.require("OverworldBattle"),
    "OverworldBattle missing")
  Pipelines.setLevel("voxel", 2)
  U.wait(3)
  Pipelines.setLevel("voxel", 1)
  Pipelines.syncOptions(game.save.options or {})
  overworldBattle.setting:setIndex(1, game)
  overworldBattle.backSetting:setIndex(1, game)
  U.teleport(game, "ROUTE_1", 5, 5, "down")
  U.wait(45)

  local function closeBattle()
    while game.stack:top() and game.stack:top() ~= game.overworld do
      game.stack:pop()
    end
    U.wait(20)
  end

  local function reachMenu(battle)
    for _ = 1, 1200 do
      if battle.phase == "menu" then return true end
      U.tap(game, "a")
      U.wait(3)
    end
    return battle.phase == "menu"
  end

  local wild = BattleState.newWild(game, "SLOWPOKE", 70)
  wild.onFinish = function() end
  game.overworld:pushBattle(wild)
  check("Alakazam Voxel battle reached menu", reachMenu(wild), wild.phase)
  local wildAnimation = wild.player and wild.player.__ascendantCrystalAnimation
  check("battle attached Crystal animation", wildAnimation ~= nil,
    wild.player and wild.player.mon.species)
  if wildAnimation then
    local first = wildAnimation.frame
    local firstSource = overworldBattle.sideTexture(wild, "player")
    firstSource = firstSource and firstSource.kantoAscendantGorochuSource
    check("battle frame A", U.shot(game, outDir .. "/07_battle_frame_a.png"))
    for _ = 1, 360 do
      if wildAnimation.frame ~= first then break end
      U.wait(1)
    end
    check("battle animation advanced", wildAnimation.frame ~= first,
      tostring(first) .. "->" .. tostring(wildAnimation.frame))
    check("battle frame B", U.shot(game, outDir .. "/08_battle_frame_b.png"))
  end
  closeBattle()

  -- Put the save's one real Gorochu in front in memory only. In a trainer
  -- battle the early card must remain Red's back; Gorochu may appear only
  -- after the actual send-out.
  local gorochuIndex
  for index, mon in ipairs(game.save.party or {}) do
    if mon.species == "GOROCHU" then gorochuIndex = index break end
  end
  check("save contains exactly one current-party Gorochu", gorochuIndex ~= nil,
    gorochuIndex)
  if gorochuIndex then
    game.save.party[1], game.save.party[gorochuIndex] =
      game.save.party[gorochuIndex], game.save.party[1]
    local battle = BattleState.newTrainer(game, "OPP_LORELEI", 1)
    battle.onFinish = function() end
    game.overworld:pushBattle(battle)
    for _ = 1, 720 do
      if game.stack:top() == battle and battle.showPlayerBack
          and battle.showEnemyTrainer and (battle.introSlide or 1) <= 0 then
        break
      end
      U.wait(1)
    end
    local introTexture = overworldBattle.sideTexture(battle, "player")
    check("trainer intro phase reached",
      battle.showPlayerBack == true and battle.showEnemyTrainer == true,
      tostring(battle.showPlayerBack) .. ":"
        .. tostring(battle.showEnemyTrainer))
    check("trainer intro keeps its character card",
      introTexture and (introTexture.trainer == true
        or introTexture.ascendantStandingTrainer ~= nil),
      introTexture and (introTexture.ascendantStandingTrainer
        or tostring(introTexture.trainer)))
    check("Gorochu absent before real send-out",
      introTexture and introTexture.kantoAscendantGorochuSupersampled == nil,
      introTexture and introTexture.kantoAscendantGorochuSource)
    check("trainer intro screenshot",
      U.shot(game, outDir .. "/09_gorochu_trainer_intro.png"))
    check("Gorochu trainer battle reached menu", reachMenu(battle), battle.phase)
    local deployed = overworldBattle.sideTexture(battle, "player")
    check("Gorochu appears after send-out",
      deployed and deployed.kantoAscendantGorochuSupersampled == true,
      deployed and deployed.kantoAscendantGorochuSource)
    check("deployed Gorochu is not a trainer card",
      deployed and deployed.trainer ~= true,
      deployed and deployed.trainer)
    check("deployed Gorochu screenshot",
      U.shot(game, outDir .. "/10_gorochu_after_sendout.png"))
    local animation = battle.player and battle.player.__ascendantCrystalAnimation
    if animation then
      local first = animation.frame
      for _ = 1, 360 do
        if animation.frame ~= first then break end
        U.wait(1)
      end
      check("Gorochu Voxel animation advances", animation.frame ~= first,
        tostring(first) .. "->" .. tostring(animation.frame))
    else
      check("Gorochu Voxel animation advances", false, "clock missing")
    end
    closeBattle()

    -- Hall of Fame is another independent presentation surface. Use the
    -- cloned save's one real Gorochu (already first only in process memory),
    -- not a synthesized test Pokemon, and leave the FULL-Voxel setting on.
    local HallOfFame = require("src.ui.HallOfFame")
    local hall = HallOfFame.new(game, function() end)
    game.stack:push(hall)
    for _ = 1, 240 do
      if hall.phase == "mons" and hall.index == 1
          and hall.scrollX >= 96 then break end
      U.wait(1)
    end
    check("Hall of Fame settled on real Gorochu",
      hall.phase == "mons" and hall.index == 1
        and game.save.party[1].species == "GOROCHU",
      tostring(hall.phase) .. ":" .. tostring(hall.index))
    local hallState = hall.__ascendantCrystalV15Hall
      and hall.__ascendantCrystalV15Hall.GOROCHU
    check("Hall of Fame attached Gorochu Crystal animation",
      hallState ~= nil, hallState and hallState.frame)
    if hallState then
      local firstFrame = hallState.frame
      local firstImage = hall:spriteFor("GOROCHU")
      local trueColor = hall.spriteTrueColors
          and hall.spriteTrueColors.GOROCHU == true
        or hall.__ascendantCrystalV15HallTrueColors
          and hall.__ascendantCrystalV15HallTrueColors[firstImage] == true
      check("Hall of Fame Gorochu is true colour", trueColor, firstImage)
      check("Hall of Fame frame A",
        U.shot(game, outDir .. "/13_gorochu_hof_frame_a.png"))
      for _ = 1, 360 do
        if hallState.frame ~= firstFrame then break end
        U.wait(1)
      end
      check("Hall of Fame Crystal animation advanced",
        hallState.frame ~= firstFrame,
        tostring(firstFrame) .. "->" .. tostring(hallState.frame))
      check("Hall of Fame frame B",
        U.shot(game, outDir .. "/14_gorochu_hof_frame_b.png"))
    end
    while game.stack:top() and game.stack:top() ~= game.overworld do
      game.stack:pop()
    end
  end

  -- Cross-cutting character presentation is intentionally part of the same
  -- immutable package process.  It runs after the untouched BLITZ receipts,
  -- so its disposable hero/party/style mutations cannot mask save restore,
  -- follower, Johto-host, Crystal or Gorochu evidence above.
  local presentationMatrix = assert(loadfile(assert(
    os.getenv("KA_CHARACTER_MATRIX"), "KA_CHARACTER_MATRIX required")))()
  check("six-character presentation runtime matrix completed",
    presentationMatrix({
      game = game, U = U, check = check, info = info,
      outDir = outDir, ascendant = ascendant,
    }) == true)

  local result = assert(io.open(outDir .. "/driver_result.txt", "wb"))
  result:write((failures == 0 and "PASS" or "FAIL")
    .. " checks=" .. checks .. " failures=" .. failures .. "\n")
  result:write("identity=" .. identity .. "\n")
  result:write("source_save_clone=" .. source .. "\n")
  result:write("source_options_clone=" .. optionSource .. "\n")
  result:write("source_save_sha256="
    .. tostring(os.getenv("KA_SOURCE_SAVE_SHA256") or "unprovided") .. "\n")
  result:write("source_options_sha256="
    .. tostring(os.getenv("KA_SOURCE_OPTIONS_SHA256") or "unprovided") .. "\n")
  result:write("authority_path=" .. tostring(authority.path) .. "\n")
  result:write("authority_version="
    .. tostring(authority.manifest and authority.manifest.version) .. "\n")
  result:write("deutsch_version=" .. tostring(mods.deutsch
    and mods.deutsch.manifest and mods.deutsch.manifest.version) .. "\n")
  result:write("dramaless_version=" .. tostring(mods.DRAMALESS_SHAPE
    and mods.DRAMALESS_SHAPE.manifest
    and mods.DRAMALESS_SHAPE.manifest.version) .. "\n")
  result:write("engine_version=" .. tostring(engineVersion) .. "\n")
  result:write("runtime_source=" .. tostring(runtimeSource) .. "\n")
  result:write("engine_payload_sha256="
    .. tostring(os.getenv("KA_ENGINE_PAYLOAD_SHA256")) .. "\n")
  result:write("authority_package_sha256="
    .. tostring(os.getenv("KA_AUTHORITY_PACKAGE_SHA256")) .. "\n")
  result:write("deutsch_package_sha256="
    .. tostring(os.getenv("KA_DEUTSCH_PACKAGE_SHA256")) .. "\n")
  result:write("dramaless_package_sha256="
    .. tostring(os.getenv("KA_DRAMALESS_PACKAGE_SHA256")) .. "\n")
  result:write("first_person_package_sha256="
    .. tostring(os.getenv("KA_FIRST_PERSON_PACKAGE_SHA256")) .. "\n")
  result:write("johto_cadence_status=" .. johtoCadenceReceipt .. "\n")
  result:write("johto_cadence_scope=status-only; no farm/traversal claimed\n")
  for _, row in ipairs(rows) do result:write(row .. "\n") end
  result:close()
  U.log("BLITZ REAL SAVE FORENSIC", failures == 0 and "PASS" or "FAIL",
    checks, failures, outDir)
  love.event.quit(failures == 0 and 0 or 1)
end
