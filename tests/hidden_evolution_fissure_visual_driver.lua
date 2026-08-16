-- Focused real-renderer proof for the entrance crack. The production mod,
-- production route maps and production 2D/DRAMALESS paths are used; only the
-- disposable starting position is selected by the driver.
return function(game)
  assert(os.getenv("KA_PACKAGE_GATE") == "1",
    "refusing fissure proof outside the immutable package gate")
  local U = dofile(os.getenv("KA_TEST_UTIL") or "tests/drivers/util.lua")
  local Pipelines = require("src.render.Pipelines")
  local out = assert(os.getenv("SHOT_DIR"), "SHOT_DIR is required")
  local renderer = assert(os.getenv("QA_RENDERER"), "QA_RENDERER is required")
  local voxel = renderer == "voxel"
  if voxel then
    assert(game.mods.exports.DRAMALESS_SHAPE,
      "DRAMALESS_SHAPE did not load")
  end
  local level = Pipelines.setLevel("voxel", voxel and 1 or 0)
  Pipelines.syncOptions(game.save.options)
  assert(voxel and level > 0 or not voxel and level == 0,
    "requested renderer is not active")

  local sites = {
    -- ROUTE_22 (35,3) is native unwalkable rock tile $37. Its nearest clear
    -- cell in that southern row is the authored gap at (33,3), which keeps
    -- the real (35,2) interaction approach and the wall itself unobstructed.
    { key="RED", map="ROUTE_22", x=35, wallY=1, approachY=2,
      captureX=33, captureY=3, elevation=6, faceOffsetY=6 },
    { key="BLUE", map="ROUTE_24", x=10, wallY=3, approachY=4,
      captureX=12, captureY=5, elevation=0 },
    { key="GREEN", map="ROUTE_3", x=41, wallY=3, approachY=4, captureY=5, elevation=0 },
  }
  local only = os.getenv("QA_FISSURE_SITE")
  if only then
    local selected
    for _, site in ipairs(sites) do
      if site.key == only:upper() then selected = site end
    end
    assert(selected, "unknown QA_FISSURE_SITE: " .. only)
    sites = { selected }
  end

  for _, site in ipairs(sites) do
    -- Frame away from the real interaction approach so the player's body
    -- cannot cover the wall pixels. Gameplay coordinates remain intact.
    U.teleport(game, site.map, site.captureX or site.x, site.captureY, "up")
    U.wait(voxel and 300 or 30)
    assert(game.overworld.map:isWalkableCell(site.captureX or site.x, site.captureY),
      site.key .. " capture cell is not clear")
    local decal
    for _, row in ipairs(game.overworld.map.def.wallDecals or {}) do
      if row.id == "KA_HEVO_WALL_FISSURE_" .. site.key then decal = row end
    end
    assert(decal and decal.cellX == site.x and decal.cellY == site.wallY
        and decal.face == "south" and decal.elevation == site.elevation
        and decal.faceOffsetY == site.faceOffsetY,
      site.key .. " wall decal missing")
    local anchor
    for _, npc in ipairs(game.overworld.npcs or {}) do
      if npc.def and npc.def.name == "KA_HEVO_FISSURE_" .. site.key then anchor = npc end
    end
    assert(anchor and anchor.cellX == site.x and anchor.cellY == site.wallY
        and anchor.def.renderMode == "none" and anchor.passable == true,
      site.key .. " invisible interaction anchor missing")
    for _, npc in ipairs(game.overworld.npcs or {}) do
      assert(not (npc.cellX == site.x and npc.cellY == site.approachY
          and npc.passable ~= true),
        site.key .. " fissure approach overlaps blocking actor "
          .. tostring(npc.def and npc.def.name or npc.id))
    end
    local path = ("%s/%s_%s_fissure.png"):format(out, renderer, site.key:lower())
    assert(U.shot(game, path), "capture failed: " .. path)
    U.log("HEVO FISSURE CAPTURE", renderer, site.key, path)
  end
  local receipt = assert(io.open(out .. "/driver_result.txt", "wb"),
    "could not write fissure package receipt")
  receipt:write("status=PASS\n")
  receipt:write("scope=HEVO-FISSURE-RENDERERS\n")
  receipt:write("renderer=", renderer, "\n")
  receipt:write("sites=RED,BLUE,GREEN\n")
  receipt:write("wall_decals=3/3\n")
  receipt:write("interaction_anchors=3/3\n")
  receipt:write("fail=0\n")
  receipt:close()
  love.event.quit(0)
end
