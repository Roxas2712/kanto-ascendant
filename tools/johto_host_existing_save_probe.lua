-- Disposable runtime probe for the missing Johto Masters host reported from
-- an existing RC save.  The source slot is loaded read-only from an explicit
-- path; the driver never writes it and refuses to run outside a probe identity.

return function(game)
  local U = dofile(assert(os.getenv("KA_TEST_UTIL"), "KA_TEST_UTIL required"))
  local source = assert(os.getenv("KA_SOURCE_SAVE"), "KA_SOURCE_SAVE required")
  local identity = assert(os.getenv("POKEPORT_IDENTITY"), "POKEPORT_IDENTITY required")
  assert(identity:find("johto%-host%-existing%-probe"),
    "refusing to run outside disposable Johto host probe identity")

  local chunk = assert(loadfile(source))
  local loaded = assert(chunk(), "source save did not return a table")
  game:restoreSave(loaded, false)
  U.wait(30)
  local exports = assert(game.mods.exports.kanto_ascendant)
  local locale = os.getenv("QA_LANGUAGE")
  if locale then
    game.mods.modOptions = game.mods.modOptions or {}
    game.mods.modOptions.kanto_ascendant =
      game.mods.modOptions.kanto_ascendant or {}
    game.mods.modOptions.kanto_ascendant.language = locale
    game.save.options = game.save.options or {}
    game.save.options.modOptions = game.save.options.modOptions or {}
    game.save.options.modOptions.kanto_ascendant =
      game.save.options.modOptions.kanto_ascendant or {}
    game.save.options.modOptions.kanto_ascendant.language = locale
    if game.mods.events then game.mods.events:emit("mod.options_changed", {
      mod = "kanto_ascendant", key = "language", value = locale,
    }) end
    U.wait(4)
    assert(exports.language and exports.language() == locale,
      "requested probe language is not active")
  end
  U.teleport(game, "INDIGO_PLATEAU_LOBBY", 9, 7, "up")
  U.wait(60)

  local renderer = os.getenv("QA_RENDERER")
  if renderer == "voxel" then
    local Pipelines = require("src.render.Pipelines")
    assert(exports.DRAMALESS_SHAPE,
      "Voxel Johto host probe requires real DRAMALESS_SHAPE")
    assert(Pipelines.setLevel("voxel", 1) == 1,
      "could not enable FULL Voxel pipeline")
    Pipelines.syncOptions(game.save.options or {})
    U.wait(90)
    assert(Pipelines.worldPipeline() == "voxel"
        and Pipelines.level("voxel") == 1,
      "Johto host probe is not using FULL Voxel")
  end

  local data = assert(exports.johtoMastersData)
  local postgame = assert(exports.postgame)
  assert(postgame.hasHallOfFame(game.save),
    "existing save is not recognized as Hall of Fame")

  local map = assert(game.data.maps[data.map])
  local definitions, live = 0, 0
  local definitionRows, liveRows = {}, {}
  for _, obj in ipairs(map.objects or {}) do
    if obj.name == data.name or obj.text == data.textId then
      definitions = definitions + 1
      definitionRows[#definitionRows + 1] = table.concat({
        tostring(obj.index), tostring(obj.name), tostring(obj.text),
        tostring(obj.runtime), tostring(obj.owner), tostring(obj.x), tostring(obj.y),
      }, "|")
    end
  end
  for _, npc in ipairs(game.overworld.npcs or {}) do
    local def = npc.def or {}
    if def.name == data.name or def.text == data.textId then
      live = live + 1
      liveRows[#liveRows + 1] = table.concat({
        tostring(npc.id), tostring(def.name), tostring(def.text),
        tostring(npc.cellX), tostring(npc.cellY),
      }, "|")
    end
  end

  local outDir = assert(os.getenv("SHOT_DIR"), "SHOT_DIR required")
  assert(U.shot(game, outDir .. "/indigo_host_existing_save.png"))
  local interaction = "not-run"
  if os.getenv("KA_PROBE_INTERACT") == "1" then
    -- Stand on the authored free approach below the host.  A party follower
    -- can occupy the natural arrival path and steal the A press, so the probe
    -- fixes only its own approach position before using the real interaction.
    U.teleport(game, "INDIGO_PLATEAU_LOBBY", 10, 9, "up")
    U.wait(24)
    U.tap(game, "a"); U.wait(240)
    local TextBox = require("src.render.TextBox")
    assert(getmetatable(game.stack:top()) == TextBox,
      "physical A press did not open the Johto host dialogue")
    interaction = "dialogue"
    assert(U.shot(game, outDir .. "/indigo_host_dialogue.png"))
    for _ = 1, 180 do
      if game.overworld.map.id == "KA_JOHTO_GATE_HALL"
        and game.stack:top() == game.overworld then break end
      U.tap(game, "a"); U.wait(3)
    end
    assert(game.overworld.map.id == "KA_JOHTO_GATE_HALL",
      "Johto host dialogue did not lead into the Gate Hall")
    interaction = "gate-hall"
    assert(U.shot(game, outDir .. "/johto_gate_hall.png"))
  end
  local result = assert(io.open(outDir .. "/driver_result.txt", "wb"))
  result:write("hallOfFame=true\n")
  result:write("map=" .. tostring(game.overworld.map.id) .. "\n")
  result:write("definitions=" .. tostring(definitions) .. "\n")
  result:write("live=" .. tostring(live) .. "\n")
  result:write("interaction=" .. interaction .. "\n")
  for _, row in ipairs(definitionRows) do result:write("def=" .. row .. "\n") end
  for _, row in ipairs(liveRows) do result:write("npc=" .. row .. "\n") end
  for _, npc in ipairs(game.overworld.npcs or {}) do
    local def = npc.def or {}
    result:write(table.concat({ "allnpc", tostring(npc.id),
      tostring(def.name), tostring(def.text), tostring(npc.cellX),
      tostring(npc.cellY), tostring(def.passable) }, "|") .. "\n")
  end
  for y = 0, game.overworld.map.heightCells - 1 do
    local cells = {}
    for x = 0, game.overworld.map.widthCells - 1 do
      local mark = game.overworld.map:isWalkableCell(x, y) and "." or "#"
      if game.overworld.map:warpAtCell(x, y) then mark = "W" end
      local npc = game.overworld:npcAtCell(x, y)
      if npc then mark = npc.def and npc.def.name == data.name and "H" or "N" end
      if game.overworld.player.cellX == x and game.overworld.player.cellY == y then
        mark = "P"
      end
      cells[#cells + 1] = mark
    end
    result:write(string.format("row%02d=%s\n", y, table.concat(cells)))
  end
  result:close()

  assert(definitions == 1,
    "expected exactly one Johto host definition, got " .. tostring(definitions))
  assert(live == 1,
    "expected exactly one live Johto host, got " .. tostring(live))
  love.event.quit(0)
end
