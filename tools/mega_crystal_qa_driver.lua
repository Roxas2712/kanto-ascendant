-- Real-LOVE QA for Mega sprite ownership with bundled/external Crystal art.
--
-- MEGA_QA_FORM accepts any official profile id in lower-kebab form
-- (mega-venusaur, charizard-x, feraligatr, raichu-y, etc.) or
-- ascendant-typhlosion. MEGA_QA_LAYOUT=2d|voxel selects the renderer and
-- MEGA_QA_SHINY=1 selects the shiny palette. The same driver can be run with
-- Kanto Ascendant alone and with Crystal Animated Sprites loaded.
-- MEGA_QA_CRYSTAL=0 selects the static four-shade Gen-I derivative and
-- MEGA_QA_VERSION=red|blue|yellow selects its real edition palette.

return function(game)
  assert(os.getenv("KA_PACKAGE_GATE") == "1",
    "refusing Hoenn Mega acceptance outside the immutable package gate")
  local U = dofile(assert(os.getenv("KA_TEST_UTIL"),
    "KA_TEST_UTIL packaged harness path required"))
  local DIR = os.getenv("SHOT_DIR") or "/tmp/kanto-ascendant-mega-qa"
  local form = (os.getenv("MEGA_QA_FORM") or "raichu-x"):lower()
  local layout = (os.getenv("MEGA_QA_LAYOUT") or "voxel"):lower()
  local targetSide = (os.getenv("MEGA_QA_SIDE") or "player"):lower()
  local backSprites = os.getenv("MEGA_QA_BACK_SPRITES") == "1"
  local forcedShiny = os.getenv("MEGA_QA_SHINY") == "1"
  local captureBaseline = os.getenv("MEGA_QA_BASELINE") == "1"
  local crystalArt = os.getenv("MEGA_QA_CRYSTAL") ~= "0"
  local dramalessCamera = (os.getenv("MEGA_QA_DRAMALESS_CAMERA") or "fork"):lower()
  local version = (os.getenv("MEGA_QA_VERSION") or "red"):lower()
  local GameVersion = require("src.core.GameVersion")
  local PaletteFX = require("src.render.PaletteFX")
  local Pokemon = require("src.pokemon.Pokemon")
  local Sprites = require("src.pokemon.Sprites")
  local BattleState = require("src.battle.BattleState")
  local Pipelines = require("src.render.Pipelines")

  assert(GameVersion.VERSIONS[version],
    "MEGA_QA_VERSION must be red, blue or yellow")
  assert(GameVersion.get() == version,
    "Hoenn Mega package cell edition mismatch")
  game.save.options.colors = "ogred"
  PaletteFX.setMode("ogred")
  game.mods.modOptions.kanto_ascendant =
    game.mods.modOptions.kanto_ascendant or {}
  assert(dramalessCamera == "fork" or dramalessCamera == "classic"
      or dramalessCamera == "wide",
    "MEGA_QA_DRAMALESS_CAMERA must be fork, classic or wide")
  game.mods.modOptions.kanto_ascendant.dramaless_battle_camera = dramalessCamera
  game.mods.modOptions.kanto_ascendant.kanto_crystal_art = crystalArt
  game.mods.modOptions.kanto_ascendant.legend_art =
    crystalArt and "crystal" or "original"
  game.mods.modOptions.kanto_ascendant.crystal_animation = crystalArt
  U.wait(20)
  local api = assert(game.mods and game.mods.exports
    and game.mods.exports.kanto_ascendant, "Kanto Ascendant export missing")
  local mega = assert(api.megaEvolution, "Mega controller missing")
  local secret = form == "ascendant-typhlosion"
  local profile = secret and mega.secretProfile() or nil
  if not profile then
    local wanted = form:gsub("^mega%-", "")
    for _, candidate in ipairs(mega.forms) do
      local id = candidate.id:lower():gsub("_", "-")
      local asset = candidate.asset:gsub("^mega_", ""):gsub("_", "-")
      if wanted == id or wanted == asset
          or form == candidate.asset:gsub("_", "-") then
        profile = candidate
        break
      end
    end
  end
  assert(profile, "unknown MEGA_QA_FORM: " .. form)
  assert(layout == "2d" or layout == "voxel",
    "MEGA_QA_LAYOUT must be 2d or voxel")
  assert(targetSide == "player" or targetSide == "enemy",
    "MEGA_QA_SIDE must be player or enemy")
  local species = profile.species
  local profileId = profile.id
  local stone = profile.stone
  local asset = profile.asset

  Pipelines.setLevel("voxel", layout == "voxel" and 1 or 0)
  Pipelines.syncOptions(game.save.options)
  -- Prefer the maintained compatible Voxel renderer, while retaining the
  -- historical renderer in the QA matrix.
  local dramatic = game.mods.exports.DRAMALESS_SHAPE
    or game.mods.exports.DRAMATIC_SHAPE
  local overworldBattle
  if dramatic and dramatic.lib then
    overworldBattle = dramatic.lib.require("OverworldBattle")
    -- DRAMALESS setting indexes 1-4 are staged 2D/3D modes; index 5 is
    -- OFF. A classic QA pass must disable staging rather than select flatB.
    overworldBattle.setting:setIndex(layout == "voxel" and 1 or 5, game)
    overworldBattle.backSetting:setIndex(backSprites and 2 or 1, game)
  end
  local ascendant = game.mods.exports.kanto_ascendant
  if dramatic == game.mods.exports.DRAMALESS_SHAPE
      and ascendant and ascendant.dramalessCameraCompat then
    game.mods.events:emit("mod.options_changed", {
      mod = "kanto_ascendant", key = "dramaless_battle_camera",
      value = game.mods.modOptions.kanto_ascendant.dramaless_battle_camera,
    })
    local camera = dramatic and dramatic.lib.require("BattleCam")
    if dramalessCamera == "classic" then
      assert(camera and camera.RIGS and camera.RIGS.tele
          and math.abs(camera.RIGS.tele.back - 144.96) < 0.001
          and math.abs(camera.RIGS.tele.height - 37.88) < 0.001
          and math.abs(camera.RIGS.tele.frameH - (34.11 * 2)) < 0.001,
        "Classic Voxel camera did not restore the calibrated classic framing")
    elseif dramalessCamera == "wide" then
      assert(camera and camera.RIGS and camera.RIGS.tele
          and math.abs(camera.RIGS.tele.back - 144.96) < 0.001
          and math.abs(camera.RIGS.tele.height - 37.88) < 0.001
          and math.abs(camera.RIGS.tele.frameH - (34.11 * 3)) < 0.001,
        "Wide Voxel camera did not apply the extra-wide framing")
    end
  end

  game.save.flags = game.save.flags or {}
  game.save.flags.EVENT_BEAT_CHAMPION_RIVAL = true
  game.save.hallOfFame = { {} }
  game.save.pokedex = game.save.pokedex or { seen = {}, owned = {} }
  local megaState = mega.state()
  if secret then
    mega.unlockSecret()
  else
    mega.unlock(game)
    assert(mega.grantStone(stone) or mega.hasStone(stone),
      "could not grant QA stone " .. stone)
    megaState.preferences[species] = profileId
  end

  local leadSpecies = targetSide == "player" and species or "BULBASAUR"
  local foeSpecies = targetSide == "enemy" and species or "BULBASAUR"
  local lead = Pokemon.new(game.data, leadSpecies, secret and 100 or 50,
    function() return forcedShiny and 10 or 8 end)
  game.save.party = { lead }
  U.teleport(game, "ROUTE_1", 5, 5, "down")
  -- The renderer's FULL preset applies lazily on the first live overworld
  -- frame and intentionally defaults BACK SPRITES to OFF. Re-apply the test
  -- case after that preset has settled, otherwise a stored FULL profile can
  -- silently turn an ON test into OFF between setup and battler creation.
  if overworldBattle then
    overworldBattle.setting:setIndex(layout == "voxel" and 1 or 5, game)
    overworldBattle.backSetting:setIndex(backSprites and 2 or 1, game)
    assert(overworldBattle.backPinned()
        == (layout == "voxel" and backSprites),
      "Voxel renderer did not retain the requested BACK SPRITES state")
  end
  local battle = BattleState.newWild(game, foeSpecies,
    targetSide == "enemy" and (secret and 100 or 50) or 35)
  battle._ascendantQaAllowSecretEnemy =
    secret and targetSide == "enemy" or nil
  if targetSide == "enemy" and forcedShiny then
    battle.enemy.mon.dvs = battle.enemy.mon.dvs or {}
    battle.enemy.mon.dvs.attack = 10
    battle.enemy.mon.dvs.defense = 10
    battle.enemy.mon.dvs.speed = 10
    battle.enemy.mon.dvs.special = 10
  end
  battle.onFinish = function() end
  game.overworld:pushBattle(battle)

  U.wait(120)
  for _ = 1, 60 do
    if battle.phase == "menu" and not battle.showPlayerBack then break end
    U.tap(game, "a")
    U.wait(8)
  end
  assert(battle.phase == "menu", "battle did not reach the command menu")
  if captureBaseline then
    U.wait(30)
    assert(U.shot(game, ("%s/base_%s_%s.png"):format(
      DIR, species:lower(), layout)))
  end
  local target = targetSide == "enemy" and battle.enemy or battle.player
  local subject = target.mon
  local ok, reason = mega.activate(battle, target, targetSide)
  assert(ok, "Mega activation failed: " .. tostring(reason))
  for _ = 1, 40 do
    if subject._ascMegaForm == profileId and battle.phase == "menu" then
      break
    end
    U.tap(game, "a")
    U.wait(8)
  end
  U.wait(45)

  assert(subject._ascMegaForm == profileId,
    "live Pokémon did not enter " .. profileId)
  assert(target._ascMegaForm == profileId,
    "live battler did not enter " .. profileId)
  local front = Sprites.path(game.data, species, "front", {
    mon = subject, kind = "battle",
  })
  local back = Sprites.path(game.data, species, "back", {
    mon = subject, kind = "battle",
  })
  local suffix = forcedShiny and "_shiny" or ""
  local function ownsMegaPath(path, side)
    local staticRoot = crystalArt
      and "assets/mega_runtime/" or "assets/mega_gen1_runtime/"
    local static = staticRoot .. asset
      .. "_" .. side .. suffix .. ".png"
    local animated = "assets/mega_animated_runtime/" .. asset
      .. "/" .. side .. "/" .. (forcedShiny and "shiny" or "normal") .. "/"
    return path and (path:find(static, 1, true)
      or (crystalArt and path:find(animated, 1, true)))
  end
  assert(ownsMegaPath(front, "front"),
    "Mega front lost to Crystal sprite ownership: " .. tostring(front))
  local expectedBackSide = layout == "voxel" and not backSprites
    and "front" or "back"
  assert(ownsMegaPath(back, expectedBackSide),
    "Mega back lost to Crystal sprite ownership: " .. tostring(back))
  assert(not target.__ascendantCrystalAnimation,
    "base Crystal animation kept running after Mega Evolution")
  assert(not target.__crystalAnimation,
    "external Crystal animation kept running after Mega Evolution")
  if crystalArt and not profile.staticOnly then
    local animation = assert(target.__ascendantMegaAnimation,
      "authored form animation did not attach in " .. layout)
    local first = animation.frame
    local current = animation
    for _ = 1, 120 do
      -- Scripted high-speed runs may receive a zero wall-clock delta on macOS;
      -- advance the public animation seam with a real frame delta as well.
      mega.updateAnimations(battle, 1 / 60)
      U.wait(1)
      current = target.__ascendantMegaAnimation
      if current and current.frame ~= first then break end
    end
    assert(current and current.frame ~= first,
      ("authored form animation did not advance (state=%s frame=%s "
        .. "elapsed=%s sprite=%s image=%s)"):format(
          tostring(current), tostring(current and current.frame),
          tostring(current and current.elapsed), tostring(target.sprite),
          tostring(current and current.image)))
  else
    assert(not target.__ascendantMegaAnimation,
      (crystalArt and "static approved Mega pose unexpectedly attached Crystal motion"
        or "static Gen-I Mega presentation unexpectedly attached Crystal motion"))
  end
  local scaleSide = targetSide == "enemy" and "front" or "back"
  local scalePath = targetSide == "enemy" and front or back
  local liveScale = BattleState.resolveBattleScale(game.data, scaleSide,
    scalePath, species)
  assert(math.abs(liveScale - 1) < 0.001,
    ("authored Mega %s scale was lost for %s: %s (%s)"):format(
      scaleSide, asset, tostring(liveScale), tostring(target.sprite)))
  if layout == "voxel" and overworldBattle then
    local observed = {}
    local previousResolve = BattleState.resolveBattleScale
    BattleState.resolveBattleScale = function(data, side, path, monSpecies)
      local value = previousResolve(data, side, path, monSpecies)
      observed[#observed + 1] = {
        side = side, path = path, species = monSpecies, value = value,
      }
      return value
    end
    local textures = overworldBattle.textures(battle)
    BattleState.resolveBattleScale = previousResolve
    local pinnedPlayer = backSprites and targetSide == "player"
    assert(textures and (pinnedPlayer
        and textures.player == nil or textures[targetSide]),
      pinnedPlayer
        and "Voxel BACK SPRITES did not keep the player on the GB menu"
        or "Voxel renderer dropped the transformed Mega texture")
    if pinnedPlayer then
      assert(overworldBattle.backPinned(),
        "requested Voxel BACK SPRITES setting is not active")
      assert(mega.rearOverlayAllowed(battle) == false,
        "classic white-paper Mega overlay leaked into Voxel BACK SPRITES")
    else
    local texture = textures[targetSide]
    assert(texture.kantoAscendantMegaSupersampled == true,
      "Voxel renderer did not select the high-resolution Mega texture")
    assert(texture.kantoAscendantMegaSource
        and texture.kantoAscendantMegaSource:find(
          crystalArt and "assets/mega" or "assets/mega_gen1_runtime",
          1, true),
      "Voxel renderer lost the approved Mega master source")
    assert(texture.kantoAscendantMegaSource:find("/front", 1, true)
        or texture.kantoAscendantMegaSource:find("_front", 1, true),
      "Voxel renderer used a rear Mega drawing instead of the camera-facing front")
    local textureWidth, textureHeight = texture.canvas:getDimensions()
    assert(textureWidth == 160 and textureHeight == 144,
      ("Voxel Mega texture did not retain its native 160:144 card: %sx%s")
        :format(tostring(textureWidth), tostring(textureHeight)))
    local voxelScale, voxelValues
    for _, call in ipairs(observed) do
      if call.side == scaleSide and call.species == species then
        voxelScale = math.min(voxelScale or math.huge, call.value)
        voxelValues = (voxelValues and (voxelValues .. ",") or "")
          .. tostring(call.value)
      end
    end
    assert(voxelScale and math.abs(voxelScale - 1) < 0.001,
      ("Voxel native Mega scale was not observed: %s (values=%s)")
        :format(tostring(voxelScale), tostring(voxelValues)))
    end
  elseif layout == "2d" and targetSide == "player" then
    assert(mega.rearOverlayAllowed(battle) == true,
      "ordinary 2D lost the authored Mega rear overlay")
  end
  U.wait(30)
  -- Player and enemy are separate acceptance surfaces: rear HUD anchoring is
  -- only visible on the player side, while the enemy proves the true front.
  -- Keep both captures rather than allowing the second run to overwrite the
  -- first merely because form/layout match.
  local label = asset .. "_" .. layout .. "_" .. targetSide
  if layout == "voxel" and backSprites then
    label = label .. "_back_sprites_on"
  end
  if forcedShiny then label = label .. "_shiny" end
  if not crystalArt then label = label .. "_gen1_" .. version end
  assert(U.shot(game, ("%s/%s.png"):format(DIR, label)))
  local out=assert(io.open(DIR.."/driver_result.txt","wb"),
    "could not write Hoenn Mega package result")
  out:write("status=PASS\n")
  out:write("scope=HOENN-MEGA-PRESENTATION\n")
  out:write("edition=",version,"\n")
  out:write("form=",form,"\n")
  out:write("layout=",layout,"\n")
  out:write("side=",targetSide,"\n")
  out:write("shiny=",forcedShiny and "1" or "0","\n")
  out:write("crystal=",crystalArt and "1" or "0","\n")
  out:write("animation=1/1\n")
  out:write("sprite_ownership=1/1\n")
  out:write("fail=0\n")
  out:close()
  U.log("HOENN MEGA PACKAGE PASS",label,
    crystalArt and "Crystal" or "Gen-I",
    "front/back sprite ownership")
  love.event.quit(0)
end
