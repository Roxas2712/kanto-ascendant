-- Focused headless contract tests for the isolated Apricorn Ball P1 package.

local engineRoot = os.getenv("GEN1RECOMP_DIR") or "."
package.path = engineRoot .. "/?.lua;" .. engineRoot .. "/?/init.lua;"
  .. package.path

local make = assert(loadfile("apricorn_balls.lua"))()

local function eq(actual, expected, message)
  assert(actual == expected, (message or "values differ") .. ": expected "
    .. tostring(expected) .. ", got " .. tostring(actual))
end

local function truthy(value, message) assert(value, message or "expected truthy") end

local function registry()
  local r = { values = {} }
  function r:register(id, value) self.values[id] = value end
  return r
end

local saved = {
  apricorn_balls = { version = 0, friendCatchLedger = { "legacy-capture" } },
}
local german = false
local handlers, hooks = {}, {}
local items, balls, itemEffects = registry(), registry(), registry()
local effects = { BALLS = {} }
local mod = {
  content = { items = items, balls = balls, item_effects = itemEffects },
  events = { on = function(_, name, fn) handlers[name] = fn end },
  hooks = { wrap = function(_, name, fn) hooks[name] = fn end },
  save = {
    get = function(_, key) return saved[key] end,
    set = function(_, key, value) saved[key] = value end,
  },
}

local breeding = { [1] = { gender = 4 }, [2] = { gender = -1 }, [92] = { gender = 4 } }
local A = make(mod, { breedingData = breeding, itemEffects = effects,
  i18n = { text = function(en, de) return german and de or en end } })
A.install()

-- All seven are real engine ball records and real bag-visible item records;
-- GS BALL is deliberately absent from the package.
eq(#A.ITEM_IDS, 7, "exact Apricorn selection")
for _, id in ipairs(A.ITEM_IDS) do
  truthy(items.values[id], id .. " item registered")
  eq(items.values[id].ball, id, id .. " links to ball record")
  truthy(balls.values[id] and balls.values[id].attempt, id .. " has catch callback")
  truthy(itemEffects.values["KA_APRICORN_" .. id],
    id .. " has a no-consumption preflight effect")
  eq(itemEffects.values["KA_APRICORN_" .. id].callStyle, "legacyArgs",
    id .. " explicitly declares its positional item-effect ABI")
  eq(effects.BALLS[id], true, id .. " is accepted by the battle bag")
end
eq(items.values.GS_BALL, nil, "GS Ball omitted")
eq(effects.BALLS.GS_BALL, nil, "GS Ball never gets a bag hook")
local itemHelp = assert(loadfile("item_help.lua"))()()
local helpGame = { data = { items = items.values } }
local helpNeedles = {
  HEAVY_BALL = "300kg", LEVEL_BALL = "x8/x4/x2", LURE_BALL = "actually hooked",
  FAST_BALL = "at least 100", LOVE_BALL = "compatible opposite",
  FRIEND_BALL = "friendship 200", MOON_BALL = "registered Moon Stone",
}
for id, needle in pairs(helpNeedles) do
  truthy(itemHelp.describe(helpGame, id):find(needle, 1, true),
    id .. " item help shows its current bonus and condition")
end

local data = {
  pokemon = {
    BULBASAUR = { id = "BULBASAUR", dex = 1, catchRate = 100,
      weightKg = 6.9, baseStats = { speed = 45 } },
    GASTLY = { id = "GASTLY", dex = 92, catchRate = 190,
      weightKg = 0.1, baseStats = { speed = 80 } },
    HEAVYMON = { id = "HEAVYMON", dex = 1, catchRate = 100,
      weightKg = 300, baseStats = { speed = 40 } },
    MIDMON = { id = "MIDMON", dex = 1, catchRate = 100,
      weightKg = 150, baseStats = { speed = 40 } },
    HUNDRED = { id = "HUNDRED", dex = 1, catchRate = 100,
      weightKg = 100, baseStats = { speed = 40 } },
    NINETY_NINE = { id = "NINETY_NINE", dex = 1, catchRate = 100,
      weightKg = 99.999, baseStats = { speed = 40 } },
    TWOHUNDRED = { id = "TWOHUNDRED", dex = 1, catchRate = 100,
      weightKg = 200, baseStats = { speed = 40 } },
    FASTMON = { id = "FASTMON", dex = 1, catchRate = 100,
      weightKg = 10, baseStats = { speed = 100 } },
    SLOWFAST = { id = "SLOWFAST", dex = 1, catchRate = 100,
      weightKg = 10, baseStats = { speed = 99 } },
    GENDERLESS = { id = "GENDERLESS", dex = 2, catchRate = 100,
      weightKg = 10, baseStats = { speed = 50 } },
    NIDORINA = { id = "NIDORINA", dex = 30, catchRate = 120,
      weightKg = 20, baseStats = { speed = 56 },
      evolutions = { { method = "ITEM", species = "NIDOQUEEN", item = "MOON_STONE" } } },
    NIDORAN_F = { id = "NIDORAN_F", dex = 29, catchRate = 235,
      weightKg = 7, baseStats = { speed = 41 },
      evolutions = { { method = "LEVEL", species = "NIDORINA", level = 16 } } },
    NIDOQUEEN = { id = "NIDOQUEEN", dex = 31, catchRate = 45,
      weightKg = 60, baseStats = { speed = 76 }, evolutions = {} },
  },
}

local function context(species, extra)
  local target = { species = species, level = 10, dvs = { attack = 0 } }
  local out = { targetMon = target, targetDef = data.pokemon[species], data = data,
    playerMon = { species = species, level = 40, dvs = { attack = 15 } } }
  for key, value in pairs(extra or {}) do out[key] = value end
  return out
end

-- Heavy Ball uses the modern additive thresholds, including the negative
-- bands; it must not quietly be a multiplier in disguise.
local q = A.quote("HEAVY_BALL", context("HEAVYMON"))
eq(q.rate, 130, "Heavy Ball +30 at 300kg")
eq(q.reason, "weight_300kg_plus", "Heavy Ball reason")
q = A.quote("HEAVY_BALL", context("MIDMON"))
eq(q.rate, 100, "Heavy Ball neutral in 100kg to 199kg band")
q = A.quote("HEAVY_BALL", context("HUNDRED"))
eq(q.rate, 100, "Heavy Ball neutral exactly at 100kg")
q = A.quote("HEAVY_BALL", context("TWOHUNDRED"))
eq(q.rate, 120, "Heavy Ball +20 at 200kg")
q = A.quote("HEAVY_BALL", context("NINETY_NINE"))
eq(q.rate, 80, "Heavy Ball -20 immediately below 100kg")
q = A.quote("HEAVY_BALL", context("BULBASAUR"))
eq(q.rate, 80, "Heavy Ball -20 under 100kg")

q = A.quote("LEVEL_BALL", context("BULBASAUR"))
eq(q.multiplier, 8, "Level Ball four-times level")
q = A.quote("LEVEL_BALL", context("BULBASAUR", {
  playerMon = { species = "BULBASAUR", level = 20, dvs = { attack = 15 } },
}))
eq(q.multiplier, 4, "Level Ball twice level")
q = A.quote("LEVEL_BALL", context("BULBASAUR", {
  playerMon = { species = "BULBASAUR", level = 11, dvs = { attack = 15 } },
}))
eq(q.multiplier, 2, "Level Ball strictly higher level")
q = A.quote("LEVEL_BALL", context("BULBASAUR", {
  playerMon = { species = "BULBASAUR", level = 10, dvs = { attack = 15 } },
}))
eq(q.multiplier, 1, "Level Ball equal level has no bonus")
q = A.quote("LURE_BALL", context("GASTLY", { encounterSource = "fishing" }))
eq(q.multiplier, 3, "Lure Ball fishing")
q = A.quote("LURE_BALL", context("GASTLY"))
eq(q.reason, "not_fishing", "Lure Ball non-fishing explanation")
q = A.quote("LURE_BALL", context("GASTLY", { fishing = true }))
eq(q.reason, "not_fishing", "Lure Ball rejects a loose non-runtime fishing flag")
q = A.quote("FAST_BALL", context("FASTMON"))
eq(q.multiplier, 4, "Fast Ball base speed 100")
local formatted = assert(A.formatQuote(q))
eq(formatted.text, "CATCH RATE x4\nBASE SPEED HIGH",
  "positive Fast Ball quote exposes live bonus and reason")
eq(formatted.effective, "positive", "positive quote is classified")
q = A.quote("FAST_BALL", context("GASTLY"))
eq(q.multiplier, 1, "Fast Ball below threshold")
formatted = assert(A.formatQuote(q))
eq(formatted.text, "CATCH RATE x1\nBASE SPEED LOW",
  "negative Fast Ball quote exposes no-bonus reason")
eq(formatted.effective, "negative", "no-bonus quote is classified")
q = A.quote("FAST_BALL", context("SLOWFAST"))
eq(q.multiplier, 1, "Fast Ball rejects base Speed 99")

q = A.quote("LOVE_BALL", context("BULBASAUR"))
eq(q.multiplier, 8, "Love Ball opposite genders")
q = A.quote("LOVE_BALL", context("BULBASAUR", {
  playerMon = { species = "GASTLY", level = 40, dvs = { attack = 15 } },
}))
eq(q.reason, "different_species", "Love Ball species condition")
q = A.quote("LOVE_BALL", context("BULBASAUR", {
  targetMon = { species = "BULBASAUR", level = 10, dvs = { attack = 15 } },
}))
eq(q.reason, "same_species_same_or_genderless", "Love Ball rejects same gender")
q = A.quote("LOVE_BALL", context("GENDERLESS", {
  playerMon = { species = "GENDERLESS", level = 40, dvs = { attack = 15 } },
}))
eq(q.reason, "same_species_same_or_genderless", "Love Ball rejects genderless pair")
q = A.quote("MOON_BALL", context("NIDORINA"))
eq(q.multiplier, 4, "Moon Ball reads an explicit Moon-Stone registry edge")
q = A.quote("MOON_BALL", context("NIDORAN_F"))
eq(q.multiplier, 4, "Moon Ball registry walk includes a pre-evolution")
q = A.quote("MOON_BALL", context("NIDOQUEEN"))
eq(q.multiplier, 4, "Moon Ball registry walk includes the final evolution")
q = A.quote("MOON_BALL", context("GASTLY"))
eq(q.reason, "not_moon_stone_line", "Moon Ball non-line explanation")
q = A.quote("MOON_BALL", { targetMon = { species = "NIDORINA", level = 10 },
  targetDef = data.pokemon.NIDORINA,
  data = { pokemon = { NIDORINA = data.pokemon.NIDORINA } } })
eq(q.available, false, "Moon Ball refuses a registry without Moon-Stone edges")
eq(q.reason, "missing_moon_stone_registry", "Moon Ball missing-registry reason")

-- Trainer and story captures are blocked before metadata/calculation, and a
-- missing datum produces an inspectable refusal rather than an invisible 1x.
q = A.quote("FAST_BALL", context("FASTMON", { battle = { kind = "trainer" } }))
eq(q.available, false, "trainer ball unavailable")
eq(q.reason, "trainer_battle", "trainer reason")
q = A.quote("FAST_BALL", context("FASTMON", { battle = { kind = "wild", noCatch = true } }))
eq(q.reason, "story_blocked", "story reason")
q = A.quote("FAST_BALL", { targetMon = { species = "UNKNOWN", level = 1 },
  targetDef = { id = "UNKNOWN", catchRate = 20, weightKg = 2 }, data = data })
eq(q.available, false, "missing speed is not neutral")
eq(q.reason, "missing_base_speed", "missing speed reason")

-- Every available reason has a shared two-line renderer in both languages.
-- Count rendered glyphs rather than UTF-8 bytes so German umlauts cannot
-- create a false overflow or split.
local function glyphs(text)
  local count = 0
  for index = 1, #text do
    local byte = text:byte(index)
    if byte < 0x80 or byte >= 0xC0 then count = count + 1 end
  end
  return count
end
local displayQuotes = {
  A.quote("HEAVY_BALL", context("HEAVYMON")),
  A.quote("HEAVY_BALL", context("NINETY_NINE")),
  A.quote("LEVEL_BALL", context("BULBASAUR")),
  A.quote("LEVEL_BALL", context("BULBASAUR", {
    playerMon = { species = "BULBASAUR", level = 10, dvs = { attack = 15 } },
  })),
  A.quote("LURE_BALL", context("GASTLY", { encounterSource = "fishing" })),
  A.quote("LURE_BALL", context("GASTLY")),
  A.quote("FAST_BALL", context("FASTMON")),
  A.quote("FAST_BALL", context("SLOWFAST")),
  A.quote("LOVE_BALL", context("BULBASAUR")),
  A.quote("LOVE_BALL", context("BULBASAUR", {
    playerMon = { species = "GASTLY", level = 40, dvs = { attack = 15 } },
  })),
  A.quote("LOVE_BALL", context("BULBASAUR", {
    targetMon = { species = "BULBASAUR", level = 10, dvs = { attack = 15 } },
  })),
  A.quote("FRIEND_BALL", context("BULBASAUR")),
  A.quote("MOON_BALL", context("NIDORINA")),
  A.quote("MOON_BALL", context("GASTLY")),
}
for _, language in ipairs({ "en", "de" }) do
  german = language == "de"
  for _, quote in ipairs(displayQuotes) do
    local display, err = A.formatQuote(quote)
    truthy(display, language .. " display exists for " .. quote.reason
      .. ": " .. tostring(err))
    eq(#display.lines, 2, language .. " quote uses exactly two lines")
    for _, line in ipairs(display.lines) do
      truthy(glyphs(line) <= A.DISPLAY_WIDTH,
        language .. " quote fits 18 glyphs: " .. line)
    end
  end
end
german = false
local blockedDisplay = A.formatQuote(A.quote("FAST_BALL",
  context("FASTMON", { battle = { kind = "trainer" } })))
eq(blockedDisplay, nil, "trainer battle never receives a bonus display")

-- The normal BagMenu consumes only after ItemEffects returns "ball". Every
-- Apricorn item now performs this preflight first, so trainer/no-catch
-- attempts preserve the real bag count and never reach a throw.
local ItemEffects = require("src.inventory.ItemEffects")
local effectData = { pokemon = data.pokemon, items = {}, item_effects = itemEffects.values }
for _, id in ipairs(A.ITEM_IDS) do
  effectData.items[id] = { id = id, ball = id, effect = "KA_APRICORN_" .. id }
end
local blockedSave = { inventory = { FAST_BALL = 2 }, player = { name = "RED" } }
local blockedResult, _, blockedExtra = ItemEffects.use(effectData, blockedSave,
  "FAST_BALL", nil, { kind = "trainer",
    enemy = { mon = { species = "FASTMON", level = 10 }, def = data.pokemon.FASTMON },
    game = { data = effectData } })
eq(blockedResult, "failed", "trainer Apricorn preflight blocks before BagMenu consumption")
eq(blockedSave.inventory.FAST_BALL, 2, "trainer block leaves the ball in the Bag")
eq(blockedExtra.apricornQuote.reason, "trainer_battle", "trainer block keeps its precise reason")
local noCatchResult, _, noCatchExtra = ItemEffects.use(effectData, blockedSave,
  "FAST_BALL", nil, { kind = "wild", noCatch = true,
    enemy = { mon = { species = "FASTMON", level = 10 }, def = data.pokemon.FASTMON },
    game = { data = effectData } })
eq(noCatchResult, "failed", "story no-catch preflight blocks before consumption")
eq(blockedSave.inventory.FAST_BALL, 2, "story block leaves the ball in the Bag")
eq(noCatchExtra.apricornQuote.reason, "story_blocked", "story block keeps its precise reason")
local legalBattle = { kind = "wild",
    player = { mon = { species = "FASTMON", level = 10, dvs = { attack = 0 } } },
    enemy = { mon = { species = "FASTMON", level = 10 }, def = data.pokemon.FASTMON },
    game = { data = effectData } }
local legalResult, legalPayload, legalExtra = ItemEffects.use(effectData,
  blockedSave, "FAST_BALL", nil, legalBattle)
eq(legalResult, "ball", "legal wild Apricorn attempt reaches the normal BagMenu throw path")
eq(legalPayload[1], "CATCH RATE x4\nBASE SPEED HIGH",
  "legal preflight returns the visible battle quote")
eq(legalExtra.apricornDisplay.text, legalPayload[1],
  "preflight payload and shared formatted API are identical")
eq(legalBattle.apricornBallQuote.formatted.text, legalPayload[1],
  "live battle stores the same formatted quote")

local wildHook = assert(hooks["battle.wild"], "Lure Ball installs the native fishing marker hook")
local fishingOpts = { hooked = true }
wildHook(function(encounter) return encounter end, { species = "GASTLY", level = 10 },
  { opts = fishingOpts })
eq(fishingOpts.encounterSource, "fishing", "only a native hooked encounter receives fishing source")
local grassOpts = {}
wildHook(function(encounter) return encounter end, { species = "GASTLY", level = 10 },
  { opts = grassOpts })
eq(grassOpts.encounterSource, nil, "ordinary water/grass wild encounter is not marked fishing")

-- The registered attempt is exercised through the real Catching callback
-- seam.  It forwards the fully explained rate into vanillaAttempt, not a
-- separate preview formula.
local Catching = require("src.battle.Catching")
local wildBattle = { kind = "wild", game = { data = data }, player = { mon = {
  species = "FASTMON", level = 10, dvs = { attack = 0 },
} } }
local caught, shakes = Catching.attempt("FAST_BALL", {
  species = "FASTMON", level = 10, dvs = { attack = 0 }, hp = 100,
  stats = { hp = 100 },
}, data.pokemon.FASTMON, function() return 0 end, nil, {
  ballDef = balls.values.FAST_BALL, battle = wildBattle,
})
eq(wildBattle.apricornBallQuote.rate, 255, "rate is clamped before engine roll")
eq(caught, true, "registered callback returns engine result")
eq(shakes, 3, "registered callback returns engine shakes")

-- Friend Ball awards the Johto friendship field only after the engine emits a
-- successful pokemon.caught event.  The event carries the same mon whether
-- the engine put it in party or PC, so both destinations remain covered.
local pcMon = { species = "BULBASAUR", johtoBond = 12 }
eq(pcMon.johtoBond, 12, "no friendship before catch")
handlers["pokemon.caught"]({ ball = "FRIEND_BALL", mon = pcMon, destination = "box" })
eq(pcMon.johtoBond, 200, "Friend Ball PC catch friendship")
local applied, why = A.applyFriendship(pcMon)
eq(applied, false, "Friend Ball idempotence")
eq(why, "already_applied", "Friend Ball idempotence reason")
local partyMon = { species = "BULBASAUR", johtoBond = 255 }
handlers["pokemon.caught"]({ ball = "POKE_BALL", mon = partyMon, destination = "party" })
eq(partyMon.johtoBond, 255, "ordinary ball cannot award friendship")

-- Legacy P1 save data normalizes without replaying an old reward; item
-- ownership is canonical engine inventory/PC state and needs no duplicate bag.
eq(saved.apricorn_balls.version, A.STATE_VERSION, "save migration version")
eq(saved.apricorn_balls.migrated, true, "legacy save marked migrated")
truthy(saved.apricorn_balls.legacyFriendCatchLedger, "legacy ledger preserved")
local coverageData, coverageBreeding = { pokemon = {} }, {}
for dex = 1, 251 do
  local id = "S" .. dex
  coverageData.pokemon[id] = { id = id, dex = dex, catchRate = 45,
    weightKg = 10, baseStats = { speed = 50 } }
  coverageBreeding[dex] = { gender = 4 }
end
local coverage = make({ save = mod.save }, { breedingData = coverageBreeding })
  .validateSpecies(coverageData)
eq(coverage.complete, true, "251-species weight/speed/gender coverage")
eq(coverage.species, 251, "coverage species count")

print("apricorn_balls_test: PASS")
