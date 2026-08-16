-- Real LÖVE capture pass for the registered Hidden Evolution maps.
-- Invoke through scripts/run.sh with POKEPORT_DRIVER and SHOT_DIR.  The
-- driver uses the engine's actual OverworldController/capture path; it does
-- not synthesize images or claim Voxel output when DRAMALESS is absent.
return function(game)
  local U = dofile("tests/drivers/util.lua")
  local RuntimeMap = require("src.world.Map")
  local maps = {
    { id="KA_HEVO_TUNNEL_ALL", tag="ka_hevo_tunnel_all_red_shaft", focus={6,12} },
    "KA_HEVO_RED_UPPER", "KA_HEVO_RED_ABYSS",
    "KA_HEVO_RED_RECOVERY", "KA_HEVO_RED_LOWER", "KA_HEVO_RED_SHRINE",
    { id="KA_HEVO_TUNNEL_ALL", tag="ka_hevo_tunnel_all_blue_shaft", focus={26,12} },
    "KA_HEVO_BLUE_FROST_THRESHOLD",
    "KA_HEVO_BLUE_FROST_HALL", "KA_HEVO_BLUE_GLACIER_MAZE",
    "KA_HEVO_BLUE_TIDAL_DEPTHS", "KA_HEVO_BLUE_KYOGRE_SHRINE",
    { id="KA_HEVO_TUNNEL_ALL", tag="ka_hevo_tunnel_all_green_shaft", focus={46,12} },
    "KA_HEVO_GREEN_THRESHOLD", "KA_HEVO_GREEN_GROVE",
    "KA_HEVO_GREEN_MIST", "KA_HEVO_GREEN_RAYQUAZA_SHRINE",
    "KA_HEVO_SHARED_SEALED_ANTECHAMBER",
  }
  local focalCells = {
    KA_HEVO_RED_UPPER = { 7, 25 }, KA_HEVO_RED_ABYSS = { 13, 17 },
    KA_HEVO_RED_RECOVERY = { 7, 9 }, KA_HEVO_RED_LOWER = { 35, 23 },
    KA_HEVO_RED_SHRINE = { 33, 13 }, KA_HEVO_BLUE_FROST_HALL = { 21, 17 },
    KA_HEVO_BLUE_GLACIER_MAZE = { 25, 17 }, KA_HEVO_BLUE_TIDAL_DEPTHS = { 27, 13 },
    KA_HEVO_BLUE_KYOGRE_SHRINE = { 19, 9 }, KA_HEVO_GREEN_GROVE = { 29, 19 },
    KA_HEVO_GREEN_MIST = { 29, 19 }, KA_HEVO_GREEN_RAYQUAZA_SHRINE = { 29, 19 },
    KA_HEVO_SHARED_SEALED_ANTECHAMBER = { 15, 7 },
    KA_NGPLUS_LEGACY_WORKSHOP = { 9, 6 },
  }
  local root = assert(os.getenv("SHOT_DIR"), "SHOT_DIR is required")
  local only = os.getenv("KA_HEVO_CAPTURE_MAP")
  if os.getenv("KA_HEVO_CAPTURE_SHARED_ONLY") == "1" then
    maps = {
      { id="KA_HEVO_TUNNEL_ALL", tag="ka_hevo_tunnel_all_red_shaft", focus={6,12} },
      { id="KA_HEVO_TUNNEL_ALL", tag="ka_hevo_tunnel_all_blue_shaft", focus={26,12} },
      { id="KA_HEVO_TUNNEL_ALL", tag="ka_hevo_tunnel_all_green_shaft", focus={46,12} },
    }
  end
  local focusOverride = os.getenv("KA_HEVO_CAPTURE_FOCUS")
  local overrideX, overrideY = focusOverride and focusOverride:match("^(%d+),(%d+)$")
  if focusOverride and not overrideX then error("KA_HEVO_CAPTURE_FOCUS must be x,y") end
  overrideX, overrideY = tonumber(overrideX), tonumber(overrideY)
  if only and only ~= "" then maps = { only } end
  -- The optional QoL banner is time-based (wall clock, not simulation
  -- frames), so a fast headless driver cannot reliably wait it out. Disable
  -- it only for this capture process; production player preferences remain
  -- untouched and every screenshot is taken with the map unobscured.
  game.save.options = game.save.options or {}
  game.save.options.modOptions = game.save.options.modOptions or {}
  game.save.options.modOptions.kanto_ascendant = game.save.options.modOptions.kanto_ascendant or {}
  game.save.options.modOptions.kanto_ascendant.qol_location_banners = false

  local function spawn(def, focus)
    local terrain = assert(game.data.tilesets[def.tileset],
      "missing terrain tileset " .. tostring(def.tileset) .. " for " .. def.id)
    local runtime = RuntimeMap.new(def, terrain)
    local wantedX, wantedY = (focus and focus[1]) or def.width,
      (focus and focus[2]) or def.height
    local best, bestDistance
    for y = 1, def.height * 2 - 2 do
      for x = 1, def.width * 2 - 2 do
        if runtime:isWalkableCell(x, y) then
          local dx, dy = x - wantedX, y - wantedY
          local distance = dx * dx + dy * dy
          if not bestDistance or distance < bestDistance then
            best, bestDistance = { x, y }, distance
          end
        end
      end
    end
    if best then return best[1], best[2] end
    error("no walkable terrain cell in " .. def.id)
  end

  local function settle(game)
    U.wait(24)
    for _ = 1, 4 do
      if game.stack:top() == game.overworld then break end
      U.tap(game, "b")
      U.wait(12)
    end
    assert(game.stack:top() == game.overworld,
      "overlay remained over capture")
    -- Give map-entry/location UI another complete input-and-render window.
    -- Captures must never be taken over an opening label or text box.
    U.tap(game, "b")
    U.wait(12)
    assert(game.stack:top() == game.overworld,
      "location overlay remained over capture")
    U.wait(24)
  end

  for _, row in ipairs(maps) do
    local id = type(row)=="table" and row.id or row
    local tag = type(row)=="table" and row.tag or id:lower()
    local rowFocus = type(row)=="table" and row.focus or nil
    local def = assert(game.data.maps[id], "campaign map is not registered: " .. id)
    local x, y = spawn(def, overrideX and { overrideX, overrideY } or rowFocus or focalCells[id])
    U.teleport(game, id, x, y, "down")
    assert(game.overworld and game.overworld.map.id == id, "teleport failed: " .. id)
    settle(game)
    assert(U.shot(game, root .. "/2d/" .. tag .. ".png"),
      "2D screenshot failed: " .. id)
  end
  U.log("Hidden Evolution 2D capture PASS", root, #maps .. " maps")
  love.event.quit(0)
end
