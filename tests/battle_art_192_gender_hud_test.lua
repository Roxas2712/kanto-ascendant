-- Focused Battle Art 1.9.2 gender/HUD ownership contract.  This deliberately
-- uses no engine fixture so the exact renderer wrapper can run in the small
-- LÖVE test host used by release QA.

local root = assert(os.getenv("TRAINER_REMATCH_MOD_DIR"),
  "TRAINER_REMATCH_MOD_DIR is required")

local checks = 0
local function ok(value, message)
  checks = checks + 1
  assert(value, message)
end
local function eq(actual, expected, message)
  checks = checks + 1
  assert(actual == expected, ("%s (got %s, want %s)")
    :format(message, tostring(actual), tostring(expected)))
end

local draws = {}
local Font = {
  draw = function(text, x, y)
    draws[#draws + 1] = { text = text, x = x, y = y }
  end,
}
package.loaded["src.render.Font"] = Font

love = love or {}
love.graphics = love.graphics or {}
local g = love.graphics
g.getCanvas = function() return nil end
g.setCanvas = function() end
g.getBlendMode = function() return "alpha", "alphamultiply" end
g.setBlendMode = function() end
g.getColor = function() return 1, 1, 1, 1 end
g.setColor = function() end

local forwarded
local renderer = {
  hudTexture = function(...)
    forwarded = { n = select("#", ...), ... }
    return { id = "battle-art-1.9.2-hud" }
  end,
}
local callbacks, overlayHook = {}, nil
local mod = {
  exports = {},
  events = {
    once = function(_, name, callback) callbacks["once:" .. name] = callback end,
    on = function(_, name, callback) callbacks[name] = callback end,
  },
  hooks = {
    wrap = function(_, name, callback)
      if name == "battle.overlay" then overlayHook = callback end
    end,
  },
}
local context
local gender = assert(loadfile(root .. "/pokemon_gender.lua"))()(mod, {
  breedingData = {
    [25] = { gender = 4 },
    [81] = { gender = -1 },
  },
  voxelRenderer = {
    module = function(_, name)
      eq(name, "OverworldBattle",
        "gender bridge requests only Battle Art's reviewed HUD module")
      return renderer
    end,
  },
  rendererBattleHud = {
    contextSchema = "ka-renderer-battle-hud-context/v1",
    context = function() return context end,
  },
})
ok(gender and type(callbacks["game.ready"]) == "function",
  "Battle Art gender bridge registers the game-ready lifecycle")
ok(type(overlayHook) == "function",
  "Battle Art gender bridge registers one fallback overlay")

callbacks["game.ready"]({ game = {} })
local wrapper = renderer.hudTexture
ok(type(wrapper) == "function",
  "Battle Art HUD texture receives one KASC gender wrapper")
callbacks["game.ready"]({ game = {} })
eq(renderer.hudTexture, wrapper,
  "Battle Art HUD gender wrapper is idempotent across game-ready refreshes")

local function mon(attack, species)
  return { species = species or "PIKACHU", dvs = { attack = attack } }
end
local battle = {
  game = { data = { pokemon = {
    PIKACHU = { dex = 25 }, MAGNEMITE = { dex = 81 },
  } } },
  enemy = { mon = mon(7) },
  player = { mon = mon(8) },
  -- A doubles-capable companion may publish these secondary slots. Battle
  -- Art 1.9.2 still owns one shared enemy/player HUD texture, so KASC must
  -- never draw the same two Crystal cells again for the partner metadata.
  doubleBattle = true,
  enemyPartner = { mon = mon(7) },
  playerPartner = { mon = mon(8) },
}
local shadow = { 0.1, 0.2, 0.3, 0.4 }
draws = {}
local layer = renderer.hudTexture(
  battle, 0, true, false, shadow, "future-tail")
eq(layer.id, "battle-art-1.9.2-hud",
  "Battle Art keeps ownership of the returned HUD texture")
eq(forwarded.n, 6,
  "Battle Art HUD wrapper forwards the complete current/future signature")
eq(forwarded[1], battle, "Battle Art HUD wrapper preserves battle identity")
eq(forwarded[3], true, "Battle Art HUD wrapper preserves DARK")
eq(forwarded[4], false, "Battle Art HUD wrapper preserves INVERTED")
eq(forwarded[5], shadow, "Battle Art HUD wrapper preserves COLOR shadow")
eq(forwarded[6], "future-tail",
  "Battle Art HUD wrapper preserves future tail arguments")
eq(#draws, 2,
  "doubles metadata cannot duplicate Battle Art's two shared gender cells")
eq(draws[1].text, "♀", "enemy gender derives from the primary battler")
eq(draws[1].x, 72, "enemy gender occupies one Crystal HUD anchor")
eq(draws[1].y, 8, "enemy gender retains the Crystal HUD baseline")
eq(draws[2].text, "♂", "player gender derives from the primary battler")
eq(draws[2].x, 104, "player gender occupies one Crystal HUD anchor")
eq(draws[2].y, 64, "player gender retains the Crystal HUD baseline")

draws = {}
battle.enemy.mon = mon(0, "MAGNEMITE")
renderer.hudTexture(battle, 0, false, false, shadow)
eq(#draws, 1, "genderless primary battler leaves its HUD cell empty")
eq(draws[1].text, "♂",
  "genderless enemy does not disturb the player's primary glyph")
battle.enemy.mon = mon(7)

draws = {}
context = nil
eq(overlayHook(function() return "native" end, battle), "native",
  "unsnapped Metal fallback preserves the native overlay result")
eq(#draws, 2,
  "unsnapped active 3D fallback draws exactly one primary glyph per side")

draws = {}
context = {
  schema = "ka-renderer-battle-hud-context/v1",
  shot = { id = "battle-art-wide-shot" },
}
battle.dramaticShapeShot = context.shot
overlayHook(function() return "native" end, battle)
eq(#draws, 0,
  "validated Battle Art snap suppresses a second native gender pair")

print(("battle_art_192_gender_hud_test: PASS (%d checks)"):format(checks))
