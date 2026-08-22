-- Phase-5 persistence, PARTY/CUSTOM and Yellow-priority contract.

local root = os.getenv("TRAINER_REMATCH_MOD_DIR") or "."
local function factory(name) return assert(loadfile(root .. "/" .. name))() end

local function harness(bucket, optionValues)
  local listeners, partyHook = {}, nil
  local mod = {
    id = "kanto_ascendant",
    save = {
      get = function(_, key, default)
        local value = bucket[key]
        return value == nil and default or value
      end,
      set = function(_, key, value) bucket[key] = value end,
    },
    options = {
      get = function(_, key) return optionValues[key] end,
    },
    events = {
      on = function(_, name, fn) listeners[name] = fn end,
    },
    hooks = {
      wrap = function(_, name, fn)
        if name == "ui.party.submenu" then partyHook = fn end
      end,
    },
    ui = {
      ListMenu = {
        new = function(_, title, items, opts)
          local list = { title = title, items = items, opts = opts }
          function list:close() self.closed = true end
          return list
        end,
      },
    },
  }
  return mod, listeners, function() return partyHook end
end

local function mon(species, hp)
  return { species = species, hp = hp or 30, dvs = {} }
end

local bucket = {}
local optionValues = {
  follower_count = 1,
  follower_order = "party",
  yellow_partner_presentation = "ascendant_box",
  yellow_raichu_face_style = "ascendant",
}
local edition = "red"
local gameVersion = {
  get = function() return edition end,
  isYellow = function() return edition == "yellow" end,
}
local mod, listeners, partyHook = harness(bucket, optionValues)
local config = factory("follower_config.lua")(mod, { gameVersion = gameVersion })
local applied = 0
local controller = { applyConfig = function() applied = applied + 1 end }
local game = {
  save = {
    party = {}, boxes = {}, options = { modOptions = {} }, flags = {},
  },
  mods = { modOptions = {} },
  stack = { pushed = {}, push = function(self, value) self.pushed[#self.pushed + 1] = value end },
}
config.install(game, controller)
assert(config.count() == 1 and config.mode() == "party",
  "Phase-5 defaults changed")
assert(config.presentation() == "ascendant_box",
  "Yellow presentation default changed")
assert(config.raichuFaces() == "ascendant",
  "Raichu face default changed")

-- Central option storage is shared by the process, but migration is per save.
-- A legacy slot without Phase-5 state always receives 1/PARTY, never another
-- edition's last global choice.
local globalFour = {
  follower_count = 4, follower_order = "custom",
  yellow_partner_presentation = "yellow_center",
  yellow_raichu_face_style = "classic_yellow",
}
local legacyMod = harness({}, globalFour)
local legacyConfig = factory("follower_config.lua")(legacyMod,
  { gameVersion = gameVersion })
local legacyGame = {
  save = { party = {}, boxes = {}, options = { modOptions = {} } },
  mods = { modOptions = {} }, stack = { push = function() end },
}
legacyConfig.install(legacyGame, { applyConfig = function() end })
assert(legacyConfig.count() == 1 and legacyConfig.mode() == "party"
    and legacyConfig.presentation() == "ascendant_box"
    and legacyConfig.raichuFaces() == "ascendant",
  "legacy save inherited another slot's global follower options")

local a, b, c, d, e, f =
  mon("CHARIZARD"), mon("LAPRAS"), mon("ESPEON"), mon("SCIZOR"),
  mon("TYRANITAR"), mon("BLASTOISE")
game.save.party = { a, b, c, d, e, f }
config.setMode("custom")
assert(config.add(c) and config.add(a) and config.add(d) and config.add(b)
    and config.add(f) and config.add(e),
  "CUSTOM selection could not be built")
local ids = config.customIds()
assert(#ids == 6 and ids[1] == c[config.monKey] and ids[6] == e[config.monKey],
  ("CUSTOM order did not persist stable ids: %s / %s / %s"):format(
    table.concat(ids, ","), tostring(c[config.monKey]), tostring(b[config.monKey])))
assert(not config.add(c), "CUSTOM accepted a duplicate Pokemon")

local selection = factory("follower_selection.lua")({
  gameVersion = gameVersion, config = config,
  yellowPartner = { partner = function() return nil end },
})
local rows = selection.activeMany(game, 6)
assert(rows[1].mon == c and rows[2].mon == a
  and rows[3].mon == d and rows[4].mon == b
  and rows[5].mon == f and rows[6].mon == e,
  "CUSTOM mode followed battle-party order")

-- Party reorder must not affect CUSTOM, and evolution must keep the same id.
game.save.party = { b, e, d, f, a, c }
c.species = "UMBREON"
rows = selection.activeMany(game, 6)
assert(rows[1].mon == c and rows[1].mon.species == "UMBREON",
  "evolution or party reorder broke CUSTOM identity")

-- Deposit skips the unavailable member and withdraw restores its old place.
table.remove(game.save.party, 4)
game.save.boxes = { { f } }
rows = selection.activeMany(game, 6)
assert(#rows == 5 and rows[1].mon == c and rows[2].mon == a
    and rows[3].mon == d and rows[4].mon == b and rows[5].mon == e,
  "boxed CUSTOM member was not skipped cleanly")
game.save.party[#game.save.party + 1] = table.remove(game.save.boxes[1], 1)
rows = selection.activeMany(game, 6)
assert(#rows == 6 and rows[1].mon == c and rows[5].mon == f,
  "withdraw did not restore CUSTOM priority")

-- Count changes affect visibility only, never stored CUSTOM priority.
config.setCount(1)
assert(#selection.activeMany(game, config.count()) == 1 and #config.customIds() == 6,
  "reducing follower count destroyed CUSTOM priority")
config.setCount(6)
assert(#selection.activeMany(game, config.count()) == 6 and #config.customIds() == 6,
  "increasing follower count did not reconstruct CUSTOM order")

-- Party-menu hook exposes one compact native action and its editor mutates
-- the same persistent configuration rather than reordering the battle party.
local hook = assert(partyHook(), "party follower hook was not registered")
local menuRows = hook(function(_, items) return items end,
  game, { { label = "STATS" } }, c, { battle = false })
assert(menuRows[#menuRows].label == "FOLLOWER"
  and type(menuRows[#menuRows].onSelect) == "function",
  "native party-menu follower action missing")
menuRows[#menuRows].onSelect(c, game)
local editor = game.stack.pushed[#game.stack.pushed]
assert(editor and #editor.items == 3,
  "CUSTOM party editor does not expose priority/remove actions")
editor.opts.onChoose(editor.items[3], editor)
assert(editor.closed and #config.customIds() == 5,
  "party editor did not remove the selected follower")
config.add(c)
menuRows[#menuRows].onSelect(c, game)
editor = game.stack.pushed[#game.stack.pushed]
editor.opts.onChoose(editor.items[1], editor)
assert(config.customIds()[5] == c[config.monKey],
  "party editor MOVE UP did not change priority")
menuRows[#menuRows].onSelect(c, game)
editor = game.stack.pushed[#game.stack.pushed]
editor.opts.onChoose(editor.items[2], editor)
assert(config.customIds()[6] == c[config.monKey],
  "party editor MOVE DOWN did not change priority")
config.move(c, -5)

-- The persisted state reconstructs through a fresh module instance and fresh
-- Pokemon tables, exactly as a save/restart/load does.
local savedIds = config.customIds()
local reloadedParty = {}
for _, old in ipairs(game.save.party) do
  reloadedParty[#reloadedParty + 1] = {
    species = old.species, hp = old.hp, dvs = {},
    [config.monKey] = old[config.monKey],
  }
end
local mod2 = harness(bucket, optionValues)
local config2 = factory("follower_config.lua")(mod2, { gameVersion = gameVersion })
local game2 = {
  save = { party = reloadedParty, boxes = {}, options = { modOptions = {} }, flags = {} },
  mods = { modOptions = {} }, stack = { push = function() end },
}
config2.install(game2, { applyConfig = function() end })
assert(config2.count() == 6 and config2.mode() == "custom",
  "non-default count/mode did not survive reload")
local afterReload = config2.customIds()
assert(#afterReload == #savedIds and afterReload[1] == savedIds[1],
  "CUSTOM id order did not survive reload")

-- Yellow's exact marked partner always leads and is never duplicated even
-- when it also appears in CUSTOM. Evolved partner species remain valid.
edition = "yellow"
local yellow = reloadedParty[2]
yellow.species = "GOROCHU"
local yellowPartner = { partner = function() return yellow end }
local yellowSelection = factory("follower_selection.lua")({
  gameVersion = gameVersion, config = config2, yellowPartner = yellowPartner,
})
local yellowRows = yellowSelection.activeMany(game2, 6)
assert(yellowRows[1].mon == yellow and yellowRows[1].mon.species == "GOROCHU",
  "evolved Yellow partner did not lead")
local partnerCount = 0
for _, row in ipairs(yellowRows) do if row.mon == yellow then partnerCount = partnerCount + 1 end end
assert(partnerCount == 1, "Yellow partner was duplicated in CUSTOM")

-- The configured count keeps Yellow's logical partner reservation even while
-- that partner cannot follow. CUSTOM identity/order survives fainting,
-- boxing, party reorder and a fresh selector instance; the returning partner
-- is prepended exactly once without consuming a sixth extra slot.
local firstExtra = yellowRows[2].mon
yellow.hp = 0
assert(#yellowSelection.activeMany(game2, 1) == 0,
  "Yellow Count=1 exposed an extra through the reserved partner slot")
local absentRows = yellowSelection.activeMany(game2, 2)
assert(#absentRows == 1 and absentRows[1].mon == firstExtra
    and absentRows[1].source == "yellow_custom",
  "Yellow Count=2 did not expose the first CUSTOM extra")
absentRows = yellowSelection.activeMany(game2, 6)
assert(#absentRows == 5 and absentRows[1].mon == firstExtra,
  "fainted Yellow partner did not preserve five CUSTOM extras")

local reordered = {}
for index = #game2.save.party, 1, -1 do
  reordered[#reordered + 1] = game2.save.party[index]
end
game2.save.party = reordered
absentRows = yellowSelection.activeMany(game2, 6)
assert(#absentRows == 5 and absentRows[1].mon == firstExtra,
  "party reorder changed absent-partner CUSTOM priority")

for index, candidate in ipairs(game2.save.party) do
  if candidate == yellow then table.remove(game2.save.party, index) break end
end
yellow.hp = 30
game2.save.boxes = { { yellow } }
absentRows = yellowSelection.activeMany(game2, 6)
assert(#absentRows == 5 and absentRows[1].mon == firstExtra,
  "boxed Yellow partner hid or reordered CUSTOM extras")
local reloadedYellowSelection = factory("follower_selection.lua")({
  gameVersion = gameVersion, config = config2, yellowPartner = yellowPartner,
})
absentRows = reloadedYellowSelection.activeMany(game2, 6)
assert(#absentRows == 5 and absentRows[1].mon == firstExtra,
  "reload lost absent-partner CUSTOM visibility/order")

game2.save.party[#game2.save.party + 1] = table.remove(game2.save.boxes[1], 1)
yellowRows = reloadedYellowSelection.activeMany(game2, 6)
partnerCount = 0
for _, row in ipairs(yellowRows) do
  if row.mon == yellow then partnerCount = partnerCount + 1 end
end
assert(#yellowRows == 6 and yellowRows[1].mon == yellow
    and yellowRows[2].mon == firstExtra and partnerCount == 1,
  "returning Yellow partner did not prepend/dedupe after reload")

listeners["mod.options_changed"]({
  mod = "kanto_ascendant", key = "yellow_partner_presentation",
  value = "yellow_center",
})
assert(config.presentation() == "yellow_center",
  "runtime Yellow presentation option was not persisted")
listeners["mod.options_changed"]({
  mod = "kanto_ascendant", key = "yellow_raichu_face_style",
  value = "classic_yellow",
})
assert(config.raichuFaces() == "classic_yellow",
  "runtime Raichu face option was not persisted")
assert(applied > 0, "runtime configuration never refreshed the controller")

print("follower phase5 config tests passed")
