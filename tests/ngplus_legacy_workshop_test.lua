local root = assert(os.getenv("KA_NGPLUS_WORKSHOP_MOD"), "KA_NGPLUS_WORKSHOP_MOD required")
local make = assert(loadfile(root .. "/ngplus_legacy_workshop.lua"))()
local makePackages = assert(loadfile(root .. "/hevo_packages.lua"))()
local Data = require("src.core.Data"); Data:load()
local RuntimeMap = require("src.world.Map")
local Serializer = require("src.core.SaveSerializer")
local function yes(v, m) assert(v, m) end
local function eq(a, b, m) assert(a == b, m .. ": " .. tostring(a) .. " ~= " .. tostring(b)) end
local function registry()
  local r = { values = {} }
  function r:register(id, value) self.values[id] = value end
  function r:get(id) return self.values[id] end
  function r:patch(id, partial)
    local value = assert(self.values[id], "missing registry row " .. id)
    for key, update in pairs(partial) do
      if type(update) == "table" and type(update.__append) == "table" then
        value[key] = value[key] or {}
        for _, row in ipairs(update.__append) do value[key][#value[key] + 1] = row end
      else value[key] = update end
    end
  end
  return r
end
local maps, text, scripts, encounters = registry(), registry(), registry(), registry()
local sprites, mapSongs = registry(), registry()
local tilesets = registry()
do
  local facility = {}
  for key, value in pairs(Data.tilesets.FACILITY) do facility[key] = value end
  facility.blocks = {}
  for index, row in ipairs(Data.tilesets.FACILITY.blocks) do
    facility.blocks[index] = {}; for cell, tile in ipairs(row) do
      facility.blocks[index][cell] = tile
    end
  end
  tilesets.values.FACILITY = facility
end
local items, itemEffects, evolutionMethods = registry(), registry(), registry()
local saved, shown, german, lastMenu = {}, {}, false, nil
local runtimeProfile = {}
local mod = { id = "kanto_ascendant", path = root, exports = {}, save = { get = function(_, k) return saved[k] end, set = function(_, k, v) saved[k] = v end },
  ui = { KantoListMenu = { new = function(_, title, rows, options)
    lastMenu = { title = title, rows = rows, options = options, footer = "" }
    return lastMenu
  end } },
  content = { maps = maps, text = text, encounters = encounters, map_scripts = scripts,
    sprites = sprites, map_songs = mapSongs, tilesets = tilesets,
    items = items, item_effects = itemEffects, evolution_methods = evolutionMethods,
    text_pointers = { patch = function() end } } }
local packages = makePackages(mod, {
  i18n = { text = function(en, de) return german and de or en end },
})
local workshop = make(mod, { i18n = { text = function(en, de) return german and de or en end },
  packages = packages,
  legacyProfile = function() return runtimeProfile end,
  showText = function(_, message, done) shown[#shown + 1] = message; if done then done() end; return true end })
yes(workshop.register(), "isolated workshop registers")
local map = maps:get(workshop.ID)
eq(map.index, 1970, "workshop uses a distinct stable map ID/index")
eq(map.tileset, "FACILITY", "workshop uses native Kanto Facility composition")
eq(map.palette, "CELADON", "workshop uses the Celadon gallery palette")
eq(map.voxelMode, "MAP_STUDIO", "workshop enables voxel map studio")
eq(map.outdoor, false, "workshop is indoor")
eq(map.label, "LegacyWorkshop", "workshop never exposes a placeholder map name")
eq(map.warps[1].destMap, "CELADON_MANSION_3F",
  "workshop returns to the real Legacy Gallery hub")
eq(map.warps[1].x, workshop.EXIT.x, "return warp uses the authored exit cell")
local runtimeMap = RuntimeMap.new(map, tilesets:get("FACILITY"))
yes(runtimeMap:isWalkableCell(workshop.EXIT.x, workshop.EXIT.y)
    and runtimeMap:isWarpTileCell(workshop.EXIT.x, workshop.EXIT.y),
  "return warp sits on a real native Facility stair tile")
local distinct = {}; for _, block in ipairs(map.blocks) do distinct[block] = true end
local distinctCount = 0; for _ in pairs(distinct) do distinctCount = distinctCount + 1 end
yes(distinctCount >= 18, "workshop is a composed multi-room map, not a repeated block hall")
yes(workshop.FLOOR_BLOCK ~= 14,
  "workshop no longer uses native checker block 14 as its floor")
for _, block in ipairs(map.blocks) do
  yes(block ~= 14, "no rejected FACILITY checker block remains on the map")
  local cells = assert(tilesets:get("FACILITY").blocks[block + 1],
    "mapped Workshop block exists in the merged FACILITY tileset")
  for _, tile in ipairs(cells) do
    yes(tile ~= 1,
      "no Workshop wall, shelf, stair or floor block retains checker tile $01")
  end
end
local floor = tilesets:get("FACILITY").blocks[workshop.FLOOR_BLOCK + 1]
for _, tile in ipairs(floor) do
  eq(tile, 17, "custom Workshop floor uses only native solid FACILITY tile $11")
end
for _, object in ipairs(map.objects) do
  yes(runtimeMap:isWalkableCell(object.x, object.y),
    object.name .. " stands on a walkable landmark")
  yes(object.sprite ~= "SPRITE_POKE_BALL",
    object.name .. " is never a Poké Ball placeholder")
end
yes(sprites:get("SPRITE_KA_LEGACY_SEAL_LOCKED")
    and sprites:get("SPRITE_KA_LEGACY_SEAL_RED")
    and sprites:get("SPRITE_KA_LEGACY_SEAL_BLUE")
    and sprites:get("SPRITE_KA_LEGACY_SEAL_GREEN")
    and sprites:get("SPRITE_KA_LEGACY_LEDGER"),
  "workshop registers dedicated seal and Ledger art")
eq(mapSongs:get(workshop.ID), "Music_Celadon",
  "workshop uses the hub's native Celadon music")
eq(workshop.ANCHOR.auditedGalleryMapId, "CELADON_MANSION_3F",
  "workshop anchor names the real gallery map")
eq(workshop.ANCHOR.status, "CONNECTED", "physical gallery entrance is connected")

local expectedBalls = {
  RED = { "HEAVY_BALL", "LEVEL_BALL" },
  BLUE = { "LURE_BALL", "FAST_BALL" },
  GREEN = { "FRIEND_BALL", "LOVE_BALL", "MOON_BALL" },
}
local expectedTargets = { RED = 5, BLUE = 5, GREEN = 7 }
for _, plan in ipairs(workshop.PLAN_ORDER) do
  eq(#plan.packages, 5, plan.character .. " matrix owns five HEVO packages")
  eq(#plan.balls, #expectedBalls[plan.character],
    plan.character .. " matrix owns the exact ball-plan size")
  local targets = 0
  for _, package in ipairs(plan.packages) do targets = targets + #package.targets end
  eq(targets, expectedTargets[plan.character],
    plan.character .. " matrix owns the exact target count")
  for index, item in ipairs(expectedBalls[plan.character]) do
    eq(plan.balls[index], item, plan.character .. " ball order is authored")
    yes(workshop.BALL_INDEX[item] == plan, item .. " points back to one seal")
  end
end
eq(workshop.BALL_INDEX.GS_BALL, nil, "GS Ball is absent from the authority matrix")

local blank = workshop.ledger({ completedPaths = {}, discoveries = {} })
for _, row in ipairs(blank) do eq(row.label, "???", "locked ledger stays spoiler-safe") end
for _, seal in ipairs(workshop.sealDisplay({ completedPaths = {} })) do
  yes(seal.symbol and seal.text == "???" and not seal.unlocked, "visible seal uses symbol/form/text without color-only state")
end
local function visibleSealCount(paths)
  local visible, count = workshop.sealObjectVisibility({ completedPaths = paths }), 0
  for _, character in ipairs({ "RED", "BLUE", "GREEN" }) do
    local object = workshop.SEAL_OBJECTS[character]
    yes(visible[object.locked] ~= visible[object.unlocked],
      character .. " renders exactly one locked/unlocked state")
    if visible[object.unlocked] then count = count + 1 end
  end
  return count
end
eq(visibleSealCount({}), 0, "zero-path profile renders zero active seals")
eq(visibleSealCount({ red = true }), 1, "RED profile renders one active seal")
eq(visibleSealCount({ red = true, blue = true }), 2,
  "RED/BLUE profile renders two active seals")
eq(visibleSealCount({ red = true, blue = true, green = true }), 3,
  "completed profile renders all three active seals")

-- v1 only knew aggregate discovery switches. Migration preserves them, but
-- expands a secret only for seals that were genuinely earned.
saved[workshop.STATE] = { version = 1, seals = { red = true, blue = true },
  discoveries = { starter_lineage = true },
  landmarks = { ARCHIVE_PLINTH = true } }
local migrated = workshop.sync({ completedPaths = { red = true } })
eq(migrated.version, 3, "v1 workshop state migrates to v3")
yes(migrated.discoveries.starter_lineage_red,
  "v1 aggregate starter trace migrates for the earned RED seal")
yes(not migrated.discoveries.starter_lineage_blue,
  "v1 aggregate trace cannot leak BLUE's locked secret")
yes(not migrated.seals.blue,
  "authoritative path profile removes a stale local BLUE seal")
yes(migrated.landmarks.ARCHIVE_PLINTH, "v1 landmark survives migration")

saved[workshop.STATE] = nil
local profile = {
  completedPaths = { red = true, blue = true, green = false },
  discoveries = {},
  hevoPersistent = { permanentItems = {
    LEGACY_STARTER_TORCHIC = true, BLAZIKENITE = true,
    LEGACY_STARTER_MUDKIP = true,
  }, secretUnlocks = { RED = true } },
}
runtimeProfile = profile
local state, changed = workshop.sync(profile); yes(changed and state.seals.red and state.seals.blue, "path seals unlock idempotently")
local _, changedAgain = workshop.sync(profile); eq(changedAgain, false, "repeated sync does not rewrite unlock state")
eq(workshop.sealCount(profile), 2, "two visible seals are counted")
yes(not workshop.complete(profile), "two seals do not complete workshop")
local rows = workshop.ledger(profile); eq(#rows[1].evolution, 5, "RED ledger exposes five package targets");eq(#rows[2].evolution, 5, "BLUE ledger exposes five package targets")
eq(#rows[1].packages, 5, "RED ledger references the five authority packages")
eq(#rows[1].balls, 2, "RED ledger exposes Heavy and Level plans")
eq(rows[1].balls[1].item, "HEAVY_BALL", "RED first plan is Heavy Ball")
eq(rows[1].balls[2].item, "LEVEL_BALL", "RED second plan is Level Ball")
eq(#rows[2].balls, 2, "BLUE ledger exposes Lure and Fast plans")
eq(rows[3].label, "???", "GREEN plans remain hidden")
local seals = workshop.sealDisplay(profile)
yes(seals[1].form == "RED" and seals[1].symbol == "R" and seals[1].unlocked, "RED seal has form, symbol, and text state")
yes(seals[2].form == "BLUE" and seals[2].symbol == "B" and seals[2].unlocked, "BLUE seal has form, symbol, and text state")
yes(seals[3].form == "GREEN" and seals[3].symbol == "G" and not seals[3].unlocked, "GREEN seal remains visibly locked")
workshop.sealTalk("red", { save = profile }); yes(shown[#shown]:find("RED", 1, true), "seal pedestal exposes symbol/form/text state")
workshop.sealTalk("red", { save = { modData = {} } }); yes(shown[#shown]:find("RED", 1, true), "live game save resolves the separate Legacy profile")
yes(rows[4].visible and rows[5].visible,
  "real RED/BLUE permanent rewards reveal only their earned secret headings")
eq(rows[2].secrets[2].label, "???", "unfound BLUE Mega secret stays spoiler-safe")
eq(workshop.openDiscoveries(profile), 1,
  "only BLUE's available but unfound Mega trace is open")
eq(#workshop.ballOffers(profile), 4,
  "two earned seals expose exactly four repeatable Ball plans")
for _, offer in ipairs(workshop.ballOffers(profile)) do
  yes(offer.item ~= "GS_BALL" and offer.price == 1000 and offer.reusable,
    "Ball offer is economic, repeatable and never GS Ball")
end
local save = { money = 25000, inventory = {}, bagOrder = {}, flags = {}, modData = {
  kanto_ascendant = { hevo_persistent = { packageUnlocks = {
    protector = true, electirizer = true,
  } } },
} }
packages.reconcile(save)
local offers = workshop.offers(save)
eq(#offers, 2, "only unlocked consumable packages appear as offers")
for _, offer in ipairs(offers) do yes(offer.reusable and offer.price == 9800 and offer.runtimePurchase, "workshop offers are real repeatable purchases at the authored price") end
yes(not workshop.NO_RUNTIME_BALL_PURCHASE, "runtime item repurchase is enabled")
local game = { save = save, data = Data, writeSave = function() return true end }
yes(not workshop.purchase(game, "protector", false), "cancelled purchase is side-effect free")
eq(save.money, 25000, "cancel does not charge money")
yes(workshop.purchase(game, "protector", true), "unlocked item is purchased")
eq(save.money, 15200, "successful purchase charges exactly 9800")
eq(save.inventory.PROTECTOR, 1, "successful purchase grants the real item")
yes(workshop.purchase(game, "protector", true), "item can be reacquired repeatedly")
eq(save.inventory.PROTECTOR, 2, "repeat purchase adds another item")
eq(save.money, 5400, "repeat purchase charges exactly once")
yes(not workshop.purchase(game, "protector", true), "insufficient funds fail closed")
eq(save.inventory.PROTECTOR, 2, "failed purchase grants nothing")

-- The real Apricorn module owns these item records. This isolated test uses
-- an explicit dependency fixture; the full-mod test below verifies the live
-- records and ball callbacks.
for item in pairs(workshop.BALL_INDEX) do
  Data.items[item] = Data.items[item]
    or { id = item, name = item:gsub("_", " "), price = 1000, ball = item }
end
save.money = 3000
local beforeCancel = Serializer.encode(save)
yes(not workshop.purchaseBall(game, "HEAVY_BALL", false),
  "cancelled Ball plan is side-effect free")
eq(Serializer.encode(save), beforeCancel, "Ball cancel changes no save field")
local locked, lockedWhy = workshop.purchaseBall(game, "LOVE_BALL", true)
yes(not locked and lockedWhy == "locked", "GREEN Ball cannot cross-unlock")
local gs, gsWhy = workshop.purchaseBall(game, "GS_BALL", true)
yes(not gs and gsWhy == "gs-ball-excluded", "GS Ball is explicitly rejected")
yes(workshop.purchaseBall(game, "HEAVY_BALL", true),
  "earned RED plan purchases the real Heavy Ball")
eq(save.inventory.HEAVY_BALL, 1, "Heavy Ball reaches the normal Bag")
eq(save.money, 2000, "Heavy Ball costs the authored economic ¥1,000")
yes(workshop.purchaseBall(game, "HEAVY_BALL", true),
  "earned Ball plan is permanently repeatable")
eq(save.inventory.HEAVY_BALL, 2, "repeat purchase adds exactly one Ball")
eq(save.money, 1000, "repeat purchase charges exactly once")
local reloaded = Serializer.decode(Serializer.encode(save))
eq(reloaded.inventory.HEAVY_BALL, 2, "Ball stock survives Save/Reload")
eq(#workshop.ballOffers(reloaded), 4,
  "Ball plans rehydrate from the durable seal profile")
local newCycle = { money = 0, inventory = {}, bagOrder = {}, modData = {} }
eq(#workshop.ballOffers(newCycle), 4,
  "a Fresh Save/NG+ reconstructs Ball plans without local duplication")
eq(newCycle.inventory.HEAVY_BALL, nil,
  "plan persistence never grants an unpurchased Ball")

local failing = { save = save, data = Data, writeSave = function() return false end }
local beforeFail = Serializer.encode(save)
local failed, failWhy = workshop.purchaseBall(failing, "LEVEL_BALL", true)
yes(not failed and failWhy == "save", "failed save rejects Ball purchase")
eq(Serializer.encode(save), beforeFail,
  "failed Ball save rolls money and inventory back exactly")
local nilOrderSave = { money = 1000, inventory = {}, flags = {}, modData = {} }
local nilOrderGame = { save = nilOrderSave, data = Data,
  writeSave = function() return false end }
local nilOrderOk = workshop.purchaseBall(nilOrderGame, "HEAVY_BALL", true)
yes(not nilOrderOk and nilOrderSave.bagOrder == nil
    and next(nilOrderSave.inventory) == nil and nilOrderSave.money == 1000,
  "failed purchase preserves an older save's absent bagOrder exactly")

local shortcuts = workshop.resonanceShortcuts(profile); eq(#shortcuts, 2, "only completed path thresholds get resonance shortcuts")
for _, shortcut in ipairs(shortcuts) do
  yes(shortcut.requiresSolved and not shortcut.usable
      and shortcut.destination == nil,
    "shortcut contract exposes no teleport before a solved threshold")
end
local canRed, redWhy = workshop.canUseResonance(profile, "RED", {})
yes(not canRed and redWhy == "unsolved",
  "an unlocked seal cannot skip its unsolved puzzle")
yes(workshop.canUseResonance(profile, "RED", { solvedThresholds = {
  KA_HEVO_RED_UPPER = true,
} }), "a genuinely solved RED threshold may enable a future adapter")
local canGreen, greenWhy = workshop.canUseResonance(profile, "GREEN", {
  solvedThresholds = { KA_HEVO_GREEN_THRESHOLD = true },
})
yes(not canGreen and greenWhy == "locked",
  "a solved-looking flag cannot bypass GREEN's locked seal")
eq(workshop.resonanceStatus(profile, "RED", {}).state, "unsolved",
  "seal UI marks an earned but unsolved resonance threshold")
eq(workshop.resonanceStatus(profile, "RED", { solvedThresholds = {
  KA_HEVO_RED_UPPER = true,
} }).state, "ready", "seal UI marks only a genuinely solved threshold ready")
eq(workshop.resonanceStatus(profile, "GREEN", { solvedThresholds = {
  KA_HEVO_GREEN_THRESHOLD = true,
} }).state, "locked", "seal UI never visually cross-unlocks a path")

-- The real shortcut is a durable round trip, never a one-way debug teleport.
-- A normal threshold visit has no token and therefore remains untouched.
local resonanceMap = {
  id = "KA_HEVO_RED_UPPER", tileset = "CAVERN", width = 2, height = 2,
  borderBlock = 0, blocks = { 21, 21, 21, 21 }, objects = {},
  warps = { { x = 0, y = 0, destMap = "KA_HEVO_TUNNEL_ALL", destWarp = 1 } },
}
local resonanceData = { maps = { KA_HEVO_RED_UPPER = resonanceMap },
  tilesets = { CAVERN = Data.tilesets.CAVERN } }
local warps, writes = {}, 0
mod.world = { warpTo = function(_, mapId, x, y, facing)
  warps[#warps + 1] = { map = mapId, x = x, y = y, facing = facing }
  return true
end }
saved.extended_characters = { player_character = "RED" }
local resonanceGame = { save = { modData = {} }, data = resonanceData,
  writeSave = function() writes = writes + 1; return true end }
local redSolved = { solvedThresholds = { KA_HEVO_RED_UPPER = true } }
local noNormalReturn, noNormalWhy = workshop.returnFromResonance(
  resonanceGame, "KA_HEVO_RED_UPPER", 0, 0)
yes(not noNormalReturn and noNormalWhy == "inactive" and #warps == 0,
  "normal dungeon entry never gains a Workshop return or skips a puzzle")

resonanceGame.writeSave = function() writes = writes + 1; return false end
local noArm, noArmWhy = workshop.useResonance(resonanceGame, "RED", redSolved)
yes(not noArm and noArmWhy == "save" and workshop.resonanceReturnState() == nil
    and #warps == 0,
  "failed outward save arms no token and performs no warp")

resonanceGame.writeSave = function() writes = writes + 1; return true end
local outward, destination = workshop.useResonance(
  resonanceGame, "RED", redSolved)
yes(outward and destination.map == "KA_HEVO_RED_UPPER"
    and #warps == 1 and warps[1].map == "KA_HEVO_RED_UPPER",
  "solved RED seal uses the real threshold destination")
local returnToken = workshop.resonanceReturnState()
yes(returnToken and returnToken.version == 1
    and returnToken.character == "RED"
    and returnToken.sourceMap == workshop.ID
    and returnToken.threshold == "KA_HEVO_RED_UPPER",
  "return token is bound to character, Workshop source and threshold")

saved = Serializer.decode(Serializer.encode(saved))
yes(workshop.resonanceReturnState()
    and workshop.resonanceReturnState().character == "RED",
  "armed return survives Save/Reload")
mod.exports.hiddenEvolutionCampaign = { modules = {
  RED = { canEnterShrine = function() return true end },
} }
saved.extended_characters = { player_character = "BLUE" }
local crossReturn, crossWhy = workshop.returnFromResonance(
  resonanceGame, "KA_HEVO_RED_UPPER", 0, 0)
yes(not crossReturn and crossWhy == "character"
    and workshop.resonanceReturnState() ~= nil and #warps == 1,
  "a different character cannot consume or use RED's return")
saved.extended_characters.player_character = "RED"
local wrongCell, wrongCellWhy = workshop.returnFromResonance(
  resonanceGame, "KA_HEVO_RED_UPPER", 1, 0)
yes(not wrongCell and wrongCellWhy == "cell"
    and workshop.resonanceReturnState() ~= nil and #warps == 1,
  "return requires the exact authored threshold entrance cell")

resonanceGame.writeSave = function() writes = writes + 1; return false end
local failedReturn, failedReturnWhy = workshop.returnFromResonance(
  resonanceGame, "KA_HEVO_RED_UPPER", 0, 0)
yes(not failedReturn and failedReturnWhy == "save"
    and workshop.resonanceReturnState() ~= nil and #warps == 1,
  "failed return save keeps player and retryable token at the threshold")
resonanceGame.writeSave = function() writes = writes + 1; return true end
local returned, returnDestination = workshop.returnFromResonance(
  resonanceGame, "KA_HEVO_RED_UPPER", 0, 0)
yes(returned and returnDestination.map == workshop.ID
    and #warps == 2 and warps[2].map == workshop.ID
    and workshop.resonanceReturnState() == nil,
  "successful physical return consumes the token and lands in Map 1970")
local duplicateReturn, duplicateWhy = workshop.returnFromResonance(
  resonanceGame, "KA_HEVO_RED_UPPER", 0, 0)
yes(not duplicateReturn and duplicateWhy == "inactive" and #warps == 2,
  "consumed return is exact-once and cannot duplicate a warp")
yes(not workshop.discover("ARCHIVE_PLINTH"), "seal-landmark discovery is idempotent")
german = true; workshop.landmarkTalk("TRIUNE_DIAL", { save = profile }); yes(shown[#shown]:find("DREIKLANG", 1, true), "landmarks localize DE")
yes(workshop.ledgerText(profile):find("BALLPLÄNE", 1, true),
  "ledger summary localizes Ball plans in German")
local stack = { pushed = {} }
function stack:push(value) self.pushed[#self.pushed + 1] = value end
game.stack = stack
workshop.ledgerTalk(game)
yes(lastMenu and lastMenu.title:find("LEDGER", 1, true),
  "Map 1970 desk opens the real combined Ledger menu")
eq(lastMenu.rows[1].value.kind, "ledger",
  "Ledger menu begins with inspectable seal plans")
local menuHasHeavy, menuHasGs = false, false
for _, item in ipairs(lastMenu.rows) do
  menuHasHeavy = menuHasHeavy or item.label == "HEAVY BALL"
  menuHasGs = menuHasGs or item.label == "GS BALL"
end
yes(menuHasHeavy and not menuHasGs,
  "runtime Ledger menu contains unlocked Heavy Ball but excludes GS Ball")
lastMenu.options.onChoose(lastMenu.rows[2])
yes(shown[#shown]:find("LURE BALL", 1, true)
    and shown[#shown]:find("SPUR: ???", 1, true),
  "plan inspection lists Ball plans while keeping unfound traces hidden")

profile.completedPaths.green = true
profile.hevoPersistent.permanentItems.LEGACY_STARTER_TREECKO = true
profile.hevoPersistent.permanentItems.SCEPTILITE = true
profile.hevoPersistent.secretUnlocks.GREEN = true
yes(workshop.complete(profile), "three seals complete workshop")
local completed = workshop.ledger(profile); eq(#completed[3].evolution, 7, "GREEN seal exposes seven targets from five packages");yes(completed[5].visible, "discovered Mega secret reveals cleanly")
eq(#completed[3].balls, 3, "GREEN seal exposes Friend/Love/Moon plans")
eq(#workshop.ballOffers(profile), 7,
  "three permanent seals expose all seven and only seven Ball plans")
print("ngplus_legacy_workshop_test: PASS")
