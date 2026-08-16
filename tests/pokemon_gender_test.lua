-- Phase-6 Gen-II Pokémon gender contract.

package.path = "./?.lua;./?/init.lua;" .. package.path

local T = require("tests.modkit")
local Pokemon = require("src.pokemon.Pokemon")
local Data = T.fixtures.load()
local modPath = os.getenv("TRAINER_REMATCH_MOD_DIR") or "mods/kanto_ascendant"
local run = T.sdk.loadMod(modPath, { data = Data })
T.eq(#run.errors, 0, "Kanto Ascendant loads with the central gender API")

local gender = assert(run.loader.exports.kanto_ascendant.pokemonGender)
T.eq(gender.MALE, "MALE", "gender API exposes a stable male enum")
T.eq(gender.FEMALE, "FEMALE", "gender API exposes a stable female enum")
T.eq(gender.GENDERLESS, "GENDERLESS", "gender API exposes a stable genderless enum")

-- The engine fixture intentionally contains only the battle-relevant base
-- subset. Use real canonical dex numbers for all seven Gen-II rate classes
-- so the data table itself, not fixture coverage, is under test.
local RATIO_DEX = { [-1] = 81, [0] = 32, [1] = 1, [2] = 58,
                    [4] = 25, [6] = 35, [8] = 29 }
local genderData = { pokemon = {} }
for ratio, dex in pairs(RATIO_DEX) do
  genderData.pokemon["RATIO_" .. tostring(ratio)] = { dex = dex }
end
local function speciesForRatio(ratio) return "RATIO_" .. tostring(ratio) end

local function mon(species, attack)
  return { species = species, dvs = { attack = attack, defense = 7, speed = 9, special = 3 } }
end

for _, ratio in ipairs({ 1, 2, 4, 6 }) do
  local species = speciesForRatio(ratio)
  local edge = ratio * 2
  T.eq(gender.getMonGender(mon(species, edge - 1), genderData), gender.FEMALE,
    "ratio " .. ratio .. " is female immediately below its Gen-II Attack-DV boundary")
  T.eq(gender.getMonGender(mon(species, edge), genderData), gender.MALE,
    "ratio " .. ratio .. " is male at its Gen-II Attack-DV boundary")
end

local maleOnly = speciesForRatio(0)
local femaleOnly = speciesForRatio(8)
local genderless = speciesForRatio(-1)
T.eq(gender.getMonGender(mon(maleOnly, 0), genderData), gender.MALE,
  "0/8 ratio is always male")
T.eq(gender.getMonGender(mon(maleOnly, 15), genderData), gender.MALE,
  "0/8 ratio ignores high Attack DV")
T.eq(gender.getMonGender(mon(femaleOnly, 0), genderData), gender.FEMALE,
  "8/8 ratio is always female")
T.eq(gender.getMonGender(mon(femaleOnly, 15), genderData), gender.FEMALE,
  "8/8 ratio ignores high Attack DV")
T.eq(gender.getMonGender(mon(genderless, 0), genderData), gender.GENDERLESS,
  "genderless species never receive a sex symbol")

local oldParty = mon(speciesForRatio(4), 7)
local oldBoxed = mon(speciesForRatio(4), 8)
local legacySave = { party = { oldParty }, boxes = { { oldBoxed } } }
T.eq(gender.getMonGender(legacySave.party[1], genderData), gender.FEMALE,
  "old party Pokémon derive their gender from existing DVs")
T.eq(gender.getMonGender(legacySave.boxes[1][1], genderData), gender.MALE,
  "old boxed Pokémon derive their gender from existing DVs")
T.eq(oldParty.gender, nil, "party inspection does not write a gender migration field")
T.eq(oldBoxed.gender, nil, "box inspection does not write a gender migration field")

local generatedData = { pokemon = {}, moves = Data.moves }
for id, def in pairs(Data.pokemon) do generatedData.pokemon[id] = def end
local generatedDef = {}
for key, value in pairs(Data.pokemon.FIXMON_A) do generatedDef[key] = value end
generatedDef.dex = 25 -- canonical Pikachu rate, on a complete fixture shape
local wildSpecies = "GENDER_SOURCE"
generatedData.pokemon[wildSpecies] = generatedDef
T.eq(gender.getGenderRatio({ species = wildSpecies }, generatedData), 4,
  "generated-source fixture carries the canonical 50/50 gender rate")
local wild = Pokemon.new(generatedData, wildSpecies, 5, function() return 0 end)
T.eq(gender.getMonGender(wild, generatedData), gender.FEMALE,
  "a deterministically generated wild Pokémon uses its generated Attack DV")
local gift = Pokemon.new(generatedData, wildSpecies, 5, function() return 15 end)
T.eq(gender.getMonGender(gift, generatedData), gender.MALE,
  "a deterministically generated gift/static Pokémon uses the same API")
local trainer = mon(wildSpecies, 8)
T.eq(gender.getMonGender(trainer, generatedData), gender.MALE,
  "trainer Pokémon with DVs use the same central calculation")

local info = gender.inspect(mon(speciesForRatio(4), 7), genderData)
T.eq(info.genderRatio, 4, "development inspection exposes the species ratio")
T.eq(info.attackDv, 7, "development inspection exposes the existing Attack DV")
T.eq(info.gender, gender.FEMALE, "development inspection exposes the derived gender")
T.eq(gender.symbol(mon(speciesForRatio(4), 7), genderData), "♀", "female UI symbol is Gen-II style")
T.eq(gender.symbol(mon(genderless, 7), genderData), nil,
  "genderless UI leaves the symbol blank")

local Font = require("src.render.Font")
local originalDraw = Font.draw
local draws = {}
Font.draw = function(text, x, y)
  draws[#draws + 1] = { text = text, x = x, y = y }
end
local battle = {
  game = { data = genderData }, introSlide = 0,
  enemy = { mon = mon(speciesForRatio(4), 7), name = "FEMALE" },
  player = { mon = mon(speciesForRatio(4), 8), name = "MALE" },
}
gender.drawBattleHUD(battle, 0)
T.eq(draws[1].text, "♀", "enemy battle HUD displays the derived female symbol")
T.eq(draws[1].x, 72, "enemy battle gender uses the Crystal HUD cell")
T.eq(draws[2].text, "♂", "player battle HUD displays the derived male symbol")
T.eq(draws[2].x, 104,
  "player battle gender has a cell independent of status and level 100")

draws = {}
battle.player.mon.level = 100
battle.player.shownStatus = "PSN"
gender.drawBattleHUD(battle, 0)
T.eq(draws[2].x, 104,
  "player status and level-100 layouts cannot overwrite gender")

draws = {}
battle.enemy.mon = mon(speciesForRatio(8), 15)
battle.enemy.name = "NIDORAN♀"
battle.player.mon = mon(speciesForRatio(0), 0)
battle.player.name = "NIDORAN♂"
gender.drawBattleHUD(battle, 0)
Font.draw = originalDraw
T.eq(draws[1].text, "♀",
  "female-only Nidoran keeps Crystal's dedicated battle gender cell")
T.eq(draws[2].text, "♂",
  "male-only Nidoran keeps Crystal's dedicated battle gender cell")

-- Exact Battle Art 1.9.2 HUD contract: preserve every renderer option
-- argument and suppress the native glyph only for a validated successful snap
-- of this exact shot. iOS and snap failures retain dramaticShapeShot but must
-- still receive the in-frame fallback glyphs.
local rendererEvents, overlayHook = {}, nil
local forwarded
local rendererHud = {
  hudTexture = function(...)
    forwarded = { n = select("#", ...), ... }
    return { id = "battle-art-hud-layer" }
  end,
}
local contextResult
local rendererGender = assert(loadfile(modPath .. "/pokemon_gender.lua"))()({
  exports = {},
  events = {
    once = function() end,
    on = function(_, name, callback) rendererEvents[name] = callback end,
  },
  hooks = {
    wrap = function(_, name, callback)
      if name == "battle.overlay" then overlayHook = callback end
    end,
  },
}, {
  breedingData = { [25] = { gender = 4 } },
  voxelRenderer = {
    module = function(_, name)
      T.eq(name, "OverworldBattle",
        "gender bridge requests only the renderer HUD module")
      return rendererHud
    end,
  },
  rendererBattleHud = {
    contextSchema = "ka-renderer-battle-hud-context/v1",
    context = function() return contextResult end,
  },
})
T.check(rendererGender ~= nil and rendererEvents["game.ready"] ~= nil,
  "renderer gender bridge registers its game-ready installer")
rendererEvents["game.ready"]({ game = {} })

local savedGraphics = {}
for _, key in ipairs({ "getCanvas", "setCanvas", "getBlendMode",
                        "setBlendMode", "getColor", "setColor" }) do
  savedGraphics[key] = love.graphics[key]
end
love.graphics.getCanvas = function() return nil end
love.graphics.setCanvas = function() end
love.graphics.getBlendMode = function() return "alpha", "alphamultiply" end
love.graphics.setBlendMode = function() end
love.graphics.getColor = function() return 1, 1, 1, 1 end
love.graphics.setColor = function() end

local rendererBattle = {
  game = { data = { pokemon = { PIKACHU = { dex = 25 } } } },
  enemy = { mon = { species = "PIKACHU", dvs = { attack = 7 } } },
  player = { mon = { species = "PIKACHU", dvs = { attack = 8 } } },
}
local colorShadow = { 0.1, 0.2, 0.3, 0.4 }
rendererHud.hudTexture(rendererBattle, 0, true, false, colorShadow,
  "future-tail")
T.eq(forwarded.n, 6,
  "Battle Art HUD wrapper forwards the complete current/future signature")
T.eq(forwarded[1], rendererBattle, "HUD wrapper forwards battle identity")
T.eq(forwarded[2], 0, "HUD wrapper forwards slide")
T.eq(forwarded[3], true, "HUD wrapper forwards DARK option")
T.eq(forwarded[4], false, "HUD wrapper forwards INVERTED option")
T.eq(forwarded[5], colorShadow, "HUD wrapper forwards COLOR shadow table")
T.eq(forwarded[6], "future-tail", "HUD wrapper forwards future arguments")

-- Battle Art exposes one classic enemy/player HUD texture. A doubles-capable
-- companion can carry secondary battlers, but those must not be drawn into
-- the same two Crystal cells a second time.
local doubleTextureDraws = {}
Font.draw = function(text, x, y)
  doubleTextureDraws[#doubleTextureDraws + 1] = {
    text = text, x = x, y = y,
  }
end
rendererBattle.doubleBattle = true
rendererBattle.enemyPartner = {
  mon = { species = "PIKACHU", dvs = { attack = 7 } },
}
rendererBattle.playerPartner = {
  mon = { species = "PIKACHU", dvs = { attack = 8 } },
}
rendererHud.hudTexture(rendererBattle, 0, false, false, colorShadow)
T.eq(#doubleTextureDraws, 2,
  "Battle Art doubles metadata cannot duplicate the two shared gender cells")
T.eq(doubleTextureDraws[1].x, 72,
  "Battle Art doubles retain one enemy gender anchor")
T.eq(doubleTextureDraws[2].x, 104,
  "Battle Art doubles retain one player gender anchor")

local overlayDraws = {}
Font.draw = function(text, x, y)
  overlayDraws[#overlayDraws + 1] = { text = text, x = x, y = y }
end
local shot = { id = "same-shot" }
rendererBattle.dramaticShapeShot = shot
contextResult = nil
overlayHook(function() return "native" end, rendererBattle)
T.eq(#overlayDraws, 2,
  "Battle Art iOS/snap failure keeps both native gender glyphs")

overlayDraws = {}
contextResult = {
  schema = "ka-renderer-battle-hud-context/v1", shot = shot,
}
overlayHook(function() return "native" end, rendererBattle)
T.eq(#overlayDraws, 0,
  "validated current-shot snap suppresses duplicate native gender glyphs")

overlayDraws = {}
rendererBattle.dramaticShapeShot = nil
rendererBattle.voxelAscendantShot = { id = "vasc-shot" }
contextResult = {
  schema = "ka-renderer-battle-hud-context/v1",
  shot = rendererBattle.voxelAscendantShot,
}
overlayHook(function() return "native" end, rendererBattle)
T.eq(#overlayDraws, 0,
  "validated Voxel Ascendant snap also suppresses duplicate native glyphs")

Font.draw = originalDraw
for key, value in pairs(savedGraphics) do love.graphics[key] = value end

T.finish("pokemon_gender_test")
