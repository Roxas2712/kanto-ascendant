package.path = (assert(os.getenv("GEN1RECOMP_ROOT")) .. "/?.lua;")
  .. assert(os.getenv("GEN1RECOMP_ROOT")) .. "/?/init.lua;./?.lua;" .. package.path
love = love or require("tests.love_stub")

local checks = 0
local function ok(value, message)
  checks = checks + 1
  if not value then error("FAIL: " .. message, 2) end
end
local function eq(actual, expected, message)
  ok(actual == expected, message .. " (expected " .. tostring(expected)
    .. ", got " .. tostring(actual) .. ")")
end
local function twoLinePages(box, label)
  ok(box and type(box.pages) == "table", label .. " creates text pages")
  for index = 1, #box.pages do
    ok(#box.pages[index] <= 2,
      ("%s page %d stays within two visible lines [%s]"):format(
        label, index, table.concat(box.pages[index], " | ")))
  end
end

local hooks, events = {}, {}
local mod = {
  id = "kanto_ascendant",
  hooks = { wrap = function(_, name, fn) hooks[name] = fn end },
  events = { on = function(_, name, fn)
    events[name] = events[name] or {}
    events[name][#events[name] + 1] = fn
  end },
  ui = {
    ListMenu = { new = function(_, title, rows, opts)
      return { title = title, items = rows, onChoose = opts.onChoose,
        onSelectKey = opts.onSelectKey, footer = opts.footer }
    end },
  },
}
mod.ui.KantoListMenu = mod.ui.ListMenu

local function species(id, dex, bst, evolutions)
  return { id = id, name = id, dex = dex,
    baseStats = { hp = bst, attack = bst, defense = bst, speed = bst, special = bst },
    evolutions = evolutions or {}, level1Moves = {}, learnset = {},
    growthRate = "MEDIUM_FAST", catchRate = 100 }
end
local data = {
  pokemon = {
    BULBASAUR = species("BULBASAUR", 1, 45,
      { { species = "IVYSAUR", method = "LEVEL", level = 16 } }),
    IVYSAUR = species("IVYSAUR", 2, 60),
    CHARMANDER = species("CHARMANDER", 4, 46),
    PIKACHU = species("PIKACHU", 25, 50),
    RATTATA = species("RATTATA", 19, 42),
    MEW = species("MEW", 151, 100),
  },
  items = {
    POTION = { name = "POTION" }, ANTIDOTE = { name = "ANTIDOTE" },
    POKE_BALL = { name = "POKé BALL" }, GREAT_BALL = { name = "GREAT BALL" },
    BICYCLE = { name = "BICYCLE", keyItem = true },
    HM_CUT = { name = "HM01" }, BOULDERBADGE = { name = "BADGE" },
  },
  moves = {},
}

local function fresh(map)
  local game = {
    data = data,
    save = { player = { name = "RED" }, party = {}, boxes = {},
      inventory = {}, pokedex = { seen = {}, owned = {} }, modData = {} },
    overworld = { map = { def = { id = map or "REDS_HOUSE_2F" } } },
    stack = { states = {}, push = function(self, row)
      self.states[#self.states + 1] = row
    end, pop = function(self) return table.remove(self.states) end,
      top = function(self) return self.states[#self.states] end },
    writes = 0,
  }
  function game:writeSave() self.writes = self.writes + 1 return true end
  return game
end

local shiny = {
  isShiny = function(mon) return mon.shiny == true end,
  forceMon = function(mon) mon.shiny = true return true end,
}
local mythicReturning = false
local mythic = {
  classify = function(battle)
    return battle.protected and "test_mythic" or nil
  end,
  isProtectedReturn = function() return mythicReturning end,
}
local boundaryCallback
local boundary
boundary = {
  active = true,
  isActive = function() return boundary.active end,
  onChanged = function(fn) boundaryCallback = fn end,
}
local makeRules = assert(loadfile("run_rules.lua"))()
local rules = makeRules(mod, {
  i18n = { text = function(en) return en end },
  shinySystem = shiny, mythicSafety = mythic, beyondKanto = boundary,
})

do
  local registered = {}
  local featureMod = {
    id = "kanto_ascendant",
    find = function() return nil end,
    options = { get = function() return nil end },
    content = { screens = { register = function(_, id, spec)
      registered[id] = spec
    end } },
    ui = { push = function() end },
    exports = {},
  }
  local features = assert(loadfile("ascendant_features.lua"))()(featureMod)
  local info = features.runRulesInfo({ save = { player = { name = "LEAF" } } })
  ok(info:find("Oak's Lab", 1, true) ~= nil,
    "options info points to Oak's Lab KASC terminal")
  ok(registered.JohtoAscendantFeatures ~= nil,
    "run-rules notice is part of the Ascendant options tree")
  local featureFile = assert(io.open("ascendant_features.lua", "rb"))
  local featureSource = featureFile:read("*a")
  featureFile:close()
  ok(featureSource:find('key = "randomizer"', 1, true) == nil
      and featureSource:find('key = "nuzlocke"', 1, true) == nil,
    "global options contain information only, never challenge controls")
end

local game = fresh()
local PlayerPC = require("src.ui.PlayerPC")
local playerPCNew = PlayerPC.new
local staleBridge = { active = true }
staleBridge.restore = function()
  staleBridge.active = false
  rawset(PlayerPC, "__kantoAscendantRunRulesPlayerPC0186", nil)
  return true
end
rawset(PlayerPC, "__kantoAscendantRunRulesPlayerPC0186", staleBridge)
rules.install(game)
eq(staleBridge.active, false,
  "upgrade retires the old process-stable PlayerPC bridge")
eq(rawget(PlayerPC, "__kantoAscendantRunRulesPlayerPC0186"), nil,
  "retired PlayerPC marker cannot reappear after hot import")
local state = rules.state()
eq(state.randomizer.enabled, false, "safe default leaves randomizer disabled")
eq(state.nuzlocke.mode, "off", "safe default leaves Nuzlocke disabled")
eq(state.locked, false, "fresh bedroom save remains configurable")

eq(hooks["ui.player_pc.items"], nil,
  "ordinary Player PCs no longer receive an ASC RUN hook")
local stockMenu = PlayerPC.new(game, { direct = true })
eq(#stockMenu.items, 4,
  "ordinary Player PC keeps exactly its four stock rows")
eq(PlayerPC.new, playerPCNew,
  "run rules never wrap the engine PlayerPC constructor")

rules.open(game)
local setupMenu = game.stack.states[#game.stack.states]
eq(setupMenu.title, "ASCENDANT RUN",
  "public runRules.open seam opens the KASC terminal rule tree")
eq(type(setupMenu.onSelectKey), "function",
  "main rule tree exposes SELECT help")
eq(setupMenu.footer, "L/R:CHG SEL:HELP",
  "main footer visibly teaches Left/Right and SELECT help")
for _, item in ipairs(setupMenu.items) do
  ok(type(item.help) == "string" and #item.help > 30,
    "every main rule row has an explanatory SELECT receipt")
end
ok(setupMenu.items[2].help:find("#001-251", 1, true) ~= nil,
  "Randomizer SELECT help exposes the effective Beyond-active #001-251 pool")
setupMenu.onSelectKey(setupMenu.items[7])
local startHelp = game.stack.states[#game.stack.states]
ok(startHelp.pages ~= nil,
  "START RUN SELECT help opens a real text receipt")

local oldSeed = state.seed
eq(type(setupMenu.onAdjustKey), "function",
  "main rule tree binds Left/Right to visible settings")
setupMenu.onChoose(setupMenu.items[6])
eq(state.seed, oldSeed,
  "A on a setting opens help and never silently changes the draft")
setupMenu.onAdjustKey(setupMenu.items[6], 1)
ok(state.seed ~= oldSeed, "NEW SEED changes even when selected in the same second")
ok(game.writes > 0, "draft terminal changes are persisted immediately")

-- Legacy setup is a detached draft. It must use the same real Left/Right and
-- SELECT controls without touching or locking the source save.
do
  local legacyGame = fresh("OAKS_LAB")
  local selected
  local sourceWrites = legacyGame.writes
  local draft = assert(rules.openLegacyDraft(legacyGame, nil,
    function(snapshot) selected = snapshot end))
  local menu = legacyGame.stack:top()
  eq(menu.title, "LEGACY RUN RULES",
    "Legacy Journey opens its dedicated rules draft")
  eq(menu.footer, "L/R:CHG SEL:HELP",
    "Legacy rules footer teaches Left/Right and SELECT")
  eq(type(menu.onAdjustKey), "function",
    "Legacy rules expose real directional adjustment")
  for _, item in ipairs(menu.items) do
    ok(type(item.help) == "string" and #item.help > 30,
      "every Legacy rules row has SELECT help")
  end
  local nuzBefore = draft.nuzlocke.mode
  menu.onChoose(menu.items[1])
  eq(draft.preset, "standard",
    "A on Randomizer profile explains instead of cycling")
  legacyGame.stack:pop() -- row help
  menu.onAdjustKey(menu.items[1], 1)
  eq(draft.preset, "gentle",
    "Right advances the Randomizer profile")
  eq(draft.nuzlocke.mode, nuzBefore,
    "Randomizer profile never changes independent Nuzlocke mode")
  menu.onAdjustKey(menu.items[1], -1)
  eq(draft.preset, "standard",
    "Left reverses the Randomizer profile")
  menu.onAdjustKey(menu.items[3], 1)
  eq(draft.nuzlocke.mode, "standard",
    "Right selects the independent Nuzlocke mode")
  menu.onChoose(menu.items[4])
  local randomSubmenu = legacyGame.stack:top()
  eq(type(randomSubmenu.onAdjustKey), "function",
    "Legacy Randomizer subrules use directional settings")
  local wildBefore = draft.randomizer.wild
  randomSubmenu.onChoose(randomSubmenu.items[1])
  eq(draft.randomizer.wild, wildBefore,
    "A on a Randomizer subrule opens help only")
  legacyGame.stack:pop() -- row help
  randomSubmenu.onAdjustKey(randomSubmenu.items[1], 1)
  eq(draft.randomizer.wild, not wildBefore,
    "Left/Right changes a Legacy Randomizer subrule")
  legacyGame.stack:pop() -- submenu
  menu.onChoose(menu.items[7])
  ok(type(selected) == "table", "CONTINUE returns a validated snapshot")
  eq(selected.version, rules.legacySnapshotVersion,
    "Legacy snapshot carries an explicit schema version")
  eq(selected.nuzlocke.mode, "standard",
    "Legacy snapshot preserves independent Nuzlocke choice")
  eq(legacyGame.writes, sourceWrites,
    "Legacy draft performs zero source-save writes")
  eq(legacyGame.save.modData.kanto_ascendant, nil,
    "Legacy draft performs zero source-save mutations")

  for _, hero in ipairs({ "RED", "BLUE", "GREEN" }) do
    for _, dexMax in ipairs({ 151, 251 }) do
      local target = fresh("OAKS_LAB").save
      target.version = hero:lower()
      target.player.name = hero
      target.player.id = dexMax + #hero
      target.modData.kanto_ascendant = { legacy_journey = {
        version = 7, runId = hero .. ":RULES", cycle = 2,
      } }
      local seeded, seedErr, changed = rules.seedLegacy(target,
        selected, dexMax)
      ok(seeded ~= nil and seedErr == nil and changed == true,
        hero .. " seeds its fresh Legacy contract")
      eq(seeded.lockReason, "legacy_start",
        hero .. " receives only the Legacy lock reason")
      eq(seeded.finalRules.poolDexMax, dexMax,
        hero .. " freezes the chosen 151/251 pool")
      eq(seeded.finalRules.nuzlocke.mode, "standard",
        hero .. " freezes the selected Nuzlocke mode")
      local repeated, repeatErr, repeatChanged = rules.seedLegacy(target,
        selected, dexMax)
      eq(repeated.seed, seeded.seed,
        hero .. " retry preserves the archived seed")
      eq(repeatErr, nil, hero .. " retry remains valid")
      eq(repeatChanged, false,
        hero .. " retry is idempotent after the same pool choice")
    end
  end

  local finalTamper = fresh("OAKS_LAB").save
  finalTamper.modData.kanto_ascendant = { legacy_journey = {
    version = 7, runId = "tamper:final", cycle = 1,
  } }
  local originallySeeded = assert(rules.seedLegacy(finalTamper, selected, 151))
  originallySeeded.finalRules.nuzlocke.mode = "off"
  local repaired, repairErr, repairChanged = rules.seedLegacy(
    finalTamper, selected, 151)
  eq(repairErr, nil, "mismatched final snapshot can be canonically reseeded")
  eq(repairChanged, true,
    "mismatched final snapshot never passes the idempotence check")
  eq(repaired.nuzlocke.mode, selected.nuzlocke.mode,
    "canonical reseed restores the confirmed Nuzlocke mode")
  eq(repaired.finalRules.nuzlocke.mode, selected.nuzlocke.mode,
    "canonical reseed restores the immutable final snapshot")

  local oldV6 = fresh("OAKS_LAB").save
  oldV6.player.name, oldV6.player.id = "BLITZ", 77
  oldV6.modData.kanto_ascendant = { legacy_journey = {
    version = 6, runId = "red:77:4", cycle = 4,
    runRulesLegacyDefault = true,
  } }
  local safeOld = assert(rules.seedLegacy(oldV6, nil, 151))
  eq(safeOld.randomizer.enabled, false,
    "old v6 pending journey migrates to Randomizer OFF")
  eq(safeOld.nuzlocke.mode, "off",
    "old v6 pending journey migrates to Nuzlocke OFF")
  local deterministicSeed = safeOld.seed
  oldV6.modData.kanto_ascendant.run_rules = nil
  local safeRetry = assert(rules.seedLegacy(oldV6, nil, 151))
  eq(safeRetry.seed, deterministicSeed,
    "old v6 power-loss retry derives the same lineage seed")

  local function tamper(mutator, label)
    local bad = rules.legacySnapshot(selected)
    mutator(bad)
    local target = fresh("OAKS_LAB").save
    target.modData.kanto_ascendant = { legacy_journey = {
      version = 7, runId = "tamper:" .. label, cycle = 1,
    } }
    local seeded, err = rules.seedLegacy(target, bad, 151)
    eq(seeded, nil, label .. " fails closed")
    ok(type(err) == "string" and #err > 0,
      label .. " reports a validation reason")
    eq(target.modData.kanto_ascendant.run_rules, nil,
      label .. " causes zero fresh-save mutation")
  end
  tamper(function(row) row.seed = 0 end, "invalid seed")
  tamper(function(row) row.randomizer.wild = "yes" end, "invalid boolean")
  tamper(function(row) row.nuzlocke.mode = "soft" end, "invalid mode")
  tamper(function(row) row.randomizer.secret = true end, "unknown field")
end

-- Drive the real engine ListMenu input seam, not just the inspectable test
-- callbacks.  This catches the released defect where Left/Right remained
-- page-jump navigation and only A could cycle a rule.
do
  local RealListMenu = require("src.ui.ListMenu")
  local input = { pressed = {} }
  function input:wasPressed(key)
    local value = self.pressed[key] == true
    self.pressed[key] = nil
    return value
  end
  function input:isDown() return false end
  local directionalGame = fresh("OAKS_LAB")
  directionalGame.input = input
  local directionalMod = {
    id = mod.id,
    hooks = { wrap = function() end },
    events = { on = function() end },
    ui = { ListMenu = RealListMenu },
  }
  directionalMod.ui.KantoListMenu = RealListMenu
  local directionalRules = makeRules(directionalMod, {
    i18n = { text = function(en) return en end },
    shinySystem = shiny, mythicSafety = mythic, beyondKanto = boundary,
  })
  directionalRules.install(directionalGame)
  directionalRules.open(directionalGame)
  local directionalMenu = directionalGame.stack.states[#directionalGame.stack.states]
  directionalMenu.index = 2
  input.pressed.right = true
  directionalMenu:update(0)
  eq(directionalRules.state().randomizer.enabled, true,
    "real Right input changes the highlighted Randomizer value")
  input.pressed.left = true
  directionalMenu:update(0)
  eq(directionalRules.state().randomizer.enabled, false,
    "real Left input changes the highlighted Randomizer value back")
  input.pressed.a = true
  directionalMenu:update(0)
  eq(directionalRules.state().randomizer.enabled, false,
    "real A input on a value opens information instead of changing it")
  ok(#directionalGame.stack.states == 2,
    "real A input opens the setting's explanatory TextBox")
end
rules.applyPreset(state, "ascendant")
state.seed = 123456
state.nuzlocke.mode = "standard"

-- Draft settings are inert until the explicit, default-NO START RUN choice.
game.overworld.map.def.id = "ROUTE_1"
local draftWild = hooks["battle.wild"](function(row) return row end,
  { species = "RATTATA", level = 3 },
  { game = game, source = "wild", opts = {} })
eq(draftWild.species, "RATTATA",
  "draft Randomizer does not affect play before explicit START RUN")
eq(state.locked, false,
  "an encounter cannot silently lock draft rules")
setupMenu.onChoose(setupMenu.items[7])
local declined = game.stack.states[#game.stack.states]
eq(declined.defaultNo, true, "final safety confirmation defaults to NO")
twoLinePages(declined, "English final safety confirmation")
declined.choice(false)
eq(state.locked, false, "NO leaves the per-save draft configurable")
setupMenu.onChoose(setupMenu.items[7])
local confirmed = game.stack.states[#game.stack.states]
confirmed.choice(true)
eq(state.locked, true, "YES writes the one explicit per-save run lock")
eq(state.lockReason, "explicit_start", "lock records only explicit START RUN")
eq(state.finalRules.seed, 123456, "confirmed seed has a durable final snapshot")
eq(state.finalRules.nuzlocke.mode, "standard",
  "confirmed Nuzlocke mode has a durable final snapshot")
eq(state.finalRules.poolDexMax, 251,
  "Beyond-active START RUN snapshots the visible #001-251 pool")

local deMod = {
  id = mod.id,
  hooks = { wrap = function() end },
  events = { on = function() end },
  ui = mod.ui,
}
local deRules = makeRules(deMod, {
  i18n = { text = function(_, de) return de end },
  shinySystem = shiny, mythicSafety = mythic,
})
local deGame = fresh("OAKS_LAB")
deRules.open(deGame)
local deMenu = deGame.stack.states[#deGame.stack.states]
eq(deMenu.footer, "L/R:ÄND SEL:HILFE",
  "German main footer visibly teaches Left/Right and SELECT help")
deMenu.onAdjustKey(deMenu.items[3], 1) -- AUS -> STANDARD
deMenu.onChoose(deMenu.items[7])
local deConfirm = deGame.stack.states[#deGame.stack.states]
eq(deConfirm.defaultNo, true,
  "German final safety confirmation also defaults to NO")
twoLinePages(deConfirm, "German final safety confirmation")

local visible = hooks["encounter.species"](function(row) return row end,
  { species = "RATTATA", level = 3 }, { mapId = "ROUTE_1" })
local wild = hooks["battle.wild"](function(row) return row end,
  visible,
  { game = game, source = "wild", opts = {} })
eq(wild.species, visible.species,
  "visible wild and resulting battle use the same randomized species")
ok(data.pokemon[visible.species] ~= nil,
  "visible-wild phase always resolves to a registered species")
local protectedVisible = hooks["encounter.species"](
  function(row) return row end,
  { species = "RHYDON", level = 70 }, {
    mapId = "KA_HEVO_RED_UPPER", kaProtected = true,
    kaEncounterSource = "hevo_dungeon",
  })
eq(protectedVisible.species, "RHYDON",
  "protected progression habitat bypasses species randomization")
local protectedBattle = hooks["battle.wild"](
  function(row) return row end, protectedVisible,
  { game = game, source = "wild", opts = {} })
eq(protectedBattle.species, "RHYDON",
  "protected classic roll reaches battle without a second randomization")
eq(protectedBattle.level, 70,
  "protected classic roll keeps its authored level at battle startup")
local directWild = hooks["battle.wild"](function(row) return row end,
  { species = "RATTATA", level = 3 },
  { game = game, source = "wild", opts = {} })
ok(data.pokemon[directWild.species] ~= nil,
  "randomized wild encounter always resolves to a registered species")
eq(state.lockReason, "explicit_start",
  "encounters cannot replace the explicit lock reason")
local firstSpecies = directWild.species
local frozenMapping = state.mappings.species.RATTATA
eq(state.finalRules.mappings.species.RATTATA, frozenMapping,
  "generated mapping is added to the immutable final receipt")
state.mappings.species = {}
state = rules.state()
eq(state.mappings.species.RATTATA, frozenMapping,
  "reload restores a cleared mapping from the immutable receipt")
state.poolDexMax = 151 -- simulate a stale/tampered projection before callback
boundary.active = false
boundaryCallback(false, game)
eq(state.poolDexMax, 251,
  "confirmed 151/251 pool boundary self-heals before option changes rebuild")
eq(rules.poolMaxDex(game), 251,
  "runtime pool rebuild uses the immutable snapshot boundary")
eq(state.mappings.species.RATTATA, frozenMapping,
  "confirmed species mapping survives an option-boundary change")
local repeatWild = hooks["battle.wild"](function(row) return row end,
  { species = "RATTATA", level = 3 },
  { game = game, source = "wild", opts = {} })
eq(repeatWild.species, firstSpecies, "same seed produces the same wild mapping")
boundary.active = true

local untouchedMythic = hooks["battle.wild"](function(row) return row end,
  { species = "MEW", level = 50 },
  { game = game, source = "static", opts = { randomizerProtected = true } })
eq(untouchedMythic.species, "MEW", "protected scripted mythic is never randomized")

local trainerParty = hooks["trainer.party"](
  function(_, _, rows) return rows end, "OPP_YOUNGSTER", 1,
  { { species = "RATTATA", level = 6, moves = { "TACKLE" } } })
ok(data.pokemon[trainerParty[1].species] ~= nil,
  "trainer randomizer returns a registered species")
eq(trainerParty[1].moves, nil,
  "randomized trainer learns the replacement species' natural moves")

local gift = { ctx = { game = game }, species = "CHARMANDER", level = 5 }
game.overworld.map.def.id = "OAKS_LAB"
for _, fn in ipairs(events["pokemon.before_give"]) do fn(gift) end
ok(data.pokemon[gift.species] ~= nil,
  "starter randomizer returns a registered species")

local generalArgs = hooks["script.command"](
  function(_, _, args) return args end,
  { game = game }, "give_item", { "POTION", 1 })
ok(data.items[generalArgs[1]] ~= nil,
  "field item randomizer returns a registered same-category item")
eq(state.finalRules.mappings.items.POTION, state.mappings.items.POTION,
  "generated item mapping joins the immutable final receipt")
local keyArgs = hooks["script.command"](
  function(_, _, args) return args end,
  { game = game }, "give_item", { "BICYCLE", 1 })
eq(keyArgs[1], "BICYCLE", "key items are never randomized")
game.overworld.map.def.id = "ROUTE_1"

-- Every screen remains inspectable through SELECT, while A cannot mutate a
-- confirmed run.  normalize() also restores the final snapshot after reload
-- or a later engine/mod process touches the mutable projection.
rules.open(game)
local lockedMain = game.stack.states[#game.stack.states]
local lockedSeed = state.seed
lockedMain.onAdjustKey(lockedMain.items[6], 1)
eq(state.seed, lockedSeed, "locked main screen cannot reseed")
lockedMain.onChoose(lockedMain.items[4])
local lockedRandom = game.stack.states[#game.stack.states]
eq(type(lockedRandom.onSelectKey), "function",
  "locked Randomizer submenu keeps SELECT help")
for _, item in ipairs(lockedRandom.items) do
  ok(type(item.help) == "string" and #item.help > 30,
    "every Randomizer subrule has SELECT help")
end
local lockedWild = state.randomizer.wild
lockedRandom.onAdjustKey(lockedRandom.items[1], 1)
eq(state.randomizer.wild, lockedWild,
  "locked Randomizer submenu cannot change a mapping rule")
lockedMain.onChoose(lockedMain.items[5])
local lockedNuzlocke = game.stack.states[#game.stack.states]
eq(type(lockedNuzlocke.onSelectKey), "function",
  "locked Nuzlocke submenu keeps SELECT help")
for _, item in ipairs(lockedNuzlocke.items) do
  ok(type(item.help) == "string" and #item.help > 30,
    "every Nuzlocke subrule has SELECT help")
end
lockedNuzlocke.onAdjustKey(lockedNuzlocke.items[1], 1)
eq(state.nuzlocke.mode, "standard",
  "locked Nuzlocke submenu cannot disable or change mode")
eq(rules.applyPreset(state, "standard"), false,
  "public preset seam rejects a locked run")
state.seed = 42
state.randomizer.enabled = false
state.nuzlocke.mode = "off"
state.version = 2
state = rules.state()
eq(state.version, 3, "reload/upgrade normalizes the current run-rules schema")
eq(state.seed, lockedSeed, "reload restores the confirmed seed")
eq(state.randomizer.enabled, true,
  "reload restores the confirmed Randomizer switch")
eq(state.nuzlocke.mode, "standard",
  "reload restores the confirmed Nuzlocke mode")
eq(state.nuzlocke.blackout, "end",
  "hard blackout policy cannot be changed to CONTINUE")

state.areas = {}
local enemy = { species = "RATTATA", level = 3, hp = 10,
  stats = { hp = 10 }, moves = {} }
local firstBattle = { game = game, kind = "wild", enemy = { mon = enemy } }
for _, fn in ipairs(events["battle.started"]) do fn({ battle = firstBattle }) end
ok(state.areas.ROUTE_1 ~= nil, "first area encounter is recorded")

local secondBattle = { game = game, kind = "wild",
  enemy = { mon = { species = "CHARMANDER", level = 4 } } }
for _, fn in ipairs(events["battle.started"]) do fn({ battle = secondBattle }) end
eq(secondBattle.noCatch, true, "later encounter in the same area cannot be caught")

local partyMon = { species = "BULBASAUR", level = 8, hp = 0,
  stats = { hp = 24 }, moves = {} }
game.save.party = { partyMon }
local faintBattle = { game = game, kind = "wild",
  enemy = { mon = enemy } }
local writesBeforeFaint = game.writes
for _, fn in ipairs(events["battle.fainted"]) do
  fn({ battle = faintBattle, battler = { isPlayer = true, mon = partyMon } })
end
eq(partyMon.ascendantNuzlockeDead, true, "ordinary faint marks the party mon dead")
ok(game.writes > writesBeforeFaint,
  "ordinary faint is persisted immediately against reload")
local deathCount = #state.deaths
for _, fn in ipairs(events["battle.fainted"]) do
  fn({ battle = faintBattle, battler = { isPlayer = true, mon = partyMon } })
end
eq(#state.deaths, deathCount,
  "duplicate faint notifications cannot duplicate a durable death")

local protectedMon = { species = "BULBASAUR", level = 8, hp = 0,
  stats = { hp = 24 }, moves = {} }
for _, fn in ipairs(events["battle.fainted"]) do
  fn({ battle = { game = game, kind = "wild", protected = true,
      enemy = { mon = { species = "MEW" } } },
    battler = { isPlayer = true, mon = protectedMon } })
end
eq(protectedMon.ascendantNuzlockeDead, nil,
  "protected mythic faint never creates a Nuzlocke death")

mythicReturning = true
for _, fn in ipairs(events["world.blacked_out"]) do fn({ save = game.save }) end
eq(state.failed, false,
  "protected Mew/Celebi return warp cannot fail the Nuzlocke run")
eq(partyMon.ascendantNuzlockeDead, true,
  "protected return exemption does not rewrite ordinary death history")
mythicReturning = false
for _, fn in ipairs(events["world.blacked_out"]) do fn({ save = game.save }) end
eq(state.failed, true, "ordinary blackout permanently ends the hard run")
eq(partyMon.ascendantNuzlockeDead, nil,
  "failed run clears dead flags so the save remains playable")
eq(partyMon.hp, 24, "failed run returns the team healed")

local shinyGame = fresh("ROUTE_2")
rules.install(shinyGame)
local shinyState = rules.state()
shinyState.nuzlocke.mode = "shinylocke"
shinyState.nuzlocke.shinyOdds = 1
rules.lock(shinyGame, "explicit_start")
local shinyTarget = { species = "CHARMANDER", level = 4, hp = 10,
  stats = { hp = 10 }, moves = {} }
local shinyBattle = { game = shinyGame, kind = "wild",
  enemy = { mon = shinyTarget } }
for _, fn in ipairs(events["battle.started"]) do fn({ battle = shinyBattle }) end
eq(shinyTarget.shiny, true,
  "Shinylocke force roll uses the configured deterministic odds")
eq(shinyBattle.noCatch, nil, "a qualifying Shinylocke encounter stays catchable")

local plus = fresh("REDS_HOUSE_2F")
rules.install(plus)
local plusState = rules.state()
eq(plusState.randomizer.enabled, false,
  "a genuinely new Legacy save/run returns to the safe OFF preset")
eq(plusState.locked, false,
  "a genuinely new Legacy save/run is configurable again per save")

boundary.active = false
local kantoOnly = fresh("OAKS_LAB")
rules.install(kantoOnly)
rules.open(kantoOnly)
local kantoOnlyMenu = kantoOnly.stack.states[#kantoOnly.stack.states]
ok(kantoOnlyMenu.items[2].help:find("#001-151", 1, true) ~= nil,
  "Randomizer SELECT help exposes the effective Kanto-only #001-151 pool")
kantoOnlyMenu.onChoose(kantoOnlyMenu.items[7])
local kantoOnlyConfirm = kantoOnly.stack.states[#kantoOnly.stack.states]
twoLinePages(kantoOnlyConfirm, "Kanto-only final safety confirmation")
kantoOnlyConfirm.choice(true)
eq(rules.state().finalRules.poolDexMax, 151,
  "Beyond-off START RUN snapshots the visible #001-151 pool")
boundary.active = true

local blue = fresh("OAKS_LAB")
blue.save.player.name = "BLUE"
rules.install(blue)
rules.open(blue)
eq(blue.stack.states[#blue.stack.states].title, "ASCENDANT RUN",
  "BLUE reaches the same direct Lab-terminal rule screen")

local green = fresh("OAKS_LAB")
green.save.player.name = "GREEN"
green.save.modData.kanto_ascendant = { extended_characters = {
  version = 1, enabled = true, player_character = "GREEN",
  rival_character = "RED", third_character = "BLUE",
} }
rules.install(green)
rules.open(green)
eq(green.stack.states[#green.stack.states].title, "ASCENDANT RUN",
  "GREEN reaches the same direct Lab-terminal rule screen")
eq(hooks["ui.player_pc.items"], nil,
  "RED, BLUE and GREEN cannot find a duplicate ASC RUN in ordinary PCs")

-- Optional exact-save regression. The release gate supplies a cloned BLITZ
-- snapshot here; this test mutates only the table returned by loadfile and its
-- writeSave stub, never the source snapshot on disk.
local blitzFixture = os.getenv("BLITZ_SAVE_FIXTURE")
if blitzFixture and blitzFixture ~= "" then
  local blitz = fresh("INDIGO_PLATEAU_LOBBY")
  blitz.save = assert(loadfile(blitzFixture))()
  rules.install(blitz)
  rules.open(blitz)
  local blitzMenu = blitz.stack.states[#blitz.stack.states]
  eq(blitzMenu.title, "ASCENDANT RUN",
    "the cloned BLITZ save opens through the same Lab-terminal seam")
  eq(hooks["ui.player_pc.items"], nil,
    "the cloned BLITZ save cannot expose a duplicate ordinary-PC row")
  ok(blitzMenu.items[2].help:find("#001-251", 1, true) ~= nil,
    "the cloned BLITZ save shows its effective #001-251 Randomizer pool")
  blitzMenu.onAdjustKey(blitzMenu.items[2], 1) -- clone-only Randomizer draft
  blitzMenu.onChoose(blitzMenu.items[7])
  local blitzConfirm = blitz.stack.states[#blitz.stack.states]
  twoLinePages(blitzConfirm, "BLITZ-clone final safety confirmation")
  blitzConfirm.choice(true)
  eq(rules.state().finalRules.poolDexMax, 251,
    "BLITZ clone snapshots #001-251 after explicit confirmation")
  eq(rules.state().finalRules.randomizer.enabled, true,
    "BLITZ clone snapshots the one-time Randomizer switch")
end

local oldSave = fresh("REDS_HOUSE_2F")
oldSave.save.party = { { species = "BULBASAUR", level = 20, hp = 40,
  stats = { hp = 40 }, moves = {} } }
rules.install(oldSave)
local oldState = rules.state()
eq(oldState.locked, false,
  "an existing progressed save retains one explicit bedroom-PC setup chance")
eq(oldState.legacyProgress, true,
  "an existing progressed save is marked for the from-now-on warning")
eq(oldState.randomizer.enabled, false,
  "an existing progressed save migrates to the safe standard preset")
rules.open(oldSave)
local oldMenu = oldSave.stack.states[#oldSave.stack.states]
eq(oldMenu.items[7].label, "START RUN",
  "existing save keeps one explicit Lab-terminal setup chance")

local rc25Save = fresh("REDS_HOUSE_2F")
rc25Save.save.party = { { species = "BULBASAUR", level = 20, hp = 40,
  stats = { hp = 40 }, moves = {} } }
rc25Save.save.modData = { kanto_ascendant = { run_rules = {
  version = 1, configured = true, locked = true,
  preset = "standard", seed = 650025,
  randomizer = {
    enabled = false, wild = true, trainers = true, starters = true,
    gifts = false, static = false, items = false, legendary = false,
    balanced = true, consistent = true,
  },
  nuzlocke = { mode = "off", dupes = true, blackout = "end",
    shinyOdds = 4096 },
  mappings = { species = {}, items = {} }, areas = {}, deaths = {},
  encounterSerial = 0,
} } }
rules.install(rc25Save)
local repaired = rules.state()
eq(repaired.version, 3, "RC25 run-rule records migrate to version 3")
eq(repaired.locked, false,
  "RC25's progress-only auto-lock is repaired instead of trapping the menu")
eq(repaired.migrationNoticePending, true,
  "the repaired record requires an explicit from-now-on confirmation")

local genuineLock = fresh("REDS_HOUSE_2F")
genuineLock.save.modData = { kanto_ascendant = { run_rules = {
  version = 1, configured = true, locked = true,
  lockReason = "first_encounter", preset = "standard", seed = 650026,
  randomizer = rc25Save.save.modData.kanto_ascendant.run_rules.randomizer,
  nuzlocke = rc25Save.save.modData.kanto_ascendant.run_rules.nuzlocke,
  mappings = { species = {}, items = {} }, areas = {}, deaths = {},
  encounterSerial = 1,
} } }
rules.install(genuineLock)
eq(rules.state().locked, false,
  "an old encounter-only lock is repaired because it had no explicit YES")
eq(rules.state().migrationNoticePending, true,
  "repaired encounter-only lock must use the new final confirmation")

local explicitOldLock = fresh("REDS_HOUSE_2F")
explicitOldLock.save.modData = { kanto_ascendant = { run_rules = {
  version = 2, configured = true, locked = true,
  lockReason = "player_pc", preset = "ascendant", seed = 650027,
  randomizer = rc25Save.save.modData.kanto_ascendant.run_rules.randomizer,
  nuzlocke = rc25Save.save.modData.kanto_ascendant.run_rules.nuzlocke,
  mappings = { species = {}, items = {} }, areas = {}, deaths = {},
  encounterSerial = 1,
} } }
rules.install(explicitOldLock)
local explicitOldState = rules.state()
eq(explicitOldState.locked, true,
  "an old explicit Player-PC YES receipt remains permanently locked")
eq(explicitOldState.finalRules.seed, 650027,
  "old explicit lock receives an immutable v3 snapshot")

print(("PASS run rules: %d checks"):format(checks))
