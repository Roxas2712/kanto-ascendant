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
  local U = dofile("tests/drivers/util.lua")
  local DIR = os.getenv("SHOT_DIR") or "/tmp/kanto-ascendant-mega-qa"
  local form = (os.getenv("MEGA_QA_FORM") or "raichu-x"):lower()
  local layout = (os.getenv("MEGA_QA_LAYOUT") or "voxel"):lower()
  local targetSide = (os.getenv("MEGA_QA_SIDE") or "player"):lower()
  local forcedShiny = os.getenv("MEGA_QA_SHINY") == "1"
  local captureBaseline = os.getenv("MEGA_QA_BASELINE") == "1"
  local crystalArt = os.getenv("MEGA_QA_CRYSTAL") ~= "0"
  local version = (os.getenv("MEGA_QA_VERSION") or "red"):lower()
  local GameVersion = require("src.core.GameVersion")
  local PaletteFX = require("src.render.PaletteFX")
  local Pokemon = require("src.pokemon.Pokemon")
  local Sprites = require("src.pokemon.Sprites")
  local BattleState = require("src.battle.BattleState")
  local Pipelines = require("src.render.Pipelines")

  assert(GameVersion.VERSIONS[version],
    "MEGA_QA_VERSION must be red, blue or yellow")
  GameVersion.set(version)
  game.save.options.colors = "ogred"
  PaletteFX.setMode("ogred")
  game.mods.modOptions.trainer_rematch =
    game.mods.modOptions.trainer_rematch or {}
  game.mods.modOptions.trainer_rematch.kanto_crystal_art = crystalArt
  game.mods.modOptions.trainer_rematch.legend_art =
    crystalArt and "crystal" or "original"
  game.mods.modOptions.trainer_rematch.crystal_animation = crystalArt
  U.wait(20)
  local api = assert(game.mods and game.mods.exports
    and game.mods.exports.trainer_rematch, "Kanto Ascendant export missing")
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
  local dramatic = game.mods.exports.DRAMATIC_SHAPE
  local overworldBattle
  if dramatic and dramatic.lib then
    overworldBattle = dramatic.lib.require("OverworldBattle")
    overworldBattle.setting:setIndex(layout == "voxel" and 1 or 2, game)
    overworldBattle.backSetting:setIndex(1, game)
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
  local expectedBackSide = layout == "voxel" and "front" or "back"
  assert(ownsMegaPath(back, expectedBackSide),
    "Mega back lost to Crystal sprite ownership: " .. tostring(back))
  assert(not target.__ascendantCrystalAnimation,
    "base Crystal animation kept running after Mega Evolution")
  assert(not target.__crystalAnimation,
    "external Crystal animation kept running after Mega Evolution")
  if crystalArt then
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
      "static Gen-I Mega presentation unexpectedly attached Crystal motion")
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
    assert(textures and textures[targetSide],
      "Voxel renderer dropped the transformed Mega texture")
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
    assert(textureWidth == 230 and textureHeight == 207,
      ("Voxel Mega texture is not high-resolution 160:144: %sx%s")
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
  U.wait(30)
  local label = asset .. "_" .. layout
  if forcedShiny then label = label .. "_shiny" end
  if not crystalArt then label = label .. "_gen1_" .. version end
  assert(U.shot(game, ("%s/%s.png"):format(DIR, label)))
  U.log(label, crystalArt and "Crystal" or "Gen-I",
    "front/back sprite ownership PASS")
end
