-- Regression for 6.7 Ascendant rewards promised while the Bag is full.
-- Two independently completed rewards must survive save/reload and be
-- delivered by Oak's aide in the original completion order. Pre-6.7 scalar
-- pendingReward saves migrate into the same FIFO without duplication.

local source = debug.getinfo(1, "S").source:sub(2)
local root = os.getenv("TRAINER_REMATCH_MOD_DIR")
  or source:match("^(.*)/tests/") or "."

local bagAccept = false
local delivered = {}
package.loaded["src.inventory.Bag"] = nil
package.preload["src.inventory.Bag"] = function()
  return {
    add = function(_, item)
      if not bagAccept then return false end
      delivered[#delivered + 1] = item
      return true
    end,
  }
end
package.loaded["src.render.TextBox"] = nil
package.preload["src.render.TextBox"] = function()
  return { new = function(_, text, done) return { text=text, done=done } end }
end

local function controller(saved)
  local mod = {
    id = "kanto_ascendant",
    save = {
      get = function(_, key) return saved[key] end,
      set = function(_, key, value) saved[key] = value end,
    },
    options = { get = function() return false end },
    hooks = { wrap = function() end },
    events = { on = function() end },
    ui = { insertBefore = function(items) return items end },
  }
  local postgameState = {
    apexChampion = true, crownChampion = false,
    masterWins = { brock=true, misty=true }, crownWins = {},
  }
  local postgame = {
    state = function() return postgameState end,
    hasHallOfFame = function() return true end,
    allMaster = function() return false end,
    caught = function() return false end,
    legendSetting = function() return "off" end,
    events = {
      enabledLegendCount = function() return 0 end,
      caughtLegendCount = function() return 0 end,
      researchLog = function() return nil end,
    },
  }
  local baseData = {
    gyms = {
      { key="brock", map="PEWTER_GYM", class="OPP_BROCK" },
      { key="misty", map="CERULEAN_GYM", class="OPP_MISTY" },
    },
    legendOrder = {},
  }
  local function quest(reward)
    return {
      target=1, reward=reward,
      intro={en="INTRO",de="INTRO"},
      landmark={en="GYM",de="ARENA"},
      hint={en="HINT",de="TIPP"},
      progress={en="PROGRESS %d",de="FORTSCHRITT %d"},
      complete={en="COMPLETE",de="FERTIG"},
    }
  end
  local data = {
    ranks = { { threshold=0, title={en="ROOKIE",de="NEULING"} } },
    research = {}, achievements = {}, rocket = {},
    gymQuests = { brock=quest("PP_UP"), misty=quest("MAX_REVIVE") },
    tournament = { name="TOURNAMENT_HOST", rules={}, opponents={} },
    newGamePlus = { name="NGPLUS_HOST" },
    mew = { name="MEW_HOST", clues={} },
    world = {}, worldMoments = {},
  }
  return assert(loadfile(root .. "/ascendant.lua"))()(mod, baseData, {
    data=data, postgame=postgame,
  })
end

local function game()
  return {
    save = { player={name="RED"}, inventory={}, party={} },
    data = { items = {
      PP_UP={name="PP UP"}, MAX_REVIVE={name="MAX REVIVE"},
      RARE_CANDY={name="RARE CANDY"},
    }, pokemon={} },
    stack = { pushed={}, push=function(self, value)
      self.pushed[#self.pushed + 1] = value
    end },
  }
end
local function npc(name, class)
  return { frozen=false, def={name=name,trainerClass=class},
    facePlayer=function() end }
end
local function talk(api, currentGame, map, currentNpc)
  return api.handleTalk({map={id=map},player={}}, currentNpc, currentGame)
end

local saved = {
  ascendant = {
    research={completed={}}, gymQuests={
      brock={active=true,progress=1,done=false},
      misty={active=true,progress=1,done=false},
    },
    achievements={}, metrics={}, bossBattles={},
    tournament={runs=0,wins=0,best=0}, frontierPoints=0,
    typeMastery={}, rocketStage=0, mewStage=0, cycle=0,
  },
}
local api = controller(saved)
local firstGame = game()
assert(talk(api, firstGame, "PEWTER_GYM", npc("BROCK", "OPP_BROCK")))
assert(talk(api, firstGame, "CERULEAN_GYM", npc("MISTY", "OPP_MISTY")))
local queue = saved.ascendant.pendingRewards
assert(type(queue) == "table" and #queue == 2,
  "two full-Bag completions did not preserve two pending rewards")
assert(queue[1] == "PP_UP" and queue[2] == "MAX_REVIVE",
  "pending rewards did not retain completion order")
assert(saved.ascendant.pendingReward == nil,
  "new rewards still use the overwrite-prone scalar")

-- Recreate the controller to model a save/reload boundary, then claim in FIFO
-- order from the one existing delivery authority: Oak's lab aide.
bagAccept = true
api = controller(saved)
local reloadedGame = game()
local aide = npc("OAKSLAB_SCIENTIST1", "OPP_SCIENTIST")
assert(talk(api, reloadedGame, "OAKS_LAB", aide))
assert(#delivered == 1 and delivered[1] == "PP_UP",
  "first pending reward was not delivered first after reload")
assert(#saved.ascendant.pendingRewards == 1
    and saved.ascendant.pendingRewards[1] == "MAX_REVIVE",
  "first delivery did not retain the second pending reward")
assert(talk(api, reloadedGame, "OAKS_LAB", aide))
assert(#delivered == 2 and delivered[2] == "MAX_REVIVE",
  "second pending reward was not delivered second")
assert(#saved.ascendant.pendingRewards == 0,
  "FIFO was not empty after both deliveries")

-- A legacy scalar is older than any queue entry and migrates to the front
-- exactly once, even if state normalization runs repeatedly.
local legacySaved = { ascendant = {
  research={completed={}}, gymQuests={}, achievements={}, metrics={},
  bossBattles={}, tournament={runs=0,wins=0,best=0}, frontierPoints=0,
  typeMastery={}, rocketStage=0, mewStage=0, cycle=0,
  pendingReward="RARE_CANDY", pendingRewards={"PP_UP"},
} }
local legacy = controller(legacySaved)
local migrated = legacy.state()
assert(migrated.pendingReward == nil,
  "legacy pendingReward scalar was not retired")
assert(#migrated.pendingRewards == 2
    and migrated.pendingRewards[1] == "RARE_CANDY"
    and migrated.pendingRewards[2] == "PP_UP",
  "legacy scalar was not migrated ahead of the newer FIFO")
migrated = legacy.state()
assert(#migrated.pendingRewards == 2,
  "legacy scalar migration duplicated a reward on normalization")

print("ascendant pending rewards FIFO 6.7 test passed")
