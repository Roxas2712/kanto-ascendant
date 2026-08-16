local engine = assert(os.getenv("GEN1RECOMP_DIR"), "GEN1RECOMP_DIR is required")
package.path = engine .. "/?.lua;" .. engine .. "/?/init.lua;" .. package.path

local Serializer = require("src.core.SaveSerializer")
local createArchive = assert(loadfile("legacy_archive.lua"))()
local createJourney = assert(loadfile("legacy_journey.lua"))()
local createHall = assert(loadfile("legacy_hall.lua"))()

local assertions = 0
local function ok(value, message)
  assertions = assertions + 1
  if not value then error("FAIL: " .. message, 2) end
end
local function eq(actual, expected, message)
  ok(actual == expected, message .. " (got " .. tostring(actual)
    .. ", expected " .. tostring(expected) .. ")")
end

local function memfs()
  local files = {}
  return {
    files = files,
    getInfo = function(path)
      return files[path] ~= nil and { type = "file" } or nil
    end,
    read = function(path) return files[path] end,
    write = function(path, bytes) files[path] = bytes return true end,
    remove = function(path) files[path] = nil return true end,
    createDirectory = function() return true end,
  }
end

local registries = {
  pokemon = { PIKACHU = { name = "PIKACHU" } },
  moves = { TACKLE = { name = "TACKLE" } },
  items = {
    POTION = { name = "POTION" },
    B1 = { name = "B1" }, B2 = { name = "B2" },
    B3 = { name = "B3" }, B4 = { name = "B4" },
  },
}

local sequence = 0
local function archiveFor(tag)
  sequence = sequence + 1
  return createArchive({
    fs = memfs(), serializer = Serializer, edition = "red",
    modId = "kanto_ascendant", directory = "test/pacts/" .. tag .. sequence,
    pokemonRegistry = registries.pokemon,
    moveRegistry = registries.moves,
    itemRegistry = registries.items,
    isBadge = function(id) return id == "B1" or id == "B2"
      or id == "B3" or id == "B4" end,
  })
end

local function champion(id)
  return {
    version = "red", player = { id = id, name = "RED", rival = "BLUE" },
    flags = { EVENT_BEAT_CHAMPION_RIVAL = true }, hallOfFame = { {} },
    party = { { species = "PIKACHU", level = 50, moves = { "TACKLE" } } },
    boxes = { {} }, inventory = { POTION = 1 }, pcItems = {}, money = 100,
    modData = { kanto_ascendant = {} },
  }
end

local function freshRun(pact, policy, id)
  local archive = archiveFor(pact .. policy)
  local source = champion(id)
  local current, stored = assert(archive.beginJourney(source, {
    pact = pact, bankPolicy = policy, playerAvatar = "RED",
    runRules = archive.safeRunRulesSnapshot(source),
  }))
  local fresh = {
    version = "red", player = { id = id + 1000 }, flags = {}, party = {},
    boxes = { {} }, inventory = {}, pcItems = {}, modData = {},
  }
  assert(archive.seedNewSave(fresh))
  assert(archive.markRunStarted(fresh))
  return archive, fresh, current, stored
end

local pactCases = {}
for _, pact in ipairs({ "journey", "trainer", "legacy", "ascendant" }) do
  for _, policy in ipairs({ "open", "badges4", "league", "sealed" }) do
    pactCases[#pactCases + 1] = { pact, policy, pact, policy }
  end
end
eq(#pactCases, 16, "the product contract contains the complete 4x4 matrix")
for index, row in ipairs(pactCases) do
  local archive, fresh, current, stored = freshRun(row[1], row[2], 100 + index)
  eq(current.pact, row[3], row[1] .. " persists in archive.current")
  eq(current.bankPolicy, row[4], row[1] .. " persists its separate Bank rule")
  eq(stored.hallOfLegacy[1].pact, row[3], row[1] .. " enters Hall of Legacy")
  eq(stored.hallOfLegacy[1].bankPolicy, row[4],
    row[1] .. " Hall entry retains its Bank rule")
  local live = fresh.modData.kanto_ascendant.legacy_journey
  eq(live.pact, row[3], row[1] .. " seeds into the fresh save")
  eq(live.bankPolicy, row[4], row[1] .. " policy seeds into the fresh save")
  local roundTrip = assert(Serializer.decode(Serializer.encode(fresh)))
  eq(roundTrip.modData.kanto_ascendant.legacy_journey.pact, row[3],
    row[1] .. " survives save/reload")
  eq(roundTrip.modData.kanto_ascendant.legacy_journey.bankPolicy, row[4],
    row[1] .. " Bank rule survives save/reload")
end

local openArchive, openSave = freshRun("trainer", "open", 201)
local allowed, why = openArchive.bankAccess(openSave)
eq(allowed, false, "OPEN still waits for Oak's durable partner")
eq(why, "partner", "the partner prerequisite is explicit")
openSave.modData.kanto_ascendant.legacy_journey.partnerChosen = true
allowed, why = openArchive.bankAccess(openSave)
eq(allowed, true, "OPEN unlocks immediately after the partner")
eq(why, "open", "OPEN reports its satisfied rule")

local badgeArchive, badgeSave = freshRun("trainer", "badges4", 202)
local badgeRun = badgeSave.modData.kanto_ascendant.legacy_journey
badgeRun.partnerChosen = true
allowed, why = badgeArchive.bankAccess(badgeSave)
eq(allowed, false, "four-badge policy is closed at zero current badges")
eq(why, "badges4", "four-badge lock reports the missing threshold")
badgeSave.inventory = { B1 = 1, B2 = 1, B3 = 1, B4 = 1 }
allowed = badgeArchive.bankAccess(badgeSave)
eq(allowed, true, "four current-run badges unlock the Bank")

-- The external current record wins over edited live-save pact/policy fields.
badgeRun.pact, badgeRun.bankPolicy = "ascendant", "open"
badgeSave.inventory = {}
local policy, pact
allowed, why, policy, pact = badgeArchive.bankAccess(badgeSave)
eq(allowed, false, "editing the live save cannot weaken its Bank rule")
eq(why, "badges4", "the immutable external threshold remains in force")
eq(policy, "badges4", "Bank access reads policy from archive.current")
eq(pact, "trainer", "Bank access reads pact from archive.current")
assert(badgeArchive.syncProfile(badgeSave))
eq(badgeRun.pact, "trainer", "profile sync repairs a modified live pact")
eq(badgeRun.bankPolicy, "badges4", "profile sync repairs a modified Bank rule")

local leagueArchive, leagueSave = freshRun("legacy", "league", 203)
leagueSave.modData.kanto_ascendant.legacy_journey.partnerChosen = true
allowed, why = leagueArchive.bankAccess(leagueSave)
eq(allowed, false, "league policy ignores an earlier archived Hall")
eq(why, "league_required", "league policy names the current-run requirement")
leagueSave.flags.EVENT_BEAT_CHAMPION_RIVAL = true
leagueSave.hallOfFame = { {} }
allowed = leagueArchive.bankAccess(leagueSave)
eq(allowed, true, "the current save's Hall of Fame unlocks league policy")

local sealedArchive, sealedSave = freshRun("ascendant", "sealed", 204)
sealedSave.modData.kanto_ascendant.legacy_journey.partnerChosen = true
sealedSave.flags.EVENT_BEAT_CHAMPION_RIVAL = true
sealedSave.hallOfFame = { {} }
allowed, why = sealedArchive.bankAccess(sealedSave)
eq(allowed, false, "SEALED remains closed even after the current League")
eq(why, "sealed", "SEALED reports its permanent run lock")

local oldArchive = archiveFor("migration")
local old = oldArchive.normalize({
  version = 6, cycle = 7, bank = {}, locker = { items = {}, money = 0 },
  hallOfLegacy = {}, current = {
    cycle = 7, runId = "OLD:7", status = "active",
    pact = "unknown-old-value", bankUnlocked = true,
  },
})
assert(oldArchive.write(old))
local oldSave = { inventory = {}, modData = { kanto_ascendant = {
  legacy_journey = {
    cycle = 7, runId = "OLD:7", pact = "unknown-old-value",
    bankUnlocked = true,
  },
} } }
allowed, why, policy, pact = oldArchive.bankAccess(oldSave)
eq(allowed, true, "old active bankUnlocked=true remains compatibility-open")
eq(why, "compat", "old unconditional access is explicitly classified")
eq(pact, "journey", "unknown old pact migrates to Journey")
eq(policy, "open", "unknown old Bank rule migrates to OPEN")

local language = "en"
local hooks = {}
local access = false
local uiArchive = {
  bindData = function() return true end,
  copy = function(value)
    local out = {}
    for key, child in pairs(value or {}) do out[key] = child end
    return out
  end,
  current = function() return {} end,
  bankAccess = function()
    return access, access and "open" or "partner", "open", "trainer"
  end,
  profile = function() return { completedPaths = {} } end,
  isEligible = function() return false end,
  seedNewSave = function() return false end,
  reconcileLeases = function() return true end,
  reconcileCheckout = function() return true end,
  syncProfile = function() return true end,
  hevoDoorQuestReady = function() return false end,
}
local uiMod = {
  id = "kanto_ascendant", path = ".",
  exports = { runRules = { open = function() return true end } },
  log = { error = function() end },
  hooks = { wrap = function(_, name, fn) hooks[name] = fn end },
  events = { on = function() end },
  ui = { ListMenu = { new = function(_, title, rows, opts)
    return { title = title, items = rows, opts = opts }
  end } },
}
local journey = createJourney(uiMod, {
  archive = uiArchive,
  i18n = { text = function(en, de) return language == "de" and de or en end },
})
local rows = journey.pactRows()
eq(#rows, 4, "the live Oak menu exposes four pact values")
eq(table.concat({ rows[1].value, rows[2].value, rows[3].value, rows[4].value }, ","),
  "journey,trainer,legacy,ascendant", "the four pact ids are stable")
eq(journey.bankPolicyRows("ascendant")[1].value, "sealed",
  "Ascendant preselects its SEALED recommendation without removing choices")
eq(#journey.bankPolicyRows("journey"), 4,
  "Journey can choose every separate Bank rule")
ok(journey.pactRows()[1].detail:find("separately", 1, true) ~= nil,
  "Journey's live detail no longer promises a forced OPEN rule")
eq(#journey.bankPolicyRows("trainer"), 4,
  "Trainer can choose every separate Bank rule")
eq(#journey.bankPolicyRows("legacy"), 4,
  "Legacy can choose every separate Bank rule")
eq(journey.OAK_HOST_MAP, "OAKS_LAB", "Oak hosts the choice in his real Lab")
eq(journey.OAK_HOST_OBJECT, "OAKSLAB_OAK1",
  "the sequence identifies the existing visible Oak object")
language = "de"
eq(journey.pactRows()[1].label, "REISE", "Journey has a German pact label")
eq(journey.pactRows()[3].label, "VERMÄCHTNIS",
  "Legacy has a German pact label")
eq(journey.bankPolicyRows("trainer")[2].label, "AB 4 ORDEN",
  "the four-badge rule has a German label")
eq(journey.bankPolicyRows("ascendant")[1].label, "VERSIEGELT",
  "SEALED has a German label")
language = "en"

local pcSave = { modData = { kanto_ascendant = { legacy_journey = {
  runId = "UI:1", pact = "trainer", bankPolicy = "open",
  bankPolicyVersion = 1,
} } } }
ok(hooks["ui.pc.items"] == nil,
  "ordinary Player PCs receive no Legacy or KASC rows")
local function labHub()
  local states, stack = {}, {}
  function stack:push(state) states[#states + 1] = state end
  function stack:pop() return table.remove(states) end
  function stack:top() return states[#states] end
  local menu = assert(journey.openLabTerminal({ save = pcSave, stack = stack }))
  return menu
end
local pcItems = labHub().items
eq(pcItems[3].label, "BANK [LOCKED]",
  "Oak's KASC terminal shows a visible locked Bank row before the partner")
access = true
pcItems = labHub().items
eq(pcItems[3].label, "LEGACY BANK",
  "the same direct Lab-terminal row becomes the real Bank after unlock")

local hallMod = {
  id = "kanto_ascendant",
  save = { get = function() return nil end, set = function() end },
  hooks = { wrap = function() end }, events = { on = function() end },
  ui = { insertBefore = function(rows) return rows end },
}
local hallJourney = {
  isActive = function() return true end,
  state = function() return { runId = "CARD:1", pact = "legacy" } end,
  currentPact = function() return "legacy" end,
}
local hall = createHall(hallMod, {
  i18n = { text = function(en) return en end }, legacyJourney = hallJourney,
})
eq(hall.pactCardText({}), "PACT:LEGACY",
  "Trainer Card reads the authoritative current pact compactly")
local hallDe = createHall(hallMod, {
  i18n = { text = function(_, de) return de end }, legacyJourney = hallJourney,
})
eq(hallDe.pactCardText({}), "PAKT:VERM.",
  "Trainer Card pact line is compact and bilingual")
hallJourney.isActive = function() return false end
eq(hall.pactCardText({}), nil,
  "ordinary runs receive no invented pact line on their Trainer Card")

print(("LEGACY PACT MATRIX PASS: %d assertions"):format(assertions))
