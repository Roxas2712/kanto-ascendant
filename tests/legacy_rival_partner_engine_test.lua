-- Real-data NG+ rival-partner contract.
--
-- Run from the Gen1 Recomp checkout:
--   TRAINER_REMATCH_MOD_DIR=../kanto-ascendant \
--     luajit ../kanto-ascendant/tests/legacy_rival_partner_engine_test.lua

package.path = "./?.lua;./?/init.lua;" .. package.path
local T = require("tests.modkit")
local Data = require("src.core.Data")
if not (Data.pokemon and Data.pokemon.BULBASAUR) then Data:load() end

local checks = 0
local function ok(value, label)
  checks = checks + 1
  assert(value, label)
end
local function eq(actual, expected, label)
  ok(actual == expected, label .. " (got " .. tostring(actual)
    .. ", expected " .. tostring(expected) .. ")")
end

local originalKanto = {}
for species, def in pairs(Data.pokemon) do
  if tonumber(def.dex) and def.dex >= 1 and def.dex <= 151 then
    originalKanto[#originalKanto + 1] = species
  end
end
table.sort(originalKanto, function(a, b)
  return Data.pokemon[a].dex < Data.pokemon[b].dex
end)
eq(#originalKanto, 151, "real engine data exposes all 151 Kanto species")

local modPath = os.getenv("TRAINER_REMATCH_MOD_DIR")
  or "mods/kanto_ascendant"
local run = T.sdk.loadMod(modPath, { data = Data })
ok(run.mod ~= nil, "Kanto Ascendant loads in the engine SDK")
eq(#(run.errors or {}), 0, "real engine/mod merge is clean")
local exports = assert(run.loader.exports.kanto_ascendant)
local rival = assert(exports.legacyRivalPartner,
  "legacy rival-partner export is installed")
local partnerCatalogue = assert(exports.legacyStarters,
  "Legacy partner catalogue export is installed")
local activeCatalogueGame = { data = Data, save = { modData = {
  kanto_ascendant = { beyond_kanto = {
    version = 1, active = true, irreversible = true,
  } },
} } }
local freeRows = partnerCatalogue.rows(activeCatalogueGame, "free")
local expectedFree = {}
for _, id in ipairs(partnerCatalogue.partnerAllowlistOrder) do
  if not partnerCatalogue.legendaryIds[id] then
    expectedFree[#expectedFree + 1] = id
  end
end
eq(#expectedFree, 118,
  "unmastered rival contract contains 118 non-capstone choices")
eq(#freeRows, #expectedFree,
  "rival QA sees the filtered authoritative order used by the UI")
eq(freeRows[1].id, "BULBASAUR",
  "the real graphical catalogue begins with Bulbasaur")
eq(freeRows[#freeRows].id, "LARVITAR",
  "the unmastered graphical catalogue closes with Larvitar")
local previousDex = 0
for index, row in ipairs(freeRows) do
  eq(row.id, expectedFree[index],
    "real catalogue row follows the filtered authoritative allowlist")
  ok(partnerCatalogue.partnerAllowlist[row.id] == true,
    "real catalogue row is commit-legal")
  ok(row.dex > previousDex and row.dex <= 251,
    "real catalogue row retains increasing canonical Dex placement")
  previousDex = row.dex
  eq(Data.pokemon[row.id], row.def,
    "real catalogue row " .. row.dex .. " uses the canonical registered record")
end
ok(partnerCatalogue.partnerAllowlist.DITTO,
  "rival QA retains lineless Ditto")
eq(partnerCatalogue.partnerAllowlist.GENGAR, nil,
  "rival QA excludes Gengar")
eq(partnerCatalogue.partnerAllowlist.DRAGONITE, nil,
  "rival QA excludes Dragonite")
eq(partnerCatalogue.partnerAllowlist.PIKACHU, nil,
  "rival QA excludes Pikachu because Pichu is its base stage")

local SaveData = require("src.core.SaveData")
local Pokemon = require("src.pokemon.Pokemon")
local BattleState = require("src.battle.BattleState")
local save = SaveData.newGame()
save.modData = save.modData or {}
save.modData.kanto_ascendant = save.modData.kanto_ascendant or {}
local journey = { rivalClaimed = true }
save.modData.kanto_ascendant.legacy_journey = journey
run.loader.modSave = save.modData
local game = {
  data = Data,
  save = save,
  stack = { push = function() end },
}
game.save.party = {
  Pokemon.new(Data, "RATTATA", 100, function() return 8 end),
}
rival.bindGame(game)

-- Claim and cancel do not leak a species. The right ball is cosmetic until
-- the catalogue/left-ball choice has received its second confirmation.
local pending = rival.resolveForJourney(journey)
eq(pending, nil, "right-ball claim alone leaves rival species unresolved")
eq(journey.rivalPartner, nil, "claim alone stores no rival line")
journey.partnerSpecies = "TORCHIC"
pending = rival.resolveForJourney(journey)
eq(pending, nil, "unconfirmed player choice leaves rival unresolved")
eq(journey.rivalPartner, nil, "cancelled choice stores no rival line")

journey.partnerChosen = true
local hoennCounter = assert(rival.resolveForJourney(journey))
eq(hoennCounter.lineId, "hoenn_water",
  "Torchic's committed rival counter is the Mudkip family")
eq(hoennCounter.base, "MUDKIP", "Hoenn rival starts with Mudkip")
eq(hoennCounter.mid, "MARSHTOMP", "Hoenn rival reaches Marshtomp")
eq(hoennCounter.final, "SWAMPERT", "Hoenn rival reaches Swampert")
eq(hoennCounter.sourcePartner, "TORCHIC",
  "stored rival line records the committed source partner")

local firstStored = journey.rivalPartner
eq(rival.resolveForJourney(journey), firstStored,
  "repeat resolution reuses the stored table")
local reloaded = {
  partnerChosen = true,
  partnerSpecies = journey.partnerSpecies,
  rivalPartner = {},
}
for key, value in pairs(journey.rivalPartner) do
  reloaded.rivalPartner[key] = value
end
local reloadStored = reloaded.rivalPartner
eq(rival.resolveForJourney(reloaded), reloadStored,
  "serialized/reloaded valid line is not rerolled")

eq(rival.chooseForSpecies("BULBASAUR").lineId, "kanto_fire",
  "Kanto starter triangle retains its type counter")
eq(rival.chooseForSpecies("CHARMANDER").lineId, "kanto_water",
  "Charmander is countered by the Squirtle line")
eq(rival.chooseForSpecies("SQUIRTLE").lineId, "kanto_grass",
  "Squirtle is countered by the Bulbasaur line")
eq(rival.chooseForSpecies("CHIKORITA").lineId, "johto_fire",
  "Johto starter triangle retains its type counter")
eq(rival.chooseForSpecies("CYNDAQUIL").lineId, "johto_water",
  "Cyndaquil is countered by the Totodile line")
eq(rival.chooseForSpecies("TOTODILE").lineId, "johto_grass",
  "Totodile is countered by the Chikorita line")
eq(rival.chooseForSpecies("TREECKO").lineId, "hoenn_fire",
  "fixed Green Hoenn starter is countered by Torchic")
eq(rival.chooseForSpecies("MUDKIP").lineId, "hoenn_grass",
  "fixed Blue Hoenn starter is countered by Treecko")

-- Free/Balanced Oak choices stay inside the exact same authoritative
-- unmastered allowlist. The earned left Hoenn ball keeps the explicit
-- triangle above, but no ordinary catalogue choice may pull a hidden Hoenn
-- fallback out of the right ball.
local linesById = {}
for _, line in ipairs(rival.lines) do linesById[line.lineId] = line end
local function chartMultiplier(attack, defenders)
  local multiplier = 10
  for _, defender in ipairs(defenders or {}) do
    local found = 10
    for _, row in ipairs(Data.type_chart.matchups or {}) do
      if row.attacker == attack and row.defender == defender then
        found = tonumber(row.multiplier) or 10
        break
      end
    end
    multiplier = math.floor(multiplier * found / 10)
  end
  return multiplier
end
for _, row in ipairs(freeRows) do
  local first = assert(rival.chooseForSpecies(row.id),
    "no catalogue rival line for " .. row.id)
  local second = assert(rival.chooseForSpecies(row.id),
    "unstable catalogue rival line for " .. row.id)
  eq(first.lineId, second.lineId,
    row.id .. " catalogue rival line is deterministic")
  ok(partnerCatalogue.partnerAllowlist[first.base] == true,
    row.id .. " rival base remains in the legal authored list")
  ok(not first.lineId:match("^hoenn_"),
    row.id .. " never receives a general Hoenn fallback")
  ok(Data.pokemon[first.base] and Data.pokemon[first.mid]
      and Data.pokemon[first.final],
    row.id .. " catalogue rival keeps three real registered milestones")
  local line, best = assert(linesById[first.lineId]), 10
  for _, attack in ipairs(line.attacks) do
    best = math.max(best, chartMultiplier(attack, row.def.types))
  end
  ok(best > 10,
    row.id .. " catalogue rival has a real super-effective attack type")
end

-- Repair the exact stale shape produced by earlier 6.5 candidates once,
-- then retain the repaired table through repeat resolution and serialization.
local staleCatalogueJourney = {
  partnerChosen = true,
  partnerSpecies = "GASTLY",
  rivalPartner = {
    version = 1, lineId = "hoenn_water", sourcePartner = "GASTLY",
    base = "MUDKIP", mid = "MARSHTOMP", final = "SWAMPERT",
  },
}
local staleTable = staleCatalogueJourney.rivalPartner
local repaired = assert(rival.resolveForJourney(staleCatalogueJourney))
ok(repaired ~= staleTable,
  "a stale catalogue-to-Hoenn binding is migrated exactly once")
ok(partnerCatalogue.partnerAllowlist[repaired.base] == true,
  "the migrated rival base returns to the authoritative catalogue")
eq(rival.resolveForJourney(staleCatalogueJourney), repaired,
  "repeat resolution reuses the repaired rival table")
local repairedReload = {
  partnerChosen = true,
  partnerSpecies = staleCatalogueJourney.partnerSpecies,
  rivalPartner = {},
}
for key, value in pairs(repaired) do repairedReload.rivalPartner[key] = value end
local serializedRepair = repairedReload.rivalPartner
eq(rival.resolveForJourney(repairedReload), serializedRepair,
  "serialized/reloaded catalogue repair is not rerolled")

-- Every Kanto/Johto catalogue entry has a deterministic, constructible and
-- non-identical strong counterpart. This includes awkward types and all
-- evolved species even though the UI itself exposes only legal bases.
local catalogue = {}
for _, species in ipairs(originalKanto) do catalogue[#catalogue + 1] = species end
for _, species in ipairs(assert(exports.johtoData).order) do
  catalogue[#catalogue + 1] = species
end
eq(#catalogue, 251, "coverage matrix contains exactly dex 001-251")
for _, species in ipairs(catalogue) do
  local a = assert(rival.chooseForSpecies(species), "no line for " .. species)
  local b = assert(rival.chooseForSpecies(species), "unstable line for " .. species)
  eq(a.lineId, b.lineId, species .. " rival line is deterministic")
  ok(Data.pokemon[a.base] and Data.pokemon[a.mid] and Data.pokemon[a.final],
    species .. " counterpart stages all exist in merged data")
  ok(species ~= a.base and species ~= a.mid and species ~= a.final,
    species .. " is never paired with its own family")
  local stats = Data.pokemon[a.final].baseStats
  local total = 0
  for _, value in pairs(stats or {}) do total = total + (tonumber(value) or 0) end
  ok(total >= 390, species .. " counterpart final form is meaningfully strong")
end

local function rowSignature(row)
  local moves = type(row.moves) == "table" and table.concat(row.moves, ",") or ""
  return table.concat({ row.species, tostring(row.level), moves }, ":")
end

-- The live hook walks all 24 real Red/Blue rival parties. Only the final
-- authored starter slot changes; levels and every other row remain exact.
local rbCases = {
  { class = "OPP_RIVAL1", count = 9 },
  { class = "OPP_RIVAL2", count = 12 },
  { class = "OPP_RIVAL3", count = 3 },
}
for _, group in ipairs(rbCases) do
  for index = 1, group.count do
    local source = assert(Data.trainers[group.class].parties[index])
    local beforeLast = rowSignature(source[#source])
    local out = run.loader.hooks:call("trainer.party",
      function(_, _, party) return party end, group.class, index, source)
    eq(#out, #source, group.class .. " party " .. index .. " keeps team size")
    for slot = 1, #source - 1 do
      eq(rowSignature(out[slot]), rowSignature(source[slot]),
        group.class .. " party " .. index .. " preserves slot " .. slot)
    end
    local stage = group.class == "OPP_RIVAL1" and "base"
      or group.class == "OPP_RIVAL2" and (index <= 6 and "mid" or "final")
      or "final"
    eq(out[#out].species, hoennCounter[stage],
      group.class .. " party " .. index .. " uses the correct milestone")
    eq(out[#out].level, source[#source].level,
      group.class .. " party " .. index .. " retains starter-slot level")
    eq(rowSignature(source[#source]), beforeLast,
      group.class .. " party " .. index .. " source roster is immutable")
    -- Stock 0.1.86 exposes the trainer.party hook but not the newer
    -- BattleState.validTrainerPartyDef helper. Enter the real constructor
    -- instead: an unknown species/level fails there, while a newer engine's
    -- invalid-hook fallback is caught by the exact roster comparison below.
    local battle = BattleState.newTrainer(game, group.class, index)
    eq(#battle.enemyParty, #out,
      group.class .. " party " .. index .. " constructs at the hooked size")
    for slot, expected in ipairs(out) do
      local actual = assert(battle.enemyParty[slot])
      eq(actual.species, expected.species,
        group.class .. " party " .. index .. " constructs species " .. slot)
      eq(actual.level, expected.level,
        group.class .. " party " .. index .. " constructs level " .. slot)
    end
    ok(battle.trainerPartyHookFallback ~= true,
      group.class .. " party " .. index .. " is accepted without fallback")
  end
end

-- Enter actual engine BattleState construction for one encounter per curve
-- milestone; this catches invalid IDs that a table-only assertion would miss.
for _, spec in ipairs({
  { "OPP_RIVAL1", 1, "MUDKIP" },
  { "OPP_RIVAL2", 1, "MARSHTOMP" },
  { "OPP_RIVAL3", 1, "SWAMPERT" },
}) do
  local battle = BattleState.newTrainer(game, spec[1], spec[2])
  eq(battle.enemyParty[#battle.enemyParty].species, spec[3],
    spec[1] .. " enters a real battle with the resolved partner stage")
  ok(battle.trainerPartyHookFallback ~= true,
    spec[1] .. " does not trigger engine party-hook fallback")
end

-- Exact Pokémon Yellow rival rows, mirrored from pret/pokeyellow
-- data/trainers/parties.asm. Eevee remains unevolved through Pokémon Tower;
-- Silph, Route 22 and Champion are the three authored Eeveelution branches.
local function party(spec)
  local rows = {}
  for token in spec:gmatch("[^,]+") do
    local species, level = token:match("^([A-Z0-9_]+):(%d+)$")
    rows[#rows + 1] = { species = species, level = tonumber(level) }
  end
  return rows
end
local yellow = {
  OPP_RIVAL1 = {
    party("EEVEE:5"),
    party("SPEAROW:9,EEVEE:8"),
    party("SPEAROW:18,SANDSHREW:15,RATTATA:15,EEVEE:17"),
  },
  OPP_RIVAL2 = {
    party("SPEAROW:19,RATTATA:16,SANDSHREW:18,EEVEE:20"),
    party("FEAROW:25,SHELLDER:23,VULPIX:22,SANDSHREW:20,EEVEE:25"),
    party("FEAROW:25,MAGNEMITE:23,SHELLDER:22,SANDSHREW:20,EEVEE:25"),
    party("FEAROW:25,VULPIX:23,MAGNEMITE:22,SANDSHREW:20,EEVEE:25"),
    party("SANDSLASH:38,NINETALES:35,CLOYSTER:37,KADABRA:35,JOLTEON:40"),
    party("SANDSLASH:38,CLOYSTER:35,MAGNETON:37,KADABRA:35,FLAREON:40"),
    party("SANDSLASH:38,MAGNETON:35,NINETALES:37,KADABRA:35,VAPOREON:40"),
    party("SANDSLASH:47,EXEGGCUTE:45,NINETALES:45,CLOYSTER:47,KADABRA:50,JOLTEON:53"),
    party("SANDSLASH:47,EXEGGCUTE:45,CLOYSTER:45,MAGNETON:47,KADABRA:50,FLAREON:53"),
    party("SANDSLASH:47,EXEGGCUTE:45,MAGNETON:45,NINETALES:47,KADABRA:50,VAPOREON:53"),
  },
  OPP_RIVAL3 = {
    party("SANDSLASH:61,ALAKAZAM:59,EXEGGUTOR:61,CLOYSTER:61,NINETALES:63,JOLTEON:65"),
    party("SANDSLASH:61,ALAKAZAM:59,EXEGGUTOR:61,MAGNETON:61,CLOYSTER:63,FLAREON:65"),
    party("SANDSLASH:61,ALAKAZAM:59,EXEGGUTOR:61,NINETALES:61,MAGNETON:63,VAPOREON:65"),
  },
}
for class, parties in pairs(yellow) do
  for index, source in ipairs(parties) do
    local oldPartner = source[#source].species
    local out = rival.replaceParty(class, index, source, hoennCounter, true)
    for slot = 1, #source - 1 do
      eq(rowSignature(out[slot]), rowSignature(source[slot]),
        "Yellow " .. class .. "/" .. index .. " preserves slot " .. slot)
    end
    eq(out[#out].species, oldPartner == "EEVEE" and "MUDKIP" or "SWAMPERT",
      "Yellow " .. class .. "/" .. index .. " preserves Eevee milestone")
    eq(out[#out].level, source[#source].level,
      "Yellow " .. class .. "/" .. index .. " preserves partner level")
  end
end

local yellowSpecial = {
  partnerChosen = true, partnerSpecies = "PIKACHU", partnerMode = "yellow",
}
local yellowEevee = assert(rival.resolveForJourney(yellowSpecial))
eq(yellowEevee.base, "EEVEE",
  "Yellow's direct Pikachu path resolves the sole rival ball as Eevee")
eq(yellowEevee.mid, "EEVEE",
  "Yellow's authored early rival curve keeps Eevee")
eq(yellowEevee.final, "JOLTEON",
  "Yellow's authored Eevee line retains a real final evolution")

-- Dedicated Yellow hook adapter: even if the identity-team layer handed it
-- a foreign roster, it restarts from Yellow's real registered party and does
-- not touch save.rivalStarter (which controls story dialogue/branch flags).
local Hooks = require("src.mods.Hooks")
local yhooks, yevents = Hooks.new(), {}
local yjourney = {
  rivalClaimed = true, partnerChosen = true, partnerSpecies = "TORCHIC",
  rivalPartner = hoennCounter,
}
local ymod = {
  id = "kanto_ascendant",
  content = { pokemon = { get = function(_, species)
    return Data.pokemon[species]
  end } },
  save = { get = function(_, key)
    return key == "legacy_journey" and yjourney or nil
  end },
  hooks = { wrap = function(_, name, fn, priority)
    return yhooks:wrap(name, fn, priority, "yellow-rival-test")
  end },
  events = { on = function(_, name, fn) yevents[name] = fn end },
}
local makeRival = assert(loadfile(modPath .. "/legacy_rival_partner.lua"))()
local yellowRival = makeRival(ymod, {
  GameVersion = { isYellow = function() return true end },
})
local yellowSave = {
  rivalStarter = 2,
  modData = { kanto_ascendant = { legacy_journey = yjourney } },
}
yellowRival.bindGame({
  data = { pokemon = Data.pokemon, type_chart = Data.type_chart,
    trainers = {
      OPP_RIVAL1 = { parties = yellow.OPP_RIVAL1 },
      OPP_RIVAL2 = { parties = yellow.OPP_RIVAL2 },
      OPP_RIVAL3 = { parties = yellow.OPP_RIVAL3 },
    } },
  save = yellowSave,
})
local canonical = yellow.OPP_RIVAL2[6]
local mangled = party("PIKACHU:99,SNORLAX:99,BLASTOISE:99")
local adapted = yhooks:call("trainer.party",
  function(_, _, rows) return rows end, "OPP_RIVAL2", 6, mangled)
eq(#adapted, #canonical, "Yellow adapter restores canonical team size")
for slot = 1, #canonical - 1 do
  eq(rowSignature(adapted[slot]), rowSignature(canonical[slot]),
    "Yellow adapter restores canonical non-partner slot " .. slot)
end
eq(adapted[#adapted].species, "SWAMPERT",
  "Yellow adapter replaces only the evolved Eevee slot")
eq(yellowSave.rivalStarter, 2,
  "Yellow rivalStarter story branch remains untouched")

-- A lower-priority trainer randomizer may keep changing every ordinary slot,
-- but the delayed Oak rival partner is a story binding and is pinned by the
-- outer post-processor after that randomizer returns.
yhooks:wrap("trainer.party", function(nextParty, class, index, rows)
  local resolved = nextParty(class, index, rows)
  local out = {}
  for slot, row in ipairs(resolved) do
    out[slot] = { species = "RATTATA", level = row.level }
  end
  return out
end, 70, "test-randomizer")
local randomized = yhooks:call("trainer.party",
  function(_, _, rows) return rows end, "OPP_RIVAL2", 6, mangled)
for slot = 1, #randomized - 1 do
  eq(randomized[slot].species, "RATTATA",
    "Yellow randomizer still owns ordinary slot " .. slot)
end
eq(randomized[#randomized].species, "SWAMPERT",
  "binding rival partner survives the trainer randomizer")
eq(randomized[#randomized].level, canonical[#canonical].level,
  "randomizer-safe rival pin retains the authored milestone level")

print(("LEGACY RIVAL PARTNER PASS: %d assertions"):format(checks))
