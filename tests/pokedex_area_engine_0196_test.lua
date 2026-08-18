-- Optional exact-engine regression. Point KA_ENGINE_ROOT (or the historical
-- KA_ENGINE_0196_ROOT alias) at an unpacked official Gen1 Recomp `.love` and
-- KA_EXPECT_ENGINE at its exact version; the test first proves the released
-- TownMap constructor crashes on Ascendant's HEVO metadata, then installs the
-- mod compatibility reader and exercises the same constructor successfully.

local root = os.getenv("KA_ENGINE_ROOT") or os.getenv("KA_ENGINE_0196_ROOT")
if not root or root == "" then
  print("POKEDEX AREA ENGINE SKIP: KA_ENGINE_ROOT not set")
  return
end
local expectedEngine = os.getenv("KA_EXPECT_ENGINE")
  or (os.getenv("KA_ENGINE_0196_ROOT") and "0.1.96")
assert(expectedEngine and expectedEngine ~= "",
  "KA_EXPECT_ENGINE is required")
local version = assert(loadfile(root .. "/src/core/Version.lua"))()
assert(version.engine == expectedEngine,
  "wrong exact engine: " .. tostring(version.engine))

package.preload["src.render.Font"] = function()
  return { draw = function() end, drawBox = function() end,
    drawCode = function() end }
end
package.preload["src.core.Sound"] = function()
  return { play = function() end }
end

love = {
  graphics = {
    newImage = function() error("headless image") end,
  },
}

local TownMap = assert(loadfile(root .. "/src/ui/TownMap.lua"))()
local install = assert(loadfile("pokedex_area_compat.lua"))()

local currentEdition = "red"
local currentLocale = "en"
package.preload["src.core.Strings"] = function()
  return function(text, ...)
    if currentLocale == "de" and text == "AREA" then text = "GEBIET" end
    if select("#", ...) > 0 then return text:format(...) end
    return text
  end
end
package.preload["src.core.GameVersion"] = function()
  return { isYellow = function() return currentEdition == "yellow" end }
end
package.preload["src.ui.ListMenu"] = function()
  return { new = function(_, title, items, opts)
    return { title = title, items = items, opts = opts,
      close = function(self) self.closed = true end }
  end }
end
package.preload["src.ui.Menu"] = function()
  return { new = function(_, entries, opts)
    return { entries = entries, opts = opts }
  end }
end
package.preload["src.ui.Screens"] = function()
  return { push = function(game, id, opts)
    assert(id == "TownMap")
    local screen = TownMap.new(game, opts)
    game.stack:push(screen)
    return screen
  end }
end

local encounters = {
  ROUTE_1 = {
    grass = { rate = 25, slots = {
      { species = "PIKACHU", level = 4 },
    } },
    water = { rate = 0, slots = {} },
  },
  KA_HEVO_RED_UPPER = {
    grass = { rate = 15, slots = {
      { species = "MAGMAR", level = 30 },
    } },
    water = { rate = 0, slots = {} },
    kaProtected = true,
    kaEncounterSource = "hevo_dungeon",
    hevoCharacter = "RED",
    kaMaxVisible = 3,
  },
}

local game = {
  data = {
    encounters = encounters,
    pokemon = {
      PIKACHU = { id = "PIKACHU", name = "PIKACHU", dex = 25 },
      CHIKORITA = { id = "CHIKORITA", name = "CHIKORITA", dex = 152 },
    },
    constants = { dexSize = 151, dexDigits = 3 },
    field = { townMap = { locations = {
      ROUTE_1 = { name = "ROUTE 1", x = 2, y = 2 },
      ROUTE_24 = { name = "ROUTE 24", x = 4, y = 4 },
      KA_HEVO_RED_UPPER = { name = "HEVO", x = 3, y = 3 },
    } } },
  },
  save = {
    pokedex = { seen = { PIKACHU = true, CHIKORITA = true }, owned = {} },
  },
}

local reproduced, releasedError = pcall(TownMap.new, game,
  { nestSpecies = "PIKACHU" })
assert(not reproduced,
  "official reader unexpectedly accepted scalar encounter metadata")
assert(tostring(releasedError):find("attempt to index", 1, true), releasedError)
print(("POKEDEX AREA ENGINE %s REPRO: %s"):format(
  expectedEngine, tostring(releasedError)))

assert(install({
  townMap = TownMap,
  -- Johto's authored habitats are runtime encounter replacements rather
  -- than literal ROM encounter slots. The compatibility layer may project
  -- only currently active, already selectable species into AREA's read-only
  -- view; it must never mutate the canonical encounter registry.
  habitatsFor = function(_, species)
    if species == "CHIKORITA" then
      return { { map = "ROUTE_24", terrain = "grass" } }
    end
    return {}
  end,
}))
for _, edition in ipairs({ "red", "blue", "yellow" }) do
  game.edition = edition
  local screen = assert(TownMap.new(game, { nestSpecies = "PIKACHU" }))
  assert(screen.nestSpecies == "PIKACHU")
  assert(#screen.nests == 1 and screen.nests[1].name == "ROUTE 1")
  assert(game.data.encounters == encounters)

  local extended = assert(TownMap.new(game, { nestSpecies = "MAGMAR" }))
  assert(#extended.nests == 1 and extended.nests[1].name == "HEVO")
  assert(game.data.encounters == encounters)

  local johto = assert(TownMap.new(game, { nestSpecies = "CHIKORITA" }))
  assert(#johto.nests == 1 and johto.nests[1].name == "ROUTE 24",
    edition .. " authored Johto habitat missing from AREA")
  assert(game.data.encounters == encounters,
    edition .. " Johto AREA projection mutated encounter data")
end

-- Drive the exact public Pokédex module through its list and DATA/CRY/AREA
-- side menu, for every edition and both UI labels.  This verifies the repair
-- at the reported navigation seam rather than only calling TownMap directly.
local PokedexMenu = assert(loadfile(root .. "/src/ui/PokedexMenu.lua"))()
for _, edition in ipairs({ "red", "blue", "yellow" }) do
  for _, locale in ipairs({ "en", "de" }) do
    currentEdition, currentLocale = edition, locale
    local stack = { rows = {} }
    function stack:push(row) self.rows[#self.rows + 1] = row end
    game.stack = stack

    local list = PokedexMenu.new(game)
    local pikachu
    for _, item in ipairs(list.items) do
      if item.value == "PIKACHU" then pikachu = item break end
    end
    assert(pikachu, edition .. "/" .. locale .. " Pokédex row")
    list.opts.onChoose(pikachu, list)
    local side = assert(stack.rows[#stack.rows])
    local area
    for _, entry in ipairs(side.entries) do
      if entry.label == (locale == "de" and "GEBIET" or "AREA") then
        area = entry
        break
      end
    end
    assert(area, edition .. "/" .. locale .. " AREA side-menu row")
    area.onSelect()
    local screen = assert(stack.rows[#stack.rows])
    assert(screen.nestSpecies == "PIKACHU")
    assert(#screen.nests == 1 and screen.nests[1].name == "ROUTE 1")
    assert(game.data.encounters == encounters)
  end
end

print(("POKEDEX AREA ENGINE %s PASS: released crash reproduced, 9 direct and 6 full menu paths fixed")
  :format(expectedEngine))
