-- Exact-engine acceptance for the physical Lab-PC -> Legacy Oak PicBox path.

return function(game)
  local Version = require("src.core.Version")
  local SaveData = require("src.core.SaveData")
  local Runtime = require("src.mods.Runtime")
  local Pokemon = require("src.pokemon.Pokemon")
  local TextBox = require("src.render.TextBox")
  local dir = assert(os.getenv("SHOT_DIR"), "SHOT_DIR is required")
  assert(Version.engine == "0.1.96", "exact engine 0.1.96 is required")
  assert(os.getenv("POKEPORT_IDENTITY") == "ka-oak-host-hd-0196-20260816",
    "disposable Oak HD identity is required")

  local U = {}
  function U.wait(frames)
    for _ = 1, frames or 1 do coroutine.yield() end
  end
  function U.tap(button)
    table.insert(game.input.pressQueue, button)
    U.wait(1)
    game.input.state[button] = false
  end
  function U.shot(path)
    game.capturePath = path
    for _ = 1, 180 do
      if not game.capturePath then break end
      U.wait(1)
    end
    U.wait(2)
    local file = io.open(path, "rb")
    if not file then return false end
    file:close()
    return true
  end
  function U.teleport(mapId, x, y, facing)
    while game.stack:top() do game.stack:pop() end
    game.stack:push(require("src.world.OverworldController"),
      mapId, x, y, facing or "down")
    U.wait(20)
  end

  local function waitFor(predicate, frames)
    for _ = 1, frames or 1200 do
      local value = predicate()
      if value then return value end
      U.wait(1)
    end
    return nil
  end
  local function isText(value)
    return value and getmetatable(value) == TextBox
  end
  local function drainToOverworld(frames)
    return waitFor(function()
      local top = game.stack:top()
      local runner = game.overworld and game.overworld.runner
      if top == game.overworld and not (runner and runner:isRunning()) then
        return true
      end
      if isText(top) then
        if top.waiting or top.done then U.tap("a")
        else
          game.input.state.a = true
          U.wait(1)
          game.input.state.a = false
        end
      elseif top and top ~= game.overworld then
        U.tap("a")
      else
        U.wait(1)
      end
    end, frames or 4800) == true
  end
  local function menu()
    local top = game.stack:top()
    return top and type(top.items) == "table" and top or nil
  end
  local function findRow(rows, needle)
    for index, row in ipairs(rows or {}) do
      if tostring(row.label):find(needle, 1, true) then return index end
    end
  end
  local function selectRow(current, index)
    assert(current and index, "missing PC row")
    while current.index ~= index do U.tap("down"); U.wait(2) end
    U.wait(2)
    U.tap("a")
    return waitFor(function()
      return game.stack:top() ~= current and true or nil
    end, 300)
  end
  local function settleText(box)
    for _ = 1, 1200 do
      if box.waiting or box.done then return true end
      game.input.state.a = true
      U.wait(1)
      game.input.state.a = false
    end
    return false
  end

  if love.window and love.window.setMode then
    love.window.setMode(1600, 900, { resizable = true, highdpi = false })
    U.wait(20)
  end

  local api = assert(game.mods and game.mods.exports
      and game.mods.exports.kanto_ascendant,
    "Kanto Ascendant did not load")
  local journey = assert(api.legacyJourney)
  local characters = assert(api.extendedCharacters)

  local slot = "slotoakhosthd0196"
  assert(SaveData.setActiveSlot("red", slot) == slot)
  local fresh = SaveData.newGame(game:bootConfig())
  fresh.options.uiLayout = "dynamic"
  fresh.options.textSpeed = 1
  game.save = fresh
  game:adoptSave(fresh)
  Runtime.emit("save.created", { save = fresh })
  game.mods.modOptions.kanto_ascendant =
    game.mods.modOptions.kanto_ascendant or {}
  game.mods.modOptions.kanto_ascendant.language = "de"
  fresh.options.modOptions = fresh.options.modOptions or {}
  fresh.options.modOptions.kanto_ascendant =
    game.mods.modOptions.kanto_ascendant
  Runtime.emit("mod.options_changed", {
    game = game, mod = "kanto_ascendant", key = "language", value = "de",
  })
  characters.select("RED")
  fresh.player.name, fresh.player.rival = "ROT", "BLAU"
  fresh.party = { Pokemon.new(game.data, "PIKACHU", 52) }
  fresh.flags = fresh.flags or {}
  fresh.flags.EVENT_BEAT_CHAMPION_RIVAL = true
  fresh.hallOfFame = { { name = "ROT", character = "RED" } }
  game:adoptSave(fresh)

  -- This driver owns the exact physical Lab-PC and rendering boundary. Stage
  -- the durable authorities exactly as the completed RED path leaves them;
  -- the dungeon suites independently prove the seal/black-door sequence.
  local bucket = assert(fresh.modData.kanto_ascendant)
  bucket.hevo_run = bucket.hevo_run or {}
  bucket.hevo_run.dungeonLegacy = {
    seals = { RED = true }, reentered = { RED = true },
  }
  bucket.hidden_evolution_story_campaign =
    bucket.hidden_evolution_story_campaign or {}
  bucket.hidden_evolution_story_campaign.doorVisits =
    bucket.hidden_evolution_story_campaign.doorVisits or {}
  bucket.hidden_evolution_story_campaign.doorVisits.RED = true
  assert(journey.reconcileHevoSealGate(fresh, false) == true,
    "staged RED completion did not arm the Legacy gate")
  assert(journey.canBegin(game.save) == true,
    "staged Hall/seal/Oak call did not arm Legacy Journey")

  U.teleport("OAKS_LAB", 1, 2, "up")
  U.wait(30)
  assert(drainToOverworld(4800),
    "Lab transition or pending Oak call did not return to play")
  game.input:reset()
  local pc
  for _ = 1, 4 do
    U.tap("a")
    pc = waitFor(menu, 180)
    if pc then break end
    U.wait(6)
  end
  pc = assert(pc, "physical Lab PC did not open")
  local beginIndex
  for index, row in ipairs(pc.items or {}) do
    if row.value == "legacy_journey" then beginIndex = index break end
  end
  beginIndex = assert(beginIndex,
    "physical Lab PC has no LEGACY/VERMÄCHTNIS action row")
  assert(selectRow(pc, beginIndex),
    "VERMÄCHTNIS/START stayed in the PC menu")

  local oakText = assert(waitFor(function()
    local top = game.stack:top()
    return isText(top) and top or nil
  end, 1200), "Oak's hosted Legacy text did not open")
  assert(settleText(oakText), "Oak's hosted text did not finish typing")
  local portrait
  for _, state in ipairs(game.stack.states or {}) do
    if state.kascLegacyOakHdImage then portrait = state break end
  end
  assert(portrait, "Legacy PicBox did not attach its HD Oak source")
  assert(portrait.image == nil,
    "Legacy PicBox still draws the 64px Oak below the HD layer")
  assert(portrait.kascLegacyOakHdSourceWidth == 590
      and portrait.kascLegacyOakHdSourceHeight == 1009,
    "Legacy PicBox loaded the wrong Oak source dimensions")

  local screenshot = dir .. "/01_legacy_pc_oak_hd_dynamic_engine0196.png"
  assert(U.shot(screenshot), "Oak HD screenshot did not reach disk")
  local proof = assert(portrait.kascLegacyOakHdProof,
    "render.hud did not draw the HD Oak source")
  assert(proof.screenSpace == true and proof.textBoxOcclusion == true)
  assert(proof.sourceWidth == 590 and proof.sourceHeight == 1009)
  assert(proof.drawWidth > 34 and proof.drawHeight > 58,
    "HD Oak was not rendered above native 160x144 resolution")

  local result = assert(io.open(dir .. "/driver_result.txt", "wb"))
  result:write("PASS\n")
  result:write("engine=", Version.engine, "\n")
  result:write("identity=", os.getenv("POKEPORT_IDENTITY"), "\n")
  result:write("slot=", slot, "\n")
  result:write("flow=PHYSICAL_LAB_PC_TO_LEGACY_OAK_HOST\n")
  result:write("ui_layout=", fresh.options.uiLayout, "\n")
  result:write("source=", proof.path, "\n")
  result:write(("source_dimensions=%dx%d\n"):format(
    proof.sourceWidth, proof.sourceHeight))
  result:write(("draw_dimensions=%.2fx%.2f\n"):format(
    proof.drawWidth, proof.drawHeight))
  result:write("textbox_complete=", tostring(oakText.waiting or oakText.done), "\n")
  result:write("screenshot=", screenshot, "\n")
  result:close()
  print("LEGACY OAK HOST HD VISUAL PASS engine=0.1.96 screenshot="
    .. screenshot)
  love.event.quit(0)
end
