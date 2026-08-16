-- Authority integration proof for the post-prototype Hidden Evolution maps.
-- Run from gen1recomp with KA_HIDDEN_EVOLUTION_MOD set to this worktree.
package.path = "./?.lua;./?/init.lua;" .. package.path

local T = require("tests.modkit")
-- Use the engine's generated data: the compact SDK fixture deliberately does
-- not carry native CAVERN, so it cannot validate an Escape-Rope-safe cave.
local Data = require("src.core.Data")
Data:load()
local root = assert(os.getenv("KA_HIDDEN_EVOLUTION_MOD"),
  "KA_HIDDEN_EVOLUTION_MOD is required")
local sdkRoot = root:sub(1, 1) == "/" and "/" or "."
local run = T.sdk.loadMod(root, { data = Data, root = sdkRoot })
T.eq(#run.errors, 0, "Authority main.lua loads Hidden Evolution")

local exports = run.loader.exports.kanto_ascendant
local campaign = assert(exports.hiddenEvolutionCampaign,
  "Authority exports the integrated campaign controller")
local packages = assert(exports.hevoPackages,
  "Authority exports the integrated HEVO package runtime")
T.eq(#packages.order, 15, "main loads exactly fifteen HEVO packages")
T.eq(packages.audit.registeredTargets, 17,
  "main loads exactly seventeen HEVO evolution targets")
T.eq(#packages.byCharacter.RED, 5, "main loads five RED packages")
T.eq(#packages.byCharacter.BLUE, 5, "main loads five BLUE packages")
T.eq(#packages.byCharacter.GREEN, 5, "main loads five GREEN packages")
local function targetCount(character)
  local count = 0
  for _, package in ipairs(packages.byCharacter[character]) do
    count = count + #package.targets
  end
  return count
end
T.eq(targetCount("RED"), 5, "RED's five packages expose five target species")
T.eq(targetCount("BLUE"), 5, "BLUE's five packages expose five target species")
T.eq(targetCount("GREEN"), 7, "GREEN's five packages expose seven target species")
for _, itemId in ipairs({ "PROTECTOR", "MAGMARIZER", "RAZOR_FANG",
    "ELECTIRIZER", "RAZOR_CLAW", "DUBIOUS_DISC", "SHINY_STONE",
    "DUSK_STONE" }) do
  local item = assert(Data.items[itemId], "main did not register " .. itemId)
  T.eq(item.effect, packages.ITEM_EFFECT,
    itemId .. " uses the generic package item effect")
  T.eq(item.needsTarget, true, itemId .. " opens the party picker")
  T.eq(item.lootExcluded, true, itemId .. " is excluded from random loot")
  T.eq(item.progressionItem, true, itemId .. " is progression metadata")
end
T.check(Data.item_effects[packages.ITEM_EFFECT] ~= nil,
  "main merges the generic HEVO item effect")
T.eq(Data.item_effects[packages.ITEM_EFFECT].callStyle, "legacyArgs",
  "HEVO item effect explicitly declares its positional compatibility ABI")
T.check(exports.ngplusLegacyWorkshop ~= nil
    and Data.maps.KA_NGPLUS_LEGACY_WORKSHOP.index == 1970,
  "main registers the repeatable Legacy Workshop on its stable map index")
local workshop = exports.ngplusLegacyWorkshop
local workshopBalls = {
  RED = { "HEAVY_BALL", "LEVEL_BALL" },
  BLUE = { "LURE_BALL", "FAST_BALL" },
  GREEN = { "FRIEND_BALL", "LOVE_BALL", "MOON_BALL" },
}
for _, plan in ipairs(workshop.PLAN_ORDER) do
  T.eq(#plan.packages, 5,
    plan.character .. " Workshop plan references five live HEVO packages")
  T.eq(#plan.balls, #workshopBalls[plan.character],
    plan.character .. " Workshop plan has the authored Ball count")
  for index, itemId in ipairs(workshopBalls[plan.character]) do
    T.eq(plan.balls[index], itemId,
      plan.character .. " Workshop Ball order is authoritative")
    T.check(Data.items[itemId] and Data.items[itemId].ball == itemId,
      itemId .. " Workshop plan resolves to the live Apricorn item")
    T.eq(Data.items[itemId].price, workshop.BALL_PRICE,
      itemId .. " Workshop price matches the live item economy")
  end
end
T.eq(workshop.BALL_INDEX.GS_BALL, nil,
  "full main runtime excludes GS Ball from the Workshop")
local redBallOffers = workshop.ballOffers({
  completedPaths = { red = true, blue = false, green = false },
})
T.eq(#redBallOffers, 2,
  "full main runtime opens only Heavy/Level for a RED-only profile")
T.eq(redBallOffers[1].item, "HEAVY_BALL",
  "full main runtime preserves RED's first Ball plan")
T.eq(redBallOffers[2].item, "LEVEL_BALL",
  "full main runtime preserves RED's second Ball plan")
local runtimeSave = {
  player = { name = "RED" }, flags = {}, inventory = {
    PROTECTOR = 1, ELECTIRIZER = 1,
  }, bagOrder = { "PROTECTOR", "ELECTIRIZER" },
  party = {
    { species = "LICKITUNG", level = 30, moves = {} },
    { species = "ELECTABUZZ", level = 30, moves = {} },
  }, modData = { kanto_ascendant = { extended_characters = {
    player_character = "RED",
  }, hevo_persistent = { packageUnlocks = {
    protector = true, rollout_knowledge = true, electirizer = true,
  } } } },
}
packages.reconcile(runtimeSave)
local itemResult, _, itemExtra = require("src.inventory.ItemEffects").use(
  Data, runtimeSave, "PROTECTOR", { species = "RHYDON", moves = {} })
T.eq(itemResult, "consumed",
  "the merged main data dispatches a real HEVO target item")
T.eq(itemExtra and itemExtra.evolveTo, "RHYPERIOR",
  "the merged target item resolves the registry-authored evolution")
local reminder = exports.fieldTech.reminderMoves({ data = Data,
  save = runtimeSave }, runtimeSave.party[1])
local foundRollout = false
for _, row in ipairs(reminder) do
  if row.id == "ROLLOUT" then foundRollout = true break end
end
T.check(foundRollout,
  "main wires unlocked knowledge into the real Route 5 Reminder")
local daycareRows = exports.daycare.evolutionChoices({
  data = Data, save = runtimeSave,
})
local foundElectirizer = false
for _, row in ipairs(daycareRows) do
  if row.hevo and row.hevo.package.id == "electirizer"
      and row.evo.species == "ELECTIVIRE" then
    foundElectirizer = true break
  end
end
T.check(foundElectirizer,
  "main wires the same item eligibility into the Route 5 Day-Care machine")
T.check(campaign.validateNoPrototypeFallback(),
  "Authority never falls back to retired prototype IDs")
local expected = {
  "KA_HEVO_TUNNEL_ALL",
  "KA_HEVO_RED_UPPER", "KA_HEVO_RED_ABYSS", "KA_HEVO_RED_RECOVERY",
  "KA_HEVO_RED_LOWER", "KA_HEVO_RED_SHRINE",
  "KA_HEVO_BLUE_FROST_THRESHOLD", "KA_HEVO_BLUE_FROST_HALL", "KA_HEVO_BLUE_GLACIER_MAZE",
  "KA_HEVO_BLUE_TIDAL_DEPTHS", "KA_HEVO_BLUE_KYOGRE_SHRINE",
  "KA_HEVO_SHARED_SEALED_ANTECHAMBER",
  "KA_HEVO_GREEN_THRESHOLD", "KA_HEVO_GREEN_GROVE", "KA_HEVO_GREEN_MIST",
  "KA_HEVO_GREEN_RAYQUAZA_SHRINE",
}
local RuntimeMap = require("src.world.Map")
local cavernLadderCells = {
  [61]={{1,1}}, [62]={{1,1}}, [97]={{1,0}}, [98]={{1,1}},
  [124]={{1,1}}, [127]={{0,1}},
}
local nativeTilesets = {
  KA_HEVO_GREEN_THRESHOLD = "FOREST", KA_HEVO_GREEN_GROVE = "FOREST",
  KA_HEVO_GREEN_MIST = "FOREST", KA_HEVO_GREEN_RAYQUAZA_SHRINE = "FOREST",
}
for _, id in ipairs(expected) do
  local map = assert(Data.maps[id], "Authority did not load map " .. id)
  T.eq(map.tileset, nativeTilesets[id] or "CAVERN", id .. " uses a native Gen-I terrain tileset")
  T.eq(map.voxelMode, "FULL", id .. " uses the native DRAMALESS voxel profile")
  T.eq(map.voxelCells, nil, id .. " must not carry a private positional voxel carpet")
  T.eq(map.outdoor, false, id .. " is not globally flyable")
  T.eq(Data.audio.mapSongs[id], "Music_KA_DeepEvolution",
    id .. " owns the dungeon score and cannot inherit route music")
  -- The native CAVERN atlas contains six block variants whose artwork is
  -- unmistakably a ladder.  Every visible ladder cell in every authored
  -- CAVERN trial/shared map must therefore own a real declared warp; this is
  -- the inverse of merely checking that declared warps use a trigger tile.
  if map.tileset == "CAVERN" then
    local runtime = RuntimeMap.new(map, Data.tilesets.CAVERN)
    for by=0,map.height-1 do for bx=0,map.width-1 do
      local block = map.blocks[by*map.width+bx+1]
      for _,cell in ipairs(cavernLadderCells[block] or {}) do
        local x,y=bx*2+cell[1],by*2+cell[2]
        T.check(runtime:warpAtCell(x,y) ~= nil,
          id .. " visible ladder at " .. x .. "," .. y .. " is functional")
      end
    end end
  end
end
T.eq(Data.maps.KA_HEVO_TUNNEL_ALL.layoutHash, "hevo-a-0b71",
  "Authority loads the accepted three-shaft user layout")
T.eq(#Data.maps.KA_HEVO_TUNNEL_ALL.warps, 6,
  "shared tunnel exposes three route exits and three trial entrances")
T.eq(Data.maps.KA_HEVO_TUNNEL_RED, nil,
  "Authority no longer registers RED's duplicate tunnel map")
T.eq(Data.maps.KA_HEVO_TUNNEL_BLUE, nil,
  "Authority no longer registers BLUE's duplicate tunnel map")
T.eq(Data.maps.KA_HEVO_TUNNEL_GREEN, nil,
  "Authority no longer registers GREEN's duplicate tunnel map")
for _, key in ipairs({ "RED", "BLUE", "GREEN" }) do
  local site = campaign.modules.tunnel.sites[key]
  T.eq(site.tunnel, "KA_HEVO_TUNNEL_ALL",
    key .. " is routed through the shared tunnel")
  local raw = { player = { map = site.legacyTunnel, x = 1, y = 1,
    facing = "left", surfing = true } }
  local changed, who = campaign.modules.tunnel.migrateSaveLocation(raw)
  T.check(changed and who == key and raw.player.map == "KA_HEVO_TUNNEL_ALL"
      and raw.player.x == site.branch.entry.x and raw.player.y == site.branch.entry.y
      and raw.player.surfing == false,
    key .. " old tunnel save migrates to its isolated shared shaft")
end
T.check(Data.maps.KA_HEVO_BLUE_FROST_HALL.tileset == "CAVERN"
    and Data.maps.KA_HEVO_GREEN_GROVE.tileset == "FOREST"
    and Data.maps.KA_HEVO_SHARED_SEALED_ANTECHAMBER.tileset == "CAVERN",
  "BLUE, GREEN and shared terrain use their native Kanto profiles")
T.eq(Data.tilesets.KA_HEVO_G2_ICE_PATH, nil,
  "retired Johto Ice Path tileset is not loaded into the RC")
T.eq(Data.tilesets.KA_HEVO_G2_FOREST, nil,
  "retired Johto Forest tileset is not loaded into the RC")
local transformFile = assert(io.open(root .. "/shiny_transforms.lua", "rb"))
local transform = transformFile:read("*a")
transformFile:close()
T.check(transform:find("hidden_evolution/sealed_future_door.png", 1, true) ~= nil
    and transform:find("hidden_evolution/sealed_fissure.png", 1, true) ~= nil
    and transform:find("canAuthorImages", 1, true) ~= nil
    and transform:find("ctx.writeImage(relic", 1, true) ~= nil
    and transform:find("local doorPalette", 1, true) ~= nil
    and transform:find('{ 7, 7, "red" }', 1, true) ~= nil
    and transform:find('{ 6, 8, "blue" }', 1, true) ~= nil
    and transform:find('{ 8, 8, "green" }', 1, true) ~= nil
    and transform:find("ctx.blit(door, cavern", 1, true) == nil,
  "HEVO field art keeps transparent rune/fissure and authored tri-seal door recipes")
T.eq(campaign.fieldPolicy(nil, "FLY", "KA_HEVO_RED_UPPER").allowFlyInside,
  true, "HEVO provides the narrow indoor-FLY allowlist")
T.eq(campaign.fieldPolicy(nil, "FLASH", "KA_HEVO_RED_UPPER").blockFlash,
  true, "RED FLASH is hard-blocked")
T.eq(campaign.fieldPolicy(nil, "FLASH", "KA_HEVO_RED_UPPER").flashBlockReason,
  "darkness", "RED FLASH uses the darkness feedback")
T.eq(campaign.fieldPolicy(nil, "FLASH", "KA_HEVO_BLUE_GLACIER_MAZE").flashBlockReason,
  "darkness", "BLUE FLASH cannot bypass the ice-darkness trial")
T.eq(campaign.fieldPolicy(nil, "FLASH", "KA_HEVO_GREEN_MIST").flashBlockReason,
  "mist", "GREEN FLASH cannot bypass the authored mist")
T.eq(campaign.fieldPolicy(nil, "FLASH", "KA_HEVO_SHARED_SEALED_ANTECHAMBER"), nil,
  "FLASH resistance stays scoped to the three visibility trials")
T.eq(campaign.fieldPolicy(nil, "FLY", "ROUTE_22"), nil,
  "FLY policy does not leak outside HEVO")
T.check(exports.legacyDungeonAdapter ~= nil,
  "campaign receives the established legacy adapter surface")
T.check(campaign.modules.shared.journey == exports.legacyJourney,
  "shared black door reaches the authoritative Legacy readiness/call gate")
T.check(exports.megaEvolution ~= nil,
  "campaign receives the existing Mega controller surface")
local oldEngineGame = { data = Data, save = {}, stack = {}, renderer = {} }
local OverworldState = require("src.world.OverworldController")
local currentDrawAtmosphere = OverworldState.drawAtmosphere
local inlineOk, inlineMode = campaign.runtimePreflight(oldEngineGame)
T.eq(inlineOk, true,
  "intermediate renderer remains a supported HEVO gameplay runtime")
T.eq(inlineMode, "atmosphere-fallback",
  "intermediate renderer selects the inline atmosphere presentation")
local overlayOk, overlayMode = campaign.runtimePreflight({ renderer = {
  queueWorldPostOverlay = function() return true end,
} })
T.eq(overlayOk, true,
  "current renderer remains a supported HEVO gameplay runtime")
T.eq(overlayMode, "world-post-overlay",
  "current renderer selects the final world-overlay presentation")
OverworldState.drawAtmosphere = nil -- exact released-0.1.83 capability shape
local preflightOk, preflightWhy = campaign.runtimePreflight(oldEngineGame)
T.eq(preflightOk, true,
  "released renderer remains a supported HEVO gameplay runtime")
T.eq(preflightWhy, "legacy-native-darkness",
  "preflight identifies released native-darkness presentation")
local installOk, installWhy = campaign.install(oldEngineGame)
T.eq(installOk, true,
  "released renderer installs the complete HEVO campaign")
T.eq(installWhy, "legacy-mod-world-mask",
  "install reports the truthful mod-owned released presentation mode")
T.eq(campaign.presentationMode, "legacy-mod-world-mask",
  "released runtime upgrades native darkness to the mod-owned world mask")
T.check(campaign.visibilityCompat and campaign.visibilityCompat.installed,
  "released runtime installs the final-world visibility compatibility adapter")
T.eq(campaign.modules.hints.installed, true,
  "post-Hall researcher listeners install without the overlay queue")
T.eq(campaign.modules.tunnel.installed, true,
  "fissure and shared-tunnel listeners install without the overlay queue")
T.eq(campaign.modules.BLUE.installed, true,
  "BLUE gameplay installs without a renderer assertion")
T.eq(campaign.encounters._installed, true,
  "dungeon encounters install without the overlay queue")
OverworldState.drawAtmosphere = currentDrawAtmosphere

run.release()
T.finish("hidden_evolution_campaign_authority_load_test")
