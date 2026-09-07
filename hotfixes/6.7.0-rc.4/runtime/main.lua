-- Kanto Ascendant: talk to a trainer you have already beaten to get a
-- ranked rematch. Ordinary prize money remains intact; the bonus-reward
-- layer adds either an item or a separate money bonus after a victory.
-- with a line in its own voice, matched to the personality that class
-- shows in its regular dialogue.

local DEFAULT_MIN_REST_STEPS = 151
local DEFAULT_MAX_REST_STEPS = 2510
local DEFAULT_LEVEL_GAIN = 2
local MAX_LEVEL_GAIN = 20
local MAX_LEVEL_BOOST = 99
local MAX_POKEMON_LEVEL = 100

local CRYSTAL_ASSETS = {
  RAIKOU = "raikou", ENTEI = "entei", SUICUNE = "suicune",
  LUGIA = "lugia", HO_OH = "ho_oh", CELEBI = "celebi",
}

local function loadSibling(mod, filename)
  -- mod:read goes through the loader filesystem, so this works identically
  -- for an installed directory, a ZIP and Modkit's virtual validation FS.
  local body, readErr = mod:read(filename)
  assert(type(body) == "string", readErr or ("unable to read " .. filename))
  -- 0.1.86 compiles every chunk produced by loadstring back into this mod's
  -- own sandbox.  A host loadfile fallback would both escape that contract
  -- and is intentionally absent from the mod environment.
  local chunk, err = loadstring(body, "@" .. mod.path .. "/" .. filename)
  assert(chunk, err or readErr)
  return chunk()
end

local function clampedInteger(value, fallback, minimum, maximum)
  value = math.floor(tonumber(value) or fallback)
  return math.max(minimum, math.min(maximum, value))
end

local function normalizedRestRange(minSteps, maxSteps)
  -- Never rewrite a historical saved pair. The supported editor starts at
  -- 151, but an untouched 128-256 save keeps that exact future cadence until
  -- its owner edits the CUSTOM range.
  minSteps = clampedInteger(minSteps, DEFAULT_MIN_REST_STEPS, 1, 2510)
  maxSteps = clampedInteger(maxSteps, DEFAULT_MAX_REST_STEPS, 1, 2510)
  if minSteps > maxSteps then minSteps, maxSteps = maxSteps, minSteps end
  return minSteps, maxSteps
end

local function rollRestSteps(random, minSteps, maxSteps)
  minSteps, maxSteps = normalizedRestRange(minSteps, maxSteps)
  random = random or math.random
  return clampedInteger(random(minSteps, maxSteps), minSteps, minSteps, maxSteps)
end

local function restLine(steps)
  steps = math.max(1, math.floor(tonumber(steps) or 1))
  return ("Still training!\nCome back in\n%d more step%s."):format(
    steps, steps == 1 and "" or "s")
end

-- The first rematch is already stronger than the original fight.  Every
-- completed rematch raises the next one again until the natural level-100
-- ceiling stops each individual Pokémon.
local function nextLevelBoost(rematches, gain)
  rematches = math.max(0, math.floor(tonumber(rematches) or 0))
  gain = clampedInteger(gain, DEFAULT_LEVEL_GAIN, 0, MAX_LEVEL_GAIN)
  return math.min(MAX_LEVEL_BOOST, (rematches + 1) * gain)
end

local function boostedTeam(team, boost)
  if type(team) ~= "table" then return team end
  boost = math.max(0, math.floor(tonumber(boost) or 0))
  local out = {}
  for i, slot in ipairs(team) do
    local copy = {}
    for key, value in pairs(slot) do copy[key] = value end
    copy.level = math.min(MAX_POKEMON_LEVEL, (tonumber(slot.level) or 1) + boost)
    out[i] = copy
  end
  return out
end

-- One line per trainer class, written in the class's voice.  The line
-- leads straight into the YES/NO prompt, so every one reads as a
-- challenge.  Rows are the text box's lines (max 18 chars each).
local REMATCH_LINES = {
  OPP_YOUNGSTER    = "I like shorts!\nBut I'm not\nlosing twice!",
  OPP_BUG_CATCHER  = "My BUG POKéMON\nwant to battle\nyou again!",
  OPP_LASS         = "I've been training\nsince we last\nfought. Rematch?",
  OPP_SAILOR       = "You're back,\nlandlubber! One\nmore battle?",
  OPP_JR_TRAINER_M = "I'll try harder\nthis time. Let's\nbattle again!",
  OPP_JR_TRAINER_F = "I've practiced\na lot since\nlast time!",
  OPP_POKEMANIAC   = "I've caught even\nmore POKéMON\nsince you beat me!",
  OPP_SUPER_NERD   = "I've studied\nyour strategy.\nLet's try again!",
  OPP_HIKER        = "I've climbed many\nmountains since\nour last battle!",
  OPP_BIKER        = "You're back for\nmore? Let's go\nfor a ride!",
  OPP_BURGLAR      = "You beat me\nonce. I want to\nsettle this!",
  OPP_ENGINEER     = "I've built some\nnew machines.\nTest them!",
  OPP_UNUSED_JUGGLER = "I've been\npracticing my\njuggling. Watch!",
  OPP_FISHER       = "The fish here\naren't the only\nthing I'll catch!",
  OPP_SWIMMER      = "The water's fine.\nLet's battle\nagain!",
  OPP_CUE_BALL     = "I'm not done\nwith you yet.\nRematch!",
  OPP_GAMBLER      = "I'll bet my\nPOKéMON can beat\nyours this time!",
  OPP_BEAUTY       = "I won't lose\nthis time. Care\nfor a rematch?",
  OPP_PSYCHIC_TR   = "I knew you'd\ncome back. Let's\nbattle again!",
  OPP_ROCKER       = "The encore is\nover. Time for\nround two!",
  OPP_JUGGLER      = "I've been\npracticing my\njuggling. Watch!",
  OPP_TAMER        = "My POKéMON are\nhungry for a\nrematch!",
  OPP_BIRD_KEEPER  = "My flying\nPOKéMON want to\nbattle again!",
  OPP_BLACKBELT    = "I've trained hard\nsince our last\nbattle. Rematch?",
  OPP_RIVAL1       = "You again? Fine,\nbut this time\nI'm not losing!",
  OPP_RIVAL2       = "You again? Fine,\nbut this time\nI'm not losing!",
  OPP_RIVAL3       = "You again? Fine,\nbut this time\nI'm not losing!",
  OPP_PROF_OAK     = "Care to battle\nme again, my\nyoung friend?",
  OPP_CHIEF        = "I won't lose\ntwice. Rematch!",
  OPP_SCIENTIST    = "My research\nshows I can\nbeat you now!",
  OPP_GIOVANNI     = "You've got nerve\ncoming back.\nWe'll see!",
  OPP_ROCKET       = "Team Rocket\nalways comes\nback. Rematch!",
  OPP_COOLTRAINER_M = "I've gotten\nstronger since\nwe last fought!",
  OPP_COOLTRAINER_F = "You're strong,\nbut I've trained\nsince then. Again?",
  OPP_BRUNO        = "Hoo hah! My\nmuscles have\ngrown! Rematch!",
  OPP_BROCK        = "You've returned.\nMy rock-hard\nPOKéMON await you!",
  OPP_MISTY        = "You're back!\nMy WATER POKéMON\nare ready for you!",
  OPP_LT_SURGE     = "Shock me again\nif you can,\nkid!",
  OPP_ERIKA        = "How lovely to\nsee you again.\nShall we battle?",
  OPP_KOGA         = "You have grown.\nProve it once\nmore. Rematch.",
  OPP_BLAINE       = "Ha! Fire burns\nbrighter the\nsecond time!",
  OPP_SABRINA      = "I foresaw your\nreturn. I have\nbeen waiting.",
  OPP_GENTLEMAN    = "Care for a\ncivilized\nrematch?",
  OPP_LORELEI      = "The cold winds\ncall for another\nbattle. Come.",
  OPP_CHANNELER    = "The spirits\nwish to see\nanother battle.",
  OPP_AGATHA       = "Heh heh heh.\nBack for more,\nare you?",
  OPP_LANCE        = "My dragons have\nslept long\nenough. Prove\nyourself again!",
}

local DEFAULT_LINE = "You're looking\nfor a rematch?"

-- One line per trainer class for when the player says NO.  Cocky and
-- rough classes mock the player; wise and polite ones are understanding.
local REMATCH_DECLINES = {
  OPP_YOUNGSTER    = "Ha! I knew\nit! Too scared\nto face me!",
  OPP_BUG_CATCHER  = "Chirp chirp!\nScared of a few\nlittle bugs?",
  OPP_LASS         = "Oh, I see.\nToo frightened\nof me, I bet!",
  OPP_SAILOR       = "Avast! Scared\nof the sea,\nare ya?",
  OPP_JR_TRAINER_M = "Coward! I bet\nyou're scared of\na real battle!",
  OPP_JR_TRAINER_F = "You're scared,\naren't you? I\nknew it!",
  OPP_POKEMANIAC   = "Ha! I guess my\ncollection scared\nyou off!",
  OPP_SUPER_NERD   = "Interesting.\nFear is just\npoor calculations.",
  OPP_HIKER        = "Hmph! Scared of\na little climb,\nare ya?",
  OPP_BIKER        = "Chicken! My\nwheels are too\nfast for you!",
  OPP_BURGLAR      = "Smart move.\nYou'd lose your\nPOKéMON to me.",
  OPP_ENGINEER     = "Fear of a\nmachine breakdown?\nHow fitting!",
  OPP_UNUSED_JUGGLER = "Afraid I'll\njuggle you dizzy?\nHeh.",
  OPP_FISHER       = "Got cold feet,\ndid ya? Ha!",
  OPP_SWIMMER      = "Scared to dip\nyour toes in,\nhuh?",
  OPP_CUE_BALL     = "Hah! You're\nscared of my\ntough moves!",
  OPP_GAMBLER      = "Chicken out? I\nwould've bet on\nit. Ha!",
  OPP_BEAUTY       = "Oh my. Afraid\nyour POKéMON\ncan't shine?",
  OPP_PSYCHIC_TR   = "I can see your\nfear. It's\nquite loud.",
  OPP_ROCKER       = "Too loud for\nyou? Ha! What\na pansy!",
  OPP_JUGGLER      = "Afraid I'll\njuggle you dizzy?\nHeh.",
  OPP_TAMER        = "Wise. My beasts\nwould've torn\nyou apart.",
  OPP_BIRD_KEEPER  = "Scared of a\nlittle flight?\nHa!",
  OPP_BLACKBELT    = "A wise choice.\nMy fists are\ntoo strong for\nyou.",
  OPP_RIVAL1       = "Ha! What a\nwimp. I've got\nbetter things\nto do.",
  OPP_RIVAL2       = "Ha! What a\nwimp. I've got\nbetter things\nto do.",
  OPP_RIVAL3       = "Ha! What a\nwimp. I've got\nbetter things\nto do.",
  OPP_PROF_OAK     = "Very well.\nWhen you're\nready, come\nback.",
  OPP_CHIEF        = "Chicken! I\nthought you had\nnerve!",
  OPP_SCIENTIST    = "Fear is a\nvariable I\naccounted for.",
  OPP_GIOVANNI     = "Coward. I\nexpected better\nof you.",
  OPP_ROCKET       = "Scared of Team\nRocket's power,\nhuh?",
  OPP_COOLTRAINER_M = "Too cool for a\nrematch? Ha!",
  OPP_COOLTRAINER_F = "Chicken! And\nhere I thought\nyou were strong.",
  OPP_BRUNO        = "Hoo hah! Fear\nis a weakness!\nTrain harder!",
  OPP_BROCK        = "Hm. You aren't\nready. Come\nback when you\nare.",
  OPP_MISTY        = "Heh, scared of\nsome WATER\nPOKéMON?",
  OPP_LT_SURGE     = "Ha! Scared of\na little shock?\nSome soldier\nyou are!",
  OPP_ERIKA        = "How shy. When\nyou're ready,\nI'll be here.",
  OPP_KOGA         = "Fear is poison.\nTrain your\nmind, then\nreturn.",
  OPP_BLAINE       = "Ha! The heat\ntoo much for\nyou?",
  OPP_SABRINA      = "I foresaw this\ntoo. Your fear\nis clear.",
  OPP_GENTLEMAN    = "Very well. A\ntrue gentleman\nnever presses.",
  OPP_LORELEI      = "Cold feet in\nthe cold winds?\nHow fitting.",
  OPP_CHANNELER    = "The spirits\ncan wait. Fear\nis natural.",
  OPP_AGATHA       = "Heh heh. Scared\nof an old\nwoman, are you?",
  OPP_LANCE        = "I respect a\ncareful trainer.\nTrain, then\nreturn.",
}

local DEFAULT_DECLINE = "Ha! Scared of\na rematch, are\nyou?"

-- One line per trainer class for the "your team is far stronger" warning,
-- spoken when the rematch team averages more than 10 levels above the
-- player's party.  Same voice as the challenge lines: the class owns the
-- warning.  Rows are the text box's lines (max 18 chars each).
local REMATCH_WARNINGS = {
  OPP_BROCK      = "Hm. My team is\nfar stronger than\nbefore. Are you\nsure?",
  OPP_MISTY      = "My POKéMON have\ngrown far beyond\nyours. Really?",
  OPP_LT_SURGE   = "Warning: my team\nis on another\nlevel. Still in?",
  OPP_ERIKA      = "My flowers have\nbloomed past your\nteam's strength.\nStill sure?",
  OPP_KOGA       = "My poison has\ngrown deadlier\nthan your team\ncan handle. Sure?",
  OPP_BLAINE     = "The heat burns\nfar beyond your\nteam. Ready?",
  OPP_SABRINA    = "I foresee your\nteam is far\nbehind mine. Are\nyou certain?",
  OPP_LORELEI    = "My cold winds\nare far stronger\nthan your team.\nContinue?",
  OPP_BRUNO      = "Hoo hah! My power\nis far beyond\nyours! Still\nsure?",
  OPP_AGATHA     = "Heh heh. My\nghosts are far\nabove your team.\nSure about this?",
  OPP_LANCE      = "My dragons tower\nfar above your\nteam. Do you\nreally wish to?",
  OPP_RIVAL3     = "My team is far\nstronger than\nyours now. Sure?",
}

local DEFAULT_WARN = "My team is far\nstronger than\nyours. Are you\nsure?"

local function resolveWarning(classId)
  return REMATCH_WARNINGS[classId] or DEFAULT_WARN
end

-- How many levels the trainer's team averages above the player's party;
-- nil when either side is empty, so callers can skip the warning.
local function levelGap(playerParty, team)
  if not team or #team == 0 then return nil end
  local playerLevels, playerCount = 0, 0
  if playerParty then
    for _, mon in ipairs(playerParty) do
      if mon and mon.level then
        playerLevels = playerLevels + mon.level
        playerCount = playerCount + 1
      end
    end
  end
  if playerCount == 0 then return nil end
  local teamLevels = 0
  for _, slot in ipairs(team) do
    teamLevels = teamLevels + (slot.level or 0)
  end
  return (teamLevels / #team) - (playerLevels / playerCount)
end

local function resolveLine(classId)
  return REMATCH_LINES[classId] or DEFAULT_LINE
end

local function resolveDecline(classId)
  return REMATCH_DECLINES[classId] or DEFAULT_DECLINE
end

-- the prize line filtered out of rematch victory queues
local function isPrizeLine(text)
  return type(text) == "string" and text:find("got ", 1, true) ~= nil
    and text:find("for winning", 1, true) ~= nil
end

return function(mod)
  -- Preserve the support interface for gameplay modules; public builds use
  -- an inert implementation without marker files or host-logger wrappers.
  mod.exports = mod.exports or {}
  mod.exports.supportSessionLog =
    loadSibling(mod, "support_session_log.lua")(mod)
  if not mod.exports.supportSessionLog.boot()
      and mod.log and type(mod.log.warn) == "function" then
    mod.log:warn("KASC bounded support log unavailable")
  end

  -- Must run before any option is read or save migration is registered.
  -- 6.5 corrects the historical trainer_rematch identity collision while
  -- preserving old options/save data and an RC9 rollback shadow.
  local identityMigration = loadSibling(mod, "identity_migration.lua")
  assert(identityMigration.install(mod))

  -- The newer migration layer supplies schema defaults and the launcher-time
  -- validation bridge.  Keep the RC10 shadow migration above as well: it is
  -- what makes the accepted RC9 rollback able to read saves written by 6.5.
  local idMigration = loadSibling(mod, "id_migration.lua").new(mod)
  -- A saved GAME SPEED belongs to gameplay. Keep the title and the complete
  -- New Game / Oak sequence at the authored 1x cadence.
  assert(loadSibling(mod, "pre_game_speed.lua")())
  -- This runs before the engine validates the selected slot. The accepted
  -- 6.0.7 data remains in its old bucket as a rollback snapshot and is copied
  -- into the new permanent namespace for 6.0.8+.
  mod.events:on("save.loading", function(ev)
    if idMigration.migrateSave(ev and ev.raw) then
      mod.log:info("migrated legacy trainer_rematch save data")
    end
  end, 10000)

  -- One explicit acquisition authority owns every Hoenn family and its
  -- Red/Green/Blue third before any encounter or UI consumer is created.
  mod.exports.hoennAcquisition67Data = loadSibling(
    mod, "hoenn_acquisition_67_data.lua")
  local i18n = loadSibling(mod, "localization.lua")(mod)
  -- KASC-66-GEN3-PROGRESSION-UNLOCKS uses one save-local discovery state for
  -- all twelve starter habitats. The TRACE FINDER is registered before the
  -- content graph freezes and earned only through ordinary rematch wins.
  mod.exports.discoveryCore = loadSibling(mod, "discovery_core.lua").create(
    mod, {
      state = loadSibling(mod, "discovery_state.lua"),
      starters = loadSibling(mod, "starter_discovery.lua"),
      overlay = loadSibling(mod, "encounter_overlay.lua"),
      hoenn = loadSibling(mod, "hoenn_discovery.lua"),
      hoennData = mod.exports.hoennAcquisition67Data,
    })
  mod.exports.hoennFieldAccess = loadSibling(
    mod, "hoenn_field_access_67.lua")(mod, {
      i18n = i18n,
      acquisition = mod.exports.hoennAcquisition67Data,
    })
  mod.exports.explorationDevice = loadSibling(
    mod, "exploration_device.lua")(mod, { i18n = i18n })
  local restProfiles = loadSibling(mod, "rematch_break_profiles.lua")
  mod.exports.rematchBreakProfiles = restProfiles
  -- KASC dialogue must never auto-scroll a third visible Gen-I text row.
  -- Install the ownership-aware guard before any sibling registers text, and
  -- track both localized results and content-backed map dialogue.
  local dialoguePagination = loadSibling(mod, "dialogue_pagination.lua")(
    mod)
  dialoguePagination.wrapLocalization(i18n)
  mod.exports.dialoguePagination = dialoguePagination
  -- One fail-closed renderer authority for native Voxel Ascendant, the
  -- reviewed DRAMALESS transition build and exact upstream Battle Art
  -- 1.9.0/1.9.2.
  -- Gameplay remains renderer-optional. Bridges consume KASC's local closed
  -- facade instead of forwarding a renderer owner's private loader.
  mod.exports.voxelRendererCompat = loadSibling(
    mod, "voxel_renderer_compat.lua")(mod)
  -- Battle Art 1.9.2's optional desktop cache can reject a completed RAM/GPU
  -- mesh before it is swapped into the scene. Install the exact-version seam
  -- after every package has exported, but before a save can enter gameplay.
  mod.events:once("mods.loaded", function()
    local prepared, why = mod.exports.voxelRendererCompat.prepare()
    assert(prepared, "renderer compatibility preparation failed: "
      .. tostring(why))
  end)
  local ascendantUi = loadSibling(mod, "ascendant_ui.lua")(
    mod, { i18n = i18n })
  -- A separate widget facade keeps vanilla/third-party lists untouched.
  -- Every Kanto Ascendant feature explicitly asks for this presentation.
  mod.ui.KantoListMenu = ascendantUi.ListMenu
  mod.exports.ascendantUi = ascendantUi
  -- Card-owned presentation seam: KASC marks and explains every ordinary
  -- feature list. VASC may lift that public contract into ORAS fullscreen;
  -- without VASC (or with another selected skin), KASC's localized FireRed
  -- focus/help renderer remains the safe, fully functional fallback.
  assert(mod.exports.supportSessionLog.registerSegment({
    cardId="KASC-66-FULLSCREEN-ORAS-MENU-SHELL", version="v1",
    schema="kasc/fullscreen-menu-shell/v1",
    owner="kasc.fullscreen-menu-shell/v1", active=true,
    dependencyStatus="vasc-optional",
    providerStatus="kasc-focus-help-markers-ready",
    buildReceiptId="fullscreen-oras-menu-shell",
    rollbackReceiptId="KASC_66_FULLSCREEN_ORAS_MENU_SHELL_ROLLBACK",
  }))
  -- KA-INTERNAL: LEGACY-JOURNEY-001
  local legacyJourney = loadSibling(mod, "legacy_journey.lua")(mod, {
    equipmentRewards = loadSibling(mod, "equipment_rewards_67.lua"),
    i18n = i18n,
    makeArchive = loadSibling(mod, "legacy_archive.lua"),
    -- The Signals hub is constructed later, but the callback runs only after
    -- gameplay starts.  This keeps the HEVO unlock on the same real Oak-call
    -- presentation seam as Johto while retaining a TextBox fallback inside
    -- legacy_journey.lua for minimal/headless loads.
    onOakCall = function(game, text, onDone)
      local hub = mod.exports and mod.exports.signalsHub
      if hub and type(hub.showOakCall) == "function" then
        return hub.showOakCall(game, text, onDone)
      end
    end,
  })
  mod.exports.legacyJourney = legacyJourney
  -- 66-ROCKET-RECOVERY-RAIDS owns only the raid/custody segment. Local Box
  -- custody is crash-safe; the Legacy fallback uses the archive's public
  -- lease API and never edits vault rows directly.
  mod.exports.rocketRecoveryCustody67 = loadSibling(
    mod, "rocket_recovery_custody_67.lua")(mod)
  mod.exports.rocketRecoverySources67 = loadSibling(
    mod, "rocket_recovery_sources_67.lua")(mod, {
      archive = legacyJourney.archive,
      localCustody = mod.exports.rocketRecoveryCustody67,
    })
  mod.exports.surpriseTitles67Data = loadSibling(mod,
    "surprise_titles_67_data.lua")
  mod.exports.surpriseDialogueMatrix67 = loadSibling(mod,
    "surprise_dialogue_matrix_67.lua")(mod, { i18n = i18n })
  mod.exports.surpriseTrainers67 = loadSibling(mod,
    "surprise_trainers_67.lua")(mod, {
      i18n = i18n,
      data = mod.exports.surpriseTitles67Data,
      archive = legacyJourney.archive,
      dialogue = mod.exports.surpriseDialogueMatrix67,
    })
  local legacyWanderers = loadSibling(mod, "legacy_wanderers.lua")(mod, {
    i18n = i18n, journey = legacyJourney,
    surprise = mod.exports.surpriseTrainers67,
    -- Rematch rewards is constructed later because its UI depends on the
    -- complete option schema. Resolve it lazily when a Wanderer reward rolls.
    rewards = function() return mod.exports.rematchRewards end,
    equipmentRewards = function() return mod.exports.equipmentRewards67 end,
  })
  mod.exports.legacyWanderers = legacyWanderers
  local legacyPathsData = loadSibling(mod, "legacy_paths_data.lua")
  local makeLegacyPaths = loadSibling(mod, "legacy_paths.lua")
  local legacyPaths = makeLegacyPaths(mod, {
    i18n = i18n, journey = legacyJourney,
    wanderers = legacyWanderers, data = legacyPathsData,
  })
  mod.exports.legacyPaths = legacyPaths
  mod.exports.legacyPathsData = legacyPathsData
  local makeLegacyOakFinale = loadSibling(mod, "legacy_oak_finale.lua")
  local legacyOakFinale = makeLegacyOakFinale(mod, {
    i18n = i18n, journey = legacyJourney, paths = legacyPaths,
  })
  legacyPaths.setFinale(legacyOakFinale)
  mod.exports.legacyOakFinale = legacyOakFinale
  local characterDialogue = loadSibling(mod, "character_dialogue.lua")

  -- SGB's historical paper shade is a faint magenta (255,239,255).  It was
  -- unobtrusive on four-colour tiles but becomes an obvious pink cast beside
  -- the full-colour trainer and Pokemon PNGs in this model pack.  Normalize
  -- only SGB shade zero to real white across the complete rendered game;
  -- colored ink, world midtones and every other selectable display mode stay
  -- untouched.
  do
    local PaletteFX = require("src.render.PaletteFX")
    if not PaletteFX.__kantoAscendantWhitePaper then
      local originalEffectiveColors = PaletteFX.effectiveColors
      PaletteFX.effectiveColors = function(colors)
        local resolved = originalEffectiveColors(colors)
        if PaletteFX.mode ~= "gbc" or type(resolved) ~= "table"
            or not resolved[1] then
          return resolved
        end
        return {
          { 255, 255, 255 }, resolved[2], resolved[3], resolved[4],
        }
      end
      PaletteFX.__kantoAscendantWhitePaper = true
    end
  end
  mod.content.field:patch("title", { copyrightText = "KANTO ASCENDANT" })
  mod.content.sprites:register("SPRITE_KA_GREEN", {
    id = "SPRITE_KA_GREEN",
    image = mod.path .. "/assets/characters/green_walk.png",
    frames = 6,
    walker = true,
    -- RED++ group 2 is the authentic green OBJ family. SpriteRenderer shares
    -- this resolved sheet with Dramatic Shape, so Red/Blue/Green, SGB and
    -- monochrome modes all produce their own coherent Voxel spectrum.
    paletteSource = "ROM:SpriteSheetPointerTable[21]",
  })
  local crystalWalkAssets = loadSibling(mod, "crystal_walk_assets.lua")(mod)
  mod.exports.crystalWalkAssets = crystalWalkAssets
  -- Optional cohesive Gen-I field set. Every identity owns native 16x16 walk,
  -- bicycle and fishing frames; no state silently falls back to Red. The
  -- larger reviewed designs are used only for battle/selection portraits.
  for _, character in ipairs({ "RED", "GREEN", "BLUE" }) do
    local stem = character:lower()
    for _, state in ipairs({
      { suffix = "WALK", file = "walk" },
      { suffix = "BIKE", file = "bike" },
      { suffix = "FISH", file = "fish" },
    }) do
      local id = "SPRITE_KA_CRYSTAL_" .. character .. "_" .. state.suffix
      mod.content.sprites:register(id, {
        id = id,
        image = state.file == "walk" and crystalWalkAssets.resolve(stem)
          or (mod.path .. "/assets/characters/crystal_chars/" .. stem
            .. "_" .. state.file .. ".png"),
        frames = 6, walker = true, trueColor = true,
      })
    end
  end
  -- CRYSTAL CHARS combines the three playable identities above with Kanto
  -- Ascendant's own Voxel portraits. Native FRLG trainer PNGs are deliberately
  -- absent; compact 2D opponents remain the edition-original Gen-I pictures.
  -- Register this before extended_characters so its event refresh runs first
  -- and the identity-aware Rival front remains the final override.
  local frlgTrainerPack = loadSibling(mod, "frlg_trainer_pack.lua")(mod)
  mod.exports.frlgTrainerPack = frlgTrainerPack
  local trainerVoxelPortraits = loadSibling(mod,
    "trainer_voxel_portraits.lua")(mod)
  mod.exports.trainerVoxelPortraits = trainerVoxelPortraits
  local extendedCharacters = loadSibling(mod, "extended_characters.lua")(mod, {
    i18n = i18n, dialogue = characterDialogue,
    trainerVoxelPortraits = trainerVoxelPortraits,
    frlgTrainerPack = frlgTrainerPack,
    voxelRenderer = mod.exports.voxelRendererCompat,
    -- World Rank registers later in this entry chunk. Keep this lookup
    -- late-bound and fail-closed so reserved guest class IDs prove nothing.
    worldRankGuestAuthority = function(classId, game)
      local guests = mod.exports and mod.exports.worldRankTournamentGuests
      if type(guests) == "table"
          and type(guests.authority) == "function" then
        return guests.authority(classId, game)
      end
      return nil, "guest-authority-unavailable"
    end,
  })
  mod.exports.extendedCharacters = extendedCharacters
  -- Casey's default Ascendant back remains the compact Gen-I asset.
  mod.content.battle_sprite_scales:register("KA_GREEN_TRAINER_BACK", {
    path = mod.path .. "/assets/characters/green_back.png",
    scale = 2,
    offsetY = 2,
  })
  -- CRYSTAL CHARS backs are native 64x64 FRLG-scale art. They draw once at
  -- source resolution; the previous 32x32->2x path was the source of blur.
  local crystalBackOffsetY = { red = 0, green = 4, blue = 1 }
  for _, character in ipairs({ "red", "green", "blue" }) do
    local throwFrames = {}
    for frame = 1, 5 do
      throwFrames[frame] = mod.path .. "/assets/characters/crystal_chars/"
        .. character .. "_back_throw_" .. frame .. ".png"
    end
    mod.content.battle_sprite_scales:register(
      "KA_CRYSTAL_" .. character:upper() .. "_TRAINER_BACK", {
        path = mod.path .. "/assets/characters/crystal_chars/"
          .. character .. "_back.png",
        scale = 1,
        -- Authored silhouettes have different transparent foot baselines.
        -- Offset only the battle placement so all three meet the stock frame;
        -- the pixels and every field animation remain untouched.
        offsetY = crystalBackOffsetY[character],
        throwFrames = throwFrames,
        throwTicks = 6,
      })
  end
  mod.exports.rivalTeams = loadSibling(mod, "rival_teams.lua")(mod, extendedCharacters)
  mod.exports.legacyRivalPartner = loadSibling(mod, "legacy_rival_partner.lua")(mod)
  mod.exports.battleAcceptance = loadSibling(mod, "battle_acceptance.lua")(mod, {
    i18n = i18n,
  })
  mod.exports.titleIntro = loadSibling(mod, "title_intro.lua")(mod, extendedCharacters)
  -- KASC-66-ANIMATED-TITLE-CORE-PREP owns only the optional trainer overlay.
  -- The registry is private to this Card: no title species pools or alternate
  -- compositor are registered here, and the existing 6.6 title remains owner.
  local titleTrainerRegistry = loadSibling(mod,
    "presentation_sprite_registry.lua")(mod)
  mod.exports.titleTrainerAnimation67 = loadSibling(mod,
    "title_trainer_animation_67.lua")(mod, {
      registry = titleTrainerRegistry,
    })
  assert(mod.exports.titleIntro.setTrainerAnimation(
    mod.exports.titleTrainerAnimation67),
    "animated title trainer adapter registration failed")
  -- KASC-66-VISUAL-TITLE-THEMES is an asset-free palette provider. It does
  -- not own title composition, trainer timing, music, input or any Engine
  -- hook; the existing TitleState palette adapter remains the sole caller.
  mod.exports.titleVisualThemes66 = loadSibling(mod,
    "title_visual_themes_66.lua")(mod)
  assert(mod.exports.titleIntro.setVisualThemes(
    mod.exports.titleVisualThemes66),
    "visual title theme adapter registration failed")
  local recruitment = loadSibling(mod, "trainer_recruits.lua")
  local rematchRosterAuthority = loadSibling(mod,
    "rematch_roster_authority.lua")
  mod.exports.rematchRosterAuthority = rematchRosterAuthority
  local loot = loadSibling(mod, "rematch_loot.lua")
  mod.exports.equipmentRewards67 = loadSibling(mod, "equipment_rewards_67.lua")
  mod.exports.equipmentRewards67.registerSupport(mod.exports.supportSessionLog)
  loot.bindEquipmentRewards(mod.exports.equipmentRewards67)
  local function installedMod(id)
    local ok, handle = pcall(mod.find, id)
    return ok and handle ~= nil
  end
  -- Register content-backed QoL screens before the loader freezes registries.
  if not installedMod("jj_quick_select") then
    local installQuickSelect = loadSibling(mod, "quick_select.lua")
    if type(installQuickSelect) == "function" then
      mod.exports.quickSelect = installQuickSelect(mod, { i18n = i18n })
    end
  else
    mod.exports.externalQuickSelect = true
  end
  if not installedMod("quality_of_life") then
    local installQuality = loadSibling(mod, "quality_of_life.lua")
    if type(installQuality) == "function" then
      mod.exports.qualityOfLife = installQuality(mod)
    end
  else
    mod.exports.externalQualityOfLife = true
  end
  local function menuLabel(english, german)
    return i18n.isGerman() and german or english
  end

  -- PokéPC Followers 1.3.0 deliberately rewrites Yellow's scripted
  -- level-5 Pikachu into Charmander and replaces the corresponding names
  -- and Oak dialogue. Ascendant supports arbitrary followers, but it must
  -- not replace Yellow's canonical starter story as a side effect. Our
  -- higher-priority content layer restores the original visible text; the
  -- runtime constructor guard lives in follower_compat.lua.
  local GameVersion = require("src.core.GameVersion")
  -- Yellow's vanilla Oak script treats two owned species as proof that the
  -- Pokédex already exists. Legacy withdrawal breaks that invariant, so C14
  -- owns one narrowly scoped story-command compatibility guard.
  mod.exports.legacyNgplusProgression = loadSibling(
    mod, "legacy_ngplus_progression.lua")(mod, {
      journey = legacyJourney,
      gameVersion = GameVersion,
    })
  local yellowMtMoonFossilDialogue = loadSibling(
    mod, "yellow_mtmoon_fossil_dialogue.lua")({
      gameVersion = GameVersion,
    })
  mod.exports.yellowMtMoonFossilDialogue = yellowMtMoonFossilDialogue
  if GameVersion.isYellow() then
    mod.content.strings:override("PIKACHU", "PIKACHU")
    mod.content.text:override(
      "_OaksLabPikachuDislikesPokeballsText1",
      i18n.text("OAK: What?", "EICH: Wie bitte?"))
    mod.content.text:override(
      "_OaksLabPikachuDislikesPokeballsText2",
      i18n.text(
        "OAK: Would you\nlook at that!\fIt's odd, but it\nappears that your"
          .. "\nPIKACHU dislikes\nPOKé BALLs.\fYou should just\nkeep it with you."
          .. "\fThat should make\nit happy!\fYou can talk to it\nand see how it"
          .. "\nfeels about you.",
        "EICH: Schau Dir\ndas an!\fEs ist seltsam,\naber Dein PIKACHU"
          .. "\nmag scheinbar\nkeine POKéBÄLLE.\fEs muß Dich\nso begleiten."
          .. "\fDann ist es\nauch glücklich.\fDu kannst mit ihm\nsprechen und"
          .. "\nmerkst dann, ob\nes Dich mag."))
    mod.content.text:override(
      "_OaksLabOak1YouShouldTalkToIt",
      i18n.text(
        "OAK: You should\ntalk to it and\nsee how it feels.",
        "EICH: Du solltest\nmit ihm sprechen\nund Dich um es\nkümmern."))
  end

  local ascendantOptionSchema = {
    { key = "difficulty", label = menuLabel("DIFFICULTY", "SCHWIERIGKEIT"),
      type = "choice", default = "standard",
      choices = {
        { menuLabel("STANDARD", "STANDARD"), "standard" },
        { menuLabel("HIGH", "HOCH"), "high" },
        { menuLabel("HARD", "SCHWER"), "hard" },
        { menuLabel("VERY HARD", "SEHR SCHWER"), "very_hard" },
        { menuLabel("EXTREME", "EXTREM"), "extreme" },
      } },
    { key = "story_difficulty_rosters",
      label = menuLabel("DIFFICULTY ROSTERS", "SCHWIERIGKEITS-TEAMS"),
      type = "toggle", default = true },
    { key = "battle_generation_mode",
      label = menuLabel("BATTLE GENERATION", "KAMPF-GENERATION"),
      type = "choice", default = "auto",
      choices = {
        { "AUTO", "auto" },
        { menuLabel("OFF", "AUS"), "off" },
        { "GEN I", "gen1" }, { "GEN II", "gen2" },
        { "GEN III", "gen3" }, { "GEN IV", "gen4" },
        { "GEN V", "gen5" }, { "GEN VI", "gen6" },
      } },
    { key = "adaptive_trainer_levels",
      label = menuLabel("ADAPTIVE TRAINER-LV", "ADAPTIVE TRAINER-LV"),
      -- AUTO is classic on Standard and follows the documented target gaps
      -- on higher difficulties. Existing slots receive a save-local classic
      -- hold until the player deliberately revisits this row or Difficulty.
      type = "choice", default = "auto",
      choices = {
        { "AUTO", "auto" },
        { menuLabel("OFF", "AUS"), "off" },
        { "-2", "-2" },
        { menuLabel("MATCH", "GLEICH"), "0" },
        { "PLUS 2", "2" }, { "PLUS 4", "4" },
        { "PLUS 6", "6" }, { "PLUS 8", "8" },
      } },
    { key = "wild_level_scaling",
      label = menuLabel("WILD LEVEL SCALING", "WILD-LEVEL-SKALIERUNG"),
      -- Difficulty must never raise a fresh or migrated save's Wild levels
      -- unless the player explicitly opts in. The upstream encounter remains
      -- authoritative while OFF; trainer difficulty is a separate contract.
      type = "toggle", default = false },
    { key = "rare_item_lock",
      label = menuLabel("RARE ITEM LOCK", "SELTENE ITEMS SCHÜTZEN"),
      type = "toggle", default = true },
    { key = "vision_encounters",
      label = menuLabel("HO-OH VISION", "HO-OH-VISION"),
      type = "toggle", default = true },
    { key = "rest_profile",
      label = menuLabel("REMATCH BREAK", "REVANCHENPAUSE"),
      type = "choice", default = restProfiles.DEFAULT,
      choices = {
        { menuLabel("VERY SHORT", "SEHR KURZ"), "very_short" },
        { menuLabel("SHORT", "KURZ"), "short" },
        { menuLabel("NORMAL", "NORMAL"), "normal" },
        { menuLabel("LONG", "LANG"), "long" },
        { menuLabel("VERY LONG", "SEHR LANG"), "very_long" },
        { menuLabel("CUSTOM", "EIGEN"), "custom" },
      } },
    { key = "rest_min",
      label = menuLabel("CUSTOM MIN STEPS", "EIGENE MIN-SCHRITTE"),
      type = "number",
      default = DEFAULT_MIN_REST_STEPS, min = 151, max = 2510, step = 1 },
    { key = "rest_max",
      label = menuLabel("CUSTOM MAX STEPS", "EIGENE MAX-SCHRITTE"),
      type = "number",
      default = DEFAULT_MAX_REST_STEPS, min = 151, max = 2510, step = 1 },
    { key = "level_gain", label = menuLabel("LEVELS / REMATCH", "LEVEL / REVANCHE"),
      type = "number",
      default = DEFAULT_LEVEL_GAIN, min = 0, max = MAX_LEVEL_GAIN, step = 1 },
    { key = "team_growth", label = menuLabel("TEAM GROWTH", "TEAM-WACHSTUM"),
      type = "toggle", default = true },
    { key = "loot_mode", label = menuLabel("REMATCH LOOT", "REVANCHEN-BEUTE"),
      type = "choice", default = "balanced",
      choices = {
        { menuLabel("OFF", "AUS"), "off" },
        { menuLabel("BALANCED", "NORMAL"), "balanced" },
        { menuLabel("GENEROUS", "VIEL"), "generous" },
      } },
    { key = "legacy_wanderer_frequency",
      label = menuLabel("WANDERER FREQ.", "WANDERER-HÄUFIGK."),
      type = "choice", default = "rare",
      choices = {
        { menuLabel("NEVER", "NIE"), "never" },
        { menuLabel("RARE", "SELTEN"), "rare" },
        { menuLabel("NORMAL", "NORMAL"), "normal" },
        { menuLabel("OFTEN", "OFT"), "often" },
      } },
    { key = "surprise_dialogue_matrix",
      label = menuLabel("WANDERER DIALOGUE", "WANDERER-DIALOGE"),
      type = "toggle", default = true },
    { key = "surprise_trainer_mega",
      label = menuLabel("WANDERER MEGA", "WANDERER-MEGA"),
      type = "toggle", default = true },
    { key = "surprise_team_fairness",
      label = menuLabel("WANDERER FAIRNESS", "WANDERER-FAIRNESS"),
      type = "toggle", default = true },
    { key = "hoenn_encounters",
      label = menuLabel("HOENN ENCOUNTERS", "HOENN-BEGEGNUNGEN"),
      type = "toggle", default = true },
    { key = "hoenn_level_mode",
      label = menuLabel("HOENN LEVELS", "HOENN-LEVEL"),
      type = "choice", default = "route",
      choices = {
        { menuLabel("ROUTE", "ROUTE"), "route" },
        { menuLabel("BADGES", "ORDEN"), "badges" },
        { menuLabel("PARTY", "TEAM"), "party" },
      } },
    { key = "hoenn_trace_presentation",
      label = menuLabel("HOENN TRACE MOMENT", "HOENN-SPURMOMENT"),
      type = "toggle", default = true },
    { key = "hoenn_roamers",
      label = menuLabel("EON ROAMERS", "ÄON-WANDERER"),
      type = "toggle", default = true },
    { key = "hoenn_roamer_flee",
      label = menuLabel("EON FLEE", "ÄON-FLUCHT"),
      type = "toggle", default = true },
    { key = "hoenn_regi_sanctums",
      label = menuLabel("REGI SANCTUMS", "REGI-SANKTUARIEN"),
      type = "toggle", default = true },
    { key = "hoenn_moltres_volcano",
      label = menuLabel("MOLTRES VOLCANO", "LAVADOS-VULKAN"),
      type = "toggle", default = true },
    { key = "hoenn_endgame_access_puzzles",
      label = menuLabel("ENDGAME ACCESS", "ENDGAME-ZUGÄNGE"),
      type = "toggle", default = true },
    { key = "hoenn_legend_portals",
      label = menuLabel("HOENN PORTALS", "HOENN-PORTALE"),
      type = "toggle", default = true },
    { key = "hoenn_birth_island",
      label = menuLabel("BIRTH ISLAND", "ENTSTEHUNGSINSEL"),
      type = "toggle", default = true },
    { key = "hoenn_jirachi_finale",
      label = menuLabel("JIRACHI FINALE", "JIRACHI-FINALE"),
      type = "toggle", default = true },
    { key = "starter_habitats_enabled",
      label = menuLabel("STARTER HABITATS", "STARTER-HABITATE"),
      type = "toggle", default = true },
    { key = "kanto_151",
      label = menuLabel("KANTO 151 RESTART", "KANTO 151 NEUST."),
      type = "choice", default = "ascendant",
      choices = {
        { menuLabel("REWARDS", "BELOHNUNGEN"), "ascendant" },
        { menuLabel("WILD", "WILD"), "wild" },
        { menuLabel("OFF", "AUS"), "off" },
      } },
    { key = "legend_art", label = menuLabel("JOHTO ART", "JOHTO-GRAFIK"),
      type = "choice",
      default = "crystal",
      choices = {
        { menuLabel("CRYSTAL (BUNDLED)", "KRISTALL (ENTHALTEN)"), "crystal" },
        { menuLabel("KANTO FALLBACK", "KANTO-ERSATZ"), "original" },
      } },
    { key = "kanto_crystal_art",
      label = menuLabel("KANTO CRYSTAL ART", "KANTO-KRISTALLGRAFIK"),
      type = "toggle", default = true },
    { key = "dex_sprite_style",
      label = menuLabel("DEX SPRITES", "DEX-SPRITES"),
      type = "choice", default = "original",
      choices = {
        { menuLabel("ORIGINAL", "ORIGINAL"), "original" },
        { menuLabel("CRYSTAL", "CRYSTAL"), "crystal" },
      } },
    { key = "party_icon_style",
      label = menuLabel("TEAM ICONS", "TEAM-ICONS"),
      type = "choice", default = "animated",
      choices = {
        { menuLabel("ANIMATED SPECIES", "ANIMIERTE ARTEN"), "animated" },
        { menuLabel("ORIGINAL GEN I", "ORIGINAL GEN I"), "original" },
      } },
    { key = "crystal_animation",
      label = menuLabel("CRYSTAL ANIMATION", "KRISTALL-ANIMATION"),
      type = "toggle", default = true },
    { key = "non_crystal_pixel_2d",
      label = menuLabel("NEW SPECIES 2D STILLS", "NEUE ARTEN 2D-STANDBILD"),
      type = "toggle", default = true },
    { key = "classic_2d_sprite_connector",
      label = menuLabel("2D SPRITE TRACK", "2D-SPRITE-SPUR"),
      type = "toggle", default = true },
    { key = "legacy_random_partners",
      label = menuLabel("NG+ RANDOM PARTNERS", "NG+ ZUFALLSPARTNER"),
      type = "toggle", default = true },
    { key = "legacy_global_babies",
      label = menuLabel("GLOBAL RANDOM BABIES", "GLOBAL-ZUFALL BABYS"),
      type = "toggle", default = true },
    { key = "non_crystal_voxel_animations",
      label = menuLabel("NEW SPECIES VOXEL ANIM.", "NEUE ARTEN VOXEL-ANIM."),
      type = "toggle", default = true },
    { key = "pokemon_sprite_style",
      label = menuLabel("POKéMON SPRITE STYLE", "POKéMON-SPRITESTIL"),
      -- Fresh 6.5 profiles start with the complete Crystal presentation,
      -- including title and Oak's demo Pokémon. Existing explicit choices
      -- remain untouched by the option migration.
      type = "choice", default = "crystal",
      choices = {
        { menuLabel("AUTO (COMPATIBLE)", "AUTO (KOMPATIBEL)"), "legacy" },
        { menuLabel("GAME-ORIGINAL", "SPIEL-ORIGINAL"), "original" },
        { "CRYSTAL 2D", "crystal" },
      } },
    { key = "character_sprite_style",
      label = menuLabel("FIELD CHARACTERS", "SPIELERFIGUREN"),
      type = "choice", default = "crystal",
      choices = {
        { "ASCENDANT FIELD", "ascendant" },
        { "KASC FIELD", "crystal" },
      } },
    { key = "trainer_portrait_style",
      label = menuLabel("TRAINER PORTRAITS", "TRAINER-PORTRÄTS"),
      type = "choice", default = "crystal_hd",
      choices = {
        { "CRYSTAL HD", "crystal_hd" },
        { menuLabel("ORIGINAL", "ORIGINAL"), "original" },
      } },
    { key = "animated_title_trainers",
      label = menuLabel("ANIMATED TITLE TRAINERS",
        "ANIMIERTE TITELTRAINER"),
      -- The 6.6 RC enables the reviewed animation for new profiles and for
      -- existing profiles that have no value yet.  The engine resolves a
      -- missing key through this default without overwriting a saved choice;
      -- an explicit OFF therefore remains authoritative across upgrades.
      type = "toggle", default = true },
    { key = "title_visual_theme",
      label = menuLabel("TITLE THEME", "TITELDESIGN"),
      -- The asset-free Theme Card is deliberately opt-in visually. Missing
      -- and invalid saved values resolve to the exact current 6.6 title.
      type = "choice", default = "classic",
      choices = {
        { menuLabel("CLASSIC", "KLASSISCH"), "classic" },
        { menuLabel("TRAINER TRIO", "TRAINER-TRIO"), "trio" },
        { menuLabel("MONO STAGE", "MONO-BÜHNE"), "mono" },
      } },
    { key = "sprite_style_battle",
      label = menuLabel("SPRITES IN BATTLE", "SPRITES IM KAMPF"),
      type = "toggle", default = true },
    { key = "sprite_style_summary",
      label = menuLabel("SPRITES IN PARTY/STATUS", "SPRITES IN TEAM/STATUS"),
      type = "toggle", default = true },
    { key = "sprite_style_dex",
      label = menuLabel("SPRITES IN POKéDEX", "SPRITES IM POKéDEX"),
      type = "toggle", default = true },
    { key = "sprite_style_box",
      label = menuLabel("SPRITES IN BOXES", "SPRITES IN BOXEN"),
      type = "toggle", default = true },
    { key = "box_grid_icon_style",
      label = menuLabel("BOX ICONS", "BOX-ICONS"),
      type = "choice", default = "current",
      choices = {
        { menuLabel("CURRENT", "AKTUELL"), "current" },
        { menuLabel("HGSS WALKERS", "HGSS-BEGLEITER"), "hgss_walker" },
      } },
    { key = "sprite_style_scenes",
      label = menuLabel("SPRITES IN OTHER SCENES", "SPRITES IN SZENEN"),
      type = "toggle", default = true },
    { key = "shiny_hunts", label = menuLabel("SHINY HUNTS", "SHINY-JAGD"),
      type = "choice", default = "ascendant",
      choices = {
        { menuLabel("ASCENDANT", "ASCENDANT"), "ascendant" },
        { menuLabel("NATURAL 1/8192", "NATÜRLICH 1/8192"), "natural" },
      } },
    { key = "shiny_effects",
      label = menuLabel("SHINY EFFECTS", "SHINY-EFFEKTE"),
      type = "toggle", default = true },
    { key = "shiny_protection",
      label = menuLabel("SHINY RELEASE LOCK", "SHINY-SCHUTZ"),
      type = "toggle", default = true },
    { key = "shiny_event",
      label = menuLabel("RED GYARADOS", "ROTES GARADOS"),
      type = "toggle", default = true },
    { key = "mega_evolution",
      label = menuLabel("MEGA EVOLUTION", "MEGA-ENTWICKLUNG"),
      type = "toggle", default = true },
    { key = "mega_opponents",
      label = menuLabel("ENEMY MEGA", "GEGNER-MEGA"),
      type = "choice", default = "bosses",
      choices = {
        { menuLabel("BOSSES", "BOSSE"), "bosses" },
        { menuLabel("ALL TRAINERS", "ALLE TRAINER"), "all" },
        { menuLabel("OFF", "AUS"), "off" },
      } },
    { key = "johto_time", label = menuLabel("JOHTO TIME", "JOHTO-ZEIT"),
      type = "choice", default = "auto",
      choices = {
        { menuLabel("AUTO CLOCK", "AUTO-UHR"), "auto" },
        { menuLabel("DAY", "TAG"), "day" },
        { menuLabel("NIGHT", "NACHT"), "night" },
      } },
    { key = "living_world_enabled",
      label = menuLabel("WILD POKéMON", "WILD-POKéMON"),
      type = "toggle", default = true },
    { key = "living_world_density",
      label = menuLabel("WILD COUNT", "WILD-MENGE"),
      type = "choice", default = "normal",
      choices = {
        { menuLabel("LOW", "WENIG"), "low" },
        { menuLabel("NORMAL", "NORMAL"), "normal" },
        { menuLabel("HIGH", "VIEL"), "high" },
        { menuLabel("VERY HIGH", "SEHR VIEL"), "very_high" },
      } },
    { key = "living_world_random_encounters",
      label = menuLabel("RANDOM BATTLES", "ZUFALLSKÄMPFE"),
      -- A fresh/missing setting starts with both encounter presentations:
      -- visible Wilds and the classic step roll.  The option loader still
      -- prefers any stored boolean, so an explicit player choice of false is
      -- never rewritten by this schema default.
      type = "toggle", default = true },
    { key = "living_world_water",
      label = menuLabel("WATER", "WASSER"),
      type = "choice", default = "swimming_sprites",
      choices = {
        { menuLabel("SWIMMING SPRITES", "SCHWIMMSPRITES"), "swimming_sprites" },
        { menuLabel("HIDDEN SILHOUETTES", "VERBORGENE SILHOUETTEN"), "hidden_silhouettes" },
        { menuLabel("SILHOUETTES", "SILHOUETTEN"), "silhouettes" },
        { menuLabel("CLASSIC ENCOUNTERS", "KLASSISCHE KÄMPFE"), "classic_encounters" },
        { menuLabel("DISABLED", "AUS"), "disabled" },
      } },
    { key = "living_world_caves",
      label = menuLabel("CAVES", "HÖHLEN"),
      type = "choice", default = "reachable",
      choices = {
        { menuLabel("REACHABLE ONLY", "NUR ERREICHBAR"), "reachable" },
        { menuLabel("MIXED SCENERY", "GEMISCHTE KULISSE"), "mixed" },
      } },
    { key = "living_world_grass",
      label = menuLabel("GRASS", "GRAS"),
      type = "choice", default = "immersed",
      choices = {
        { menuLabel("IN GRASS", "IM GRAS"), "immersed" },
        { menuLabel("ABOVE GRASS", "ÜBER GRAS"), "above" },
      } },
    { key = "living_world_idle",
      label = menuLabel("CALM SPECIES", "RUHIGE ARTEN"),
      type = "toggle", default = true },
    { key = "living_world_wander",
      label = menuLabel("WANDERING", "WANDERND"),
      type = "toggle", default = true },
    { key = "living_world_chase",
      label = menuLabel("CHASE", "VERFOLGUNG"),
      type = "toggle", default = true },
    { key = "living_world_hidden",
      label = menuLabel("HIDDEN", "VERSTECKT"),
      type = "toggle", default = true },
    { key = "living_world_silhouettes",
      label = menuLabel("SILHOUETTES", "SILHOUETTEN"),
      type = "toggle", default = false },
    { key = "johto_wilds_integration",
      label = menuLabel("JOHTO HABITATS", "JOHTO-HABITATE"),
      type = "toggle", default = true },
    { key = "living_world_towns",
      label = menuLabel("TOWN POKéMON", "STADT-POKéMON"),
      type = "toggle", default = true },
    { key = "wilds_town_pokemon_amount",
      label = menuLabel("TOWN COUNT", "STADTMENGE"),
      type = "choice", default = "auto",
      choices = {
        { menuLabel("AUTOMATIC", "AUTOMATISCH"), "auto" },
        { "0", 0 },
        { "1", 1 },
        { "2", 2 },
        { "3", 3 },
        { "4", 4 },
        { "5", 5 },
      } },
    { key = "wilds_town_pokemon_species",
      label = menuLabel("TOWN REGION", "STADTREGION"),
      type = "choice", default = "mixed",
      choices = {
        { menuLabel("KANTO ONLY", "NUR KANTO"), "kanto" },
        -- The bundled Gen-I UI font has no plus glyph.  Keep the same meaning
        -- while ensuring the selected value is fully legible on every port.
        { menuLabel("KANTO / JOHTO", "KANTO / JOHTO"), "mixed" },
        { menuLabel("JOHTO ONLY", "NUR JOHTO"), "johto" },
      } },
    { key = "johto_level_bonus",
      label = menuLabel("JOHTO LEVEL BONUS", "JOHTO-ANSTIEG"),
      type = "choice", default = "2_8",
      choices = {
        { menuLabel("ROUTE AVG PLUS 2 TO 8", "ROUTENMITTEL PLUS 2 BIS 8"), "2_8" },
        { menuLabel("ROUTE AVG PLUS 2 TO 5", "ROUTENMITTEL PLUS 2 BIS 5"), "2_5" },
      } },
    { key = "ascendant_useful_bag",
      label = menuLabel("ASCENDANT BAG", "KASC-BEUTEL"),
      type = "toggle", default = true },
    { key = "ascendant_bag_mode",
      label = menuLabel("ASCENDANT BAG MODE", "BEUTEL-DESIGN"),
      type = "choice", default = "pockets",
      choices = {
        { menuLabel("OFF / EXTERNAL MOD", "AUS / EXTERNE MOD"), "off" },
        { menuLabel("GAME DEFAULT", "SPIELSTANDARD"), "standard" },
        { menuLabel("KASC SKIN", "KASC"), "skin" },
        { menuLabel("KASC SKIN / 999 SLOTS", "KASC (999)"), "expanded" },
        { menuLabel("FIRERED POCKETS / 999", "FEUERROT (999)"), "pockets" },
      } },
    { key = "ascendant_quick_select",
      label = menuLabel("QUICK SELECT", "SCHNELLWAHL"),
      type = "toggle", default = true },
    { key = "ascendant_qol",
      label = menuLabel("ASCENDANT QOL", "KOMFORTHILFEN"),
      type = "toggle", default = true },
    -- These four rows must remain in the final schema. quality_of_life.lua
    -- registers them before this full Ascendant schema is defined; omitting
    -- them here made untouched profiles resolve EASY INTERACTIONS to nil,
    -- even though its submenu displayed the intended ON default.
    { key = "qol_exp_bar",
      label = menuLabel("BATTLE EXP BAR", "EP-LEISTE"),
      type = "choice", default = "blue",
      choices = {
        { menuLabel("OFF", "AUS"), "off" },
        { menuLabel("ON (BLACK)", "AN (SCHWARZ)"), "black" },
        { menuLabel("ON (BLUE)", "AN (BLAU)"), "blue" },
      } },
    { key = "qol_caught_indicator",
      label = menuLabel("POKéDEX INDICATOR", "GEFANGEN-ICON"),
      type = "choice", default = "red",
      choices = {
        { menuLabel("OFF", "AUS"), "off" },
        { menuLabel("ON (GREY)", "AN (GRAU)"), "grey" },
        { menuLabel("ON (RED)", "AN (ROT)"), "red" },
      } },
    { key = "qol_easy_interactions",
      label = menuLabel("EASY INTERACTIONS", "EINFACHE INTERAKTION"),
      type = "toggle", default = true },
    { key = "qol_location_banners",
      label = menuLabel("LOCATION BANNERS", "ORTSBANNER"),
      type = "choice", default = 2,
      choices = {
        { menuLabel("OFF", "AUS"), false },
        { menuLabel("ON (1 SECOND)", "AN (1 SEKUNDE)"), 1 },
        { menuLabel("ON (2 SECONDS)", "AN (2 SEKUNDEN)"), 2 },
        { menuLabel("ON (3 SECONDS)", "AN (3 SEKUNDEN)"), 3 },
      } },
    { key = "modern_storage_ui",
      label = menuLabel("MENU SKINS MASTER", "MENÜ-DESIGN"),
      type = "toggle", default = true },
    { key = "pc_interface_style",
      label = menuLabel("PC INTERFACE", "PC-OBERFLÄCHE"),
      type = "choice", default = "firered",
      choices = {
        { "FIRERED / LEAFGREEN", "firered" },
        { "KANTO ASCENDANT", "ascendant" },
        { menuLabel("GAME DEFAULT", "SPIELSTANDARD"), "default" },
        { "FIRERED / LEAFGREEN WIDE", "firered_wide" },
      } },
    { key = "legacy_bank_interface_style",
      label = menuLabel("LEGACY BANK UI", "BANK-ANSICHT"),
      type = "choice", default = "follow_pc",
      choices = {
        { menuLabel("FOLLOW PC INTERFACE", "WIE PC"),
          "follow_pc" },
        { "FIRERED / LEAFGREEN", "firered" },
        { "KANTO ASCENDANT", "ascendant" },
        { "FIRERED / LEAFGREEN WIDE", "firered_wide" },
      } },
    { key = "catch_destination",
      label = menuLabel("CATCH DESTINATION", "FANGZIEL"),
      type = "choice", default = "ask",
      choices = {
        { menuLabel("ASK PARTY / BOX", "TEAM / BOX FRAGEN"), "ask" },
        { menuLabel("PARTY FIRST", "ZUERST TEAM"), "party" },
        { menuLabel("BOX FIRST", "ZUERST BOX"), "box" },
        { menuLabel("OFF", "AUS"), "off" },
      } },
    { key = "pokedex_filter",
      label = menuLabel("POKéDEX FILTER", "POKéDEX-FILTER"),
      type = "choice", default = "all",
      choices = {
        { menuLabel("ALL", "ALLE"), "all" },
        { menuLabel("SEEN", "GESEHEN"), "seen" },
        { menuLabel("OWNED", "BESITZT"), "owned" },
      } },
    { key = "box_filter",
      label = menuLabel("BOX FILTER", "BOX-FILTER"),
      type = "choice", default = "all",
      choices = {
        { menuLabel("ALL", "ALLE"), "all" },
        { menuLabel("KANTO ONLY", "NUR KANTO"), "kanto" },
        { menuLabel("JOHTO ONLY", "NUR JOHTO"), "johto" },
      } },
    { key = "text_speed",
      label = menuLabel("TEXT SPEED PRESET", "TEXTGESCHWINDIGKEIT"),
      type = "choice", default = "engine",
      choices = {
        { menuLabel("ENGINE OPTION", "ENGINE-EINSTELLUNG"), "engine" },
        { menuLabel("FAST", "SCHNELL"), "fast" },
        { menuLabel("NORMAL", "NORMAL"), "normal" },
        { menuLabel("SLOW", "LANGSAM"), "slow" },
      } },
    { key = "ride_control",
      label = menuLabel("LEGACY BICYCLE KEY", "ALTE FAHRRAD-TASTE"),
      type = "choice", default = "select",
      choices = {
        { menuLabel("SELECT USES BICYCLE", "SELECT NUTZT FAHRRAD"), "select" },
        { menuLabel("CLASSIC BAG ONLY", "NUR KLASSISCHER BEUTEL"), "classic" },
      } },
    { key = "quick_select_tap",
      label = menuLabel("DEFAULT FAVORITE", "START-FAVORIT"),
      type = "choice", default = "bicycle",
      choices = {
        { menuLabel("BICYCLE", "FAHRRAD"), "bicycle" },
        { menuLabel("FIELD KIT", "FELD-KIT"), "field_kit" },
        { menuLabel("NOTHING", "NICHTS"), "none" },
      } },
    { key = "quick_select_registration",
      label = menuLabel("BAG FAVORITE", "BEUTEL-FAVORIT"),
      type = "toggle", default = true },
    { key = "quick_select_empty_notice",
      label = menuLabel("EMPTY SLOT NOTICE", "LEERER-PLATZ-HINWEIS"),
      type = "toggle", default = true },
    { key = "catch_box_notice",
      label = menuLabel("BOX TRANSFER NOTICE", "BOX-TRANSFER-HINWEIS"),
      type = "toggle", default = true },
    { key = "status_values",
      label = menuLabel("STATUS VALUES", "STATUSWERTE"),
      type = "choice", default = "off",
      choices = {
        { menuLabel("OFF", "AUS"), "off" },
        { "DV / IV", "dv" },
        { "DV / IV AND EV", "full" },
      } },
    { key = "modern_ball_skins",
      label = menuLabel("MODERN BALL SKINS", "MODERNE BALL-SKINS"),
      type = "toggle", default = true },
    { key = "fast_box_switch",
      label = menuLabel("FAST BOX SWITCH", "SCHNELLER BOXWECHSEL"),
      type = "toggle", default = true },
    { key = "mythic_signals",
      label = menuLabel("MYTHIC SIGNALS", "MYTHOS-SIGNALE"),
      type = "toggle", default = true },
    { key = "legend_articuno", label = "ARTICUNO", type = "choice",
      default = "apex",
      choices = { { "APEX", "apex" }, { "VANILLA", "vanilla" },
                  { menuLabel("OFF", "AUS"), "off" } } },
    { key = "legend_zapdos", label = "ZAPDOS", type = "choice",
      default = "apex",
      choices = { { "APEX", "apex" }, { "VANILLA", "vanilla" },
                  { menuLabel("OFF", "AUS"), "off" } } },
    { key = "legend_moltres", label = "MOLTRES", type = "choice",
      default = "apex",
      choices = { { "APEX", "apex" }, { "VANILLA", "vanilla" },
                  { menuLabel("OFF", "AUS"), "off" } } },
    { key = "legend_mewtwo", label = "MEWTWO", type = "choice",
      default = "apex",
      choices = { { "APEX", "apex" }, { "VANILLA", "vanilla" },
                  { menuLabel("OFF", "AUS"), "off" } } },
    { key = "legend_raikou", label = "RAIKOU", type = "toggle", default = true },
    { key = "legend_entei", label = "ENTEI", type = "toggle", default = true },
    { key = "legend_suicune", label = "SUICUNE", type = "toggle", default = true },
    { key = "legend_lugia", label = "LUGIA", type = "toggle", default = true },
    { key = "legend_ho_oh", label = "HO-OH", type = "toggle", default = true },
    { key = "legend_celebi", label = "CELEBI", type = "toggle", default = true },
    { key = "legend_mew", label = "MEW", type = "toggle", default = true },
    { key = "mew_profile", label = menuLabel("MEW PROFILE", "MEW-PROFIL"),
      type = "choice", default = "ascendant",
      choices = {
        { menuLabel("ASCENDANT LV.100", "ASCENDANT LV.100"), "ascendant" },
        { menuLabel("HISTORICAL LV.5", "HISTORISCH LV.5"), "historical" },
      } },
    { key = "event_mode", label = menuLabel("HERITAGE EVENTS", "HERITAGE-EVENTS"),
      type = "choice", default = "festival",
      choices = {
        { menuLabel("FESTIVAL CUPS", "FESTIVAL-CUPS"), "festival" },
        { menuLabel("ROAMING HUNTS", "WANDERNDE JAGD"), "roaming" },
        { menuLabel("OFF", "AUS"), "off" },
      } },
    { key = "event_university_magikarp", label = "UNIV. MAGIKARP",
      type = "toggle", default = true },
    { key = "event_stamp_fearow", label = "STAMP FEAROW",
      type = "toggle", default = true },
    { key = "event_flying_pikachu", label = "FLYING PIKACHU",
      type = "toggle", default = true },
    { key = "event_stamp_rapidash", label = "STAMP RAPIDASH",
      type = "toggle", default = true },
    { key = "event_surfing_pikachu", label = "SURFING PIKACHU",
      type = "toggle", default = true },
    { key = "event_flee", label = menuLabel("ROAMERS CAN FLEE", "WANDERER FLIEHEN"),
      type = "toggle", default = true },
    { key = "event_rosette", label = menuLabel("EVENT ROSETTE", "EVENT-ROSETTE"),
      type = "toggle", default = true },
    { key = "gift_codes_enabled",
      label = menuLabel("GIFT CODES", "GESCHENKCODES"),
      type = "toggle", default = true },
    { key = "rocket_story", label = menuLabel("ROCKET STORY", "ROCKET-STORY"),
      type = "toggle", default = true },
    { key = "rocket_raids",
      label = menuLabel("ROCKET RECOVERY", "ROCKET-RÜCKHOLUNG"),
      type = "toggle", default = true },
    { key = "late_species_67",
      label = menuLabel("LATE SPECIES", "SPÄT-ARTEN"),
      type = "toggle", default = true },
    { key = "fairy_affection_67",
      label = menuLabel("FAIRY EVOLUTION", "FEEN-ENTWICKLUNG"),
      type = "toggle", default = true },
    { key = "grand_tournament",
      label = menuLabel("BATTLE FRONTIER", "KAMPF-FRONTIER"),
      type = "toggle", default = true },
    { key = "life_of_rival",
      label = menuLabel("A RIVAL'S LIFE", "RIVALENLEBEN"),
      type = "toggle", default = true },
    { key = "follower_count",
      label = menuLabel("FOLLOWER COUNT", "BEGLEITER-ANZAHL"),
      type = "choice", default = 1,
      choices = {
        { "1", 1 }, { "2", 2 }, { "3", 3 },
        { "4", 4 }, { "5", 5 }, { "6", 6 },
      } },
    { key = "follower_order",
      label = menuLabel("FOLLOWER ORDER", "BEGLEITER-FOLGE"),
      type = "choice", default = "party",
      choices = {
        { menuLabel("PARTY", "TEAM"), "party" },
        { "CUSTOM", "custom" },
      } },
    { key = "ascendant_rules",
      label = menuLabel("CHALLENGE RULES", "CHALLENGE-REGELN"),
      type = "choice", default = "rotating",
      choices = {
        { menuLabel("ROTATING", "ROTIEREND"), "rotating" },
        { menuLabel("NO ITEMS", "KEINE ITEMS"), "ascendant" },
        { menuLabel("NORMAL", "NORMAL"), "normal" },
      } },
  }
  -- The engine option schema has no dynamic row predicate. Build the schema
  -- edition-aware instead so Red and Blue do not carry a dead Yellow-only
  -- setting while Yellow still gets the normal one-row option control.
  if GameVersion.isYellow() then
    ascendantOptionSchema[#ascendantOptionSchema + 1] = {
      key = "yellow_partner_presentation",
      label = menuLabel("YELLOW PARTNER UI", "YELLOW-PARTNER-UI"),
      type = "choice", default = "ascendant_box",
      choices = {
        { menuLabel("ASCENDANT BOX", "ASCENDANT-BOX"), "ascendant_box" },
        { menuLabel("YELLOW CENTER", "YELLOW-ZENTRUM"), "yellow_center" },
      },
    }
    ascendantOptionSchema[#ascendantOptionSchema + 1] = {
      key = "yellow_raichu_face_style",
      label = menuLabel("RAICHU FACES", "RAICHU-MIMIK"),
      type = "choice", default = "ascendant",
      choices = {
        { menuLabel("ASCENDANT", "ASCENDANT"), "ascendant" },
        { menuLabel("CLASSIC YELLOW", "KLASSISCH GELB"), "classic_yellow" },
      },
    }
  end
  idMigration.applyOptionDefaults(ascendantOptionSchema)
  mod.options:define(ascendantOptionSchema)
  mod.exports.legacy65CardInventory = loadSibling(
    mod, "legacy_65_card_inventory.lua")(mod, {
      supportLog=mod.exports.supportSessionLog,
    })
  mod.exports.hoennOptionalCards67 = loadSibling(
    mod, "hoenn_optional_cards_67.lua")(mod, {
      supportLog = mod.exports.supportSessionLog,
    })
  -- One save-local authority controls the active type, species and legal
  -- move epoch. AUTO follows authenticated progression; manual downgrades
  -- preserve newer moves losslessly on the Pokemon itself.
  mod.exports.generationTypeProjection = loadSibling(
    mod, "generation_type_projection.lua")
  mod.exports.generationMoveCatalog67Data = loadSibling(
    mod, "generation_move_catalog_67_data.lua")
  mod.exports.generationLearnsets67Data = loadSibling(
    mod, "generation_learnsets_67_data.lua")
  mod.exports.generationMachines67Data = loadSibling(
    mod, "generation_machines_67_data.lua")
  mod.exports.generationEvidence = loadSibling(
    mod, "generation_evidence.lua")(mod)
  mod.exports.generationMigration = loadSibling(
    mod, "generation_migration.lua")(mod)
  mod.exports.generationMoveMemory = loadSibling(
    mod, "generation_move_memory.lua")(mod)
  mod.exports.generationRulesReceipts = loadSibling(
    mod, "generation_rules_receipt.lua")(mod)
  mod.exports.generationRules = loadSibling(mod, "generation_rules.lua")(
    mod, {
      evidence = mod.exports.generationEvidence,
      migration = mod.exports.generationMigration,
      moveMemory = mod.exports.generationMoveMemory,
      typeProjection = mod.exports.generationTypeProjection,
      receipts = mod.exports.generationRulesReceipts,
      moveCatalog = mod.exports.generationMoveCatalog67Data,
      supportLog = mod.exports.supportSessionLog,
    })
  mod.exports.generationCheckpoint67 = loadSibling(mod, "generation_checkpoint_67.lua")(
    mod, { rules = mod.exports.generationRules, supportLog = mod.exports.supportSessionLog })
  mod.exports.difficultyTeamContracts67 = loadSibling(
    mod, "difficulty_team_contracts_67.lua")(mod, {
      generationRules = mod.exports.generationRules,
      supportLog = mod.exports.supportSessionLog,
    })
  assert(mod.exports.rivalTeams.setDifficultyContracts(
    mod.exports.difficultyTeamContracts67),
    "rival difficulty-contract binding failed")
  assert(mod.exports.hoennFieldAccess.setGenerationRules(
    mod.exports.generationRules),
    "Hoenn field access generation-rules binding failed")
  assert(legacyWanderers.setGenerationRules(mod.exports.generationRules),
    "Legacy Wanderers generation-rules binding failed")
  assert(restProfiles.install(mod))
  mod.exports.migrateRestProfileOptions = function(game, fresh)
    return restProfiles.migrateGameOptions(mod.id, game, fresh)
  end

  local makeOptionHelp = loadSibling(mod, "option_help.lua")
  local optionHelp = makeOptionHelp(i18n)
  mod.exports.classicLink = loadSibling(mod, "classic_link.lua")(mod, {
    i18n = i18n,
    generationRules = mod.exports.generationRules,
    wireAdapter = loadSibling(mod, "classic_link_wire_67.lua")(),
  })
  assert(mod.exports.classicLink.installUi(ascendantUi))
  local makeRematchRewards = loadSibling(mod, "rematch_rewards.lua")
  local rematchRewards = makeRematchRewards(mod, {
    i18n = i18n,
    loot = loot,
    optionSchema = ascendantOptionSchema,
    optionHelp = optionHelp,
    ascendantUi = ascendantUi,
    legacyWanderers = legacyWanderers,
    hoennFieldAccess = mod.exports.hoennFieldAccess,
    restProfiles = restProfiles,
    classicLink = mod.exports.classicLink,
    generationRules = mod.exports.generationRules,
  })
  mod.exports.rematchRewards = rematchRewards
  mod.exports.optionHelp = optionHelp
  local makeItemHelp = loadSibling(mod, "item_help.lua")
  local itemHelp = makeItemHelp(i18n)
  local makeAscendantBag = loadSibling(mod, "ascendant_bag.lua")
  local ascendantBag = makeAscendantBag(mod, {
    ui = ascendantUi,
    itemHelp = itemHelp,
  })
  mod.exports.itemHelp = itemHelp
  mod.exports.ascendantBag = ascendantBag

  -- Ascendant's bag owns the screen while enabled, even when the standalone
  -- Useful Bag is installed. Turning this option off restores the standalone
  -- mod; its optional dependency loads before Ascendant.
  local bagMode
  if mod.options:get("ascendant_useful_bag") == false then
    bagMode = "off"
  else
    bagMode = mod.options:get("ascendant_bag_mode") or "pockets"
  end
  if bagMode == "expanded" or bagMode == "pockets" then
    mod.content.constants:patch("bagSize", 999)
  end
  if bagMode == "pockets" then
    local installBag = loadSibling(mod, "useful_bag.lua")
    if type(installBag) == "function" then
      installBag(mod, { i18n = i18n })
    end
    mod.exports.externalUsefulBag = false
  elseif bagMode ~= "off" then
    -- Reclaim the Bag screen from an installed standalone Useful Bag while
    -- any Ascendant mode is selected. "OFF / EXTERNAL" below is the single
    -- explicit hand-off back to the external mod.
    -- BagMenu may already be owned by the standalone Useful Bag, which
    -- loads first through our optional dependency.  Re-enabling Ascendant
    -- after a mod-off save must reclaim that existing id explicitly;
    -- register() treats the second owner as a fatal duplicate and prevents
    -- SaveData from restoring quarantined Pokémon and items.
    mod.content.screens:override("BagMenu", {
      new = function(game, opts)
        return require("src.ui.BagMenu").new(game, opts)
      end,
    })
    mod.exports.externalUsefulBag = false
  else
    mod.exports.externalUsefulBag = installedMod("useful_bag")
  end
  local installAscendantFeatures =
    loadSibling(mod, "ascendant_features.lua")
  if type(installAscendantFeatures) == "function" then
    mod.exports.ascendantFeatures = installAscendantFeatures(mod, {
      optionHelp = optionHelp,
      i18n = i18n,
    })
  end

  -- 6.5 QoL is bundled, but an installed standalone mod owns the same UI
  -- surface.  Defer detection until the loader has resolved all manifests,
  -- then install only the features that do not have an external owner.
  mod.events:once("mods.loaded", function()
    -- KASC owns this local lifecycle; VASC exposes only the public PokemonUi
    -- Host-v1 capability it consumes.  The card performs no save/story work
    -- and remains a fail-open optional presentation binding.
    local makeVascLegacyBankCard = loadSibling(
      mod, "vasc_legacy_bank_card.lua")
    local vascLegacyBankCard = makeVascLegacyBankCard(mod)
    local installStorage = loadSibling(mod, "modern_storage_ui.lua")
    if type(installStorage) == "function" then
      installStorage(mod, {
        i18n = i18n,
        vascLegacyBankCard = vascLegacyBankCard,
      })
    end
    local installCatchDestination = loadSibling(mod, "catch_destination.lua")
    if type(installCatchDestination) == "function" then
      installCatchDestination(mod, { i18n = i18n })
    end
    local installFilters = loadSibling(mod, "storage_filters.lua")
    if type(installFilters) == "function" then installFilters(mod) end
    local installPokedexAreaCompat = loadSibling(mod,
      "pokedex_area_compat.lua")
    if type(installPokedexAreaCompat) == "function" then
      local makeAreaHabitats = loadSibling(mod,
        "pokedex_area_habitats.lua")
      mod.exports.pokedexAreaHabitats = makeAreaHabitats(mod)
      local ok, why = installPokedexAreaCompat({
        habitatsFor = mod.exports.pokedexAreaHabitats,
      })
      assert(ok, why)
    end
    local installTextSpeed = loadSibling(mod, "text_speed.lua")
    if type(installTextSpeed) == "function" then installTextSpeed(mod) end
    -- Party icons are installed below after the follower registries exist;
    -- the animated renderer requires those registries as explicit inputs.
    local installCapturePreview = loadSibling(mod, "capture_preview.lua")
    if type(installCapturePreview) == "function" then
      installCapturePreview(mod)
    end
    local installSummaryInsights = loadSibling(mod, "summary_insights.lua")
    if type(installSummaryInsights) == "function" then
      installSummaryInsights(mod, { i18n = i18n })
    end
    local installModernBalls = loadSibling(mod, "modern_ball_skins.lua")
    if type(installModernBalls) == "function" then installModernBalls(mod) end
  end)

  -- The German translation packs currently ship a misaligned category
  -- table: Mew and Mewtwo both end up labelled "VOGEL".  Ascendant uses
  -- both species in authored encounters, so restore their canonical Dex
  -- categories in our later content layer instead of exposing the broken
  -- external mapping.  Keep the original Gen-I English spelling
  -- "NEW SPECIE"; "NEUE ART" is its official compact German counterpart.
  local dexKindCompat = {
    MEW = { en = "NEW SPECIE", de = "NEUE ART" },
    MEWTWO = { en = "GENETIC", de = "GENMUTANT" },
  }
  if i18n.isGerman() then
    local germanKinds = loadSibling(mod, "german_dex_kinds.lua")
    for species, kind in pairs(germanKinds) do
      dexKindCompat[species] = { en = kind, de = kind }
    end
    -- Keep the original preset spelling. Player names are data, not words
    -- to translate; in particular ASH must never be rewritten by a locale.
    mod.content.field:patch("boot", {
      namePresets = {
        player = { "RED", "ASH", "JACK" },
        rival = { "BLUE", "GARY", "JOHN" },
      },
    })
  end
  for species, labels in pairs(dexKindCompat) do
    if mod.content.pokemon:get(species) then
      mod.content.pokemon:patch(species, {
        dexEntry = { kind = i18n.isGerman() and labels.de or labels.en },
      })
    end
  end
  mod.exports.dexKindCompat = dexKindCompat

  local function localizedLine(classId)
    return i18n.rematch(classId, resolveLine(classId))
  end
  local function localizedDecline(classId)
    return i18n.decline(classId, resolveDecline(classId))
  end
  local function localizedWarning(classId)
    return i18n.warning(classId, resolveWarning(classId))
  end
  local function localizedRestLine(steps)
    return i18n.rest(steps, restLine(steps))
  end

  -- The major post-game expansion lives in focused modules so the original
  -- field-trainer rematch path stays small and backwards-compatible.
  local postgameData = loadSibling(mod, "postgame_data.lua")
  postgameData.dialogue = loadSibling(mod, "postgame_dialogue.lua")
  local johtoData = loadSibling(mod, "johto_data.lua")
  -- One save-local, irreversible boundary owns every transition away from the
  -- original 151. Keep it on exports to avoid another top-level LuaJIT local.
  mod.exports.beyondKanto = loadSibling(mod, "johto_unleashed.lua")(mod, {
    i18n = i18n, johtoData = johtoData,
    generationRules = mod.exports.generationRules,
  })
  mod.exports.generationRules.setCurrentDataProvider(function(game, epoch)
    local active, migrated, witness = mod.exports.beyondKanto.sync(
      game, game and game.save, "generation-profile-sync")
    if mod.exports.starterSpecies67
        and type(mod.exports.starterSpecies67.refreshMoves) == "function" then
      mod.exports.starterSpecies67.refreshMoves(game, epoch)
    end
    if mod.exports.generationLearnsets67
        and type(mod.exports.generationLearnsets67.apply) == "function" then
      mod.exports.generationLearnsets67.apply(game, epoch)
    end
    return active, migrated, witness
  end)
  legacyWanderers.setBeyondKantoBoundary(mod.exports.beyondKanto)
  if legacyJourney.archive and legacyJourney.archive.setWithdrawalGate then
    legacyJourney.archive.setWithdrawalGate(function(save, mon)
      return mod.exports.beyondKanto.canWithdrawMon(save, mon)
    end)
  end
  local makeAscendantMenu = loadSibling(mod, "ascendant_menu.lua")
  local ascendantMenu = makeAscendantMenu(mod, {
    i18n = i18n,
    ascendantUi = ascendantUi,
    supportLog = mod.exports.supportSessionLog,
  })
  mod.exports.ascendantMenu = ascendantMenu
  local makeSpriteAssets = loadSibling(mod, "sprite_assets.lua")
  local spriteAssets = makeSpriteAssets(mod)
  mod.exports.spriteAssets = spriteAssets
  for _, species in ipairs(johtoData.order) do
    CRYSTAL_ASSETS[species] = species:lower()
  end
  CRYSTAL_ASSETS.HO_OH = "ho_oh"
  local registerSpecies = loadSibling(mod, "postgame_species.lua")
  local contentEnabled, johtoAudio =
    registerSpecies(mod, postgameData, johtoData, i18n)
  mod.exports.johtoAudio = johtoAudio
  local legacyHoenn = loadSibling(mod, "legacy_hoenn.lua")(mod, { i18n = i18n })
  mod.exports.legacyHoenn = legacyHoenn
  mod.exports.legacyRandomPartners67 = loadSibling(
    mod, "legacy_random_partners_67.lua")(mod, {
      supportLog = mod.exports.supportSessionLog,
    })
  local hevoSpeciesData = loadSibling(mod, "hevo_species_data.lua")
  -- Existing HEVO content uses this package registry as its source of truth.
  -- Store it on exports so this dense factory gains no additional local.
  mod.exports.hevoPackages = loadSibling(mod, "hevo_packages.lua")(mod, {
    i18n = i18n, enabled = contentEnabled, journey = legacyJourney,
    beyondKanto = mod.exports.beyondKanto,
    generationRules = mod.exports.generationRules,
  })
  mod.exports.eeveeFieldSpots67 = loadSibling(
    mod, "eevee_field_spots_67.lua")(mod, {
      packages = mod.exports.hevoPackages,
    })
  local hevoSpecies = loadSibling(mod, "hevo_species.lua")(mod, {
    i18n = i18n, data = hevoSpeciesData, packages = mod.exports.hevoPackages,
    enabled = contentEnabled,
  })
  mod.exports.hevoSpecies = hevoSpecies
  mod.exports.extendedSpeciesRuntime = loadSibling(mod, "extended_species_runtime.lua")(mod, {
    legacyHoenn = legacyHoenn,
    hevoSpecies = hevoSpecies,
    hevoData = hevoSpeciesData,
  })
  if spriteAssets.setExtendedSpeciesRuntime then
    spriteAssets.setExtendedSpeciesRuntime(mod.exports.extendedSpeciesRuntime)
  end
  local legacyStarters = loadSibling(mod, "legacy_starters.lua")(mod, {
    i18n = i18n, journey = legacyJourney, hoenn = legacyHoenn,
    rival = mod.exports.legacyRivalPartner, johto = johtoData,
    beyondKanto = mod.exports.beyondKanto,
    hoennAcquisition = mod.exports.hoennAcquisition67Data,
    randomPartners = mod.exports.legacyRandomPartners67,
  })
  mod.exports.legacyStarters = legacyStarters
  assert(mod.exports.hoennFieldAccess.setLegacyStarters(legacyStarters),
    "Hoenn field access needs Legacy starter authority")
  assert(mod.exports.hoennFieldAccess.setLegacyProgression(legacyJourney),
    "Hoenn field access needs Legacy progression authority")
  local registerGorochu = loadSibling(mod, "gorochu.lua")
  local gorochu = registerGorochu(mod, { i18n = i18n })
  if gorochu.available then CRYSTAL_ASSETS.GOROCHU = "gorochu" end
  mod.exports.gorochu = gorochu
  local makeKantoCompletion = loadSibling(mod, "kanto_completion.lua")
  local kantoCompletion = makeKantoCompletion(mod, {
    i18n = i18n,
    contentEnabled = contentEnabled,
    legacyJourney = legacyJourney,
    gameVersion = GameVersion,
  })
  mod.exports.kantoCompletion = kantoCompletion
  local makeFieldTech = loadSibling(mod, "field_tech.lua")
  local fieldTech = makeFieldTech(mod, {
    i18n = i18n,
    contentEnabled = contentEnabled,
    generationRules = mod.exports.generationRules,
  })
  mod.exports.fieldTech = fieldTech
  mod.exports.generationMoveCatalog67 = loadSibling(
    mod, "generation_move_catalog_67.lua")(mod, {
      data = mod.exports.generationMoveCatalog67Data,
      i18n = i18n,
    })
  mod.exports.generationMachines67 = loadSibling(
    mod, "generation_machines_67.lua")(mod, {
      data = mod.exports.generationMachines67Data,
      generationRules = mod.exports.generationRules,
    })
  assert(fieldTech.setGenerationMachines(mod.exports.generationMachines67),
    "generation machine archive binding failed")
  if mod.exports.hevoPackages and mod.exports.hevoPackages.attachFieldTech then
    assert(mod.exports.hevoPackages.attachFieldTech(fieldTech))
  end
  mod.exports.hoennRoamers67 = loadSibling(mod, "hoenn_roamers_67.lua")(
    mod, { fieldAccess = mod.exports.hoennFieldAccess, i18n = i18n })
  local makePostgameEvents = loadSibling(mod, "postgame_events.lua")
  local makePostgame = loadSibling(mod, "postgame.lua")
  local postgame = makePostgame(mod, postgameData, {
    contentEnabled = contentEnabled,
    i18n = i18n,
    makeEvents = makePostgameEvents,
    fieldTech = fieldTech,
    kantoCompletion = kantoCompletion,
    gorochu = gorochu,
    rematchRewards = rematchRewards,
    restProfiles = restProfiles,
    beyondKanto = mod.exports.beyondKanto,
    rivalIdentity = function()
      return extendedCharacters.getRivalCharacter()
    end,
  })
  mod.exports.postgame = postgame
  -- The four native depots and their rewards are registered before the
  -- content graph freezes. Generation-aware TM selection fails closed to the
  -- Gen-I pool until a later generation-rules owner is present.
  mod.exports.rocketRecoveryRaids67Data = loadSibling(
    mod, "rocket_recovery_raids_67_data.lua")
  mod.exports.rocketRecoveryRewards67 = loadSibling(
    mod, "rocket_recovery_rewards_67.lua")(mod, {
      data = mod.exports.rocketRecoveryRaids67Data,
      equipmentRewards = mod.exports.equipmentRewards67,
      generationRules = mod.exports.generationRules,
    })
  mod.exports.rocketRecoveryRaids67 = loadSibling(
    mod, "rocket_recovery_raids_67.lua")(mod, {
      sources = mod.exports.rocketRecoverySources67,
      generationRules = mod.exports.generationRules,
      data = mod.exports.rocketRecoveryRaids67Data,
      supportLog = mod.exports.supportSessionLog,
      captureAvailable = function(game, row)
        local provider = mod.exports.lateSpecies67
        return provider ~= nil
          and type(provider.raidCaptureAvailable) == "function"
          and provider.raidCaptureAvailable(game, row) == true
      end,
    })
  mod.exports.rocketRecoveryRaids67.bindRewards({
    awardPlan = function(game, key, plan)
      return mod.exports.rocketRecoveryRewards67.awardPlan(game, key, plan)
    end,
  })
  mod.exports.rocketRecoveryRaids67Content = loadSibling(
    mod, "rocket_recovery_raids_67_content.lua")(mod, {
      maps = loadSibling(mod, "rocket_recovery_raids_67_maps.lua"),
      data = mod.exports.rocketRecoveryRaids67Data,
    })
  assert(mod.exports.rocketRecoveryRaids67Content.register())
  mod.exports.rocketRecoveryRaids67Runtime = loadSibling(
    mod, "rocket_recovery_raids_67_runtime.lua")(mod, {
      raids = mod.exports.rocketRecoveryRaids67,
      data = mod.exports.rocketRecoveryRaids67Data,
      maps = mod.exports.rocketRecoveryRaids67Content.maps,
      content = mod.exports.rocketRecoveryRaids67Content,
      postgame = postgame,
      i18n = i18n,
      generationRules = mod.exports.generationRules,
    })
  mod.exports.postgameData = postgameData
  mod.exports.johtoData = johtoData
  local breedingData = loadSibling(mod, "breeding_data.lua")
  local eggMoves = loadSibling(mod, "egg_moves.lua")
  mod.exports.generationLearnsets67 = loadSibling(
    mod, "generation_learnsets_67.lua")(mod, {
      data = mod.exports.generationLearnsets67Data,
      generationRules = mod.exports.generationRules,
      eggMoves = eggMoves,
      fieldTech = fieldTech,
    })
  mod.exports.surpriseTeamFairness67 = loadSibling(
    mod, "surprise_team_fairness_67.lua")(mod, {
      learnsets = mod.exports.generationLearnsets67,
      generationRules = mod.exports.generationRules,
    })
  assert(legacyWanderers.setFairnessProvider(
    mod.exports.surpriseTeamFairness67))
  mod.exports.generationBattleGate67 = loadSibling(
    mod, "generation_battle_gate_67.lua")(mod, {
      generationRules = mod.exports.generationRules,
      i18n = i18n,
      equipmentCheckpoint = function(game)
        local equipment = mod.exports.pokemonEquipment67
        if equipment then return equipment.checkpoint(game) end
      end,
    })
  -- KASC-66-HOENN-DEX-252-386: reuse the fifteen established owners and
  -- register only the 120 still-missing identities.  Canonical Hoenn
  -- #261-279 receive collision-safe runtime ids because that range already
  -- belongs to the private HEVO catalogue in 6.6 saves.
  mod.exports.hoennSpecies67Data = loadSibling(
    mod, "hoenn_species_67_data.lua")
  mod.exports.hoennDexCompletion67 = loadSibling(
    mod, "hoenn_dex_completion_67.lua")(mod, {
      data = mod.exports.hoennSpecies67Data,
      journey = legacyJourney,
      generationRules = mod.exports.generationRules,
      bankBridge = function() return mod.exports.legacyBankBridge end,
    })
  mod.exports.hoennSpecies67RuntimeData = loadSibling(
    mod, "hoenn_species_67_runtime_data.lua")
  mod.exports.hoennSpecies67 = loadSibling(mod, "hoenn_species_67.lua")(
    mod, {
      data = mod.exports.hoennSpecies67Data,
      runtimeData = mod.exports.hoennSpecies67RuntimeData,
      breedingData = breedingData,
      eggMoves = eggMoves,
      hevoPackages = mod.exports.hevoPackages,
      i18n = i18n,
      enabled = contentEnabled,
    })
  mod.exports.legacyGlobalBabies67Data = loadSibling(
    mod, "legacy_global_babies_67_data.lua")
  mod.exports.legacyGlobalBabies67 = loadSibling(
    mod, "legacy_global_babies_67.lua")(mod, {
      data = mod.exports.legacyGlobalBabies67Data,
      generationRules = mod.exports.generationRules,
      i18n = i18n,
      supportLog = mod.exports.supportSessionLog,
    })
  assert(legacyStarters.setGlobalBabyProvider(
    mod.exports.legacyGlobalBabies67))
  mod.exports.hoennEndgameRunEvents67 = loadSibling(
    mod, "hoenn_endgame_run_events_67.lua")(mod)
  mod.exports.hoennEndgameEditorGeometry67 = loadSibling(
    mod, "hoenn_endgame_editor_geometry_67.lua")
  mod.exports.hoennEndgameTilesets67 = loadSibling(
    mod, "hoenn_endgame_tilesets_67.lua")(mod, {
      json = loadSibling(mod, "world_rank_json.lua"),
    })
  if contentEnabled then assert(mod.exports.hoennEndgameTilesets67.register()) end
  mod.exports.hoennResearchSanctums67 = loadSibling(
    mod, "hoenn_research_sanctums_67.lua")(mod, {
      dex = mod.exports.hoennDexCompletion67,
      generationRules = mod.exports.generationRules,
      fieldAccess = mod.exports.hoennFieldAccess,
      runEvents = mod.exports.hoennEndgameRunEvents67,
      postgame = postgame,
      geometry = mod.exports.hoennEndgameEditorGeometry67,
      fieldTech = fieldTech,
      i18n = i18n,
    })
  if contentEnabled then
    assert(mod.exports.hoennResearchSanctums67.register())
  end
  mod.exports.hoennMoltresVolcano67 = loadSibling(
    mod, "hoenn_moltres_volcano_67.lua")(mod, {
      postgame = postgame,
      runEvents = mod.exports.hoennEndgameRunEvents67,
      geometry = mod.exports.hoennEndgameEditorGeometry67,
      volcanoTileset = mod.exports.hoennEndgameTilesets67.VOLCANO_ID,
      regirockComplete = function(game)
        return mod.exports.hoennResearchSanctums67
          and mod.exports.hoennResearchSanctums67.eventComplete(game,"REGIROCK")
      end,
      i18n = i18n,
    })
  if contentEnabled then assert(mod.exports.hoennMoltresVolcano67.register()) end
  mod.exports.hoennBattleSurrounds67 = loadSibling(
    mod, "hoenn_battle_surrounds_67.lua")(mod)
  -- Register the map-only letterbox after the load set is complete; game.ready
  -- below supplies the live stack so battles and menus can be excluded.
  mod.events:once("mods.loaded", function()
    if contentEnabled and mod.exports.hoennBattleSurrounds67 then
      assert(mod.exports.hoennBattleSurrounds67.install())
    end
  end)
  local pokemonGender = loadSibling(mod, "pokemon_gender.lua")(mod, {
    breedingData = breedingData,
    voxelRenderer = mod.exports.voxelRendererCompat,
  })
  mod.exports.pokemonGender = pokemonGender
  -- P1 Apricorn Balls are installed here (after the canonical Gen-II gender
  -- source is available, before the loader freezes item/ball registries).
  -- They use the regular battle, bag, PC and save paths; no parallel capture
  -- UI or inventory is introduced.
  do
    local makeApricornBalls = loadSibling(mod, "apricorn_balls.lua")
    local apricornBalls = makeApricornBalls(mod, {
      i18n = i18n,
      breedingData = breedingData,
      pokemonGender = pokemonGender,
      speciesData = loadSibling(mod, "apricorn_ball_data.lua"),
      itemEffects = require("src.inventory.ItemEffects"),
    })
    apricornBalls.install()
    mod.exports.apricornBalls = apricornBalls
    -- Replaces the existing procedural modern-ball raster bridge with the
    -- imported Journeys/Essentials masters. The module is visual-only.
    loadSibling(mod, "journeys_ball_skins.lua")(mod)
  end
  local eggHatchAnimation = loadSibling(mod, "egg_hatch_animation.lua")(mod, {
    i18n = i18n,
  })
  mod.exports.eggHatchAnimation = eggHatchAnimation
  local makeDaycare = loadSibling(mod, "daycare.lua")
  local daycare = makeDaycare(mod, {
    postgame = postgame,
    i18n = i18n,
    contentEnabled = contentEnabled,
    breedingData = breedingData,
    eggMoves = eggMoves,
    pokemonGender = pokemonGender,
    hatchAnimation = eggHatchAnimation,
    abilities = function() return mod.exports.pokemonAbilityBinding67 end,
    giftEggAllowed = function(game,mon)
      local archive=mod.exports.eventArchive
      return archive and archive.giftEggHatchAllowed(mon) or false
    end,
    fieldTech = fieldTech,
    hevoPackages = mod.exports.hevoPackages,
    beyondKanto = mod.exports.beyondKanto,
    generationRules = mod.exports.generationRules,
  })
  local makeMegaEvolution = loadSibling(mod, "mega_evolution.lua")
  local megaAnimationData = loadSibling(mod, "mega_animation_data.lua")
  local megaEvolution = makeMegaEvolution(mod, {
    postgame = postgame,
    i18n = i18n,
    contentEnabled = contentEnabled,
    animationData = megaAnimationData,
    voxelRenderer = mod.exports.voxelRendererCompat,
    linkPolicy = mod.exports.classicLink,
  })
  daycare.setMega(megaEvolution)
  local makeShinySystem = loadSibling(mod, "shiny_system.lua")
  local shinySystem = makeShinySystem(mod, {
    postgame = postgame,
    i18n = i18n,
  })
  local makeGorochuVisuals = loadSibling(mod, "gorochu_visuals.lua")
  local gorochuVisuals = makeGorochuVisuals(mod, {
    species = gorochu.id,
    shinySystem = shinySystem,
    voxelRenderer = mod.exports.voxelRendererCompat,
  })
  mod.exports.gorochuVisuals = gorochuVisuals
  local gorochuCatalogueOverlay = loadSibling(
    mod, "gorochu_catalogue_overlay.lua"
  )(mod, {
    species = gorochu.id,
    shinySystem = shinySystem,
    visuals = gorochuVisuals,
  })
  gorochuCatalogueOverlay.register()
  mod.exports.gorochuCatalogueOverlay = gorochuCatalogueOverlay
  -- Reviewed DRAMALESS 1.6.2-ST.190.1 and Battle Art 1.9.0/1.9.2 predate a
  -- native wall-decal module. Keep HEVO's fissures bound to real wall planes
  -- without modifying either separately installed renderer; future/native
  -- support wins.
  mod.exports.rendererWallDecalsCompat = loadSibling(
    mod, "dramaless_wall_decals_compat.lua")(mod, {
      voxelRenderer = mod.exports.voxelRendererCompat,
    })
  -- Backward-compatible diagnostic name for existing QA/support tooling.
  mod.exports.dramalessWallDecalsCompat =
    mod.exports.rendererWallDecalsCompat
  local trueColorWorldCompat = loadSibling(mod,
    "truecolor_world_compat.lua")()
  mod.exports.trueColorWorldCompat = trueColorWorldCompat
  -- Load the Gen-IV--VII starter catalogue before the animation controller
  -- scans its guest identities. Registration follows immediately after that
  -- controller is built, still before the engine freezes content.
  mod.exports.starterSpecies67Data = loadSibling(
    mod, "starter_species_67_data.lua")
  mod.exports.fairyAffection67Data = loadSibling(
    mod, "fairy_affection_67_data.lua")
  mod.exports.lateSpecies67Data = loadSibling(
    mod, "late_species_67_data.lua")
  mod.exports.starterRuntimeDexes = (function()
    local guests = {}
    for _, species in ipairs(mod.exports.starterSpecies67Data.order or {}) do
      local row = mod.exports.starterSpecies67Data.species[species]
      assert(row and tonumber(row.sourceDex),
        "starter runtime animation dex missing: " .. tostring(species))
      guests[tonumber(row.sourceDex)] = true
    end
    return guests
  end)()
  mod.exports.lateSpeciesRuntimeDexes = (function()
    local guests = {}
    for _, species in ipairs(mod.exports.lateSpecies67Data.order or {}) do
      local row = mod.exports.lateSpecies67Data.species[species]
      assert(row and tonumber(row.dex),
        "late species runtime animation dex missing: " .. tostring(species))
      guests[tonumber(row.dex)] = true
    end
    return guests
  end)()
  local crystalAnimationData = loadSibling(mod, "crystal_animation_data.lua")
  crystalAnimationData.grayscale = loadSibling(
    mod, "crystal_animation_data_grayscale.lua")
  -- The filenames and 7000-range IDs retain their audited source lineage;
  -- ownership and release metadata belong to the selected 6.6 Alola segment.
  mod.exports.alolaGiftForms66Data = loadSibling(
    mod, "alola_forms_67_data.lua")
  local function readOptionalAnimationData(filename)
    local body = mod:read(filename)
    if not body then return {} end
    local chunk, err = loadstring(body, "@" .. mod.path .. "/" .. filename)
    assert(chunk, err)
    return chunk()
  end
  -- Fail closed for older/sparse package mirrors: the base mod still boots
  -- with reviewed static cards if this optional authored-motion table was
  -- omitted. Release/package gates require it in the 6.5 artifact.
  local extendedCrystalAnimationData = readOptionalAnimationData(
    "extended_crystal_animation_data.lua")
  -- All #252-386 front/back normal/shiny Emerald clocks are merged into the
  -- existing animation controller; no second battle renderer is introduced.
  extendedCrystalAnimationData.emeraldHoenn = loadSibling(
    mod, "emerald_hoenn_animation_data.lua")
  extendedCrystalAnimationData.starterFamilies = loadSibling(
    mod, "starter_animation_data.lua")
  extendedCrystalAnimationData.fairyAffection = loadSibling(
    mod, "fairy_affection_animation_data.lua")
  extendedCrystalAnimationData.lateSpecies = loadSibling(
    mod, "late_species_animation_data.lua")
  local nonCrystalHdAnimationData = loadSibling(
    mod, "non_crystal_hd_animation_data.lua")
  nonCrystalHdAnimationData = loadSibling(mod,"authored_crystal_library_67.lua")(
    nonCrystalHdAnimationData,loadSibling(mod,"authored_crystal_67_data.lua"),"voxel")
  mod.exports.finalCrystalArt67={data=loadSibling(mod,"final_crystal_art_67_data.lua"),
    merge=loadSibling(mod,"final_crystal_art_67.lua")}
  nonCrystalHdAnimationData=mod.exports.finalCrystalArt67.merge(
    nonCrystalHdAnimationData,mod.exports.finalCrystalArt67.data,"voxel")
  local nonCrystalPixel2DData = loadSibling(
    mod, "non_crystal_pixel_2d_data.lua")
  local classic2DGen2ifiedData = loadSibling(
    mod, "classic_2d_gen2ified_data.lua")
  -- The separate sprite-catalog task supplies a complete canonical
  -- #252-721 Gen-2-style library. Runtime rows keep their collision-safe
  -- private dex, but resolve artwork by sourceDex.
  mod.exports.classic2DGen2ifiedLibrary67 = loadSibling(
    mod, "classic_2d_gen2ified_library_67.lua")(
      nonCrystalPixel2DData, classic2DGen2ifiedData)
  mod.exports.finalCrystalArt67.voxelFallback=mod.exports.finalCrystalArt67.merge(
    nonCrystalPixel2DData,mod.exports.finalCrystalArt67.data,"fallback")
  -- Construct the VASC animation Card only after the canonical #252+ static
  -- overlay has mutated this shared table. Missing/single-frame Neo variants
  -- can therefore fall back to the exact reviewed 2D front without reviving
  -- the old 3DS-style provider or touching classic battle backs.
  mod.exports.nonCrystalHdSprites67 = loadSibling(
    mod, "non_crystal_hd_sprites_67.lua")(mod, {
      data = nonCrystalHdAnimationData,
      fallbackData = mod.exports.finalCrystalArt67.voxelFallback,
      shinySystem = shinySystem,
      voxelRenderer = mod.exports.voxelRendererCompat,
      supportLog = mod.exports.supportSessionLog,
    })
  mod.exports.nonCrystalPixel2DSprites67 = loadSibling(
    mod, "non_crystal_pixel_2d_sprites_67.lua")(mod, {
      data = nonCrystalPixel2DData,
      supportLog = mod.exports.supportSessionLog,
    })
  mod.exports.alolaGiftAnimation66 = loadSibling(
    mod, "alola_animation_data.lua")
  crystalAnimationData.back = crystalAnimationData.back or {
    normal = {}, shiny = {},
  }
  for _, variant in ipairs({ "normal", "shiny" }) do
    for dex, timing in pairs(extendedCrystalAnimationData[variant] or {}) do
      crystalAnimationData[variant][dex] = timing
    end
    crystalAnimationData.back[variant] =
      crystalAnimationData.back[variant] or {}
    local rear = extendedCrystalAnimationData.back
      and extendedCrystalAnimationData.back[variant] or {}
    for dex, timing in pairs(rear) do
      crystalAnimationData.back[variant][dex] = timing
    end
    for dex, timing in pairs(
        extendedCrystalAnimationData.emeraldHoenn[variant] or {}) do
      crystalAnimationData[variant][dex] = timing
    end
    local emeraldRear = extendedCrystalAnimationData.emeraldHoenn.back
      and extendedCrystalAnimationData.emeraldHoenn.back[variant] or {}
    for dex, timing in pairs(emeraldRear) do
      crystalAnimationData.back[variant][dex] = timing
    end
    for dex, timing in pairs(
        extendedCrystalAnimationData.starterFamilies[variant] or {}) do
      crystalAnimationData[variant][dex] = timing
    end
    local starterRear = extendedCrystalAnimationData.starterFamilies.back
      and extendedCrystalAnimationData.starterFamilies.back[variant] or {}
    for dex, timing in pairs(starterRear) do
      crystalAnimationData.back[variant][dex] = timing
    end
    for dex, timing in pairs(
        extendedCrystalAnimationData.fairyAffection[variant] or {}) do
      crystalAnimationData[variant][dex] = timing
    end
    local fairyRear = extendedCrystalAnimationData.fairyAffection.back
      and extendedCrystalAnimationData.fairyAffection.back[variant] or {}
    for dex, timing in pairs(fairyRear) do
      crystalAnimationData.back[variant][dex] = timing
    end
    for dex, timing in pairs(
        extendedCrystalAnimationData.lateSpecies[variant] or {}) do
      crystalAnimationData[variant][dex] = timing
    end
    local lateRear = extendedCrystalAnimationData.lateSpecies.back
      and extendedCrystalAnimationData.lateSpecies.back[variant] or {}
    for dex, timing in pairs(lateRear) do
      crystalAnimationData.back[variant][dex] = timing
    end
    for dex, timing in pairs(
        mod.exports.alolaGiftAnimation66[variant] or {}) do
      crystalAnimationData[variant][dex] = timing
    end
    local alolaRear = mod.exports.alolaGiftAnimation66.back
      and mod.exports.alolaGiftAnimation66.back[variant] or {}
    for dex, timing in pairs(alolaRear) do
      crystalAnimationData.back[variant][dex] = timing
    end
  end
  crystalAnimationData.normal[tostring(gorochu.dex)] =
    gorochu.animationDurations
  crystalAnimationData.shiny[tostring(gorochu.dex)] =
    gorochu.animationDurations
  crystalAnimationData.grayscale[tostring(gorochu.dex)] =
    gorochu.animationDurations
  crystalAnimationData.back.grayscale =
    crystalAnimationData.back.grayscale or {}
  crystalAnimationData.back.grayscale[tostring(gorochu.dex)] =
    gorochu.animationDurations
  local makeCrystalAnimation = loadSibling(mod, "crystal_animation.lua")
  mod.exports.classic2DSpriteConnector67=loadSibling(
    mod,"classic_2d_sprite_connector_67.lua")(mod,{
      supportLog=mod.exports.supportSessionLog,
    })
  local crystalAnimation = makeCrystalAnimation(mod, {
    additionalArtRegistrar = loadSibling(mod, "backend_gift_art_67.lua"),
    animationData = crystalAnimationData,
    voxelAnimationData = mod.exports.nonCrystalHdSprites67.data,
    pixel2DData = mod.exports.nonCrystalPixel2DSprites67.data,
    voxelFallbackData = mod.exports.finalCrystalArt67.voxelFallback,
    neo2DData = mod.exports.finalCrystalArt67.merge(loadSibling(mod,"authored_crystal_library_67.lua")(
      loadSibling(mod,"neo_crystal_2d_67_data.lua"),
      loadSibling(mod,"authored_crystal_67_data.lua"),"native"),mod.exports.finalCrystalArt67.data,"native"),
    shinySystem = shinySystem,
    megaEvolution = megaEvolution,
    voxelRenderer = mod.exports.voxelRendererCompat,
    classic2DConnector=mod.exports.classic2DSpriteConnector67,
    speciesOrder = johtoData.order,
    guestDexes = mod.exports.hoennSpecies67.animationDexes((function()
      local guests = {
        [gorochu.dex] = true,
        [700] = true,
        [252] = true, [253] = true, [254] = true,
        [255] = true, [256] = true, [257] = true,
        [258] = true, [259] = true, [260] = true,
        [261] = true, [262] = true, [263] = true,
        [264] = true, [265] = true, [266] = true,
        [267] = true, [268] = true, [269] = true,
        [270] = true, [271] = true, [272] = true,
        [273] = true, [274] = true, [275] = true,
        [276] = true, [277] = true, [278] = true,
        [279] = true,
        [7019] = true, [7020] = true, [7026] = true,
        [7027] = true, [7028] = true, [7037] = true,
        [7038] = true, [7050] = true, [7051] = true,
        [7052] = true, [7053] = true, [7074] = true,
        [7075] = true, [7076] = true, [7088] = true,
        [7089] = true, [7103] = true, [7105] = true,
      }
      for dex in pairs(mod.exports.starterRuntimeDexes) do
        guests[dex] = true
      end
      for dex in pairs(mod.exports.lateSpeciesRuntimeDexes) do
        guests[dex] = true
      end
      for _, species in ipairs(
          mod.exports.legacyGlobalBabies67Data.order or {}) do
        local row = mod.exports.legacyGlobalBabies67Data.species[species]
        guests[assert(tonumber(row and row.sourceDex),
          "global baby runtime dex missing: " .. tostring(species))] = true
      end
      return guests
    end)()),
    classicGuestDexes = { [gorochu.dex] = true },
  })
  mod.exports.extendedSpeciesRuntime.bind({ crystalAnimation = crystalAnimation })
  mod.exports.starterSpecies67 = loadSibling(mod, "starter_species_67.lua")(
    mod, {
      data = mod.exports.starterSpecies67Data,
      beyondKanto = mod.exports.beyondKanto,
      i18n = i18n,
      shinySystem = shinySystem,
      crystalAnimation = crystalAnimation,
      generationRules = mod.exports.generationRules,
    })
  mod.exports.alolaGiftForms66 = loadSibling(mod, "alola_forms_67.lua")(
    mod, {
      data = mod.exports.alolaGiftForms66Data,
      i18n = i18n,
      shinySystem = shinySystem,
      crystalAnimation = crystalAnimation,
      enabled = contentEnabled,
    })
  mod.exports.fairyAffection67 = loadSibling(mod, "fairy_affection_67.lua")(
    mod, {
      data = mod.exports.fairyAffection67Data,
      i18n = i18n,
      generationRules = mod.exports.generationRules,
      shinySystem = shinySystem,
      crystalAnimation = crystalAnimation,
      enabled = contentEnabled and mod.options:get("fairy_affection_67") ~= false,
      supportLog = mod.exports.supportSessionLog,
    })
  mod.exports.lateSpecies67 = loadSibling(mod, "late_species_67.lua")(
    mod, {
      data = mod.exports.lateSpecies67Data,
      i18n = i18n,
      shinySystem = shinySystem,
      crystalAnimation = crystalAnimation,
      enabled = contentEnabled and mod.options:get("late_species_67") ~= false,
      supportLog = mod.exports.supportSessionLog,
    })
  local crystalV15 = loadSibling(mod, "crystal_v15_features.lua")(mod, {
    crystalAnimation = crystalAnimation,
    shinySystem = shinySystem,
    catalogueOwner = gorochuVisuals,
  })
  daycare.setShinySystem(shinySystem)
  mod.exports.daycare = daycare
  mod.exports.breedingData = breedingData
  mod.exports.megaEvolution = megaEvolution
  mod.exports.surpriseMega67 = loadSibling(mod,
    "surprise_mega_67.lua")(mod, {
      mega = megaEvolution, postgame = postgame, i18n = i18n,
    })
  assert(legacyWanderers.setMegaProvider(mod.exports.surpriseMega67))
  mod.exports.shinySystem = shinySystem
  mod.exports.crystalAnimation = crystalAnimation
  mod.exports.crystalV15 = crystalV15
  -- Hidden Evolution only consumes the established journey/character/Mega
  -- surfaces.  The adapter is exported once so future reward controllers can
  -- reuse the same durable transaction boundary without reaching into the
  -- Legacy Archive's private state.
  mod.exports.legacyDungeonAdapter = mod.exports.legacyDungeonAdapter
    or loadSibling(mod, "legacy_dungeon_adapter.lua")({
      archive = legacyJourney,
      journey = legacyJourney,
      characters = extendedCharacters,
      starters = legacyStarters,
      packages = mod.exports.hevoPackages,
      megaEvolution = megaEvolution,
      events = mod.events,
      log = mod.log,
      i18n = i18n,
      modId = mod.id,
      beyondKanto = mod.exports.beyondKanto,
    })
  mod.exports.ngplusLegacyWorkshop = loadSibling(
    mod, "ngplus_legacy_workshop.lua")(mod, {
      i18n = i18n, packages = mod.exports.hevoPackages,
      legacyProfile = legacyJourney.profile,
    })
  if contentEnabled then
    assert(mod.exports.ngplusLegacyWorkshop.register())
  end
  -- Keep this on exports rather than adding another top-level local: this
  -- factory is intentionally near LuaJIT's 200-local limit. Registration is
  -- fail-closed, so a missing package cannot fall back to prototype maps.
  mod.exports.hiddenEvolutionCampaign = loadSibling(mod, "hidden_evolution_campaign.lua")(mod, {
    i18n = i18n,
    questionUi = ascendantUi,
    extendedCharacters = extendedCharacters,
    activeCharacter = function(game)
      return legacyJourney.activeCharacter(game and game.save)
    end,
    -- Use the active save's seeded Journey record, not the mutable global
    -- archive counter, so an original or recovered slot cannot inherit the
    -- level scale of another save.
    journeyCycle = function(game)
      local state = legacyJourney.state(game and game.save)
      return state and state.cycle
    end,
    -- One Hall-of-Fame authority for every postgame feature.  The HEVO
    -- researchers must follow the same hall record/champion-flag migration
    -- semantics as rematches and the rest of the postgame controller.
    postgame = postgame,
    journey = legacyJourney,
    legacyDungeonAdapter = mod.exports.legacyDungeonAdapter,
    megaEvolution = megaEvolution,
    hevoPackages = mod.exports.hevoPackages,
    voxelRenderer = mod.exports.voxelRendererCompat,
    beyondKanto = mod.exports.beyondKanto,
  })
  mod.exports.hoennLegendPortals67 = loadSibling(
    mod, "hoenn_legend_portals_67.lua")(mod, {
      dex = mod.exports.hoennDexCompletion67,
      journey = legacyJourney,
      skyTileset = mod.exports.hoennEndgameTilesets67.ID,
      geometry = mod.exports.hoennEndgameEditorGeometry67,
      i18n = i18n,
    })
  assert(mod.exports.hoennLegendPortals67.bindShared(
    mod.exports.hiddenEvolutionCampaign.load().shared))
  mod.exports.hoennBirthIsland67 = loadSibling(
    mod, "hoenn_birth_island_67.lua")(mod, {
      dex = mod.exports.hoennDexCompletion67,
      runEvents = mod.exports.hoennEndgameRunEvents67,
      i18n = i18n,
    })
  mod.exports.hoennJirachiFinale67 = loadSibling(
    mod, "hoenn_jirachi_finale_67.lua")(mod, {
      dex = mod.exports.hoennDexCompletion67,
      journey = legacyJourney, i18n = i18n,
    })
  -- The physical Hoenn access Card is registered before content freezes;
  -- its shared collision-aware placement authority is reused by all later
  -- wandering/event NPC owners.
  mod.exports.runtimeNpcPlacement = mod.exports.runtimeNpcPlacement
    or loadSibling(mod, "runtime_npc_placement.lua")(mod)
  mod.exports.hoennEndgameAccess67 = loadSibling(
    mod, "hoenn_endgame_access_67.lua")(mod, {
      regis = mod.exports.hoennResearchSanctums67,
      moltres = mod.exports.hoennMoltresVolcano67,
      birth = mod.exports.hoennBirthIsland67,
      placement = mod.exports.runtimeNpcPlacement,
      postgame = postgame,
      i18n = i18n,
    })
  if contentEnabled then
    assert(mod.exports.hoennLegendPortals67.register())
    assert(mod.exports.hoennBirthIsland67.register())
    assert(mod.exports.hoennJirachiFinale67.register())
    assert(mod.exports.hoennEndgameAccess67.register())
    assert(mod.exports.hiddenEvolutionCampaign.register())
    if mod.exports.hevoPackages.enabled then
      assert(mod.exports.hevoPackages.registerFieldAltar(
        "KA_HEVO_BLUE_KYOGRE_SHRINE", "TEXT_KA_HEVO_MAGNETIC_ALTAR",
        "magnetic_field", { x = 11, y = 9 }))
      assert(mod.exports.hevoPackages.registerFieldAltar(
        "KA_HEVO_BLUE_KYOGRE_SHRINE", "TEXT_KA_HEVO_ICE_ALTAR",
        "ice_field", { x = 27, y = 9 }))
      assert(mod.exports.hevoPackages.registerFieldAltar(
        "KA_HEVO_GREEN_RAYQUAZA_SHRINE", "TEXT_KA_HEVO_MOSS_ALTAR",
        "moss_field", { x = 39, y = 7 }))
      assert(mod.exports.eeveeFieldSpots67.register())
    end
    if fieldTech and fieldTech.registerMapPolicyProvider then
      assert(fieldTech.registerMapPolicyProvider("hidden_evolution_campaign",
        function(game, moveId, mapId)
          return mod.exports.hiddenEvolutionCampaign.fieldPolicy(game, moveId, mapId)
        end))
    end
  end
  local makeFollowerCompat = loadSibling(mod, "follower_compat.lua")
  local followerCompat = makeFollowerCompat(mod, {
    spriteAssets = spriteAssets,
    shinySystem = shinySystem,
  })
  mod.exports.followerCompat = followerCompat
  local makeYellowPartner = loadSibling(mod, "yellow_partner.lua")
  local yellowPartner = makeYellowPartner(mod, {
    i18n = i18n,
    spriteAssets = spriteAssets,
    shinySystem = shinySystem,
    gorochu = gorochu,
    -- This deliberate native seam lets the Yellow adapter continue handling
    -- engine-created partner text while ordinary KASC requires stay scoped.
    nativeTextBox = dialoguePagination.nativeTextBox,
  })
  if megaEvolution and megaEvolution.setYellowPartner then
    megaEvolution.setYellowPartner(yellowPartner)
  end
  mod.exports.yellowPartner = yellowPartner
  local makeFollowerConfig = loadSibling(mod, "follower_config.lua")
  local followerConfig = makeFollowerConfig(mod, {
    i18n = i18n,
    gameVersion = GameVersion,
    yellowPartner = yellowPartner,
    legacyStarters = legacyStarters,
  })
  if yellowPartner and yellowPartner.setFollowerConfig then
    yellowPartner.setFollowerConfig(followerConfig)
  end
  local makeFollowerSelection = loadSibling(mod, "follower_selection.lua")
  local followerSelection = makeFollowerSelection({
    gameVersion = GameVersion,
    yellowPartner = yellowPartner,
    legacyStarters = legacyStarters,
    config = followerConfig,
  })
  local makeFollowerSprites = loadSibling(mod, "follower_sprites.lua")
  local extendedFollowerOrder = {}
  for _, species in ipairs(johtoData.order) do
    extendedFollowerOrder[#extendedFollowerOrder + 1] = species
  end
  for _, species in ipairs(legacyHoenn.order) do
    extendedFollowerOrder[#extendedFollowerOrder + 1] = species
  end
  for _, species in ipairs(hevoSpecies.order) do
    extendedFollowerOrder[#extendedFollowerOrder + 1] = species
  end
  for _, species in ipairs(mod.exports.hoennSpecies67.registeredOrder) do
    extendedFollowerOrder[#extendedFollowerOrder + 1] = species
  end
  for _, species in ipairs(mod.exports.starterSpecies67.order) do
    extendedFollowerOrder[#extendedFollowerOrder + 1] = species
  end
  for _, species in ipairs(mod.exports.fairyAffection67.order) do
    extendedFollowerOrder[#extendedFollowerOrder + 1] = species
  end
  for _, species in ipairs(mod.exports.lateSpecies67.order) do
    extendedFollowerOrder[#extendedFollowerOrder + 1] = species
  end
  local followerSprites = makeFollowerSprites(mod, {
    spriteAssets = spriteAssets,
    shinySystem = shinySystem,
    johtoData = { order = extendedFollowerOrder },
    extendedRuntime = mod.exports.extendedSpeciesRuntime,
  })
  assert(mod.exports.fairyAffection67.bind({
    shinySystem = shinySystem,
    crystalAnimation = crystalAnimation,
    followerSprites = followerSprites,
  }))
  assert(mod.exports.lateSpecies67.bind({
    shinySystem = shinySystem,
    crystalAnimation = crystalAnimation,
    followerSprites = followerSprites,
  }))
  local kantoSpecies = loadSibling(mod, "kanto_species.lua")
  if spriteAssets and type(spriteAssets.setKantoSpecies) == "function" then
    spriteAssets.setKantoSpecies(kantoSpecies)
  end
  local makePartyIcons = loadSibling(mod, "party_icons.lua")
  local partyIcons = makePartyIcons(mod, {
    sprites = followerSprites,
    kanto = kantoSpecies,
    johto = extendedFollowerOrder,
    extendedRuntime = mod.exports.extendedSpeciesRuntime,
  })
  local makeSingleFollower = loadSibling(mod, "single_follower.lua")
  local singleFollower = makeSingleFollower(mod, {
    selection = followerSelection,
    sprites = followerSprites,
    yellowPartner = yellowPartner,
    config = followerConfig,
    i18n = i18n,
  })
  mod.exports.followerConfig = followerConfig
  mod.exports.followerSelection = followerSelection
  mod.exports.followerSprites = followerSprites
  mod.exports.partyIcons = partyIcons
  mod.exports.singleFollower = singleFollower
  mod.exports.extendedSpeciesRuntime.bind({
    followerSprites = followerSprites,
    partyIcons = partyIcons,
  })
  mod.exports.hoennSpecies67.bind({
    shinySystem = shinySystem,
    followerSprites = followerSprites,
    partyIcons = partyIcons,
  })
  mod.exports.starterSpecies67.bind({
    shinySystem = shinySystem,
    followerSprites = followerSprites,
    crystalAnimation = crystalAnimation,
  })
  mod.exports.alolaGiftForms66.bind({
    shinySystem = shinySystem,
    followerSprites = followerSprites,
    crystalAnimation = crystalAnimation,
  })
  local johtoEncounterLevels =
    loadSibling(mod, "johto_encounter_levels.lua")
  do
    local band = mod.options:get("johto_level_bonus")
    if band == "2_5" then
      johtoEncounterLevels.setBonusRange(2, 5)
    else
      johtoEncounterLevels.setBonusRange(2, 8)
    end
  end
  mod.exports.runtimeNpcPlacement = mod.exports.runtimeNpcPlacement
    or loadSibling(mod, "runtime_npc_placement.lua")(mod)
  local makeJohtoResearch = loadSibling(mod, "johto_research.lua")
  local johtoResearch = makeJohtoResearch(mod, {
    data = johtoData,
    postgame = postgame,
    i18n = i18n,
    contentEnabled = contentEnabled,
    daycare = daycare,
    encounterLevels = johtoEncounterLevels,
    johtoBoundary = mod.exports.beyondKanto,
    placement = mod.exports.runtimeNpcPlacement,
  })
  shinySystem.setJohtoResearch(johtoResearch)
  recruitment.configureJohto(johtoData.order, function(species)
    return johtoResearch.isRecruitFamilyEligible(species)
  end)
  assert(recruitment.configureSpeciesAvailability(function(game, species, def)
    return mod.exports.generationRules.speciesAvailable(game, species, def)
  end))
  recruitment.configureEvolutionAvailability(function(target, from, row, context)
    if target == "GOROCHU" then
      if not mod.exports.beyondKanto.isActive() then return false end
      local s = gorochu and gorochu.state and gorochu.state(false)
      return s and s.playerEvolved == true or false
    end
    local game=context and context.game
    local def=game and game.data and game.data.pokemon[target]
    local national=def and tonumber(def.sourceDex or def.nationalDex or def.dex)
    if national and national>=152 and national<=1025 and not def.isMega
        and not def.isGigantamax and not def.regionalForm then
      return mod.exports.generationRules.speciesAvailable(game,target,def)
    end
    if not mod.exports.beyondKanto.isActive() then return false end
    local core = mod.exports.discoveryCore
    local hoenn = core and core.Hoenn
    local family = hoenn and hoenn.familyForSpecies
      and select(1, hoenn.familyForSpecies(target))
    if family and core.state and type(core.state.status) == "function" then
      local status = core.state.status("hoenn", family)
      if status == "sighted" or status == "unlocked" then return true end
    end
    return johtoResearch.isSpeciesResearched(target)
      or johtoResearch.isRecruitFamilyEligible(target)
  end)
  legacyWanderers.setRecruitmentProvider(recruitment)
  mod.exports.johtoResearch = johtoResearch

  local signalsStateModule = loadSibling(mod, "johto_signals_state.lua")
  local signalsState = signalsStateModule.create(mod)
  local signalsContentModule = loadSibling(mod, "johto_signals_content.lua")
  local signalsContent = signalsContentModule.create(mod, {
    state = signalsState,
    i18n = i18n,
  })
  signalsContent.register()

  local signalsHub
  local makeJohtoSignals = loadSibling(mod, "johto_signals.lua")
  local johtoSignals = makeJohtoSignals(mod, {
    state = signalsState,
    content = signalsContent,
    johtoData = johtoData,
    i18n = i18n,
    encounterLevels = johtoEncounterLevels,
    -- Only the physical receiver at Driftglass can skip Kanto First.  The
    -- state-aware Signals hub still offers its post-repair ON/OFF switch, but
    -- old launcher SIGNAL START values are intentionally ignored.
    startPolicyOptions = false,
    johtoBoundary = mod.exports.beyondKanto,
    generationRules = mod.exports.generationRules,
    onOakCall = function(game, text, onDone)
      if signalsHub then
        return signalsHub.showOakCall(game, text, onDone)
      end
    end,
    onCapsuleFound = function(game)
      if signalsHub then return signalsHub.onCapsuleFound(game) end
    end,
    onOnboardingRequired = function(game, policy, text, decide)
      if signalsHub then
        return signalsHub.offerOnboarding(game, policy, text, decide)
      end
    end,
  })
  -- Elm's permanent research habitats and every visible-Wilds consumer must
  -- obey the same Driftglass receiver mode.  Without this shared gate a
  -- post-game research flag could leak Johto into Kanto First or into an
  -- unrelated Wanderwave.
  johtoResearch.setMigrationGate(function(species, ctx)
    return johtoSignals.allowsHabitatSpecies(species, ctx)
  end)
  local makeMythicSignals = loadSibling(mod, "mythic_signals.lua")
  local mythicSignals = makeMythicSignals(mod, {
    state = signalsState,
    content = signalsContent,
    johtoSignals = johtoSignals,
    beyondKanto = mod.exports.beyondKanto,
    generationRules = mod.exports.generationRules,
    i18n = i18n,
  })
  local prismModule = loadSibling(mod, "driftglass_prisms.lua")
  local driftglassPrisms = prismModule.create(mod, {
    state = signalsState,
    content = signalsContent,
    i18n = i18n,
    fieldTech = fieldTech,
  })
  driftglassPrisms.register()
  local function johtoTrainerMovesUnlocked()
    if not mod.exports.beyondKanto.isActive() then return false end
    local root = signalsState.root(false)
    return root and root.earlyJohto
      and root.earlyJohto.receiverRepaired == true or false
  end
  local masteryModule = loadSibling(mod, "rematch_mastery.lua")
  local rematchMastery = masteryModule.create({
    resonanceRules = driftglassPrisms.resonanceRules,
    -- Extended trainer moves share the repaired-Receiver boundary. Crown
    -- signature attacks additionally require their exact Field-Tech reward;
    -- OVERHEAT has no local reward item and therefore uses the receiver plus
    -- the species-legal merged registry source enforced by mastery itself.
    extendedMoveAllowed = function(game, species, moveId)
      if not johtoTrainerMovesUnlocked() then return false end
      if moveId == "OVERHEAT" then return true, false end
      local allowed = type(fieldTech.signatureMoveAllowed) == "function"
        and fieldTech.signatureMoveAllowed(game, species, moveId) == true
        or false
      return allowed, allowed
    end,
    -- Driftglass is the existing legal seam for Generation-II moves on
    -- Kanto species.  Trainers may use those moves only after the receiver
    -- has actually been repaired in this save.
    johtoUnlocked = johtoTrainerMovesUnlocked,
  })
  mod.exports.rematchMastery = rematchMastery
  local rematchAI = loadSibling(mod, "rematch_ai.lua")(mod)
  mod.exports.rematchAI = rematchAI
  mod.exports.opponentSmartAI67 = loadSibling(mod,
    "opponent_smart_ai_67.lua")(mod, {
      useful = rematchAI, rules = mod.exports.generationRules,
      blockedStatus = function(b,who,status)
        local effects=mod.exports.pokemonAbilityEffects67
        return effects and effects.blockStatus(b,who,status)~=nil or false
      end,
    })
  local yellowGymMoveFidelity = loadSibling(mod,
    "yellow_gym_move_fidelity.lua")
  local storyGymDifficulty = loadSibling(mod,
    "story_gym_difficulty.lua")(mod, {
      gameVersion = GameVersion,
      usefulLayerId = rematchAI.layerId,
      yellowFidelity = yellowGymMoveFidelity,
      johtoUnlocked = johtoTrainerMovesUnlocked,
      resonanceRules = driftglassPrisms.resonanceRules,
      difficultyContracts = mod.exports.difficultyTeamContracts67,
    })
  mod.exports.storyGymDifficulty = storyGymDifficulty
  legacyWanderers.setMasteryProvider(rematchMastery)
  local difficulty = loadSibling(mod, "difficulty.lua")(mod, {
    i18n = i18n,
    mastery = rematchMastery,
  })
  mod.exports.difficulty = difficulty
  mod.exports.adaptiveTrainerLevels = loadSibling(
    mod, "adaptive_trainer_levels.lua")(mod, {
      difficulty = difficulty,
      difficultyContracts = mod.exports.difficultyTeamContracts67,
    })
  mod.exports.storyLevelCap = loadSibling(mod, "story_level_cap.lua")(mod, {
    gameVersion = GameVersion,
    storyGym = storyGymDifficulty,
    difficulty = difficulty,
    adaptiveTrainerLevels = mod.exports.adaptiveTrainerLevels,
    rivalTeams = mod.exports.rivalTeams,
    rivalIdentity = function()
      -- Battle composition falls back to the authored BLUE/vanilla roster
      -- while the optional character selector is disabled. A stale saved
      -- RED/GREEN choice must not make the projected cap diverge from the
      -- team the trainer.party hook will actually use.
      if not extendedCharacters.isEnabled() then return "BLUE" end
      return extendedCharacters.getRivalCharacter()
    end,
    postgame = postgame,
    postgameData = postgameData,
  })
  daycare.setLevelCap(mod.exports.storyLevelCap)
  mod.exports.storyLevelCapMenu = loadSibling(
    mod, "story_level_cap_menu.lua")(mod, {
      i18n = i18n, controller = mod.exports.storyLevelCap,
    })
  local bicycleSelect = loadSibling(mod, "bicycle_select.lua")(mod, {
    i18n = i18n,
  })
  mod.exports.bicycleSelect = bicycleSelect
  local itemProtection = loadSibling(mod, "item_protection.lua")(mod, {
    i18n = i18n,
  })
  mod.exports.itemProtection = itemProtection
  local visionEncounters = loadSibling(mod, "vision_encounters.lua")(mod, {
    i18n = i18n,
    crystalAnimation = crystalAnimation,
  })
  mod.exports.visionEncounters = visionEncounters
  local mythicSafety = loadSibling(mod, "mythic_safety.lua")(mod)
  mod.exports.mythicSafety = mythicSafety
  local runRules = loadSibling(mod, "run_rules.lua")(mod, {
    i18n = i18n,
    shinySystem = shinySystem,
    mythicSafety = mythicSafety,
    beyondKanto = mod.exports.beyondKanto,
    generationRules = mod.exports.generationRules,
  })
  mod.exports.runRules = runRules
  -- Wanderer victories reveal only the active character's Hoenn third. A
  -- native encounter is replaced transactionally and counts as seen/caught
  -- only after the exact wild battle reaches the engine.
  mod.exports.discoveryCore.hoenn = mod.exports.discoveryCore.Hoenn.attach(
    mod, {
      state = mod.exports.discoveryCore.state,
      legacyHoenn = legacyHoenn,
      extendedSpeciesRuntime = mod.exports.extendedSpeciesRuntime,
      hoennSpecies67 = mod.exports.hoennSpecies67,
      fieldAccess = mod.exports.hoennFieldAccess,
      legacyStarters = legacyStarters,
      legacyJourney = legacyJourney,
      runRules = runRules,
      generationRules = mod.exports.generationRules,
    })
  mod.exports.hoennTraceMusic67 = loadSibling(
    mod, "hoenn_trace_music_67.lua")(mod)
  mod.exports.hoennTracePresentation67 = loadSibling(
    mod, "hoenn_trace_presentation_67.lua")(mod, {
      i18n = i18n,
      musicId = mod.exports.hoennTraceMusic67.id,
    })
  local dojoPrizes = loadSibling(mod, "dojo_prizes.lua")(mod, {
    i18n = i18n,
  })
  mod.exports.dojoPrizes = dojoPrizes
  local makeSignalsHub = loadSibling(mod, "johto_signals_hub.lua")
  signalsHub = makeSignalsHub(mod, {
    state = signalsState,
    content = signalsContent,
    early = johtoSignals,
    mythic = mythicSignals,
    prisms = driftglassPrisms,
    i18n = i18n,
    johtoBoundary = mod.exports.beyondKanto,
  })
  local makeSignalsWilds = loadSibling(mod, "johto_signals_wilds.lua")
  local signalsWilds = makeSignalsWilds(mod, {
    johtoSignals = johtoSignals,
    mythicSignals = mythicSignals,
    johtoResearch = johtoResearch,
    encounterLevels = johtoEncounterLevels,
    runRules = runRules,
  })
  mod.exports.johtoSignalsState = signalsState
  mod.exports.johtoSignalsContent = signalsContent
  mod.exports.johtoSignals = johtoSignals
  mod.exports.mythicSignals = mythicSignals
  mod.exports.driftglassPrisms = driftglassPrisms
  mod.exports.signalsHub = signalsHub
  mod.exports.signalsWilds = signalsWilds

  local wildsSpawnSafety = loadSibling(mod, "wilds_spawn_safety.lua")(mod)
  -- Ascendant-owned script cells that are not represented by vanilla ROM
  -- object events.  Future scripted content uses the same explicit seam.
  wildsSpawnSafety.reserveCells("OAKS_LAB", {
    { x = 0, y = 1, approaches = true }, -- Legacy terminal + use cell
    { x = 1, y = 1, approaches = true }, -- Legacy terminal + use cell
    { x = 5, y = 5 },                    -- fresh-run scripted landing
  }, "Ascendant Oak's Lab scripted position")
  mod.exports.wildsSpawnSafety = wildsSpawnSafety
  -- Access V3.1 is inert outside a Legacy run. Each edge reveal requires a
  -- traced starter family and writes a monotonic archive receipt before the
  -- corresponding compact habitat can be entered.
  mod.exports.hiddenAccessReveal = loadSibling(
    mod, "hidden_access_reveal.lua")(mod, mod.exports.explorationDevice, {
      isNewGamePlus = function(game)
        return legacyJourney.isActive(game and game.save) == true
      end,
      prerequisite = function(game, def)
        local gate = def and def.eligibility or {}
        if gate.kind == "starter" then
          local state = mod.exports.discoveryCore
            and mod.exports.discoveryCore.state
          local status = state and state.status
            and state.status(gate.generation, gate.family) or "unseen"
          return status == "sighted" or status == "trace"
            or status == "caught" or status == "unlocked"
        end
        local profile = legacyJourney.profile()
        local completed = profile and profile.completedPaths or {}
        local save = game and game.save
        local active = legacyJourney.activeCharacter(save)
        local function hasCurrentSeal(character)
          if type(character) ~= "string" or active ~= character
              or type(legacyJourney.currentHevoSeal) ~= "function" then
            return false
          end
          local ok, sealed, owner = pcall(
            legacyJourney.currentHevoSeal, save, character)
          return ok and sealed == true and owner == character
        end
        if gate.kind == "profile_legend" then
          return hasCurrentSeal(gate.profile)
        end
        if gate.kind == "jirachi_convergence" then
          return completed.red == true and completed.blue == true
            and completed.green == true and profile
            and profile.legacyPass == true and hasCurrentSeal(active)
        end
        return false, "unknown Access V3.1 prerequisite"
      end,
      durableReceipts = {
        all = function()
          return legacyJourney.hiddenAccessReceipts()
        end,
        isOpen = function(id)
          return legacyJourney.hiddenAccessIsOpen(id)
        end,
        markOpen = function(id, receipt, game)
          return legacyJourney.markHiddenAccessOpen(
            game and game.save, id, receipt)
        end,
      },
      reserveWilds = function(mapId, cells, id)
        return wildsSpawnSafety.reserveCells(
          mapId, cells, "Access V3.1 " .. tostring(id))
      end,
      featureAvailable = function(_, def)
        local destination = def and def.handoff and def.handoff.destination
        local mapId = destination and destination.map
        if type(mapId) == "string"
            and mapId:match("^KA_HABITAT_") then
          return mod.options:get("starter_habitats_enabled") ~= false
        end
        return true
      end,
      prepareHandoff = function(game, def)
        local habitats = mod.exports.starterHabitats
        local destination = def and def.handoff and def.handoff.destination
        if not (habitats and destination and habitats.maps
            and habitats.maps[destination.map]) then return true end
        return habitats.prepareHandoff(
          game, def.id, def.mapId, destination.map)
      end,
      rollbackHandoff = function(game, def, token, reason)
        local habitats = mod.exports.starterHabitats
        local destination = def and def.handoff and def.handoff.destination
        if not (habitats and destination and habitats.maps
            and habitats.maps[destination.map]) then return false end
        return habitats.rollbackHandoff(game, token, reason)
      end,
    })
  assert(mod.exports.hiddenAccessReveal.register(),
    "Access V3.1 definition registration failed")
  assert(mod.exports.hiddenAccessReveal.registerInteractions(),
    "Access V3.1 interaction registration failed")
  mod.exports.starterHabitats = loadSibling(
    mod, "starter_habitats_loader.lua")(mod, {
      loadSibling = loadSibling,
      discoveryCore = mod.exports.discoveryCore,
      legacyJourney = legacyJourney,
      explorationDevice = mod.exports.explorationDevice,
      wildsSpawnSafety = wildsSpawnSafety,
      hiddenAccessReveal = mod.exports.hiddenAccessReveal,
      signalsWilds = signalsWilds,
      shinySystem = shinySystem,
      generationRules = mod.exports.generationRules,
      i18n = i18n,
      speciesAuthority = mod.exports.starterSpecies67,
      supportLog = mod.exports.supportSessionLog,
      onSpeciesAvailabilityChanged = function(game)
        if mod.exports.wildsCompat
            and type(mod.exports.wildsCompat.refreshVisible) == "function" then
          mod.exports.wildsCompat.refreshVisible(
            "starter habitat species authority changed")
        end
      end,
    })
  local makeWildsCompat = loadSibling(mod, "wilds_compat.lua")
  local wildsCompat = makeWildsCompat(mod, {
    johtoResearch = johtoResearch,
    johtoSignals = johtoSignals,
    data = johtoData,
    crystalNames = CRYSTAL_ASSETS,
    spriteAssets = spriteAssets,
    extendedRuntime = mod.exports.extendedSpeciesRuntime,
    contentEnabled = contentEnabled,
    encounterLevels = johtoEncounterLevels,
    voxelRenderer = mod.exports.voxelRendererCompat,
    spawnSafety = wildsSpawnSafety,
    generationRules = mod.exports.generationRules,
  })
  mod.exports.wildsCompat = wildsCompat
  -- A clean Ascendant install must own a working visible-spawn provider.
  -- Prefer a separately installed Wilds release when present; otherwise load
  -- the bundled 1.12.2 spawn/ambient core without its overlapping follower
  -- controller or settings menus.
  local internalWilds = loadSibling(mod, "internal_wilds.lua")(mod, {
    extendedRuntime = mod.exports.extendedSpeciesRuntime,
    voxelRenderer = mod.exports.voxelRendererCompat,
    spawnSafety = wildsSpawnSafety,
  })
  mod.exports.internalWilds = internalWilds
  mod.exports.starterSpecies67.attachWilds(internalWilds.exports)
  -- Backend fact authority only. Does not change Dex size, encounter pools,
  -- existing species definitions or the user's selected generation profile.
  mod.exports.backendNationalCatalog67 = loadSibling(mod,
    "backend_national_catalog_67_data.lua")
  mod.exports.backendGenerationRules67 = loadSibling(mod,
    "backend_generation_rules_67.lua")({
      data = loadSibling(mod, "backend_generation_rules_67_data.lua"),
      catalog = mod.exports.backendNationalCatalog67,
      formLearnsetOverrides = loadSibling(mod, "backend_form_learnset_overrides_67_data.lua"),
      supportLog = mod.exports.supportSessionLog,
      load = function(path) return loadSibling(mod, path) end,
    })
  mod.exports.backendLaterMoves67 = loadSibling(mod, "backend_later_moves_67.lua")(mod, {
    facts = mod.exports.backendGenerationRules67, i18n = i18n,
    supportLog = mod.exports.supportSessionLog,
  })
  mod.exports.backendMoveAnimationArt67 = loadSibling(mod,
    "backend_move_animation_art_67.lua")(mod, { moves = mod.exports.backendLaterMoves67 })
  mod.exports.backendGiftSpecies67 = loadSibling(mod,
    "backend_gift_species_67.lua")(mod, {
      catalog = mod.exports.backendNationalCatalog67,
      facts = mod.exports.backendGenerationRules67,
      art = loadSibling(mod, "backend_national_art_67_data.lua"),
      sprites = mod.exports.crystalAnimation,
      i18n = i18n,
    })
  mod.exports.backendLiveLearnsets67 = loadSibling(mod, "backend_live_learnsets_67.lua")({
    species = mod.exports.backendGiftSpecies67, rules = mod.exports.generationRules,
    catalog = mod.exports.backendNationalCatalog67, eggMoves = eggMoves,
    fieldTech = fieldTech, edition = function() return GameVersion.get() end,
  })
  mod.exports.generationLearnsets67.setBackendProvider(mod.exports.backendLiveLearnsets67)
  mod.exports.generationRules.setLiveLearnsetProvider(mod.exports.backendLiveLearnsets67.apply)
  mod.exports.generationRules.setOwnedGiftMoveCompatibilityProvider(
    mod.exports.backendLiveLearnsets67.giftMoveCompatible)
  fieldTech.setReminderMoveAvailability(function(game, mon, move)
    local resolved = mod.exports.generationRules.resolve(game)
    return mod.exports.generationRules.monMoveAvailable(game, mon, move,
      resolved.activeEpoch, resolved.extensionsEnabled)
  end)
  mod.exports.backendLiveMoveRules67 = loadSibling(mod, "backend_live_move_rules_67.lua")({
    facts = mod.exports.backendGenerationRules67,
    species = mod.exports.backendGiftSpecies67,
    supportLog = mod.exports.supportSessionLog,
  })
  mod.exports.generationRules.setLiveMoveProvider(mod.exports.backendLiveMoveRules67.apply)
  mod.exports.backendMoveAccuracy67 = loadSibling(mod, "backend_move_accuracy_67.lua")(mod, {
    facts = mod.exports.backendGenerationRules67, species = mod.exports.backendGiftSpecies67,
    rules = mod.exports.generationRules, supportLog = mod.exports.supportSessionLog,
  })
  mod.exports.backendSplitSpecial67 = loadSibling(mod, "backend_split_special_67.lua")(mod, {
    facts = mod.exports.backendGenerationRules67, species = mod.exports.backendGiftSpecies67,
    rules = mod.exports.generationRules, supportLog = mod.exports.supportSessionLog, i18n = i18n,
  })
  mod.exports.backendCriticalRules67 = loadSibling(mod, "backend_critical_rules_67.lua")(mod, {
    facts = mod.exports.backendGenerationRules67, species = mod.exports.backendGiftSpecies67,
    rules = mod.exports.generationRules, damage = loadSibling(mod, "pokemon_damage_math_67.lua"),
    abilities = function() return mod.exports.pokemonAbilityEffects67 end,
    i18n = i18n,
    held = function(mon) return mod.exports.pokemonEquipment67.heldId(mon) end,
    supportLog = mod.exports.supportSessionLog,
  })
  mod.exports.generationMoveCatalog67.setStatResolver(
    mod.exports.backendSplitSpecial67.changes, mod.exports.backendSplitSpecial67.changeStage)
  mod.exports.backendMegaForms67 = loadSibling(mod, "backend_mega_forms_67.lua")({
    mega = megaEvolution, catalog = mod.exports.backendNationalCatalog67,
    species = mod.exports.backendGiftSpecies67,
    metadata = loadSibling(mod, "backend_mega_catalog_67_data.lua"),
    art = loadSibling(mod, "backend_national_art_67_data.lua"), i18n = i18n,
  })
  mod.exports.backendGigantamaxForms67 = loadSibling(mod, "backend_gigantamax_forms_67.lua")({
    catalog = mod.exports.backendNationalCatalog67, species = mod.exports.backendGiftSpecies67,
    metadata = loadSibling(mod, "backend_gigantamax_catalog_67_data.lua"),
    art = loadSibling(mod, "backend_national_art_67_data.lua"),
    read = function(path) return mod:read(path) end,
  })
  mod.exports.pokemonAbilityBinding67 = loadSibling(mod,
    "pokemon_ability_binding_67.lua")({
      facts = mod.exports.backendGenerationRules67,
      catalog = mod.exports.backendNationalCatalog67,
      digest = loadSibling(mod, "legacy_bank_sha256.lua"),
      supports = function(game, id, epoch)
        local effects = mod.exports.pokemonAbilityEffects67
        return effects and effects.supportsAbility(game, id, epoch) or false
      end,
    })
  mod.exports.pokemonEquipment67 = loadSibling(mod,
    "pokemon_equipment_runtime_67.lua")(mod, {
      rules = mod.exports.generationRules,
      facts = mod.exports.backendGenerationRules67,
      evidence = mod.exports.generationEvidence,
      abilities = mod.exports.pokemonAbilityBinding67,
      i18n = i18n,
      makeCore = loadSibling(mod, "pokemon_equipment_67.lua"),
      digest = loadSibling(mod, "legacy_bank_sha256.lua"),
      effects = function()
        return {supportsItem = function(game,id,epoch)
          local recovery = mod.exports.pokemonEquipmentEffects67
          local berries = mod.exports.pokemonModernBerries67
          local boost = mod.exports.pokemonEquipmentTypeBoost67
          local critical = mod.exports.backendCriticalRules67
          local survival = mod.exports.pokemonLethalHitSurvival67
          local smoke = mod.exports.pokemonSmokeBall67
          return recovery and recovery.supportsItem(game,id,epoch)
            or berries and berries.supportsItem(game,id,epoch)
            or boost and boost.supportsItem(game,id,epoch)
            or critical and critical.supportsItem(game,id,epoch)
            or survival and survival.supportsItem(game,id,epoch)
            or smoke and smoke.supportsItem(game,id,epoch) or false
        end}
      end,
      supportLog = mod.exports.supportSessionLog,
    })
  mod.exports.pokemonAbilityEffects67 = loadSibling(mod,
    "pokemon_ability_effects_67.lua")(mod, {
      rules = mod.exports.generationRules,
      abilities = mod.exports.pokemonAbilityBinding67,
      i18n = i18n,
    })
  mod.exports.backendFlinchEffects67 = loadSibling(mod, "backend_flinch_effects_67.lua")(mod, {
    facts = mod.exports.backendGenerationRules67, species = mod.exports.backendGiftSpecies67,
    rules = mod.exports.generationRules, supportLog = mod.exports.supportSessionLog,
    abilities = function() return mod.exports.pokemonAbilityEffects67 end,
  })
  mod.exports.backendStatusRules67 = loadSibling(mod, "backend_status_rules_67.lua")(mod, {
    facts = mod.exports.backendGenerationRules67, species = mod.exports.backendGiftSpecies67,
    rules = mod.exports.generationRules, supportLog = mod.exports.supportSessionLog,
  })
  mod.exports.backendSecondaryConditions67 = loadSibling(mod, "backend_secondary_conditions_67.lua")(mod, {
    facts = mod.exports.backendGenerationRules67, species = mod.exports.backendGiftSpecies67,
    status = mod.exports.backendStatusRules67, supportLog = mod.exports.supportSessionLog,
    abilities = function() return mod.exports.pokemonAbilityEffects67 end,
  })
  mod.exports.backendPartialTrapping67 = loadSibling(mod, "backend_partial_trapping_67.lua")(mod, {
    facts = mod.exports.backendGenerationRules67, species = mod.exports.backendGiftSpecies67,
    status = mod.exports.backendStatusRules67, critical = mod.exports.backendCriticalRules67,
    i18n = i18n, supportLog = mod.exports.supportSessionLog,
  })
  mod.exports.generationCheckpoint67.addValidator(
    mod.exports.backendPartialTrapping67.validateCheckpoint)
  mod.exports.pokemonEquipmentEffects67 = loadSibling(mod,
    "pokemon_held_hp_67.lua")(mod, {
      rules = mod.exports.generationRules,
      facts = mod.exports.backendGenerationRules67,
      held = mod.exports.pokemonEquipment67.heldId,
      i18n = i18n,
    })
  mod.exports.pokemonModernBerries67 = loadSibling(mod,
    "pokemon_held_berries_67.lua")(mod, {
      rules = mod.exports.generationRules,
      facts = mod.exports.backendGenerationRules67,
      held = mod.exports.pokemonEquipment67.heldId,
      i18n = i18n,
    })
  mod.exports.generationCheckpoint67.addValidator(mod.exports.pokemonEquipmentEffects67.validateCheckpoint)
  mod.exports.pokemonLethalHitSurvival67 = loadSibling(mod,
    "pokemon_lethal_hit_survival_67.lua")(mod, {
      rules = mod.exports.generationRules, facts = mod.exports.backendGenerationRules67,
      held = mod.exports.pokemonEquipment67.heldId,
      abilities = mod.exports.pokemonAbilityEffects67, i18n = i18n,
    })
  mod.exports.generationCheckpoint67.addValidator(mod.exports.pokemonModernBerries67.validateCheckpoint)
  mod.exports.generationCheckpoint67.addValidator(mod.exports.pokemonAbilityEffects67.validateCheckpoint)
  mod.exports.pokemonWildEquipment67 = loadSibling(mod,
    "pokemon_equipment_wild_67.lua")(mod, {
      rules = mod.exports.generationRules,
      facts = mod.exports.backendGenerationRules67,
      abilities = mod.exports.pokemonAbilityBinding67,
      held = mod.exports.pokemonEquipment67.heldId,
      digest = loadSibling(mod, "legacy_bank_sha256.lua"),
      i18n = i18n,
      origin = function(battle)
        local wilds = mod.exports.internalWilds
        local logic = wilds and wilds.exports and wilds.exports.logic
        local pending = logic and logic.pendingBattle
        if not pending or pending.species ~= battle.enemy.mon.species then return nil end
        local meta = battle.game.save.meta or {}
        local identity = meta.playthroughId or meta.saveIdentity
        if not identity then return nil end
        return table.concat({identity,tostring(logic.activeMapId),
          tostring(pending.id),pending.species}, ':')
      end,
    })
  mod.exports.pokemonEquipmentTypeBoost67 = loadSibling(mod,
    "pokemon_equipment_type_boost_67.lua")(mod, {
      rules = mod.exports.generationRules,
      facts = mod.exports.backendGenerationRules67,
      held = mod.exports.pokemonEquipment67.heldId,
      damage = loadSibling(mod, "pokemon_damage_math_67.lua"),
    })
  mod.exports.pokemonSmokeBall67 = loadSibling(mod, "pokemon_smoke_ball_67.lua")(mod, {
    facts = mod.exports.backendGenerationRules67, rules = mod.exports.generationRules,
    held = mod.exports.pokemonEquipment67.heldId, i18n = i18n,
    trapping = function() return mod.exports.backendPartialTrapping67 end,
  })
  local ascendantData = loadSibling(mod, "ascendant_data.lua")
  local makeAscendant = loadSibling(mod, "ascendant.lua")
  local ascendant
  local eventData = loadSibling(mod, "event_data.lua")
  local makeEventArchive = loadSibling(mod, "event_archive.lua")
  local eventArchive = makeEventArchive(mod, {
    data = eventData,
    postgame = postgame,
    i18n = i18n,
    placement = mod.exports.runtimeNpcPlacement,
    generationEpoch = function(game)
      local profile=mod.exports.generationRules.resolve(game)
      return profile and profile.activeEpoch or 1
    end,
    prepareGiftEgg = function(game,mon,profile,receipt)
      local binding=mod.exports.pokemonAbilityBinding67
      if not binding or not receipt then return false,'egg_binding_unavailable' end
      local epoch=mon.eventDistribution.learnsetGeneration or profile.originGeneration
      mon._kascAbility67=binding.reserveEgg(game,mon.species,nil,false,
        epoch,receipt.digest)
      return type(mon._kascAbility67)=='table','egg_binding_unavailable'
    end,
  })
  mod.exports.backendGiftProfiles67 = loadSibling(mod,
    "backend_gift_profiles_67.lua")({
      species = mod.exports.backendGiftSpecies67,
      catalog = mod.exports.backendNationalCatalog67,
      mega = mod.exports.backendMegaForms67,
      megaMetadata = loadSibling(mod, "backend_mega_catalog_67_data.lua"),
      gigantamax = mod.exports.backendGigantamaxForms67,
      gigantamaxMetadata = loadSibling(mod, "backend_gigantamax_catalog_67_data.lua"),
    })
  assert(eventArchive.registerGiftProfiles(mod.exports.backendGiftProfiles67.profiles)
    == #mod.exports.backendGiftProfiles67.profiles,
    "backend Gift Code profile registration incomplete")
  assert(eventArchive.registerGiftProfiles(
    mod.exports.alolaGiftForms66.giftProfiles()) == 18,
    "6.6 Alola Gift Code profile registration incomplete")
  mod.exports.eventArchive = eventArchive
  mod.exports.eventData = eventData
  -- 6.6 selected segment: the runtime sees digest-only campaign metadata.
  -- Plaintext tester codes remain outside the repository and package. Keep
  -- the controller on exports so this already dense factory consumes no new
  -- LuaJIT local slots.
  mod.exports.giftCodeCatalog = loadSibling(mod, "gift_code_catalog.lua")
  mod.exports.crossGenerationGiftProfiles66 = loadSibling(
    mod, "cross_generation_gift_profiles_66.lua")
  assert(mod.exports.crossGenerationGiftProfiles66.register(
    eventArchive, mod.exports.giftCodeCatalog),
    "6.6 cross-generation Gift Code profile registration incomplete")
  assert(mod.exports.generationRules.setOwnedGiftBattleCompatibilityProvider(
    function(_, mon)
      return eventArchive.battleCompatibleGift(mon)
    end), "event-gift battle compatibility binding failed")
  mod.exports.alolaGiftCodeCatalog66 = loadSibling(
    mod, "alola_gift_code_catalog.lua")
  for _, campaign in ipairs(
      mod.exports.alolaGiftCodeCatalog66.campaigns or {}) do
    mod.exports.giftCodeCatalog.campaigns[
      #mod.exports.giftCodeCatalog.campaigns + 1] = campaign
  end
  mod.exports.backendGiftCodeCatalog67 = loadSibling(mod,
    "backend_gift_code_catalog_67.lua")
  for _, campaign in ipairs(mod.exports.backendGiftCodeCatalog67.campaigns) do
    mod.exports.giftCodeCatalog.campaigns[#mod.exports.giftCodeCatalog.campaigns+1]=campaign
  end
  mod.exports.giftCodes = loadSibling(mod, "gift_codes.lua")(mod, {
    catalog = mod.exports.giftCodeCatalog,
    eventArchive = eventArchive,
    sharedArchive = legacyJourney.archive,
    followerSprites = followerSprites,
    i18n = i18n,
    supportLog = mod.exports.supportSessionLog,
  })

  -- Official Crystal battle art is bundled for all 251 species. Johto keeps
  -- its named front/back pack, while Kanto's numbered back pack completes the
  -- bundled animated fronts and also covers Yellow's special Pikachu route.
  local crystalAvailable = {}
  local crystalShinyAvailable = {}
  local function registerCrystalBackScale(id, relative)
    local source = mod.path .. "/" .. relative
    mod.content.battle_sprite_scales:register(id, {
      path = source,
      scale = 1,
    })
    -- spriteAssets.crystal removes the edge-connected opaque background and
    -- normally returns a derived-cache path. BattleState keys image scales by
    -- the path it actually loaded, so the prepared path needs its own record.
    local prepared = spriteAssets.crystal(relative)
    if prepared and prepared ~= source then
      mod.content.battle_sprite_scales:register(id .. "_PREPARED", {
        path = prepared,
        scale = 1,
      })
    end
  end
  for species, name in pairs(CRYSTAL_ASSETS) do
    local front = "assets/crystal/" .. name .. "_front.png"
    local back = "assets/crystal/" .. name .. "_back.png"
    crystalAvailable[species] =
      mod:read(front) ~= nil and mod:read(back) ~= nil
    crystalShinyAvailable[species] =
      mod:read("assets/crystal/" .. name .. "_front_shiny.png") ~= nil
      and mod:read("assets/crystal/" .. name .. "_back_shiny.png") ~= nil
    -- These are full 56x56 Crystal backs. Without an explicit image scale
    -- the 2D battle renderer applies the Gen-I 2x back-sprite default and
    -- clips them badly; Dramatic Shape happened to hide that mistake by
    -- requesting front art for both sides.
    if mod:read(back) ~= nil then
      registerCrystalBackScale(
        "KANTO_ASCENDANT_CRYSTAL_" .. species .. "_BACK", back)
    end
    local shinyBack = "assets/crystal/" .. name .. "_back_shiny.png"
    if mod:read(shinyBack) ~= nil then
      registerCrystalBackScale(
        "KANTO_ASCENDANT_CRYSTAL_" .. species .. "_BACK_SHINY", shinyBack)
    end
  end
  local kantoCrystalBacks = { normal = {}, shiny = {} }
  for dex = 1, 151 do
    local prefix = ("assets/crystal/kanto/%03d_back"):format(dex)
    local normalRelative = prefix .. ".png"
    local shinyRelative = prefix .. "_shiny.png"
    if mod:read(normalRelative) ~= nil then
      kantoCrystalBacks.normal[dex] = true
      registerCrystalBackScale(
        ("KANTO_ASCENDANT_CRYSTAL_%03d_BACK"):format(dex), normalRelative)
    end
    if mod:read(shinyRelative) ~= nil then
      kantoCrystalBacks.shiny[dex] = true
      registerCrystalBackScale(
        ("KANTO_ASCENDANT_CRYSTAL_%03d_BACK_SHINY"):format(dex),
        shinyRelative)
    end
  end
  mod.exports.crystalSprites = crystalAvailable
  mod.exports.crystalShinySprites = crystalShinyAvailable
  mod.exports.kantoCrystalBacks = kantoCrystalBacks
  -- Run before Crystal Animated Sprites' priority-930 resolver and the
  -- priority-990 Mega resolver. Some visual mods intentionally return their
  -- selected Kanto artwork without calling lower-priority hooks, so shiny DVs
  -- must be committed in a dedicated preflight rather than in our later
  -- priority-100 art-selection wrapper.
  mod.hooks:wrap("pokemon.sprite", function(nextSprite, path, ctx)
    if shinySystem then shinySystem.prepareSprite(ctx) end
    return nextSprite(path, ctx)
  end, 2000)
  mod.hooks:wrap("pokemon.sprite", function(nextSprite, path, ctx)
    local requestedPath = path
    ctx = ctx or {}
    path = nextSprite(path, ctx)
    local def = ctx.data and ctx.data.pokemon
      and ctx.data.pokemon[ctx.species]
    local dex = def and tonumber(def.dex)
    local name = ctx and CRYSTAL_ASSETS[ctx.species]

    -- Ascendant's #252-279 catalogue has one deliberately split identity:
    -- private `dex` is save/menu ordering, while sourceDex is reserved for
    -- National-Dex consumers such as Wilds. Every 2D game surface uses the
    -- exact authored internal-slot front/back card. select() reports motion
    -- only when this exact registered species has supplied timing and a real
    -- next frame; staticFrameOne remains the honest fallback for missing
    -- sources and every one-pose rear card.
    local extendedIdentity = mod.exports.extendedSpeciesRuntime
      and mod.exports.extendedSpeciesRuntime.identity(ctx.species, ctx.data)
    if extendedIdentity
        and not (ctx.mon and (ctx.mon._ascMegaForm or ctx.mon.ascMegaForm)) then
      local extendedSide = ctx.side == "back" and "back" or "front"
      local voxelFront = extendedSide == "back"
        and def and path == def.spriteFront
      if voxelFront then extendedSide = "front" end
      local externalOverride = type(path) == "string" and path ~= ""
        and path ~= requestedPath and not voxelFront
      if externalOverride then
        if crystalAnimation then
          crystalAnimation.select(ctx, extendedSide, true)
        end
        return shinySystem and shinySystem.spritePath(path, ctx) or path
      end
      local shiny = shinySystem and shinySystem.isShiny(ctx.mon)
      local variant = shiny and "shiny" or "normal"
      local animated, animatedTrueColor
      if crystalAnimation then
        animated, animatedTrueColor = crystalAnimation.select(
          ctx, extendedSide, false)
      end
      if animated then
        ctx.trueColor = animatedTrueColor
        return animated
      end
      local static, staticTrueColor
      if crystalAnimation then
        static, staticTrueColor = crystalAnimation.staticFrameOne(
          ctx, extendedSide, variant)
      end
      if static then
        ctx.trueColor = staticTrueColor
        return static
      end
    end

    -- Gorochu's registered 2D sprite remains the flat/Crystal source. Its
    -- current 56px Crystal-primary frame owns catalogue-style views when the
    -- player did not explicitly request the Crystal Dex presentation.
    -- External sprite resolvers still win because their changed path is
    -- preserved before this local presentation choice is considered.
    local gorochuCrystalCatalogue =
      (ctx.kind == "dex" or ctx.kind == "summary")
        and mod.options:get("dex_sprite_style") == "crystal"
      or ctx.kind == "box"
        and mod.options:get("pokemon_sprite_style") == "crystal"
        and mod.options:get("sprite_style_box") ~= false
    if ctx.species == "GOROCHU"
        and (ctx.kind == "dex" or ctx.kind == "summary" or ctx.kind == "box")
        and not gorochuCrystalCatalogue
        and path == requestedPath and gorochuVisuals then
      -- Dex/status use the same current frame in the native and final HUD
      -- passes. Box previews remain on the ordinary image path.
      local relative = gorochuCatalogueOverlay
          and gorochuCatalogueOverlay.cataloguePath(ctx)
        or gorochuVisuals.cataloguePath(ctx.mon)
      if relative then
        ctx.trueColor = ctx.kind == "box"
        return mod.path .. "/" .. relative
      end
    end

    -- Pokédex and summary presentation share the player's static artwork
    -- choice. The party detail screen is a catalogue-style view, not a live
    -- battle, and must not fall back to the active ROM's old front after the
    -- player selected CRYSTAL. Johto has no native R/B/Y art, so #152-251
    -- always uses its bundled species-authentic Crystal frame instead of the
    -- old Kanto silhouette fallback.
    if ctx.kind == "dex" or ctx.kind == "summary" then
      local externalOverride = type(path) == "string" and path ~= ""
        and path ~= requestedPath
      if externalOverride or (crystalAnimation and dex and dex <= 151
          and crystalAnimation.externalKantoActive(dex)) then
        return path
      end
      if dex and dex >= 152 and dex <= 251 and crystalAnimation then
        local static, trueColor = crystalAnimation.staticFrameOne(
          ctx, "front", "normal")
        if static then
          ctx.trueColor = trueColor
          return static
        end
      end
      -- Registered guest species (Gorochu is Dex #1026) use the same
      -- Crystal frame provider.  Previously only #001-251 reached it, so
      -- the high-quality Pokédex/summary path silently fell back.
      if dex and dex > 251 and name
          and mod.options:get("dex_sprite_style") == "crystal"
          and crystalAnimation then
        local static, trueColor = crystalAnimation.staticFrameOne(
          ctx, "front", "normal")
        if static then ctx.trueColor = trueColor; return static end
      end
      if dex and dex >= 1 and dex <= 151
          and mod.options:get("dex_sprite_style") == "crystal"
          and crystalAnimation then
        local static, trueColor = crystalAnimation.staticFrameOne(
          ctx, "front", "normal")
        if static then
          ctx.trueColor = trueColor
          return static
        end
      end
      return path or requestedPath
    end

    local selectedSide = ctx.side == "back" and "back" or "front"
    -- Dramatic Shape asks the normal back-sprite route, then replaces its
    -- answer with the species' front path so both battlers face the voxel
    -- camera. Preserve that decision instead of forcing the Crystal back
    -- sprite over it.
    local voxelFront = selectedSide == "back"
      and def and path == def.spriteFront
    if voxelFront then
      selectedSide = "front"
    end
    -- A lower-priority visual mod that explicitly replaced the requested
    -- path owns this species. Dramatic Shape's intentional back->front swap
    -- is the one exception: Ascendant supplies its matching Crystal front.
    local externalOverride = type(path) == "string" and path ~= ""
      and path ~= requestedPath and not voxelFront
    if externalOverride then
      if crystalAnimation then
        crystalAnimation.select(ctx, selectedSide, true)
      end
      return shinySystem and shinySystem.spritePath(path, ctx) or path
    end

    -- The 6.5 Sprite tree is the single owner for every ordinary #001-251
    -- presentation surface. The selected style can be enabled independently
    -- for battle, party/status, Pokédex, boxes and all remaining scenes.
    -- External visual mods still win above this wrapper.
    local scopeKey = ({
      battle = "sprite_style_battle",
      summary = "sprite_style_summary",
      dex = "sprite_style_dex",
      box = "sprite_style_box",
    })[ctx.kind] or "sprite_style_scenes"
    local selectedStyle = mod.options:get("pokemon_sprite_style")
    local selectedForSurface = mod.options:get(scopeKey) ~= false
    if selectedStyle == "legacy"
        and (ctx.kind == "dex" or ctx.kind == "summary") then
      if crystalAnimation and dex and dex <= 151
          and crystalAnimation.externalKantoActive(dex) then
        return path
      end
      if dex and dex >= 152 and dex <= 251 and crystalAnimation then
        local static, trueColor = crystalAnimation.staticFrameOne(
          ctx, "front", "normal")
        if static then
          ctx.trueColor = trueColor
          return static
        end
      end
      if dex and dex >= 1 and dex <= 151
          and mod.options:get("dex_sprite_style") == "crystal"
          and crystalAnimation then
        local static, trueColor = crystalAnimation.staticFrameOne(
          ctx, "front", "normal")
        if static then
          ctx.trueColor = trueColor
          return static
        end
      end
      return path or requestedPath
    end
    if selectedStyle ~= "legacy"
        and dex and dex >= 1 and dex <= 251 then
      if crystalAnimation and dex <= 151
          and crystalAnimation.externalKantoActive(dex) then
        return shinySystem and shinySystem.spritePath(path, ctx) or path
      end
      if selectedStyle ~= "crystal" or not selectedForSurface then
        if crystalAnimation then
          crystalAnimation.select(ctx, selectedSide, true)
        end
        return shinySystem and shinySystem.spritePath(path, ctx) or path
      end

      local shiny = shinySystem and shinySystem.isShiny(ctx.mon)
      local variant = shiny and "shiny" or "normal"
      local animated, animatedTrueColor
      if crystalAnimation then
        animated, animatedTrueColor = crystalAnimation.select(
          ctx, selectedSide, false)
      end
      if animated then
        ctx.trueColor = animatedTrueColor
        return animated
      end

      local static, staticTrueColor
      if crystalAnimation then
        static, staticTrueColor = crystalAnimation.staticFrameOne(
          ctx, selectedSide, variant)
      end
      if static then
        ctx.trueColor = staticTrueColor
        return static
      end

      local relative
      if selectedSide == "back" and dex <= 151
          and kantoCrystalBacks.normal[dex] then
        relative = ("assets/crystal/kanto/%03d_back%s.png"):format(
          dex, shiny and kantoCrystalBacks.shiny[dex] and "_shiny" or "")
      elseif selectedSide == "back" and name
          and crystalAvailable[ctx.species] then
        relative = "assets/crystal/" .. name .. "_back"
          .. (shiny and crystalShinyAvailable[ctx.species]
            and "_shiny" or "") .. ".png"
      end
      if relative then
        ctx.trueColor = true
        return spriteAssets.crystal(relative)
          or (mod.path .. "/" .. relative)
      end

      -- Coverage validation should make this unreachable for #001-251.
      -- Keep the edition sprite as a safe fallback for a damaged install.
      return shinySystem and shinySystem.spritePath(path, ctx) or path
    end

    local bundledKantoBack = selectedSide == "back" and not voxelFront
      and dex and dex >= 1 and dex <= 151
      and kantoCrystalBacks.normal[dex]
      and mod.options:get("kanto_crystal_art") ~= false
      and not (crystalAnimation
        and crystalAnimation.externalKantoActive(dex))
    if bundledKantoBack then
      -- Crystal backs are full-size 56px cards. Gen I's original player
      -- sprites are half-size and normally drawn at 2x, so the per-image
      -- registry above explicitly keeps these at their native 1x size.
      ctx.trueColor = true
      if crystalAnimation then crystalAnimation.select(ctx, "back", false) end
      local shiny = shinySystem and shinySystem.isShiny(ctx.mon)
        and kantoCrystalBacks.shiny[dex]
      local relative = ("assets/crystal/kanto/%03d_back%s.png"):format(
        dex, shiny and "_shiny" or "")
      return mod.path .. "/" .. relative
    end
    if mod.options:get("legend_art") ~= "crystal"
        or not name or not crystalAvailable[ctx.species] then
      local animated, animatedTrueColor
      if crystalAnimation then
        animated, animatedTrueColor = crystalAnimation.select(
          ctx, selectedSide, false)
      end
      if animated then
        ctx.trueColor = animatedTrueColor
        return animated
      end
      return shinySystem and shinySystem.spritePath(path, ctx) or path
    end
    -- Crystal PNGs carry their own limited GBC palette. Opt them out of
    -- Gen1's four-shade/SGB recolor; the original fallback remains
    -- palette-aware.
    ctx.trueColor = true
    local shiny = shinySystem and shinySystem.isShiny(ctx.mon)
      and crystalShinyAvailable[ctx.species]
    local relative = "assets/crystal/" .. name .. "_"
      .. selectedSide .. (shiny and "_shiny" or "") .. ".png"
    local animated, animatedTrueColor
    if crystalAnimation then
      animated, animatedTrueColor = crystalAnimation.select(
        ctx, selectedSide, false)
    end
    if animated then
      ctx.trueColor = animatedTrueColor
      return animated
    end
    return spriteAssets.crystal(relative)
      or (mod.path .. "/" .. relative)
  end, 100)

  -- The party list uses the separate pokemon.icon seam. The bundled files
  -- are genuine six-pose 16x96 menu/walker sheets; party_icons.lua renders
  -- their two down-facing frames without the vanilla mirrored-OBJ treatment.
  -- A dedicated external icon resolver still keeps priority.
  mod.hooks:wrap("pokemon.icon", function(nextIcon, path, ctx)
    local requestedPath = path
    path = nextIcon(path, ctx)
    if type(path) == "string" and path ~= ""
        and path ~= requestedPath then
      return path
    end
    -- party_icons.lua replaces the engine's mirrored 8x8 OBJ renderer. If
    -- that compatibility seam is unavailable, keep vanilla icons instead of
    -- returning a sheet that the stock renderer cannot display correctly.
    if not mod.exports.partyIcons then return path end
    ctx = ctx or {}
    if mod.options:get("party_icon_style") ~= "animated"
        or mod.options:get("sprite_style_summary") == false then
      return path
    end
    local def = ctx.data and ctx.data.pokemon
      and ctx.data.pokemon[ctx.species]
    local dex = def and tonumber(def.dex)
    if not (dex and dex >= 1 and dex <= 251) then return path end
    return ("%s/assets/crystal_menu_icons/%03d.png"):format(mod.path, dex)
  end, 100)

  mod.exports.resolveLine = localizedLine
  mod.exports.resolveDecline = localizedDecline
  mod.exports.resolveWarning = localizedWarning
  mod.exports.levelGap = levelGap
  mod.exports.isPrizeLine = isPrizeLine
  mod.exports.restLine = localizedRestLine
  mod.exports.language = function()
    return i18n.isGerman() and "de" or "en"
  end
  mod.exports.rollRestSteps = rollRestSteps
  mod.exports.nextLevelBoost = nextLevelBoost
  mod.exports.boostedTeam = boostedTeam
  mod.exports.recruitTeam = recruitment.expand
  mod.exports.recruitPools = recruitment.pools
  mod.exports.recruitment = recruitment
  -- Preserve the legacy inspection seam: callers receive an item id,
  -- not the new stack row.  Registry-aware callers pass imported data either
  -- as the fourth argument or as ctx.data.
  mod.exports.lootForRoll = function(roll, mode, ctx, data)
    local row = loot.select(roll, mode, ctx,
      data or (ctx and ctx.data))
    return row and row.item or nil, row and row.qty or nil
  end
  mod.exports.rematchLoot = loot
  mod.exports.lootBands = loot.bands
  mod.exports.defaults = {
    minRestSteps = DEFAULT_MIN_REST_STEPS,
    maxRestSteps = DEFAULT_MAX_REST_STEPS,
    levelGain = DEFAULT_LEVEL_GAIN,
    maxLevelBoost = MAX_LEVEL_BOOST,
  }

  -- `step_clock` is the literal number of tiles walked. Systems such as
  -- friendship, eggs and world events must never observe Training Rush's
  -- trainer-only bonus. `trainer_step_clock` is the accelerated timeline
  -- used exclusively by field-trainer recovery and silent growth.
  local function playerStepClock()
    return math.max(0, math.floor(tonumber(mod.save:get("step_clock", 0)) or 0))
  end

  local function stepClock()
    local clock = mod.save:get("trainer_step_clock")
    if clock == nil then return playerStepClock() end
    return math.max(0, math.floor(tonumber(clock) or 0))
  end

  mod.exports.playerStepClock = playerStepClock
  mod.exports.trainerStepClock = stepClock
  legacyWanderers.setClockProvider(stepClock)

  local function trainerStates()
    local states = mod.save:get("trainers")
    if type(states) ~= "table" then
      states = {}
      mod.save:set("trainers", states)
    end
    return states
  end

  local makeWorldEvents = loadSibling(mod, "world_events.lua")
  local worldEvents = makeWorldEvents(mod, {
    postgame = postgame,
    i18n = i18n,
    johtoResearch = johtoResearch,
    beyondKanto = mod.exports.beyondKanto,
    generationRules = mod.exports.generationRules,
    showMenu = false,
  })
  signalsHub.setWorldEvents(worldEvents)
  shinySystem.setWorldEvents(worldEvents)
  mod.exports.worldEvents = worldEvents

  ascendant = makeAscendant(mod, postgameData, {
    data = ascendantData,
    postgame = postgame,
    i18n = i18n,
    trainerStates = trainerStates,
    eventArchive = eventArchive,
    johtoResearch = johtoResearch,
    worldEvents = worldEvents,
    kantoCompletion = kantoCompletion,
    legacyPaths = legacyPaths,
    placement = mod.exports.runtimeNpcPlacement,
    rocketRecovery = mod.exports.rocketRecoveryRaids67,
  })
  eventArchive.setAscendant(ascendant)
  postgame.extension = ascendant
  if postgame.setMastery then
    postgame.setMastery(rematchMastery, function(context)
      return ascendant and ascendant.bossBattleCount
        and ascendant.bossBattleCount(context) or 0
    end)
  end
  mod.exports.ascendant = ascendant
  mod.exports.ascendantData = ascendantData

  local makeFrontierExchange = loadSibling(mod, "frontier_exchange.lua")
  local frontierExchange = makeFrontierExchange(mod, {
    i18n = i18n,
    postgame = postgame,
    wallet = ascendant,
    johtoResearch = johtoResearch,
    fieldTech = fieldTech,
  })
  daycare.setFrontierExchange(frontierExchange)
  mod.exports.frontierExchange = frontierExchange

  local johtoMastersData = loadSibling(mod, "johto_masters_data.lua")
  local makeJohtoMasters = loadSibling(mod, "johto_masters.lua")
  local johtoMasters = makeJohtoMasters(mod, {
    data = johtoMastersData,
    postgame = postgame,
    ascendant = ascendant,
    shinySystem = shinySystem,
    i18n = i18n,
    journey = legacyJourney,
    beyondKanto = mod.exports.beyondKanto,
    generationRules = mod.exports.generationRules,
    placement = mod.exports.runtimeNpcPlacement,
    fieldTech = fieldTech,
  })
  ascendant.setJohtoMasters(johtoMasters)
  mod.exports.johtoMasters = johtoMasters
  mod.exports.johtoMastersData = johtoMastersData
  johtoMasters.music = loadSibling(mod, "johto_masters_music.lua")(mod)
  if contentEnabled then johtoMasters.music.register() end
  mod.exports.johtoMastersMusic = johtoMasters.music
  -- One attached controller keeps the large install closure below from
  -- gaining another local while passages retain their own map namespace.
  johtoMasters.passages = loadSibling(mod, "johto_masters_passages.lua")(mod, {
    baseline = johtoMasters, postgame = postgame, i18n = i18n,
    questionUi = ascendantUi,
    contentEnabled = contentEnabled,
    tilesetFactory = loadSibling(mod, "johto_masters_tilesets.lua"),
    music = johtoMasters.music,
  })
  johtoMasters.passages.register()
  mod.exports.johtoMastersPassages = johtoMasters.passages

  local makeDexProgress = loadSibling(mod, "dex_progress.lua")
  local dexProgress = makeDexProgress(mod, {
    i18n = i18n,
    postgame = postgame,
    johtoData = johtoData,
    shinySystem = shinySystem,
    ascendant = ascendant,
    beyondKanto = mod.exports.beyondKanto,
  })
  mod.exports.dexProgress = dexProgress
  if signalsHub and type(signalsHub.setDexProgress) == "function" then
    signalsHub.setDexProgress(dexProgress)
  end
  if johtoResearch and type(johtoResearch.setDexProgress) == "function" then
    johtoResearch.setDexProgress(dexProgress)
  end
  mod.exports.beyondKanto.bindControllers({
    signals = johtoSignals, research = johtoResearch, dex = dexProgress,
  })

  local makeAscendantTyphlosion = loadSibling(
    mod, "ascendant_typhlosion.lua")
  local ascendantTyphlosion = makeAscendantTyphlosion(mod, {
    i18n = i18n,
    johtoMasters = johtoMasters,
    megaEvolution = megaEvolution,
    showMenu = false,
  })
  mod.exports.ascendantTyphlosion = ascendantTyphlosion
  local makeStarterRelicQuests = loadSibling(
    mod, "starter_relic_quests.lua")
  local starterRelicQuests = makeStarterRelicQuests(mod, {
    i18n = i18n,
    megaEvolution = megaEvolution,
    ascendantTyphlosion = ascendantTyphlosion,
    placement = mod.exports.runtimeNpcPlacement,
  })
  mod.exports.starterRelicQuests = starterRelicQuests

  local makeResearchAtlas = loadSibling(mod, "research_atlas.lua")
  local researchAtlas = makeResearchAtlas(mod, {
    generationRules = mod.exports.generationRules,
    i18n = i18n,
    postgame = postgame,
    ascendant = ascendant,
    ascendantData = ascendantData,
    fieldTech = fieldTech,
    kantoCompletion = kantoCompletion,
    johtoResearch = johtoResearch,
    lootBands = loot.bands,
    loot = loot,
    trainerStates = trainerStates,
    stepClock = stepClock,
    signalsHub = signalsHub,
  })
  mod.exports.researchAtlas = researchAtlas

  local grandTourData = loadSibling(mod, "grand_tour_data.lua")
  local makeGrandTour = loadSibling(mod, "grand_tour.lua")
  local grandTour = makeGrandTour(mod, {
    data = grandTourData,
    postgame = postgame,
    i18n = i18n,
    dialoguePagination = dialoguePagination,
    beyondKanto = mod.exports.beyondKanto,
    generationRules = mod.exports.generationRules,
    stepClock = playerStepClock,
    placement = mod.exports.runtimeNpcPlacement,
    awardFrontierPoints = function(amount)
      local multiplier = worldEvents and worldEvents.frontierMultiplier
        and worldEvents.frontierMultiplier() or 1
      return ascendant.addFrontierPoints(
        math.max(0, math.floor(tonumber(amount) or 0))
          * math.max(1, math.floor(tonumber(multiplier) or 1)))
    end,
    unlockTitle = function(id)
      return ascendant.unlockAchievement(id)
    end,
  })
  mod.exports.grandTour = grandTour
  mod.exports.grandTourData = grandTourData

  local makeQuestTracker = loadSibling(mod, "quest_tracker.lua")
  local questTracker = makeQuestTracker(mod, {
    i18n = i18n,
    postgame = postgame,
    postgameData = postgameData,
    ascendant = ascendant,
    ascendantData = ascendantData,
    johtoResearch = johtoResearch,
    johtoData = johtoData,
    johtoMasters = johtoMasters,
    grandTour = grandTour,
    ascendantTyphlosion = ascendantTyphlosion,
    starterRelicQuests = starterRelicQuests,
    signalsHub = signalsHub,
    legacyPaths = legacyPaths,
    beyondKanto = mod.exports.beyondKanto,
    rocketRecovery = mod.exports.rocketRecoveryRaids67,
  })
  ascendant.setQuestTracker(questTracker)
  researchAtlas.setQuestTracker(questTracker)
  questTracker.setSignalsHub(signalsHub)
  researchAtlas.setSignalsHub(signalsHub)
  mod.exports.questTracker = questTracker

  local makeOnboarding = loadSibling(mod, "onboarding.lua")
  local onboarding = makeOnboarding(mod, {
    i18n = i18n,
    postgame = postgame,
    questTracker = questTracker,
  })
  mod.exports.onboarding = onboarding

  local makeLegacyHall = loadSibling(mod, "legacy_hall.lua")
  local legacyHall = makeLegacyHall(mod, {
    i18n = i18n,
    postgame = postgame,
    ascendant = ascendant,
    ascendantData = ascendantData,
    johtoMasters = johtoMasters,
    grandTour = grandTour,
    legacyPaths = legacyPaths,
    legacyJourney = legacyJourney,
  })
  mod.exports.legacyHall = legacyHall
  legacyHall.setExtraTitleProvider(mod.exports.surpriseTrainers67)
  mod.exports.surpriseTrainers67.bindHall(legacyHall)
  mod.exports.titleAuthority67 = legacyHall
  legacyWanderers.setTitleProvider(legacyHall)

  -- 66-WORLD-RANK: isolated tournament controller. Keep the controllers on
  -- the Hall namespace so this Lua 5.1 entry chunk stays below its local cap.
  legacyHall.worldRankData = loadSibling(mod, "ngplus_tournament_data.lua")
  legacyHall.worldRankGuests = loadSibling(
    mod, "ngplus_tournament_guests.lua")(mod, {
      json = loadSibling(mod, "world_rank_json.lua"),
      i18n = i18n,
      battleTheme = "Music_KA_GSC_RivalBattle",
    })
  -- Each optional identity registers independently and remains unavailable
  -- unless all four approved visual surfaces and its exact team are valid.
  legacyHall.worldRankGuests.register()
  mod.exports.worldRankTournamentGuests = legacyHall.worldRankGuests
  legacyHall.worldRankOpponentAuthority = function(classId, game)
    if classId == "OPP_CYNTHIA_KA" or classId == "OPP_ASH_KA" then
      return legacyHall.worldRankGuests.authority(classId, game)
    end
    local record = game and game.data and game.data.trainers
      and game.data.trainers[classId]
    local spriteId = legacyHall.worldRankData.trainerOverworldSprites
      and legacyHall.worldRankData.trainerOverworldSprites[classId]
    if not (type(record) == "table" and type(spriteId) == "string"
        and type(record.pic) == "string" and record.pic ~= ""
        and type(game.data.sprites) == "table"
        and game.data.sprites[spriteId] ~= nil) then
      return nil
    end
    return {
      class = classId,
      trainerRecord = record,
      battlePortrait = { id = record.pic, registered = true },
      overworldSprite = { id = spriteId, registered = true },
    }
  end
  -- This fail-closed adapter is visible only until the concrete reward
  -- transaction below is fully constructed.
  legacyHall.worldRankRewardAdapter = {
    status = function()
      return { ready = false, pending = true, status = "adapter_pending" }
    end,
    pendingModel = function(_, queue)
      return {
        pending = type(queue) == "table" and #queue > 0,
        pendingCount = type(queue) == "table" and #queue or 0,
        text = i18n.text(
          "A sealed World Rank prize is waiting for delivery.",
          "Ein versiegelter Weltrang-Preis wartet auf Zustellung."),
      }
    end,
    reconcile = function() return false, "adapter_pending" end,
  }
  mod.exports.worldRankTournamentRewardAdapter =
    legacyHall.worldRankRewardAdapter
  legacyHall.worldRank = loadSibling(mod, "ngplus_tournament.lua")(mod, {
    data = legacyHall.worldRankData,
    i18n = i18n,
    generationRules = mod.exports.generationRules,
    supportLog = mod.exports.supportSessionLog,
    journey = legacyJourney,
    edition = function() return GameVersion.get() end,
    profile = function(game)
      local save = game and game.save or {}
      local meta = type(save.meta) == "table" and save.meta or {}
      return meta.playthroughId or meta.profileId or meta.slotId
        or save.playthroughId or save.profileId or "native"
    end,
    hallCount = function(game)
      return #(game and game.save and game.save.hallOfFame or {})
    end,
    language = function() return mod.exports.language() end,
    legacyState = function()
      return legacyJourney.archive.worldRankState()
    end,
    legacyUnlocked = function()
      local state = legacyJourney.archive.worldRankState()
      return type(state) == "table" and state.unlocked == true
    end,
    markLegacyUnlocked = function(game)
      return legacyJourney.archive.markWorldRankUnlocked(game and game.save)
    end,
    opponentAuthority = legacyHall.worldRankOpponentAuthority,
    formatAuthority = function(game, formatId)
      local authority = legacyHall.worldRankRosters
      if authority and type(authority.formatAuthority) == "function" then
        return authority.formatAuthority(game, formatId)
      end
    end,
    opponentClass = function(game, formatId, rank, token)
      local authority = legacyHall.worldRankRosters
      if authority and type(authority.opponentClass) == "function" then
        return authority.opponentClass(game, formatId, rank, token)
      end
    end,
    rewardPendingModel = function(game, queue)
      local adapter = mod.exports.worldRankTournamentRewards
        or legacyHall.worldRankRewardAdapter
      local pending = adapter and (adapter.pendingModel or adapter.status)
      if type(pending) == "function" then return pending(game, queue) end
    end,
  })
  mod.exports.hoennTournamentEncounters67 = loadSibling(
    mod, "hoenn_tournament_encounters_67.lua")(mod, {
      acquisition = mod.exports.hoennAcquisition67Data,
      discoveryCore = mod.exports.discoveryCore,
      legacyProfile = legacyJourney.profile,
      generationRules = mod.exports.generationRules,
      forceShiny = function(mon, definition)
        return shinySystem and shinySystem.forceMon
          and shinySystem.forceMon(mon, definition) == true
      end,
    })
  legacyHall.worldRankRewards = loadSibling(
    mod, "ngplus_tournament_rewards.lua")(mod, {
      data = legacyHall.worldRankData,
      equipmentRewards = mod.exports.equipmentRewards67,
      generationRules = mod.exports.generationRules,
      tournament = legacyHall.worldRank,
      archive = legacyJourney.archive,
      i18n = i18n,
      discoveryAuthority = function(game, species)
        local pokedex = game and game.save and game.save.pokedex or {}
        local seen = type(pokedex.seen) == "table" and pokedex.seen or {}
        local owned = type(pokedex.owned) == "table" and pokedex.owned or {}
        return seen[species] == true or owned[species] == true
      end,
      speciesReady = mod.exports.hoennTournamentEncounters67
        .ordinaryRewardEligible,
      onDelivered = mod.exports.hoennTournamentEncounters67
        .onTournamentDelivered,
      forceShiny = function(mon, definition)
        return shinySystem and shinySystem.forceMon
          and shinySystem.forceMon(mon, definition) == true
      end,
      isShiny = function(mon)
        return shinySystem and shinySystem.isShiny
          and shinySystem.isShiny(mon) == true
      end,
      grantTitle = function(_, id)
        local state = ascendant.state(false)
        if type(state) == "table" and type(state.achievements) == "table"
            and state.achievements[id] == true then return true end
        ascendant.unlockAchievement(id)
        state = ascendant.state(false)
        return type(state) == "table" and type(state.achievements) == "table"
          and state.achievements[id] == true
      end,
      linkActive = function(game)
        return game and (game.linkSession ~= nil and game.linkSession ~= false
          or type(game.linkNet) == "table"
            and game.linkNet.closed ~= true) or false
      end,
    })
  mod.exports.worldRankTournamentRewards = legacyHall.worldRankRewards
  legacyHall.worldRankRosters = loadSibling(
    mod, "ngplus_tournament_rosters.lua")({
      data = legacyHall.worldRankData,
      tournament = legacyHall.worldRank,
      generationRules = mod.exports.generationRules,
      trainerAuthority = legacyHall.worldRankOpponentAuthority,
      megaAuthority = function(_, species)
        local rows = megaEvolution and megaEvolution.formsBySpecies
          and megaEvolution.formsBySpecies[species]
        local profile = type(rows) == "table" and rows[1] or nil
        if not (profile and profile.stone and profile.id) then return nil end
        return { stone = profile.stone, form = profile.id }
      end,
    })
  legacyHall.worldRankPolicy = loadSibling(
    mod, "ngplus_tournament_battle_policy.lua")({
      text = function(en, de) return i18n.text(en, de) end,
    })
  legacyHall.worldRankRuntime = loadSibling(
    mod, "ngplus_tournament_runtime.lua")(mod, {
      tournament = legacyHall.worldRank,
      data = legacyHall.worldRankData,
      rosters = legacyHall.worldRankRosters,
      policy = legacyHall.worldRankPolicy,
      placement = mod.exports.runtimeNpcPlacement,
      postgame = postgame,
      i18n = i18n,
      opponentAuthority = legacyHall.worldRankOpponentAuthority,
      rewardAdapter = function()
        return mod.exports.worldRankTournamentRewards
          or legacyHall.worldRankRewardAdapter
      end,
    })
  mod.exports.worldRankTournament = legacyHall.worldRank
  mod.exports.worldRankTournamentData = legacyHall.worldRankData
  mod.exports.worldRankTournamentRosters = legacyHall.worldRankRosters

  -- The separately owned habitat card now supplies the rumor dependencies;
  -- ordinary rival meetings keep their existing scheduler and team authority.
  mod.exports.rivalTeamProgression = loadSibling(
    mod, "rival_team_progression.lua")({
      supportLog = mod.exports.supportSessionLog,
    })
  legacyHall.lifeOfRivalCard67 = loadSibling(
    mod, "life_of_rival_card_67.lua")(mod, {
      load = function(filename) return loadSibling(mod, filename) end,
      supportLog = mod.exports.supportSessionLog,
      life = {
        i18n = i18n,
        gameVersion = GameVersion,
        characters = extendedCharacters,
        postgame = postgame,
        rivalTeams = mod.exports.rivalTeams,
        teamProgression = mod.exports.rivalTeamProgression,
        wanderers = legacyWanderers,
        spawnSafety = wildsSpawnSafety,
        titles = legacyHall,
        journey = legacyJourney,
        beyondKanto = mod.exports.beyondKanto,
        generationRules = mod.exports.generationRules,
        rumorsEnabled = true,
        explorationDevice = mod.exports.explorationDevice,
        hiddenAccessReveal = mod.exports.hiddenAccessReveal,
        starterHabitats = mod.exports.starterHabitats,
        dialogues = loadSibling(mod, "life_of_rival_dialogue_data.lua"),
      },
      parallel = {
        i18n = i18n,
        characters = extendedCharacters,
        postgame = postgame,
        spawnSafety = wildsSpawnSafety,
        data = loadSibling(mod, "life_of_rival_journey_data.lua"),
      },
    })
  mod.exports.lifeOfRivalCard67 = legacyHall.lifeOfRivalCard67
  mod.exports.lifeOfRival = legacyHall.lifeOfRivalCard67.life
  mod.exports.rivalParallelJourney = legacyHall.lifeOfRivalCard67.parallel
  assert(mod.exports.explorationDevice.setNoTargetHint(function(game)
    return mod.exports.lifeOfRival.traceFinderQuestHint(game)
  end), "TRACE FINDER starter-rumor hint binding failed")

  -- The native Trainer Card is authored on the fixed 160x144 UI canvas.
  -- Keep it as the final input/error fallback, but retain one standard-card
  -- owner at window resolution so the already-bundled 128px portraits and
  -- leader art remain genuinely high resolution.
  local makeTrainerCardHDStandard = loadSibling(
    mod, "trainer_card_hd_standard.lua")
  local trainerCardHDStandard = makeTrainerCardHDStandard(mod, {
    i18n = i18n,
    extendedCharacters = extendedCharacters,
    legacyHall = legacyHall,
  })
  mod.exports.trainerCardHDStandard = trainerCardHDStandard

  -- 66-HD-TRAINER-CARD-COLLECTION owns only catalogue/save/presentation
  -- policy. It delegates the effective screen and final-window pass to the
  -- existing HD-standard owner, which remains the immediate error fallback.
  -- Hang the two objects off legacyHall to avoid consuming entry-chunk locals
  -- near Lua 5.1's local-variable ceiling.
  legacyHall.trainerCards = loadSibling(mod,
    "trainer_card_collection.lua")(mod, {
      i18n = i18n,
      postgame = postgame,
      ascendant = ascendant,
      legacyHall = legacyHall,
      worldRankTournament = legacyHall.worldRank,
      showWorldRankDialogue = function(game, text, done, receipt)
        return legacyHall.worldRankRuntime.presentText(
          game, text, done, receipt)
      end,
    })
  legacyHall.trainerCardHD = loadSibling(mod,
    "trainer_card_hd_renderer.lua")(mod, {
      collection = legacyHall.trainerCards,
      i18n = i18n,
      characters = extendedCharacters,
      standardFallback = trainerCardHDStandard,
    })
  mod.exports.trainerCardCollection = legacyHall.trainerCards
  mod.exports.trainerCardHDRenderer = legacyHall.trainerCardHD
  mod.exports.rocketRecoveryRaids67.bindRewards({
    awardTrainerCard = function(id, reason, game)
      return legacyHall.trainerCards.award(id, reason, game)
    end,
  })

  local function trainerKey(overworld, npc)
    if npc and npc.id then return tostring(npc.id) end
    local mapId = overworld and overworld.map and overworld.map.id or "UNKNOWN"
    local index = npc and npc.def and npc.def.index or "?"
    return tostring(mapId) .. "_obj_" .. tostring(index)
  end

  -- Route 22's first rival is an onStep story encounter, not a field
  -- trainer.  It intentionally remains available after a loss until its
  -- story flag is set on a win.  Its hidden/respawned object can otherwise
  -- look like a defeated trainer to the generic talk hook after a reload.
  -- Keep this deliberately narrow: ordinary OPP_RIVAL1 trainers and every
  -- normal trainer on Route 22 retain the standard rematch path.
  local function isRoute22FirstRival(overworld, npc, scripts)
    local map = overworld and overworld.map
    local def = npc and npc.def
    -- The real generated ROUTE22_RIVAL1 object intentionally has no
    -- trainerClass; its onStep story script supplies OPP_RIVAL1 at runtime.
    -- Match the authored object identity/text instead of a field that exists
    -- only on ordinary talk trainers (and previously only in the test stub).
    if not (map and map.id == "ROUTE_22" and def
        and ((def.name == "ROUTE22_RIVAL1")
          or (def.index == 1 and def.text == "TEXT_ROUTE22_RIVAL1"))) then
      return false
    end
    local script = scripts and scripts.get and scripts.get(map.id)
    return script and type(script.onStep) == "function" or false
  end

  local function stateFor(key, create)
    local states = trainerStates()
    local state = states[key]
    if type(state) ~= "table" and create then
      state = {
        rematches = 0, trainingCycles = 0, masteryWins = 0,
        recruitFamilies = {},
      }
      states[key] = state
    end
    if type(state) == "table" then
      state.rematches = math.max(0, math.floor(
        tonumber(state.rematches) or 0))
      state.trainingCycles = math.max(0, math.floor(
        tonumber(state.trainingCycles) or 0))
      state.masteryWins = math.max(0, math.floor(
        tonumber(state.masteryWins) or 0))
      state.recruitFamilies = type(state.recruitFamilies) == "table"
        and state.recruitFamilies or {}
      state.recruitHistory = type(state.recruitHistory) == "table"
        and state.recruitHistory or {}
      while #state.recruitHistory > 3 do table.remove(state.recruitHistory, 1) end
      state.originalStages = type(state.originalStages) == "table"
        and state.originalStages or {}
      state.originalBranches = type(state.originalBranches) == "table"
        and state.originalBranches or {}
      state.rematchProgressionVersion = math.max(1, math.floor(
        tonumber(state.rematchProgressionVersion) or 1))
    end
    return state
  end

  local function levelGain()
    return clampedInteger(mod.options:get("level_gain"),
      DEFAULT_LEVEL_GAIN, 0, MAX_LEVEL_GAIN)
  end

  local function randomSource(deps)
    if deps and deps.random then return deps.random end
    if love and love.math and love.math.random then return love.math.random end
    return math.random
  end

  local function configuredRestRange()
    return restProfiles.range(
      mod.options:get("rest_profile"),
      mod.options:get("rest_min"), mod.options:get("rest_max"))
  end
  mod.exports.configuredRematchRestRange = configuredRestRange

  local function rollConfiguredRest(deps)
    local minSteps, maxSteps = configuredRestRange()
    return rollRestSteps(randomSource(deps), minSteps, maxSteps)
  end

  local function scheduleNextTraining(state, startAt, deps)
    local duration = rollConfiguredRest(deps)
    state.nextTrainingAt = math.floor(tonumber(startAt) or stepClock()) + duration
    state.lastTraining = duration
    return duration
  end

  -- Once the visible post-battle rest has expired, the trainer stays ready
  -- but keeps training on silent rest-sized intervals. Every fully completed
  -- interval raises the next rematch tier. Settling on every world step makes
  -- this genuinely background progression; the lazy calls also repair old
  -- saves that predate nextTrainingAt.
  local function settleTraining(state, deps)
    if type(state) ~= "table" or not state.readyAt then return 0 end
    local clock = stepClock()
    if clock < state.readyAt then return 0 end
    state.trainingCycles = math.max(0, math.floor(
      tonumber(state.trainingCycles) or 0))
    if not state.nextTrainingAt then
      -- A 1.0.5-or-older save cannot tell how long its ready trainer has
      -- already waited. Start the first silent cycle now rather than granting
      -- speculative levels retroactively.
      scheduleNextTraining(state, clock, deps)
      return 0
    end

    local gained = 0
    while clock >= state.nextTrainingAt
        and state.trainingCycles < MAX_LEVEL_BOOST do
      state.trainingCycles = state.trainingCycles + 1
      gained = gained + 1
      scheduleNextTraining(state, state.nextTrainingAt, deps)
    end
    -- +99 reaches level 100 even from level 1 when LEVEL GAIN is 1. Keep the
    -- silent clock moving without an unbounded catch-up loop once no further
    -- strength can be represented.
    if clock >= state.nextTrainingAt then
      scheduleNextTraining(state, clock, deps)
    end
    return gained
  end

  local function settleAllTraining(deps)
    for _, state in pairs(trainerStates()) do
      settleTraining(state, deps)
    end
  end

  local function migrateRestTimers(deps)
    if tonumber(mod.save:get("rest_range_version", 0)) >= 3 then return end
    -- Profiles govern only intervals rolled after this point. Existing
    -- readyAt/nextTrainingAt/bossRest timestamps are authoritative and must
    -- never jump merely because the menu representation changed.
    mod.save:set("rest_range_version", 3)
  end
  mod.exports.migrateRestTimers = migrateRestTimers

  local function remainingSteps(key)
    local state = stateFor(key, false)
    if not state or not state.readyAt then return 0 end
    settleTraining(state)
    return math.max(0, math.floor(state.readyAt - stepClock()))
  end

  local function trainingCycles(key)
    local state = stateFor(key, false)
    if not state then return 0 end
    settleTraining(state)
    return state.trainingCycles
  end

  local function scheduleRest(key, deps)
    local state = stateFor(key, true)
    local duration = rollConfiguredRest(deps)
    state.readyAt = stepClock() + duration
    state.lastRest = duration
    -- This second interval is invisible: readiness remains available after
    -- readyAt, while reaching nextTrainingAt grows the team in the background.
    scheduleNextTraining(state, state.readyAt, deps)
    return duration
  end

  local function seedDefeatedTrainers(save, deps)
    for key, defeated in pairs((save and save.defeatedTrainers) or {}) do
      if defeated and not stateFor(key, false) then scheduleRest(key, deps) end
    end
  end

  local function strengthenBattle(game, battle, boost)
    battle.rematchLevelBoost = boost
    if boost <= 0 or not battle.enemyParty then return end

    local Pokemon = require("src.pokemon.Pokemon")
    local Stats = require("src.pokemon.Stats")
    local Growth = require("src.pokemon.Growth")
    for _, mon in ipairs(battle.enemyParty) do
      local oldLevel = tonumber(mon.level) or 1
      local newLevel = math.min(MAX_POKEMON_LEVEL, oldLevel + boost)
      if newLevel > oldLevel then
        local species = game.data.pokemon[mon.species]
        local previousMoves = {}
        for index, move in ipairs(mon.moves or {}) do
          previousMoves[index] = {}
          for key, value in pairs(move) do previousMoves[index][key] = value end
        end
        -- Growing between rematches can teach normal level-up moves while
        -- preserving any special trainer moves already applied by the
        -- battle constructor.
        Pokemon.learnMovesFromDayCare(game.data, mon, species, oldLevel, newLevel)
        local adaptive = mod.exports.adaptiveTrainerLevels
        if adaptive and type(adaptive.ensureDamagingMove) == "function" then
          -- Day Care replacement may otherwise shift out the last damaging
          -- move (notably Butterfree's CONFUSION across the powder levels).
          -- This guard runs only for an actually raised trainer Pokémon.
          pcall(adaptive.ensureDamagingMove,
            game.data, mon, species, previousMoves, newLevel)
        end
        mon.level = newLevel
        mon.exp = Growth.expForLevel(species.growthRate, newLevel,
                                      game.data.growth_rates)
        local fresh = Stats.calc(
          species, newLevel, mon.dvs, mon.statExp, mon)
        -- The active battler points at this stats table already, so mutate
        -- it in place instead of replacing it underneath the HUD/damage code.
        mon.stats = mon.stats or {}
        for stat, value in pairs(fresh) do mon.stats[stat] = value end
        mon.hp = mon.stats.hp
      end
    end
    if battle.enemy and battle.enemy.mon then
      battle.enemy.shownHP = battle.enemy.mon.hp
    end
  end

  local function appendRecruits(game, battle, team)
    if not (battle and battle.enemyParty and type(team) == "table") then return 0 end
    local first = #battle.enemyParty + 1
    if first > #team then return 0 end
    local Pokemon = require("src.pokemon.Pokemon")
    local Stats = require("src.pokemon.Stats")
    local trainerDvs = (game.data.constants and game.data.constants.trainerDvs)
      or { hp = 8, attack = 9, defense = 8, speed = 8, special = 8 }
    local added = 0
    for i = first, math.min(6, #team) do
      local slot = team[i]
      if game.data.pokemon[slot.species] then
        local mon = Pokemon.new(game.data, slot.species, slot.level,
          function(lo, hi) return math.floor((lo + hi) / 2) end)
        mon.dvs = trainerDvs
        mon.stats = Stats.calc(game.data.pokemon[slot.species],
          slot.level, trainerDvs, nil, mon)
        mon.hp = mon.stats.hp
        if slot.moves then
          mon.moves = {}
          for _, moveId in ipairs(slot.moves) do
            local move = game.data.moves[moveId]
            mon.moves[#mon.moves + 1] = {
              id = moveId, pp = move and move.pp or 0,
            }
          end
        end
        battle.enemyParty[#battle.enemyParty + 1] = mon
        added = added + 1
      end
    end
    return added
  end

  local function applyOriginalProgression(game, battle, baseTeam, rematchTeam)
    if not (battle and battle.enemyParty and type(baseTeam) == "table"
        and type(rematchTeam) == "table") then return 0 end
    local Pokemon = require("src.pokemon.Pokemon")
    local Stats = require("src.pokemon.Stats")
    local trainerDvs = (game.data.constants and game.data.constants.trainerDvs)
      or { hp = 8, attack = 9, defense = 8, speed = 8, special = 8 }
    local evolved = 0
    for index = 1, math.min(#baseTeam, #battle.enemyParty) do
      local planned = rematchTeam[index]
      local original = baseTeam[index]
      local current = battle.enemyParty[index]
      if planned and original and planned.species ~= original.species
          and current and current.species == original.species
          and game.data.pokemon[planned.species] then
        local level = math.max(1, math.min(100,
          math.floor(tonumber(current and current.level)
            or tonumber(original.level) or 1)))
        local mon = Pokemon.new(game.data, planned.species, level,
          function(lo, hi) return math.floor((lo + hi) / 2) end)
        mon.dvs = trainerDvs
        mon.stats = Stats.calc(game.data.pokemon[planned.species],
          level, trainerDvs, nil, mon)
        mon.hp = mon.stats.hp
        battle.enemyParty[index] = mon
        evolved = evolved + 1
      end
    end
    return evolved
  end

  -- BattleState.newTrainer materializes the active battler before Ascendant
  -- applies persistent rematch evolution. Replacing enemyParty[1] alone
  -- therefore leaves the old species definition, name, front image and
  -- Crystal-animation selection cached in battle.enemy. Rebuild the visible
  -- lead as one identity transaction while the battle is still off-screen.
  mod.exports.syncRematchLead = function(game, battle, BattleState)
    if not (game and game.data and battle and battle.enemyParty) then
      return false
    end
    local index = math.max(1, math.floor(tonumber(battle.enemyIndex) or 1))
    local lead = battle.enemyParty[index]
    if not lead or (battle.enemy and battle.enemy.mon == lead) then
      return false
    end
    BattleState = BattleState or require("src.battle.BattleState")
    if type(BattleState.makeBattler) ~= "function" then return false end
    battle.enemy = BattleState.makeBattler(game.data, lead, false)
    if game.save and game.save.pokedex then
      game.save.pokedex.seen = game.save.pokedex.seen or {}
      game.save.pokedex.seen[lead.species] = true
    end
    if type(battle.aiUsesFor) == "function" then
      battle.aiUses = battle:aiUsesFor()
    end
    return true
  end

  mod.exports.remainingSteps = remainingSteps
  mod.exports.trainingCycles = trainingCycles
  mod.exports.trainerKey = trainerKey
  mod.exports.trainerStates = trainerStates

  local function offerRematch(self, npc, game, deps)
    local d = npc.def
    local TextBox = deps.textBox or require("src.render.TextBox")
    local Runtime = deps.runtime or require("src.mods.Runtime")
    local BattleState = deps.battleState or require("src.battle.BattleState")
    npc.frozen = true
    npc:facePlayer(self.player)
    local unfreeze = function() npc.frozen = false end

    local function decline()
      -- the class reacts to the NO: mocking, or understanding for the
      -- wise classes.  The trainer's vanilla post-battle line follows as
      -- a second page, so the base-game text is never lost.
      local header = game.data:trainerHeader(self.map.def.label, d.index)
      local after = header and header.after and game.data.text[header.after]
      local line = localizedDecline(d.trainerClass)
      if after then line = line .. "\f" .. after end
      game.stack:push(TextBox.new(game, line, unfreeze))
    end

    local function accept()
      -- a mod may ship a dedicated rematch team for the class: the
      -- trainer record's rematchIndex points at it (Yellow Legacy Changes
      -- appends the hack's L64-77 rematch teams this way).  Fall back to
      -- the trainer's own party when none is marked.
      local record = game.data.trainers and game.data.trainers[d.trainerClass]
      local marked = record and record.rematchIndex
      local partyIndex = marked and record.parties and record.parties[marked]
          and marked or d.trainerParty
      local team = record and record.parties and record.parties[partyIndex]
      local key = trainerKey(self, npc)
      local state = stateFor(key, true)
      -- 5.0's Research Atlas remembers only trainers the player has already
      -- met.  These presentation fields do not affect the stable trainer key
      -- or any old save's cooldown data.
      state.mapId = self.map and self.map.id or state.mapId
      state.trainerClass = d.trainerClass or state.trainerClass
      settleTraining(state, deps)
      local progress = state.rematches + state.trainingCycles
      local boost = nextLevelBoost(progress, levelGain())
      local rank = ascendant and ascendant.rematchRank(progress)
      local rosterAuthority = rematchRosterAuthority.authority(game, {
        kind = "field", key = key, trainerClass = d.trainerClass,
        rematchNumber = (state.rematches or 0) + 1,
        edition = GameVersion.get(), storage = mod.storage,
      })
      local rematchTeam, generation = recruitment.expand(
        game.data, team, d.trainerClass,
        key, progress, boost, mod.options:get("team_growth") ~= false, {
          game = game,
          selections = state.recruitFamilies,
          recentHistory = state.recruitHistory,
          originalStages = state.originalStages,
          originalBranches = state.originalBranches,
          rematchNumber = (state.rematches or 0) + 1,
          -- A focused test may inject RNG. Production rebuilds the exact same
          -- roster from the durable save/run authority across visual options,
          -- reloads and retries.
          random = deps.rematchRandom,
          seed = rosterAuthority,
          deferCommit = true,
        })
      -- The rematch builder owns growth and recruits, but the shared 6.7
      -- contract owns the final lane boundary. A malformed, overfull or
      -- generation-illegal optional plan falls back to the trainer's exact
      -- registered team before preview, warning text or save writes occur.
      local teamContracts = mod.exports.difficultyTeamContracts67
      if teamContracts and type(teamContracts.validatePlan) == "function" then
        local legal = teamContracts.validatePlan(
          "expert_rematch", game, rematchTeam)
        if not legal then
          rematchTeam, generation = team, nil
        end
      end
      -- Freeze one pure level plan before showing a warning. The exact same
      -- targets are later applied to the battle. In adaptive mode numeric B
      -- is suppressed, while the progress value above still owns ranks,
      -- evolutions, recruits, AI and rewards. OFF/AUTO-on-Standard keeps the
      -- classic constructor path byte-for-byte (including appended recruits).
      local adaptive = mod.exports.adaptiveTrainerLevels
      local frozenTeam, frozenReport, plannedPreview
      if adaptive and type(adaptive.planRematch) == "function" then
        local plannedOk, plannedTeam, plannedReport = pcall(
          adaptive.planRematch,
          rematchTeam, game.save.party, {
            selection = adaptive.currentSelection(),
            difficultyName = mod.options:get("difficulty") or "standard",
            badges = difficulty.progressBadges(game),
            difficultyBonus = difficulty.progressionBonus(
              "trainer", difficulty.progressBadges(game),
              mod.options:get("difficulty") or "standard"),
            classicBoost = boost, originalCount = #team,
            pokemon = game.data and game.data.pokemon,
          })
        if plannedOk and type(plannedTeam) == "table"
            and plannedReport and (plannedReport.mode == "classic"
              or plannedReport.mode == "adaptive") then
          -- Both modes use the pure planner for the warning preview so the
          -- displayed gap includes the same fixed Difficulty floor as the
          -- eventual constructor. Only Adaptive freezes/applies slot targets;
          -- Classic still follows its byte-compatible battle path below.
          plannedPreview = plannedTeam
          if plannedReport.mode == "adaptive" then
            frozenTeam, frozenReport = plannedTeam, plannedReport
          end
        end
      end
      local previewTeam = plannedPreview or boostedTeam(rematchTeam, boost)

      local function battle()
        Runtime.emit("world.trainer_engaged", { npc = npc,
          trainerClass = d.trainerClass, partyIndex = partyIndex })
        local header = game.data:trainerHeader(self.map.def.label, d.index)
        local wonText = header and header.won and game.data.text[header.won]
        local b = BattleState.newTrainer(game, d.trainerClass, partyIndex)
        state.trainerName = b.trainer and b.trainer.name
          or state.trainerName or d.name
        state.lastTeamSize = #(b.enemyParty or {})
        b.rematch = true
        b.rematchTrainerKey = key
        b.rematchTrainerClass = d.trainerClass
        b.rematchRank = rank and rank.key
        if ascendant then ascendant.applyRematchRank(b, rank) end
        rematchAI.attach(b)
        b.rematchNumber = (state.rematches or 0) + 1
        b.rematchTrainingCycles = state.trainingCycles
        b.rematchOriginalEvolutions = applyOriginalProgression(
          game, b, team, rematchTeam)
        b.rematchRecruits = appendRecruits(game, b, rematchTeam)
        b.rematchLeadSynchronized = mod.exports.syncRematchLead(
          game, b, BattleState)
        b.rematchRecruitSpecies = {}
        for i = math.max(1, #rematchTeam - b.rematchRecruits + 1),
            #rematchTeam do
          if rematchTeam[i] and rematchTeam[i].recruited then
            b.rematchRecruitSpecies[#b.rematchRecruitSpecies + 1] =
              rematchTeam[i].species
          end
        end
        local adaptiveApplied = false
        if frozenTeam and frozenReport and frozenReport.mode == "adaptive"
            and adaptive and type(adaptive.applyBattleTargets) == "function" then
          adaptiveApplied = adaptive.applyBattleTargets(game, b, frozenTeam, {
            -- A cooperative Randomizer may change species while retaining
            -- slot structure. The frozen slot levels remain authoritative;
            -- level-incompatible rewrites still fail closed to classic.
            allowSpeciesRemap = true,
          })
          if adaptiveApplied then
            -- Preserve B as inspectable progression metadata without applying
            -- it numerically a second time.
            b.rematchLevelBoost = boost
            b.rematchNumericBoostSuppressed = boost
            b.ascendantAdaptiveTrainerLevels = frozenReport
          end
        end
        if not adaptiveApplied then strengthenBattle(game, b, boost) end
        b.rematchMasteryReport = rematchMastery.apply(game, b, {
          kind = "field", key = key, progress = progress,
          rematches = state.rematches, masteryWins = state.masteryWins,
          trainerClass = d.trainerClass,
        })
        state.lastTeamSize = #(b.enemyParty or {})
        b.endBattleText = wonText and TextBox.substitute(game, wonText) or nil
        b.onFinish = function(result)
          -- A completed battle sends this trainer back to training whether
          -- the player won or blacked out.  The next meeting gets the next
          -- strength tier only after that rest has elapsed.
          recruitment.commit(state, generation, result == "win")
          if result == "win" then
            state.rematches = math.max(0,
              math.floor(state.rematches or 0)) + 1
            if b.rematchAtLevelCap then
              state.masteryWins = math.max(0,
                math.floor(state.masteryWins or 0)) + 1
            end
            state.rematchProgressionVersion = 3
          end
          scheduleRest(key, deps)
          local rewards = {}
          local function addReward(text)
            if text then rewards[#rewards + 1] = text end
          end
          if result == "win" then
            addReward(fieldTech and fieldTech.afterRematch(game, b))
            addReward(mod.exports.explorationDevice
              and mod.exports.explorationDevice.afterRematch(game, b))
            addReward(rematchRewards.afterWin(game, b, state, deps))
            addReward(johtoResearch.afterRematch(game, b))
            addReward(shinySystem and shinySystem.afterRematch(game, b))
          end
          local reward = #rewards > 0 and table.concat(rewards, "\f") or nil
          self:afterBattle(result, b)
          if reward then
            game.stack:push(TextBox.new(game, reward, unfreeze))
          else
            unfreeze()
          end
        end
        self:pushBattle(b)
      end

      -- when the rematch team averages more than 10 levels above the
      -- player's party, the class warns in its own voice and asks again
      local gap = frozenTeam and adaptive
        and adaptive.previewGap(previewTeam, game.save.party,
          game.data and game.data.pokemon)
        or levelGap(game.save.party, previewTeam)
      if gap and gap > 10 then
        game.stack:push(TextBox.new(game, localizedWarning(d.trainerClass), nil, {
          choice = function(yes)
            if yes then battle() else decline() end
          end,
        }))
      else
        battle()
      end
    end

    local rankState = stateFor(trainerKey(self, npc), true)
    settleTraining(rankState, deps)
    local opening = localizedLine(d.trainerClass)
    if ascendant then
      local shownRank = ascendant.rematchRank(
        rankState.rematches + rankState.trainingCycles)
      if shownRank and shownRank.threshold > 0 then
        opening = ascendant.rankLine(
          rankState.rematches + rankState.trainingCycles) .. "\f" .. opening
      end
    end
    game.stack:push(TextBox.new(game, opening, nil, {
      choice = function(yes)
        if yes then accept() else decline() end
      end,
    }))
  end

  -- deps injectable so the headless test can drive the wraps without the
  -- engine; in-game every one resolves to the real module
  local activeGame
  local function install(game, deps)
    activeGame = game
    restProfiles.bindGame(game)
    assert(mod.exports.generationRules.install(game))
    deps = deps or {}
    local Overworld = deps.overworld or require("src.world.OverworldController")
    local BattleState = deps.battleState or require("src.battle.BattleState")
    local TextBox = deps.textBox or require("src.render.TextBox")
    local Runtime = deps.runtime or require("src.mods.Runtime")
    local mapScripts = deps.mapScripts or require("data.scripts.init")
    assert(mod.exports.generationBattleGate67.install(game, {
      battleState = BattleState, textBox = TextBox,
      runtime = Runtime, partyMenu = deps.partyMenu,
      music = deps.music,
    }))

    -- Engine 0.1.96/0.1.98 omit only Yellow's Mt. Moon fossil Super Nerd
    -- trainer header. Repair the exact imported data shape before any talk,
    -- battle or rematch wrapper can observe it; R/B are a cold no-op.
    yellowMtMoonFossilDialogue.install(game)

    -- Run only after every enabled mod has merged its audio registry. Existing
    -- Gen-II cries therefore always win; Ascendant supplies its bundled
    -- species-authentic legacy files only for missing Johto entries, and
    -- Mega/Ascendant forms naturally retain their species cry.
    if johtoAudio then johtoAudio.install(game) end
    if gorochu then gorochu.install(game, deps) end
    if megaEvolution then megaEvolution.install(game, deps) end
    if gorochuVisuals then gorochuVisuals.install(game) end
    if trueColorWorldCompat then trueColorWorldCompat.install() end
    if mod.exports.rendererWallDecalsCompat then
      mod.exports.rendererWallDecalsCompat.install(game)
    end
    if contentEnabled and mod.exports.hoennBattleSurrounds67 then
      assert(mod.exports.hoennBattleSurrounds67.install(game))
    end
    if kantoCompletion then kantoCompletion.install(game, deps) end
    if mod.exports.explorationDevice then
      mod.exports.explorationDevice.install(game, deps)
    end
    if mod.exports.hiddenAccessReveal then
      local accessOk, accessWhy = mod.exports.hiddenAccessReveal.install(game)
      assert(accessOk, "Access V3.1 install failed: " .. tostring(accessWhy))
    end
    if fieldTech then fieldTech.install(game, deps) end
    if contentEnabled and mod.exports.hiddenEvolutionCampaign then
      mod.exports.hiddenEvolutionCampaign.install(game, deps)
    end
    if contentEnabled and mod.exports.hoennLegendPortals67 then
      assert(mod.exports.hoennLegendPortals67.install(game, {
        battleState = BattleState,
      }))
    end
    if contentEnabled and mod.exports.hoennBirthIsland67 then
      assert(mod.exports.hoennBirthIsland67.install(game, {
        battleState = BattleState, mapScripts = mapScripts,
      }))
    end
    if contentEnabled and mod.exports.hoennJirachiFinale67 then
      assert(mod.exports.hoennJirachiFinale67.install(game, {
        battleState = BattleState, mapScripts = mapScripts,
      }))
    end
    if contentEnabled and mod.exports.hoennEndgameAccess67 then
      assert(mod.exports.hoennEndgameAccess67.install(game, {
        mapScripts = mapScripts,
      }))
    end
    if frontierExchange then frontierExchange.install(game, deps) end
    if daycare then daycare.install(game, deps) end
    if shinySystem then shinySystem.install(game, deps) end
    if runRules then runRules.install(game) end
    if mod.exports.extendedSpeciesRuntime then
      mod.exports.extendedSpeciesRuntime.install(game)
    end
    if mod.exports.lateSpecies67 then
      mod.exports.lateSpecies67.install(game)
    end
    if mod.exports.alolaGiftForms66 then
      mod.exports.alolaGiftForms66.install(game)
    end
    if crystalAnimation then crystalAnimation.install(game, deps) end
    if mod.exports.nonCrystalHdSprites67 then
      mod.exports.nonCrystalHdSprites67.install(game, {
        battleState=BattleState,
      })
    end
    if crystalV15 then crystalV15.install(game, deps) end
    if ascendant then ascendant.install(game, deps) end
    if mod.exports.rocketRecoveryRaids67 then
      mod.exports.rocketRecoveryRaids67.install(game)
    end
    if mod.exports.rocketRecoveryRaids67Runtime then
      mod.exports.rocketRecoveryRaids67Runtime.install(game)
    end
    if mod.exports.rocketRecoveryRewards67 then
      mod.exports.rocketRecoveryRewards67.install(game)
    end
    if eventArchive then eventArchive.install(game, deps) end
    if mod.exports.giftCodes then mod.exports.giftCodes.install(game) end
    if johtoResearch then johtoResearch.install(game, deps) end
    if legacyHoenn then legacyHoenn.install(game) end
    if mod.exports.hevoPackages then mod.exports.hevoPackages.install(game) end
    if hevoSpecies then hevoSpecies.install(game) end
    if mod.exports.hoennSpecies67 then
      mod.exports.hoennSpecies67.install(game)
    end
    if mod.exports.hoennDexCompletion67 then
      mod.exports.hoennDexCompletion67.sync(game)
    end
    if mod.exports.hoennResearchSanctums67 then
      assert(mod.exports.hoennResearchSanctums67.install(game, {
        battleState = BattleState, mapScripts = mapScripts,
      }))
    end
    if mod.exports.hoennMoltresVolcano67 then
      assert(mod.exports.hoennMoltresVolcano67.install(game, {
        battleState = BattleState, mapScripts = mapScripts,
      }))
    end
    if mod.exports.fairyAffection67 then
      assert(mod.exports.fairyAffection67.install(game))
    end
    if legacyStarters then legacyStarters.install(game, {
      mapScripts = mapScripts,
    }) end
    if mod.exports.hoennFieldAccess then
      assert(mod.exports.hoennFieldAccess.install(game, {
        mapScripts = mapScripts,
        placement = mod.exports.runtimeNpcPlacement,
        textBox = TextBox,
      }), "Hoenn field access install failed")
    end
    if mod.exports.hoennRoamers67 then
      mod.exports.hoennRoamers67.install(game, { battleState = BattleState })
    end
    if signalsState then signalsState.install(game) end
    if johtoSignals and johtoSignals.game ~= game then
      -- CONTINUE adopts its selected save only after game.ready. Deferring
      -- the optional direct-start question avoids presenting a stale prompt
      -- from the provisional title-screen save.
      johtoSignals.install(game, false)
    end
    if mythicSignals then mythicSignals.install(game, {
      battleState = BattleState,
      stats = deps.stats,
    }) end
    if driftglassPrisms then driftglassPrisms.install(game) end
    if mod.exports.starterSpecies67 then
      mod.exports.starterSpecies67.install(game)
    end
    if mod.exports.starterHabitats and mod.exports.hiddenAccessReveal then
      assert(mod.exports.starterHabitats.install(game))
    end
    if signalsHub then signalsHub.install(game) end
    if wildsCompat then wildsCompat.install(game, {
      random = deps.wildsRandom,
    }) end
    if signalsWilds then signalsWilds.install(game, {
      random = deps.wildsRandom,
    }) end
    if worldEvents then worldEvents.install(game, deps) end
    if johtoMasters then johtoMasters.install(game, deps) end
    if dexProgress then dexProgress.install(game, deps) end
    if ascendantTyphlosion then ascendantTyphlosion.install(game, deps) end
    if starterRelicQuests then starterRelicQuests.install(game, deps) end
    if researchAtlas then researchAtlas.install(game, deps) end
    if grandTour then grandTour.install(game, deps) end
    if questTracker then questTracker.install(game, deps) end
    if onboarding then onboarding.install(game, deps) end
    if legacyHall then legacyHall.install(game, deps) end
    if legacyHall and legacyHall.worldRank then
      legacyHall.worldRank.install(game)
      mod.exports.hoennTournamentEncounters67.install(game)
      legacyHall.worldRankPolicy.install({
        battleState = BattleState,
        bagMenu = require("src.ui.BagMenu"),
        itemEffects = require("src.inventory.ItemEffects"),
      })
      legacyHall.worldRankRewards.install(game)
      legacyHall.worldRankRuntime.install(game)
    end
    if trainerCardHDStandard then trainerCardHDStandard.install(game) end
    if legacyHall and legacyHall.trainerCards then
      legacyHall.trainerCards.install(game)
    end
    if legacyHall and legacyHall.trainerCardHD then
      legacyHall.trainerCardHD.install(game)
    end
    if followerCompat then followerCompat.install(game) end
    if yellowPartner then yellowPartner.install(game, deps) end
    if followerConfig then followerConfig.install(game, singleFollower) end
    if singleFollower then singleFollower.install(game) end

    -- Keep the installed wrappers stable, but replace their dispatch target
    -- on every install. Dev hot reload keeps engine module tables alive while
    -- recreating this entry chunk; a wrapper that closes over the first game,
    -- dependency set, or sibling controller would otherwise stay stale.
    local talkRuntime = {}
    function talkRuntime.handle(self, npc)
      local d = npc.def
      if dojoPrizes
          and dojoPrizes.handleTalk(self, npc, game) then return true end
      if yellowPartner
          and yellowPartner.handleTalk(self, npc, game) then return true end
      if gorochu and gorochu.handleTalk(self, npc, game) then return true end
      if daycare and daycare.handleTalk(self, npc, game) then return true end
      if starterRelicQuests
          and starterRelicQuests.handleTalk(self, npc, game) then return true end
      -- Hall-of-Fame gym leaders are scripted in the base game, so the
      -- post-game controller gets first refusal before the generic/scripted
      -- split below.
      if johtoResearch
          and johtoResearch.handleTalk(self, npc, game) then return true end
      if ascendant and ascendant.handleTalk(self, npc, game) then return true end
      if postgame and postgame.handleTalk(self, npc, game) then return true end
      -- only the generic-trainer branch: scripted encounters (gym leaders,
      -- rivals, story fights) keep their own flow, defeated or not
      local scripted = (mapScripts and mapScripts.talkScript(self.map.id, d.text))
        or isRoute22FirstRival(self, npc, mapScripts)
      if not scripted and d.trainerClass and self:trainerDefeated(npc) then
        local key = trainerKey(self, npc)
        -- A defeated trainer without a mod record can occur when an older
        -- save is adopted after boot or when another mod sets the victory
        -- flag directly. Seed the missing record here as a final safety net
        -- so such trainers never jump straight to an immediate rematch.
        if not stateFor(key, false) then scheduleRest(key, deps) end
        local trainerState = stateFor(key, true)
        trainerState.mapId = self.map and self.map.id or trainerState.mapId
        trainerState.trainerClass = d.trainerClass
          or trainerState.trainerClass
        trainerState.trainerName = trainerState.trainerName or d.name
        if rematchRewards.hasPending(game, trainerState) then
          npc.frozen = true
          npc:facePlayer(self.player)
          local text = rematchRewards.deliverPending(game, trainerState)
          game.stack:push(TextBox.new(game, text, function()
            npc.frozen = false
          end))
          return true
        end
        local left = remainingSteps(key)
        if left > 0 then
          npc.frozen = true
          npc:facePlayer(self.player)
          local header = game.data:trainerHeader(self.map.def.label, d.index)
          local after = header and header.after and game.data.text[header.after]
          local status = localizedRestLine(left)
          if after then status = status .. "\f" .. after end
          game.stack:push(TextBox.new(game, status, function()
            npc.frozen = false
          end))
          return true
        end
        return true, offerRematch(self, npc, game, deps)
      end
      return false
    end
    function talkRuntime.afterTrainer(self, npc, defeatedBefore)
      if not isRoute22FirstRival(self, npc, mapScripts)
          and not defeatedBefore and self:trainerDefeated(npc) then
        scheduleRest(trainerKey(self, npc), deps)
      end
    end
    Overworld._kantoAscendantTalkRuntime = talkRuntime

    -- one wrap per boot; hot reload refreshes the runtime slot above and then
    -- leaves the stable engine-facing functions untouched
    if Overworld._rematchTalkWrapped then return end
    Overworld._rematchTalkWrapped = true

    local vanillaTalkTo = Overworld.talkTo
    Overworld.talkTo = function(self, npc)
      local current = Overworld._kantoAscendantTalkRuntime
      if current and type(current.handle) == "function" then
        local handled, result = current.handle(self, npc)
        if handled then return result end
      end
      return vanillaTalkTo(self, npc)
    end

    -- The first rematch must not be available one dialogue box after the
    -- original victory.  Wrap the normal trainer flow and start this
    -- trainer's first rest only after the base game has recorded the win.
    local vanillaEngageTrainer = Overworld.engageTrainer
    if vanillaEngageTrainer then
      Overworld.engageTrainer = function(self, npc, onDone,
          endBattleText, skipBattleText)
        local defeatedBefore = self:trainerDefeated(npc)
        local function done(...)
          local current = Overworld._kantoAscendantTalkRuntime
          if current and type(current.afterTrainer) == "function" then
            current.afterTrainer(self, npc, defeatedBefore)
          end
          if onDone then return onDone(...) end
        end
        return vanillaEngageTrainer(self, npc, done,
          endBattleText, skipBattleText)
      end
    end

    -- A save that already contains beaten trainers cannot tell us when
    -- those old victories happened.  Seed one rest period on first install
    -- so enabling the mod mid-playthrough follows the same rule.
    seedDefeatedTrainers(game.save, deps)

    -- The bonus system leaves the engine's trainer prize and Pay Day
    -- paths untouched.  The additional item-or-money roll happens only in
    -- rematchRewards.afterWin and therefore cannot replace ordinary winnings.
  end
  -- Move owners have all registered by this point. The Day-Care retained the
  -- shared table by reference, so this late reconciliation is save-neutral.
  mod.exports.hoennSpecies67.reconcileEggMoves()
  mod.exports.install = install

  mod.events:on("world.stepped", function()
    local realClock = playerStepClock() + 1
    local gain = 1 + (worldEvents and worldEvents.trainingStepBonus
      and worldEvents.trainingStepBonus() or 0)
    local trainerClock = stepClock() + gain
    mod.save:set("step_clock", realClock)
    mod.save:set("trainer_step_clock", trainerClock)
    settleAllTraining()
    if ascendant then ascendant.refreshRankMarkers() end
    if worldEvents then worldEvents.onStep(nil, realClock) end
  end)

  -- game.ready runs before CONTINUE adopts the selected slot. The profile
  -- module's priority-5000 save.loaded handler resolves the selected slot's
  -- exact pair before this missing-timer seeding handler runs.
  mod.events:on("save.loaded", function(ev)
    -- Reassert late-bound Johto audio after the selected Red/Blue/Yellow
    -- slot becomes live. This is idempotent and also clears any negative
    -- Sound cache entry created by an earlier follower/UI lookup.
    if johtoAudio and activeGame then johtoAudio.install(activeGame) end
    if gorochu and activeGame then gorochu.installAudio(activeGame) end
    if mod.save:get("trainer_step_clock") == nil then
      mod.save:set("trainer_step_clock", playerStepClock())
    end
    seedDefeatedTrainers(ev.save)
    migrateRestTimers()
  end)

  mod.events:on("game.ready", function(ev)
    if idMigration.persistOptions(ev.game, ascendantOptionSchema) then
      mod.log:info("migrated legacy trainer_rematch options")
    end
    install(ev.game)
  end)
end
