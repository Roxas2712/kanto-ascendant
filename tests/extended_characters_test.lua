-- Phase-3 coverage for identity, visual resolution and role-safe rivals.
-- Run from Gen1 Recomp:
--   POKEPORT_DATA_DIR=tests/fixture_data \
--   TRAINER_REMATCH_MOD_DIR=../kanto-ascendant \
--   luajit ../kanto-ascendant/tests/extended_characters_test.lua

package.path = "./?.lua;./?/init.lua;" .. package.path

local T = require("tests.modkit")
local Data = T.fixtures.load()
local modPath = os.getenv("TRAINER_REMATCH_MOD_DIR") or "mods/kanto_ascendant"
local sdkOpts = { data = Data }
if modPath:sub(1, 1) == "/" then sdkOpts.root = "/" end
local originalLoveNewImage = love.graphics.newImage
local assetSink = assert(loadfile(modPath
  .. "/tests/headless_modkit_asset_sink.lua"))()(T, modPath, {
  bridgeLove = true,
  derivedPrefix = "save/mod-derived/kanto_ascendant/",
})
local loaded, run = pcall(T.sdk.loadMod, modPath, sdkOpts)
if not loaded then
  assetSink.cleanup()
  error(run, 0)
end
T.eq(#run.errors, 0, "Kanto Ascendant loads with extended characters")
local runtimeModPath = assert(run.mod and run.mod.path,
  "SDK exposes the loader-owned runtime mod path")

local characters = assert(run.loader.exports.kanto_ascendant.extendedCharacters)
local titleIntro = assert(run.loader.exports.kanto_ascendant.titleIntro)
local frlgTrainerPack = assert(run.loader.exports.kanto_ascendant.frlgTrainerPack)
local trainerVoxelPortraits = assert(
  run.loader.exports.kanto_ascendant.trainerVoxelPortraits)
local crystalWalkAssets = assert(
  run.loader.exports.kanto_ascendant.crystalWalkAssets)
local freshStyleDefault, freshTrainerDefault, freshTrainerChoices
for _, row in ipairs(run.loader.optionSchemas.kanto_ascendant or {}) do
  if row.key == "pokemon_sprite_style" then freshStyleDefault = row.default end
  if row.key == "trainer_portrait_style" then
    freshTrainerDefault = row.default
    freshTrainerChoices = row.choices
  end
end
T.eq(freshStyleDefault, "crystal",
  "fresh 6.5 games enable Crystal scenes and animation from the title onward")
T.eq(freshTrainerDefault, "crystal_hd",
  "fresh 6.5 games enable approved Crystal HD trainer portraits")
local trainerChoiceValues = {}
for _, choice in ipairs(freshTrainerChoices or {}) do
  trainerChoiceValues[#trainerChoiceValues + 1] = choice[2]
end
T.eq(table.concat(trainerChoiceValues, ","), "crystal_hd,original",
  "trainer portrait menu exposes exactly HD and edition-original")
T.eq(table.concat(titleIntro.order, ","), "GREEN,BLUE,RED",
  "title trainer order advertises the mod with Green first")
T.eq(characters.characterStyle(), "crystal",
  "CRYSTAL CHARS is the default character style")
run.loader.modOptions.kanto_ascendant = { character_sprite_style = "ascendant" }
T.eq(characters.getState().enabled, false,
  "an absent legacy record keeps extended selection off")
T.eq(characters.getPlayerCharacter(), "RED",
  "legacy player identity resolves to Red")
T.eq(characters.getRivalCharacter(), "BLUE",
  "legacy rival identity resolves to Blue")
T.eq(characters.getThirdCharacter(), "GREEN",
  "legacy third identity resolves to Green")
T.eq(characters.getPlayerGender(), "MALE",
  "trainer gender comes from character identity, not Pokémon data")
local legacyRedBack = run.loader.hooks:call("player.sprite",
  function(path) return path end, "vanilla-red-back.png",
  { side = "back", kind = "battle" })
T.check(legacyRedBack:match(
    "/assets/characters/crystal_chars/red_back%.png$") ~= nil,
  "legacy Red/Blue saves resolve the approved Red battle back without "
    .. "manufacturing character-selection state")
T.eq(characters.getState().enabled, false,
  "legacy Red presentation does not mutate the protected selector state")
T.eq(characters.getCharacterGender("GREEN"), "FEMALE",
  "Green has centralized female trainer gender")
local redBack = characters.resolveVisual("RED", "battleBack", "back", 1)
T.eq(redBack.path, "assets/characters/crystal_chars/red_back.png",
  "legacy field style cannot downgrade Red's FRLG-scale battle back")
T.eq(redBack.direction, "back", "resolver retains directional state")
T.eq(characters.getCharacterSprite("RED", "bike").status, "final",
  "Red keeps the complete baseline visual family")
T.eq(characters.definition("BLUE").palette, "BLUE",
  "character palette identity is represented without a sprite migration")
T.eq(table.concat(characters.selectionOrder, ","), "GREEN,BLUE,RED",
  "default live selector advertises Green first")
for _, id in ipairs(characters.selectionOrder) do
  T.eq(characters.selectionLabel(id), id,
    id .. " is identified canonically before the editable naming screen")
end
T.eq(characters.displayName("GREEN"), "GREEN",
  "English game data keeps the English character label")

T.eq(characters.characterStyle(), "ascendant",
  "the Ascendant option remains available for field sprites")
for _, id in ipairs(characters.selectionOrder) do
  T.check(characters.selectionVisual(id).path:find(
      "/crystal_chars/" .. id:lower() .. "_voxel_front_hd.png", 1, true) ~= nil,
    id .. " Oak selector keeps its native HD model with old settings")
end
run.loader.modOptions.kanto_ascendant.character_sprite_style = "crystal"
T.eq(characters.characterStyle(), "crystal",
  "CRYSTAL CHARS can be selected explicitly")
local frlgCount = 0
for _ in pairs(frlgTrainerPack.fronts) do frlgCount = frlgCount + 1 end
T.eq(frlgCount, 42, "Crystal modelpack covers every used non-rival Kanto class")
T.eq(trainerVoxelPortraits.count, 38,
  "dedicated Ascendant standees cover every non-Elite Kanto trainer class")
local trainerGame = {
  data = { trainers = {
    OPP_BROCK = { id = "OPP_BROCK", pic = "baseline/brock.png" },
    OPP_RIVAL1 = { id = "OPP_RIVAL1", pic = "identity/rival.png" },
  } },
  mods = { modOptions = run.loader.modOptions },
}
T.eq(frlgTrainerPack.refresh(trainerGame), true,
  "trainer presentation refresh installs the selected opponent fronts")
T.check(trainerGame.data.trainers.OPP_BROCK.pic:find(
    "/frlg_trainers/leader_brock_voxel_front_v2.png", 1, true) ~= nil,
  "Brock defaults to his approved Crystal HD 64px 2D sibling")
T.eq(trainerGame.data.trainers.OPP_BROCK.trueColor, true,
  "FRLG opponent fronts bypass four-shade recoloring")
local rivalBeforeCharacterRefresh = trainerGame.data.trainers.OPP_RIVAL1.pic
T.check(not tostring(rivalBeforeCharacterRefresh):find("/frlg_trainers/", 1, true),
  "generic FRLG class pack never replaces the identity-aware rival")
for _, id in ipairs({ "RED", "GREEN", "BLUE" }) do
  local prefix = "SPRITE_KA_CRYSTAL_" .. id .. "_"
  T.eq(characters.getCharacterSprite(id, "overworld").sprite, prefix .. "WALK",
    id .. " owns a Crystal walking sheet")
  T.eq(characters.getCharacterSprite(id, "bike").sprite, prefix .. "BIKE",
    id .. " owns a Crystal bicycle sheet")
  T.eq(characters.getCharacterSprite(id, "fishing").sprite, prefix .. "FISH",
    id .. " owns a Crystal fishing sheet")
  local front = characters.getCharacterSprite(id, "front").path
  local expectedFront = id == "RED"
      and "assets/characters/crystal_chars/red_voxel_front.png"
    or "assets/characters/crystal_chars/" .. id:lower() .. "_front.png"
  T.eq(front, expectedFront,
    id .. " defaults to its bundled Crystal front")
  T.check(characters.selectionVisual(id).path:find(
      "/crystal_chars/" .. id:lower() .. "_voxel_front_hd.png", 1, true) ~= nil,
    id .. " selector uses the native 128px standing model")
  T.check(characters.getCharacterSprite(id, "battleBack").path:find(
      "/crystal_chars/" .. id:lower() .. "_back.png", 1, true) ~= nil,
    id .. " owns a Crystal battle back")
  local walkDef = assert(run.data.sprites[prefix .. "WALK"])
  local bikeDef = assert(run.data.sprites[prefix .. "BIKE"])
  local fishDef = assert(run.data.sprites[prefix .. "FISH"])
  T.eq(walkDef.frameWidth, nil, id .. " walking uses native 16x16 geometry")
  T.eq(walkDef.frameHeight, nil, id .. " walking needs no renderer extension")
  T.check(walkDef.image:find("/crystal_chars/" .. id:lower()
      .. "_walk.png", 1, true) ~= nil,
    id .. " walking registration does not use the 2026-08-17 primary")
  T.check(crystalWalkAssets.receipts[id:lower()].lane ~= "fallback-v1",
    id .. " unexpectedly selected the packaged v1 fallback")
  T.eq(bikeDef.frameWidth, nil, id .. " bicycle uses native 16x16 geometry")
  T.eq(fishDef.frameHeight, nil, id .. " fishing uses native 16x16 geometry")
  T.eq(walkDef.trueColor, true, id .. " custom colors bypass map recoloring")
end
run.loader.modOptions.kanto_ascendant = {
  character_sprite_style = "ascendant", trainer_portrait_style = "frlg",
}
for _, identity in ipairs({ "BLUE", "GREEN" }) do
  characters.select(identity)
  T.eq(characters.getCharacterSprite(identity, "bike").sprite,
    "SPRITE_KA_CRYSTAL_" .. identity .. "_BIKE",
    identity .. " keeps its own identity when mounting the bicycle in GAME/KASC")
end
T.eq(frlgTrainerPack.refresh(trainerGame), true,
  "legacy FRLG option can be migrated independently of field style")
T.eq(trainerGame.data.trainers.OPP_BROCK.pic, "baseline/brock.png",
  "legacy FRLG option migrates to Brock's edition-original portrait")
run.loader.modOptions.kanto_ascendant.trainer_portrait_style = "original"
T.eq(frlgTrainerPack.refresh(trainerGame), true,
  "game-original trainer portraits can be restored")
T.eq(trainerGame.data.trainers.OPP_BROCK.pic, "baseline/brock.png",
  "ORIGINAL restores the exact pre-pack Brock portrait")

-- ORIGINAL and CRYSTAL HD are complete, disjoint 2D identity families for
-- all three selectable trainers. Staged 3D battles retain the independently
-- authored standing front regardless of the 2D portrait choice.
T.eq(characters.trainerPortraitStyle(), "original",
  "identity resolver reads the same ORIGINAL trainer option")
local identityFrontStates = {
  "front", "trainerCard", "hallOfFame", "credits", "intro", "special",
  "rivalPortrait",
}
local originalFronts = {
  RED = "save/mod-derived/kanto_ascendant/characters/red_front.png",
  BLUE = "save/mod-derived/kanto_ascendant/characters/blue_rival.png",
  GREEN = "assets/characters/green_front.png",
}
local originalBacks = {
  RED = "save/mod-derived/kanto_ascendant/characters/red_back.png",
  BLUE = "assets/characters/blue_back.png",
  GREEN = "assets/characters/green_back.png",
}
local crystalFronts = {
  RED = "assets/characters/crystal_chars/red_voxel_front.png",
  BLUE = "assets/characters/crystal_chars/blue_front.png",
  GREEN = "assets/characters/crystal_chars/green_front.png",
}
local crystalBacks, crystalSelectors, crystalVoxels = {}, {}, {}
for _, id in ipairs({ "RED", "BLUE", "GREEN" }) do
  crystalBacks[id] = "assets/characters/crystal_chars/"
    .. id:lower() .. "_back.png"
  crystalSelectors[id] = "assets/characters/crystal_chars/"
    .. id:lower() .. "_voxel_front_hd.png"
  crystalVoxels[id] = "assets/characters/crystal_chars/"
    .. id:lower() .. "_voxel_front.png"
  for _, state in ipairs(identityFrontStates) do
    local visual = assert(characters.getCharacterSprite(id, state))
    T.eq(visual.path, originalFronts[id],
      "ORIGINAL " .. id .. " " .. state .. " uses its base front")
    T.eq(visual.fallbackCharacter, nil,
      "ORIGINAL " .. id .. " " .. state .. " keeps its identity")
  end
  T.eq(characters.getCharacterSprite(id, "selectorHd").path,
    originalFronts[id], "ORIGINAL " .. id .. " selector state is base art")
  local selector = characters.selectionVisual(id)
  T.eq(selector.path, originalFronts[id],
    "ORIGINAL Oak selector uses " .. id .. " base art")
  T.eq(selector.bounds, nil,
    "ORIGINAL " .. id .. " selector uses the complete source canvas")
  T.eq(characters.getCharacterSprite(id, "battleBack").path,
    originalBacks[id], "ORIGINAL " .. id .. " uses its base 2D back")
  T.eq(characters.getCharacterSprite(id, "voxelFront").path,
    crystalVoxels[id], "ORIGINAL never replaces " .. id .. " 3D standee")
end

for _, id in ipairs({ "RED", "BLUE", "GREEN" }) do
  characters.select(id)
  T.eq(characters.getPlayerSprite("intro").path, originalFronts[id],
    id .. " player intro follows ORIGINAL")
  T.eq(characters.getPlayerSprite("battleBack").path, originalBacks[id],
    id .. " normal 2D player back follows ORIGINAL")
  local rival = characters.getRivalCharacter()
  T.eq(characters.getRivalSprite("rivalPortrait").path,
    originalFronts[rival], rival .. " rival portrait follows ORIGINAL")
end

run.loader.modOptions.kanto_ascendant.trainer_portrait_style = "crystal_hd"
T.eq(characters.trainerPortraitStyle(), "crystal_hd",
  "Crystal HD remains the normalized default identity family")
for _, id in ipairs({ "RED", "BLUE", "GREEN" }) do
  T.eq(characters.selectionVisual(id).path, crystalSelectors[id],
    "Crystal HD restores " .. id .. " selector master")
  T.eq(characters.getCharacterSprite(id, "selectorHd").path,
    crystalSelectors[id], "Crystal HD " .. id .. " selector state is HD")
  for _, state in ipairs(identityFrontStates) do
    T.eq(characters.getCharacterSprite(id, state).path, crystalFronts[id],
      "Crystal HD " .. id .. " " .. state .. " uses bundled front")
  end
  T.eq(characters.getCharacterSprite(id, "battleBack").path,
    crystalBacks[id], "Crystal HD " .. id .. " uses bundled 2D back")
  T.eq(characters.getCharacterSprite(id, "voxelFront").path,
    crystalVoxels[id], "Crystal HD keeps " .. id .. " staged-3D standee")
end

local liveFrontContexts = {
  { kind = "trainer_card", label = "Trainer Card" },
  { kind = "hall_of_fame", label = "Hall of Fame" },
  { kind = "credits", label = "credits" },
  { kind = "intro", label = "intro" },
}
-- Exact minimum-engine regression: these calls execute the mod-authored hook
-- inside Gen1 Recomp's 0.1.90 sandbox.  Derived-path selection must use the
-- engine Assets API without touching the sandbox-forbidden love.filesystem.
local engineAssets = require("src.render.Assets")
local identityAssetsExists = engineAssets.exists
engineAssets.exists = function(path)
  if type(path) == "string"
      and path:find("save/mod%-derived/kanto_ascendant/characters/", 1) then
    return true
  end
  return identityAssetsExists(path)
end
for _, family in ipairs({
  { option = "original", fronts = originalFronts, backs = originalBacks },
  { option = "crystal_hd", fronts = crystalFronts, backs = crystalBacks },
}) do
  run.loader.modOptions.kanto_ascendant.trainer_portrait_style = family.option
  for _, id in ipairs({ "RED", "BLUE", "GREEN" }) do
    characters.select(id)
    local battlePath = run.loader.hooks:call("player.sprite",
      function(path) return path end, "native-player-back.png",
      { side = "back", kind = "battle" })
    T.check(battlePath:sub(-#family.backs[id]) == family.backs[id],
      family.option .. " live 2D battle hook uses " .. id .. " back")
    for _, surface in ipairs(liveFrontContexts) do
      local frontPath = run.loader.hooks:call("player.sprite",
        function(path) return path end, "native-player-front.png",
        { side = "front", kind = surface.kind })
      T.check(frontPath:sub(-#family.fronts[id]) == family.fronts[id],
        family.option .. " live " .. surface.label .. " hook uses "
          .. id .. " front")
    end
    characters.refreshVisuals(trainerGame)
    local rival = characters.getRivalCharacter()
    local rivalPath = trainerGame.data.trainers.OPP_RIVAL1.pic
    T.check(rivalPath:sub(-#family.fronts[rival]) == family.fronts[rival],
      family.option .. " live rival hook uses " .. rival .. " front")
  end
end
engineAssets.exists = identityAssetsExists
run.loader.modOptions.kanto_ascendant.trainer_portrait_style = "crystal_hd"

local selected = characters.select("BLUE")
T.eq(selected.player_character, "BLUE", "Blue becomes player identity")
T.eq(selected.rival_character, "GREEN", "Green becomes rival identity")
T.eq(selected.third_character, "RED", "Red becomes third identity")
T.eq(characters.voxelStandingTrainerCharacter({
    oppClass = "OPP_RIVAL1", showEnemyTrainer = true,
  }, "enemy"), "GREEN",
  "DRAMALESS HD enemy standee is reserved for a real Kanto Rival class")
local johtoVoxelPaths = {}
for _, classId in ipairs({
  "KA_JOHTO_SILVER", "KA_JOHTO_KRIS", "KA_JOHTO_GOLD",
}) do
  T.eq(characters.voxelStandingTrainerCharacter({
      oppClass = classId, showEnemyTrainer = true,
    }, "enemy"), nil,
    classId .. " never aliases through the selected Kanto rival")
  local spec = characters.voxelStandingTrainerSpec({
    oppClass = classId, showEnemyTrainer = true,
  }, "enemy")
  T.check(spec and spec.id == classId:gsub("KA_", ""),
    classId .. " resolves its own isolated Voxel identity")
  T.check(spec.path:find("assets/johto_masters/battle/", 1, true) == 1
      and spec.path:find("_voxel_front_hd.png", 1, true),
    classId .. " resolves its authored 128px Voxel card")
  T.check(not johtoVoxelPaths[spec.path],
    classId .. " does not share another Master's Voxel card")
  johtoVoxelPaths[spec.path] = true
end
local indigoVoxelPaths = {}
for _, classId in ipairs({
  "OPP_LORELEI", "OPP_BRUNO", "OPP_AGATHA", "OPP_LANCE",
}) do
  T.eq(characters.voxelStandingTrainerCharacter({
      oppClass = classId, showEnemyTrainer = true,
    }, "enemy"), nil,
    classId .. " never aliases through the selected Kanto rival")
  local spec = characters.voxelStandingTrainerSpec({
    oppClass = classId, showEnemyTrainer = true,
  }, "enemy")
  T.check(spec and spec.id == "INDIGO_" .. classId:gsub("OPP_", ""),
    classId .. " resolves its own Indigo Voxel identity")
  T.check(spec.path:find("assets/characters/frlg_trainers/", 1, true) == 1
      and spec.path:find("_voxel_front_hd_v3.png", 1, true),
    classId .. " resolves its authored 128px Voxel standee")
  T.check(not indigoVoxelPaths[spec.path],
    classId .. " does not share another Elite Four standee")
  indigoVoxelPaths[spec.path] = true
end
T.eq(characters.voxelStandingTrainerCharacter({
    oppClass = "OPP_BROCK", showEnemyTrainer = true,
  }, "enemy"), nil,
  "ordinary trainer classes are never aliased to the selected Kanto rival")
local brockVoxel = characters.voxelStandingTrainerSpec({
  oppClass = "OPP_BROCK", showEnemyTrainer = true,
}, "enemy")
T.check(brockVoxel and brockVoxel.class == "OPP_BROCK"
    and brockVoxel.path:find("leader_brock_voxel_front_hd_v2.png", 1, true),
  "Brock resolves an isolated authored 128px FULL-Voxel standee")
local erikaVoxel = characters.voxelStandingTrainerSpec({
  oppClass = "OPP_ERIKA", showEnemyTrainer = true,
}, "enemy")
T.check(erikaVoxel and erikaVoxel.class == "OPP_ERIKA"
    and erikaVoxel.approvedVersion == "v2"
    and erikaVoxel.path:find("leader_erika_voxel_front_hd_v2.png", 1, true),
  "Erika resolves only her approved versioned V2 FULL standee")
local oakBetaVoxel = characters.voxelStandingTrainerSpec({
  oppClass = "KA_OAK_BETA", showEnemyTrainer = true,
}, "enemy")
T.check(oakBetaVoxel
    and oakBetaVoxel.path:find("professor_oak_voxel_front_hd_v1.png", 1, true),
  "Oak's isolated Legacy finale deliberately reuses Professor Oak identity")
T.eq(characters.voxelStandingTrainerCharacter({
    oppClass = "KA_JOHTO_SILVER", showPlayerBack = true,
  }, "player"), "BLUE",
  "player-side standing art remains identity-aware in every trainer battle")
T.eq(characters.voxelStandingTrainerCharacter({
    oppClass = "OPP_RIVAL1", showEnemyTrainer = false,
  }, "enemy"), nil,
  "a hidden rival trainer does not manufacture a Voxel card")
T.eq(characters.voxelStandingTrainerSpec({
    oppClass = "KA_JOHTO_KRIS", showEnemyTrainer = false,
  }, "enemy"), nil,
  "a hidden Johto Master does not manufacture a Voxel card")
T.eq(characters.voxelStandingTrainerSpec({
    oppClass = "KA_JOHTO_KRIS", showPlayerBack = true,
  }, "player"), nil,
  "Johto enemy cards never replace the selected player avatar")
T.eq(characters.getRivalGender(), "FEMALE", "rival gender follows matrix")
T.eq(characters.getPlayerSprite("overworld").sprite, "SPRITE_BLUE",
  "Blue player receives the real Blue overworld sheet")
T.eq(characters.getRivalSprite("overworld").sprite, "SPRITE_KA_GREEN",
  "Green uses her authored six-frame 16x16 walker")
T.eq(characters.getRivalSprite("rivalPortrait").path,
  "assets/characters/crystal_chars/green_front.png",
  "Green rival portrait resolves to the clean 64px Casey art")
T.eq(characters.getPlayerSprite("battleBack").path,
  "assets/characters/crystal_chars/blue_back.png",
  "Blue always uses his native 64px FRLG-scale battle back")
T.eq(characters.rivalBattleRole, "OPP_RIVAL",
  "starter counter-pick and battle progression remain role-based")
local blueBackPath = run.loader.hooks:call("player.sprite",
  function(path) return path end, "vanilla-back.png",
  { side = "back", kind = "battle" })
T.check(blueBackPath:match(
    "/assets/characters/crystal_chars/blue_back%.png$") ~= nil,
  "battle-back hook follows selected identity without field-style leakage")
local blueCardPath = run.loader.hooks:call("player.sprite",
  function(path) return path end, "vanilla-front.png",
  { side = "front", kind = "trainer_card" })
T.check(blueCardPath:sub(-#crystalFronts.BLUE) == crystalFronts.BLUE,
  "Trainer Card follows Blue's selected Crystal HD family")
for _, family in ipairs({
  { option = "original", fronts = originalFronts },
  { option = "crystal_hd", fronts = crystalFronts },
}) do
  run.loader.modOptions.kanto_ascendant.trainer_portrait_style = family.option
  for _, fieldStyle in ipairs({ "ascendant", "crystal" }) do
    run.loader.modOptions.kanto_ascendant.character_sprite_style = fieldStyle
    for _, identity in ipairs({ "RED", "BLUE", "GREEN" }) do
      characters.select(identity)
      T.eq(characters.getPlayerSprite("trainerCard").path,
        family.fronts[identity], identity .. " Trainer Card follows "
          .. family.option .. " independently of " .. fieldStyle .. " field art")
    end
  end
end

-- Missing imported derivatives are not a crash path. Preserve the selected
-- identity with its bundled Crystal sibling, then automatically return to the
-- edition-native result as soon as the transform output becomes available.
local previousFilesystem = love.filesystem
love.filesystem = { getInfo = function() return nil end }
run.loader.modOptions.kanto_ascendant.trainer_portrait_style = "original"
characters.select("RED")
local missingRedBack = run.loader.hooks:call("player.sprite",
  function(path) return path end, "native-red-back.png",
  { side = "back", kind = "battle" })
T.check(missingRedBack:match(
    "/assets/characters/crystal_chars/red_back%.png$") ~= nil,
  "missing derived Red back fails safe to bundled Red back")
local missingRedCard = run.loader.hooks:call("player.sprite",
  function(path) return path end, "native-red-front.png",
  { side = "front", kind = "trainer_card" })
T.check(missingRedCard:match(
    "/assets/characters/crystal_chars/red_voxel_front%.png$") ~= nil,
  "missing derived Red front fails safe to bundled Red front")
characters.select("BLUE")
local missingBlueCard = run.loader.hooks:call("player.sprite",
  function(path) return path end, "native-blue-front.png",
  { side = "front", kind = "trainer_card" })
T.check(missingBlueCard:match(
    "/assets/characters/crystal_chars/blue_front%.png$") ~= nil,
  "missing derived Blue front fails safe to bundled Blue front")
love.filesystem = { getInfo = function(path)
  if path:find("save/mod%-derived/kanto_ascendant/characters/", 1) then
    return { type = "file" }
  end
end }
characters.select("RED")
local restoredRedBack = run.loader.hooks:call("player.sprite",
  function(path) return path end, "native-red-back.png",
  { side = "back", kind = "battle" })
T.eq(restoredRedBack,
  "save/mod-derived/kanto_ascendant/characters/red_back.png",
  "available derived Red back is restored without reloading the mod")
love.filesystem = previousFilesystem
run.loader.modOptions.kanto_ascendant.trainer_portrait_style = "original"

-- KASC's complete 56px figures used to be drawn at the engine-native
-- (104,4), which lets opaque feet/right-edge pixels overwrite the patterned
-- border.  The renderer contract must fit every fixed identity wholly inside
-- the exact 48x48 white card interior and must be the draw actually used by
-- TrainerCard, not only an unused geometry helper.
local TrainerCard = require("src.ui.TrainerCard")
T.eq(TrainerCard._kantoAscendantProfileFitWrapped, true,
  "Trainer Card installs the KASC-only profile placement seam")
T.eq(TrainerCard._kantoAscendantLeaderFacesWrapped, true,
  "Trainer Card installs the KASC leader-face seam")
-- The SDK aliases an external checkout behind mods/<checkout-name>. Its
-- filesystem adapter understands that virtual path, while the headless Love
-- stub opens PNGs directly through io.open(). Bridge only that runtime prefix
-- back to the source checkout while exercising the image-backed card seam.
local nativeNewImage = love.graphics.newImage
love.graphics.newImage = function(path, ...)
  local prefix = runtimeModPath .. "/"
  if type(path) == "string" and path:sub(1, #prefix) == prefix then
    path = modPath .. path:sub(#runtimeModPath + 1)
  end
  return nativeNewImage(path, ...)
end
local facesLoaded, leaderFaces = pcall(characters.trainerCardLeaderFaces)
if not facesLoaded then error(leaderFaces, 0) end
leaderFaces = assert(leaderFaces)
local leaderWidth, leaderHeight = leaderFaces.img:getDimensions()
T.eq(leaderWidth, 16,
  "leader face atlas is exactly one Trainer Card cell wide")
T.eq(leaderHeight, 128,
  "leader face atlas contains exactly eight stacked cells")
T.eq(table.concat(leaderFaces.order, ","),
  "BROCK,MISTY,LT_SURGE,ERIKA,KOGA,SABRINA,BLAINE,GIOVANNI",
  "leader face atlas follows canonical Kanto badge order")
T.check(leaderFaces.path:match(
    "/assets/trainer_card/kasc_leader_faces%.png$") ~= nil,
  "leader faces resolve from the packaged KASC card atlas")
for index = 0, 7 do
  local quad = assert(leaderFaces.quads[index])
  local x, y, width, height
  if type(quad.getViewport) == "function" then
    x, y, width, height = quad:getViewport()
  else
    x, y, width, height = quad.x, quad.y, quad.w, quad.h
  end
  T.eq(x, 0, "leader face " .. index .. " starts in the only atlas column")
  T.eq(y, index * 16,
    "leader face " .. index .. " occupies its canonical atlas row")
  T.eq(width, 16, "leader face " .. index .. " preserves card width")
  T.eq(height, 16, "leader face " .. index .. " preserves card height")
end
local constructedCard = TrainerCard.new({
  data = Data,
  save = { player = { name = "GREEN" }, inventory = {} },
})
T.check(constructedCard.faces
    and constructedCard.faces.path == leaderFaces.path,
  "new Trainer Cards replace only unearned faces with KASC leaders")
T.check(constructedCard.badges and constructedCard.badges.img,
  "earned badge artwork remains the stock engine badge sheet")
T.check(constructedCard.badges.img ~= constructedCard.faces.img,
  "leader portraits never replace earned badge artwork")
love.graphics.newImage = nativeNewImage
local graphicsDraw = love.graphics.draw
for _, identity in ipairs({ "RED", "BLUE", "GREEN" }) do
  characters.select(identity)
  local fit = assert(characters.trainerCardProfileFit(identity, 56, 56))
  T.eq(fit.character, identity, identity .. " fit follows selected identity")
  T.eq(fit.profile.path, originalFronts[identity],
    identity .. " ORIGINAL fit follows its base profile")
  T.eq(fit.safe.x, 104, identity .. " safe box begins after card text")
  T.eq(fit.safe.y, 8, identity .. " safe box begins below top frame")
  T.eq(fit.safe.w, 48, identity .. " safe box stops before right frame")
  T.eq(fit.safe.h, 48, identity .. " safe box stops above bottom frame")
  T.check(math.abs(fit.scaleX - 6 / 7) < 0.000001
      and math.abs(fit.scaleY - 6 / 7) < 0.000001,
    identity .. " 56px source is proportionally reduced to 48px")
  T.check(fit.x >= fit.safe.x and fit.y >= fit.safe.y
      and fit.x + fit.width <= fit.safe.x + fit.safe.w
      and fit.y + fit.height <= fit.safe.y + fit.safe.h,
    identity .. " fitted pixel canvas is wholly inside the frame")

  local picture = {
    identity = identity,
    minFilter = "linear",
    magFilter = "linear",
  }
  function picture:getDimensions() return 56, 56 end
  function picture:getFilter() return self.minFilter, self.magFilter end
  function picture:setFilter(minFilter, magFilter)
    self.minFilter, self.magFilter = minFilter, magFilter
  end
  local pictureDraw
  local recorder = function(drawable, ...)
    if drawable == picture then
      pictureDraw = { ... }
      T.eq(drawable.minFilter, "nearest",
        identity .. " profile uses crisp pixel filtering while scaled")
      T.eq(drawable.magFilter, "nearest",
        identity .. " profile magnification filter remains pixel-exact")
    end
  end
  love.graphics.draw = recorder
  TrainerCard.draw({
    pic = picture,
    game = {
      data = Data,
      save = {
        player = { name = identity }, inventory = {}, money = 0, playTime = 0,
      },
    },
    frameBox = function() end,
  })
  T.eq(love.graphics.draw, recorder,
    identity .. " card draw restores the engine graphics function")
  T.eq(picture.minFilter, "linear",
    identity .. " card draw restores the profile minimum filter")
  T.eq(picture.magFilter, "linear",
    identity .. " card draw restores the profile magnification filter")
  T.check(pictureDraw ~= nil, identity .. " profile is drawn exactly once")
  T.check(pictureDraw and math.abs(pictureDraw[1] - 104) < 0.000001
      and math.abs(pictureDraw[2] - 8) < 0.000001,
    identity .. " profile draw is anchored in the white interior")
  T.check(pictureDraw and pictureDraw[3] == 0
      and math.abs(pictureDraw[4] - 6 / 7) < 0.000001
      and math.abs(pictureDraw[5] - 6 / 7) < 0.000001,
    identity .. " live profile draw preserves aspect ratio")
  love.graphics.draw = graphicsDraw
end

-- A renderer failure during the fitted draw must not leak nearest filtering
-- into later screens or leave the global draw seam replaced.
local brokenPicture = { minFilter = "linear", magFilter = "linear" }
function brokenPicture:getDimensions() return 56, 56 end
function brokenPicture:getFilter() return self.minFilter, self.magFilter end
function brokenPicture:setFilter(minFilter, magFilter)
  self.minFilter, self.magFilter = minFilter, magFilter
end
local failingDraw = function(drawable)
  if drawable == brokenPicture then error("trainer-card-profile-failure") end
end
love.graphics.draw = failingDraw
local cardDrawn, cardProblem = pcall(TrainerCard.draw, {
  pic = brokenPicture,
  game = {
    data = Data,
    save = {
      player = { name = "GREEN" }, inventory = {}, money = 0, playTime = 0,
    },
  },
  frameBox = function() end,
})
T.eq(cardDrawn, false, "profile renderer failures still propagate")
T.check(tostring(cardProblem):find("trainer-card-profile-failure", 1, true)
    ~= nil,
  "profile renderer retains the original failure detail")
T.eq(love.graphics.draw, failingDraw,
  "failed profile draw restores the engine graphics function")
T.eq(brokenPicture.minFilter, "linear",
  "failed profile draw restores the minimum filter")
T.eq(brokenPicture.magFilter, "linear",
  "failed profile draw restores the magnification filter")
love.graphics.draw = graphicsDraw

run.loader.modOptions.kanto_ascendant.trainer_portrait_style = "crystal_hd"
run.loader.modOptions.kanto_ascendant.character_sprite_style = "ascendant"
characters.select("BLUE")
T.eq(characters.playerVisualState({ kind = "trainer_card" }), "trainerCard",
  "Trainer Card requests use their declared resolver state")
T.eq(characters.playerVisualState({ kind = "hall_of_fame" }), "hallOfFame",
  "Hall of Fame requests use their declared resolver state")
T.eq(characters.playerVisualState({ kind = "credits" }), "credits",
  "credits requests use their declared resolver state")
T.eq(characters.playerVisualState({ kind = "intro" }), "intro",
  "intro requests use their declared resolver state")
T.eq(characters.playerVisualState({ kind = "special" }), "special",
  "special requests use their declared resolver state")
T.eq(characters.getState().player_name, nil,
  "character state never stores or overwrites a custom player name")
T.eq(characters.getState().rival_name, nil,
  "character state never stores or overwrites a custom rival name")

local green = characters.select("GREEN")
T.eq(green.rival_character, "RED", "Green-versus-Red matrix is preserved")
T.eq(characters.getPlayerGender(), "FEMALE", "Green player gender remains centralized")
T.eq(characters.playerVisualState({ side = "back", kind = "battle" }),
  "battleBack", "ordinary 2D battles keep Casey's authored back sprite")
T.eq(characters.getPlayerSprite("battleBack").path,
  "assets/characters/crystal_chars/green_back.png",
  "ordinary 2D battle back stays independent from her field style")

-- A Voxel overworld does not imply a staged 3D battle.  Bind the character
-- resolver to the reviewed renderer's public battle predicate so BACK
-- SPRITES / 3D-BTL OFF automatically restores the correct edition avatar.
local Pipelines = require("src.render.Pipelines")
local voxelCompat = assert(
  run.loader.exports.kanto_ascendant.voxelRendererCompat)
local originalPipelineLevel = Pipelines.level
local originalRendererModule = voxelCompat.module
Pipelines.level = function(id)
  if id == "voxel" then return 1 end
  return originalPipelineLevel(id)
end
for _, identity in ipairs({ "RED", "GREEN", "BLUE" }) do
  characters.select(identity)
  voxelCompat.module = function(_, name)
    T.eq(name, "OverworldBattle",
      "mixed-mode character resolver asks only for the battle boundary")
    return { wantsFront = function() return false end }, "VOXEL_ASCENDANT"
  end
  T.eq(characters.playerVisualState({ side = "back", kind = "battle" }),
    "battleBack", identity .. " uses a back sprite when 3D-BTL is off")
  T.check(characters.getPlayerSprite("battleBack").path:match(
      "/" .. identity:lower() .. "_back%.png$") ~= nil,
    identity .. " resolves its own authored battle back in mixed mode")

  voxelCompat.module = function()
    return { wantsFront = function() return true end }, "VOXEL_ASCENDANT"
  end
  T.eq(characters.playerVisualState({ side = "back", kind = "battle" }),
    "voxelFront", identity .. " stays standing in an active 3D battle")
end
voxelCompat.module = function()
  return nil, "DRAMALESS_SHAPE",
    "renderer-native-owned:DRAMALESS_SHAPE"
end
local dramalessModeGame = {
  mods = { modOptions = {} },
  save = { options = { modOptions = {} } },
  data = { trainers = {
    OPP_RIVAL1 = { pic = "native-rival-1" },
    OPP_RIVAL2 = { pic = "native-rival-2" },
    OPP_RIVAL3 = { pic = "native-rival-3" },
  } },
}
characters.select("BLUE")
characters.refreshVisuals(dramalessModeGame)
T.eq(characters.playerVisualState({ side = "back", kind = "battle" }),
  "voxelFront", "reviewed Dramaless default enables its native standing card")
T.check(dramalessModeGame.data.trainers.OPP_RIVAL1.pic:match(
    "/assets/characters/crystal_chars/green_voxel_front%.png$") ~= nil,
  "Dramaless cards ON installs Green's standing rival identity")
dramalessModeGame.mods.modOptions.DRAMALESS_SHAPE = {
  voxel_2d_battles = false,
}
characters.refreshVisuals(dramalessModeGame)
T.eq(characters.playerVisualState({ side = "back", kind = "battle" }),
  "battleBack", "Dramaless cards OFF restores the authored 2D back")
T.check(dramalessModeGame.data.trainers.OPP_RIVAL1.pic:match(
    "/assets/characters/crystal_chars/green_front%.png$") ~= nil,
  "Dramaless cards OFF restores Green's normal rival front")
dramalessModeGame.mods.modOptions.DRAMALESS_SHAPE.voxel_2d_battles = true
characters.refreshVisuals(dramalessModeGame)
T.eq(characters.playerVisualState({ side = "back", kind = "battle" }),
  "voxelFront", "Dramaless cards ON keeps the native standing card")
dramalessModeGame.mods.modOptions.DRAMALESS_SHAPE = nil
dramalessModeGame.save.options.modOptions.DRAMALESS_SHAPE = {
  voxel_2d_battles = false,
}
T.eq(characters.playerVisualState({ side = "back", kind = "battle" }),
  "battleBack", "saved Dramaless OFF state is honored before loader hydration")
voxelCompat.module = function() error("capability probe failed") end
T.eq(characters.playerVisualState({ side = "back", kind = "battle" }),
  "battleBack", "renderer resolution failure safely falls back to 2D back art")
voxelCompat.module = function()
  return { wantsFront = function() error("battle probe failed") end },
    "VOXEL_ASCENDANT"
end
T.eq(characters.playerVisualState({ side = "back", kind = "battle" }),
  "battleBack", "battle capability failure safely falls back to 2D back art")
voxelCompat.module = originalRendererModule
Pipelines.level = originalPipelineLevel
characters.select("GREEN")
T.eq(characters.getRivalSprite("overworld").sprite, "SPRITE_RED",
  "Green-versus-Red maps use Red's established sheet")
T.eq(characters.getRivalSprite("rivalPortrait").path,
  "assets/characters/crystal_chars/red_voxel_front.png",
  "Red rival portrait follows the active Crystal HD family")
T.eq(characters.getThirdCharacter(), "BLUE", "third character is retained on Green route")

local nativePortraits = {
  OPP_RIVAL1 = { pic = "native-rival-1" },
  OPP_RIVAL2 = { pic = "native-rival-2" },
  OPP_RIVAL3 = { pic = "native-rival-3" },
}
local presentationGame = { data = { trainers = nativePortraits } }
characters.setEnabled(false)
characters.refreshVisuals(presentationGame)
T.eq(nativePortraits.OPP_RIVAL1.pic, "native-rival-1",
  "disabled legacy saves leave rival portraits untouched")
characters.select("BLUE")
T.check(nativePortraits.OPP_RIVAL1.pic:match(
  "/assets/characters/crystal_chars/green_front%.png$") ~= nil,
  "enabled selection applies the clean 64px Green rival portrait")
characters.setEnabled(false)
T.eq(nativePortraits.OPP_RIVAL1.pic, "native-rival-1",
  "disabling selection restores the engine-owned rival portrait")

local labText = {
  _RedsHouse1FMomWakeUpText = "MOM: Right.\nAll boys leave home someday.",
  _PalletTownRivalsHouseSignText = "BLUE'S HOUSE",
  _BluesHouseDaisyRivalAtLabText = "BLUE is at the lab.",
  _LancesRoomLanceAfterBattleText = "His name is BLUE.",
  _OaksLabRivalGrampsText = "{RIVAL}: Gramps!",
  _OaksLabRivalWhatAboutMeText = "{RIVAL}: Hey!\nGramps! What\nabout me?",
  _CeruleanCityRivalPreBattleText = "vanilla rival challenge",
}
local storyGame = { data = { trainers = {}, text = labText } }
characters.select("GREEN")
characters.refreshVisuals(storyGame)
T.check(not labText._OaksLabRivalGrampsText:find("Gramps", 1, true),
  "Red is never called Oak's grandson in Green's route")
T.check(not labText._OaksLabRivalWhatAboutMeText:find("Gramps", 1, true),
  "all Lab rival lines lose the inherited grandson wording")
characters.select("BLUE")
characters.refreshVisuals(storyGame)
T.check(labText._OaksLabRivalGrampsText:find("Professor", 1, true) ~= nil,
  "Green rival keeps her playful voice without an invented family role")
T.check(not labText._OaksLabRivalGrampsText:find("Grandpa", 1, true),
  "Green rival never inherits Blue's grandson wording")
T.check(labText._CeruleanCityRivalPreBattleText:find("team check", 1, true) ~= nil,
  "Green personality reaches rival battles outside Oak's Lab")
characters.select("RED")
characters.refreshVisuals(storyGame)
T.eq(labText._OaksLabRivalGrampsText, "{RIVAL}: Gramps!",
  "Blue rival restores the active game's exact native wording")
characters.select("GREEN")
characters.refreshVisuals(storyGame)
T.check(labText._RedsHouse1FMomWakeUpText:find("girls", 1, true) ~= nil,
  "Green's mother addresses her as a girl")
T.eq(labText._PalletTownRivalsHouseSignText, "OAK FAMILY HOUSE",
  "shared family house sign no longer assumes Blue is the player")
T.check(labText._BluesHouseDaisyRivalAtLabText:find("{RIVAL}", 1, true) ~= nil,
  "Daisy points to the selected Red rival instead of hard-coding Blue")

local steps = run.loader.hooks:call("intro.oak_speech.build",
  function(rows) return rows end, {
    { id = "world_spiel", kind = "say" },
    { id = "name_player", kind = "name" },
    { id = "ask_rival_name", kind = "say" },
    { id = "name_rival", kind = "name" },
  }, {})
T.eq(steps[2].id, "extended_character_selection",
  "New Game opens the default selector before player naming")
T.eq(steps[4].id, "extended_character_relation",
  "Blue receives his family cue and Green her Pallet introduction")
T.eq(steps[7].id, "extended_rival_confirmation",
  "Oak confirms the chosen rival name after the naming screen")
for _, step in ipairs(steps) do
  if step.id == "name_player" or step.id == "ask_rival_name" or step.id == "name_rival" then
    T.eq(step.kind, "fn", "rival naming resolves through identity")
  end
end

local function introStep(id)
  for _, step in ipairs(steps) do
    if step.id == id then return step end
  end
end

-- Exercise the actual naming-screen options, callbacks and save writes.  A
-- mere step-kind assertion missed the first demo's stale Green naming menu.
local Screens = require("src.ui.Screens")
local originalPush = Screens.push
local pushed
local playerHoldCloseCount = 0
Screens.push = function(game, id, opts)
  T.check(playerHoldCloseCount > 0,
    "Gen1Recomp 0.2.14 player prompt closes before NamingScreen is pushed")
  pushed = { game = game, id = id, opts = opts }
end
local answers, playerDone = {}, 0
characters.select("GREEN")
local namingSpeech = {
  game = { save = { player = {} } }, nameLen = 7,
  holdBox = { text = "First, what is your name?" },
  closeHoldBox = function(self)
    self.holdBox = nil
    playerHoldCloseCount = playerHoldCloseCount + 1
  end,
  recordAnswer = function(_, step, index, value, label)
    answers[#answers + 1] = { step = step.id, index = index,
      value = value, label = label }
  end,
}
introStep("name_player").run(namingSpeech,
  function() playerDone = playerDone + 1 end)
T.eq(namingSpeech.holdBox, nil,
  "custom player naming releases Gen1Recomp's held prompt")
T.eq(playerHoldCloseCount, 1,
  "custom player naming closes the held prompt exactly once")
T.eq(pushed.id, "NamingScreen", "Green player uses the real naming screen")
T.eq(pushed.opts.title, "HER NAME?", "Green player naming uses female wording")
T.eq(pushed.opts.presets[1], "GREEN", "Green is the first player-name preset")
T.eq(pushed.opts.presets[2], "CASEY", "Casey is Green's second player-name preset")
T.eq(pushed.opts.presets[3], "JEAN", "Jean is Green's third player-name preset")
T.eq(pushed.opts.newNameLast, true,
  "free player-name entry is explicitly ordered last")
pushed.opts.onDone("LEAF")
T.eq(namingSpeech.game.save.player.name, "LEAF",
  "custom Green player name is written to the vanilla save field")
T.eq(answers[1].step, "name_player", "player naming records the original intro step")
T.eq(playerDone, 1, "player naming advances exactly once")

-- Keep the pre-0.2.14 contract valid too. If Gen1Recomp removes the held-box
-- lifecycle again, Ascendant must continue directly to its naming screen.
local legacyPlayerDone = 0
local legacyNamingSpeech = {
  game = { save = { player = {} } }, nameLen = 7,
  recordAnswer = function() end,
}
introStep("name_player").run(legacyNamingSpeech,
  function() legacyPlayerDone = legacyPlayerDone + 1 end)
T.eq(pushed.id, "NamingScreen",
  "engines without closeHoldBox keep the legacy naming path")
pushed.opts.onDone("RED")
T.eq(legacyNamingSpeech.game.save.player.name, "RED",
  "legacy naming path still writes the selected player name")
T.eq(legacyPlayerDone, 1,
  "legacy naming path advances exactly once")

characters.select("BLUE")
local rivalDone = 0
introStep("name_rival").run(namingSpeech,
  function() rivalDone = rivalDone + 1 end)
T.eq(pushed.opts.title, "HER NAME?", "Green rival naming uses female wording")
T.eq(pushed.opts.presets[1], "GREEN", "Green is the first rival-name preset")
T.eq(pushed.opts.presets[2], "CASEY", "Casey is Green's second rival-name preset")
T.eq(pushed.opts.presets[3], "JEAN", "Jean is Green's third rival-name preset")
T.eq(pushed.opts.newNameLast, true,
  "free rival-name entry is explicitly ordered last")
pushed.opts.onDone("IVY")
T.eq(namingSpeech.game.save.player.rival, "IVY",
  "custom Green rival name is written to the vanilla save field")
T.eq(rivalDone, 1, "rival naming advances exactly once")

characters.select("RED")
introStep("name_player").run(namingSpeech, function() end)
T.eq(pushed.opts.title, "YOUR NAME?", "Red player keeps neutral player wording")
T.eq(pushed.opts.presets[1], "RED", "Red route restores the Red name preset")
T.eq(pushed.opts.presets[2], "ASH", "Red keeps Ash as the second preset")
T.eq(pushed.opts.presets[3], "JACK", "Red keeps Jack as the third preset")
introStep("name_rival").run(namingSpeech, function() end)
T.eq(pushed.opts.title, "HIS NAME?", "Blue rival keeps male wording")
T.eq(pushed.opts.presets[1], "BLUE", "Red route restores the Blue rival preset")
T.eq(pushed.opts.presets[2], "GARY", "Blue keeps Gary as the second preset")
T.eq(pushed.opts.presets[3], "JOHN", "Blue keeps John as the third preset")

characters.select("GREEN")
introStep("name_rival").run(namingSpeech, function() end)
T.eq(pushed.opts.title, "HIS NAME?", "Red rival keeps male wording")
T.eq(pushed.opts.presets[1], "RED", "Green route starts Red's suggestions with Red")
T.eq(pushed.opts.presets[2], "ASH", "Green route offers Ash for Red")
T.eq(pushed.opts.presets[3], "JACK", "Green route offers Jack for Red")
Screens.push = originalPush

-- Exercise the real NamingScreen/Menu stack as well as its options contract:
-- suggestions must actually render above NEW NAME in an unmodified engine.
local StateStack = require("src.core.StateStack")
local liveGame = { save = { player = {} }, data = {} }
liveGame.stack = setmetatable({}, { __index = StateStack })
liveGame.stack:init()
local liveSpeech = {
  game = liveGame, nameLen = 7,
  recordAnswer = function() end,
}
characters.select("GREEN")
introStep("name_rival").run(liveSpeech, function() end)
local liveMenu = liveGame.stack:top()
T.eq(liveMenu.items[1].label, "RED", "live naming menu puts Red first")
T.eq(liveMenu.items[2].label, "ASH", "live naming menu puts Ash second")
T.eq(liveMenu.items[3].label, "JACK", "live naming menu puts Jack third")
T.eq(liveMenu.items[4].label, "NEW NAME",
  "live naming menu puts free name entry at the bottom")

local blueRivalLine, blueRivalDone, blueRivalPic = nil, 0, nil
characters.select("RED")
introStep("ask_rival_name").run({
  applyPic = function(_, pic) blueRivalPic = pic.pic end,
  sayText = function(_, line, next)
    blueRivalLine = line
    if next then next() end
  end,
}, function() blueRivalDone = blueRivalDone + 1 end)
T.eq(blueRivalLine,
  "This is my grand-\nson.\fHe's been your\nrival for years.\f...What was his\nname again?",
  "Red route introduces Oak's grandson before asking for his name")
T.eq(blueRivalPic, "rival",
  "Red route switches from the player to Blue's portrait")
T.eq(blueRivalDone, 1, "Blue rival introduction advances exactly once")

characters.select("BLUE")
introStep("ask_rival_name").run({
  applyPic = function() end,
  sayText = function(_, line, next)
    blueRivalLine = line
    if next then next() end
  end,
}, function() end)
T.eq(blueRivalLine,
  "This girl is from\nPALLET TOWN.\fShe's friendly, quick,\nand full of plans.\f...What was her\nname again?",
  "Blue route introduces Green without inventing an Oak relationship")

local relationLine, relationDone = nil, 0
characters.select("GREEN")
introStep("extended_character_relation").run({
  sayText = function(_, line, next)
    relationLine = line
    if next then next() end
  end,
}, function() relationDone = relationDone + 1 end)
T.eq(relationLine, "Ah, {PLAYER}!\fYour journey begins\ntoday.",
  "Oak welcomes Green without calling her his granddaughter")
T.check(not relationLine:find("grand", 1, true),
  "Green's player introduction has no family claim")
T.eq(relationDone, 1, "Green's player introduction advances exactly once")

characters.select("BLUE")
introStep("extended_character_relation").run({
  sayText = function(_, line, next)
    relationLine = line
    if next then next() end
  end,
}, function() end)
T.check(relationLine:find("my grandson", 1, true) ~= nil,
  "Blue remains Professor Oak's canonical grandson")

local greenRivalLine, greenRivalDone = nil, 0
characters.select("GREEN")
for _, step in ipairs(steps) do
  if step.id == "ask_rival_name" then
    step.run({
      applyPic = function() end,
      sayText = function(_, line, next)
        greenRivalLine = line
        if next then next() end
      end,
    }, function() greenRivalDone = greenRivalDone + 1 end)
  end
end
T.eq(greenRivalLine,
  "This boy is from\nPALLET TOWN.\fHe says little, but\nlistens closely.\f...What was his\nname again?",
  "Green's route introduces Red as a quiet non-grandchild Pallet boy")
T.eq(greenRivalDone, 1,
  "the Green rival introduction advances exactly once")

local confirmationLine, confirmationDone = nil, 0
namingSpeech.game.save.player.rival = "RAY"
introStep("extended_rival_confirmation").run({
  game = namingSpeech.game,
  applyPic = function() end,
  sayText = function(_, line, next)
    confirmationLine = line:gsub("{RIVAL}", namingSpeech.game.save.player.rival)
    if next then next() end
  end,
}, function() confirmationDone = confirmationDone + 1 end)
T.eq(confirmationLine, "Right! RAY!\fA trainer from\nPALLET TOWN.",
  "Oak confirms the actual chosen Red name and role")
T.eq(confirmationDone, 1, "rival confirmation advances exactly once")

run.release()
assetSink.cleanup()
T.eq(love.graphics.newImage, originalLoveNewImage,
  "headless asset bridge restores the engine image loader")
T.finish("extended_characters_test")
