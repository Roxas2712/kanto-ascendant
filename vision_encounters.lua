-- Rare, once-per-save scripted Ho-Oh vision. Its identity stays unknown, no
-- party member is sent out and the queue ends before a battle command opens.

return function(mod, opts)
  opts = opts or {}
  local crystalAnimation = opts.crystalAnimation
  local i18n = opts.i18n
  local V = { active = nil, game = nil, STATE_VERSION = 2 }
  V.DEFS = {
    {
      key = "ho_oh", species = "HO_OH", level = 70, chance = 0.01,
      -- The anime-style glimpse belongs in Route 2's grass before the
      -- Viridian Forest entrance, never inside the forest or either gate.
      maps = { ROUTE_2 = true }, grassOnly = true,
      -- Route 2 is one 20x72 map containing land on both sides of the
      -- forest. These are the four southern grass rows between Viridian City
      -- and VIRIDIAN_FOREST_SOUTH_GATE; the northern Route-2 grass is out.
      area = { minX = 4, maxX = 9, minY = 48, maxY = 51 },
      mystery = true, direct = true, music = "Music_Dungeon1",
    },
  }
  local function tr(en, de)
    return i18n and i18n.text and i18n.text(en, de) or en
  end

  -- A deliberately small battle-state program preserves the real battle
  -- renderer (including Voxel and Crystal animation) without invoking any
  -- combat mechanics. It is installed on this one instance only, so ordinary
  -- wild battles and the later catchable Ho-Oh never see these rules.
  function V.enterMystery(battle, def)
    local Music = require("src.core.Music")
    local Sound = require("src.core.Sound")
    local Runtime = require("src.mods.Runtime")
    battle.musicKind = "vision"
    battle.introSlide = 0
    battle.introBalls = nil
    battle.showEnemyTrainer = false
    battle.showPlayerBack = false
    battle.enemySendingOut = false
    battle.sendingOut = false
    -- Reuse the engine's presentation-only hiding rules. The phase never
    -- reaches menu, so the Old-Man demo input path cannot run.
    battle.demo = true
    battle.demoName = "???"
    battle.queue = {}
    if def.music then
      Music.play(battle.data, def.music, true, { reason = "vision" })
    end
    battle:say(tr("A golden shadow\nappeared!",
      "Ein goldener\nSchatten erscheint!"))
    battle:act(function()
      -- ROAR's tempo modifier stretches the species cry into an unfamiliar
      -- call without adding a new audio asset.
      Sound.playMoveCry(battle.data, def.species, 0x40)
    end)
    battle:say(tr("A strange melody\nechoed...",
      "Eine fremde Melodie\nerklingt..."))
    battle:act(function() battle.enemyHidden = true end)
    battle:say(tr("The golden vision\nvanished.",
      "Die goldene Vision\nverschwindet."))
    battle:act(function() battle.result = "run" end)
    battle.phase = "messages"
    battle.afterQueue = "finish"
    battle:syncSides()
    Runtime.emit("battle.started", {
      battle = battle, kind = "vision", species = "???", level = "???",
    })
  end

  local function clone(value)
    if type(value) ~= "table" then return value end
    local out = {}
    for key, child in pairs(value) do out[key] = clone(child) end
    return out
  end
  local function root()
    local state = mod.save:get("vision_encounters")
    if type(state) ~= "table" then state = {} end
    state.version = V.STATE_VERSION
    state.ho_oh = state.ho_oh == true
    state.lugia = nil
    mod.save:set("vision_encounters", state)
    return state
  end
  function V.eligible(def, mapId, roll)
    return mod.options:get("vision_encounters") ~= false
      and def.maps[mapId] == true and root()[def.key] ~= true
      and tonumber(roll) < def.chance
  end
  function V.eligibleStep(game, def, ev, roll)
    if not (ev and V.eligible(def, ev.mapId, roll)) then return false end
    local area = def.area
    if area and (ev.x < area.minX or ev.x > area.maxX
        or ev.y < area.minY or ev.y > area.maxY) then
      return false
    end
    if not def.grassOnly then return true end
    local map = game and game.overworld and game.overworld.map
    return map and map.id == ev.mapId and type(map.isGrassCell) == "function"
      and map:isGrassCell(ev.x, ev.y) or false
  end

  function V.finish(game, battle, result)
    if game and battle and battle.visionPartySnapshot then
      game.save.party = clone(battle.visionPartySnapshot)
    end
    V.active = nil
    -- Ho-Oh always supplies "run" and returns to the same field cell without
    -- a blackout. Regular mythical battles use mythic_safety.lua instead.
    local overworld = game and game.overworld
    if overworld and type(overworld.afterBattle) == "function" then
      overworld:afterBattle(result or "run", battle)
    end
  end
  function V.start(game, def)
    if V.active or not (game and game.overworld) then return false end
    local state = root()
    if state[def.key] then return false end
    state[def.key] = true; mod.save:set("vision_encounters", state)
    local BattleState = require("src.battle.BattleState")
    local dex = game.save.pokedex
    local wasSeen = dex and dex.seen and dex.seen[def.species] or nil
    local battle = BattleState.newWild(game, def.species, def.level,
      { scriptedEncounter = "ASCENDANT_VISION_" .. def.key:upper() })
    battle.ascendantVision = def.key
    battle.noCatch = true
    if def.key == "ho_oh" and battle.enemy and crystalAnimation
        and type(crystalAnimation.tintVisionGold) == "function" then
      battle.enemy.sprite = crystalAnimation.tintVisionGold(battle.enemy.sprite)
      battle.enemy.__ascendantVisionGold = true
    end
    battle.visionPartySnapshot = clone(game.save.party)
    battle.onFinish = function(result) V.finish(game, battle, result) end
    if def.mystery and battle.enemy then
      -- newWild marks every constructed species as seen. A vision that does
      -- not reveal its name must not spoil the Pokédex entry either.
      if dex and dex.seen then dex.seen[def.species] = wasSeen end
      battle.visionRealSpecies = def.species
      battle.visionRealLevel = def.level
      battle.enemy.name = "???"
      battle.enemy.mon.level = "???"
      battle.introText = tr("A golden shadow\nappeared!",
        "Ein goldener\nSchatten erscheint!")
      battle.enter = function(self) return V.enterMystery(self, def) end
    end
    V.active = battle
    if def.direct and game.stack and type(game.stack.push) == "function" then
      game.stack:push(battle)
    else
      game.overworld:pushBattle(battle)
    end
    return true
  end
  mod.events:on("game.ready", function(ev) V.game = ev and ev.game end)
  mod.events:on("world.stepped", function(ev)
    local game = V.game
    if V.active or not (game and game.stack and game.stack:top() == game.overworld) then return end
    local random = love and love.math and love.math.random or math.random
    for _, def in ipairs(V.DEFS) do
      if def.maps[ev.mapId] and V.eligibleStep(game, def, ev, random()) then
        V.start(game, def); return
      end
    end
  end, 5000)
  -- A vision starts during world.stepped, before the same physical step can
  -- roll a normal encounter.  Suppress that one competing candidate.
  mod.hooks:wrap("encounter.species", function(nextEncounter, enc, ctx)
    if V.active then return nil end
    return nextEncounter(enc, ctx)
  end, 5000)
  mod.hooks:wrap("battle.exp_award", function(nextAward, ctx)
    if ctx and ctx.battle and ctx.battle.ascendantVision then return end
    return nextAward(ctx)
  end, 5000)
  mod.events:on("battle.ended", function(ev)
    local battle = ev and ev.battle
    if not (battle and battle.ascendantVision) then return end
    if V.game and battle.visionPartySnapshot then
      V.game.save.party = clone(battle.visionPartySnapshot)
    end
    V.active = nil
  end, 5000)
  return V
end
