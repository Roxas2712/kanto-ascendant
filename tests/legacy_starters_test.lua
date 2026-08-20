local modulePath = os.getenv("KANTO_SIGNALS_MOD_DIR") or "."
local createStarters = assert(loadfile(modulePath .. "/legacy_starters.lua"))()
local johto = assert(loadfile(modulePath .. "/johto_data.lua"))()

local function loadEngineTextBox()
  local candidates = {
    os.getenv("GEN1RECOMP_ROOT"), os.getenv("GEN1RECOMP_DIR"),
    "../gen1recomp", "gen1recomp",
  }
  local root
  for _, candidate in ipairs(candidates) do
    if candidate and candidate ~= "" then
      local handle = io.open(candidate .. "/src/render/TextBox.lua", "rb")
      if handle then handle:close() root = candidate break end
    end
  end
  assert(root, "GEN1RECOMP_ROOT with the target TextBox.lua is required")
  local priorPath = package.path
  package.path = root .. "/?.lua;" .. root .. "/?/init.lua;" .. priorPath
  local ok, value = pcall(function()
    return assert(loadfile(root .. "/src/render/TextBox.lua"))()
  end)
  package.path = priorPath
  assert(ok and type(value) == "table" and type(value.paginate) == "function",
    "target engine TextBox paginator could not be loaded")
  return value
end

local EngineTextBox = loadEngineTextBox()

local assertions = 0
local function check(value, message)
  assertions = assertions + 1
  if not value then error("FAIL: " .. message, 2) end
end
local function eq(actual, expected, message)
  check(actual == expected, message .. " (got " .. tostring(actual)
    .. ", expected " .. tostring(expected) .. ")")
end
local function twoLinePages(text, label)
  local pages = EngineTextBox.paginate(text, 18)
  check(#pages > 0, label .. " has at least one page")
  for index, page in ipairs(pages) do
    check(#page <= 2, ("%s page %d exceeds the 0.1.96 two-line box: %s")
      :format(label, index, table.concat(page, " | ")))
  end
end

local language = "en"
local cryCount, browseSoundCount, hiddenCalls = 0, 0, 0

-- Engine 0.1.96 persists a save through main/.bak/.tmp. The production code
-- snapshots that triplet through SaveData's public persistence seam; this
-- in-memory filesystem lets the focused rollback tests inject each write
-- failure without touching a developer save.
local saveFiles = {}
local saveFs = { failNext = {} }
local function engineSaveFilename(version)
  if version == "blue" then return "save_blue.lua" end
  if version == "yellow" then return "save_yellow.lua" end
  return "save.lua"
end
function saveFs.getInfo(path)
  return saveFiles[path] ~= nil and { type = "file" } or nil
end
function saveFs.read(path) return saveFiles[path] end
function saveFs.write(path, bytes)
  if (saveFs.failNext[path] or 0) > 0 then
    saveFs.failNext[path] = saveFs.failNext[path] - 1
    return false, "injected write failure"
  end
  saveFiles[path] = bytes
  return true
end
function saveFs.remove(path) saveFiles[path] = nil return true end
package.preload["src.core.SaveData"] = function()
  return {
    persistenceFs = function() return saveFs end,
    saveFilename = engineSaveFilename,
  }
end

package.preload["src.pokemon.Party"] = function()
  return {
    MAX = 6,
    add = function(party, mon) party[#party + 1] = mon return true end,
  }
end
package.preload["src.pokemon.Pokemon"] = function()
  return {
    new = function(_, species, level)
      return { species = species, level = level, moves = {} }
    end,
  }
end
package.preload["src.battle.BattleState"] = function()
  return {
    stampOT = function(save, mon)
      mon.ot = save.player.name
      mon.otId = save.player.id
    end,
  }
end
package.preload["src.pokemon.Sprites"] = function()
  return { path = function() return "test-front.png", false end }
end
package.preload["src.battle.TypeChart"] = function()
  local de = {
    PSYCHIC_TYPE = "PSYCHO", FLYING = "FLUG", GRASS = "PFLANZE",
    POISON = "GIFT", FIRE = "FEUER", WATER = "WASSER",
  }
  return {
    displayName = function(id)
      return language == "de" and (de[id] or id) or
        (id == "PSYCHIC_TYPE" and "PSYCHIC" or id)
    end,
  }
end
package.preload["src.core.Sound"] = function()
  return {
    play = function() browseSoundCount = browseSoundCount + 1 end,
    playCry = function() cryCount = cryCount + 1 end,
  }
end
package.preload["src.render.TextBox"] = function()
  return {
    new = function(_, text, onDone, opts)
      return {
        kind = "text", text = text, onDone = onDone,
        choice = opts and opts.choice,
        defaultNo = opts and opts.defaultNo == true,
      }
    end,
  }
end
package.preload["src.script.Commands"] = function()
  return {
    hide_object = function(ctx, map, object)
      hiddenCalls = hiddenCalls + 1
      ctx.save.objectToggles = ctx.save.objectToggles or {}
      ctx.save.objectToggles[map] = ctx.save.objectToggles[map] or {}
      ctx.save.objectToggles[map][object] = false
    end,
  }
end

local function newStack()
  local stack = { items = {} }
  function stack:push(value) self.items[#self.items + 1] = value end
  function stack:pop() return table.remove(self.items) end
  function stack:top() return self.items[#self.items] end
  return stack
end

local function chooseText(stack, answer)
  local text = stack:pop()
  check(text and type(text.choice) == "function",
    "the expected YES/NO text box is on top")
  text.choice(answer)
  return text
end

local function confirmKantoOnly(stack)
  chooseText(stack, false)
  return chooseText(stack, true)
end

local registeredText, eventHandlers = {}, {}
local crystalCalls = 0
local ruleSeedCalls = {}
local mod = {
  id = "kanto_ascendant",
  path = "/bundle/kanto_ascendant",
  content = { text = {} }, events = {},
  exports = { crystalAnimation = {
    staticFrameOne = function(ctx, side, variant)
      crystalCalls = crystalCalls + 1
      local dex = ctx.data.pokemon[ctx.species].dex
      return ("/crystal/front/%s/%d/001.png"):format(variant, dex), true
    end,
  } },
  log = { warn = function() end, error = function() end },
  ui = { ListMenu = { new = function(_, title, rows, opts)
    return { title = title, items = rows, opts = opts }
  end } },
}
mod.exports.runRules = {
  seedLegacy = function(save, snapshot, dexMax)
    local bucket = save.modData.kanto_ascendant
    local previous = bucket.run_rules
    if type(snapshot) == "table" and snapshot.invalid then
      return nil, "invalid archived rules"
    end
    local seed = type(snapshot) == "table" and snapshot.seed or 650000
    if type(previous) == "table" and previous.lockReason == "legacy_start"
        and previous.poolDexMax == dexMax and previous.seed == seed then
      return previous, nil, false
    end
    local seeded = {
      locked = true, configured = true, lockReason = "legacy_start",
      poolDexMax = dexMax, seed = seed,
      randomizer = { enabled = snapshot and snapshot.randomizer
        and snapshot.randomizer.enabled == true or false },
      nuzlocke = { mode = snapshot and snapshot.nuzlocke
        and snapshot.nuzlocke.mode or "off", blackout = "end" },
      finalRules = { poolDexMax = dexMax, seed = seed },
    }
    bucket.run_rules = seeded
    ruleSeedCalls[#ruleSeedCalls + 1] = {
      save = save, dexMax = dexMax, seed = seed,
    }
    return seeded, nil, true
  end,
}
mod.exports.runRules.livePoolMax = 151
mod.exports.runRules.buildPool = function(game)
  local bucket = game.save.modData.kanto_ascendant
  local rules = bucket.run_rules
  mod.exports.runRules.livePoolMax = type(rules) == "table" and rules.locked
      and tonumber(rules.poolDexMax)
    or (bucket.beyond_kanto and bucket.beyond_kanto.active and 251 or 151)
  return true
end
function mod:read(relative)
  if relative == "assets/crystal_animated/front/normal/152/001.png" then
    return "crystal-frame-one"
  end
end
function mod.content.text:register(id, value) registeredText[id] = value end
function mod.events:on(name, fn)
  eventHandlers[name] = eventHandlers[name] or {}
  eventHandlers[name][#eventHandlers[name] + 1] = fn
end

local syncCount, labRivalReceipts = 0, 0
local function runState(save)
  local bucket = save.modData and save.modData.kanto_ascendant
  return bucket and bucket.legacy_journey or nil
end
local journey = {}
journey.completedPaths = { red = false, blue = false, green = false }
function journey.isActive(save)
  local s = runState(save)
  return type(s) == "table" and s.runId ~= nil
end
function journey.activeCharacter(save)
  local s = runState(save)
  return s and s.avatar
end
function journey.syncPartner()
  syncCount = syncCount + 1
  return true
end
function journey.profile()
  if journey.profileThrows then error("injected archive read failure") end
  if journey.profileMissing then return nil end
  return {
    completedPaths = journey.completedPaths,
    readOnly = journey.profileReadOnly,
    futureVersion = journey.profileFutureVersion,
  }
end
function journey.onLabRivalResolved(game)
  labRivalReceipts = labRivalReceipts + 1
  game.titleRestoredAtRivalBoundary = true
  return true
end

local rival = { fail = false, bound = nil }
function rival.bindGame(game) rival.bound = game end
function rival.resolveForJourney(s)
  if rival.fail then return nil, "forced rival failure" end
  check(s.partnerChosen == true and type(s.partnerSpecies) == "string",
    "the rival resolves only after the player partner is staged")
  s.rivalPartner = {
    version = 1, base = "SQUIRTLE", mid = "WARTORTLE",
    final = "BLASTOISE", lineId = "test_water",
    sourcePartner = s.partnerSpecies,
  }
  return s.rivalPartner
end

local i18n = {
  text = function(en, de) return language == "de" and de or en end,
}
local beyondKanto = { listeners = {} }
function beyondKanto.isActive(value)
  local save = value and value.save or value
  local bucket = save and save.modData and save.modData.kanto_ascendant
  return bucket and bucket.beyond_kanto
    and bucket.beyond_kanto.active == true or false
end
function beyondKanto.onChanged(listener)
  beyondKanto.listeners[#beyondKanto.listeners + 1] = listener
end
local function notifyBoundary(game, active, reason)
  for _, listener in ipairs(beyondKanto.listeners) do
    listener(active, game, reason)
  end
end
function beyondKanto.activate(game, activation)
  local bucket = game.save.modData.kanto_ascendant
  local old = bucket.beyond_kanto
  bucket.beyond_kanto = {
    version = 1, active = true, irreversible = true,
    decision = activation and activation.decision or "player_confirmed",
  }
  notifyBoundary(game, true, "activated")
  if game.writeSave and game:writeSave() == false then
    bucket.beyond_kanto = old
    notifyBoundary(game, false, "activation-rollback")
    return false, "save_failed", "BOUNDARY SAVE FAILED"
  end
  return true, "activated", "BOUNDARY ACTIVE"
end
beyondKanto.onChanged(function(_, game)
  mod.exports.runRules.buildPool(game)
end)
local starters = createStarters(mod, {
  journey = journey, hoenn = {}, johto = johto, rival = rival, i18n = i18n,
  beyondKanto = beyondKanto,
})

eq(#starters.canonicalOrder, 251,
  "Oak's authored catalogue has exactly the canonical #001-251")
eq(starters.canonicalOrder[1], "BULBASAUR", "the catalogue starts at #001")
eq(starters.canonicalOrder[151], "MEW", "Kanto closes at #151")
eq(starters.canonicalOrder[152], "CHIKORITA", "Johto starts at #152")
eq(starters.canonicalOrder[251], "CELEBI", "the catalogue closes at #251")

local pokemon = {}
for dex, id in ipairs(starters.canonicalOrder) do
  pokemon[id] = {
    id = id, dex = dex, name = id,
    types = { dex % 2 == 0 and "WATER" or "NORMAL" },
    growthRate = dex % 3 == 0 and "SLOW" or "MEDIUM_FAST",
  }
end
pokemon.BULBASAUR.types = { "GRASS", "POISON" }
pokemon.XATU.types = { "PSYCHIC_TYPE", "FLYING" }
pokemon.TREECKO = {
  id = "TREECKO", dex = 252, name = "TREECKO",
  types = { "GRASS" }, growthRate = "MEDIUM_SLOW",
}
pokemon.TORCHIC = {
  id = "TORCHIC", dex = 255, name = "TORCHIC",
  types = { "FIRE" }, growthRate = "MEDIUM_SLOW",
}
pokemon.MUDKIP = {
  id = "MUDKIP", dex = 258, name = "MUDKIP",
  types = { "WATER" }, growthRate = "MEDIUM_SLOW",
}
-- A lower lexical form with the same Dex number must never replace #157.
pokemon.ASCENDANT_TYPHLOSION = {
  id = "ASCENDANT_TYPHLOSION", dex = 157,
  name = "ASC. TYPHLOSION", types = { "FIRE" }, growthRate = "SLOW",
}

local moveDefs = {}
for _, plan in pairs(starters.legendaryMoveSets) do
  for _, move in ipairs(plan) do
    moveDefs[move] = moveDefs[move]
      or { id = move, pp = 15, power = 50, type = "NORMAL" }
  end
end
local actualTypes = {
  ARTICUNO = { "ICE", "FLYING" }, ZAPDOS = { "ELECTRIC", "FLYING" },
  MOLTRES = { "FIRE", "FLYING" }, MEWTWO = { "PSYCHIC_TYPE" },
  MEW = { "PSYCHIC_TYPE" },
}
for _, species in ipairs({
  "RAIKOU", "ENTEI", "SUICUNE", "LUGIA", "HO_OH", "CELEBI",
}) do
  actualTypes[species] = johto.species[species].types
end
local stabTypes = {
  ARTICUNO = "ICE", ZAPDOS = "ELECTRIC", MOLTRES = "FIRE",
  MEWTWO = "PSYCHIC_TYPE", MEW = "PSYCHIC_TYPE", RAIKOU = "ELECTRIC",
  ENTEI = "FIRE", SUICUNE = "WATER", LUGIA = "FLYING",
  HO_OH = "FIRE", CELEBI = "PSYCHIC_TYPE",
}
for species, move in pairs(starters.legendaryEarlyStab) do
  pokemon[species].types = actualTypes[species]
  moveDefs[move].type = stabTypes[species]
  moveDefs[move].power = 40
end
local function legality(species, level1, learned, machines)
  pokemon[species].level1Moves = level1 or {}
  pokemon[species].learnset = {}
  for index = 1, #(learned or {}), 2 do
    pokemon[species].learnset[#pokemon[species].learnset + 1] = {
      level = learned[index], move = learned[index + 1],
    }
  end
  pokemon[species].tmhm = machines or {}
end
legality("ARTICUNO", { "PECK", "ICE_BEAM" },
  { 55, "AGILITY", 60, "MIST" })
legality("ZAPDOS", { "THUNDERSHOCK", "DRILL_PECK" },
  { 51, "THUNDER", 55, "AGILITY" })
legality("MOLTRES", { "PECK", "FIRE_SPIN" },
  { 55, "AGILITY", 60, "SKY_ATTACK" })
legality("MEWTWO", { "CONFUSION", "SWIFT", "PSYCHIC_M" },
  { 70, "RECOVER" })
legality("MEW", { "POUND" },
  { 10, "TRANSFORM", 20, "MEGA_PUNCH", 40, "PSYCHIC_M" })
for _, species in ipairs({
  "RAIKOU", "ENTEI", "SUICUNE", "LUGIA", "HO_OH", "CELEBI",
}) do
  local def = johto.species[species]
  pokemon[species].level1Moves = def.level1
  pokemon[species].learnset = def.learnset
  pokemon[species].tmhm = def.tmhm
end

local input = { pressed = {} }
function input:wasPressed(id) return self.pressed[id] == true end
function input:isDown() return false end

local function freshSave(avatar)
  return {
    version = "red",
    player = { id = 77, name = "RED", rival = "BLUE" },
    party = {}, boxes = { {} }, daycare = {}, inventory = {},
    flags = {
      EVENT_FOLLOWED_OAK_INTO_LAB = true,
      EVENT_OAK_ASKED_TO_CHOOSE_MON = true,
      KA_LEGACY_RIVAL_BALL_TAKEN = true,
    },
    pokedex = { seen = {}, owned = {} }, objectToggles = {},
    modData = { kanto_ascendant = {
      beyond_kanto = {
        version = 1, active = true, irreversible = true,
        decision = "test_active",
      },
      legacy_journey = {
      version = 7, cycle = 2, runId = "RUN:2", avatar = avatar or "RED",
      pendingRunRules = {
        seed = 650000, randomizer = { enabled = false },
        nuzlocke = { mode = "off" },
      },
      rivalBallTaken = true,
      completedPaths = { red = false, blue = false, green = false },
      },
    } },
  }
end

local function newGame(avatar)
  local game = {
    data = { pokemon = pokemon, moves = moveDefs }, save = freshSave(avatar),
    stack = newStack(), input = input, writeCount = 0,
    writeFails = false,
  }
  function game:writeSave()
    self.writeCount = self.writeCount + 1
    return not self.writeFails
  end
  return game
end

local function savePath(game)
  return engineSaveFilename(game.save.version)
end

local function resetDisk(game, suffix)
  game.save.version = suffix
  local main = savePath(game)
  saveFiles[main] = "SEALED:DEX=151:" .. suffix
  saveFiles[main .. ".bak"] = "OLDER:DEX=151:" .. suffix
  saveFiles[main .. ".tmp"] = nil
  saveFs.failNext = {}
  return main, {
    [main] = saveFiles[main],
    [main .. ".bak"] = saveFiles[main .. ".bak"],
    [main .. ".tmp"] = nil,
  }
end

local function installAtomicWriter(game)
  function game:writeSave()
    self.writeCount = self.writeCount + 1
    local main = savePath(self)
    local bucket = self.save.modData.kanto_ascendant
    local rules = bucket.run_rules
    local bytes = ("LIVE:DEX=%s:JOHTO=%s"):format(
      tostring(rules and rules.poolDexMax),
      tostring(bucket.beyond_kanto and bucket.beyond_kanto.active == true))
    local previous = saveFs.read(main)
    if previous then
      local backed = saveFs.write(main .. ".bak", previous)
      if backed == false then return false end
    end
    local staged = saveFs.write(main .. ".tmp", bytes)
    if staged == false then return false end
    saveFs.remove(main)
    local written = saveFs.write(main, bytes)
    if written == false then return false end
    saveFs.remove(main .. ".tmp")
    return true
  end
end

local function reloadDiskDex(main)
  for _, row in ipairs({
    { source = "main", path = main },
    { source = "tmp", path = main .. ".tmp" },
    { source = "bak", path = main .. ".bak" },
  }) do
    local bytes = saveFiles[row.path]
    local dex = type(bytes) == "string" and bytes:match("DEX=(%d+)") or nil
    if dex then return tonumber(dex), row.source end
  end
end

local game = newGame("RED")
local spritePath, spriteTrueColor, spriteSource =
  starters.crystalSpritePath(game, "CHIKORITA")
eq(spritePath, "/crystal/front/normal/152/001.png",
  "Legacy partner previews request the explicit Crystal front frame")
eq(spriteTrueColor, true,
  "Crystal partner previews retain their authored true-colour pixels")
eq(spriteSource, "crystal",
  "the catalogue records Crystal rather than Oak's generic sprite provider")
check(crystalCalls > 0, "the Crystal controller owns partner preview lookup")
local installedCrystal = mod.exports.crystalAnimation
mod.exports.crystalAnimation = nil
local reboundPath, reboundTrueColor, reboundSource =
  starters.crystalSpritePath(game, "CHIKORITA")
eq(reboundPath,
  "/bundle/kanto_ascendant/assets/crystal_animated/front/normal/152/001.png",
  "a resume before controller rebind still resolves bundled Crystal frame one")
eq(reboundTrueColor, true,
  "the deterministic bundled Crystal preview remains true-colour")
eq(reboundSource, "crystal",
  "late controller installation cannot silently select Oak's generic art")
mod.exports.crystalAnimation = installedCrystal
local free = starters.rows(game, "free")
local balanced = starters.rows(game, "balanced")
eq(#free, 118,
  "Free Choice hides all eleven capstone partners before three path clears")
eq(#free, #starters.partnerAllowlistOrder - #starters.legendaryOrder,
  "the locked UI removes precisely the eleven authored capstone entries")
local priorDex = 0
for _, row in ipairs(free) do
  check(row.dex > priorDex, "the locked UI preserves canonical Dex order")
  priorDex = row.dex
  check(starters.partnerAllowlist[row.id],
    "the UI cannot expose an out-of-allowlist species")
  eq(starters.legendaryIds[row.id], nil,
    "an incomplete durable archive cannot expose " .. row.id .. " as a legend")
end
eq(table.concat((function()
  local ids = {}
  for _, row in ipairs(free) do ids[#ids + 1] = row.id end
  return ids
end)(), ","),
  "BULBASAUR,CHARMANDER,SQUIRTLE,CATERPIE,WEEDLE,PIDGEY,RATTATA,SPEAROW,EKANS,SANDSHREW,NIDORAN_F,NIDORAN_M,VULPIX,ZUBAT,ODDISH,PARAS,VENONAT,DIGLETT,MEOWTH,PSYDUCK,MANKEY,GROWLITHE,POLIWAG,ABRA,MACHOP,BELLSPROUT,TENTACOOL,GEODUDE,PONYTA,SLOWPOKE,MAGNEMITE,FARFETCHD,DODUO,SEEL,GRIMER,SHELLDER,GASTLY,ONIX,DROWZEE,KRABBY,VOLTORB,EXEGGCUTE,CUBONE,LICKITUNG,KOFFING,RHYHORN,CHANSEY,TANGELA,KANGASKHAN,HORSEA,GOLDEEN,STARYU,MR_MIME,SCYTHER,PINSIR,TAUROS,MAGIKARP,LAPRAS,DITTO,EEVEE,PORYGON,OMANYTE,KABUTO,AERODACTYL,SNORLAX,DRATINI,CHIKORITA,CYNDAQUIL,TOTODILE,SENTRET,HOOTHOOT,LEDYBA,SPINARAK,CHINCHOU,PICHU,CLEFFA,IGGLYBUFF,TOGEPI,NATU,MAREEP,MARILL,SUDOWOODO,HOPPIP,AIPOM,SUNKERN,YANMA,WOOPER,MURKROW,MISDREAVUS,UNOWN,WOBBUFFET,GIRAFARIG,PINECO,DUNSPARCE,GLIGAR,SNUBBULL,QWILFISH,SHUCKLE,HERACROSS,SNEASEL,TEDDIURSA,SLUGMA,SWINUB,CORSOLA,REMORAID,DELIBIRD,MANTINE,SKARMORY,HOUNDOUR,PHANPY,STANTLER,SMEARGLE,TYROGUE,SMOOCHUM,ELEKID,MAGBY,MILTANK,LARVITAR",
  "the derived free allowlist has an exact stable canonical order")

-- Run-local seals, the three Hoenn stones and encounter/catch flags are not
-- the capstone authority. Only the validated external profile may add the
-- eleven legends/mythicals back to Oak's authored order.
local run = runState(game.save)
run.completedPaths = { red = true, blue = true, green = true }
game.save.inventory.BLAZIKENITE = 1
game.save.inventory.SWAMPERTITE = 1
game.save.inventory.SCEPTILITE = 1
game.save.flags.EVENT_BEAT_ARTICUNO = true
game.save.flags.EVENT_BEAT_MEWTWO = true
game.save.pokedex.owned.MEW = true
game.save.pokedex.owned.CELEBI = true
eq(starters.legendaryUnlocked(), false,
  "run-local seals, stones and legendary encounters cannot unlock capstones")
eq(#starters.rows(game, "free"), 118,
  "tampered save-local evidence cannot alter Oak's partner catalogue")

local priorCompleted = journey.completedPaths
journey.completedPaths = { red = true, blue = true, green = true }
check(starters.legendaryUnlocked(),
  "three exact durable archive paths unlock capstone partners")
local mastered = starters.rows(game, "free")
eq(#mastered, 132,
  "the completed archive restores eleven capstones and three Hoenn rewards")
local masteredSet = {}
for index, row in ipairs(mastered) do
  masteredSet[row.id] = true
  if index <= #starters.partnerAllowlistOrder then
    eq(row.id, starters.partnerAllowlistOrder[index],
      "mastered catalogue restores exact canonical allowlist order")
  end
end
eq(table.concat({ mastered[130].id, mastered[131].id, mastered[132].id }, ","),
  "TORCHIC,MUDKIP,TREECKO",
  "mastered catalogue appends the explicit RED/BLUE/GREEN reward order")
for _, species in ipairs(starters.legendaryOrder) do
  check(masteredSet[species],
    "the mastered #001-251 catalogue includes " .. species)
end

local kantoMastered = newGame("RED")
runState(kantoMastered.save).partnerDexMax = 151
local kantoMasteredSet = {}
for _, row in ipairs(starters.rows(kantoMastered, "free")) do
  kantoMasteredSet[row.id] = true
end
for _, species in ipairs({ "ARTICUNO", "ZAPDOS", "MOLTRES", "MEWTWO", "MEW" }) do
  check(kantoMasteredSet[species],
    "a mastered Kanto-only run still offers " .. species)
end
for _, species in ipairs({ "RAIKOU", "ENTEI", "SUICUNE", "LUGIA", "HO_OH", "CELEBI" }) do
  eq(kantoMasteredSet[species], nil,
    "a mastered #001-151 run still seals Johto species " .. species)
end
for _, species in ipairs({ "TORCHIC", "MUDKIP", "TREECKO" }) do
  eq(kantoMasteredSet[species], nil,
    "a #001-151 run still seals the path-earned Hoenn reward " .. species)
end

journey.profileReadOnly = true
eq(starters.legendaryUnlocked(), false,
  "a read-only future/unsafe archive fails the capstone gate closed")
journey.profileReadOnly = nil
journey.profileFutureVersion = 99
eq(starters.legendaryUnlocked(), false,
  "unknown future archive schema cannot cross-unlock capstones")
journey.profileFutureVersion = nil
journey.completedPaths = { red = true, blue = true, green = 1 }
eq(starters.legendaryUnlocked(), false,
  "truthy tampering cannot replace an exact durable GREEN completion bit")
journey.completedPaths = priorCompleted
check(starters.basePartnerIds.GASTLY and starters.basePartnerIds.DITTO
    and starters.basePartnerIds.PICHU,
  "Free Choice admits base stages and standalone species")
check(starters.partnerAllowlist.DITTO and starters.partnerAllowlist.PICHU,
  "the explicit authoritative allowlist retains Ditto and Pichu")
eq(starters.basePartnerIds.GENGAR, nil, "Free Choice excludes evolved Gengar")
eq(starters.partnerAllowlist.DRAGONITE, nil,
  "Free Choice excludes evolved Dragonite")
eq(starters.basePartnerIds.PIKACHU, nil, "Pichu excludes Pikachu from Free Choice")
eq(starters.basePartnerIds.TREECKO, nil,
  "path-earned Hoenn rewards remain outside the static base allowlist")
check(#balanced > 20 and #balanced < #free,
  "Balanced Choice is a meaningful curated subset")
local balancedSet = {}
for _, row in ipairs(balanced) do balancedSet[row.id] = true end
check(balancedSet.PIDGEY and balancedSet.CHIKORITA and balancedSet.PICHU,
  "Balanced Choice includes weak early Kanto and Johto partners")
eq(balancedSet.PIKACHU, nil,
  "Balanced Choice uses the same base-stage allowlist as Free Choice")
eq(balancedSet.MEWTWO, nil, "Balanced Choice excludes Mewtwo")
eq(next(game.save.pokedex.seen), nil,
  "opening either catalogue never fills the new Pokédex")

-- A completed Hidden-Evolution path now contributes its Hoenn starter to
-- Oak's reusable middle-ball catalogue for every later character.  This
-- cross-character reward is deliberately narrower than the static #001-251
-- partner allowlist: only exact booleans from the validated archive profile
-- may add these three rows, and both catalogue filters must agree.
local HOENN_CATALOG_IDS = {
  TORCHIC = true, MUDKIP = true, TREECKO = true,
}
local function hoennCatalogIds(gameNow, mode)
  local ids = {}
  for _, row in ipairs(starters.rows(gameNow, mode)) do
    if HOENN_CATALOG_IDS[row.id] then ids[#ids + 1] = row.id end
  end
  return table.concat(ids, ",")
end
local function expectHoennCatalog(gameNow, expected, label)
  eq(hoennCatalogIds(gameNow, "balanced"), expected,
    label .. " in Balanced Choice")
  eq(hoennCatalogIds(gameNow, "free"), expected,
    label .. " in Free Choice")
end

local catalogAuthorityGame = newGame("GREEN")
expectHoennCatalog(catalogAuthorityGame, "", "an empty archive exposes no Hoenn row")
eq(starters.partnerAllowlist.TORCHIC, nil,
  "the durable reward does not widen the static rival/catalogue allowlist")
eq(starters.partnerAllowlist.MUDKIP, nil,
  "Mudkip remains outside the static #001-251 allowlist")
eq(starters.partnerAllowlist.TREECKO, nil,
  "Treecko remains outside the static #001-251 allowlist")

local spoofBucket = catalogAuthorityGame.save.modData.kanto_ascendant
runState(catalogAuthorityGame.save).completedPaths = {
  red = true, blue = true, green = true,
}
spoofBucket.early_hevo_survey = {
  version = 1, authority = "viridian_pre_hall_hevo_survey_v1",
  profile = "RED", admitted = true, entered = true,
}
spoofBucket.hevo_persistent = {
  meta = { RED = true, BLUE = true, GREEN = true },
  permanentItems = {
    LEGACY_STARTER_TORCHIC = true,
    LEGACY_STARTER_MUDKIP = true,
    LEGACY_STARTER_TREECKO = true,
  },
}
catalogAuthorityGame.save.flags.KA_HEVO_FISSURE_DISCOVERED_RED = true
catalogAuthorityGame.save.flags.KA_HEVO_FISSURE_DISCOVERED_BLUE = true
catalogAuthorityGame.save.flags.KA_HEVO_FISSURE_DISCOVERED_GREEN = true
catalogAuthorityGame.save.inventory.BLAZIKENITE = 1
catalogAuthorityGame.save.inventory.SWAMPERTITE = 1
catalogAuthorityGame.save.inventory.SCEPTILITE = 1
catalogAuthorityGame.save.pokedex.owned.TORCHIC = true
catalogAuthorityGame.save.pokedex.owned.MUDKIP = true
catalogAuthorityGame.save.pokedex.owned.TREECKO = true
expectHoennCatalog(catalogAuthorityGame, "",
  "survey, puzzle, save-local, ownership and stone spoofing expose nothing")

journey.completedPaths = { red = true, blue = false, green = false }
for _, avatar in ipairs({ "RED", "BLUE", "GREEN" }) do
  expectHoennCatalog(newGame(avatar), "TORCHIC",
    "RED's first durable completion follows " .. avatar .. " into the middle ball")
end
journey.completedPaths = { red = true, blue = true, green = false }
expectHoennCatalog(newGame("GREEN"), "TORCHIC,MUDKIP",
  "two different durable paths expose their two authored starters")
journey.completedPaths = { red = true, blue = true, green = true }
expectHoennCatalog(newGame("RED"), "TORCHIC,MUDKIP,TREECKO",
  "the third different durable path completes the three-starter catalogue")

journey.completedPaths = { red = true, blue = true, green = 1 }
expectHoennCatalog(newGame("RED"), "TORCHIC,MUDKIP",
  "a truthy non-boolean path bit cannot authorize a starter")
journey.profileReadOnly = true
expectHoennCatalog(newGame("RED"), "",
  "a read-only archive profile fails the Hoenn catalogue closed")
journey.profileReadOnly = nil
journey.profileFutureVersion = 99
expectHoennCatalog(newGame("RED"), "",
  "an unknown future archive profile fails the Hoenn catalogue closed")
journey.profileFutureVersion = nil
journey.profileMissing = true
expectHoennCatalog(newGame("RED"), "",
  "a missing archive profile fails the Hoenn catalogue closed")
journey.profileMissing = nil
journey.profileThrows = true
expectHoennCatalog(newGame("RED"), "",
  "an archive read failure fails the Hoenn catalogue closed")
journey.profileThrows = nil

-- Direct selection is accepted only through the real R/B or Yellow catalogue
-- source.  The left/current-hero contract remains the distinct `hoenn` mode.
journey.completedPaths = { red = true, blue = false, green = false }
local kantoOnlyReward = newGame("BLUE")
runState(kantoOnlyReward.save).partnerDexMax = 151
expectHoennCatalog(kantoOnlyReward, "",
  "a run explicitly fixed to #001-151 keeps non-Kanto rewards sealed")
eq(starters.choose(kantoOnlyReward, "TORCHIC", "balanced", "catalog",
  "catalog"), false,
  "a direct API call cannot bypass the fixed #001-151 partner pool")
local crossCharacter = newGame("BLUE")
local crossChosen, crossMon = starters.choose(crossCharacter, "TORCHIC",
  "balanced", "catalog", "catalog")
check(crossChosen and crossMon.species == "TORCHIC",
  "BLUE may select RED's durable Torchic from the real middle ball")
eq(runState(crossCharacter.save).partnerMode, "balanced",
  "the cross-character reward remains a catalogue choice")
eq(runState(crossCharacter.save).rivalPartner.sourcePartner, "TORCHIC",
  "the rival binding records the exact Hoenn catalogue choice")

journey.completedPaths = { red = false, blue = false, green = false }
local alreadyChosen = newGame("BLUE")
local ordinaryChosen = starters.choose(alreadyChosen, "BULBASAUR",
  "balanced", "catalog", "catalog")
check(ordinaryChosen, "the control run commits its ordinary partner")
journey.completedPaths.red = true
eq(runState(alreadyChosen.save).partnerSpecies, "BULBASAUR",
  "a later archive completion never rewrites the current-run partner")
eq(starters.choose(alreadyChosen, "TORCHIC", "balanced", "catalog",
  "catalog"), false,
  "a later archive completion never reopens the consumed partner choice")

local yellowEquivalent = newGame("GREEN")
local yellowChosen, yellowMon = starters.choose(yellowEquivalent, "TORCHIC",
  "free", "catalog", "yellow_catalog")
check(yellowChosen and yellowMon.species == "TORCHIC",
  "Yellow's equivalent catalogue source accepts the durable Hoenn row")
eq(runState(yellowEquivalent.save).partnerMode, "free",
  "Yellow persists the chosen catalogue filter")

local sourceSpoof = newGame("BLUE")
local spoofChosen = starters.choose(sourceSpoof, "TORCHIC",
  "balanced", "left", "hoenn_ball")
eq(spoofChosen, false,
  "a non-catalogue source cannot spend the cross-character reward")
eq(#sourceSpoof.save.party, 0,
  "source spoofing cannot stage a partner")

local failedCatalogSave = newGame("BLUE")
failedCatalogSave.writeFails = true
local catalogSaved, catalogSaveWhy = starters.choose(failedCatalogSave,
  "TORCHIC", "free", "catalog", "catalog")
eq(catalogSaved, false,
  "a failed save rolls the cross-character catalogue choice back")
eq(catalogSaveWhy, "save failed",
  "the failed durable catalogue write is explicit")
eq(#failedCatalogSave.save.party, 0,
  "failed catalogue persistence leaves no staged Pokémon")
eq(runState(failedCatalogSave.save).partnerChosen, nil,
  "failed catalogue persistence leaves no partner sentinel")
eq(failedCatalogSave.save.pokedex.owned.TORCHIC, nil,
  "failed catalogue persistence leaves no Pokédex ownership")

local reloadedCatalog = newGame("GREEN")
expectHoennCatalog(reloadedCatalog, "TORCHIC",
  "archive-authorized rows survive a new game/save object")
local visualRows = starters.rows(reloadedCatalog, "balanced")
local visualIndex
for index, row in ipairs(visualRows) do
  if row.id == "TORCHIC" then visualIndex = index break end
end
check(visualIndex ~= nil, "the graphical row includes durable Torchic")
local visualCatalog = starters.Catalog.new(reloadedCatalog, {
  onPartnerChosen = function() end, onCatalogCancelled = function() end,
}, {
  mode = "balanced", ball = "catalog", source = "catalog",
  rows = visualRows, index = visualIndex,
})
eq(visualCatalog:current().spriteSource, "crystal",
  "the durable Hoenn row uses its reviewed Crystal preview")

journey.completedPaths = { red = false, blue = false, green = false }

-- Before the once-only partner list appears, Oak asks whether this new cycle
-- should irreversibly open Johto. NO is the safe default, but it must open a
-- second default-NO safety question before the one-time #001-151 choice is
-- committed. Driftglass remains available as a later world unlock.
local kantoDecision = newGame("RED")
kantoDecision.save.modData.kanto_ascendant.beyond_kanto = {
  version = 1, active = false, decision = "fresh_gen1",
}
local kantoReady
starters.ensureLegacyBeyond(kantoDecision, function(active)
  kantoReady = active
end)
local boundaryPrompt = kantoDecision.stack:top()
check(boundaryPrompt and boundaryPrompt.defaultNo
    and boundaryPrompt.text:find("RANDOMIZER ALSO", 1, true)
    and boundaryPrompt.text:find("THIS IS PERMANENT", 1, true),
  "Oak explains the permanent 151/251 consequence before the default-NO choice")
twoLinePages(boundaryPrompt.text,
  "English permanent Johto boundary question")
chooseText(kantoDecision.stack, false)
local noJohtoConfirmation = kantoDecision.stack:top()
check(noJohtoConfirmation and noJohtoConfirmation.defaultNo
    and noJohtoConfirmation.text:find("DRIFTGLASS MAY", 1, true),
  "declining Johto opens a second default-NO explanation of the later unlock")
twoLinePages(noJohtoConfirmation.text,
  "English Kanto-only safety question")
eq(kantoReady, nil,
  "the first NO cannot consume the once-only partner decision")
eq(starters.partnerDexMax(kantoDecision.save), 151,
  "the unconfirmed NO leaves the effective catalogue fallback untouched")
eq(runState(kantoDecision.save).partnerDexMax, nil,
  "the unconfirmed NO writes no durable partner boundary")
eq(kantoDecision.writeCount, 0,
  "the unconfirmed NO performs no save write")
chooseText(kantoDecision.stack, false)
local returnedBoundaryPrompt = kantoDecision.stack:top()
check(returnedBoundaryPrompt and returnedBoundaryPrompt.defaultNo
    and returnedBoundaryPrompt.text:find("OAK: OPEN JOHTO", 1, true),
  "NO on the safety question returns to Oak's original decision")
eq(runState(kantoDecision.save).partnerDexMax, nil,
  "returning from the safety question still mutates nothing")
chooseText(kantoDecision.stack, false)
chooseText(kantoDecision.stack, true)
eq(kantoReady, false, "declining continues with the Kanto-only partner list")
eq(starters.partnerDexMax(kantoDecision.save), 151,
  "declining durably freezes this partner choice at #001-151")
eq(kantoDecision.writeCount, 1,
  "the Kanto-only decision is saved before any partner is shown")
eq(runState(kantoDecision.save).runRulesLocked, true,
  "the Kanto decision locks run rules before any partner is shown")
eq(kantoDecision.save.modData.kanto_ascendant.run_rules.poolDexMax, 151,
  "the same Kanto write freezes the Randomizer pool at #001-151")
check(not (function()
  for _, row in ipairs(starters.rows(kantoDecision, "free")) do
    if row.id == "CHIKORITA" then return true end
  end
  return false
end)(), "declining hides Johto partners from the final one-time choice")
local stackDepth = #kantoDecision.stack.items
starters.ensureLegacyBeyond(kantoDecision, function(active)
  kantoReady = active
end)
eq(#kantoDecision.stack.items, stackDepth,
  "the persisted Kanto decision is not asked again after reopening the ball")
local driftglassChanged, driftglassReason = beyondKanto.activate(kantoDecision, {
  decision = "driftglass_later",
})
check(driftglassChanged and driftglassReason == "activated"
    and beyondKanto.isActive(kantoDecision.save),
  "a confirmed Kanto-only partner choice never blocks later Driftglass access")
eq(starters.partnerDexMax(kantoDecision.save), 151,
  "later Driftglass activation cannot rewrite the consumed partner catalogue")
check(not (function()
  for _, row in ipairs(starters.rows(kantoDecision, "free")) do
    if row.id == "CHIKORITA" then return true end
  end
  return false
end)(), "later Driftglass activation keeps the already fixed #001-151 choice")

local johtoDecision = newGame("BLUE")
johtoDecision.save.modData.kanto_ascendant.beyond_kanto = {
  version = 1, active = false, decision = "fresh_gen1",
}
local johtoReady
starters.ensureLegacyBeyond(johtoDecision, function(active)
  johtoReady = active
end)
chooseText(johtoDecision.stack, true)
eq(runState(johtoDecision.save).runRulesLocked, true,
  "Johto activation locks run rules before its readable receipt")
eq(johtoDecision.save.modData.kanto_ascendant.run_rules.poolDexMax, 251,
  "Johto activation writes the #001-251 Randomizer pool atomically")
local activatedText = johtoDecision.stack:pop()
check(activatedText and type(activatedText.onDone) == "function",
  "successful Johto activation pauses on a readable receipt")
activatedText.onDone()
eq(johtoReady, true, "accepting proceeds only after the activation receipt")
eq(starters.partnerDexMax(johtoDecision.save), 251,
  "accepting opens the full #001-251 partner boundary")
eq(johtoDecision.save.modData.kanto_ascendant.beyond_kanto.decision,
  "legacy_partner_catalog",
  "the irreversible receipt identifies Oak's Legacy partner decision")
local johtoWrites = johtoDecision.writeCount
johtoReady = nil
starters.ensureLegacyBeyond(johtoDecision, function(active)
  johtoReady = active
end)
eq(johtoReady, true,
  "power-loss resume recognizes the already locked Johto contract")
eq(johtoDecision.writeCount, johtoWrites,
  "power-loss resume does not rewrite or reroll a locked contract")
check((function()
  for _, row in ipairs(starters.rows(johtoDecision, "free")) do
    if row.id == "CHIKORITA" then return true end
  end
  return false
end)(), "accepting exposes Johto partners before the player chooses")

-- Failed writes roll back the pool, lock marker and seeded rules as one unit.
-- Retrying derives the same archived seed and only then opens a catalogue.
local failedRules = newGame("GREEN")
failedRules.save.modData.kanto_ascendant.beyond_kanto = {
  version = 1, active = false, decision = "fresh_gen1",
}
runState(failedRules.save).pendingRunRules = {
  seed = 777777,
  randomizer = { enabled = true },
  nuzlocke = { mode = "standard" },
}
failedRules.writeFails = true
local failedReady, failedBlocked
starters.ensureLegacyBeyond(failedRules, function(active)
  failedReady = active
end, function(reason)
  failedBlocked = reason
end)
confirmKantoOnly(failedRules.stack)
eq(failedReady, nil,
  "failed atomic Kanto write never opens the partner catalogue")
eq(runState(failedRules.save).partnerDexMax, nil,
  "failed atomic Kanto write rolls back partner pool")
eq(runState(failedRules.save).runRulesLocked, nil,
  "failed atomic Kanto write rolls back the rule-lock marker")
eq(failedRules.save.modData.kanto_ascendant.run_rules, nil,
  "failed atomic Kanto write rolls back seeded rules")
local failedHint = failedRules.stack:pop()
check(failedHint and type(failedHint.onDone) == "function",
  "failed atomic write leaves a readable retry receipt")
failedHint.onDone()
eq(failedBlocked, "save_failed",
  "failed atomic write reports its retry-safe reason")
failedRules.writeFails = false
starters.ensureLegacyBeyond(failedRules, function(active)
  failedReady = active
end)
confirmKantoOnly(failedRules.stack)
eq(failedReady, false, "successful retry opens the Kanto catalogue")
eq(failedRules.save.modData.kanto_ascendant.run_rules.seed, 777777,
  "successful retry preserves the archived confirmed seed")

local failedJohto = newGame("BLUE")
failedJohto.save.modData.kanto_ascendant.beyond_kanto = {
  version = 1, active = false, decision = "fresh_gen1",
}
runState(failedJohto.save).pendingRunRules = {
  seed = 888888, randomizer = { enabled = true },
  nuzlocke = { mode = "off" },
}
failedJohto.writeFails = true
local failedJohtoReady
starters.ensureLegacyBeyond(failedJohto, function(active)
  failedJohtoReady = active
end)
chooseText(failedJohto.stack, true)
eq(failedJohtoReady, nil,
  "failed Johto activation never opens the partner catalogue")
eq(runState(failedJohto.save).partnerDexMax, nil,
  "failed Johto activation rolls back partner pool")
eq(failedJohto.save.modData.kanto_ascendant.run_rules, nil,
  "failed Johto activation rolls back seeded rules")
eq(beyondKanto.isActive(failedJohto), false,
  "failed Johto activation rolls back the permanent boundary")
eq(mod.exports.runRules.livePoolMax, 151,
  "failed Johto activation rebuilds the live Randomizer pool at #001-151")

-- Reproduce both SaveData 0.1.96 failure windows for every Legacy identity.
-- A rejected #251 write must restore main/.bak/.tmp exactly, rebuild the live
-- pool, and leave no recovery witness that could unlock Johto after restart.
for _, locale in ipairs({ "en", "de" }) do
  language = locale
  for _, character in ipairs({ "RED", "BLUE", "GREEN" }) do
    for _, failure in ipairs({ "tmp", "main" }) do
      local label = locale .. " " .. character .. " " .. failure
      local rollbackGame = newGame(character)
      rollbackGame.save.modData.kanto_ascendant.beyond_kanto = {
        version = 1, active = false, decision = "fresh_gen1",
      }
      local main, before = resetDisk(rollbackGame,
        ({ RED = "red", BLUE = "blue", GREEN = "yellow" })[character])
      installAtomicWriter(rollbackGame)
      saveFs.failNext[failure == "tmp" and main .. ".tmp" or main] = 1
      local ready, blocked
      starters.ensureLegacyBeyond(rollbackGame, function(active)
        ready = active
      end, function(reason)
        blocked = reason
      end)
      chooseText(rollbackGame.stack, true)
      eq(ready, nil, label
        .. " failure never opens the partner catalogue")
      eq(runState(rollbackGame.save).partnerDexMax, nil,
        label .. " failure restores the partner boundary")
      eq(rollbackGame.save.modData.kanto_ascendant.run_rules, nil,
        label .. " failure restores saved RunRules")
      eq(beyondKanto.isActive(rollbackGame), false,
        label .. " failure keeps Johto sealed")
      eq(mod.exports.runRules.livePoolMax, 151,
        label .. " failure rebuilds the live 151 pool")
      eq(saveFiles[main], before[main],
        label .. " failure restores reloadable main")
      eq(saveFiles[main .. ".bak"], before[main .. ".bak"],
        label .. " failure restores the old backup")
      eq(saveFiles[main .. ".tmp"], before[main .. ".tmp"],
        label .. " failure removes the rejected witness")
      local reloadDex, reloadSource = reloadDiskDex(main)
      eq(reloadDex, 151,
        label .. " restart can load only the previous 151 contract")
      eq(reloadSource, "main",
        label .. " restart never promotes the rejected temporary witness")
      local receipt = rollbackGame.stack:pop()
      check(receipt and type(receipt.onDone) == "function",
        label .. " failure leaves an A-gated receipt")
      twoLinePages(receipt.text,
        label .. " rollback receipt")
      receipt.onDone()
      eq(blocked, "save_failed",
        label .. " failure reports verified rollback")
    end
  end
end
language = "en"

-- Repeated B/NO navigation must replace the two prompt states instead of
-- growing the stack or mutating the fresh save.
local loopDecision = newGame("RED")
loopDecision.save.modData.kanto_ascendant.beyond_kanto = {
  version = 1, active = false, decision = "fresh_gen1",
}
starters.ensureLegacyBeyond(loopDecision, function()
  error("NO loop must never open a catalogue")
end)
for _ = 1, 50 do
  chooseText(loopDecision.stack, false)
  chooseText(loopDecision.stack, false)
  eq(#loopDecision.stack.items, 1,
    "default-NO loop keeps exactly one prompt on the stack")
end
eq(loopDecision.writeCount, 0,
  "50 default-NO loops perform no save write")
eq(runState(loopDecision.save).partnerDexMax, nil,
  "50 default-NO loops perform no partner-boundary mutation")
eq(loopDecision.save.modData.kanto_ascendant.run_rules, nil,
  "50 default-NO loops perform no RunRules mutation")

-- Every supported Legacy identity receives the same safe, readable contract
-- in both shipped languages. Exercise both terminal decisions: the guarded
-- NO path freezes only this consumed partner choice at 151, while the first
-- YES irreversibly opens the save and its live Randomizer pool at 251.
for _, locale in ipairs({ "en", "de" }) do
  language = locale
  for _, character in ipairs({ "RED", "BLUE", "GREEN" }) do
    local label = locale .. " " .. character
    local kantoGame = newGame(character)
    kantoGame.save.modData.kanto_ascendant.beyond_kanto = {
      version = 1, active = false, decision = "fresh_gen1",
    }
    local kantoActive
    starters.ensureLegacyBeyond(kantoGame, function(active)
      kantoActive = active
    end)
    local first = kantoGame.stack:top()
    check(first and first.defaultNo,
      label .. " first Johto decision defaults to NO")
    check(first.text:find(locale == "de" and "DAUERHAFT" or "PERMANENT",
        1, true) ~= nil,
      label .. " discloses permanence before YES")
    twoLinePages(first.text, label .. " first Johto decision")
    chooseText(kantoGame.stack, false)
    local safety = kantoGame.stack:top()
    check(safety and safety.defaultNo,
      label .. " Kanto-only safety question defaults to NO")
    twoLinePages(safety.text, label .. " Kanto-only safety question")
    chooseText(kantoGame.stack, false)
    local returned = kantoGame.stack:top()
    check(returned and returned.defaultNo,
      label .. " second NO returns to the first decision")
    eq(kantoGame.writeCount, 0,
      label .. " second NO writes no save")
    eq(runState(kantoGame.save).partnerDexMax, nil,
      label .. " second NO mutates no partner boundary")
    chooseText(kantoGame.stack, false)
    chooseText(kantoGame.stack, true)
    eq(kantoActive, false,
      label .. " confirmed Kanto path opens the 151 catalogue")
    eq(runState(kantoGame.save).partnerDexMax, 151,
      label .. " confirmed Kanto path fixes this choice at 151")
    eq(kantoGame.save.modData.kanto_ascendant.run_rules.poolDexMax, 151,
      label .. " confirmed Kanto path fixes the Randomizer at 151")

    local johtoGame = newGame(character)
    johtoGame.save.modData.kanto_ascendant.beyond_kanto = {
      version = 1, active = false, decision = "fresh_gen1",
    }
    local johtoActive
    starters.ensureLegacyBeyond(johtoGame, function(active)
      johtoActive = active
    end)
    chooseText(johtoGame.stack, true)
    local receipt = johtoGame.stack:pop()
    check(receipt and type(receipt.onDone) == "function",
      label .. " Johto YES leaves a readable A-gated receipt")
    twoLinePages(receipt.text, label .. " Johto activation receipt")
    receipt.onDone()
    eq(johtoActive, true,
      label .. " Johto YES opens the 251 catalogue after its receipt")
    eq(runState(johtoGame.save).partnerDexMax, 251,
      label .. " Johto YES fixes the partner boundary at 251")
    eq(johtoGame.save.modData.kanto_ascendant.run_rules.poolDexMax, 251,
      label .. " Johto YES fixes the Randomizer at 251")
    eq(mod.exports.runRules.livePoolMax, 251,
      label .. " Johto YES rebuilds the live Randomizer pool at 251")
  end
end
language = "en"

local malformedRules = newGame("RED")
malformedRules.save.modData.kanto_ascendant.beyond_kanto = {
  version = 1, active = false, decision = "fresh_gen1",
}
runState(malformedRules.save).pendingRunRules = { invalid = true }
local malformedReady
starters.ensureLegacyBeyond(malformedRules, function(active)
  malformedReady = active
end)
confirmKantoOnly(malformedRules.stack)
eq(malformedReady, nil,
  "malformed archived rules fail closed before partner selection")
eq(malformedRules.writeCount, 0,
  "malformed archived rules perform zero fresh-save writes")
eq(runState(malformedRules.save).partnerDexMax, nil,
  "malformed archived rules perform zero pool mutation")
eq(malformedRules.save.modData.kanto_ascendant.run_rules, nil,
  "malformed archived rules perform zero run-rule mutation")

local missingV7Rules = newGame("GREEN")
missingV7Rules.save.modData.kanto_ascendant.beyond_kanto = {
  version = 1, active = false, decision = "fresh_gen1",
}
runState(missingV7Rules.save).pendingRunRules = nil
runState(missingV7Rules.save).runRulesLegacyDefault = nil
local missingReady
starters.ensureLegacyBeyond(missingV7Rules, function(active)
  missingReady = active
end)
confirmKantoOnly(missingV7Rules.stack)
eq(missingReady, nil,
  "v7 target without a confirmed rules snapshot fails closed")
eq(missingV7Rules.writeCount, 0,
  "missing v7 rules perform zero fresh-save writes")
eq(runState(missingV7Rules.save).partnerDexMax, nil,
  "missing v7 rules cannot freeze or expose a partner pool")
eq(missingV7Rules.save.modData.kanto_ascendant.run_rules, nil,
  "missing v7 rules never silently become Randomizer/Nuzlocke OFF")

local migratedV6Rules = newGame("RED")
migratedV6Rules.save.modData.kanto_ascendant.beyond_kanto = {
  version = 1, active = false, decision = "fresh_gen1",
}
runState(migratedV6Rules.save).version = 6
runState(migratedV6Rules.save).pendingRunRules = nil
runState(migratedV6Rules.save).runRulesLegacyDefault = true
local migratedReady
starters.ensureLegacyBeyond(migratedV6Rules, function(active)
  migratedReady = active
end)
confirmKantoOnly(migratedV6Rules.stack)
eq(migratedReady, false,
  "only marker-authenticated v6 migration may derive deterministic OFF")
eq(migratedV6Rules.save.modData.kanto_ascendant.run_rules.seed, 650000,
  "authenticated v6 migration seeds its deterministic safe contract")

eq(starters.heroChoice(game.save).species, "TORCHIC",
  "Red's fixed left ball contains Torchic")
game.save.modData.kanto_ascendant.legacy_journey.avatar = "BLUE"
eq(starters.heroChoice(game.save).species, "MUDKIP",
  "Blue's fixed left ball contains Mudkip")
game.save.modData.kanto_ascendant.legacy_journey.avatar = "GREEN"
eq(starters.heroChoice(game.save).species, "TREECKO",
  "Green's fixed left ball contains Treecko")
for _, fixture in ipairs({
  { character = "RED", species = "TORCHIC", dex = 255 },
  { character = "BLUE", species = "MUDKIP", dex = 258 },
  { character = "GREEN", species = "TREECKO", dex = 252 },
}) do
  local heroGame = newGame(fixture.character)
  local species = starters.heroChoice(heroGame.save).species
  local path, trueColor, source = starters.crystalSpritePath(heroGame, species)
  check(species == fixture.species
      and path:find(("/front/normal/%d/001.png"):format(fixture.dex), 1, true),
    fixture.character .. " previews its fixed partner with Crystal frame one")
  eq(trueColor, true,
    fixture.character .. " fixed-partner preview remains true-colour")
  eq(source, "crystal",
    fixture.character .. " fixed-partner preview never uses generic Oak art")
end
language = "en"
eq(starters.typesLabel(pokemon.XATU), "PSYCHIC / FLYING",
  "the catalogue uses the merged English type display names")
language = "de"
eq(starters.typesLabel(pokemon.XATU), "PSYCHO / FLUG",
  "the catalogue uses the merged German type display names")
eq(starters.growthLabel({ growthRate = "SLOW" }), "LANGSAM / SCHWER",
  "growth and difficulty are localized together")
language = "en"

-- The left gift is visible but locked until this character's rift was sealed
-- in an earlier Legacy life.  Other characters' seals never cross-unlock it.
journey.completedPaths = { red = false, blue = true, green = true }
game = newGame("RED")
eq(starters.hoennUnlocked(game.save), false,
  "Blue and Green seals do not unlock Red's Hoenn ball")
local lockedGift, lockedWhy = starters.choose(
  game, "TORCHIC", "hoenn", "left", "hoenn_ball")
eq(lockedGift, false, "the Hoenn gift is unavailable before its rift seal")
eq(lockedWhy, "matching rift seal required",
  "the direct API reports the story gate")
journey.completedPaths.red = true
eq(starters.hoennUnlocked(game.save), true,
  "Red's completed rift unlocks only Red's Hoenn gift")
for _, row in ipairs({
  { avatar = "RED", key = "red" },
  { avatar = "BLUE", key = "blue" },
  { avatar = "GREEN", key = "green" },
}) do
  journey.completedPaths = { red = false, blue = false, green = false }
  local heroGame = newGame(row.avatar)
  eq(starters.hoennUnlocked(heroGame.save), false,
    row.avatar .. " remains locked before the matching rift")
  journey.completedPaths[row.key] = true
  eq(starters.hoennUnlocked(heroGame.save), true,
    row.avatar .. " unlocks after exactly the matching rift")
end
journey.completedPaths = { red = true, blue = false, green = false }

-- Successful choice: one party mon, one Dex row, one game save, then archive.
game = newGame("RED")
syncCount, rival.fail = 0, false
check(starters.labExitLocked(game.save),
  "R/B Lab exit is locked after rival claim but before partner choice")
local selected, mon = starters.choose(
  game, "TORCHIC", "hoenn", "left", "hoenn_ball")
check(selected, "the character-bound Hoenn partner commits")
eq(mon.species, "TORCHIC", "the committed party Pokémon is Torchic")
eq(mon.level, 5, "Oak's Legacy partner starts at level 5")
eq(mon.ot, "RED", "the partner receives the fresh-save OT")
eq(#game.save.party, 1, "the partner is added exactly once")
eq(game.writeCount, 1, "the complete player+rival state uses one game write")
eq(syncCount, 1, "archive mirroring occurs after the durable game write")
local committed = runState(game.save)
eq(committed.partnerMode, "hoenn", "the flat partner mode is persisted")
eq(committed.partnerSpecies, "TORCHIC", "the flat species is persisted")
eq(committed.partnerChosen, true, "the choice has a durable sentinel")
eq(committed.partnerBall, "left", "the physical left ball is recorded")
eq(committed.partnerChosenAtCycle, 2, "the choice records its Legacy cycle")
eq(committed.rivalPartner.sourcePartner, "TORCHIC",
  "the delayed rival line resolves before the same save")
eq(starters.labExitLocked(game.save), false,
  "R/B Lab exit unlocks only after partner and rival resolve together")
eq(game.save.flags.EVENT_CHOSE_CHARMANDER, true,
  "Red's authored lab branch remains the compatibility branch")
eq(game.save.pokedex.seen.TORCHIC, true,
  "only the selected partner becomes seen")
eq(game.save.pokedex.owned.TORCHIC, true,
  "only the selected partner becomes owned")
local seenCount = 0
for _ in pairs(game.save.pokedex.seen) do seenCount = seenCount + 1 end
eq(seenCount, 1, "the catalogue does not unlock unrelated Pokédex entries")
eq(starters.choose(game, "BULBASAUR", "free", "catalog", "catalog"), false,
  "a second choice is rejected")
eq(#game.save.party, 1, "retrying cannot duplicate the partner")

-- Rival resolution must happen before disk; failures fully restore staging.
game = newGame("RED")
game.save.pokedex.seen.RATTATA = true
syncCount, rival.fail = 0, true
local resolved, resolveErr = starters.choose(
  game, "TORCHIC", "hoenn", "left", "hoenn_ball")
eq(resolved, false, "a rival resolution failure aborts the choice")
check(tostring(resolveErr):find("forced rival", 1, true),
  "the resolver error reaches the selector")
eq(game.writeCount, 0, "no partial player-only state reaches disk")
eq(#game.save.party, 0, "the staged partner is removed after resolve failure")
eq(runState(game.save).partnerChosen, nil,
  "partner metadata rolls back after resolve failure")
eq(game.save.pokedex.seen.RATTATA, true,
  "pre-existing Dex state survives rollback")
eq(game.save.pokedex.seen.TORCHIC, nil,
  "the failed candidate leaves no Dex ownership")

game = newGame("RED")
eq(starters.choose(game, "ASCENDANT_TYPHLOSION", "free", "catalog",
  "catalog"), false,
  "the API rejects a form that merely shares a canonical Dex number")
eq(#game.save.party, 0, "a rejected form cannot enter the fresh-save party")

for _, species in ipairs({ "GENGAR", "PIKACHU", "TURTWIG" }) do
  game = newGame("RED")
  eq(starters.choose(game, species, "free", "catalog", "catalog"), false,
    "the API rejects direct non-allowlist choice " .. species)
  eq(#game.save.party, 0,
    "a rejected direct choice cannot add " .. species .. " to the party")
end
game = newGame("RED")
syncCount, rival.fail = 0, false
local baseChosen, baseMon = starters.choose(game, "GASTLY", "free",
  "catalog", "catalog")
check(baseChosen and baseMon.species == "GASTLY",
  "the API accepts an allowed base-stage Gastly")
game = newGame("RED")
local pichuChosen, pichuMon = starters.choose(game, "PICHU", "free",
  "catalog", "catalog")
check(pichuChosen and pichuMon.species == "PICHU",
  "the API accepts Pichu, the authoritative Pikachu-line base stage")

-- Capstone partner transaction: all identities share the same durable
-- three-path reward, every species retains its Crystal card and receives a
-- legal deterministic four-move level-5 kit. No local shadow/stone evidence
-- can bypass the archive profile.
local beforeCapstone = journey.completedPaths
journey.completedPaths = { red = true, blue = false, green = true }
local lockedLegend = newGame("GREEN")
runState(lockedLegend.save).completedPaths = {
  red = true, blue = true, green = true,
}
lockedLegend.save.inventory.BLAZIKENITE = 1
lockedLegend.save.inventory.SWAMPERTITE = 1
lockedLegend.save.inventory.SCEPTILITE = 1
local lockedChoice, lockedChoiceWhy = starters.choose(
  lockedLegend, "MEW", "free", "catalog", "catalog")
eq(lockedChoice, false,
  "two durable paths plus all three stones cannot choose Mew")
eq(lockedChoiceWhy, "all three durable Legacy paths are required",
  "locked direct choice reports the exact archive prerequisite")
eq(#lockedLegend.save.party, 0,
  "a locked mythical direct call cannot stage a party member")

journey.completedPaths = { red = true, blue = true, green = true }
rival.fail = false
local heroes = { "RED", "BLUE", "GREEN" }
for _, species in ipairs(starters.legendaryOrder) do
  local previewGame = newGame("RED")
  local preview, trueColor, source = starters.crystalSpritePath(
    previewGame, species)
  check(preview:find(("/front/normal/%d/001.png")
      :format(pokemon[species].dex), 1, true),
    species .. " uses its canonical Crystal front preview")
  eq(trueColor, true, species .. " Crystal preview remains true-colour")
  eq(source, "crystal", species .. " preview cannot fall back to generic art")

  local plan = starters.legendaryMoveSets[species]
  eq(#plan, 4, species .. " has exactly four authored Legacy start moves")
  for _, move in ipairs(plan) do
    check(starters.legalMoveSource(pokemon[species], move) ~= nil,
      species .. " start move " .. move .. " is in level/TM/tutor data")
  end
  local stab = starters.legendaryEarlyStab[species]
  check((moveDefs[stab].power or 0) > 0,
    species .. " has an immediately damaging STAB move")

  for _, hero in ipairs(heroes) do
    local eliteGame = newGame(hero)
    local chosen, elite = starters.choose(eliteGame, species, "free",
      "catalog", "catalog")
    check(chosen and elite and elite.level == 5,
      hero .. " can start with mastered capstone partner " .. species)
    eq(#elite.moves, 4,
      hero .. " receives " .. species .. " with four level-5 moves")
    for moveIndex, move in ipairs(plan) do
      eq(elite.moves[moveIndex].id, move,
        hero .. " / " .. species .. " retains deterministic move order")
      eq(elite.moves[moveIndex].pp, moveDefs[move].pp,
        hero .. " / " .. species .. " receives canonical base PP")
    end
    eq(starters.partner({ save = eliteGame.save }), elite,
      hero .. " / " .. species
        .. " remains the exact marked partner after a save reload")
  end
end

local capstoneRollback = newGame("BLUE")
capstoneRollback.writeFails = true
local capstoneSaved, capstoneSaveErr = starters.choose(capstoneRollback,
  "LUGIA", "free", "catalog", "catalog")
eq(capstoneSaved, false, "failed disk write aborts a legendary choice")
eq(capstoneSaveErr, "save failed",
  "legendary rollback surfaces the ordinary save error")
eq(#capstoneRollback.save.party, 0,
  "failed legendary write removes the staged level-5 partner")
eq(runState(capstoneRollback.save).partnerChosen, nil,
  "failed legendary write restores the run contract")
eq(capstoneRollback.save.pokedex.owned.LUGIA, nil,
  "failed legendary write restores Pokédex ownership")
capstoneRollback.writeFails = false
local retried, retriedLegend = starters.choose(capstoneRollback,
  "LUGIA", "free", "catalog", "catalog")
check(retried and retriedLegend.species == "LUGIA",
  "the same mastered archive can safely retry after rollback")
eq(#capstoneRollback.save.party, 1,
  "retry after failed legendary save creates exactly one partner")

local missingMove = moveDefs.RECOVER
moveDefs.RECOVER = nil
local illegalRegistry = newGame("RED")
local illegalChosen, illegalWhy = starters.choose(illegalRegistry,
  "MEWTWO", "free", "catalog", "catalog")
eq(illegalChosen, false,
  "a removed move registry entry fail-closes the capstone transaction")
check(tostring(illegalWhy):find("RECOVER", 1, true),
  "illegal capstone plan identifies the missing move")
eq(illegalRegistry.writeCount, 0,
  "illegal move plan never reaches the save transaction")
eq(#illegalRegistry.save.party, 0,
  "illegal move plan cannot stage a Pokémon")
moveDefs.RECOVER = missingMove
journey.completedPaths = beforeCapstone

game = newGame("RED")
game.writeFails, rival.fail, syncCount = true, false, 0
local saved, saveErr = starters.choose(
  game, "TORCHIC", "hoenn", "left", "hoenn_ball")
eq(saved, false, "a failed fresh-save write aborts the choice")
eq(saveErr, "save failed", "the selector reports the save failure")
eq(game.writeCount, 1, "the failed write is attempted exactly once")
eq(syncCount, 0, "archive state is never advanced before disk succeeds")
eq(#game.save.party, 0, "the staged partner rolls back after save failure")
eq(runState(game.save).rivalPartner, nil,
  "the staged rival line also rolls back after save failure")

-- The graphical carousel browses silently, switches filters, and confirms
-- twice with NO preselected before committing.
game = newGame("RED")
local chosenByController, cancelled = nil, false
local ctl = {
  onPartnerChosen = function(_, species, ball)
    chosenByController = species .. ":" .. ball
  end,
  onCatalogCancelled = function() cancelled = true end,
}
local catalog = starters.Catalog.new(game, ctl, {
  mode = "free", ball = "catalog", source = "catalog",
})
game.stack:push(catalog)
local beforeCry = cryCount
catalog:move(1)
eq(cryCount, beforeCry, "rapid carousel browsing never plays species cries")
check(browseSoundCount > 0, "carousel movement uses a short UI sound")
catalog.index = 71
check(catalog:toggleMode(), "SELECT switches between Free and Balanced")
eq(catalog.mode, "balanced", "the selected filter is visible in state")
catalog.mode = "free"
catalog.rows = starters.rows(game, "free")
catalog.index = 1
catalog:confirm()
local firstConfirm = game.stack:top()
eq(firstConfirm.defaultNo, true, "the first partner confirmation defaults NO")
chooseText(game.stack, true)
local finalConfirm = game.stack:top()
eq(finalConfirm.defaultNo, true, "the final irreversible confirmation defaults NO")
check(finalConfirm.text:find("FINAL BULBASAUR", 1, true),
  "the second confirmation clearly identifies the irreversible choice")
chooseText(game.stack, true)
eq(chosenByController, "BULBASAUR:catalog",
  "the graphical catalogue commits through its controller")
eq(runState(game.save).partnerMode, "free",
  "the chosen catalogue filter is part of the save contract")

-- Real R/B map seam: ordinary saves delegate; active NG+ claims right early.
local ordinaryCalls, enterCalls, doneCalls = 0, 0, 0
local authoredRivalStep = false
local scripts = {
  talk = {
    TEXT_OAKSLAB_CHARMANDER_POKE_BALL = function(_, _, _, done)
      ordinaryCalls = ordinaryCalls + 1 if done then done() end
    end,
    TEXT_OAKSLAB_SQUIRTLE_POKE_BALL = function(_, _, _, done)
      ordinaryCalls = ordinaryCalls + 1 if done then done() end
    end,
    TEXT_OAKSLAB_BULBASAUR_POKE_BALL = function(_, _, _, done)
      ordinaryCalls = ordinaryCalls + 1 if done then done() end
    end,
  },
  onEnter = function() enterCalls = enterCalls + 1 end,
  onStep = function(activeGame, activeOw)
    if not authoredRivalStep then return false end
    activeOw.runner:run({
      { "start_battle", "trainer", "OPP_RIVAL1", 1 },
      { "set_flag", "EVENT_BATTLED_RIVAL_IN_OAKS_LAB" },
      { "show_text", "RIVAL_EXIT" },
    }, { onDone = function() activeGame.authoredRivalDone = true end })
    return true
  end,
}
local mapScripts = { get = function(map) return map == "OAKS_LAB" and scripts end }
local ow = { runner = { calls = {} } }
function ow.runner:run(rows, options)
  self.calls[#self.calls + 1] = rows
  for _, row in ipairs(rows or {}) do
    if row[1] == "hide_object" then
      game.save.objectToggles[row[2]] = game.save.objectToggles[row[2]] or {}
      game.save.objectToggles[row[2]][row[3]] = false
    elseif row[1] == "set_flag" then
      game.save.flags[row[2]] = true
    end
  end
  if options and options.onDone then options.onDone() end
end

game = newGame("RED")
runState(game.save).rivalBallTaken = nil
game.save.flags.KA_LEGACY_RIVAL_BALL_TAKEN = nil
check(starters.install(game, { mapScripts = mapScripts }),
  "the adapter installs through the real map-script table shape")
eq(rival.bound, game, "the rival resolver is bound before Oak's selection")
eq(scripts.onStep(game, ow, 5, 6), true,
  "R/B's Lab exit is intercepted before the rival claim and partner")
eq(ow.runner.calls[1][1][2], "_KantoAscendantLegacyLabLocked",
  "Oak explicitly blocks the unfinished R/B Lab exit")
eq(runState(game.save).rivalBallTaken, nil,
  "the R/B exit blocker cannot advance the rival claim")
scripts.onEnter(game, ow)
eq(enterCalls, 1, "the authored Oak onEnter still runs")
eq(runState(game.save).rivalBallTaken, true,
  "the rival claims the right ball on first eligible lab entry")
eq(game.save.objectToggles.OAKS_LAB.OAKSLAB_BULBASAUR_POKE_BALL, false,
  "the right rival ball is visibly gone before the player chooses")
local claimWrites = game.writeCount
scripts.onEnter(game, ow)
eq(game.writeCount, claimWrites,
  "the early rival claim is idempotent across repeated onEnter calls")
eq(runState(game.save).rivalPartner, nil,
  "claiming the physical rival ball does not resolve its species early")

-- Fresh Legacy starts inside the Lab.  Even if the imported Lab onStep owns
-- the first post-selector cell, the rival claim must win that boundary rather
-- than disappearing behind the vanilla handler.
local stepPriority = newGame("RED")
runState(stepPriority.save).rivalBallTaken = nil
stepPriority.save.flags.KA_LEGACY_RIVAL_BALL_TAKEN = nil
game = stepPriority
local oldOnStep = scripts.onStep
scripts.onStep = function() return true end
check(starters.install(stepPriority, { mapScripts = mapScripts }),
  "the first-step priority fixture re-installs the ordinary lab seam")
ow.runner.calls = {}
eq(scripts.onStep(stepPriority, ow, 5, 5), true,
  "the first Fresh-Lab step is consumed by the rival claim")
eq(runState(stepPriority.save).rivalBallTaken, true,
  "the rival claim precedes an authored onStep that also returns true")
eq(#ow.runner.calls, 1,
  "the priority boundary starts exactly one rival animation")
scripts.onStep = oldOnStep

-- A failed early right-ball save must leave the whole scene untouched.  The
-- same map hook is then the retry path; animation and object hiding start
-- only after the retry becomes durable.
local failedClaim = newGame("RED")
runState(failedClaim.save).rivalBallTaken = nil
failedClaim.save.flags.KA_LEGACY_RIVAL_BALL_TAKEN = nil
failedClaim.writeFails = true
game = failedClaim
check(starters.install(failedClaim, { mapScripts = mapScripts }),
  "the retry fixture re-installs the ordinary lab seam")
ow.runner.calls = {}
scripts.onEnter(failedClaim, ow)
eq(failedClaim.writeCount, 1, "failed early rival claim attempts one write")
eq(runState(failedClaim.save).rivalBallTaken, nil,
  "failed early rival claim rolls back its status")
eq(failedClaim.save.flags.KA_LEGACY_RIVAL_BALL_TAKEN, nil,
  "failed early rival claim rolls back its flag")
eq(#ow.runner.calls, 0,
  "failed early rival claim never starts the rival animation")
check(not (failedClaim.save.objectToggles.OAKS_LAB
    and failedClaim.save.objectToggles.OAKSLAB_BULBASAUR_POKE_BALL == false),
  "failed early rival claim never hides the physical ball")
failedClaim.writeFails = false
scripts.onEnter(failedClaim, ow)
eq(failedClaim.writeCount, 2, "the next lab entry retries the rival claim")
eq(runState(failedClaim.save).rivalBallTaken, true,
  "the successful retry records the rival claim")
eq(#ow.runner.calls, 1,
  "the successful retry starts exactly one rival animation")

-- Exercise the real R/B ball handler rather than only the exported helper:
-- every identity must see the default-NO boundary question before a
-- catalogue state exists, and declining must open only the Kanto rows.
for _, character in ipairs({ "RED", "BLUE", "GREEN" }) do
  local boundaryGame = newGame(character)
  boundaryGame.save.modData.kanto_ascendant.beyond_kanto = {
    version = 1, active = false, decision = "fresh_gen1",
  }
  runState(boundaryGame.save).partnerDexMax = nil
  game = boundaryGame
  scripts.talk.TEXT_OAKSLAB_SQUIRTLE_POKE_BALL(
    boundaryGame, ow, {}, function() end)
  local prompt = boundaryGame.stack:top()
  check(prompt and prompt.kind == "text" and prompt.defaultNo == true,
    character .. " sees default-NO Johto choice before a partner screen")
  eq(runState(boundaryGame.save).partnerChosen, nil,
    character .. " cannot consume a partner while the Johto prompt is open")
  chooseText(boundaryGame.stack, false)
  local safety = boundaryGame.stack:top()
  check(safety and safety.defaultNo == true,
    character .. " receives the second default-NO Kanto-only safety question")
  chooseText(boundaryGame.stack, true)
  eq(runState(boundaryGame.save).runRulesLocked, true,
    character .. " locks rules before the Kanto catalogue exists")
  eq(boundaryGame.save.modData.kanto_ascendant.run_rules.poolDexMax, 151,
    character .. " locks the Kanto Randomizer pool")
  local kantoCatalog = boundaryGame.stack:top()
  check(kantoCatalog and kantoCatalog.mode == "balanced",
    character .. " reaches Oak's catalogue only after answering the boundary")
  for _, row in ipairs(kantoCatalog.rows) do
    check(row.dex <= 151,
      character .. " default-NO catalogue remains inside #001-151")
  end

  local johtoGame = newGame(character)
  johtoGame.save.modData.kanto_ascendant.beyond_kanto = {
    version = 1, active = false, decision = "fresh_gen1",
  }
  runState(johtoGame.save).partnerDexMax = nil
  game = johtoGame
  scripts.talk.TEXT_OAKSLAB_SQUIRTLE_POKE_BALL(
    johtoGame, ow, {}, function() end)
  chooseText(johtoGame.stack, true)
  eq(runState(johtoGame.save).runRulesLocked, true,
    character .. " locks rules before the Johto receipt")
  eq(johtoGame.save.modData.kanto_ascendant.run_rules.poolDexMax, 251,
    character .. " locks the Johto Randomizer pool")
  local receipt = johtoGame.stack:pop()
  check(receipt and type(receipt.onDone) == "function",
    character .. " receives an A-gated Johto activation receipt")
  receipt.onDone()
  local johtoCatalog = johtoGame.stack:top()
  check(beyondKanto.isActive(johtoGame.save)
      and starters.partnerDexMax(johtoGame.save) == 251,
    character .. " activates the Driftglass boundary before its catalogue")
  check(johtoCatalog and johtoCatalog.mode == "balanced",
    character .. " opens the partner screen only after activation completes")
  check((function()
    for _, row in ipairs(johtoCatalog.rows or {}) do
      if row.id == "CHIKORITA" then return true end
    end
    return false
  end)(), character .. " sees #001-251 candidates after accepting Johto")
end
game = failedClaim

journey.completedPaths.red = false
scripts.talk.TEXT_OAKSLAB_CHARMANDER_POKE_BALL(
  game, ow, {}, function() doneCalls = doneCalls + 1 end)
local lockedBallText = game.stack:pop()
check(lockedBallText and lockedBallText.kind == "text"
    and lockedBallText.text:find("RED RIFT SEAL", 1, true)
    and lockedBallText.text:find("Perhaps in your\nnext life", 1, true),
  "the visible left ball gives Oak's English earlier-life seal hint")
language = "de"
scripts.talk.TEXT_OAKSLAB_CHARMANDER_POKE_BALL(
  game, ow, {}, function() doneCalls = doneCalls + 1 end)
lockedBallText = game.stack:pop()
check(lockedBallText and lockedBallText.text:find("rotem\nHöhlensiegel", 1, true)
    and lockedBallText.text:find("nächsten Leben", 1, true),
  "the left-ball story gate has a readable German next-life hint")
language = "en"
journey.completedPaths.red = true

scripts.talk.TEXT_OAKSLAB_CHARMANDER_POKE_BALL(
  game, ow, {}, function() doneCalls = doneCalls + 1 end)
local leftCatalog = game.stack:top()
eq(leftCatalog.mode, "hoenn", "the left ball opens the Hoenn preview")
eq(leftCatalog.modeLocked, true, "the fixed Hoenn ball cannot change filter")
eq(leftCatalog:current().id, "TORCHIC", "Red's left preview shows Torchic")
input.pressed = { b = true }
leftCatalog:update()
input.pressed = {}
eq(doneCalls, 1, "cancelling a ball preview releases the frozen NPC")

local ordinary = newGame("RED")
ordinary.save.modData = {}
scripts.talk.TEXT_OAKSLAB_CHARMANDER_POKE_BALL(
  ordinary, ow, {}, function() doneCalls = doneCalls + 1 end)
eq(ordinaryCalls, 1, "normal campaigns delegate to the authored ball handler")

-- Received names use localized species display names, never registry ids.
language = "de"
pokemon.TORCHIC.name = "FLEMMLI"
game = newGame("RED")
starters.refresh(game)
ow.runner.calls = {}
scripts.onEnter(game, ow)
scripts.talk.TEXT_OAKSLAB_CHARMANDER_POKE_BALL(game, ow, {}, function() end)
leftCatalog = game.stack:top()
leftCatalog:confirm()
chooseText(game.stack, true)
chooseText(game.stack, true)
local receivedRAM
for _, rows in ipairs(ow.runner.calls) do
  for _, row in ipairs(rows) do
    if row[1] == "show_text"
        and row[2] == "_KantoAscendantLegacyReceivedPartner" then
      receivedRAM = row[3] and row[3].RAM
    end
  end
end
eq(receivedRAM, "FLEMMLI",
  "the German received message substitutes the localized Hoenn name")
language = "en"
pokemon.TORCHIC.name = "TORCHIC"

-- Yellow: cancel leaves Eevee visible; catalogue commit hides it only after
-- the final confirmation; non-Pikachu postbattle rows suppress Pikachu beats.
local yellowTexts, yellowEvents = {}, {}
local yellowMod = {
  id = "kanto_ascendant", content = { text = {} }, events = {},
  log = { warn = function() end, error = function() end },
  ui = { ListMenu = { new = function(_, title, rows, opts)
    return { title = title, items = rows, opts = opts }
  end } },
}
function yellowMod.content.text:register(id, value) yellowTexts[id] = value end
function yellowMod.events:on(name, fn)
  yellowEvents[name] = yellowEvents[name] or {}
  yellowEvents[name][#yellowEvents[name] + 1] = fn
end
local yellowStarters = createStarters(yellowMod, {
  journey = journey, hoenn = {}, johto = johto, rival = rival, i18n = i18n,
})
local yellowOriginalCalls, yellowStepRows = 0, nil
local yellowScripts = {
  talk = {
    TEXT_OAKSLAB_OAK1 = function(_, _, _, done)
      if done then done() end
    end,
    TEXT_OAKSLAB_EEVEE_POKE_BALL = function(activeGame, _, _, done)
      yellowOriginalCalls = yellowOriginalCalls + 1
      activeGame.save.party[#activeGame.save.party + 1] = {
        species = "PIKACHU", level = 5,
      }
      activeGame.save.flags.EVENT_GOT_STARTER = true
      activeGame.save.flags.EVENT_CHOSE_PIKACHU = true
      if done then done() end
    end,
  },
  onStep = function(_, activeOw)
    activeOw.runner:run({
      { "play_cry", "PIKACHU" },
      { "show_text", "_OaksLabPikachuDislikesPokeballsText1" },
      { "show_text", "_OaksLabPikachuDislikesPokeballsText2" },
      { "show_text", "KEEP_THIS_ROW" },
    })
    return true
  end,
}
local yellowMapScripts = {
  get = function(map) return map == "OAKS_LAB" and yellowScripts end,
}
local yellowOw = { runner = {} }
function yellowOw.runner:run(rows, options)
  yellowStepRows = rows
  for _, row in ipairs(rows or {}) do
    if row[1] == "hide_object" then
      local save = yellowStarters.game.save
      save.objectToggles[row[2]] = save.objectToggles[row[2]] or {}
      save.objectToggles[row[2]][row[3]] = false
    end
  end
  if options and options.onDone then options.onDone() end
end

local function newYellowGame()
  local value = newGame("RED")
  runState(value.save).rivalBallTaken = nil
  value.save.flags.KA_LEGACY_RIVAL_BALL_TAKEN = nil
  value.save.objectToggles = {}
  yellowStarters.game = value
  return value
end

local function chooseYellowPath(gameNow, index)
  local menu = gameNow.stack:top()
  check(menu and menu.items and #menu.items == 3,
    "Oak's Yellow menu visibly offers exactly three partner paths")
  menu.opts.onChoose(menu.items[index])
  return gameNow.stack:top()
end

local yellowGame = newYellowGame()
check(yellowStarters.install(yellowGame, { mapScripts = yellowMapScripts }),
  "the dedicated Yellow lab seam installs")
local yellowDone = 0
yellowStepRows = nil
eq(yellowScripts.onStep(yellowGame, yellowOw, 5, 6), true,
  "Yellow's Lab exit is intercepted before the sole ball is claimed")
eq(yellowStepRows[1][2], "_KantoAscendantLegacyLabLocked",
  "Oak explicitly blocks the unfinished Yellow Lab exit")
eq(runState(yellowGame.save).rivalBallTaken, nil,
  "testing the locked exit cannot claim the rival ball")
yellowScripts.talk.TEXT_OAKSLAB_EEVEE_POKE_BALL(
  yellowGame, yellowOw, {}, function() yellowDone = yellowDone + 1 end)
local yellowMenu = yellowGame.stack:top()
eq(yellowMenu.items[1].value, "pikachu", "Pikachu special is Yellow path one")
eq(yellowMenu.items[2].value, "hoenn", "earned Hoenn is Yellow path two")
eq(yellowMenu.items[3].value, "catalog", "the reusable catalogue is Yellow path three")
eq(runState(yellowGame.save).rivalBallTaken, true,
  "Yellow's rival claim is durable before Oak offers the player a path")
eq(yellowGame.writeCount, 1,
  "the rival's one-ball claim is its own exact-once save boundary")
eq(yellowGame.save.objectToggles.OAKS_LAB.OAKSLAB_EEVEE_POKE_BALL, false,
  "the sole physical ball disappears when the rival takes it")
yellowGame.stack:pop()
yellowMenu.opts.onCancel()
eq(yellowDone, 1, "cancelling Oak's path menu releases the frozen NPC")
eq(#yellowGame.save.party, 0, "Yellow cancel gives no Pokémon")
yellowScripts.talk.TEXT_OAKSLAB_OAK1(
  yellowGame, yellowOw, {}, function() yellowDone = yellowDone + 1 end)
check(yellowGame.stack:top().items[1].value == "pikachu",
  "Oak personally reopens the path menu after cancel or reload")
yellowGame.stack:pop()

yellowGame = newYellowGame()
yellowStarters.refresh(yellowGame)
yellowStarters.game = yellowGame
yellowDone, yellowStepRows = 0, nil
yellowScripts.talk.TEXT_OAKSLAB_EEVEE_POKE_BALL(
  yellowGame, yellowOw, {}, function() yellowDone = yellowDone + 1 end)
local yellowCatalog = chooseYellowPath(yellowGame, 3)
eq(yellowCatalog.mode, "balanced", "Yellow's third path opens the catalogue")
local yellowCatalogHoenn = {}
for _, row in ipairs(yellowCatalog.rows) do
  if HOENN_CATALOG_IDS[row.id] then
    yellowCatalogHoenn[#yellowCatalogHoenn + 1] = row.id
  end
end
eq(table.concat(yellowCatalogHoenn, ","), "TORCHIC",
  "Yellow's graphical catalogue includes RED's durable Hoenn reward")
yellowCatalog:confirm()
chooseText(yellowGame.stack, true)
chooseText(yellowGame.stack, true)
eq(runState(yellowGame.save).partnerSpecies, "BULBASAUR",
  "Yellow can commit a non-Pikachu catalogue partner")
eq(runState(yellowGame.save).rivalBallTaken, true,
  "Yellow retains the already durable Eevee claim after partner commit")
eq(yellowGame.writeCount, 2,
  "Yellow saves one rival claim and one complete partner+rival resolution")
eq(yellowGame.save.objectToggles.OAKS_LAB.OAKSLAB_EEVEE_POKE_BALL, false,
  "the committed Yellow catalogue path hides Eevee's ball")
yellowScripts.onStep(yellowGame, yellowOw, 5, 6)
local kept, leakedPikachuBeat = false, false
for _, row in ipairs(yellowStepRows or {}) do
  if row[2] == "KEEP_THIS_ROW" then kept = true end
  if row[2] == "PIKACHU"
      or row[2] == "_OaksLabPikachuDislikesPokeballsText1"
      or row[2] == "_OaksLabPikachuDislikesPokeballsText2" then
    leakedPikachuBeat = true
  end
end
check(kept and not leakedPikachuBeat,
  "Yellow catalogue postbattle keeps story rows but removes Pikachu-only beats")

yellowGame = newYellowGame()
yellowStarters.refresh(yellowGame)
yellowStarters.game = yellowGame
yellowScripts.talk.TEXT_OAKSLAB_EEVEE_POKE_BALL(
  yellowGame, yellowOw, {}, function() end)
local yellowHoenn = chooseYellowPath(yellowGame, 2)
eq(yellowHoenn:current().id, "TORCHIC",
  "Yellow's earned Hoenn path offers the selected Red identity's Torchic")
yellowHoenn:confirm()
chooseText(yellowGame.stack, true)
chooseText(yellowGame.stack, true)
eq(runState(yellowGame.save).partnerMode, "hoenn",
  "Yellow persists the direct earned-Hoenn route distinctly")
check(yellowGame.save.party[1][yellowStarters.partnerMarker] == true
    and yellowStarters.partner(yellowGame) == yellowGame.save.party[1],
  "Yellow's non-Pikachu Legacy choice is durably identified for followers")
eq(yellowGame.save.flags.EVENT_CHOSE_PIKACHU, nil,
  "a Yellow Hoenn handoff never activates native Pikachu story ownership")

-- Pikachu is handed directly by Oak after the rival snatch; no second table
-- ball or delegation to the base give routine is introduced.
yellowGame = newYellowGame()
yellowStarters.refresh(yellowGame)
yellowStarters.game = yellowGame
yellowScripts.talk.TEXT_OAKSLAB_EEVEE_POKE_BALL(
  yellowGame, yellowOw, {}, function() end)
local yellowPikachu = chooseYellowPath(yellowGame, 1)
eq(yellowPikachu:current().id, "PIKACHU",
  "Oak's Yellow special path previews the direct Pikachu handoff")
yellowPikachu:confirm()
chooseText(yellowGame.stack, true)
chooseText(yellowGame.stack, true)
eq(yellowOriginalCalls, 0,
  "Legacy Yellow never invokes the base handler that would fake another ball")
eq(runState(yellowGame.save).partnerSpecies, "PIKACHU",
  "Oak's direct Pikachu is persisted in the Legacy partner schema")
eq(runState(yellowGame.save).partnerMode, "yellow",
  "Pikachu retains an explicit Yellow partner mode")
check(yellowGame.save.party[1][yellowStarters.partnerMarker] == true
    and yellowStarters.partner(yellowGame) == yellowGame.save.party[1],
  "Yellow's Pikachu choice shares the durable Legacy follower identity")
eq(runState(yellowGame.save).rivalBallTaken, true,
  "the authored Eevee snatch remains paired with Pikachu's commit")
eq(yellowGame.save.flags.EVENT_CHOSE_PIKACHU, true,
  "only the actual Pikachu special sets Yellow's Pikachu branch")
eq(yellowStarters.labExitLocked(yellowGame.save), false,
  "Yellow's Lab exit unlocks only after both partners are persisted")

-- A resolver failure rolls back only the direct player handoff. The rival's
-- previously durable one-ball claim remains and Oak can retry the menu.
yellowGame = newYellowGame()
yellowStarters.refresh(yellowGame)
yellowStarters.game = yellowGame
rival.fail = true
yellowScripts.talk.TEXT_OAKSLAB_EEVEE_POKE_BALL(
  yellowGame, yellowOw, {}, function() end)
yellowPikachu = chooseYellowPath(yellowGame, 1)
yellowPikachu:confirm()
chooseText(yellowGame.stack, true)
chooseText(yellowGame.stack, true)
eq(runState(yellowGame.save).partnerChosen, nil,
  "Yellow resolver failure rolls back partial Legacy metadata")
eq(runState(yellowGame.save).rivalBallTaken, true,
  "resolver failure preserves the earlier durable rival claim")
eq(#yellowGame.save.party, 0,
  "resolver failure removes the uncommitted direct Pikachu")
rival.fail = false
yellowScripts.talk.TEXT_OAKSLAB_OAK1(yellowGame, yellowOw, {}, function() end)
check(yellowGame.stack:top().items[1].value == "pikachu",
  "Oak offers a clean retry after resolver rollback")
yellowGame.stack:pop()

yellowGame = newYellowGame()
yellowStarters.refresh(yellowGame)
yellowStarters.game = yellowGame
yellowScripts.talk.TEXT_OAKSLAB_EEVEE_POKE_BALL(
  yellowGame, yellowOw, {}, function() end)
yellowPikachu = chooseYellowPath(yellowGame, 1)
yellowGame.writeFails = true
yellowPikachu:confirm()
chooseText(yellowGame.stack, true)
chooseText(yellowGame.stack, true)
eq(yellowGame.writeCount, 2,
  "Yellow attempts a separate complete partner save after the rival claim")
eq(runState(yellowGame.save).partnerChosen, nil,
  "Yellow save failure rolls back partial Legacy metadata")
eq(runState(yellowGame.save).rivalPartner, nil,
  "Yellow save failure rolls back its staged rival line")
eq(runState(yellowGame.save).rivalBallTaken, true,
  "partner save failure never rewinds the rival's prior durable claim")
eq(#yellowGame.save.party, 0,
  "Yellow save rollback removes the uncommitted direct Pikachu")

-- The exact authored Lab runner boundary restores the archived title after
-- the rival exit sequence for every identity. It must not wait for a later
-- physical step.
for _, character in ipairs({ "RED", "BLUE", "GREEN" }) do
  game = newGame(character)
  runState(game.save).partnerChosen = true
  runState(game.save).rivalBallTaken = true
  runState(game.save).rivalPartner = { base = "SQUIRTLE" }
  game.save.flags.EVENT_GOT_STARTER = true
  game.save.flags.EVENT_BATTLED_RIVAL_IN_OAKS_LAB = nil
  starters.refresh(game)
  authoredRivalStep = true
  labRivalReceipts = 0
  eq(scripts.onStep(game, ow, 5, 6), true,
    character .. " keeps the authored first rival battle on the Lab exit")
  eq(labRivalReceipts, 1,
    character .. " restores the title at rival-script completion")
  check(game.titleRestoredAtRivalBoundary and game.authoredRivalDone,
    character .. " restores the title before the Lab callback completes")
end
authoredRivalStep = false

check(type(registeredText._KantoAscendantLegacyReceivedPartner) == "string",
  "the received-partner text is registered before content freeze")

print(("LEGACY PARTNER CATALOG PASS: %d assertions"):format(assertions))
