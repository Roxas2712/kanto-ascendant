package.path = "./?.lua;./?/init.lua;" .. package.path

local S = require("tests.harness").suite("Crystal v1.5 integration")
local check, eq = S.check, S.eq
local modDir = assert(os.getenv("TRAINER_REMATCH_MOD_DIR"),
  "TRAINER_REMATCH_MOD_DIR is required")

love = love or require("tests.love_stub")
-- A real LÖVE runtime exposes love.image.  Its presence lets this test drive
-- the COLORS-aware v1.5 branch while the ordinary SDK suite retains its
-- historical renderer-free true-colour expectations.
love.image = love.image or {}

local PaletteFX = require("src.render.PaletteFX")
local originalMode = PaletteFX.mode
PaletteFX.mode = "gbc"

local values = {
  pokemon_sprite_style = "crystal",
  character_sprite_style = "crystal",
  sprite_style_battle = true,
  sprite_style_summary = true,
  sprite_style_dex = true,
  sprite_style_box = true,
  sprite_style_scenes = true,
  crystal_animation = true,
  dex_sprite_style = "original",
}
local events, hooks, scales = {}, {}, {}
local function read(relative)
  local file = io.open(modDir .. "/" .. relative, "rb")
  if not file then return nil end
  local bytes = file:read("*a")
  file:close()
  return bytes
end
local externalMods = {}
local mod = {
  path = "/fake/kanto_ascendant",
  options = { get = function(_, key) return values[key] end },
  read = function(_, relative) return read(relative) end,
  events = { on = function(_, name, fn) events[name] = fn end },
  hooks = { wrap = function(_, name, fn) hooks[name] = fn end },
  content = {
    battle_sprite_scales = {
      register = function(_, id, def) scales[id] = def end,
    },
  },
  find = function(first, second)
    local id = second == nil and first or second
    local exports = externalMods[id]
    if exports == nil then return nil end
    return { id = id, version = "fixture", exports = exports }
  end,
}
local data = {
  pokemon = {
    BULBASAUR = { dex = 1 }, NIDORINO = { dex = 33 },
    CHIKORITA = { dex = 152 },
  },
}
local shinySystem = {
  isShiny = function(mon) return mon and mon.shiny == true end,
}
local timing = {
  normal = { ["1"] = { 100, 100 }, ["33"] = { 100, 100 },
    ["152"] = { 100, 100 } },
  shiny = { ["1"] = { 100, 100 }, ["33"] = { 100, 100 },
    ["152"] = { 100, 100 } },
  grayscale = { ["1"] = { 100, 100 }, ["33"] = { 100, 100 },
    ["152"] = { 100, 100 } },
}
local crystalFactory = assert(loadfile(modDir .. "/crystal_animation.lua"))()
local crystal = crystalFactory(mod, {
  animationData = timing,
  shinySystem = shinySystem,
  speciesOrder = { "CHIKORITA" },
})

local ctx = { species = "BULBASAUR", data = data, mon = {}, kind = "battle" }
local path, trueColor = crystal.staticFrameOne(ctx, "front", "normal")
check(path:find("/front/grayscale/1/001.png", 1, true) ~= nil,
  "GBC/SGB-style modes use the authored grayscale front")
eq(trueColor, false, "grayscale fronts remain palette-pass aware")

path, trueColor = crystal.select(ctx, "front", false)
check(path:find("/front/grayscale/1/001.png", 1, true) ~= nil,
  "battle animation starts from the grayscale v1.5 frame")
eq(trueColor, false, "battle grayscale frames are not marked true color")

path, trueColor = crystal.select(ctx, "back", false)
check(path:find("/back/grayscale/1/001.png", 1, true) ~= nil,
  "player-side Kanto art uses the v1.5 grayscale back")
eq(trueColor, false, "grayscale backs retain the engine palette pass")

-- The FireRed-styled menus are true-colour surfaces even when the saved
-- battle palette is GBC.  Exercise every shipped species instead of a small
-- representative sample so a gray Box fallback cannot hide again.
local surfaceData = { pokemon = {} }
for dex = 1, 251 do
  local species = ("SPRITE_AUDIT_%03d"):format(dex)
  surfaceData.pokemon[species] = { dex = dex }
  for _, surface in ipairs({ "summary", "dex", "box", "evolution" }) do
    local surfaceCtx = {
      species = species, data = surfaceData, mon = {}, kind = surface,
    }
    local normalPath, normalTrueColor = crystal.staticFrameOne(
      surfaceCtx, "front", "normal")
    check(type(normalPath) == "string"
        and normalPath:find(("/front/normal/%d/001.png"):format(dex),
          1, true) ~= nil,
      ("#%03d %s uses the authored colour frame"):format(dex, surface))
    eq(normalTrueColor, true,
      ("#%03d %s is marked true-colour"):format(dex, surface))

    surfaceCtx.mon.shiny = true
    local shinyPath, shinyTrueColor = crystal.staticFrameOne(
      surfaceCtx, "front", "shiny")
    check(type(shinyPath) == "string"
        and shinyPath:find(("/front/shiny/%d/001.png"):format(dex),
          1, true) ~= nil,
      ("#%03d shiny %s uses its authored frame"):format(dex, surface))
    eq(shinyTrueColor, true,
      ("#%03d shiny %s is marked true-colour"):format(dex, surface))
  end
end

local Pipelines = require("src.render.Pipelines")
local originalPipelineGet = Pipelines.get
Pipelines.get = function(id)
  if id == "voxel" then return { levels = { "OFF", "ON" } } end
  return originalPipelineGet(id)
end
Pipelines.setLevel("voxel", 1)
check(crystal.advancedColor(),
  "Voxel forces authored colour Crystal art even with the GBC palette saved")
path, trueColor = crystal.staticFrameOne(ctx, "front", "normal")
check(path:find("/front/normal/1/001.png", 1, true) ~= nil,
  "Voxel does not turn Pikachu or other Crystal Pokémon gray")
eq(trueColor, true, "Voxel Crystal frames remain true colour")
Pipelines.reset()
Pipelines.get = originalPipelineGet

PaletteFX.mode = "redpp"
ctx.mon.shiny = true
path, trueColor = crystal.staticFrameOne(ctx, "front", "shiny")
check(path:find("/front/shiny/1/001.png", 1, true) ~= nil,
  "ADVANCED mode preserves Ascendant's existing shiny animation pack")
eq(trueColor, true, "ADVANCED shiny frames remain true color")

local fakeBattleState = {
  update = function() end,
  effectRecord = function()
    return { run = function() return "ran" end }
  end,
  applyAnimEffect = function() return "applied" end,
  speciesSprite = function() return { original = true } end,
}
local game = { data = data, mods = { exports = {}, mods = {} } }
crystal.install(game, { battleState = fakeBattleState })

local user, target = { mon = { species = "DITTO" } },
  { mon = { species = "BULBASAUR" } }
local battle = setmetatable({
  data = data,
  animFxBattler = function(_, targetSide)
    return targetSide and target or user
  end,
}, { __index = fakeBattleState })
fakeBattleState.applyAnimEffect(battle, { effect = "SE_TRANSFORM_MON" })
eq(user.__ascendantCrystalTransformed, "BULBASAUR",
  "Transform records the copied species when the animation square lands")

local offUser = { mon = { species = "DITTO" } }
local record = fakeBattleState:effectRecord("TRANSFORM_EFFECT")
record.run({
  battle = { animationsOn = function() return false end },
  user = offUser,
  target = target,
})
eq(offUser.__ascendantCrystalTransformed, "BULBASAUR",
  "Transform still records its target when battle animations are disabled")

local v15Factory = assert(loadfile(modDir .. "/crystal_v15_features.lua"))()
local catalogueOwner = {
  ownsCatalogue = function(species, kind)
    return species == "GOROCHU"
      and (kind == "summary" or kind == "dex")
      and values.dex_sprite_style ~= "crystal"
  end,
}
local v15 = v15Factory(mod, {
  crystalAnimation = crystal,
  shinySystem = shinySystem,
  catalogueOwner = catalogueOwner,
})
local presentationCalls = 0
local originalPresentationAnimation = crystal.presentationAnimation
local replacement = { current = "v1.5 replacement" }
crystal.presentationAnimation = function()
  presentationCalls = presentationCalls + 1
  return { image = replacement, trueColor = true }
end
local retainedSummary = { game = { data = data }, sprite = { current = "primary" } }
local retainedSummaryImage = retainedSummary.sprite
v15:decorateSummary(retainedSummary, { species = "GOROCHU" })
eq(retainedSummary.sprite, retainedSummaryImage,
  "default Gorochu summary keeps the catalogue owner's current primary art")
local retainedDex = { game = { data = data }, sprite = { current = "primary" } }
local retainedDexImage = retainedDex.sprite
v15:decorateDex(retainedDex, "GOROCHU")
eq(retainedDex.sprite, retainedDexImage,
  "default Gorochu Dex keeps the catalogue owner's current primary art")
eq(presentationCalls, 0,
  "v1.5 never adds a second Gorochu layer over default catalogue views")
values.dex_sprite_style = "crystal"
v15:decorateSummary(retainedSummary, { species = "GOROCHU" })
eq(retainedSummary.sprite, replacement,
  "explicit Crystal Dex mode retains the v1.5 presentation choice")
eq(presentationCalls, 1,
  "explicit Crystal mode reaches exactly one presentation authority")
values.dex_sprite_style = "original"
crystal.presentationAnimation = originalPresentationAnimation
check(hooks["player.sprite"] ~= nil,
  "the player portrait resolver is registered independently")
local playerCtx = { kind = "hof", side = "front" }
local playerPath = hooks["player.sprite"](
  function(original) return original end, "vanilla-red.png", playerCtx)
eq(playerPath, "vanilla-red.png",
  "v1.5 cannot overwrite the central FRLG character resolver")
eq(playerCtx.trueColor, nil,
  "yielded trainer path does not forge true-color metadata")
check(next(scales) ~= nil,
  "v1.5 player battle backs receive an explicit native-size scale")

local oak = { game = game, demoSpecies = "BULBASAUR" }
v15:decorateOak(oak)
check(oak.__ascendantCrystalV15OakDemo ~= nil,
  "Oak's demo Pokémon receives a Crystal animation before gameplay starts")
local oakFrame = oak.__ascendantCrystalV15OakDemo.frame
crystal.advancePresentation(oak.__ascendantCrystalV15OakDemo, 0.11, game)
check(oak.__ascendantCrystalV15OakDemo.frame ~= oakFrame,
  "Oak's demo Pokémon advances through its authored Crystal frames")
-- Oak's single mirrored Nidorino must stay legible even when the player has
-- globally selected legacy art and disabled scene sprites.  No other species
-- receives this narrow forced-bundled exception.
values.pokemon_sprite_style = "legacy"
values.sprite_style_scenes = false
values.crystal_animation = false
local nativeNidorino = { source = "native-red-nidorino" }
local lateOak = { game = game, demoPic = nativeNidorino,
  demoTrueColor = false }
v15:decorateOak(lateOak)
lateOak.demoSpecies = "NIDORINO"
v15:advanceOak(lateOak)
local nidorino = lateOak.__ascendantCrystalV15OakDemo
check(nidorino and nidorino.species == "NIDORINO" and nidorino.animated
    and nidorino.__kaOakForceBundled == true,
  "late-published Oak Nidorino forces its bundled Crystal animation")
check(lateOak.demoPic ~= nativeNidorino
    and nidorino.path:find("/front/normal/33/001.png", 1, true) ~= nil,
  "legacy/off Oak Nidorino resolves the clearer bundled Crystal front")
local receipt = lateOak.__ascendantCrystalV15OakDemoReceipt
check(receipt and receipt.schema == "ka-oak-crystal-animation/v1"
    and receipt.species == "NIDORINO" and receipt.frameCount > 1
    and receipt.forcedBundled == true,
  "Oak Nidorino publishes an inspectable forced-Crystal receipt")
local nidorinoFrame = nidorino and nidorino.frame
if nidorino then crystal.advancePresentation(nidorino, 0.11, game) end
check(nidorino and nidorino.frame ~= nidorinoFrame,
  "forced Oak Nidorino advances beyond its first Crystal frame")
values.pokemon_sprite_style = "crystal"
values.sprite_style_scenes = true
values.crystal_animation = true
oak.pic = { getDimensions = function() return 40, 40 end }
oak.picTrueColor = true
local oakZone = v15:oakTrueColorZone(oak)
eq(oakZone.colors, false,
  "Oak's Crystal demo publishes an early true-colour palette exclusion")
eq(oakZone.x, 56, "Oak's 40px demo true-colour zone is centered")
eq(oakZone.y, 48, "Oak's 40px demo true-colour zone is bottom-aligned")
eq(oakZone.w, 40, "Oak's demo exclusion keeps the image width")
eq(oakZone.h, 40, "Oak's demo exclusion keeps the image height")
oak.picTrueColor = false
eq(v15:oakTrueColorZone(oak), nil,
  "palette-aware Oak pictures do not receive a forged exclusion")

game.save = { party = { { species = "BULBASAUR" } } }
local hall = { game = game, index = 1 }
check(v15:hallSprite(hall, "BULBASAUR") ~= nil,
  "Hall of Fame receives the authored Crystal picture")
eq(hall.spriteTrueColors.BULBASAUR, true,
  "Hall of Fame retains the Crystal picture's true-colour contract")
local hallFrame = hall.__ascendantCrystalV15Hall.BULBASAUR.frame
v15:updateHall(hall, 0.11)
check(hall.__ascendantCrystalV15Hall.BULBASAUR.frame ~= hallFrame,
  "Hall of Fame advances the authored Crystal animation")

-- Ascendant preserves the engine-owned title rotation, but its current
-- arbitrary cycle species is a bundled presentation contract. It must not
-- inherit gameplay scene/style toggles or fall through to another provider,
-- otherwise trainer and Pokemon identity can split again.
values.pokemon_sprite_style = "original"
values.sprite_style_scenes = false
values.crystal_animation = false
local title = {
  game = game,
  cycleSpecies = { "NIDORINO" }, cycleIndex = 1,
  kaTitleAtomicCycle = true, kaTitleSpecies = "NIDORINO",
  kaTitlePairId = "GREEN:NIDORINO",
}
local titleImage, titleTrueColor = v15:titleSprite(title)
local titleState = title.__ascendantCrystalV15Title
check(titleImage ~= nil and titleState ~= nil
    and titleState.species == "NIDORINO" and titleState.animated,
  "atomic title cycle forces the bundled animated current species")
eq(titleTrueColor, true,
  "forced bundled title frame preserves authored true colour")
check(titleState.path:find("/front/normal/33/001.png", 1, true) ~= nil,
  "forced title cycle selects bundled Nidorino from the native rotation")
values.pokemon_sprite_style = "crystal"
values.sprite_style_scenes = true
values.crystal_animation = true

values.sprite_style_scenes = false
eq(v15:trainerImage("prof.oak", "battle"), nil,
  "v1.5 trainer art stays disabled in favor of the FRLG pack")
eq(v15:trainerImage("prof.oak"), nil,
  "scene portraits obey the scene-specific toggle")
values.sprite_style_scenes = true

externalMods.crystal_animated_sprites_with_shiny_visuals = {}
eq(v15.scopeEnabled("scenes"), false,
  "an enabled external Crystal mod retains ownership without double hooks")
title.__ascendantCrystalV15Title = nil
local externalTitle = v15:titleSprite(title)
check(externalTitle ~= nil and title.__ascendantCrystalV15Title
    and title.__ascendantCrystalV15Title.species == "NIDORINO",
  "atomic title cycle still uses bundled art with an external provider")
local yielded = hooks["player.sprite"](
  function(original) return original end, "vanilla-red.png", {})
eq(yielded, "vanilla-red.png",
  "player portrait routing yields to the external Crystal mod")

PaletteFX.mode = originalMode
S.finish()
