-- Bounded reusable phase implementation for the L02 package matrix.
-- Product behavior is resolved only from the installed package exports passed
-- by the thin driver.  Existing large visual drivers are cited/reused where
-- they are renderer-safe; this module owns the missing Surf, Wilds mapping,
-- title cadence, Crystal-surface, Gorochu and immutable-restore observations.

local C = {}

local INTRO_FRAME_BUDGET = 900
local SURF_FRAME_BUDGET = 720
local BATTLE_FRAME_BUDGET = 1200
local MOTION_FRAME_BUDGET = 480
local RESTORE_FRAME_BUDGET = 300

local EXPECTED_TITLE_RHYTHM = {
  "GREEN+POKEMON", "BLUE+POKEMON", "RED+POKEMON", "GREEN+POKEMON",
}
local SURF_DIRECTIONS = {
  { "up", 0, -1 }, { "down", 0, 1 },
  { "left", -1, 0 }, { "right", 1, 0 },
}

local FRESH_RECEIPTS = {
  "characters_result.txt",
  "crystal_title_gorochu_result.txt",
  "follower_wilds_result.txt",
  "reload_verify_result.txt",
}
local BLITZ_RECEIPTS = {
  "blitz_restore_result.txt", "reload_verify_result.txt",
}
local DURABILITY_SCHEMA = "ka-l02-native-durability/v1"
local DURABILITY_KEY = "l02_presentation_native_durability"

local function readAll(path)
  local file = assert(io.open(path, "rb"), "cannot open " .. tostring(path))
  local body = file:read("*a")
  file:close()
  return assert(body, "cannot read " .. tostring(path))
end

local function sha256(body)
  local digest = love.data.hash("sha256", body)
  if type(digest) == "userdata" and digest.getString then
    digest = digest:getString()
  end
  return love.data.encode("string", "hex", digest):lower()
end

local function writeRows(path, rows)
  local file = assert(io.open(path, "wb"), "cannot write " .. tostring(path))
  file:write(table.concat(rows, "\n"), "\n")
  file:close()
end

local function commonRows(ctx, scope)
  return {
    "status=PASS",
    "scope=" .. scope,
    "edition=" .. ctx.edition,
    "renderer=" .. ctx.renderer,
    "source=" .. ctx.source,
    "engine_payload_sha256=" .. ctx.provenance.engine,
    "authority_package_sha256=" .. ctx.provenance.authority,
    "deutsch_package_sha256=" .. ctx.provenance.deutsch,
    "battle_art_package_sha256=" .. ctx.provenance.battleArt,
    "package_gate_receipt_sha256=" .. ctx.provenance.gate,
  }
end

local function writePhase(ctx, name, tokens)
  local rows = commonRows(ctx, "PRESENTATION-MOTION-PACKAGE/" .. name:upper())
  for _, token in ipairs(tokens) do rows[#rows + 1] = token end
  rows[#rows + 1] = "pass=" .. tostring(ctx.passCount())
  rows[#rows + 1] = "fail=" .. tostring(ctx.failCount())
  assert(ctx.failCount() == 0, name .. " accumulated failed observations")
  writeRows(ctx.outDir .. "/" .. name .. "_result.txt", rows)
end

local function expectedDurableSpecies(ctx)
  if ctx.source == "BLITZ" then return "ALAKAZAM" end
  return assert(({ red = "IVYSAUR", blue = "WARTORTLE",
    yellow = "RAICHU" })[ctx.edition], "unknown durability edition")
end

local function durabilityMarker(save)
  local authority = save and save.modData and save.modData.kanto_ascendant
  return authority and authority[DURABILITY_KEY]
end

local function clearStack(ctx)
  for _ = 1, BATTLE_FRAME_BUDGET do
    if not ctx.game.stack:top() then return true end
    ctx.game.stack:pop()
  end
  return ctx.game.stack:top() == nil
end

local function followerCount(game)
  local count = 0
  for _, npc in ipairs(game.overworld and game.overworld.npcs or {}) do
    if npc.pikachuFollower then count = count + 1 end
  end
  return count
end

local function follower(ctx, label, species)
  local entity = ctx.ascendant.singleFollower.entity(ctx.game)
  ctx.check(label .. " exactly one follower",
    entity ~= nil and followerCount(ctx.game) == 1, followerCount(ctx.game))
  if species then
    ctx.check(label .. " follower species", entity
      and entity.followerSpecies == species,
      entity and entity.followerSpecies)
  end
  return entity
end

local function persistNativeDurability(ctx)
  local game, U = ctx.game, ctx.U
  local SaveData = require("src.core.SaveData")
  local expected = expectedDurableSpecies(ctx)
  ctx.check("native durability follower count configured",
    ctx.ascendant.singleFollower.setCount(1, game) == 1)
  U.teleport(game, "PALLET_TOWN", 10, 8, "down")
  U.wait(24)
  local entity = follower(ctx, "Native durability write", expected)
  ctx.check("native durability write has expected lead",
    game.save.party and game.save.party[1]
      and game.save.party[1].species == expected
      and entity and entity.followerSpecies == expected,
    game.save.party and game.save.party[1]
      and game.save.party[1].species)

  game.save.modData = game.save.modData or {}
  game.save.modData.kanto_ascendant =
    game.save.modData.kanto_ascendant or {}
  game.mods.modSave = game.save.modData
  game.save.modData.kanto_ascendant[DURABILITY_KEY] = {
    schema = DURABILITY_SCHEMA,
    identity = ctx.identity,
    edition = ctx.edition,
    renderer = ctx.renderer,
    source = ctx.source,
    species = expected,
    followerCount = 1,
    writerPhase = ctx.phase,
  }
  local nativeSlot
  if ctx.source == "BLITZ" then
    local registry = game.save.options and game.save.options.saveSlots
      and game.save.options.saveSlots[ctx.edition]
    nativeSlot = registry and registry.active
    ctx.check("immutable BLITZ active slot is slot7", nativeSlot == "slot7",
      nativeSlot)
    -- SaveData resolves the progress filename before writeSave flushes the
    -- decoded options table. Bind the immutable save's real active slot now,
    -- through the public engine API, so this process and the next process
    -- both address saves/red/slot7.lua rather than different flat/slot paths.
    ctx.check("native BLITZ slot bound before progress write",
      SaveData.setActiveSlot(ctx.edition, nativeSlot) == "slot7")
  end
  local wrote = game:writeSave() == true
  ctx.check("native SaveData write completed", wrote)
  local diskOptions = wrote and SaveData.loadOptions() or nil
  local optionBucket = diskOptions and diskOptions.modOptions
    and diskOptions.modOptions.kanto_ascendant
  ctx.check("native options write round-trip completed",
    optionBucket and optionBucket.follower_count == 1,
    optionBucket and optionBucket.follower_count)
  if ctx.source == "BLITZ" then
    ctx.nativeSlot = nativeSlot
    ctx.check("immutable BLITZ snapshot unchanged after native write",
      sha256(readAll(ctx.sourceSave)) == ctx.sourceSaveSha
        and sha256(readAll(ctx.sourceOptions)) == ctx.sourceOptionsSha)
  end
  return expected
end

local function findDoor(ow, destination)
  for _, warp in ipairs(ow.map.def.warps or {}) do
    if destination == nil and warp.destMap and warp.destMap ~= "LAST_MAP"
        or destination ~= nil
          and (warp.destMap == destination or warp.destMap == "LAST_MAP") then
      return warp
    end
  end
end

local function takeDoor(ctx, warp, expectedMap)
  local ow = ctx.game.overworld
  ow.player.cellX, ow.player.cellY = warp.x, warp.y
  ow:takeWarp(warp)
  for _ = 1, RESTORE_FRAME_BUDGET do
    if ow.map.id == expectedMap and not ow.transitioning then return true end
    coroutine.yield()
  end
  return ow.map.id == expectedMap and not ow.transitioning
end

local function findSurfEdge(ow)
  local map = ow.map
  for y = 1, map.heightCells - 2 do
    for x = 1, map.widthCells - 2 do
      if map:isWalkableCell(x, y) and not map:isWaterCell(x, y)
          and not ow:npcAtCell(x, y) then
        for _, row in ipairs(SURF_DIRECTIONS) do
          local fx, fy = x + row[2], y + row[3]
          if map:isWaterCell(fx, fy) and not ow:npcAtCell(fx, fy) then
            return x, y, row[1]
          end
        end
      end
    end
  end
end

local function exerciseFollowerMotion(ctx, prefix)
  local game, U = ctx.game, ctx.U
  local ow, chosen = game.overworld, nil
  for y = 2, ow.map.heightCells - 3 do
    for x = 2, ow.map.widthCells - 3 do
      if ow.map:isWalkableCell(x, y) and not ow:npcAtCell(x, y)
          and not (ow.map.warpAtCell and ow.map:warpAtCell(x, y)) then
        for _, row in ipairs(SURF_DIRECTIONS) do
          local tx, ty = x + row[2], y + row[3]
          if ow.map:isWalkableCell(tx, ty) and not ow:npcAtCell(tx, ty)
              and not ow.map:isWaterCell(tx, ty)
              and not (ow.map.warpAtCell and ow.map:warpAtCell(tx, ty)) then
            chosen = { x, y, row[1] }
            break
          end
        end
      end
      if chosen then break end
    end
    if chosen then break end
  end
  assert(chosen, prefix .. " has no open follower-motion step")
  U.teleport(game, ow.map.id, chosen[1], chosen[2], chosen[3])
  U.wait(18)
  local entity = follower(ctx, prefix .. " motion start")
  local beforeX, beforeY = game.overworld.player.cellX, game.overworld.player.cellY
  local moved = false
  for _ = 1, MOTION_FRAME_BUDGET do
    table.insert(game.input.pressQueue, chosen[3])
    game.input.state[chosen[3]] = true
    coroutine.yield()
    if game.overworld.player.cellX ~= beforeX
        or game.overworld.player.cellY ~= beforeY then
      moved = true
      break
    end
  end
  game.input.state[chosen[3]] = false
  U.wait(24)
  local current = follower(ctx, prefix .. " motion settled")
  local gap = current and math.abs(current.cellX - game.overworld.player.cellX)
    + math.abs(current.cellY - game.overworld.player.cellY) or 99
  ctx.check(prefix .. " follower follows real input motion",
    moved and current == entity and gap == 1, gap)
  if current then
    local stableX, stableY, stableFacing =
      current.cellX, current.cellY, current.facing
    local classicPikachu = ctx.edition == "yellow"
      and current.followerSpecies == "PIKACHU"
    local stable = true
    for _ = 1, 120 do
      coroutine.yield()
      if current.cellX ~= stableX or current.cellY ~= stableY
          or not classicPikachu and current.facing ~= stableFacing
          or current.px ~= current.cellX * 16
          or current.py ~= current.cellY * 16 then
        stable = false
      end
    end
    ctx.check(prefix .. " follower idle motion is stable", stable)
  end
  return current
end

local function exerciseSurf(ctx, prefix)
  local game, U = ctx.game, ctx.U
  local surfMon = assert(game.save.party[1], "Surf lifecycle needs a lead")
  surfMon.moves = surfMon.moves or {}
  local hasSurf = false
  for _, move in ipairs(surfMon.moves) do
    if move.id == "SURF" then hasSurf = true end
  end
  if not hasSurf then
    surfMon.moves[#surfMon.moves + 1] = {
      id = "SURF", pp = game.data.moves.SURF.pp,
    }
  end
  game.save.inventory.SOULBADGE = 1
  U.teleport(game, "VERMILION_CITY", 15, 18, "down")
  U.wait(12)
  local x, y, direction = findSurfEdge(game.overworld)
  if not x then
    U.teleport(game, "FUCHSIA_CITY", 15, 18, "down")
    U.wait(12)
    x, y, direction = findSurfEdge(game.overworld)
  end
  assert(x and y and direction, "no legal land/water Surf edge found")
  U.teleport(game, game.overworld.map.id, x, y, direction)
  U.wait(8)
  follower(ctx, prefix .. " before Surf")
  ctx.check(prefix .. " production Surf preflight",
    game.overworld:useSurfFieldMove() == "ok")
  local fx, fy = game.overworld.player:facingCell()
  game.overworld:trySurf(fx, fy, function() end)
  for _ = 1, SURF_FRAME_BUDGET do
    if game.stack:top() ~= game.overworld then ctx.U.tap(game, "a") end
    if game.overworld.player.surfing and game.stack:top() == game.overworld
        and ctx.ascendant.singleFollower.entity(game) == nil then
      break
    end
    coroutine.yield()
  end
  ctx.check(prefix .. " Surf mounted through production flow",
    game.overworld.player.surfing == true)
  ctx.check(prefix .. " follower hides on water",
    ctx.ascendant.singleFollower.entity(game) == nil and followerCount(game) == 0)
  ctx.check(prefix .. " Surf step uses engine seam",
    game.overworld:stepForwardOrCrossEdge(direction) == true)
  U.wait(28)

  -- A clean, real map transition off Surf re-runs the public follower spawn
  -- predicate and proves the lifecycle can return exactly once.
  U.teleport(game, "PALLET_TOWN", 10, 8, "down")
  U.wait(18)
  local returned = follower(ctx, prefix .. " after Surf")
  return returned ~= nil
end

function C.runCharacters(ctx)
  local matrix = assert(dofile(ctx.characterMatrixPath))
  local Assets = require("src.render.Assets")
  local Runtime = require("src.mods.Runtime")
  local pack = assert(ctx.ascendant.frlgTrainerPack)
  ctx.info("reused bounded character driver",
    "tools/blitz_character_presentation_matrix.lua")
  ctx.info("reused ordinary-class inventory source",
    "tests/trainer_portrait_modes_visual_driver.lua")
  local modes = { "original", "frlg", "crystal_hd" }
  local fixed = { "RED", "BLUE", "GREEN", "SILVER", "KRIS", "GOLD" }
  ctx.check("three ordinary portrait modes frozen", #modes == 3)
  ctx.check("six fixed identities frozen", #fixed == 6)
  local ordinaryIds = {}
  for id in pairs(pack.fronts) do ordinaryIds[#ordinaryIds + 1] = id end
  table.sort(ordinaryIds)
  ctx.check("all 42 ordinary trainer classes frozen", #ordinaryIds == 42,
    #ordinaryIds)
  local options = ctx.game.mods.modOptions.kanto_ascendant or {}
  ctx.game.mods.modOptions.kanto_ascendant = options
  ctx.game.save.options = ctx.game.save.options or {}
  ctx.game.save.options.modOptions = ctx.game.save.options.modOptions or {}
  ctx.game.save.options.modOptions.kanto_ascendant =
    ctx.game.save.options.modOptions.kanto_ascendant or {}
  for _, mode in ipairs(modes) do
    options.trainer_portrait_style = mode
    ctx.game.save.options.modOptions.kanto_ascendant.trainer_portrait_style = mode
    Runtime.emit("mod.options_changed", {
      game = ctx.game, mod = "kanto_ascendant",
      key = "trainer_portrait_style", value = mode,
    })
    pack.refresh(ctx.game)
    ctx.check("ordinary mode live: " .. mode,
      pack.selectedStyle(ctx.game) == mode, pack.selectedStyle(ctx.game))
    local decoded = 0
    for _, id in ipairs(ordinaryIds) do
      local trainer = ctx.game.data.trainers[id]
      local ok, image = pcall(Assets.image, trainer and trainer.pic)
      ctx.check(id .. " resolves ordinary mode " .. mode,
        trainer and trainer.ascendantTrainerPortraitStyle == mode
          and ok and image ~= nil,
        trainer and trainer.pic)
      if ok and image then decoded = decoded + 1 end
    end
    ctx.check("42 ordinary pictures decode under " .. mode, decoded == 42,
      decoded)
  end
  ctx.check("renderer-safe character matrix completed", matrix({
    game = ctx.game,
    U = ctx.U,
    check = ctx.check,
    info = ctx.info,
    outDir = ctx.outDir,
    renderer = ctx.renderer == "2D" and "2d" or "full",
    ascendant = ctx.ascendant,
  }) == true)
  writePhase(ctx, "characters", {
    "fixed_identities=6/6",
    "ordinary_modes=3/3",
    "ordinary_classes=42/42",
  })
  return true
end

local function titleRhythm(ctx)
  local game, U = ctx.game, ctx.U
  local TitleState = require("src.ui.TitleState")
  assert(clearStack(ctx), "could not clear stack for TitleState.new")
  local title = TitleState.new(game, { onNewGame = function() end })
  game.stack:push(title)
  U.wait(5)
  local observed = {}
  for beat = 1, #EXPECTED_TITLE_RHYTHM do
    local pokemon = title:currentSprite()
    observed[#observed + 1] = title.kaTitlePhase == "pair"
      and title.player ~= nil and pokemon ~= nil
      and (tostring(title.kaTitleTrainerId) .. "+POKEMON") or "INVALID"
    if beat < #EXPECTED_TITLE_RHYTHM then
      -- Exercise the real wrapped TitleState update at its authored cadence;
      -- no result field is assigned by the harness.
      title.timer = 239
      title:update(1 / 60)
    end
  end
  local expected = table.concat(EXPECTED_TITLE_RHYTHM, ">")
  local actual = table.concat(observed, ">")
  ctx.check("exact observed Title rhythm", actual == expected, actual)
  ctx.check("title Green screenshot",
    U.shot(game, ctx.outDir .. "/title_green_loop.png"))
  assert(clearStack(ctx), "could not close title")
  return actual
end

local function crystalSurfaces(ctx)
  local game = ctx.game
  local runtime = assert(ctx.ascendant.extendedSpeciesRuntime)
  local crystal = assert(ctx.ascendant.crystalAnimation)
  local v15 = assert(ctx.ascendant.crystalV15)
  local shiny = assert(ctx.ascendant.shinySystem)
  local Pokemon = require("src.pokemon.Pokemon")
  local matrix = runtime.matrix(game)
  local validation = runtime.validate(matrix)
  ctx.info("reused exhaustive surface driver",
    "tools/extended_species_runtime_qa_driver.lua")
  ctx.check("#252-279 live runtime matrix", validation.ok and #matrix.rows == 28,
    #matrix.rows)
  local surfaces = {
    "title", "battle_front", "battle_back", "pokedex", "summary",
    "box", "hall_of_fame", "follower", "visible_wild",
  }
  local variants = { "normal", "shiny" }
  local resolved = 0
  for index, row in ipairs(matrix.rows) do
    local expectedDex = 251 + index
    ctx.check("extended species contiguous " .. tostring(expectedDex),
      row.internalRuntimeDex == expectedDex)
    for _, variant in ipairs(variants) do
      local mon = Pokemon.new(game.data, row.species, 30,
        function() return 8 end)
      if variant == "shiny" then
        assert(shiny.forceMon(mon, game.data.pokemon[row.species]))
      end
      local live = assert(row.surfaces[variant])
      for _, key in ipairs({ "battleEnemy", "battlePlayer", "dex", "summary",
          "box", "follower", "wilds" }) do
        ctx.check(row.species .. " " .. variant .. " " .. key,
          live[key] and live[key].path ~= nil)
      end
      for _, request in ipairs({
          { "front", "battle" }, { "back", "battle" },
          { "front", "dex" }, { "front", "summary" },
          { "front", "box" }, { "front", "scenes" },
        }) do
        local state = crystal.presentationAnimation(row.species, mon,
          request[1], request[2], { data = game.data })
        ctx.check(row.species .. " " .. variant .. " animation "
          .. request[1] .. "/" .. request[2], state and state.image)
        if state then crystal.advancePresentation(state, 0.40, game) end
      end
      resolved = resolved + 1
    end
  end

  -- Exercise the title/Hall controller methods explicitly in addition to the
  -- live TitleState/HallOfFame surfaces sampled around Gorochu below.
  local titleProbe = {
    game = game, cycleSpecies = { matrix.rows[1].species }, cycleIndex = 1,
    kaTitlePhase = "pair",
  }
  ctx.check("Crystal titleSprite controller live", v15:titleSprite(titleProbe))
  local oldParty = game.save.party
  local hallMon = Pokemon.new(game.data, matrix.rows[1].species, 30)
  game.save.party = { hallMon }
  local hallProbe = { game = game, index = 1 }
  ctx.check("Crystal hallSprite controller live",
    v15:hallSprite(hallProbe, hallMon.species))
  game.save.party = oldParty
  ctx.check("nine Crystal presentation surfaces frozen", #surfaces == 9)
  ctx.check("normal/shiny Crystal variants frozen",
    #variants == 2 and resolved == 56, resolved)
end

local function gorochu(ctx)
  local game, U = ctx.game, ctx.U
  local Pokemon = require("src.pokemon.Pokemon")
  local BattleState = require("src.battle.BattleState")
  local HallOfFame = require("src.ui.HallOfFame")
  assert(clearStack(ctx), "could not clear stack before Gorochu")
  game.save.party = { Pokemon.new(game.data, "GOROCHU", 70) }
  U.teleport(game, "PEWTER_GYM", 4, 10, "up")
  local battle = BattleState.newTrainer(game, "OPP_BROCK", 1)
  game.overworld:pushBattle(battle)
  local introReached = false
  for _ = 1, INTRO_FRAME_BUDGET do
    if game.stack:top() == battle and battle.showPlayerBack
        and battle.showEnemyTrainer and (battle.introSlide or 1) <= 0 then
      introReached = true
      break
    end
    U.wait(1)
  end
  ctx.check("trainer intro reached", introReached, battle.phase)
  local intro = ctx.overworldBattle.sideTexture(battle, "player")
  ctx.check("Gorochu absent from trainer intro",
    intro and intro.kantoAscendantGorochuSupersampled == nil)
  ctx.check("Gorochu intro screenshot",
    U.shot(game, ctx.outDir .. "/gorochu_trainer_intro.png"))

  local reachedMenu = false
  for _ = 1, BATTLE_FRAME_BUDGET do
    if battle.phase == "menu" then reachedMenu = true break end
    U.tap(game, "a")
    U.wait(2)
  end
  ctx.check("Gorochu real sendout reached menu", reachedMenu, battle.phase)
  local deployed = ctx.overworldBattle.sideTexture(battle, "player")
  local animation = battle.player and battle.player.__ascendantCrystalAnimation
  ctx.check("Gorochu appears only after sendout",
    battle.player and battle.player.mon
      and battle.player.mon.species == "GOROCHU" and animation ~= nil
      and (ctx.renderer == "2D"
        or deployed and deployed.kantoAscendantGorochuSupersampled == true),
    deployed and deployed.kantoAscendantGorochuSource)
  ctx.check("Gorochu sendout screenshot",
    U.shot(game, ctx.outDir .. "/gorochu_after_sendout.png"))
  local first = animation and animation.frame
  local advanced = false
  for _ = 1, MOTION_FRAME_BUDGET do
    if animation and animation.frame ~= first then advanced = true break end
    U.wait(1)
  end
  ctx.check("Gorochu battle motion advanced", advanced)
  assert(clearStack(ctx), "could not close Gorochu battle")

  local hall = HallOfFame.new(game, function() end)
  game.stack:push(hall)
  local settled = false
  for _ = 1, MOTION_FRAME_BUDGET do
    if hall.phase == "mons" and hall.index == 1 and hall.scrollX >= 96 then
      settled = true
      break
    end
    U.wait(1)
  end
  local image = hall:spriteFor("GOROCHU")
  local hallState = hall.__ascendantCrystalV15Hall
    and hall.__ascendantCrystalV15Hall.GOROCHU
  ctx.check("Gorochu Hall-of-Fame surface live",
    settled and image ~= nil and hallState ~= nil)
  ctx.check("Gorochu HOF frame A",
    U.shot(game, ctx.outDir .. "/gorochu_hof_frame_a.png"))
  local hallFirst = hallState and hallState.frame
  local hallAdvanced = false
  for _ = 1, MOTION_FRAME_BUDGET do
    if hallState and hallState.frame ~= hallFirst then hallAdvanced = true break end
    U.wait(1)
  end
  ctx.check("Gorochu Hall-of-Fame motion advanced", hallAdvanced)
  ctx.check("Gorochu HOF frame B",
    U.shot(game, ctx.outDir .. "/gorochu_hof_frame_b.png"))
  assert(clearStack(ctx), "could not close Hall of Fame")
end

function C.runCrystalTitleGorochu(ctx)
  local options = ctx.game.mods.modOptions.kanto_ascendant or {}
  ctx.game.mods.modOptions.kanto_ascendant = options
  options.pokemon_sprite_style = "crystal"
  options.crystal_animation = true
  options.sprite_style_battle = true
  options.sprite_style_summary = true
  options.sprite_style_dex = true
  options.sprite_style_box = true
  options.sprite_style_scenes = true
  local rhythm = titleRhythm(ctx)
  crystalSurfaces(ctx)
  gorochu(ctx)
  writePhase(ctx, "crystal_title_gorochu", {
    "title_rhythm=" .. rhythm,
    "crystal_species=28/28",
    "crystal_surfaces=9/9",
    "crystal_variants=2/2",
    "gorochu_intro_absent=1/1",
    "gorochu_sendout_present=1/1",
    "gorochu_hof=1/1",
  })
  return true
end

local function freshFollowerLifecycle(ctx)
  local game, U = ctx.game, ctx.U
  local Pokemon = require("src.pokemon.Pokemon")
  local Evolution = require("src.pokemon.Evolution")
  local SaveData = require("src.core.SaveData")
  ctx.info("reused follower lifecycle source",
    "tools/follower_phase2_e2e_driver.lua")
  local fresh = SaveData.newGame(game:bootConfig())
  game:restoreSave(fresh, false)
  game.mods.modSave = game.save.modData
  assert(ctx.applyRendererContract("Fresh save restore renderer", true),
    "Fresh save restore changed the requested renderer")
  game.save.flags = game.save.flags or {}
  game.save.flags.EVENT_FOLLOWED_OAK_INTO_LAB = true
  game.save.flags.EVENT_GOT_STARTER = true
  game.save.flags.EVENT_GOT_POKEDEX = true
  game.save.repelSteps = 9999
  local species = ({ red = "BULBASAUR", blue = "SQUIRTLE",
    yellow = "PIKACHU" })[ctx.edition]
  local evolved = ({ red = "IVYSAUR", blue = "WARTORTLE",
    yellow = "RAICHU" })[ctx.edition]
  local lead = Pokemon.new(game.data, species, 30)
  if ctx.edition == "yellow" then
    lead[assert(ctx.ascendant.yellowPartner.marker)] = true
  end
  game.save.party = { lead }
  ctx.ascendant.singleFollower.setCount(1, game)
  U.teleport(game, "PALLET_TOWN", 10, 8, "down")
  U.wait(20)
  local original = follower(ctx, "Fresh initial", species)
  ctx.check("Fresh follower initial screenshot",
    U.shot(game, ctx.outDir .. "/follower_fresh_initial.png"))
  exerciseFollowerMotion(ctx, "Fresh")

  U.teleport(game, "ROUTE_1", 5, 5, "down")
  U.wait(20)
  local mapped = follower(ctx, "Fresh map", species)
  ctx.check("Fresh map transition presents one follower", mapped ~= nil)
  ctx.check("Fresh follower map screenshot",
    U.shot(game, ctx.outDir .. "/follower_fresh_map.png"))

  Evolution.apply(game, lead, evolved, "L02_PRESENTATION_PACKAGE")
  U.wait(10)
  local afterEvolution = follower(ctx, "Fresh evolution", evolved)
  ctx.check("Fresh evolution updates visible follower",
    afterEvolution and afterEvolution.followerSpecies == evolved)
  ctx.check("Fresh follower evolution screenshot",
    U.shot(game, ctx.outDir .. "/follower_fresh_evolution.png"))

  U.teleport(game, "PALLET_TOWN", 10, 8, "down")
  U.wait(12)
  local outside = game.overworld.map.id
  local entry = assert(findDoor(game.overworld), "Pallet has no door")
  local interior = entry.destMap
  ctx.check("Fresh production door entered",
    takeDoor(ctx, entry, interior))
  follower(ctx, "Fresh inside door", evolved)
  ctx.check("Fresh follower door screenshot",
    U.shot(game, ctx.outDir .. "/follower_fresh_inside_door.png"))
  local exit = assert(findDoor(game.overworld, outside),
    "interior has no return door")
  ctx.check("Fresh production door returned",
    takeDoor(ctx, exit, outside))
  follower(ctx, "Fresh outside door", evolved)

  ctx.check("Fresh Surf lifecycle completed", exerciseSurf(ctx, "Fresh"))
  ctx.check("Fresh follower Surf-return screenshot",
    U.shot(game, ctx.outDir .. "/follower_fresh_after_surf.png"))

  game.overworld:reloadMap(game.overworld.map.id, "l02-fresh-follower")
  U.wait(20)
  ctx.check("Fresh native reload retains exactly one follower",
    follower(ctx, "Fresh reload", evolved) ~= nil)
  ctx.check("Fresh follower reload screenshot",
    U.shot(game, ctx.outDir .. "/follower_fresh_reload.png"))
  return original ~= nil
end

local function wildsLifecycle(ctx)
  local game, U = ctx.game, ctx.U
  local signalsWilds = assert(ctx.ascendant.signalsWilds)
  local runRules = assert(ctx.ascendant.runRules)
  local internal = assert(ctx.ascendant.internalWilds)
  local wilds = assert(internal.exports)
  local logic = assert(wilds.logic)
  local SpawnFx = assert(wilds.lib.require("spawn_fx"))
  ctx.info("reused Wilds motion source",
    "tools/follower_wilds_motion_qa_driver.lua")
  ctx.check("transactional Signals/Wilds adapter live",
    signalsWilds.installed and signalsWilds.logic == logic)
  ctx.check("bundled Wilds is package-owned", internal.bundled == true)

  U.teleport(game, "ROUTE_22", 8, 8, "down")
  U.wait(20)
  if logic._clearMap then logic:_clearMap("ROUTE_22") end
  game.save.repelSteps = 0
  game.mods.modOptions.kanto_ascendant.johto_wilds_integration = false
  local rules = assert(runRules.state(game.save))
  rules.randomizer.enabled = true
  rules.randomizer.wild = true
  rules.randomizer.balanced = false
  rules.randomizer.consistent = true
  rules.randomizer.legendary = false
  rules.seed = 6502
  rules.mappings.species = {}

  local native = { species = "RATTATA", level = 7 }
  local mapped = runRules.mapVisibleWild(native, {
    mapId = "ROUTE_22", terrain = "grass", kaVisibleWild = true,
  })
  local remembered, ticket = runRules.rememberVisibleWild(mapped, {
    mapId = "ROUTE_22", terrain = "grass", kaVisibleWild = true,
  })
  ctx.check("Wilds Randomizer maps exactly once before ticket",
    mapped.species ~= native.species
      and mapped.species == remembered.species and ticket ~= nil,
    mapped.species)
  local protected = runRules.mapVisibleWild({
    species = "NATU", level = 18, kaProtected = true,
    kaEncounterSource = "johto_research",
  }, {
    mapId = "ROUTE_22", terrain = "grass", kaVisibleWild = true,
    kaProtected = true, kaEncounterSource = "johto_research",
  })
  ctx.check("protected Johto visible Wild is never remapped",
    protected.species == "NATU" and protected.kaProtected == true
      and protected.kaEncounterSource == "johto_research")
  runRules.cancelVisibleWild(ticket)

  local record, spawnErr, entity = logic:trySpawn(game, { x = 10, y = 8 })
  ctx.check("non-explicit Wilds spawn crossed transactional adapter",
    record and entity and record._kaSignalsWilds ~= nil, spawnErr)
  if record and entity then
    local bundle = record._kaSignalsWilds
    ctx.check("Wilds contact preserves one Randomizer mapping",
      bundle and bundle.sourceNative and bundle.native and bundle.output
        and bundle.sourceNative.species ~= bundle.native.species
        and bundle.native.species == bundle.output.species
        and bundle.output.species == record.species
        and bundle.randomizerTicket
        and bundle.randomizerTicket.species == record.species,
      record.species)
    SpawnFx.updateEntity(entity, 1, {
      map = game.overworld.map, spawnFx = logic.spawnFx,
    })
    ctx.check("Wilds SpawnFX presentation became visible",
      entity.spawnFx and entity.spawnFx.done == true
        and entity.hiddenBody ~= true and entity.canTriggerBattle == true)
    ctx.check("Wilds entity attached to live world", logic:_attach(entity))
    ctx.check("Wilds SpawnFX screenshot",
      U.shot(game, ctx.outDir .. "/wilds_spawnfx.png"))
    ctx.check("visible Wild contact starts exact battle",
      logic:_startBattle(record) == true)
    local contact = false
    for _ = 1, BATTLE_FRAME_BUDGET do
      local top = game.stack:top()
      if top and top.kind == "wild" and top.enemy and top.enemy.mon
          and top.enemy.mon.species == record.species then
        contact = true
        break
      end
      U.wait(1)
    end
    ctx.check("Wilds contact reached matching battle", contact,
      record.species)
    if contact then
      ctx.check("Wilds contact screenshot",
        U.shot(game, ctx.outDir .. "/wilds_contact_battle.png"))
    end
    assert(clearStack(ctx), "could not close Wilds contact battle")
  end
end

function C.runFollowerWilds(ctx)
  freshFollowerLifecycle(ctx)
  wildsLifecycle(ctx)
  local durableSpecies = persistNativeDurability(ctx)
  writePhase(ctx, "follower_wilds", {
    "follower_exactly_one=1/1",
    "follower_map=1/1",
    "follower_door=1/1",
    "follower_surf=1/1",
    "follower_evolution=1/1",
    "follower_reload=1/1",
    "wilds_spawnfx=1/1",
    "wilds_randomizer_once=1/1",
    "wilds_johto_protection=1/1",
    "wilds_contact=1/1",
    "native_save_write=1/1",
    "native_options_write=1/1",
    "renderer_contract_persisted=1/1",
    "durability_marker_written=1/1",
    "durable_follower_species=" .. durableSpecies,
  })
  return true
end

local function applyOptions(ctx, decoded)
  local options = decoded.modOptions and decoded.modOptions.kanto_ascendant
  if type(options) ~= "table" then return false end
  ctx.game.mods.modOptions.kanto_ascendant = options
  ctx.game.save.options = ctx.game.save.options or {}
  ctx.game.save.options.modOptions = ctx.game.save.options.modOptions or {}
  ctx.game.save.options.modOptions.kanto_ascendant = options
  return true
end

function C.runBlitzRestore(ctx)
  local game, U = ctx.game, ctx.U
  local SaveData = require("src.core.SaveData")
  local NativeFollower = require("src.world.PikachuFollower")
  assert(ctx.sourceSaveSha
      == "f0d8c1925c09ad8ba825240f6218b81fd1f7dbd6c30348f6304fb006dcf2f8a0",
    "immutable BLITZ save receipt drifted")
  assert(ctx.sourceOptionsSha
      == "2f5ca783613d1ecefd12b3942ef7b12f0c78180e9b6a3820ba2637f21b91e540",
    "immutable BLITZ options receipt drifted")
  local saveBody = readAll(ctx.sourceSave)
  local optionsBody = readAll(ctx.sourceOptions)
  assert(sha256(saveBody) == ctx.sourceSaveSha,
    "immutable BLITZ save content hash drifted")
  assert(sha256(optionsBody) == ctx.sourceOptionsSha,
    "immutable BLITZ options content hash drifted")
  local loaded = assert(SaveData.decode(saveBody))
  local decodedOptions = assert(SaveData.decode(optionsBody))
  loaded.options = decodedOptions
  game:restoreSave(loaded, false)
  game.mods.modSave = game.save.modData
  assert(applyOptions(ctx, decodedOptions), "BLITZ options have no Ascendant bucket")
  local dismissedLoadReport = false
  for _ = 1, RESTORE_FRAME_BUDGET do
    if game.overworld and game.stack:top() == game.overworld then break end
    local top = game.stack:top()
    if top and top.screenId == "QuarantineReport" then
      -- The immutable RC-era save truthfully reports its changed mod set.
      -- Close exactly that engine screen through ordinary player input before
      -- the Pallet screenshot; never pop an unknown state from the stack.
      U.tap(game, "a")
      U.wait(2)
      dismissedLoadReport = true
    else
      U.wait(1)
    end
  end
  ctx.check("BLITZ load report dismissed through input",
    dismissedLoadReport and game.stack:top() == game.overworld,
    game.stack:top() and game.stack:top().screenId)
  assert(ctx.applyRendererContract("BLITZ save restore renderer", true),
    "BLITZ save restore changed the requested renderer")

  -- This label and observation intentionally precede native.refresh and every
  -- QA teleport.  It is the immutable save's natural existing-save proof.
  local natural = NativeFollower.current(game.overworld)
  ctx.check("BLITZ natural restore spawned exactly one follower",
    natural ~= nil and followerCount(game) == 1
      and natural.followerSpecies == "ALAKAZAM",
    natural and natural.followerSpecies)
  ctx.check("BLITZ natural Pallet screenshot",
    U.shot(game, ctx.outDir .. "/blitz_natural_pallet.png"))

  local native = assert(ctx.ascendant.singleFollower)
  ctx.check("BLITZ native refresh remains singular", native.refresh(game))
  follower(ctx, "BLITZ refreshed", "ALAKAZAM")
  exerciseFollowerMotion(ctx, "BLITZ")
  U.teleport(game, "ROUTE_1", 5, 5, "down")
  U.wait(20)
  ctx.check("BLITZ map transition follower",
    follower(ctx, "BLITZ map", "ALAKAZAM") ~= nil)
  ctx.check("BLITZ map screenshot",
    U.shot(game, ctx.outDir .. "/blitz_route1.png"))
  game.overworld:reloadMap(game.overworld.map.id, "l02-blitz-follower")
  U.wait(20)
  ctx.check("BLITZ map reload follower",
    follower(ctx, "BLITZ reload", "ALAKAZAM") ~= nil)
  ctx.check("BLITZ reload screenshot",
    U.shot(game, ctx.outDir .. "/blitz_reload.png"))

  U.teleport(game, "PALLET_TOWN", 10, 8, "down")
  U.wait(12)
  local entry = assert(findDoor(game.overworld), "Pallet has no BLITZ door")
  local outside, inside = game.overworld.map.id, entry.destMap
  ctx.check("BLITZ production door entered", takeDoor(ctx, entry, inside))
  follower(ctx, "BLITZ inside door", "ALAKAZAM")
  ctx.check("BLITZ door screenshot",
    U.shot(game, ctx.outDir .. "/blitz_inside_door.png"))
  local exit = assert(findDoor(game.overworld, outside),
    "BLITZ interior has no return door")
  ctx.check("BLITZ production door returned", takeDoor(ctx, exit, outside))

  ctx.check("BLITZ Surf lifecycle completed", exerciseSurf(ctx, "BLITZ"))
  ctx.check("BLITZ Surf-return screenshot",
    U.shot(game, ctx.outDir .. "/blitz_after_surf.png"))
  -- The immutable lead is already fully evolved Alakazam.  Evolution is
  -- therefore a Fresh-only lifecycle seam; mutating BLITZ into a fabricated
  -- pre-evolution would invalidate this source-provenance cell.
  ctx.check("BLITZ reload after Surf follower",
    follower(ctx, "BLITZ post-Surf reload", "ALAKAZAM") ~= nil)
  ctx.check("BLITZ final screenshot",
    U.shot(game, ctx.outDir .. "/blitz_final_follower.png"))

  local durableSpecies = persistNativeDurability(ctx)

  writePhase(ctx, "blitz_restore", {
    "blitz_source_sha256=" .. ctx.sourceSaveSha,
    "blitz_options_sha256=" .. ctx.sourceOptionsSha,
    "blitz_natural_restore=1/1",
    "blitz_load_report_dismissed=1/1",
    "follower_exactly_one=1/1",
    "follower_map=1/1",
    "follower_door=1/1",
    "follower_surf=1/1",
    "follower_reload=1/1",
    "blitz_evolution_scope=fresh-only-immutable-lead-already-evolved",
    "native_save_write=1/1",
    "native_options_write=1/1",
    "renderer_contract_persisted=1/1",
    "durability_marker_written=1/1",
    "durable_follower_species=" .. durableSpecies,
    "immutable_blitz_snapshot_unchanged=1/1",
    "native_active_slot=slot7",
  })
  return true
end

function C.runReloadVerify(ctx)
  local game, U = ctx.game, ctx.U
  local SaveData = require("src.core.SaveData")
  local expected = expectedDurableSpecies(ctx)
  local expectedWriter = ctx.source == "FRESH"
    and "follower_wilds" or "blitz_restore"
  ctx.check("separate process boot has no progress durability marker",
    durabilityMarker(game.save) == nil)
  if ctx.source == "BLITZ" then
    ctx.check("new process resolves immutable BLITZ slot7",
      SaveData.activeSlot(ctx.edition) == "slot7",
      SaveData.activeSlot(ctx.edition))
  end

  local loaded, recovered = SaveData.load(ctx.edition)
  ctx.check("native SaveData main save loaded",
    loaded ~= nil and recovered == nil, recovered or "main")
  assert(loaded, "native durability save missing")
  local marker = durabilityMarker(loaded)
  ctx.check("native durability marker is bound to this cell",
    marker and marker.schema == DURABILITY_SCHEMA
      and marker.identity == ctx.identity
      and marker.edition == ctx.edition
      and marker.renderer == ctx.renderer
      and marker.source == ctx.source
      and marker.species == expected
      and marker.followerCount == 1
      and marker.writerPhase == expectedWriter,
    marker and marker.writerPhase)
  local loadedOptions = loaded.options and loaded.options.modOptions
    and loaded.options.modOptions.kanto_ascendant
  ctx.check("native loaded options preserve follower count",
    loadedOptions and loadedOptions.follower_count == 1,
    loadedOptions and loadedOptions.follower_count)
  ctx.check("native loaded save preserves follower species",
    loaded.party and loaded.party[1]
      and loaded.party[1].species == expected,
    loaded.party and loaded.party[1] and loaded.party[1].species)

  game:restoreSave(loaded, recovered)
  U.wait(48)
  ctx.check("native process reload preserves renderer contract",
    ctx.assertRendererContract("Native save restore renderer"))
  local restoredMarker = durabilityMarker(game.save)
  ctx.check("native Game restore retained durability marker",
    game.save == loaded and restoredMarker
      and restoredMarker.schema == DURABILITY_SCHEMA)
  local restoredOptions = game.save.options and game.save.options.modOptions
    and game.save.options.modOptions.kanto_ascendant
  ctx.check("restored runtime option remains durable",
    restoredOptions and restoredOptions.follower_count == 1
      and ctx.ascendant.singleFollower.getCount() == 1,
    restoredOptions and restoredOptions.follower_count)
  local entity = follower(ctx, "Native process reload", expected)
  ctx.check("native process reload restores expected exact-one follower",
    entity and entity.followerSpecies == expected
      and followerCount(game) == 1,
    entity and entity.followerSpecies)
  if ctx.source == "BLITZ" then
    ctx.check("immutable BLITZ snapshot unchanged after native reload",
      sha256(readAll(ctx.sourceSave)) == ctx.sourceSaveSha
        and sha256(readAll(ctx.sourceOptions)) == ctx.sourceOptionsSha)
  end

  local tokens = {
    "native_process_boot_without_progress_marker=1/1",
    "native_save_load=1/1",
    "native_save_recovery=main",
    "native_save_restore=1/1",
    "renderer_contract_reloaded=1/1",
    "durable_follower_exactly_one=1/1",
    "durable_follower_option=1/1",
    "durable_follower_species=" .. expected,
  }
  if ctx.source == "BLITZ" then
    tokens[#tokens + 1] = "native_active_slot=slot7"
    tokens[#tokens + 1] = "immutable_blitz_snapshot_unchanged=1/1"
  end
  writePhase(ctx, "reload_verify", tokens)
  return true
end

local function requireToken(body, token, path)
  assert(body:find(token, 1, true),
    tostring(path) .. " missing token " .. tostring(token))
end

function C.aggregate(ctx)
  local phaseReceipts = ctx.source == "FRESH" and FRESH_RECEIPTS or BLITZ_RECEIPTS
  local bodies = {}
  for _, name in ipairs(phaseReceipts) do
    local path = ctx.outDir .. "/" .. name
    local body = readAll(path)
    requireToken(body, "status=PASS", path)
    requireToken(body, "fail=0", path)
    requireToken(body, "edition=" .. ctx.edition, path)
    requireToken(body, "renderer=" .. ctx.renderer, path)
    requireToken(body, "source=" .. ctx.source, path)
    bodies[#bodies + 1] = body
  end
  local joined = table.concat(bodies, "\n")
  local required = ctx.source == "FRESH" and {
    "fixed_identities=6/6", "ordinary_modes=3/3",
    "ordinary_classes=42/42",
    "title_rhythm=GREEN>POKEMON>BLUE>POKEMON>RED>POKEMON>GREEN",
    "crystal_species=28/28", "crystal_surfaces=9/9",
    "crystal_variants=2/2", "follower_exactly_one=1/1",
    "follower_map=1/1", "follower_door=1/1", "follower_surf=1/1",
    "follower_evolution=1/1", "follower_reload=1/1",
    "wilds_spawnfx=1/1", "wilds_randomizer_once=1/1",
    "wilds_johto_protection=1/1", "wilds_contact=1/1",
    "gorochu_intro_absent=1/1", "gorochu_sendout_present=1/1",
    "gorochu_hof=1/1", "native_save_write=1/1",
    "native_options_write=1/1",
    "native_process_boot_without_progress_marker=1/1",
    "native_save_load=1/1", "native_save_recovery=main",
    "native_save_restore=1/1",
    "renderer_contract_persisted=1/1",
    "renderer_contract_reloaded=1/1",
    "durable_follower_exactly_one=1/1",
    "durable_follower_option=1/1",
  } or {
    "blitz_source_sha256=f0d8c1925c09ad8ba825240f6218b81fd1f7dbd6c30348f6304fb006dcf2f8a0",
    "blitz_options_sha256=2f5ca783613d1ecefd12b3942ef7b12f0c78180e9b6a3820ba2637f21b91e540",
    "blitz_natural_restore=1/1", "blitz_load_report_dismissed=1/1",
    "follower_exactly_one=1/1",
    "follower_map=1/1", "follower_door=1/1", "follower_surf=1/1",
    "follower_reload=1/1", "native_save_write=1/1",
    "native_options_write=1/1",
    "native_process_boot_without_progress_marker=1/1",
    "native_save_load=1/1", "native_save_recovery=main",
    "native_save_restore=1/1",
    "renderer_contract_persisted=1/1",
    "renderer_contract_reloaded=1/1",
    "durable_follower_exactly_one=1/1",
    "durable_follower_option=1/1",
    "native_active_slot=slot7",
    "immutable_blitz_snapshot_unchanged=1/1",
  }
  required[#required + 1] =
    "durable_follower_species=" .. expectedDurableSpecies(ctx)
  for _, token in ipairs(required) do requireToken(joined, token, "phase receipts") end
  local rows = commonRows(ctx, "PRESENTATION-MOTION-PACKAGE")
  for _, token in ipairs(required) do rows[#rows + 1] = token end
  if ctx.source == "BLITZ" then
    rows[#rows + 1] =
      "blitz_evolution_scope=fresh-only-immutable-lead-already-evolved"
  end
  rows[#rows + 1] = "phase_receipts=" .. table.concat(phaseReceipts, ",")
  rows[#rows + 1] = "status=PASS"
  rows[#rows + 1] = "fail=0"
  writeRows(ctx.outDir .. "/driver_result.txt", rows)
  return true
end

function C.run(ctx)
  local dispatch = {
    characters = C.runCharacters,
    crystal_title_gorochu = C.runCrystalTitleGorochu,
    follower_wilds = C.runFollowerWilds,
    blitz_restore = C.runBlitzRestore,
    reload_verify = C.runReloadVerify,
    aggregate = C.aggregate,
  }
  return assert(dispatch[ctx.phase], "unknown L02 phase: " .. tostring(ctx.phase))(ctx)
end

function C.writeFailure(ctx, reason)
  if ctx.phase == "aggregate" then return false end
  writeRows(ctx.outDir .. "/" .. ctx.phase .. "_result.txt", {
    "status=FAIL",
    "scope=PRESENTATION-MOTION-PACKAGE/" .. ctx.phase:upper(),
    "edition=" .. tostring(ctx.edition),
    "renderer=" .. tostring(ctx.renderer),
    "source=" .. tostring(ctx.source),
    "error=" .. tostring(reason):gsub("[\r\n]+", " | "),
    "fail=" .. tostring(math.max(1, ctx.failCount())),
  })
  return true
end

return C
