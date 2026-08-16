-- Phase-3 coverage for identity, visual resolution and role-safe rivals.
-- Run from Gen1 Recomp:
--   POKEPORT_DATA_DIR=tests/fixture_data \
--   TRAINER_REMATCH_MOD_DIR=../kanto-ascendant \
--   luajit ../kanto-ascendant/tests/extended_characters_test.lua

package.path = "./?.lua;./?/init.lua;" .. package.path

local T = require("tests.modkit")
local Data = T.fixtures.load()
local modPath = os.getenv("TRAINER_REMATCH_MOD_DIR") or "mods/kanto_ascendant"
local run = T.sdk.loadMod(modPath, { data = Data })
T.eq(#run.errors, 0, "Kanto Ascendant loads with extended characters")

local characters = assert(run.loader.exports.kanto_ascendant.extendedCharacters)
local titleIntro = assert(run.loader.exports.kanto_ascendant.titleIntro)
local frlgTrainerPack = assert(run.loader.exports.kanto_ascendant.frlgTrainerPack)
local trainerVoxelPortraits = assert(
  run.loader.exports.kanto_ascendant.trainerVoxelPortraits)
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
  if id == "RED" then
    T.eq(front, "save/mod-derived/kanto_ascendant/characters/red_front.png",
      "Red compact front uses the ROM-derived native fallback")
  else
    T.check(front:find(
        "/crystal_chars/" .. id:lower() .. "_front.png", 1, true) ~= nil,
      id .. " keeps its KASC battle front")
  end
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
  T.eq(bikeDef.frameWidth, nil, id .. " bicycle uses native 16x16 geometry")
  T.eq(fishDef.frameHeight, nil, id .. " fishing uses native 16x16 geometry")
  T.eq(walkDef.trueColor, true, id .. " custom colors bypass map recoloring")
end
run.loader.modOptions.kanto_ascendant = {
  character_sprite_style = "ascendant", trainer_portrait_style = "frlg",
}
T.eq(frlgTrainerPack.refresh(trainerGame), true,
  "legacy FRLG option can be migrated independently of field style")
T.eq(trainerGame.data.trainers.OPP_BROCK.pic, "baseline/brock.png",
  "legacy FRLG option migrates to Brock's edition-original portrait")
run.loader.modOptions.kanto_ascendant.trainer_portrait_style = "original"
T.eq(frlgTrainerPack.refresh(trainerGame), true,
  "game-original trainer portraits can be restored")
T.eq(trainerGame.data.trainers.OPP_BROCK.pic, "baseline/brock.png",
  "ORIGINAL restores the exact pre-pack Brock portrait")

-- ORIGINAL is also Green's explicit compact identity family.  It affects
-- only her front-facing identity consumers and normal 2D player back; Voxel
-- battle standees/throws stay in the complete Crystal family, and Red/Blue
-- must not inherit any Green-specific routing.
T.eq(characters.trainerPortraitStyle(), "original",
  "identity resolver reads the same ORIGINAL trainer option")
local originalGreenFrontStates = {
  "front", "selectorHd", "trainerCard", "hallOfFame", "credits",
  "intro", "special", "rivalPortrait",
}
for _, state in ipairs(originalGreenFrontStates) do
  local visual = assert(characters.getCharacterSprite("GREEN", state))
  T.eq(visual.path, "assets/characters/green_front.png",
    "ORIGINAL Green " .. state .. " uses the approved compact front")
  T.eq(visual.fallbackCharacter, nil,
    "ORIGINAL Green " .. state .. " never falls through to Red")
end
local originalGreenSelector = characters.selectionVisual("GREEN")
T.eq(originalGreenSelector.path, "assets/characters/green_front.png",
  "ORIGINAL Oak selector uses Green's compact approved front")
T.eq(originalGreenSelector.bounds, nil,
  "compact Green selector uses its complete uncropped source canvas")
T.eq(characters.getCharacterSprite("GREEN", "battleBack").path,
  "assets/characters/green_back.png",
  "ORIGINAL normal 2D Green back uses the approved compact back")
T.eq(characters.getCharacterSprite("GREEN", "voxelFront").path,
  "assets/characters/crystal_chars/green_voxel_front.png",
  "ORIGINAL never replaces Green's Voxel battle standee")
T.eq(characters.selectionVisual("RED").path,
  "assets/characters/crystal_chars/red_voxel_front_hd.png",
  "ORIGINAL Green routing leaves Red's selector untouched")
T.eq(characters.selectionVisual("BLUE").path,
  "assets/characters/crystal_chars/blue_voxel_front_hd.png",
  "ORIGINAL Green routing leaves Blue's selector untouched")
T.eq(characters.getCharacterSprite("RED", "battleBack").path,
  "assets/characters/crystal_chars/red_back.png",
  "ORIGINAL Green routing leaves Red's 2D back untouched")
T.eq(characters.getCharacterSprite("BLUE", "battleBack").path,
  "assets/characters/crystal_chars/blue_back.png",
  "ORIGINAL Green routing leaves Blue's 2D back untouched")

characters.select("GREEN")
T.eq(characters.getPlayerSprite("intro").path,
  "assets/characters/green_front.png",
  "Green player intro follows ORIGINAL compact identity")
T.eq(characters.getPlayerSprite("battleBack").path,
  "assets/characters/green_back.png",
  "Green player normal battle back follows ORIGINAL compact identity")
characters.select("BLUE")
T.eq(characters.getRivalSprite("rivalPortrait").path,
  "assets/characters/green_front.png",
  "Green rival follows ORIGINAL compact identity without aliasing Blue")

run.loader.modOptions.kanto_ascendant.trainer_portrait_style = "crystal_hd"
T.eq(characters.trainerPortraitStyle(), "crystal_hd",
  "Crystal HD remains the normalized default identity family")
T.eq(characters.selectionVisual("GREEN").path,
  "assets/characters/crystal_chars/green_voxel_front_hd.png",
  "Crystal HD restores Green's native selector master")
T.eq(characters.getCharacterSprite("GREEN", "front").path,
  "assets/characters/crystal_chars/green_front.png",
  "Crystal HD restores Green's complete front")
T.eq(characters.getCharacterSprite("GREEN", "battleBack").path,
  "assets/characters/crystal_chars/green_back.png",
  "Crystal HD restores Green's complete 2D battle back")

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
local cardProfiles = {
  RED = "save/mod-derived/kanto_ascendant/characters/red_front.png",
  BLUE = "save/mod-derived/kanto_ascendant/characters/blue_rival.png",
  GREEN = "assets/characters/green_front.png",
}
local blueCardPath = run.loader.hooks:call("player.sprite",
  function(path) return path end, "vanilla-front.png",
  { side = "front", kind = "trainer_card" })
T.check(blueCardPath:sub(-#cardProfiles.BLUE) == cardProfiles.BLUE,
  "Trainer Card keeps Blue's KASC Kanto profile instead of Crystal art")
for _, style in ipairs({ "ascendant", "crystal" }) do
  run.loader.modOptions.kanto_ascendant.character_sprite_style = style
  for _, identity in ipairs({ "RED", "BLUE", "GREEN" }) do
    characters.select(identity)
    T.eq(characters.getPlayerSprite("trainerCard").path,
      cardProfiles[identity],
      identity .. " Trainer Card stays on its KASC profile in "
        .. style .. " skin mode")
  end
end

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
local leaderFaces = assert(characters.trainerCardLeaderFaces())
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
local graphicsDraw = love.graphics.draw
for _, identity in ipairs({ "RED", "BLUE", "GREEN" }) do
  characters.select(identity)
  local fit = assert(characters.trainerCardProfileFit(identity, 56, 56))
  T.eq(fit.character, identity, identity .. " fit follows selected identity")
  T.eq(fit.profile.path, cardProfiles[identity],
    identity .. " fit cannot fall through to a modern/Crystal profile")
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

  local picture = { identity = identity }
  function picture:getDimensions() return 56, 56 end
  local pictureDraw
  local recorder = function(drawable, ...)
    if drawable == picture then pictureDraw = { ... } end
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
  "save/mod-derived/kanto_ascendant/characters/red_front.png",
  "Red rival portrait uses the ROM-derived native Gen-I front")
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
T.check(labText._OaksLabRivalGrampsText:find("Grandpa", 1, true) ~= nil,
  "Green rival keeps her family role and playful voice")
T.check(labText._CeruleanCityRivalPreBattleText:find("compare teams", 1, true) ~= nil,
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
  "Blue/Green receive a concise family introduction")
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
Screens.push = function(game, id, opts)
  pushed = { game = game, id = id, opts = opts }
end
local answers, playerDone = {}, 0
characters.select("GREEN")
local namingSpeech = {
  game = { save = { player = {} } }, nameLen = 7,
  recordAnswer = function(_, step, index, value, label)
    answers[#answers + 1] = { step = step.id, index = index,
      value = value, label = label }
  end,
}
introStep("name_player").run(namingSpeech,
  function() playerDone = playerDone + 1 end)
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
  "This is my grand-\ndaughter.\fShe's your cousin.\f...What was her\nname again?",
  "Blue route introduces Green as Oak's granddaughter and cousin")

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
  "This boy is from\nPALLET TOWN.\f...I seem to have\nforgotten his name.",
  "Green's route introduces Red as a non-grandchild Pallet boy")
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

T.finish("extended_characters_test")
