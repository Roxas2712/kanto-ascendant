package.path = "./?.lua;./?/init.lua;" .. package.path

local S = require("tests.harness").suite("vision encounters")
local check, eq = S.check, S.eq
local modDir = assert(os.getenv("TRAINER_REMATCH_MOD_DIR"))

local values, saves = { vision_encounters = true }, {}
local eventHandlers, hookHandlers = {}, {}
local mod = {
  options = { get = function(_, key) return values[key] end },
  save = {
    get = function(_, key) return saves[key] end,
    set = function(_, key, value) saves[key] = value end,
  },
  events = { on = function(_, key, fn) eventHandlers[key] = fn end },
  hooks = { wrap = function(_, key, fn) hookHandlers[key] = fn end },
}

local fakeBattleState = {
  newWild = function(game, species, level)
    if game.save.pokedex then game.save.pokedex.seen[species] = true end
    local battle = {
      game = game, enemy = { mon = { species = species, level = level },
        sprite = "normal-" .. species }, data = game.data or {}, queue = {},
    }
    function battle:say(text) self.queue[#self.queue + 1] = { text = text } end
    function battle:act(fn) self.queue[#self.queue + 1] = { fn = fn } end
    function battle:syncSides() self.sidesSynced = true end
    return battle
  end,
}
package.loaded["src.battle.BattleState"] = fakeBattleState

local musicPlayed, cryPlayed, emitted
package.loaded["src.core.Music"] = {
  play = function(_, song, loop, ctx)
    musicPlayed = { song = song, loop = loop, reason = ctx and ctx.reason }
  end,
}
package.loaded["src.core.Sound"] = {
  playMoveCry = function(_, species, tempo)
    cryPlayed = { species = species, tempo = tempo }
  end,
}
package.loaded["src.mods.Runtime"] = {
  emit = function(name, payload) emitted = { name = name, payload = payload } end,
}

local tinted
local vision = assert(loadfile(modDir .. "/vision_encounters.lua"))()(mod, {
  i18n = { text = function(_, de) return de end },
  crystalAnimation = {
    tintVisionGold = function(image)
      tinted = image
      return "gold-ho-oh"
    end,
  },
})

local grass = true
local afterResult, afterBattle
local game = {
  data = {},
  save = {
    party = { { species = "PIKACHU", hp = 20 } },
    pokedex = { seen = {}, owned = {} },
  },
  stack = {
    push = function(self, battle)
      self.pushed = battle
      if battle.enter then battle:enter() end
    end,
  },
  overworld = {
    map = {
      id = "ROUTE_2",
      isGrassCell = function() return grass end,
    },
    pushBattle = function(self, battle) self.pushed = battle end,
    afterBattle = function(_, result, battle)
      afterResult, afterBattle = result, battle
    end,
  },
}

check(vision.eligibleStep(game, vision.DEFS[1],
  { mapId = "ROUTE_2", x = 4, y = 48 }, 0.009),
  "Ho-Oh has a one-percent roll in Route 2 grass")
grass = false
check(not vision.eligibleStep(game, vision.DEFS[1],
  { mapId = "ROUTE_2", x = 4, y = 48 }, 0),
  "Ho-Oh cannot start on Route 2 pavement")
grass = true
check(not vision.eligibleStep(game, vision.DEFS[1],
  { mapId = "ROUTE_2", x = 4, y = 2 }, 0),
  "Ho-Oh cannot start in Route 2 grass north of the forest")
check(not vision.eligibleStep(game, vision.DEFS[1],
  { mapId = "VIRIDIAN_FOREST", x = 4, y = 48 }, 0),
  "Ho-Oh cannot start inside Viridian Forest")

check(vision.start(game, vision.DEFS[1]), "Ho-Oh vision starts")
local battle = game.stack.pushed
eq(game.overworld.pushed, nil, "Ho-Oh appears directly without a battle transition")
eq(tinted, "normal-HO_OH", "vision gold is derived from the resolved live sprite")
eq(battle.enemy.sprite, "gold-ho-oh", "only the vision Ho-Oh is gold")
eq(battle.noCatch, true, "vision remains non-catchable")
eq(battle.enemy.name, "???", "Ho-Oh's identity stays hidden in the HUD")
eq(battle.enemy.mon.level, "???", "Ho-Oh's level stays hidden in the HUD")
eq(battle.visionRealSpecies, "HO_OH", "script retains the real private species")
eq(battle.visionRealLevel, 70, "script retains the real private level")
eq(game.save.pokedex.seen.HO_OH, nil,
  "the unnamed vision does not reveal Ho-Oh in the Pokedex")
eq(battle.phase, "messages", "the scripted vision starts in its text queue")
eq(battle.afterQueue, "finish", "the queue ends the scene before any menu")
eq(#battle.queue, 6, "the mystery scene owns three messages and three actions")
check(battle.queue[1].text:find("goldener", 1, true) ~= nil,
  "the vision opening is localized")
eq(musicPlayed.song, "Music_Dungeon1", "the vision selects its eerie music")
eq(musicPlayed.reason, "vision", "the music is scoped to the vision")
eq(emitted.payload.kind, "vision", "battle observers see a vision, not a wild fight")
eq(emitted.payload.species, "???", "battle observers do not leak the species")
eq(emitted.payload.level, "???", "battle observers do not leak the level")

battle.queue[2].fn()
eq(cryPlayed.species, "HO_OH", "the strange call uses Ho-Oh's private cry")
eq(cryPlayed.tempo, 0x40, "the private cry is deliberately distorted")
battle.queue[4].fn()
eq(battle.enemyHidden, true, "Ho-Oh vanishes before the final line")
battle.queue[6].fn()
eq(battle.result, "run", "the vision resolves without a combat result")

game.save.party[1].hp = 0
battle.onFinish("run")
eq(game.save.party[1].hp, 20, "vision teardown restores the pre-fight party")
eq(afterResult, "run", "Ho-Oh returns directly to the field")
eq(afterBattle, battle, "field return receives the actual vision scene")
eq(vision.active, nil, "vision state clears before returning to the field")

eq(#vision.DEFS, 1, "Lugia has no vision definition")
saves.vision_encounters.lugia = true
vision.eligible(vision.DEFS[1], "ROUTE_2", 1)
eq(saves.vision_encounters.lugia, nil,
  "old Lugia vision state is removed instead of replayed")

S.finish()
