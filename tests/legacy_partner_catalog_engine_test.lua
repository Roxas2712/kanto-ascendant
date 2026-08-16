-- Real-engine contract for Oak's Legacy partner catalogue and its commit
-- boundary. Run from the Gen1 Recomp checkout:
--
--   TRAINER_REMATCH_MOD_DIR=../kanto-ascendant \
--     luajit ../kanto-ascendant/tests/legacy_partner_catalog_engine_test.lua

package.path = "./?.lua;./?/init.lua;" .. package.path
require("src.core.Version").engine = "0.1.90"
local T = require("tests.modkit")
local Data = require("src.core.Data")
if not (Data.pokemon and Data.pokemon.BULBASAUR) then Data:load() end

local assertions = 0
local function check(value, message)
  assertions = assertions + 1
  if not value then error("FAIL: " .. message, 2) end
end
local function eq(actual, expected, message)
  check(actual == expected, message .. " (got " .. tostring(actual)
    .. ", expected " .. tostring(expected) .. ")")
end
local function countKeys(value)
  local count = 0
  for _ in pairs(value or {}) do count = count + 1 end
  return count
end
local function hasRow(rows, id)
  for _, row in ipairs(rows or {}) do
    if row.id == id then return true end
  end
  return false
end
local function rowIndex(rows, id)
  for index, row in ipairs(rows or {}) do
    if row.id == id then return index end
  end
end

-- Snapshot the pristine engine Kanto order before the mod adds Johto and its
-- authored forms. This makes the expected #001-151 list independent of the
-- catalogue implementation under test.
local expected = {}
for id, def in pairs(Data.pokemon or {}) do
  local dex = math.floor(tonumber(def.dex) or 0)
  if dex >= 1 and dex <= 151 then
    check(expected[dex] == nil, "base engine has one canonical species at #"
      .. dex)
    expected[dex] = id
  end
end
eq(#expected, 151, "base engine supplies exact canonical Kanto order")

local modPath = os.getenv("TRAINER_REMATCH_MOD_DIR")
  or "mods/ka_rc11_integration"
local run = T.sdk.loadMod(modPath, { data = Data })
check(run.mod ~= nil, "Kanto Ascendant loads through the real engine SDK: "
  .. table.concat(run.errors or {}, " | "))
eq(#(run.errors or {}), 0, "real engine/mod merge is clean")
local exports = assert(run.loader.exports.kanto_ascendant)
local starters = assert(exports.legacyStarters,
  "Legacy starter catalogue export is installed")
local rival = assert(exports.legacyRivalPartner,
  "Legacy rival-partner export is installed")
local johto = assert(exports.johtoData, "Johto catalogue export is installed")
for _, id in ipairs(johto.order) do expected[#expected + 1] = id end
eq(#expected, 251, "independent Kanto plus Johto order is exactly #001-251")

local function expectedUnmasteredOrder(dexMax)
  local rows = {}
  for _, id in ipairs(starters.partnerAllowlistOrder) do
    local def = Data.pokemon[id]
    if def and math.floor(tonumber(def.dex) or 0) <= dexMax
        and not starters.legendaryIds[id] then
      rows[#rows + 1] = id
    end
  end
  return rows
end

local sealedGame = { data = Data, save = { modData = {
  kanto_ascendant = { beyond_kanto = {
    version = 1, active = false, decision = "fresh_gen1",
  } },
} } }
local activeGame = { data = Data, save = { modData = {
  kanto_ascendant = { beyond_kanto = {
    version = 1, active = true, irreversible = true,
  } },
} } }
local crystalPath, crystalTrueColor, crystalSource =
  starters.crystalSpritePath(activeGame, "CHIKORITA")
check(type(crystalPath) == "string"
    and crystalPath:find("/front/normal/152/001.png", 1, true),
  "real Oak partner preview resolves Crystal frame one for Chikorita")
eq(crystalTrueColor, true,
  "real Crystal partner preview remains authored true-colour")
eq(crystalSource, "crystal",
  "real partner preview never silently falls back to a generic front sprite")
local sealedRows = starters.rows(sealedGame, "free")
local sealedExpected = expectedUnmasteredOrder(151)
eq(#sealedExpected, 66,
  "unmastered Kanto contract contains 66 non-capstone rows")
eq(#sealedRows, #sealedExpected,
  "fresh Legacy catalogue hides the five Kanto capstone partners")
for index, row in ipairs(sealedRows) do
  eq(row.id, sealedExpected[index],
    "sealed catalogue preserves filtered authoritative order")
  check(row.dex <= 151, "sealed catalogue contains only #001-151")
end
check(not hasRow(sealedRows, "CHIKORITA"),
  "sealed Legacy catalogue does not advertise a Johto partner")

local free = starters.rows(activeGame, "free")
local freeExpected = expectedUnmasteredOrder(251)
eq(#freeExpected, 118,
  "unmastered #001-251 contract contains 118 non-capstone rows")
eq(#free, #freeExpected,
  "Free Choice hides all eleven capstone partners before three clears")
for index, row in ipairs(free) do
  eq(row.id, freeExpected[index],
    "Free Choice UI preserves filtered authoritative order")
  check(starters.partnerAllowlist[row.id] == true,
    "Free Choice exposes only the authoritative allowlist " .. row.id)
  check(row.def == Data.pokemon[row.id],
    "Free Choice row uses the live canonical definition " .. row.id)
  check(row.dex <= 251, "Free Choice contains no Sinnoh row")
end
check(hasRow(free, "GASTLY"), "Gastly remains a legal base stage")
check(hasRow(free, "DITTO"), "Ditto remains a legal standalone species")
eq(starters.basePartnerIds.GENGAR, nil, "Gengar is excluded as an evolution")
eq(starters.partnerAllowlist.DRAGONITE, nil,
  "Dragonite is excluded as an evolution")
eq(starters.basePartnerIds.PIKACHU, nil, "Pikachu is excluded because Pichu is in range")
eq(starters.basePartnerIds.TURTWIG, nil, "no Sinnoh species enters the allowlist")
eq(free[#free].id, "LARVITAR",
  "unmastered catalogue ends at the last non-capstone base species")
for _, id in ipairs(starters.legendaryOrder) do
  check(not hasRow(free, id),
    "unmastered catalogue keeps capstone partner hidden: " .. id)
end

local balanced = starters.rows(activeGame, "balanced")
check(#balanced > 0 and #balanced < #free,
  "Balanced Choice is a real curated subset")
local sawKanto, sawJohto = false, false
for _, row in ipairs(balanced) do
  check(starters.balancedIds[row.id] == true,
    "Balanced Choice exposes only authored row " .. row.id)
  check(starters.basePartnerIds[row.id] == true,
    "Balanced Choice shares Free Choice's authoritative allowlist " .. row.id)
  sawKanto = sawKanto or row.dex <= 151
  sawJohto = sawJohto or row.dex >= 152
end
check(sawKanto and sawJohto,
  "Balanced Choice contains both Kanto and Johto partners")

local heroCases = {
  RED = { species = "TORCHIC", flag = "EVENT_CHOSE_CHARMANDER" },
  BLUE = { species = "MUDKIP", flag = "EVENT_CHOSE_SQUIRTLE" },
  GREEN = { species = "TREECKO", flag = "EVENT_CHOSE_BULBASAUR" },
}
local function legacySave(hero, unleashed)
  unleashed = unleashed ~= false
  return {
    player = { name = hero, rival = "RIVAL", id = 6500 },
    flags = {
      EVENT_FOLLOWED_OAK_INTO_LAB = true,
      EVENT_OAK_ASKED_TO_CHOOSE_MON = true,
      KA_LEGACY_RIVAL_BALL_TAKEN = true,
    },
    party = {}, pokedex = { seen = {}, owned = {} },
    modData = {
      kanto_ascendant = {
        beyond_kanto = {
          version = 1, active = unleashed,
          irreversible = unleashed or nil,
          decision = unleashed and "activated" or "fresh_gen1",
        },
        legacy_journey = {
          version = 5, cycle = 6, runId = "catalog-engine-" .. hero,
          avatar = hero, rivalBallTaken = true,
        },
      },
    },
  }
end

local sealedChoice = legacySave("RED", false)
local sealedOk, sealedWhy = starters.choose({ data = Data, save = sealedChoice },
  "CHIKORITA", "free", "catalog", "catalog")
eq(sealedOk, false,
  "fresh sealed Legacy run rejects a direct Johto partner choice")
eq(sealedWhy, "beyond-kanto-sealed",
  "sealed partner rejection reports the authoritative boundary")
eq(#sealedChoice.party, 0,
  "rejected non-Kanto partner mutates no party row")
eq(sealedChoice.modData.kanto_ascendant.legacy_journey.partnerChosen, nil,
  "rejected non-Kanto partner leaves Oak's one final choice unconsumed")
for hero, wanted in pairs(heroCases) do
  local choice = starters.heroChoice(legacySave(hero))
  eq(choice.species, wanted.species,
    hero .. " maps the left ball to the required Hoenn partner")
  eq(choice.flag, wanted.flag,
    hero .. " retains the matching vanilla character branch key")
end

local function stack()
  local value = { items = {} }
  function value:push(item) self.items[#self.items + 1] = item return item end
  function value:pop() return table.remove(self.items) end
  function value:top() return self.items[#self.items] end
  return value
end

-- L/R is a circular carousel in both directions. SELECT preserves the
-- nearest Dex position while switching between Balanced and Free.
local navigationGame = {
  data = Data, save = legacySave("RED"), stack = stack(),
}
local navigation = starters.Catalog.new(navigationGame, {}, {
  mode = "free", ball = "catalog", source = "catalog",
})
eq(navigation:current().dex, 1, "Free carousel starts at #001")
navigation:move(-1)
eq(navigation:current().dex, 246,
  "left from #001 wraps to unmastered Larvitar #246")
navigation:move(1)
eq(navigation:current().dex, 1, "right from #246 wraps to #001")
navigation:move(assert(rowIndex(navigation.rows, "CHIKORITA")) - 1)
eq(navigation:current().id, "CHIKORITA", "carousel reaches Johto #152")
check(navigation:toggleMode(), "SELECT switches Free to Balanced")
eq(navigation.mode, "balanced", "mode switch lands in Balanced Choice")
check(navigation:current().dex >= 152,
  "mode switch keeps the nearest available Johto position")

-- Exercise every catalogue text row through the actual draw method while
-- recording Font.draw. The screen's two columns end at x=152 inside the
-- border; no name, type, difficulty or footer may cross that edge.
local Font = require("src.render.Font")
Font.load(Data)
local originalDraw = Font.draw
local drawRows = {}
Font.draw = function(value, x, y, ...)
  drawRows[#drawRows + 1] = { value = tostring(value or ""), x = x, y = y }
  return originalDraw(value, x, y, ...)
end
local okDraw, drawErr = pcall(function()
  local screen = starters.Catalog.new(navigationGame, {}, {
    mode = "free", ball = "catalog", source = "catalog",
  })
  for index, row in ipairs(screen.rows) do
    -- Text layout is the subject here; suppress image allocations in the
    -- headless love stub without altering the live renderer path.
    row.spriteLoaded = true
    screen.index = index
    drawRows = {}
    screen:draw()
    for _, drawn in ipairs(drawRows) do
      local budget = drawn.x == 72 and 80 or drawn.x == 8 and 144 or nil
      if budget then
        check(Font.width(drawn.value) <= budget,
          ("catalog text overflow at #%03d (%s)"):format(index, drawn.value))
      end
    end
  end
end)
Font.draw = originalDraw
check(okDraw, "all legal catalogue entries draw without overflow: "
  .. tostring(drawErr))

-- Claiming the right ball is deliberately cosmetic: it persists neither a
-- rival species nor a player partner before the second confirmation.
local pending = legacySave("BLUE")
local pendingState = pending.modData.kanto_ascendant.legacy_journey
pendingState.rivalBallTaken = true
local unresolved = rival.resolveForJourney(pendingState)
eq(unresolved, nil, "right-ball claim alone leaves rival species unresolved")
eq(pendingState.rivalPartner, nil,
  "right-ball claim alone stores no rival partner line")

-- B from the real catalogue state returns to the lab callback without
-- changing flags, Pokédex, party or partner state.
local cancelStack = stack()
local cancelCount = 0
local cancelSave = legacySave("RED")
local pressed = { b = true }
local cancelGame = {
  data = Data, save = cancelSave, stack = cancelStack,
  input = { wasPressed = function(_, key)
    local value = pressed[key]
    pressed[key] = nil
    return value == true
  end },
}
local cancelCatalog = starters.Catalog.new(cancelGame, {
  onCatalogCancelled = function() cancelCount = cancelCount + 1 end,
}, { mode = "balanced", ball = "catalog", source = "catalog" })
cancelStack:push(cancelCatalog)
cancelCatalog:update()
eq(cancelStack:top(), nil, "B closes the catalogue")
eq(cancelCount, 1, "B releases the lab interaction exactly once")
eq(#cancelSave.party, 0, "catalogue cancel gives no Pokémon")
eq(countKeys(cancelSave.pokedex.seen), 0, "catalogue cancel sets no seen bit")
eq(countKeys(cancelSave.pokedex.owned), 0, "catalogue cancel sets no owned bit")
eq(cancelSave.flags.EVENT_GOT_STARTER, nil,
  "catalogue cancel does not set the starter flag")
eq(cancelSave.modData.kanto_ascendant.legacy_journey.partnerChosen, nil,
  "catalogue cancel does not commit a partner")

-- The first YES only opens the second warning. Declining that warning keeps
-- the catalogue open and still commits absolutely nothing.
local confirmStack = stack()
local confirmSave = legacySave("RED")
local confirmGame = { data = Data, save = confirmSave, stack = confirmStack }
local chosenCount = 0
local confirmCatalog = starters.Catalog.new(confirmGame, {
  onPartnerChosen = function() chosenCount = chosenCount + 1 end,
}, { mode = "free", ball = "catalog", source = "catalog", index = 71 })
confirmStack:push(confirmCatalog)
confirmCatalog:confirm()
local firstPrompt = assert(confirmStack:pop(), "first confirmation is pushed")
check(type(firstPrompt.choice) == "function",
  "first confirmation owns a YES/NO callback")
firstPrompt.choice(true)
local finalPrompt = assert(confirmStack:pop(), "final confirmation is pushed")
check(type(finalPrompt.choice) == "function",
  "second confirmation owns a YES/NO callback")
finalPrompt.choice(false)
eq(confirmStack:top(), confirmCatalog,
  "declining final confirmation returns to the catalogue")
eq(chosenCount, 0, "declining final confirmation calls no receipt callback")
eq(#confirmSave.party, 0, "declining final confirmation gives no Pokémon")
eq(countKeys(confirmSave.pokedex.owned), 0,
  "declining final confirmation sets no Dex bit")
eq(confirmSave.flags.EVENT_GOT_STARTER, nil,
  "declining final confirmation sets no starter flag")

-- Commit a Johto free-choice partner at the API boundary. Exactly one party
-- row and exactly that species' seen/owned bits appear; the rival counter is
-- resolved only now, and a second partner is rejected.
local commitSave = legacySave("BLUE")
local writes = 0
local commitGame = {
  data = Data, save = commitSave,
  writeSave = function() writes = writes + 1 return true end,
}
local committed, mon = starters.choose(commitGame,
  "CHIKORITA", "free", "catalog", "catalog")
check(committed and mon and mon.species == "CHIKORITA",
  "second confirmation commits the selected Johto partner")
eq(writes, 1, "partner commit performs one durable game-save write")
eq(#commitSave.party, 1, "partner commit adds exactly one party member")
eq(commitSave.party[1].species, "CHIKORITA",
  "party contains only the chosen partner")
eq(countKeys(commitSave.pokedex.seen), 1,
  "partner commit sets exactly one seen bit")
eq(countKeys(commitSave.pokedex.owned), 1,
  "partner commit sets exactly one owned bit")
check(commitSave.pokedex.seen.CHIKORITA
    and commitSave.pokedex.owned.CHIKORITA,
  "the sole Dex bit belongs to the selected partner")
eq(commitSave.pokedex.owned.TURTWIG, nil,
  "partner commit introduces no Sinnoh Dex bit")
check(commitSave.flags.EVENT_GOT_STARTER == true,
  "partner commit sets the canonical starter gate")
check(commitSave.flags.EVENT_CHOSE_SQUIRTLE == true,
  "Blue hero keeps the matching vanilla branch key")
eq(commitSave.flags.EVENT_CHOSE_CHARMANDER, nil,
  "Blue hero does not leak Red's branch key")
eq(commitSave.flags.EVENT_CHOSE_BULBASAUR, nil,
  "Blue hero does not leak Green's branch key")
eq(commitSave.flags.EVENT_CHOSE_PIKACHU, nil,
  "catalogue partner never impersonates Yellow's Pikachu")
local committedState = commitSave.modData.kanto_ascendant.legacy_journey
check(committedState.partnerChosen == true
    and committedState.partnerSpecies == "CHIKORITA"
    and committedState.partnerMode == "free",
  "partner state records the exact final catalogue choice")
check(type(committedState.rivalPartner) == "table"
    and committedState.rivalPartner.sourcePartner == "CHIKORITA",
  "rival species resolves only after the final player choice")
local again = starters.choose(commitGame,
  "CYNDAQUIL", "free", "catalog", "catalog")
eq(again, false, "a committed run rejects a second partner")
eq(#commitSave.party, 1, "rejected second choice cannot duplicate the party")
eq(countKeys(commitSave.pokedex.owned), 1,
  "rejected second choice cannot leak another Dex bit")

-- The API boundary must enforce the same graph-derived set that backs the
-- UI: direct calls cannot select an evolution, Pichu's middle stage, a form
-- or Sinnoh.
for _, species in ipairs({ "GENGAR", "DRAGONITE", "PIKACHU", "ASCENDANT_TYPHLOSION", "TURTWIG" }) do
  local rejectedSave = legacySave("RED")
  local rejected = starters.choose({ data = Data, save = rejectedSave },
    species, "free", "catalog", "catalog")
  eq(rejected, false, "API rejects non-allowlist species " .. species)
  eq(#rejectedSave.party, 0, "rejected API choice adds no party row")
end
local pichuSave = legacySave("RED")
local pichuOk, pichu = starters.choose({ data = Data, save = pichuSave },
  "PICHU", "free", "catalog", "catalog")
check(pichuOk and pichu and pichu.species == "PICHU",
  "the real commit API accepts Pichu as Pikachu-line base stage")
check(starters.partnerAllowlist.DITTO,
  "the real authoritative allowlist retains lineless Ditto")

print(("LEGACY PARTNER CATALOG ENGINE PASS: %d assertions")
  :format(assertions))
