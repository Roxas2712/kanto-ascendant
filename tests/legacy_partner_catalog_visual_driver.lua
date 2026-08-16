-- Real Authority-main LÖVE navigation proof for Oak's middle partner ball.
-- It deliberately stays in the catalogue: no partner is chosen or persisted.

return function(game)
  local U = dofile(os.getenv("KA_TEST_UTIL") or "tests/drivers/util.lua")
  local MapScripts = require("data.scripts.init")
  local dir = assert(os.getenv("SHOT_DIR"), "SHOT_DIR is required")
  local api = assert(game.mods.exports.kanto_ascendant)
  local starters = assert(api.legacyStarters)
  local pass, fail = 0, 0

  local function check(label, value)
    if value then pass = pass + 1 else fail = fail + 1 end
    U.log(value and "PASS" or "FAIL", label)
    return value
  end
  local function waitFor(predicate, frames)
    for _ = 1, frames or 900 do
      local value = predicate()
      if value then return value end
      U.wait(1)
    end
    return nil
  end
  local function catalog()
    local top = game.stack:top()
    return top and getmetatable(top) == starters.Catalog and top or nil
  end
  local function callMiddle()
    local handler = assert(MapScripts.talkScript("OAKS_LAB",
      "TEXT_OAKSLAB_SQUIRTLE_POKE_BALL"), "middle Oak-ball script missing")
    local done = false
    handler(game, game.overworld, nil, function() done = true end)
    return function() return done end
  end
  local function state()
    local bucket = game.save.modData and game.save.modData.kanto_ascendant
    return bucket and bucket.legacy_journey
  end
  local function allowed(rows)
    for _, row in ipairs(rows or {}) do
      if not starters.partnerAllowlist[row.id] then return false end
    end
    return true
  end
  local function unmasteredOrder(rows)
    local expected = {}
    for _, id in ipairs(starters.partnerAllowlistOrder) do
      if not starters.legendaryIds[id] then expected[#expected + 1] = id end
    end
    if #expected ~= 118 or #(rows or {}) ~= #expected then return false end
    for index, row in ipairs(rows) do
      if row.id ~= expected[index] then return false end
    end
    return rows[#rows].id == "LARVITAR"
  end

  U.wait(30)
  game.save.party, game.save.inventory = {}, {}
  game.save.pokedex = { seen = {}, owned = {} }
  game.save.flags = {
    EVENT_FOLLOWED_OAK_INTO_LAB = true,
    KA_LEGACY_RIVAL_BALL_TAKEN = true,
  }
  game.save.objectToggles = {}
  game.save.options = game.save.options or {}
  game.save.options.textSpeed = 1
  game.save.player.name, game.save.player.rival = "RED", "BLUE"
  game.save.modData = game.save.modData or {}
  game.save.modData.kanto_ascendant = game.save.modData.kanto_ascendant or {}
  game.save.modData.kanto_ascendant.legacy_journey = {
    version = 6, cycle = 88, runId = "catalog-navigation-visual",
    avatar = "RED", partnerChosen = false, rivalBallTaken = true,
    bankUnlocked = true, wanderersEnabled = true,
  }
  game:adoptSave(game.save)
  starters.refresh(game)
  U.teleport(game, "OAKS_LAB", 5, 5, "up")
  U.wait(25)
  check("real Oak lab middle ball is available", game.overworld.map.id == "OAKS_LAB")

  local done = callMiddle()
  local list = waitFor(catalog)
  check("middle ball opens authoritative Balanced Choice", list ~= nil
    and list.mode == "balanced" and allowed(list.rows) and #list.rows > 0)
  local first, count = list and list.index, list and #list.rows
  U.tap(game, "right")
  check("physical RIGHT advances one allowed row", list.index == first + 1)
  U.tap(game, "left")
  check("physical LEFT returns one allowed row", list.index == first)
  U.tap(game, "left")
  check("physical LEFT wraps first row to last", list.index == count)
  U.tap(game, "right")
  check("physical RIGHT wraps last row to first", list.index == first)
  U.wait(120)
  check("Balanced L/R wrap capture",
    U.shot(game, dir .. "/01_balanced_lr_wrap.png"))

  U.tap(game, "down")
  check("physical DOWN moves +10", list.index == math.min(count, first + 10))
  -- Give the new sprite and the renderer several full draw frames before the
  -- capture; a one-draw-frame wait can catch LÖVE's palette hand-off half way
  -- through its compositing pass.  The exact end-wrap is asserted below.
  U.wait(120)
  check("Balanced +10 capture", U.shot(game, dir .. "/02_balanced_plusminus10_wrap.png"))
  U.tap(game, "up")
  check("physical UP moves -10", list.index == first)
  list.index = count
  U.tap(game, "down")
  check("physical +10 wraps at the end", list.index == ((count - 1 + 10) % count) + 1)
  U.tap(game, "up")
  check("physical -10 recovers the final row", list.index == count)

  U.tap(game, "select")
  check("SELECT opens the 118-row unmastered Free Choice",
    list.mode == "free" and unmasteredOrder(list.rows)
      and allowed(list.rows))
  check("Free Choice keeps Gastly and Ditto but excludes higher stages", starters.partnerAllowlist.GASTLY
    and starters.partnerAllowlist.DITTO and not starters.partnerAllowlist.GENGAR
    and not starters.partnerAllowlist.PIKACHU and not starters.partnerAllowlist.DRAGONITE)
  list.index = 1
  U.tap(game, "left")
  check("Free Choice also wraps with physical LEFT", list.index == #list.rows)
  U.wait(120)
  check("Free 118-entry capture", U.shot(game, dir .. "/03_free_118_catalog.png"))

  local partyBefore = #game.save.party
  local blockedGengar = starters.choose(game, "GENGAR", "free", "catalog", "catalog")
  local blockedPikachu = starters.choose(game, "PIKACHU", "free", "catalog", "catalog")
  local blockedHoenn = starters.choose(game, "TREECKO", "free", "catalog", "catalog")
  check("public choose API rejects higher, replaced and Hoenn species", blockedGengar == false
    and blockedPikachu == false and blockedHoenn == false
    and #game.save.party == partyBefore and not state().partnerChosen)
  U.tap(game, "b")
  check("catalogue Cancel makes no partner decision", waitFor(done, 180)
    and #game.save.party == 0 and not state().partnerChosen)
  U.log(("LEGACY PARTNER CATALOG VISUAL RESULT pass=%d fail=%d"):format(pass, fail))
  love.event.quit(fail == 0 and 0 or 1)
end
