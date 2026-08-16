-- Shipped-engine proof for the compact German Gorochu Ascendant row.
return function(game)
  local U = {}
  function U.wait(frames)
    for _ = 1, frames do coroutine.yield() end
  end
  function U.log(...) print("[gorochu-de-driver]", ...) end
  function U.shot(g, path)
    local directory = path:match("^(.*)/[^/]+$")
    if directory then os.execute('mkdir -p "' .. directory .. '"') end
    g.capturePath = path
    for _ = 1, 120 do
      if not g.capturePath then break end
      coroutine.yield()
    end
    local file = io.open(path, "rb")
    if not file then return false end
    file:close()
    return true
  end
  local Runtime = require("src.mods.Runtime")
  local Font = require("src.render.Font")
  local shotDir = assert(os.getenv("SHOT_DIR"),
    "SHOT_DIR is required for German Gorochu QA")
  local pass, fail = 0, 0

  local function check(ok, label)
    U.log(ok and "PASS" or "FAIL", label)
    if ok then pass = pass + 1 else fail = fail + 1 end
  end

  U.wait(20)
  local modId = "kanto_ascendant"
  local ascendant = assert(game.mods.exports[modId],
    "Kanto Ascendant export missing")
  game.mods.modOptions[modId] = game.mods.modOptions[modId] or {}
  game.mods.modOptions[modId].language = "de"
  game.save.options = game.save.options or {}
  game.save.options.modOptions = game.save.options.modOptions or {}
  game.save.options.modOptions[modId] = game.mods.modOptions[modId]

  ascendant.gorochu.grantHeart(game)
  local startRows = Runtime.call("ui.start_menu.items",
    function(_, rows) return rows end, game, {
      { label = "SICHERN" },
    })
  local gateway
  for _, row in ipairs(startRows or {}) do
    if row.label == "ASCENDANT" then gateway = row break end
  end
  check(gateway ~= nil, "Ascendant gateway is present")
  assert(gateway and gateway.onSelect, "Ascendant gateway cannot open")
  gateway.onSelect()
  U.wait(5)

  local menu = game.stack:top()
  local gorochuRow
  for _, row in ipairs(menu and menu.items or {}) do
    if row.ascendantKey == "gorochu_quest" then
      gorochuRow = row
      break
    end
  end
  check(gorochuRow and gorochuRow.label == "GOROCHU-APP",
    "German tree uses GOROCHU-APP")
  check(gorochuRow and Font.width(gorochuRow.label) <= 136,
    "GOROCHU-APP fits beside its right-hand status")
  check(U.shot(game, shotDir .. "/gorochu_app_ascendant_menu_de.png"),
    "German Ascendant menu screenshot")

  assert(gorochuRow and gorochuRow.onSelect,
    "German Gorochu row cannot open")
  gorochuRow.onSelect()
  U.wait(240)
  local status = ascendant.gorochu.statusText(game)
  check(status:find("GOROCHU-APP", 1, true) == 1,
    "German status page uses the compact app title")
  check(status:find("GOROCHU-FORSCHUNG", 1, true) == nil,
    "old oversized title is absent")
  for line in status:gmatch("[^\n\f]+") do
    check(Font.width(line) <= 144,
      "status line fits: " .. line)
  end
  check(U.shot(game, shotDir .. "/gorochu_app_status_de.png"),
    "German Gorochu status screenshot")

  print(("[gorochu-german-menu] RESULT pass=%d fail=%d")
    :format(pass, fail))
  love.event.quit(fail == 0 and 0 or 1)
end
