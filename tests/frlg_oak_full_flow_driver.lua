-- Full renderer-backed New Game proof for the installed desktop build.
-- Unlike the focused selector regression, this starts at the intro/title,
-- chooses NEW GAME and advances Oak's real step chain until the Kanto
-- Ascendant CharacterSelect is actually pushed.

return function(game)
  local U = dofile(os.getenv("KA_TEST_UTIL") or "tests/drivers/util.lua")
  local dir = assert(os.getenv("SHOT_DIR"), "SHOT_DIR is required")
  local exports = assert(game.mods.exports.kanto_ascendant)
  local characters = assert(exports.extendedCharacters)
  local pass, fail = 0, 0

  local function check(label, value)
    if value then pass = pass + 1 else fail = fail + 1 end
    U.log(value and "PASS" or "FAIL", label)
  end

  local function isSelector(state)
    return state and getmetatable(state) == characters.CharacterSelect
  end

  U.wait(6)
  U.tap(game, "start") -- skip intro movie
  U.wait(12)
  U.tap(game, "a") -- title -> main menu
  U.wait(8)

  local menu = game.stack:top()
  local newGameIndex
  for index, item in ipairs(menu and menu.items or {}) do
    local label = tostring(item.label or item.text or ""):upper()
    U.log("title menu", index, label)
    if label:find("NEW GAME", 1, true)
        or label:find("NEUES SPIEL", 1, true) then
      newGameIndex = index
    end
  end
  check("real title menu exposes NEW GAME", newGameIndex ~= nil)
  if not newGameIndex then love.event.quit(1) return end

  local cursor = menu.cursor or menu.index or 1
  for _ = cursor, newGameIndex - 1 do U.tap(game, "down") end
  U.tap(game, "a")
  U.wait(10)

  local selector
  for _ = 1, 520 do
    local top = game.stack:top()
    if isSelector(top) then selector = top break end
    U.tap(game, "a")
    U.wait(2)
  end
  check("Oak's real New Game chain reaches Kanto character selection",
    selector ~= nil)
  if not selector then love.event.quit(1) return end

  for index, id in ipairs(characters.selectionOrder) do
    selector.index = index
    selector.__screenSpaceHd = nil
    local shot = ("%s/%02d_full_new_game_%s.png")
      :format(dir, index, id:lower())
    check(id .. " real New Game screenshot", U.shot(game, shot))
    local hd = selector.__screenSpaceHd
    check(id .. " real New Game uses native HD screen layer",
      hd and hd.character == id and hd.sourceWidth == 128
        and hd.sourceHeight == 128 and hd.integerZoom >= 1
        and hd.integerZoom == math.floor(hd.integerZoom))
  end

  U.log(("FRLG OAK FULL FLOW RESULT pass=%d fail=%d")
    :format(pass, fail))
  love.event.quit(fail == 0 and 0 or 1)
end
