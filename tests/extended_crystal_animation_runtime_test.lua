-- Runtime contract for identity-correct authored Crystal motion #252-279.

package.path = "./?.lua;./?/init.lua;" .. package.path

local S = require("tests.harness").suite("Extended Crystal animation runtime")
local check, eq = S.check, S.eq
local modDir = assert(os.getenv("TRAINER_REMATCH_MOD_DIR"),
  "TRAINER_REMATCH_MOD_DIR is required")

local function readable(relative)
  local handle = io.open(modDir .. "/" .. relative, "rb")
  if not handle then return nil end
  local body = handle:read("*a")
  handle:close()
  return body
end

local values = {
  pokemon_sprite_style = "crystal",
  sprite_style_battle = true,
  sprite_style_summary = true,
  sprite_style_dex = true,
  sprite_style_box = true,
  sprite_style_scenes = true,
  crystal_animation = true,
}
local fakeMod = {
  path = modDir,
  read = function(_, relative) return readable(relative) end,
  options = { get = function(_, key) return values[key] end },
  events = { on = function() end },
  hooks = { wrap = function() end },
  content = { battle_sprite_scales = { register = function() end } },
}
local data = { pokemon = {
  TREECKO = { id = "TREECKO", dex = 252 },
  HONCHKROW = { id = "HONCHKROW", dex = 263, sourceDex = 430 },
  AMBIPOM = { id = "AMBIPOM", dex = 261, sourceDex = 424 },
  MISMAGIUS = { id = "MISMAGIUS", dex = 262, sourceDex = 429 },
  LICKILICKY = { id = "LICKILICKY", dex = 266, sourceDex = 463 },
  RHYPERIOR = { id = "RHYPERIOR", dex = 267, sourceDex = 464 },
  TANGROWTH = { id = "TANGROWTH", dex = 268, sourceDex = 465 },
  YANMEGA = { id = "YANMEGA", dex = 272, sourceDex = 469 },
  WYNAUT = { id = "WYNAUT", dex = 279, sourceDex = 360 },
} }
local shinySystem = {
  isShiny = function(mon) return mon and mon.shiny == true end,
}
local timing = dofile(modDir .. "/extended_crystal_animation_data.lua")
local guests = {}
for dex = 252, 279 do guests[dex] = true end

local oldLove = _G.love
_G.love = {
  graphics = {
    newImage = function(path)
      return { path = path, setFilter = function() end }
    end,
  },
}

local controller = assert(dofile(modDir .. "/crystal_animation.lua")(
  fakeMod, {
    animationData = timing,
    shinySystem = shinySystem,
    guestDexes = guests,
  }))

check(controller.available[252], "Treecko has authored front timing")
check(controller.shinyAvailable[263], "Honchkrow shiny has authored timing")
check(controller.available[261],
  "Ambipom has its exact authored Polished Crystal timing")
check(controller.available[279],
  "Wynaut has its exact authored Polished Crystal timing")
eq(controller.backAnimatedAvailable.normal[252], false,
  "Treecko's one supplied rear pose is honestly static")

local treecko = { species = "TREECKO" }
local battleCtx = {
  species = "TREECKO", mon = treecko, kind = "battle", side = "front",
  data = data,
}
local first = assert(controller.select(battleCtx, "front", false))
check(first:find("/front/normal/252/001.png", 1, true) ~= nil,
  "battle starts on authored Treecko frame one")
local battle = {
  data = data,
  enemy = { mon = treecko, sprite = { path = first } },
  showEnemyTrainer = false,
  enemySendingOut = false,
}
controller.updateBattle(battle, 0.40)
local battleState = assert(battle.enemy.__ascendantCrystalAnimation,
  "enemy receives an authored animation state")
check(battleState.frame > 1,
  "enemy battle visibly advances beyond frame one")
check(battle.enemy.sprite.path:find("/front/normal/252/", 1, true) ~= nil,
  "enemy battle swaps only within Treecko's exact internal slot")

local shiny = { species = "HONCHKROW", shiny = true }
local shinyPath = assert(controller.select({
  species = "HONCHKROW", mon = shiny, kind = "battle", side = "front",
  data = data,
}, "front", false))
check(shinyPath:find("/front/shiny/263/001.png", 1, true) ~= nil,
  "private #263 resolves HONCHKROW, not National Zigzagoon")

local rear = assert(controller.select({
  species = "TREECKO", mon = treecko, kind = "battle", side = "back",
  data = data,
}, "back", false))
check(rear:find("/back/normal/252/001.png", 1, true) ~= nil,
  "player battle uses the supplied rear pose")
eq(controller.selected[treecko], nil,
  "one-pose rear receives no front-derived motion state")

local ambipom = { species = "AMBIPOM" }
local ambipomPath = assert(controller.select({
  species = "AMBIPOM", mon = ambipom, kind = "battle", side = "front",
  data = data,
}, "front", false))
check(ambipomPath:find("/front/normal/261/001.png", 1, true) ~= nil,
  "Ambipom battle owns its exact authored frame sequence")
local staticAmbipom = assert(controller.staticFrameOne({
  species = "AMBIPOM", mon = ambipom, kind = "summary", data = data,
}, "front", "normal"))
check(staticAmbipom:find("/front/normal/261/001.png", 1, true) ~= nil,
  "Ambipom still exposes a deterministic first authored pose")

for _, surface in ipairs({ "scenes", "summary", "dex", "box" }) do
  local state = assert(controller.presentationAnimation(
    "TREECKO", treecko, "front", surface, { data = data }))
  check(state.animated and state.authoredTiming,
    surface .. " accepts authored Treecko motion")
  local before = state.frame
  controller.advancePresentation(state, 0.40, { data = data })
  check(state.frame ~= before,
    surface .. " visibly advances an authored frame")
end

local ambipomState = assert(controller.presentationAnimation(
  "AMBIPOM", ambipom, "front", "summary", { data = data }))
eq(ambipomState.animated, true,
  "Summary reports Ambipom's real multi-pose motion")
eq(ambipomState.authoredTiming, true,
  "Summary uses Ambipom's authored timing")
local ambipomBefore = ambipomState.frame
controller.advancePresentation(ambipomState, 0.40, { data = data })
check(ambipomState.frame ~= ambipomBefore,
  "Summary visibly advances Ambipom beyond frame one")

local polishedIdentities = {
  AMBIPOM = 261, MISMAGIUS = 262, LICKILICKY = 266,
  RHYPERIOR = 267, TANGROWTH = 268, YANMEGA = 272, WYNAUT = 279,
}
local function imageBody(image)
  local handle = assert(io.open(image.path, "rb"))
  local body = handle:read("*a")
  handle:close()
  return body
end
for species, dex in pairs(polishedIdentities) do
  local mon = { species = species }
  local state = assert(controller.presentationAnimation(
    species, mon, "front", "summary", { data = data }))
  check(state.animated and state.authoredTiming,
    species .. " exposes authored Polished Crystal motion")
  local firstBody = imageBody(state.image)
  local visiblyChanged = false
  for _ = 1, 40 do
    controller.advancePresentation(state, 0.10, { data = data })
    if imageBody(state.image) ~= firstBody then
      visiblyChanged = true
      break
    end
  end
  check(visiblyChanged,
    species .. " reaches a genuinely different authored pose at runtime")
  check(state.image.path:find("/front/normal/" .. dex .. "/", 1, true) ~= nil,
    species .. " never crosses its private identity directory")
end

local v15 = assert(dofile(modDir .. "/crystal_v15_features.lua")(
  fakeMod, { crystalAnimation = controller, shinySystem = shinySystem }))
local summary = { game = { data = data } }
v15:decorateSummary(summary, treecko)
check(summary.__ascendantCrystalV15 and
    summary.__ascendantCrystalV15.animated,
  "Summary wrapper receives authored motion")
local dex = { game = { data = data } }
v15:decorateDex(dex, "TREECKO")
check(dex.__ascendantCrystalV15 and dex.__ascendantCrystalV15.animated,
  "Dex wrapper receives authored motion")
local title = {
  game = { data = data }, cycleSpecies = { "TREECKO" }, cycleIndex = 1,
}
check(v15:titleSprite(title) ~= nil and
    title.__ascendantCrystalV15Title.animated,
  "Title wrapper receives authored motion")
local hall = {
  game = { data = data, save = { party = { treecko } } }, index = 1,
}
check(v15:hallSprite(hall, "TREECKO") ~= nil and
    hall.__ascendantCrystalV15Hall.TREECKO.animated,
  "Hall of Fame wrapper receives authored motion")

for _, key in ipairs({
  "title", "battle_enemy", "battle_player", "dex_entry", "summary",
  "box_stats", "hall_of_fame", "follower", "wild_overworld", "voxel",
}) do
  check(controller.presentationSurfaces[key] ~= nil,
    "truth matrix names " .. key)
end
check(controller.presentationSurfaces.follower:find("walking", 1, true) ~= nil,
  "follower animation remains owned by its walking renderer")
check(controller.presentationSurfaces.voxel:find("Voxel", 1, true) ~= nil,
  "Voxel animation remains owned by the Voxel renderer")

local incompleteMod = {
  path = "/incomplete",
  read = function(_, relative)
    if relative == "assets/crystal_animated/front/normal/252/001.png" then
      return "png"
    end
    return nil
  end,
  options = fakeMod.options,
  events = fakeMod.events,
  content = fakeMod.content,
}
local incomplete = assert(dofile(modDir .. "/crystal_animation.lua")(
  incompleteMod, {
    animationData = { normal = { ["252"] = { 100, 100 } }, shiny = {} },
    shinySystem = shinySystem,
    guestDexes = { [252] = true },
  }))
local incompleteState = assert(incomplete.presentationAnimation(
  "TREECKO", treecko, "front", "summary", { data = data }))
eq(incompleteState.animated, false,
  "missing frame two fails closed to a static state")
local incompleteImage = incompleteState.image
incomplete.advancePresentation(incompleteState, 1, { data = data })
eq(incompleteState.image, incompleteImage,
  "missing frame two cannot fabricate motion")

-- Gorochu is the sole private guest with an authored CLASSIC monochrome
-- identity. It must also survive a live colour/style switch: the engine's
-- COLORS hotkey does not reconstruct battlers or re-run pokemon.sprite.
data.pokemon.GOROCHU = { id = "GOROCHU", dex = 1026 }
local gorochuTiming = {
  normal = {
    ["252"] = timing.normal["252"],
    ["1026"] = { 230, 100, 115, 105, 115, 300 },
  },
  shiny = {
    ["252"] = timing.shiny["252"],
    ["1026"] = { 230, 100, 115, 105, 115, 300 },
  },
  grayscale = { ["1026"] = { 230, 100, 115, 105, 115, 300 } },
  back = {
    normal = { ["1026"] = { 230, 100, 115, 105, 115, 300 } },
    shiny = { ["1026"] = { 230, 100, 115, 105, 115, 300 } },
    grayscale = { ["1026"] = { 230, 100, 115, 105, 115, 300 } },
  },
}
local gorochuController = assert(dofile(modDir .. "/crystal_animation.lua")(
  fakeMod, {
    animationData = gorochuTiming,
    shinySystem = shinySystem,
    guestDexes = { [1026] = true, [252] = true },
    classicGuestDexes = { [1026] = true },
  }))
local gorochu = { species = "GOROCHU", shiny = false }
values.pokemon_sprite_style = "crystal"
local gorochuColorPath, gorochuColorTrue = gorochuController.select({
  species = "GOROCHU", mon = gorochu, kind = "battle", side = "front",
  data = data,
}, "front", false)
check(gorochuColorPath:find("/front/normal/1026/001.png", 1, true) ~= nil,
  "Gorochu CRYSTAL starts on the reviewed colour frame")
eq(gorochuColorTrue, true, "Gorochu CRYSTAL remains true colour")
local gorochuBattle = {
  data = data,
  enemy = { mon = gorochu, sprite = { path = gorochuColorPath } },
  showEnemyTrainer = false,
  enemySendingOut = false,
}
gorochuController.updateBattle(gorochuBattle, 0.24)
eq(gorochuBattle.enemy.__ascendantCrystalAnimation.variant, "normal",
  "Gorochu live colour state is installed")

values.pokemon_sprite_style = "legacy"
gorochuController.updateBattle(gorochuBattle, 0.24)
local classicState = assert(gorochuBattle.enemy.__ascendantCrystalAnimation)
eq(classicState.variant, "grayscale",
  "live CLASSIC switch rebuilds Gorochu instead of dropping animation")
check(classicState.image.path:find("/front/grayscale/1026/", 1, true) ~= nil,
  "live CLASSIC switch uses the authored black-and-white frames")

values.pokemon_sprite_style = "crystal"
gorochu.shiny = true
gorochuController.updateBattle(gorochuBattle, 0.24)
local shinyState = assert(gorochuBattle.enemy.__ascendantCrystalAnimation)
eq(shinyState.variant, "shiny",
  "live shiny switch rebuilds Gorochu instead of keeping stale colour art")
check(shinyState.image.path:find("/front/shiny/1026/", 1, true) ~= nil,
  "live shiny switch resolves the reviewed shiny frame family")

values.pokemon_sprite_style = "legacy"
local classicPath, classicTrue = gorochuController.select({
  species = "GOROCHU", mon = gorochu, kind = "battle", side = "back",
  data = data,
}, "back", false)
check(classicPath:find("/back/grayscale/1026/001.png", 1, true) ~= nil,
  "Gorochu CLASSIC player side has a real black-and-white backsprite")
eq(classicTrue, true,
  "CLASSIC Gorochu preserves its authored neutral black-and-white shades")

local stillTreecko = { species = "TREECKO", shiny = true }
local privatePath = assert(gorochuController.select({
  species = "TREECKO", mon = stillTreecko, kind = "battle", side = "front",
  data = data,
}, "front", false))
check(privatePath:find("/front/shiny/252/", 1, true) ~= nil,
  "CLASSIC Gorochu exception never changes private #252-279 shiny policy")
values.pokemon_sprite_style = "crystal"

_G.love = oldLove
S.finish()
