local engine = assert(os.getenv("GEN1RECOMP_DIR"), "GEN1RECOMP_DIR is required")
package.path = engine .. "/?.lua;" .. engine .. "/?/init.lua;" .. package.path

local assertions = 0
local function ok(value, message)
  assertions = assertions + 1
  if not value then error("FAIL: " .. message, 2) end
end
local function eq(actual, expected, message)
  ok(actual == expected, message .. " (got " .. tostring(actual)
    .. ", expected " .. tostring(expected) .. ")")
end

local RealTextBox = require("src.render.TextBox")
local RealOakSpeech = require("src.ui.OakSpeech")
local function twoLinePageContract(text, label)
  local worst, badPage = 0, nil
  for index, page in ipairs(RealTextBox.paginate(text)) do
    if #page > worst then worst, badPage = #page, index end
  end
  ok(worst <= 2, ("%s has at most two rendered lines per A-page "
    .. "(page %s has %d)"):format(label, tostring(badPage), worst))
end
local function textBoxText(box)
  if type(box and box.text) == "string" then return box.text end
  local pages = {}
  for _, page in ipairs(box and box.pages or {}) do
    pages[#pages + 1] = table.concat(page, "\n")
  end
  return table.concat(pages, "\f")
end
local function flatText(value)
  return tostring(value or ""):gsub("[\n\f]+", " "):gsub("%s+", " ")
end

local hook, events, mapScripts = {}, {}, {}
local oakCalls = {}
local profileCompleted = {}
local profileTitles = {}
local archiveCalls = {
  seed = 0, begin = 0, mark = 0, reconcile = 0, johtoSync = 0,
}
local archive = {
  itemPolicyId = function(value)
    return value == "empty" and "empty" or "safe"
  end,
  copy = function(value)
    local out = {}
    for key, child in pairs(value) do out[key] = child end
    return out
  end,
  seedNewSave = function(save)
    archiveCalls.seed = archiveCalls.seed + 1
    save.seededByLegacy = true
    save.modData = save.modData or {}
    save.modData.kanto_ascendant = save.modData.kanto_ascendant or {}
    save.modData.kanto_ascendant.legacy_journey = {
      version = 7, cycle = 2, runId = "run2", pact = "journey",
      bankPolicy = "open", bankPolicyVersion = 1,
      itemPolicy = "safe", itemPolicyVersion = 1,
      pendingRunRules = archiveCalls.meta and archiveCalls.meta.runRules,
      runRulesLocked = false,
      wanderersEnabled = true,
    }
    save.modData.kanto_ascendant.ascendant = {
      selectedTitle = profileTitles.selectedTitle,
    }
    save.modData.kanto_ascendant.legacy_hall = {
      version = 1, selectedTitle = profileTitles.selectedTitle,
    }
    save.modData.kanto_ascendant.legacy_lineage_handoff = {
      version = 1, runId = "run2",
    }
    return true
  end,
  hasHandoff = function(save)
    local bucket = save and save.modData
      and save.modData.kanto_ascendant
    return type(bucket and bucket.legacy_lineage_handoff) == "table"
  end,
  reconcileLeases = function()
    archiveCalls.reconcile = archiveCalls.reconcile + 1
    return true
  end,
  reconcileCheckout = function() return true end,
  syncProfile = function() return true end,
  markRunStarted = function()
    archiveCalls.mark = archiveCalls.mark + 1
    return true
  end,
  isEligible = function(save)
    return save and (save.champion == true
      or type(save.hallOfFame) == "table" and #save.hallOfFame > 0
      or type(save.flags) == "table"
        and save.flags.EVENT_BEAT_CHAMPION_RIVAL == true)
  end,
  summary = function(_, meta)
    return { nextCycle = 2, pokemon = 4,
      items = meta and meta.itemPolicy == "empty" and 1 or 8,
      money = 9000 }
  end,
  beginJourney = function(_, meta)
    archiveCalls.begin = archiveCalls.begin + 1
    archiveCalls.meta = meta
    return { cycle = 2, runId = "run2" }
  end,
  availableMons = function() return {} end,
  locker = function() return { items = {}, money = 0 } end,
  profile = function()
    return { completedPaths = profileCompleted, titles = profileTitles }
  end,
  setAvatar = function() return true end,
  advancePath = function() return true end,
  completeFinale = function() return true end,
  syncJohtoMastersPersistent = function(save)
    archiveCalls.johtoSync = archiveCalls.johtoSync + 1
    return save and save.johtoMarker == true
  end,
}

local mod = {
  id = "kanto_ascendant",
  path = ".",
  exports = {},
  log = { error = function() end, info = function() end },
  hooks = { wrap = function(_, name, fn) hook[name] = fn end },
  events = { on = function(_, name, fn) events[name] = fn end },
  content = { map_scripts = { register = function(_, mapId, script)
    mapScripts[mapId] = script
  end } },
  ui = {
    KantoListMenu = { new = function(_, title, rows, opts)
      local menu = { title = title, items = rows, opts = opts, index = 1 }
      function menu:removeCurrent() table.remove(self.items, self.index) end
      return menu
    end },
    ListMenu = { new = function(_, title, rows, opts)
      local menu = { title = title, items = rows, opts = opts, index = 1 }
      function menu:removeCurrent() table.remove(self.items, self.index) end
      return menu
    end },
  },
}

local makeJourney = assert(loadfile("legacy_journey.lua"))()
local journey = makeJourney(mod, {
  archive = archive,
  i18n = { text = function(en) return en end },
  onOakCall = function(_, text, done)
    oakCalls[#oakCalls + 1] = { text = text, done = done }
    return true
  end,
})

local chapterSave = {
  player = { name = "LEAF", rival = "BLUE" },
  modData = { kanto_ascendant = {
    extended_characters = { player_character = "GREEN" },
    legacy_journey = {
      runId = "chapter-run", introPhase = "identity", labLocked = true,
    },
  } },
}
local chapter = journey.legacyPrologueText(chapterSave)
local chapterFlat = chapter:gsub("[\n\f]+", " "):gsub("%s+", " ")
ok(chapterFlat:find("GREEN / LEAF", 1, true)
    and chapterFlat:find("SHE HURRIES", 1, true)
    and chapterFlat:find("BLUE GOT THERE FIRST", 1, true),
  "Legacy chapter card uses the selected hero, player and rival names")
twoLinePageContract(chapter, "English Legacy chapter card")
ok(RealOakSpeech.letterboxWhite ~= false,
  "the official OakSpeech host never disables its white prologue field")
for _, fixture in ipairs({
  { character = "RED", player = "ASH", rival = "GARY", subject = "HE" },
  { character = "BLUE", player = "KAI", rival = "RED", subject = "HE" },
  { character = "GREEN", player = "LEAF", rival = "BLUE", subject = "SHE" },
}) do
  local save = {
    player = { name = fixture.player, rival = fixture.rival },
    modData = { kanto_ascendant = {
      extended_characters = { player_character = fixture.character },
      legacy_journey = {
        runId = "chapter-" .. fixture.character,
        introPhase = "identity", labLocked = true,
      },
    } },
  }
  local text = journey.legacyPrologueText(save)
  local flat = text:gsub("[\n\f]+", " "):gsub("%s+", " ")
  ok(flat:find(fixture.character .. " / " .. fixture.player, 1, true)
      and flat:find(fixture.subject .. " HURRIES", 1, true)
      and flat:find(fixture.rival .. " GOT THERE FIRST", 1, true),
    fixture.character .. " receives its own named Legacy prologue")
  twoLinePageContract(text, fixture.character .. " Legacy chapter card")
end
local chapterSteps = hook["intro.oak_speech.build"](
  function(value) return value end,
  { { id = "name" }, { id = "shrink" } },
  { game = { save = chapterSave } })
eq(chapterSteps[2].id, "legacy_fresh_chapter_card",
  "Legacy chapter card is inserted immediately before Oak's Lab reveal")
local spoken, spokenOpts, chapterDone = nil, nil, 0
local speech = {
  game = { save = chapterSave }, pic = "oak.png", picFlip = true,
  picTrueColor = true,
  sayText = function(self, text, done, opts)
    spoken, spokenOpts = text, opts
    eq(self.pic, nil, "chapter card hides Oak's portrait")
    done()
  end,
}
chapterSteps[2].run(speech, function() chapterDone = chapterDone + 1 end)
eq(spoken, chapter, "chapter card presents the exact authored prologue")
eq(spokenOpts, nil,
  "the prologue uses OakSpeech's ordinary A-gated text path, never auto text")
eq(chapterDone, 1, "chapter card finishes exactly once")
eq(speech.pic, "oak.png", "Oak portrait is restored after the chapter card")
local engineSteps = hook["intro.oak_speech.build"](
  function() return RealOakSpeech.defaultSteps({}) end, nil,
  { game = { save = chapterSave } })
local engineIndex = {}
for index, step in ipairs(engineSteps) do engineIndex[step.id] = index end
ok(engineIndex.name_player < engineIndex.name_rival
    and engineIndex.name_rival < engineIndex.legacy_fresh_chapter_card
    and engineIndex.legacy_fresh_chapter_card < engineIndex.shrink,
  "the official identity names exist before the prologue and Lab reveal")
local ordinarySteps = hook["intro.oak_speech.build"](
  function(value) return value end, { { id = "shrink" } },
  { game = { save = { modData = {} } } })
eq(#ordinarySteps, 1, "ordinary New Game never receives a Legacy chapter card")

profileTitles.selectedTitle = "RIFT CHAMPION"
for _, character in ipairs({ "RED", "BLUE", "GREEN" }) do
  local titleSave = {
    flags = { EVENT_BATTLED_RIVAL_IN_OAKS_LAB = true },
    modData = { kanto_ascendant = {
      extended_characters = { player_character = character },
      ascendant = {}, legacy_hall = { version = 1 },
      legacy_journey = {
        partnerChosen = true, archivedTitlePending = "RIFT CHAMPION",
      },
    } },
  }
  ok(journey.restoreArchivedTitleAfterLabRival(titleSave),
    character .. " restores the archived title after the first Lab rival")
  eq(titleSave.modData.kanto_ascendant.ascendant.selectedTitle,
    "RIFT CHAMPION", character .. " restores Ascendant title ownership")
  eq(titleSave.modData.kanto_ascendant.legacy_hall.selectedTitle,
    "RIFT CHAMPION", character .. " restores Legacy Hall title ownership")
  eq(titleSave.modData.kanto_ascendant.legacy_journey.archivedTitlePending, nil,
    character .. " consumes the one-shot pending title")
  eq(journey.restoreArchivedTitleAfterLabRival(titleSave), false,
    character .. " cannot receive the same title twice")
end
local staleLocalTitle = {
  flags = { EVENT_BATTLED_RIVAL_IN_OAKS_LAB = true },
  modData = { kanto_ascendant = {
    ascendant = { selectedTitle = "LOCAL-ONLY" },
    legacy_hall = { version = 1, selectedTitle = "LOCAL-ONLY" },
    legacy_journey = {
      partnerChosen = true, archivedTitlePending = "LOCAL-ONLY",
    },
  } },
}
eq(journey.restoreArchivedTitleAfterLabRival(staleLocalTitle), false,
  "a stale save-local title cannot impersonate the durable archive title")
eq(staleLocalTitle.modData.kanto_ascendant.legacy_journey.archivedTitlePending,
  "LOCAL-ONLY", "a rejected local title leaves the receipt retryable")
local futureHall = {
  version = 2, selectedTitle = "FUTURE-OWNED", opaque = { marker = 17 },
}
local futureTitleSave = {
  flags = { EVENT_BATTLED_RIVAL_IN_OAKS_LAB = true },
  modData = { kanto_ascendant = {
    ascendant = {}, legacy_hall = futureHall,
    legacy_journey = {
      partnerChosen = true, archivedTitlePending = "RIFT CHAMPION",
    },
  } },
}
ok(journey.restoreArchivedTitleAfterLabRival(futureTitleSave),
  "known Ascendant state can restore while a future Gallery schema is opaque")
eq(futureTitleSave.modData.kanto_ascendant.ascendant.selectedTitle,
  "RIFT CHAMPION", "the known title cache still receives the archive title")
eq(futureHall.selectedTitle, "FUTURE-OWNED",
  "a future Gallery title field remains byte-for-byte owned by that schema")
eq(futureHall.opaque.marker, 17,
  "future Gallery extension data is never rewritten by title restoration")
local failedTitleSave = {
  flags = { EVENT_BATTLED_RIVAL_IN_OAKS_LAB = true },
  modData = { kanto_ascendant = {
    legacy_journey = {
      partnerChosen = true, archivedTitlePending = "RIFT CHAMPION",
    },
  } },
}
local failedTitleGame = {
  save = failedTitleSave,
  writeSave = function() return false end,
}
eq(journey.onLabRivalResolved(failedTitleGame), false,
  "a failed save write cannot consume the automatic title receipt")
eq(failedTitleSave.modData.kanto_ascendant.legacy_journey.archivedTitlePending,
  "RIFT CHAMPION", "failed persistence restores the one-shot pending title")
eq(failedTitleSave.modData.kanto_ascendant.ascendant, nil,
  "failed persistence removes a transaction-created Ascendant cache")
eq(failedTitleSave.modData.kanto_ascendant.legacy_hall, nil,
  "failed persistence removes a transaction-created Gallery cache")
profileTitles.selectedTitle = nil

local function hevoSave(champion, character, sealed, doorVisited)
  character = character or "RED"
  local bucket = {
    extended_characters = { player_character = character },
    hevo_run = { dungeonLegacy = { seals = {}, reentered = {} } },
    hidden_evolution_story_campaign = { doorVisits = {} },
  }
  bucket.hevo_run.dungeonLegacy.seals[character] = sealed and true or nil
  bucket.hidden_evolution_story_campaign.doorVisits[character] =
    doorVisited and true or nil
  return {
    champion = champion == true, flags = {},
    player = { name = character, id = 25 },
    modData = { kanto_ascendant = bucket },
  }
end

ok(journey.syncJohtoMastersPersistent({ johtoMarker = true }),
  "Johto Masters persistence uses the Journey archive boundary")
eq(archiveCalls.johtoSync, 1,
  "Johto Masters archive synchronization is forwarded exactly once")

local seeded = hook["save.new_game"](function(save) return save end, {})
ok(seeded.seededByLegacy, "save.new_game seeds pending legacy metadata")
eq(archiveCalls.seed, 1, "New Game is seeded exactly once")

local interrupted = {
  player = { map = "REDS_HOUSE_2F", x = 3, y = 6, facing = "down" },
  flags = { EVENT_GOT_STARTER = true }, objectToggles = {},
  modData = { kanto_ascendant = { legacy_journey = {
    runId = "resume-identity", introPhase = "identity",
  } } },
}
ok(journey.resumeFreshLab(nil, interrupted),
  "a reloaded identity phase is recovered without a live renderer")
eq(interrupted.player.map, "OAKS_LAB",
  "identity reload fails closed into Oak's Lab")
eq(interrupted.player.x, 5, "identity reload restores the safe Lab x cell")
eq(interrupted.player.y, 5, "identity reload restores the safe Lab y cell")
eq(interrupted.flags.EVENT_GOT_STARTER, nil,
  "identity reload cannot inherit a false completed-starter flag")
ok(interrupted.flags.EVENT_FOLLOWED_OAK_INTO_LAB
    and interrupted.flags.EVENT_OAK_ASKED_TO_CHOOSE_MON,
  "identity reload suppresses outside Oak while retaining the choice gate")
ok(interrupted.objectToggles.OAKS_LAB.OAKSLAB_OAK1 == true,
  "identity reload keeps the real Oak host visible")

interrupted.modData.kanto_ascendant.legacy_journey.introPhase = "partner"
interrupted.player.map = "PALLET_TOWN"
ok(journey.resumeFreshLab(nil, interrupted),
  "a reloaded partner phase is also recoverable")
eq(interrupted.player.map, "OAKS_LAB",
  "partner reload cannot strand the player outside the locked Lab")

local hallOnly = hevoSave(true, "RED", false, false)
ok(hook["ui.pc.items"] == nil,
  "Journey never injects KASC rows into an ordinary Player PC")
local beforeHint = journey.storyGateHint({ champion = false })
ok(beforeHint:find("LEGACY IS LOCKED", 1, true) ~= nil
  and beforeHint:find("Nothing resets", 1, true) ~= nil,
  "pre-Hall explanation names the Hall gate and has no reset side effect")
twoLinePageContract(beforeHint, "English pre-Hall terminal hint")

local afterHint = journey.storyGateHint(hallOnly)
ok(afterHint:find("FISSURE PATH", 1, true) ~= nil
  and afterHint:find("MISSING", 1, true) ~= nil
  and afterHint:find("Postgame alone", 1, true) ~= nil,
  "post-Hall explanation directs the player to the matching fissure")
twoLinePageContract(afterHint, "English post-Hall terminal hint")

local sealOnly = hevoSave(true, "RED", true, false)
ok(not journey.reconcileHevoSealGate(sealOnly, true),
  "finalize/seal alone cannot migrate the Journey gate")
local directNotify, directWhy = journey.notifyHevoSeal({ save=sealOnly }, "RED")
ok(not directNotify and directWhy == "door",
  "direct Journey notification cannot forge the shared-door authority")
local sealOnlyHint = journey.storyGateHint(sealOnly)
ok(sealOnlyHint:find("final", 1, true) ~= nil
    and sealOnlyHint:find("black door", 1, true) ~= nil,
  "seal-only save is directed back to its shared black door")
twoLinePageContract(sealOnlyHint, "English final-door terminal hint")

local readySave = hevoSave(true, "RED", true, true)
ok(journey.reconcileHevoSealGate(readySave, false),
  "matching HOF, current seal and shared-door visit arm the gate")
local readyHint = journey.storyGateHint(readySave)
ok(readyHint:find("PACT, BANK, ITEMS", 1, true) ~= nil
  and readyHint:find("final review", 1, true) ~= nil
  and readyHint:find("ASC RUN", 1, true) ~= nil,
  "qualified explanation distinguishes the confirmed Legacy procedure")
twoLinePageContract(readyHint, "English ready terminal hint")

local runRuleOpens, legacyRuleDrafts, legacyRuleMigrations = {}, {}, {}
local legacyRuleSnapshot = {
  version = 1, preset = "ascendant", seed = 650777,
  randomizer = {
    enabled = true, wild = true, trainers = true, starters = true,
    gifts = true, static = true, items = true, legendary = false,
    balanced = true, consistent = true,
  },
  nuzlocke = {
    mode = "standard", dupes = true, blackout = "end", shinyOdds = 4096,
  },
}
mod.exports.runRules = { open = function(game)
  runRuleOpens[#runRuleOpens + 1] = game
  return true
end, openLegacyDraft = function(game, draft, done)
  legacyRuleDrafts[#legacyRuleDrafts + 1] = { game = game, draft = draft }
  done(legacyRuleSnapshot)
  return {}
end, seedLegacy = function(save, snapshot, pool)
  legacyRuleMigrations[#legacyRuleMigrations + 1] = {
    save = save, snapshot = snapshot, pool = pool,
  }
  local bucket = save.modData.kanto_ascendant
  bucket.run_rules = {
    locked = true, lockReason = "legacy_start", poolDexMax = pool,
    randomizer = { enabled = false }, nuzlocke = { mode = "off" },
  }
  return bucket.run_rules
end }

local migratedActive = {
  version = "red", player = { id = 77, name = "BLITZ" },
  modData = { kanto_ascendant = { legacy_journey = {
    version = 7, runId = "red:77:4", cycle = 4,
    archiveStatus = "active", runRulesLegacyDefault = true,
    pendingRunRules = nil,
  }, beyond_kanto = { version = 1, active = true } } },
}
ok(journey.reconcileLegacyRunRules(migratedActive),
  "active marker-authenticated v6 Journey locks deterministic OFF on load")
eq(#legacyRuleMigrations, 1,
  "active v6 migration calls the rules authority exactly once")
eq(legacyRuleMigrations[1].snapshot, nil,
  "only the v6 migration marker authorizes an absent archived snapshot")
eq(legacyRuleMigrations[1].pool, 251,
  "active v6 migration preserves the already-open Johto boundary")
ok(migratedActive.modData.kanto_ascendant.legacy_journey.runRulesLocked,
  "active v6 migration records the one-way lock")
ok(not journey.reconcileLegacyRunRules(migratedActive),
  "active v6 rules migration is idempotent")
local pendingV6 = archive.copy(migratedActive)
pendingV6.modData.kanto_ascendant.legacy_journey.archiveStatus =
  "pending_new_game"
pendingV6.modData.kanto_ascendant.legacy_journey.runRulesLocked = nil
pendingV6.modData.kanto_ascendant.run_rules = nil
ok(not journey.reconcileLegacyRunRules(pendingV6),
  "pending v6 Journey waits for Oak's explicit 151/251 choice")
eq(#legacyRuleMigrations, 1,
  "pending v6 migration cannot lock a pool before Oak's choice")
local Font = require("src.render.Font")
local function kascRowFits(row)
  local rightX = row.right and (151 - Font.width(row.right)) or 151
  return Font.width(row.label) <= math.max(24, rightX - 22)
end

local function physicalLabHub(save, targetX, targetY)
  local opens, states = 0, {}
  local stack = {}
  function stack:push(state) states[#states + 1] = state end
  function stack:pop() return table.remove(states) end
  function stack:top() return states[#states] end
  local gameAtPc = {
    save = save,
    data = {
      items = {
        POTION = { name = "POTION" },
        HM_SURF = { name = "HM03", machine = { kind = "HM", move = "SURF" } },
        BLAZIKENITE = { name = "BLAZIKENITE", tossable = false },
      },
      pokemon = {
        PIKACHU = { name = "PIKACHU", dex = 25,
          types = { "ELECTRIC" } },
        CHIKORITA = { name = "CHIKORITA", dex = 152,
          types = { "GRASS" } },
      },
      moves = { SURF = { name = "SURF" } },
    },
    overworld = { map = { id = "OAKS_LAB" } },
    stack = stack,
    writeSave = function() return true end,
  }
  local ow = { openPC = function() opens = opens + 1 end }
  local handled = mapScripts.OAKS_LAB.onInteract(
    gameAtPc, ow, targetX, targetY or 1)
  return handled, opens, states[#states], gameAtPc, states
end

for _, targetX in ipairs({ 0, 1 }) do
  local handled, opens, hub = physicalLabHub(readySave, targetX)
  ok(handled == true and opens == 0,
    "both visible halves of Oak's 0.1.95 Lab terminal bypass Player PC at x="
      .. targetX)
  eq(hub.title, "KASC TERMINAL",
    "both physical Lab-terminal halves open the direct KASC hub")
  eq(hub.items[1].value, "legacy_journey",
    "Legacy Journey is the first direct terminal action")
  eq(hub.items[2].value, "asc_run",
    "ASC Run is the second direct terminal action")
  ok(kascRowFits(hub.items[1]) and kascRowFits(hub.items[2]),
    "direct terminal labels and status columns fit without an ellipsis")
  eq(#hub.items, 2,
    "a completed non-Legacy save sees exactly the two direct setup systems")
end
for _, target in ipairs({ { 2, 1 }, { 3, 1 }, { 0, 0 }, { 1, 2 } }) do
  local handled, opens, hub = physicalLabHub(
    readySave, target[1], target[2])
  ok(handled == false and opens == 0,
    ("Lab PC binding does not steal neighbouring target (%d,%d)")
      :format(target[1], target[2]))
  ok(hub == nil,
    "a neighbouring Lab target cannot open the KASC hub")
end

local callCases = {
  RED = { trial = "GROUDON", partner = "TORCHIC" },
  BLUE = { trial = "KYOGRE", partner = "MUDKIP" },
  GREEN = { trial = "RAYQUAZA", partner = "TREECKO" },
}
local productionBegin = journey.begin
local journeyBegins = {}
journey.begin = function(game)
  journeyBegins[#journeyBegins + 1] = game
  return true
end
for _, character in ipairs({ "RED", "BLUE", "GREEN" }) do
  local save = hevoSave(true, character, true, true)
  ok(journey.reconcileHevoSealGate(save, false),
    character .. " matching seal and door arm its own Journey")
  local ready, owner = journey.canBegin(save)
  ok(ready and owner == character,
    character .. " Journey readiness retains the exact hero authority")
  for _, foreign in ipairs({ "RED", "BLUE", "GREEN" }) do
    if foreign ~= character then
      ok(not journey.currentHevoSeal(save, foreign),
        character .. " cannot consume " .. foreign .. "'s seal")
    end
  end
  for _, targetX in ipairs({ 0, 1 }) do
    local handled, opens, hub, gameAtPc = physicalLabHub(save, targetX)
    ok(handled and opens == 0 and hub.items[1].value == "legacy_journey"
        and hub.items[2].value == "asc_run",
      character .. " reaches both direct KASC actions at terminal x="
        .. targetX)
    if targetX == 0 then
      local before = #journeyBegins
      hub.opts.onChoose(hub.items[1])
      ok(#journeyBegins == before + 1
          and journeyBegins[#journeyBegins] == gameAtPc,
        character .. " direct Journey row invokes its own ready save")
    else
      local before = #runRuleOpens
      hub.opts.onChoose(hub.items[2])
      ok(#runRuleOpens == before + 1
          and runRuleOpens[#runRuleOpens] == gameAtPc,
        character .. " direct ASC Run row invokes the public rules seam")
    end
  end
  local before = #oakCalls
  local called, why = journey.notifyHevoSeal({ save = save,
    writeSave = function() return true end }, character)
  ok(called and why == "called" and #oakCalls == before + 1,
    character .. " requests exactly one character-owned Oak call")
  local text = oakCalls[#oakCalls].text
  ok(text:find(callCases[character].trial, 1, true)
      and text:find(callCases[character].partner, 1, true)
      and text:find("upper-left", 1, true)
      and text:find("final YES", 1, true),
    character .. " Oak call explains trial, next left-ball partner, PC and confirmations")
  twoLinePageContract(text, character .. " English Oak call")
  oakCalls[#oakCalls].done()
end
journey.begin = productionBegin
-- The migration/idempotence case below owns a fresh observation ledger.
oakCalls = {}

-- Optional exact-save regression. The release gate supplies a private clone
-- of the active BLITZ slot8 file; loadfile returns an in-memory table and this
-- test never calls a filesystem save writer.
local blitzFixture = os.getenv("BLITZ_SAVE_FIXTURE")
if blitzFixture and blitzFixture ~= "" then
  local blitz = assert(loadfile(blitzFixture))()
  eq(blitz.player and blitz.player.name, "BLITZ",
    "exact Journey fixture belongs to BLITZ")
  eq(blitz.player and blitz.player.map, "OAKS_LAB",
    "exact BLITZ fixture is the reported post-call Lab save")
  eq(blitz.meta and blitz.meta.engine, "0.1.95",
    "exact BLITZ fixture retains its engine stamp")
  local ready, owner = journey.canBegin(blitz)
  ok(ready and owner == "RED",
    "unmodified BLITZ slot8 clone already satisfies the RED Journey gate")
  local blitzBegins = 0
  journey.begin = function(game)
    ok(game.save == blitz,
      "BLITZ direct Journey row retains the exact in-memory fixture")
    blitzBegins = blitzBegins + 1
    return true
  end
  for _, targetX in ipairs({ 0, 1 }) do
    local handled, opens, hub, gameAtPc = physicalLabHub(blitz, targetX)
    ok(handled and opens == 0
        and hub.items[1].value == "legacy_journey"
        and hub.items[2].value == "asc_run",
      "BLITZ clone reaches both direct actions through terminal x=" .. targetX)
    if targetX == 0 then
      hub.opts.onChoose(hub.items[1])
      eq(blitzBegins, 1,
        "BLITZ exact clone can select the direct Legacy Journey action")
    else
      local before = #runRuleOpens
      hub.opts.onChoose(hub.items[2])
      ok(#runRuleOpens == before + 1
          and runRuleOpens[#runRuleOpens] == gameAtPc,
        "BLITZ exact clone can select the direct ASC Run action")
    end
  end
  journey.begin = productionBegin
  ok(not journey.currentHevoSeal(blitz, "BLUE")
      and not journey.currentHevoSeal(blitz, "GREEN"),
    "BLITZ RED completion cannot consume BLUE/GREEN seals")
end

local preHallDoor = hevoSave(false, "RED", true, true)
local preHallReady, preHallWhy = journey.reconcileHevoSealGate(
  preHallDoor, true)
ok(not preHallReady and preHallWhy == "hall"
    and not journey.canBegin(preHallDoor),
  "matching seal and door visit still require Hall of Fame")

profileCompleted.red = true
local priorCycle = hevoSave(true, "RED", false, true)
local priorBucket = priorCycle.modData.kanto_ascendant
priorBucket.hevo_persistent = { meta = { RED = true } }
priorBucket.legacy_journey = {
  runId = "active-cycle-2", cycle = 2, avatar = "RED",
  pathComplete = false,
}
ok(not journey.currentHevoSeal(priorCycle),
  "a prior global RED completion cannot unlock a new active RED cycle")

local activeCompleted = hevoSave(true, "RED", false, true)
activeCompleted.modData.kanto_ascendant.legacy_journey = {
  runId = "active-cycle-3", cycle = 3, avatar = "RED",
  pathComplete = true, bankUnlocked = true,
}
ok(journey.reconcileHevoSealGate(activeCompleted, true)
    and journey.canBegin(activeCompleted),
  "already-active Legacy save keeps its current pathComplete authority")

local originalMigration = hevoSave(true, "RED", false, true)
ok(journey.reconcileHevoSealGate(originalMigration, true)
    and journey.canBegin(originalMigration),
  "pre-package archive without persistent.meta plus matching door migrates")
profileCompleted.red = nil

local activeSave = {
  champion = false,
  modData = { kanto_ascendant = {
    legacy_journey = { bankUnlocked = true, wanderersEnabled = true },
  } },
}
local activeHandled, activePCOpens, activeHub = physicalLabHub(activeSave, 0)
ok(activeHandled and activePCOpens == 0,
  "active Legacy save reaches its bank through the direct Lab terminal")
eq(activeHub.items[3].value, "legacy_bank",
  "fresh Journey exposes its bank after the two top-level KASC actions")
ok(hook["ui.pc.items"] == nil,
  "active Legacy bank is not duplicated in ordinary Player PCs")
local _, _, styledHub, styledGame, styledStates = physicalLabHub(activeSave, 1)
styledHub.opts.onChoose(styledHub.items[3])
local styledBank = styledStates[#styledStates]
eq(styledBank.opts.ascendantStyle, "firered-storage",
  "Legacy Pokémon Bank uses the shared KASC storage presentation")
local normalLocker = archive.locker
archive.locker = function() return { items = { POTION = 2 }, money = 0 } end
styledBank.opts.onChoose(styledBank.items[3])
local styledLocker = styledStates[#styledStates]
eq(styledLocker.opts.ascendantStyle, "firered-storage",
  "Legacy locker hub uses the shared KASC storage presentation")
styledLocker.opts.onChoose(styledLocker.items[1])
local styledItems = styledStates[#styledStates]
eq(styledItems.opts.ascendantStyle, "firered-legacy-storage",
  "Legacy item withdrawals use the dedicated modern KASC archive presentation")
ok(type(styledItems.opts.ascendantStorageDescription) == "function",
  "Legacy item withdrawals expose the KASC archive detail panel")
ok(type(styledItems.opts.onSelectKey) == "function",
  "Legacy item rows expose non-mutating SELECT help")
local beforeItemHelp = #styledStates
styledItems.opts.onSelectKey(styledItems.items[1])
eq(#styledStates, beforeItemHelp + 1,
  "SELECT opens one counted-item help box")
local ordinaryItemHelp = textBoxText(styledStates[#styledStates])
local ordinaryItemFlat = flatText(ordinaryItemHelp)
ok(ordinaryItemFlat:find("Counted Legacy item", 1, true)
    and ordinaryItemFlat:find("Choose 1-2", 1, true)
    and ordinaryItemFlat:find("Bag", 1, true)
    and ordinaryItemFlat:find("Player PC", 1, true)
    and ordinaryItemFlat:find("B cancels unchanged", 1, true),
  "counted-item SELECT help explains quantity, capacity and safe cancel")
twoLinePageContract(ordinaryItemHelp, "English counted-item SELECT help")

-- Counted Locker rows must open the production quantity selector before any
-- checkout is staged.  Cancelling that selector is a pure UI operation.
do
  styledGame.stack:pop()
  styledGame.save.inventory = {}
  styledGame.save.pcItems = {}
  local quantityOpened, quantityOpenErr = pcall(
    styledItems.opts.onChoose, styledItems.items[1])
  local quantityBox = styledStates[#styledStates]
  ok(quantityOpened and quantityBox ~= styledItems
      and quantityBox.qty == 1 and quantityBox.max == 2,
    "counted Legacy row opens an explicit 1..available quantity selector: "
      .. tostring(quantityOpenErr))
  if quantityOpened and quantityBox ~= styledItems
      and type(quantityBox.onDone) == "function" then
    styledGame.stack:pop()
    quantityBox.onDone(nil)
  end
end

-- Even a stale preview/custom archive that exposes an old story receipt must
-- show an exact reason and current-run prerequisite, never a payout action.
archive.locker = function() return { items = { HM_SURF = 1 }, money = 0 } end
journey.openLocker(styledGame)
local lockedLocker = styledStates[#styledStates]
lockedLocker.opts.onChoose(lockedLocker.items[1])
local lockedItems = styledStates[#styledStates]
eq(lockedItems.items[1].right, "LOCK",
  "an old archived HM is visibly locked")
local beforeLockedHelp = #styledStates
lockedItems.opts.onSelectKey(lockedItems.items[1])
eq(#styledStates, beforeLockedHelp + 1,
  "SELECT on a locked HM opens help without checkout")
local lockedItemHelp = textBoxText(styledStates[#styledStates])
local lockedItemFlat = flatText(lockedItemHelp)
ok(lockedItemFlat:find("HMs are story", 1, true)
    and lockedItemFlat:find("SAFARI ZONE", 1, true),
  "locked HM help names both the reason and exact Surf prerequisite")
twoLinePageContract(lockedItemHelp, "English locked-HM SELECT help")

local normalAvailable = archive.availableMons
archive.availableMons = function() return {
  {
    id = "LOCKED:CHIKORITA",
    mon = { species = "CHIKORITA", level = 12, moves = {} },
    withdrawBlocked = true,
    withdrawReason = "BEYOND KANTO is sealed in this save.",
  },
} end
journey.openBank(styledGame)
local helpBank = styledStates[#styledStates]
helpBank.opts.onChoose(helpBank.items[1])
local lockedMons = styledStates[#styledStates]
eq(lockedMons.opts.ascendantStyle, "firered-legacy-storage",
  "Legacy Pokémon rows use the same dedicated archive presentation")
ok(type(lockedMons.opts.onSelectKey) == "function",
  "Legacy Pokémon rows expose SELECT help")
local beforeMonHelp = #styledStates
lockedMons.opts.onSelectKey(lockedMons.items[1])
eq(#styledStates, beforeMonHelp + 1,
  "SELECT on a sealed Pokémon opens help without leasing it")
local lockedMonHelp = textBoxText(styledStates[#styledStates])
local lockedMonFlat = flatText(lockedMonHelp)
ok(lockedMonFlat:find("choose YES for JOHTO", 1, true)
    and lockedMonFlat:find("ELM'S AIDE", 1, true)
    and lockedMonFlat:find("no limit", 1, true),
  "sealed Pokémon help names both activation paths and unlimited safe storage")
twoLinePageContract(lockedMonHelp, "English sealed-Pokémon SELECT help")
archive.availableMons = normalAvailable
archive.locker = normalLocker
ok(journey.wanderersEnabled(activeSave),
  "fresh journey activates wandering challengers")

local normalSave = { modData = { kanto_ascendant = {
  extended_characters = { player_character = "green" },
} } }
eq(journey.activeCharacter(normalSave), "GREEN",
  "the public character hook resolves normal Red/Blue/Green runs")

-- BLITZ-style pre-6.5 saves have no extended-character record because Red
-- was the only player. The live seal and final-door checks must use the same
-- exact-absence migration as Aster and Package A; a present future identity
-- remains authoritative invalid data.
local legacyRedHevo = hevoSave(true, "RED", true, true)
legacyRedHevo.modData.kanto_ascendant.extended_characters = nil
eq(journey.activeCharacter(legacyRedHevo), "RED",
  "exact identity-record absence migrates to legacy RED")
ok(journey.currentHevoSeal(legacyRedHevo, "RED"),
  "legacy RED durable seal survives the identity migration")
ok(journey.currentHevoDoorVisit(legacyRedHevo, "RED"),
  "legacy RED final-door visit survives the identity migration")
ok(journey.reconcileHevoSealGate(legacyRedHevo, true),
  "legacy RED seal and door can complete the live handoff")
local futureHevo = hevoSave(true, "RED", true, true)
futureHevo.modData.kanto_ascendant.extended_characters = {
  player_character = "FUTURE",
}
eq(journey.activeCharacter(futureHevo), nil,
  "present future identity fails closed instead of becoming RED")
ok(not journey.currentHevoSeal(futureHevo, "RED"),
  "future identity cannot consume Red's durable seal")
ok(not journey.currentHevoDoorVisit(futureHevo, "RED"),
  "future identity cannot consume Red's final-door visit")

local reconcileBeforeLoad = archiveCalls.reconcile
events["save.loaded"]({ save = activeSave })
events["save.writing"]({ save = activeSave })
eq(archiveCalls.reconcile, reconcileBeforeLoad + 1,
  "loading reconciles interrupted bank leases exactly once")
eq(archiveCalls.mark, 1, "first save marks the direct hand-off active")

local migrated = hevoSave(true, "BLUE", true, true)
local migrationGame = { save = migrated, writes = 0 }
function migrationGame:writeSave() self.writes = self.writes + 1 return true end
events["save.loaded"]({ save = migrated, game = migrationGame })
ok(migrated.flags[journey.HEVO_READY_FLAG] == true,
  "load migration backfills readiness from matching HOF/seal/door evidence")
eq(#oakCalls, 0, "save load itself does not present over provisional UI")
events["map.entered"]({ game = migrationGame,
  mapId = "KA_HEVO_SHARED_SEALED_ANTECHAMBER" })
eq(#oakCalls, 0,
  "migration inside HEVO waits for the authored black-door sequence")
events["map.entered"]({ game = migrationGame, mapId = "PALLET_TOWN" })
eq(#oakCalls, 1, "leaving HEVO delivers one real Oak-call request")
local migratedCall = oakCalls[#oakCalls]
ok(migratedCall.text:find("KYOGRE", 1, true) ~= nil
    and migratedCall.text:find("MUDKIP", 1, true) ~= nil
    and migratedCall.text:find("upper-left", 1, true) ~= nil
    and migratedCall.text:find("final YES", 1, true) ~= nil,
  "Oak call explains BLUE's trial, next partner, exact PC and confirmation boundary")
twoLinePageContract(migratedCall.text, "migrated BLUE Oak call")
migratedCall.done()
ok(migrated.flags[journey.HEVO_OAK_CALLED_FLAG] == true
    and migrationGame.writes == 2,
  "closing the call durably records its idempotent delivery")
events["save.loaded"]({ save = migrated, game = migrationGame })
events["map.entered"]({ game = migrationGame, mapId = "PALLET_TOWN" })
eq(#oakCalls, 1, "Save/Reload cannot duplicate the completed Oak call")

local emitted, screen, adopted, optionsApplied = {}, nil, nil, nil
package.loaded["src.core.SaveData"] = {
  newGame = function()
    local save = {
      player = { map = "REDS_HOUSE_2F", x = 3, y = 6, facing = "down" },
      options = { textSpeed = 3 }, modData = {},
    }
    return hook["save.new_game"](function(value) return value end, save)
  end,
}
package.loaded["src.mods.Runtime"] = {
  emit = function(name, payload) emitted[#emitted + 1] = { name, payload } end,
}
local overworld = { id = "OVERWORLD" }
package.loaded["src.world.OverworldController"] = overworld
package.loaded["src.ui.Screens"] = {
  push = function(_, id) screen = id end,
}

local stack = { values = { { old = true }, { pc = true } } }
function stack:top()
  local row = self.values[#self.values]
  return row and (row.value ~= nil and row.value or row) or nil
end
function stack:pop() return table.remove(self.values) end
function stack:push(value, ...)
  self.values[#self.values + 1] = { value = value, args = { ... } }
end
local game = {
  stack = stack,
  data = {
    field = { boot = { screens = { newGame = "OakSpeech" } } },
    trainers = {
      OPP_PROF_OAK = { pic = "oak-existing.png", trueColor = true },
    },
  },
  bootConfig = function() return { version = "red" } end,
  adoptSave = function(_, save) adopted = save end,
  applyOptions = function(_, value) optionsApplied = value end,
}
profileTitles.selectedTitle = "RIFT CHAMPION"
local fresh = journey.startFreshGame(game)
ok(fresh.seededByLegacy, "direct transition uses the hooked New Game save")
eq(adopted, fresh, "fresh save becomes the loader's live save")
eq(optionsApplied, fresh.options, "fresh options are applied")
eq(screen, "OakSpeech", "direct transition opens Oak's intro")
eq(fresh.player.map, "OAKS_LAB",
  "the fresh Legacy save lands directly in Oak's Lab")
eq(fresh.player.x, 5, "the locked Lab landing uses the authored safe x cell")
eq(fresh.player.y, 5, "the locked Lab landing uses the authored safe y cell")
eq(fresh.player.facing, "up", "the player starts facing Oak")
ok(fresh.flags.EVENT_FOLLOWED_OAK_INTO_LAB
    and fresh.flags.EVENT_OAK_ASKED_TO_CHOOSE_MON,
  "the fresh Lab suppresses the outside Oak escort while opening partner choice")
eq(fresh.flags.EVENT_GOT_STARTER, nil,
  "the canonical starter flag remains unset before durable partner resolution")
ok(fresh.objectToggles.OAKS_LAB.OAKSLAB_OAK1 == true
    and fresh.objectToggles.OAKS_LAB.OAKSLAB_OAK2 == false,
  "the existing Oak host is visible without spawning substitute art")
eq(#stack.values, 1, "old PC/overworld stack is fully replaced")
eq(stack.values[1].value, overworld, "fresh overworld sits below Oak's intro")
eq(stack.values[1].args[1], "OAKS_LAB",
  "the actual Overworld push targets Oak's Lab rather than the bedroom")
eq(emitted[1][1], "save.created", "fresh mod state receives save.created")
ok(screen ~= "TitleState", "transition never visits the title screen")
eq(fresh.modData.kanto_ascendant.legacy_journey.archivedTitlePending,
  "RIFT CHAMPION",
  "fresh Legacy state stages the archive-authoritative title for the rival")
eq(fresh.modData.kanto_ascendant.ascendant.selectedTitle, nil,
  "the archived title stays hidden until the first Lab rival resolves")
eq(fresh.modData.kanto_ascendant.legacy_hall.selectedTitle, nil,
  "the known Gallery cache also waits for the first Lab rival receipt")
profileTitles.selectedTitle = nil

local normalSummary = archive.summary
archive.summary = function()
  return {
    readOnly = true, nextCycle = nil, pokemon = 0, items = 0, money = 0,
  }, "future schema 8"
end
archive.readOnly, archive.futureVersion = true, 8
package.loaded["src.render.TextBox"] = {
  paginate = RealTextBox.paginate,
  new = function(_, text, done, opts)
    return { text = text, done = done, opts = opts }
  end,
}
package.loaded["src.ui.PicBox"] = {
  new = function(_, path, _, opts)
    local value = {
      kind = "oak-portrait", path = path, opts = opts,
      image = { kind = "low-resolution-oak" },
    }
    function value:draw()
      self.baseDrawCount = (self.baseDrawCount or 0) + 1
    end
    return value
  end,
}

-- The Journey UI owns the durable bridge from the archive's narrowly proven
-- cycle-zero bootstrap adoption to the current save.  It must persist that
-- receipt before showing any pact/confirmation screen, and roll the volatile
-- receipt back if the normal save write fails.
local adoptArchive = {}
for key, value in pairs(archive) do adoptArchive[key] = value end
adoptArchive.summary = normalSummary
adoptArchive.readOnly, adoptArchive.futureVersion = nil, nil
local adoptionCalls = 0
adoptArchive.lineageStatus = function(save)
  local bucket = save and save.modData
    and save.modData.kanto_ascendant
  return type(bucket and bucket.legacy_storage_binding) == "table",
    "This save contains Legacy history but no verified scoped archive binding"
end
adoptArchive.adoptScopedBootstrap = function(save, context)
  adoptionCalls = adoptionCalls + 1
  ok(context and context.playthroughId == save.meta.playthroughId,
    "bootstrap adoption receives the exact engine-issued playthrough context")
  save.modData.kanto_ascendant.legacy_storage_binding = {
    version = 1, scope = "playthrough",
    playthroughId = context.playthroughId,
    archiveDigest = "0123456789abcdef",
  }
  return true, "scoped-bootstrap"
end
local adoptMod = {
  id = "kanto_ascendant", path = ".", exports = {},
  log = { error = function() end, info = function() end },
  hooks = { wrap = function() end }, events = { on = function() end },
  content = { map_scripts = { register = function() end } }, ui = mod.ui,
  storage = { context = function(_, adoptGame)
    return { playthroughId = adoptGame.save.meta.playthroughId,
      gameVersion = "red", engineVersion = "0.1.95" }
  end },
}
local adoptJourney = makeJourney(adoptMod, {
  archive = adoptArchive,
  i18n = { text = function(en) return en end },
})
local function adoptionGame(writeResult)
  local values = {}
  local adoptStack = {}
  function adoptStack:push(value) values[#values + 1] = value end
  function adoptStack:pop() return table.remove(values) end
  function adoptStack:top() return values[#values] end
  local save = hevoSave(true, "RED", true, true)
  save.meta = { playthroughId = "blitz_scope" }
  local writes = 0
  local adoptGame = {
    save = save, stack = adoptStack,
    data = { trainers = { OPP_PROF_OAK = { pic = "oak-existing.png" } } },
  }
  function adoptGame:writeSave()
    writes = writes + 1
    return writeResult
  end
  return adoptGame, values, function() return writes end
end

local adoptedGame, adoptedStates, adoptedWrites = adoptionGame(true)
ok(adoptJourney.reconcileHevoSealGate(adoptedGame.save, false),
  "bootstrap adoption fixture passes the real story gate")
ok(adoptJourney.begin(adoptedGame) == true,
  "verified scoped bootstrap proceeds to Oak's pact UI")
eq(adoptedWrites(), 1,
  "verified bootstrap receipt is saved exactly once before the UI opens")
ok(type(adoptedGame.save.modData.kanto_ascendant
      .legacy_storage_binding) == "table"
    and #adoptedStates >= 1,
  "durable bootstrap binding exists before any confirmation is visible")

local failedAdoptGame, failedAdoptStates, failedAdoptWrites = adoptionGame(false)
ok(adoptJourney.reconcileHevoSealGate(failedAdoptGame.save, false),
  "write-failure adoption fixture passes the story gate")
eq(adoptJourney.begin(failedAdoptGame), false,
  "a volatile bootstrap receipt cannot open the pact UI")
eq(failedAdoptWrites(), 1,
  "failed bootstrap persistence attempts exactly one normal save write")
eq(failedAdoptGame.save.modData.kanto_ascendant.legacy_storage_binding, nil,
  "failed persistence restores the in-memory save to its unbound state")
local bindingSaveText = failedAdoptStates[#failedAdoptStates].text
ok(bindingSaveText:find("NOT SAVED", 1, true)
    and not bindingSaveText:find("TOO NEW", 1, true),
  "bootstrap write failure is specific and is never mislabeled as future schema")
twoLinePageContract(bindingSaveText,
  "bootstrap-binding save-failure message")
eq(adoptionCalls, 2,
  "bootstrap proof runs once for each unbound candidate and never loops")

game.save = readySave
local beforeReadOnly = #stack.values
eq(journey.begin(game), false,
  "a future archive blocks the Legacy Journey confirmation UI")
eq(#stack.values, beforeReadOnly + 1,
  "future archive blocking shows one compatibility message")
local futureText = stack.values[#stack.values].value.text
ok(futureText:find("newer KASC", 1, true) ~= nil
    and futureText:find("version", 1, true) ~= nil,
  "only a real future schema is described as a newer KASC archive")
twoLinePageContract(futureText, "future-archive compatibility message")
eq(archiveCalls.begin, 0,
  "read-only UI never starts or partially stages another journey")
archive.summary = normalSummary
archive.readOnly, archive.futureVersion = nil, nil

archive.summary = function()
  return {
    readOnly = false, nextCycle = 2, pokemon = 1, items = 1, money = 0,
    blockers = { "1 Day-Care Plus parent must be collected" },
  }
end
readySave.modData.kanto_ascendant.daycare_plus = {
  parents = { { species = "DITTO" } }, reservedEggs = {},
}
local beforeDaycareBlock = #stack.values
local beginsBeforeDaycareBlock = archiveCalls.begin
eq(journey.begin(game), false,
  "Day-Care holdings block the Legacy confirmation UI")
eq(#stack.values, beforeDaycareBlock + 1,
  "Day-Care blocking shows one actionable message")
local daycareText = stack.values[#stack.values].value.text
ok(daycareText:find("DAY%-CARE") and daycareText:find("DITTO", 1, true)
    and daycareText:find("Choose LEGACY", 1, true)
    and daycareText:find("again", 1, true),
  "the UI names DITTO, Day-Care collection and the exact retry action")
twoLinePageContract(daycareText, "specific Day-Care blocker message")
eq(archiveCalls.begin, beginsBeforeDaycareBlock,
  "the Day-Care UI block never stages an archive transaction")
archive.summary = normalSummary
readySave.modData.kanto_ascendant.daycare_plus = nil

local transitionCount, saveWrites = 0, 0
journey.startFreshGame = function()
  transitionCount = transitionCount + 1
  return {}
end
game.writeSave = function()
  saveWrites = saveWrites + 1
  return true
end
game.save = hevoSave(true, "RED", true, true)
ok(journey.reconcileHevoSealGate(game.save, false),
  "confirmation fixture passes the full current-run gate")
local oldLove = love
local hdLoadPath, hdFilter, hdDraw, hdScissors
local hdImage = {
  getDimensions = function() return 590, 1009 end,
  setFilter = function(_, min, mag) hdFilter = { min, mag } end,
}
love = { graphics = {
  newImage = function(path)
    hdLoadPath = path
    return hdImage
  end,
  setShader = function() end,
  setBlendMode = function() end,
  setColor = function() end,
  setScissor = function(...)
    hdScissors = hdScissors or {}
    hdScissors[#hdScissors + 1] = { ... }
  end,
  draw = function(...) hdDraw = { ... } end,
} }
local oakHdChecked = false
local function openOakHostedJourneySummary(itemChoiceIndex)
  ok(journey.begin(game) ~= false,
    "qualified PC action opens Oak's hosted pact sequence")
  local oakHost = stack:pop().value
  ok(oakHost.text:find("PROF. OAK", 1, true)
      and oakHost.text:find("choose a", 1, true)
      and oakHost.text:find("PACT", 1, true),
    "Oak personally explains and asks for the four-pact choice")
  twoLinePageContract(oakHost.text, "English Oak pact introduction")
  local portrait = stack:top()
  ok(portrait and portrait.kind == "oak-portrait"
      and tostring(portrait.path):find("oak%-existing%.png"),
    "the hosted choice visibly reuses Oak's existing portrait asset")
  ok(portrait.opts and portrait.opts.trueColor == true,
    "Oak's hosted portrait explicitly preserves authored RGB colours")
  ok(portrait.kascTrueColorPortrait == true
      and portrait.kascPortraitClass == "OPP_PROF_OAK",
    "Oak's hosted portrait owns the explicit true-colour repair receipt")
  eq(portrait.sgbPalettes, nil,
    "Oak never becomes the exclusive palette owner and cannot clip the TextBox")
  ok(portrait.kascTrueColorDrawMark == true,
    "Oak's hosted portrait records the additive draw-time true-colour repair")
  local PaletteFX = require("src.render.PaletteFX")
  PaletteFX.clearTrueColor()
  PaletteFX.setPass("ui")
  portrait:draw()
  local zones = PaletteFX.trueColorRects("ui")
  PaletteFX.setPass(nil)
  eq(portrait.baseDrawCount, 1,
    "the true-colour wrapper preserves PicBox's original draw exactly once")
  eq(#zones, 1, "Oak's draw appends one bounded true-colour rectangle")
  ok(portrait.kascLegacyOakHdImage == hdImage
      and portrait.kascLegacyOakFallbackImage.kind == "low-resolution-oak"
      and portrait.image == nil,
    "loaded HD Oak suppresses only PicBox's low-resolution image layer")
  eq(portrait.kascLegacyOakHdSourceWidth, 590,
    "Legacy Oak records the approved master width")
  eq(portrait.kascLegacyOakHdSourceHeight, 1009,
    "Legacy Oak records the approved master height")
  ok(hdLoadPath:find("professor_oak_legacy_host_hd_v1.png", 1, true)
      and hdFilter[1] == "linear" and hdFilter[2] == "linear",
    "Legacy Oak loads and downsamples the dedicated authored HD source")
  if not oakHdChecked then
    local TextBoxMeta = { isTextBox = true }
    local textBox = setmetatable({}, TextBoxMeta)
    local hudStack = { states = { portrait, textBox } }
    function hudStack:top() return self.states[#self.states] end
    local nextHudCalls = 0
    hdDraw, hdScissors = nil, nil
    hook["render.hud"](function()
      nextHudCalls = nextHudCalls + 1
    end, { stack = hudStack }, {
      gameX = 0, gameY = 0, gameWidth = 800, gameHeight = 720,
      scale = 5, dpiX = 1, dpiY = 1,
    })
    eq(nextHudCalls, 1, "HD Oak preserves the existing HUD hook chain")
    ok(hdDraw and hdDraw[1] == hdImage,
      "HD Oak is drawn from the native source after the UI canvas")
    eq(hdScissors[1][1], 260,
      "HD Oak clip starts at PicBox's exact screen-space x")
    eq(hdScissors[1][2], 180,
      "HD Oak clip starts at PicBox's exact screen-space y")
    eq(hdScissors[1][3], 320,
      "HD Oak clip preserves PicBox's 64px inner width")
    eq(hdScissors[1][4], 300,
      "the TextBox remains above the lower four PicBox pixels")
    ok(#hdScissors[2] == 0,
      "HD Oak releases its bounded screen-space clip")
    local proof = portrait.kascLegacyOakHdProof
    ok(proof and proof.screenSpace == true
        and proof.textBoxOcclusion == true
        and proof.sourceWidth == 590 and proof.sourceHeight == 1009,
      "HD Oak publishes source and layering render evidence")
    eq(math.floor(proof.drawHeight + 0.5), 290,
      "HD source occupies the old Oak subject's exact 58px height at 5x")
    ok(math.floor(proof.drawWidth + 0.5) == 170,
      "HD source preserves the old Oak subject's exact 34px width at 5x")

    hdDraw = nil
    hudStack.states[#hudStack.states] = { isOpaque = true }
    hook["render.hud"](function() end, { stack = hudStack }, {
      gameX = 0, gameY = 0, gameWidth = 800, gameHeight = 720,
    })
    eq(hdDraw, nil,
      "HD Oak cannot leak over a non-TextBox state above PicBox")
    oakHdChecked = true
    love = oldLove
  end
  ok(zones[1].colors == false and zones[1].x == 48 and zones[1].y == 32
      and zones[1].w == 72 and zones[1].h == 72,
    "Oak's 9x9 PicBox frame bypasses remapping without owning the screen zones")
  PaletteFX.clearTrueColor()
  oakHost.done()
  local pactMenu = stack:pop().value
  eq(#pactMenu.items, 4, "Oak's list contains exactly four pacts")
  eq(pactMenu.items[1].value, "journey", "Journey is the first pact")
  eq(pactMenu.items[2].value, "trainer", "Trainer is the second pact")
  eq(pactMenu.items[3].value, "legacy", "Legacy is the third pact")
  eq(pactMenu.items[4].value, "ascendant", "Ascendant is the fourth pact")
  ok(type(pactMenu.opts.onSelectKey) == "function"
      and pactMenu.opts.footer:find("SEL:HELP", 1, true),
    "pact menu advertises and wires SELECT help")
  pactMenu.opts.onSelectKey(pactMenu.items[1])
  local pactHelp = stack:pop().value
  ok(pactHelp.text:upper():find("LIGHTLY", 1, true) ~= nil
      and pactHelp.text:upper():find("IMPROVED", 1, true) ~= nil,
    "pact SELECT help explains the highlighted pact")
  eq(pactMenu.items[1].value, "journey",
    "pact SELECT help never mutates the selection")
  pactMenu.opts.onChoose(pactMenu.items[1])
  local bankIntro = stack:pop().value
  ok(bankIntro.text:find("BANK", 1, true) ~= nil
      and bankIntro.text:find("RULE", 1, true) ~= nil,
    "Oak explains the independent Bank rule after Journey")
  twoLinePageContract(bankIntro.text, "English Oak bank-rule introduction")
  bankIntro.done()
  local bankMenu = stack:pop().value
  eq(#bankMenu.items, 4, "Journey exposes all four separate Bank rules")
  eq(bankMenu.items[1].value, "open", "OPEN remains Journey's first recommendation")
  ok(type(bankMenu.opts.onSelectKey) == "function"
      and bankMenu.opts.footer:find("SEL:HELP", 1, true),
    "Bank rule menu advertises and wires SELECT help")
  bankMenu.opts.onSelectKey(bankMenu.items[4])
  local bankHelp = stack:pop().value
  ok(bankHelp.text:upper():find("CANNOT", 1, true) ~= nil
      and bankHelp.text:upper():find("OPENED", 1, true) ~= nil,
    "Bank SELECT help explains the highlighted access gate")
  eq(bankMenu.items[1].value, "open",
    "Bank SELECT help never changes the pending choice")
  bankMenu.opts.onChoose(bankMenu.items[1])
  local itemIntro = stack:pop().value
  ok(itemIntro.text:find("SAFE", 1, true) ~= nil
      and itemIntro.text:find("EMPTY", 1, true) ~= nil,
    "Oak explains SAFE/EMPTY before the item choice")
  twoLinePageContract(itemIntro.text, "English Oak item-archive introduction")
  itemIntro.done()
  local itemMenu = stack:pop().value
  eq(#itemMenu.items, 2, "Legacy exposes SAFE and EMPTY item policies")
  eq(itemMenu.items[1].value, "safe",
    "SAFE is the first non-destructive item recommendation")
  eq(itemMenu.items[2].value, "empty",
    "EMPTY remains an explicit alternate item choice")
  ok(type(itemMenu.opts.onSelectKey) == "function"
      and itemMenu.opts.footer:find("SEL:HELP", 1, true),
    "item archive menu advertises and wires SELECT help")
  itemMenu.opts.onSelectKey(itemMenu.items[1])
  local itemHelp = stack:pop().value
  ok(itemHelp.text:upper():find("TRANSFERABLE", 1, true) ~= nil
      and itemHelp.text:upper():find("ITEMS", 1, true) ~= nil
      and itemHelp.text:upper():find("BADGES", 1, true) ~= nil
      and itemHelp.text:upper():find("FIELD KIT", 1, true) ~= nil,
    "SAFE SELECT help names what transfers and every protected category")
  eq(itemMenu.items[1].value, "safe",
    "item SELECT help is read-only and keeps SAFE selected")
  itemMenu.opts.onSelectKey(itemMenu.items[2])
  local emptyHelp = stack:pop().value
  local emptyText = emptyHelp.text:upper()
  ok(emptyText:find("THREE", 1, true) ~= nil
      and emptyText:find("PATH", 1, true) ~= nil
      and emptyText:find("MEGA", 1, true) ~= nil
      and emptyText:find("STONES", 1, true) ~= nil,
    "EMPTY help discloses the three retained path-stone souvenirs")
  itemMenu.opts.onChoose(itemMenu.items[itemChoiceIndex or 1])
  eq(#legacyRuleDrafts > 0, true,
    "item choice opens the detached Legacy rules draft")
  return stack.values[#stack.values].value
end

local beforeConfirmation = #stack.values
local firstBox = openOakHostedJourneySummary()
eq(#stack.values, beforeConfirmation + 1,
  "Oak's completed pact choice leaves exactly one summary page")
ok(not (firstBox.opts and firstBox.opts.defaultNo == true),
  "informational review is not a second irreversible confirmation")
ok(firstBox.text:find("ARCHIVE KEEPS", 1, true) ~= nil
    and firstBox.text:find("POKéMON", 1, true) ~= nil
    and firstBox.text:find("ITEMS / MONEY", 1, true) ~= nil
    and firstBox.text:find("NEW CYCLE RESETS", 1, true) ~= nil
    and firstBox.text:find("STORY + MAPS", 1, true) ~= nil
    and firstBox.text:find("Nothing ends yet", 1, true) ~= nil,
  "informational page names archived holdings and every reset consequence")
twoLinePageContract(firstBox.text, "English informational review")
firstBox.done()
local secondBox = stack.values[#stack.values].value
ok(secondBox ~= firstBox and secondBox.opts.defaultNo == true,
  "informational review opens the sole default-NO confirmation")
ok(secondBox.text:find("PACT / BANK", 1, true) ~= nil
    and secondBox.text:find("ITEM ARCHIVE", 1, true) ~= nil
    and secondBox.text:find("SAFE", 1, true) ~= nil
    and secondBox.text:find("RANDOMIZER", 1, true) ~= nil
    and secondBox.text:find("PROFILE", 1, true) ~= nil
    and secondBox.text:find("ASCENDANT", 1, true) ~= nil
    and secondBox.text:find("NUZLOCKE", 1, true) ~= nil
    and secondBox.text:find("STANDARD", 1, true) ~= nil
    and secondBox.text:find("650777", 1, true) ~= nil
    and secondBox.text:find("LAB CHOICE 151/251", 1, true) ~= nil
    and secondBox.text:find("THIS RUN", 1, true) ~= nil
    and secondBox.text:find("ENDS + ARCHIVES", 1, true) ~= nil
    and secondBox.text:find("CURRENT SAVE", 1, true) ~= nil
    and secondBox.text:find("WILL BE REPLACED", 1, true) ~= nil
    and secondBox.text:find("CANNOT BE", 1, true) ~= nil
    and secondBox.text:find("CONTINUED AGAIN", 1, true) ~= nil
    and secondBox.text:find("NEW SAVE", 1, true) ~= nil
    and secondBox.text:find("CREATED NOW", 1, true) ~= nil
    and secondBox.text:find("ARE YOU SURE", 1, true) ~= nil,
  "sole final page explicitly warns that the current save is replaced")
twoLinePageContract(secondBox.text, "English final irreversible review")
secondBox.opts.choice(false)
eq(archiveCalls.begin, 0,
  "sole default-NO branch cannot archive or start a run")
eq(saveWrites, 0, "default-NO cancellation writes no save")
eq(transitionCount, 0, "default-NO cancellation performs no transition")

local emptyFirst = openOakHostedJourneySummary(2)
local emptyFirstFlat = emptyFirst.text:gsub("%s+", " ")
ok(emptyFirstFlat:find("OPTIONAL ITEMS", 1, true)
    and emptyFirstFlat:find("NONE", 1, true)
    and emptyFirstFlat:find("EARNED PATH STONES", 1, true)
    and emptyFirstFlat:find("1 RETAINED", 1, true),
  "EMPTY informational review never claims that path souvenirs are discarded")
twoLinePageContract(emptyFirst.text, "English EMPTY informational review")
emptyFirst.done()
local emptyFinal = stack.values[#stack.values].value
local emptyFinalFlat = emptyFinal.text:gsub("%s+", " ")
ok(emptyFinalFlat:find("ITEM ARCHIVE", 1, true)
    and emptyFinalFlat:find("EMPTY", 1, true)
    and emptyFinalFlat:find("OPTIONAL ITEMS", 1, true)
    and emptyFinalFlat:find("NONE", 1, true)
    and emptyFinalFlat:find("EARNED PATH STONES", 1, true)
    and emptyFinalFlat:find("1 RETAINED", 1, true)
    and emptyFinalFlat:find("EMPTY (0 ITEMS)", 1, true) == nil,
  "EMPTY final review reports the exact earned path-stone count")
twoLinePageContract(emptyFinal.text, "English EMPTY final review")
emptyFinal.opts.choice(false)
eq(archiveCalls.begin, 0,
  "EMPTY default-NO review remains nonmutating")

-- Readiness is checked again at the irreversible confirmation boundary.
game.save.modData.kanto_ascendant.legacy_journey_hevo_gate.ready = false
secondBox.opts.choice(true)
eq(archiveCalls.begin, 0,
  "lost readiness at final YES cannot reach archive.beginJourney")
eq(saveWrites, 0,
  "lost readiness at final YES cannot write or reset the current save")

ok(journey.reconcileHevoSealGate(game.save, false),
  "restoring the same durable evidence re-arms the final action")
local confirmedFirst = openOakHostedJourneySummary()
confirmedFirst.done()
local confirmedSecond = stack.values[#stack.values].value
confirmedSecond.opts.choice(true)
eq(archiveCalls.begin, 1,
  "sole explicit YES starts exactly one Legacy archive transaction")
eq(saveWrites, 1,
  "qualified final confirmation saves the current run exactly once first")
eq(transitionCount, 1,
  "qualified final confirmation performs exactly one fresh-cycle handoff")
eq(archiveCalls.meta.pact, "journey",
  "the chosen pact reaches archive.beginJourney transactionally")
eq(archiveCalls.meta.bankPolicy, "open",
  "Journey's independently selected OPEN rule reaches the transaction")
eq(archiveCalls.meta.itemPolicy, "safe",
  "Journey's default SAFE item rule reaches the transaction")
eq(archiveCalls.meta.runRules.seed, 650777,
  "detached confirmed seed reaches the archive transaction")
eq(archiveCalls.meta.runRules.nuzlocke.mode, "standard",
  "independent Nuzlocke mode reaches the archive transaction")

local committedBegins, committedTransitions = archiveCalls.begin, transitionCount
game.writeSave = function()
  saveWrites = saveWrites + 1
  return false
end
local failedFirst = openOakHostedJourneySummary()
failedFirst.done()
local failedSecond = stack.values[#stack.values].value
failedSecond.opts.choice(true)
eq(archiveCalls.begin, committedBegins,
  "a current-save failure cannot stage or mutate the Legacy archive")
eq(transitionCount, committedTransitions,
  "a current-save failure cannot reset or transition into Fresh Save")

-- Unique Mega Stone withdrawal is a three-store transaction: archive pending
-- receipt -> current-save Stone Case -> successful game write -> archive
-- decrement. A failed game write rolls the provisional ledger bit back and
-- leaves the unique receipt available for an exact retry.
local savedArchiveFns = {}
for _, name in ipairs({ "locker", "beginItemCheckout", "completeCheckout",
    "cancelCheckout", "itemClaimStatus", "classifyItem" }) do
  savedArchiveFns[name] = archive[name] or false
end
local savedMega = mod.exports.megaEvolution
local lockerCount, pendingCheckout = 1, nil
local checkoutBegins, checkoutCompletes, checkoutCancels = 0, 0, 0
local megaState = { case = true, ring = true, stones = {} }
local megaController = {
  state = function() return megaState end,
  hasStone = function(id) return megaState.stones[id] == true end,
  importLegacyStone = function(id)
    if not (megaState.case or megaState.ring) then return nil, "no case" end
    local added = megaState.stones[id] ~= true
    if added then megaState.stones[id] = true end
    return { stone = id, added = added }
  end,
  rollbackLegacyStone = function(receipt)
    if receipt and receipt.added then
      megaState.stones[receipt.stone] = nil
      receipt.added = false
    end
    return true
  end,
}
mod.exports.megaEvolution = megaController
archive.classifyItem = function(id)
  return { id = id, category = "mega_stone", transferable = true,
    claimMode = "unique_after_mega_access" }
end
archive.itemClaimStatus = function(_, id)
  if not (megaState.case or megaState.ring) then
    return false, "mega_access_required", archive.classifyItem(id)
  end
  return true, megaState.stones[id] and "already_owned" or "ready",
    archive.classifyItem(id)
end
archive.locker = function()
  return { items = lockerCount > 0 and { BLAZIKENITE = lockerCount } or {},
    money = 0 }
end
archive.beginItemCheckout = function(_, id, count)
  checkoutBegins = checkoutBegins + 1
  pendingCheckout = { id = "MEGA-CHECKOUT-" .. checkoutBegins,
    item = id, count = count }
  return pendingCheckout
end
archive.completeCheckout = function(save, id)
  ok(pendingCheckout and pendingCheckout.id == id,
    "Mega finalization owns the staged archive receipt")
  ok(save.modData.kanto_ascendant.mega_evolution.stones.BLAZIKENITE,
    "archive decrements only after the current save owns the Mega Stone")
  checkoutCompletes = checkoutCompletes + 1
  lockerCount, pendingCheckout = math.max(0, lockerCount - 1), nil
  return true
end
archive.cancelCheckout = function(id)
  ok(pendingCheckout and pendingCheckout.id == id,
    "Mega cancellation owns the staged archive receipt")
  checkoutCancels, pendingCheckout = checkoutCancels + 1, nil
  return true
end

local megaStack = { values = {} }
function megaStack:push(value) self.values[#self.values + 1] = value end
function megaStack:pop() return table.remove(self.values) end
function megaStack:top() return self.values[#self.values] end
local megaSave = {
  inventory = {},
  modData = { kanto_ascendant = {
    legacy_journey = { runId = "MEGA-RUN", bankUnlocked = true },
    mega_evolution = megaState,
  } },
}
local megaWrites, failMegaWrite = 0, false
local megaGame = {
  save = megaSave, stack = megaStack,
  data = { items = { BLAZIKENITE = { name = "BLAZIKENITE" } } },
}
function megaGame:writeSave()
  megaWrites = megaWrites + 1
  return not failMegaWrite
end
local function chooseMegaReceipt()
  ok(journey.openLocker(megaGame) ~= false,
    "active Legacy run opens the transactional Locker")
  local hub = megaStack:top()
  hub.opts.onChoose(hub.items[1])
  local list = megaStack:top()
  list.opts.onChoose(list.items[1])
  return list
end

local successfulMegaList = chooseMegaReceipt()
eq(checkoutBegins, 1, "Mega withdrawal stages exactly one archive receipt")
eq(megaWrites, 1, "Mega withdrawal writes the current save exactly once")
eq(checkoutCompletes, 1,
  "successful current-save write consumes the unique archive receipt")
eq(lockerCount, 0, "successful Mega withdrawal decrements the Locker once")
eq(megaState.stones.BLAZIKENITE, true,
  "successful Mega withdrawal persists one Stone Case entitlement")
eq(megaSave.inventory.BLAZIKENITE, nil,
  "Mega withdrawal never creates a phantom Bag item")
eq(#successfulMegaList.items, 0,
  "consumed unique receipt disappears from the visible Locker")

lockerCount, megaState.stones.BLAZIKENITE = 1, true
chooseMegaReceipt()
eq(checkoutCompletes, 2,
  "already-owned Mega Stone idempotently clears its stale receipt")
eq(megaState.stones.BLAZIKENITE, true,
  "already-owned claim preserves the single boolean Stone Case record")
eq(megaSave.inventory.BLAZIKENITE, nil,
  "already-owned claim still produces no Bag duplicate")

lockerCount, megaState.stones.BLAZIKENITE = 1, nil
failMegaWrite = true
local failedMegaList = chooseMegaReceipt()
eq(checkoutCancels, 1,
  "failed current-save write cancels the staged archive receipt")
eq(checkoutCompletes, 2,
  "failed current-save write never decrements the archive")
eq(lockerCount, 1, "failed Mega withdrawal leaves the receipt retryable")
eq(megaState.stones.BLAZIKENITE, nil,
  "failed Mega withdrawal rolls back its provisional Stone Case bit")
eq(megaSave.inventory.BLAZIKENITE, nil,
  "failed Mega withdrawal leaves no phantom Bag item")
eq(failedMegaList.footer, "SAVE FAILED",
  "failed Mega withdrawal reports the exact recoverable failure")

for name, fn in pairs(savedArchiveFns) do
  archive[name] = fn ~= false and fn or nil
end
mod.exports.megaEvolution = savedMega

local deCalls = {}
local deMod = {
  id = "kanto_ascendant", path = ".", log = mod.log,
  exports = { runRules = {
    open = function() return true end,
    openLegacyDraft = function(_, _, done)
      done(legacyRuleSnapshot)
      return {}
    end,
  } },
  hooks = { wrap = function() end }, events = { on = function() end },
  content = { map_scripts = { register = function() end } }, ui = mod.ui,
}
local deJourney = makeJourney(deMod, {
  archive = archive,
  i18n = { text = function(_, de) return de end },
  onOakCall = function(_, text, done)
    deCalls[#deCalls + 1] = { text = text, done = done }
    return true
  end,
})
local deHelpGame = {
  data = {
    items = {
      HM_SURF = { name = "VM03",
        machine = { kind = "HM", move = "SURFER" } },
      UNREVIEWED_RELIC = { name = "UNGEPRÜFTES RELIKT", tossable = false },
    },
    pokemon = {
      CHIKORITA = { name = "ENDIVIE", dex = 152,
        types = { "PFLANZE" } },
    },
    moves = { SURFER = { name = "SURFER" } },
  },
}
local deItemHelp = deJourney.itemLockedHelp(deHelpGame, "HM_SURF")
local deItemFlat = flatText(deItemHelp)
ok(deItemFlat:find("GRUND", 1, true)
    and deItemFlat:find("SAFARI%-ZONE")
    and deItemFlat:find("Story dieses Laufs", 1, true),
  "German locked-HM help names reason and exact current-run prerequisite")
twoLinePageContract(deItemHelp, "German locked-HM SELECT help")
local deUnknownHelp = deJourney.itemLockedHelp(
  deHelpGame, "UNREVIEWED_RELIC")
local deUnknownFlat = flatText(deUnknownHelp)
ok(deUnknownFlat:find("GRUND", 1, true)
    and deUnknownFlat:find("nicht geprüft", 1, true)
    and deUnknownFlat:find("Quarantäne", 1, true),
  "German unreviewed-item help names quarantine and the update prerequisite")
twoLinePageContract(deUnknownHelp,
  "German unreviewed-item SELECT help")
local deMonHelp = deJourney.monHelpText(deHelpGame, {
  mon = { species = "CHIKORITA", level = 12 },
  withdrawBlocked = true,
  withdrawReason = "JENSEITS VON KANTO ist versiegelt.",
})
local deMonFlat = flatText(deMonHelp)
ok(deMonFlat:find("Wähle JA für JOHTO", 1, true)
    and deMonFlat:find("LINDS Assistent", 1, true)
    and deMonFlat:find("unbegrenzt", 1, true),
  "German sealed-Pokémon help names both unlock paths and safe storage")
twoLinePageContract(deMonHelp, "German sealed-Pokémon SELECT help")
local normalBankAccess = archive.bankAccess
for _, bankCase in ipairs({
  { true, "open" },
  { false, "partner" },
  { false, "badges4" },
  { false, "league_required" },
  { false, "sealed" },
  { false, "unknown" },
}) do
  archive.bankAccess = function()
    return bankCase[1], bankCase[2], "open", "journey"
  end
  twoLinePageContract(journey.bankPolicyHint({}),
    "English Bank hint " .. bankCase[2])
  twoLinePageContract(deJourney.bankPolicyHint({}),
    "German Bank hint " .. bankCase[2])
end
archive.bankAccess = normalBankAccess

local deBlockedSave = hevoSave(true, "RED", true, true)
deBlockedSave.modData.kanto_ascendant.daycare_plus = {
  parents = { { mon = { species = "DITTO" } } }, reservedEggs = {},
}
ok(deJourney.reconcileHevoSealGate(deBlockedSave, false),
  "German DITTO blocker fixture is Journey-ready")
local summaryBeforeGermanBlocker = archive.summary
archive.summary = function()
  return {
    readOnly = false, nextCycle = 2, pokemon = 1, items = 1, money = 0,
    blockers = { "1 Day-Care Plus parent must be collected" },
  }
end
game.save = deBlockedSave
local deBlockedBefore = #stack.values
eq(deJourney.begin(game), false,
  "German DITTO Day-Care holding blocks Legacy before any pact screen")
eq(#stack.values, deBlockedBefore + 1,
  "German DITTO blocker presents exactly one actionable message")
local deDaycareText = stack.values[#stack.values].value.text
ok(deDaycareText:find("DITTO", 1, true)
    and deDaycareText:find("PENSION", 1, true)
    and deDaycareText:find("VERMÄCHTNIS", 1, true)
    and deDaycareText:find("Nichts", 1, true),
  "German blocker names DITTO, collection place, retry action and safe state")
twoLinePageContract(deDaycareText, "German specific DITTO blocker")
archive.summary = summaryBeforeGermanBlocker
local deCases = {
  RED = { trial = "GROUDONS", partner = "FLEMMLI" },
  BLUE = { trial = "KYOGRES", partner = "HYDROPI" },
  GREEN = { trial = "RAYQUAZAS", partner = "GECKARBOR" },
}
for _, character in ipairs({ "RED", "BLUE", "GREEN" }) do
  local save = hevoSave(true, character, true, true)
  ok(deJourney.reconcileHevoSealGate(save, false),
    character .. " also arms the German Journey presentation")
  local called = deJourney.notifyHevoSeal({ save = save,
    writeSave = function() return true end }, character)
  ok(called == true, character .. " opens a German Oak call")
  local text = deCalls[#deCalls].text
  ok(text:find(deCases[character].trial, 1, true)
      and text:find(deCases[character].partner, 1, true)
      and text:find("KASC%-PC")
      and text:find("letzte JA", 1, true),
    character .. " German call is trial-, partner-, PC- and confirmation-correct")
  twoLinePageContract(text, character .. " German Oak call")
  deCalls[#deCalls].done()
end

twoLinePageContract(deJourney.storyGateHint({ champion = false }),
  "German pre-Hall terminal hint")
twoLinePageContract(deJourney.storyGateHint(hevoSave(true, "RED", false, false)),
  "German post-Hall terminal hint")
twoLinePageContract(deJourney.storyGateHint(hevoSave(true, "RED", true, false)),
  "German final-door terminal hint")
local deFlowSave = hevoSave(true, "RED", true, true)
ok(deJourney.reconcileHevoSealGate(deFlowSave, false),
  "German review-flow fixture is Journey-ready")
twoLinePageContract(deJourney.storyGateHint(deFlowSave),
  "German ready terminal hint")
game.save = deFlowSave
ok(deJourney.begin(game) ~= false,
  "German Journey opens its complete pact/bank/review flow")
local deOakIntro = stack:pop().value
twoLinePageContract(deOakIntro.text, "German Oak pact introduction")
deOakIntro.done()
local dePactMenu = stack:pop().value
dePactMenu.opts.onChoose(dePactMenu.items[1])
local deBankIntro = stack:pop().value
twoLinePageContract(deBankIntro.text, "German Oak bank-rule introduction")
deBankIntro.done()
local deBankMenu = stack:pop().value
deBankMenu.opts.onChoose(deBankMenu.items[1])
local deItemIntro = stack:pop().value
twoLinePageContract(deItemIntro.text, "German Oak item-archive introduction")
deItemIntro.done()
local deItemMenu = stack:pop().value
eq(deItemMenu.items[1].value, "safe",
  "German flow also defaults item archive to SAFE")
deItemMenu.opts.onChoose(deItemMenu.items[1])
local deFirstReview = stack.values[#stack.values].value
ok(deFirstReview.text:find("PRÜFUNG", 1, true)
    and deFirstReview.text:find("Noch endet nichts", 1, true)
    and deFirstReview.text:find("VERMÄCHTNIS neu wählen", 1, true) == nil,
  "German informational review is coherent and non-irreversible")
twoLinePageContract(deFirstReview.text,
  "German informational review")
deFirstReview.done()
local deFinalReview = stack.values[#stack.values].value
local deFinalFlat = deFinalReview.text:gsub("[%s\f]+", " ")
ok(deFinalReview.text:find("LETZTE PRÜFUNG", 1, true)
    and deFinalReview.text:find("ITEM%-ARCHIV")
    and deFinalReview.text:find("RANDOMIZER%-PROFIL")
    and deFinalReview.text:find("LABORWAHL 151/251", 1, true)
    and deFinalFlat:find("ALTER SPIELSTAND", 1, true)
    and deFinalFlat:find("WIRD ERSETZT", 1, true)
    and deFinalFlat:find("NICHT MEHR FORTSETZBAR", 1, true)
    and deFinalFlat:find("NEUER SPIELSTAND", 1, true)
    and deFinalFlat:find("WIRD JETZT ERSTELLT", 1, true)
    and deFinalFlat:find("BIST DU SICHER", 1, true)
    and deFinalReview.text:find("VORGABE IST NEIN", 1, true),
  "German final review clearly warns that the old save is replaced")
twoLinePageContract(deFinalReview.text,
  "German final irreversible review")
deFinalReview.opts.choice(false)

local deHubSave = hevoSave(true, "RED", true, true)
ok(deJourney.reconcileHevoSealGate(deHubSave, false),
  "German direct terminal fixture is Journey-ready")
local deStates, deStack = {}, {}
function deStack:push(state) deStates[#deStates + 1] = state end
function deStack:pop() return table.remove(deStates) end
function deStack:top() return deStates[#deStates] end
local deHub = assert(deJourney.openLabTerminal({
  save = deHubSave, stack = deStack,
}))
eq(deHub.items[1].label, "VERMÄCHTNIS",
  "German direct Journey row uses the fit-safe full concept name")
eq(deHub.items[2].label, "ASC-LAUF",
  "German ASC Run row is direct and unambiguous")
ok(kascRowFits(deHub.items[1]) and kascRowFits(deHub.items[2]),
  "German direct terminal rows fit the real KASC label/status budget")

print(("LEGACY JOURNEY PASS: %d assertions"):format(assertions))
