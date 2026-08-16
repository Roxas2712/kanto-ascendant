package.path = "./?.lua;./?/init.lua;" .. package.path

local S = require("tests.harness").suite("mythic Nuzlocke safety")
local check, eq = S.check, S.eq
local modDir = assert(os.getenv("TRAINER_REMATCH_MOD_DIR"))
local listeners = {}
local mod = {
  events = { on = function(_, name, fn, priority)
    listeners[name] = listeners[name] or {}
    listeners[name][#listeners[name] + 1] = {
      fn = fn, priority = priority or 0,
    }
  end },
}

-- This fake is the bundled Nuzlocke wrapper's relevant behavior: ordinary
-- faints remove the mon and a wipe becomes nuzlocke_game_over; demo battles
-- fall through to the engine's normal faint/blackout path.
local BattleState = {
  onFaint = function(self, battler)
    if self.demo then
      self.vanillaFaints = (self.vanillaFaints or 0) + 1
      battler.faintQueued = true
      return
    end
    for i, mon in ipairs(self.game.save.party) do
      if mon == battler.mon then table.remove(self.game.save.party, i) break end
    end
    self.nuzlockeDeaths = (self.nuzlockeDeaths or 0) + 1
  end,
  playerMonFainted = function(self)
    if self.demo then
      self.result, self.afterQueue = "lose", "finish"
    else
      self.nuzlockeGameOver = true
      self.result, self.afterQueue = "nuzlocke_game_over", "finish"
    end
  end,
}
package.loaded["src.battle.BattleState"] = BattleState

local safety
local OverworldState = {
  afterBattle = function(self, result, current)
    self.returns = (self.returns or 0) + 1
    self.protectedDuringReturn = safety.isProtectedReturn(current.game.save)
    self.lastResult = result
    return "authored_return"
  end,
}
package.loaded["src.world.OverworldController"] = OverworldState

safety = assert(loadfile(modDir .. "/mythic_safety.lua"))()(mod)
local function emit(name, payload)
  local rows = listeners[name] or {}
  table.sort(rows, function(a, b) return a.priority > b.priority end)
  for _, row in ipairs(rows) do row.fn(payload) end
end
local function battle(species, tag, value)
  local mon = { species = species, hp = 1 }
  local out = {
    enemy = { mon = { species = species } },
    player = { isPlayer = true, mon = mon },
    game = { save = { party = { mon } } },
  }
  if tag then out[tag] = value or species end
  return out
end

local lugia = battle("LUGIA", "postgameLegend")
emit("battle.started", { battle = lugia })
eq(lugia.ascendantMythicProtected, nil, "Lugia is outside the exception")

for _, species in ipairs({ "MEW", "CELEBI" }) do
  local ordinary = battle(species)
  emit("battle.started", { battle = ordinary })
  eq(ordinary.ascendantMythicProtected, nil,
    "an unrelated " .. species .. " battle is not claimed")
end

local hooh = battle("HO_OH", "postgameLegend")
emit("battle.started", { battle = hooh })
eq(hooh.ascendantMythicProtected, "postgame_legend",
  "regular Ascendant Ho-Oh is protected")
BattleState.onFaint(hooh, hooh.player)
eq(#hooh.game.save.party, 1, "Ho-Oh defeat does not delete the party mon")
eq(hooh.vanillaFaints, 1, "Ho-Oh uses the normal faint path")
eq(hooh.demo, nil, "temporary Nuzlocke exemption does not leak")
BattleState.playerMonFainted(hooh)
eq(hooh.result, "lose", "Ho-Oh wipe becomes a normal blackout")
eq(hooh.nuzlockeGameOver, nil, "Ho-Oh wipe cannot end the Nuzlocke save")
local hoohWorld = {}
eq(OverworldState.afterBattle(hoohWorld, "lose", hooh), "authored_return",
  "protected loss still executes the authored overworld return")
eq(hoohWorld.protectedDuringReturn, true,
  "protected receipt exists during the exact synchronous return warp")
eq(safety.isProtectedReturn(hooh.game.save), false,
  "protected receipt cannot leak past the authored return")

for _, row in ipairs({
  { "CELEBI", "kaMythicTrue", "mythic_true" },
  { "MEW", "kaMythicEcho", "mythic_echo" },
  { "MEW", "ascendantMew", "ascendant_mew", true },
}) do
  local current = battle(row[1], row[2], row[4] or row[1])
  emit("battle.started", { battle = current })
  eq(current.ascendantMythicProtected, row[3],
    row[1] .. " source is classified")
  BattleState.onFaint(current, current.player)
  BattleState.playerMonFainted(current)
  eq(#current.game.save.party, 1, row[1] .. " keeps the party mon")
  eq(current.result, "lose", row[1] .. " reaches normal blackout")
  eq(current.nuzlockeGameOver, nil, row[1] .. " does not end the save")
  local world = {}
  OverworldState.afterBattle(world, "lose", current)
  eq(world.protectedDuringReturn, true,
    row[1] .. " marks only its authored safe return")
  eq(safety.isProtectedReturn(current.game.save), false,
    row[1] .. " return marker clears immediately")
end

BattleState.onFaint(lugia, lugia.player)
eq(#lugia.game.save.party, 0,
  "unprotected Lugia still follows the selected Nuzlocke rules")
eq(lugia.nuzlockeDeaths, 1, "the safety wrapper remains tightly scoped")
local lugiaWorld = {}
OverworldState.afterBattle(lugiaWorld, "lose", lugia)
eq(lugiaWorld.protectedDuringReturn, false,
  "ordinary Legendary loss cannot borrow a Mythic exemption")
check(BattleState._kantoAscendantMythicSafety == true,
  "runtime guard is installed only once")

S.finish()
