-- Exact-0.1.83 visual receipt for the mod-owned HEVO visibility adapter.
--
-- This driver is only run against a disposable LÖVE identity containing a
-- copied BLITZ slot.  It never saves.  It forces the ordinary flat world path
-- in memory, enters one real RED floor, and records both the rendered frame
-- and the adapter's final-world runtime evidence.

return function(game)
  local U = dofile(assert(os.getenv("KA_TEST_UTIL"), "KA_TEST_UTIL required"))
  local SaveData = require("src.core.SaveData")
  local Pipelines = require("src.render.Pipelines")
  local Tilt = require("src.render.Tilt")
  local OverworldState = require("src.world.OverworldController")
  local identity = assert(os.getenv("POKEPORT_IDENTITY"),
    "POKEPORT_IDENTITY required")
  local outDir = assert(os.getenv("SHOT_DIR"), "SHOT_DIR required")
  local expectedCompatSha = assert(os.getenv("KA_VISIBILITY_SHA256"),
    "KA_VISIBILITY_SHA256 required")
  local expectedCampaignSha = assert(os.getenv("KA_CAMPAIGN_SHA256"),
    "KA_CAMPAIGN_SHA256 required")

  assert(identity:find("ka%-hevo%-visibility%-legacy", 1, false),
    "refusing non-disposable identity")
  assert(os.getenv("KA_SOURCE_SAVE") == nil,
    "driver must use only the copied identity slot")

  local function hex(bytes)
    return love.data.encode("string", "hex", bytes)
  end

  local function runtimeSha(path)
    return hex(love.data.hash("sha256", assert(love.filesystem.read(path))))
  end

  local actualCompatSha = runtimeSha(
    "mods/kanto_ascendant/hidden_evolution_visibility_compat.lua")
  local actualCampaignSha = runtimeSha(
    "mods/kanto_ascendant/hidden_evolution_campaign.lua")
  assert(actualCompatSha == expectedCompatSha,
    "runtime visibility adapter differs from reviewed source")
  assert(actualCampaignSha == expectedCampaignSha,
    "runtime campaign differs from reviewed source")

  assert(SaveData.setActiveSlot("red", "slot7") == "slot7",
    "could not select copied BLITZ slot7")
  local loaded = assert(SaveData.load("red"),
    "copied BLITZ slot7 did not load")
  assert(loaded.player and loaded.player.name == "BLITZ",
    "copied slot is not BLITZ")
  game:restoreSave(loaded)
  U.wait(180)

  local authority = assert(game.mods and game.mods.exports
      and game.mods.exports.kanto_ascendant,
    "Kanto Ascendant export missing")
  local campaign = assert(authority.hiddenEvolutionCampaign,
    "Hidden Evolution campaign missing")
  local postInstallPreflightOk, postInstallPreflightMode =
    campaign.runtimePreflight(game)
  assert(postInstallPreflightOk == true,
    "post-install presentation audit failed")
  assert(campaign.presentationMode == "legacy-mod-world-mask",
    "mod-owned legacy visibility did not install")
  local compat = assert(campaign.visibilityCompat,
    "legacy visibility adapter export missing")
  assert(compat.installed == true,
    "legacy visibility adapter inactive")

  -- Prove the compatibility path itself rather than a newer renderer hook.
  assert(type(game.renderer.queueWorldPostOverlay) ~= "function",
    "unexpected world-post-overlay API in exact legacy probe")
  -- The route modules install a drawAtmosphere function themselves, but the
  -- old controller has no call site for it.  Its post-install presence is why
  -- runtimePreflight now reports atmosphere-fallback; visibilityCompat being
  -- instantiated proves the pre-install branch was legacy-native-darkness.
  assert(type(OverworldState.drawAtmosphere) == "function",
    "route-level dead atmosphere callback was not installed as expected")

  -- Keep this one receipt isolated to the ordinary flat final-world path.
  Tilt.setLevel(0)
  for _, entry in ipairs(Pipelines.list()) do
    if entry.def and entry.def.drawWorld then
      Pipelines.setLevel(entry.id, 0)
    end
  end
  U.wait(180)
  assert(Pipelines.worldPipeline() == nil, "world pipeline still active")
  assert(not Tilt.active(), "tilt still active")

  while game.stack:top() do game.stack:pop() end
  local RuntimeMap = require("src.world.Map")
  local mapId = "KA_HEVO_RED_UPPER"
  local def = assert(game.data.maps[mapId], "RED floor missing")
  local runtime = RuntimeMap.new(def, assert(game.data.tilesets[def.tileset]))
  local wantedX, wantedY = 13, 29
  local spawnX, spawnY, best
  for y = 1, def.height * 2 - 2 do
    for x = 1, def.width * 2 - 2 do
      if runtime:isWalkableCell(x, y) then
        local d = (x - wantedX) ^ 2 + (y - wantedY) ^ 2
        if not best or d < best then
          spawnX, spawnY, best = x, y, d
        end
      end
    end
  end
  assert(spawnX, "RED receipt has no walkable spawn")
  U.teleport(game, mapId, spawnX, spawnY, "down")
  U.wait(180)
  while game.stack:top() and game.stack:top() ~= game.overworld do
    game.stack:pop()
  end
  U.wait(60)

  local red = assert(campaign.modules and campaign.modules.RED,
    "RED route missing")
  local profile = red.sightProfile(0, false)
  game.overworld.kaHevoRedSight = profile
  game.overworld.visionRadius = profile.radius
  U.wait(60)

  local shotPath = outDir .. "/hevo_red_legacy_visibility.png"
  assert(U.shot(game, shotPath), "visibility screenshot did not reach disk")
  local evidence = assert(game.overworld.kaHevoLegacyVisibilityRuntime,
    "final-world visibility runtime evidence missing")
  assert(evidence.contract == "KA_HEVO_LEGACY_VISIBILITY_V1",
    "wrong visibility contract")
  assert(evidence.mapId == mapId and evidence.kind == "RED",
    "visibility applied to wrong map/route")
  assert(evidence.presentation == "legacy-mod-world-mask",
    "wrong presentation path")
  assert(evidence.projection == "legacy-flat-world-canvas",
    "receipt did not use the flat final-world path")
  assert(evidence.renderPath == "shader" or evidence.renderPath == "stencil",
    "visibility did not render through a supported path")
  assert(evidence.outerOpaque == true and evidence.radius == 1.9,
    "RED visibility aperture is not the fail-closed initial profile")

  local modErrors = game.mods and #(game.mods.errors or {}) or -1
  assert(modErrors == 0, "mod errors present in exact runtime")
  local result = assert(io.open(outDir .. "/RESULT.txt", "wb"))
  result:write("status=PASS\n")
  result:write("identity=", identity, "\n")
  result:write("engine=", tostring(require("src.core.Version").engine), "\n")
  result:write("save_name=", tostring(game.save.player.name), "\n")
  result:write("map=", mapId, "\n")
  result:write("spawn=", tostring(spawnX), ",", tostring(spawnY), "\n")
  result:write("install_trigger=legacy-native-darkness\n")
  result:write("post_install_preflight_mode=",
    tostring(postInstallPreflightMode), "\n")
  result:write("presentation_mode=", campaign.presentationMode, "\n")
  result:write("contract=", tostring(evidence.contract), "\n")
  result:write("projection=", tostring(evidence.projection), "\n")
  result:write("render_path=", tostring(evidence.renderPath), "\n")
  result:write("outer_opaque=", tostring(evidence.outerOpaque), "\n")
  result:write("radius=", tostring(evidence.radius), "\n")
  result:write("cell_pixels=", tostring(evidence.cellPixels), "\n")
  result:write("center=", tostring(evidence.center.x), ",",
    tostring(evidence.center.y), "\n")
  result:write("visibility_sha256=", actualCompatSha, "\n")
  result:write("campaign_sha256=", actualCampaignSha, "\n")
  result:write("mod_errors=", tostring(modErrors), "\n")
  result:write("screenshot=", shotPath, "\n")
  result:close()

  print(("HEVO LEGACY VISIBILITY PASS mode=%s path=%s map=%s radius=%.1f")
    :format(campaign.presentationMode, evidence.renderPath, mapId,
      evidence.radius))
  love.event.quit(0)
end
