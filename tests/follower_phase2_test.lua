local root = os.getenv("TRAINER_REMATCH_MOD_DIR") or "."

local function factory(name)
  return assert(loadfile(root .. "/" .. name))()
end

local edition = "red"
local gameVersion = { get = function() return edition end }
local partner
local yellowPartner = {
  partner = function() return partner end,
}
local legacyPartner
local legacyStarters = {
  partner = function() return legacyPartner end,
}
local selection = factory("follower_selection.lua")({
  gameVersion = gameVersion, yellowPartner = yellowPartner,
  legacyStarters = legacyStarters,
})

local function mon(species, hp, dex)
  return { species = species, hp = hp, dvs = {}, _dex = dex }
end

local bulbasaur = mon("BULBASAUR", 20, 1)
local caterpie = mon("CATERPIE", 0, 10)
local red = { save = { party = { caterpie, bulbasaur }, flags = {} } }
local selected, slot, source = selection.active(red)
assert(selected == bulbasaur and slot == 2
  and source == "party_first_healthy", "Red must pick first healthy party mon")
red.save.party[1], red.save.party[2] = red.save.party[2], red.save.party[1]
assert(selection.active(red) == bulbasaur, "party reorder must refresh slot 1")
bulbasaur.hp = 0
assert(selection.active(red) == nil, "all-fainted party must hide follower")
bulbasaur.hp = 20

edition = "blue"
assert(selection.active(red) == bulbasaur, "Blue must share Red PARTY policy")

edition = "yellow"
local pikachu = mon("PIKACHU", 18, 25)
partner = pikachu
local yellow = {
  save = { party = { bulbasaur, pikachu },
    flags = { EVENT_GOT_STARTER = true } },
}
assert(selection.active(yellow) == pikachu,
  "Yellow must select the exact partner, not party slot 1")
pikachu.species = "RAICHU"
assert(selection.active(yellow) == pikachu,
  "Yellow partner identity must survive in-place evolution")
table.remove(yellow.save.party, 2)
assert(selection.active(yellow) == nil,
  "boxed Yellow partner must not be replaced by unrelated party mon")

local chikorita = mon("CHIKORITA", 19, 152)
yellow.save.party = { bulbasaur, chikorita }
legacyPartner = chikorita
local selectedLegacy, legacySlot, legacySource = selection.active(yellow)
assert(selectedLegacy == chikorita and legacySlot == 2
  and legacySource == "yellow_legacy_partner",
  "Yellow Legacy catalogue partner must use the normal follower path")
chikorita.hp = 0
assert(selection.active(yellow) == nil,
  "a fainted Yellow Legacy partner must not promote another party mon")
chikorita.hp = 19
legacyPartner = nil

local registered
local warnings = {}
local spriteMod = {
  path = root,
  read = function(_, relative)
    local file = io.open(root .. "/" .. relative, "rb")
    if not file then return nil end
    local bytes = file:read("*a")
    file:close()
    return bytes
  end,
  content = { sprites = {
    get = function() return registered end,
    register = function(_, _, def) registered = def end,
    patch = function(_, _, def) registered = def end,
  } },
  log = { warn = function(_, fmt, value)
    warnings[#warnings + 1] = fmt:format(value)
  end },
}
local spriteRegistry = factory("follower_sprites.lua")(spriteMod, {
  spriteAssets = { follower = function(species, shiny)
    if species == "CHIKORITA" then
      return root .. "/assets/followers_runtime/"
        .. (shiny and "shiny" or "normal") .. "/follower_CHIKORITA.png"
    end
  end },
  shinySystem = { isShiny = function(candidate) return candidate.shiny end },
})
assert(registered and registered.frames == 6 and registered.walker
  and registered.trueColor, "generic sprite transport must be a true-color walker")
local spriteGame = { data = { pokemon = {
  BULBASAUR = { dex = 1 }, RAICHU = { dex = 26 },
  CHIKORITA = { dex = 152 }, MISSINGNO = { dex = 0 },
}, sprites = { SPRITE_PIKACHU = registered } } }
assert(spriteRegistry.resolve(spriteGame, bulbasaur):match("follower_001%.png$"),
  "Bulbasaur must resolve its own Kanto sheet")
assert(spriteRegistry.resolve(spriteGame, pikachu):match("follower_026%.png$"),
  "evolved Yellow partner must resolve actual Raichu art")
assert(spriteRegistry.resolve(spriteGame,
  { species = "CHIKORITA", hp = 1 }):match("follower_CHIKORITA%.png$"),
  "Johto must use Ascendant's bundled species registry")
assert(spriteRegistry.resolve(spriteGame,
  { species = "MISSINGNO", hp = 1 }) == nil,
  "missing art must hide instead of using unrelated fallback")
assert(#warnings == 1, "missing art must log exactly once per variant")

-- Lightweight engine integration: exercise the real controller wrappers
-- against an NPC-shaped follower and the engine's private spawn closure.
local current
local Follower = {}
local shouldSpawn = function() return false end
Follower.current = function() return current end
Follower.onMapEntered = function(game, ow)
  current = nil
  ow.npcs, ow.entities = {}, { ow.player }
  if shouldSpawn(game, ow) then
    current = {
      id = "native_follower", cellX = ow.player.cellX,
      cellY = ow.player.cellY + 1, px = ow.player.cellX * 16,
      py = (ow.player.cellY + 1) * 16, facing = "down",
      moving = false, pikachuFollower = true,
      facePlayer = function(self) self.facing = "up" end,
    }
    ow.npcs[1] = current
    ow.entities[2] = current
  end
end
Follower.update = function(game, ow)
  if not shouldSpawn(game, ow) then current = nil return end
  if not current then Follower.onMapEntered(game, ow) end
end
Follower.talk = function() end
Follower.setVisible = function(ow, visible)
  for i, entity in ipairs(ow.entities or {}) do
    if entity == current then table.remove(ow.entities, i) break end
  end
  if visible and current then ow.entities[#ow.entities + 1] = current end
end
package.preload["src.world.PikachuFollower"] = function() return Follower end
-- single_follower installs its real A-button seam on the production
-- OverworldController.  This isolated transport fixture therefore supplies
-- the smallest matching controller surface and verifies that restore leaves
-- the native method intact.
local Overworld = { interact = function() return "native" end }
local originalOverworldInteract = Overworld.interact
package.preload["src.world.OverworldController"] = function() return Overworld end
package.preload["src.render.SpriteRenderer"] = function()
  return { new = function(def, id) return { def = def, id = id } end }
end

edition = "red"
bulbasaur.hp = 20
red.data = spriteGame.data
red.mods = { exports = {} }
red.overworld = {
  player = { cellX = 5, cellY = 6, facing = "down" }, npcs = {}, entities = {},
}
local callbacks = {}
local controllerMod = {
  events = { on = function(_, name, callback) callbacks[name] = callback end },
  log = { info = function() end, error = function(_, message) error(message) end },
}
local spritesStub = {
  resolve = function(_, active) return active and ("sheet_" .. active.species) end,
  configure = function(_, active)
    if not active then return nil end
    local path = "sheet_" .. active.species
    local def = red.data.sprites.SPRITE_PIKACHU
    def.image, def.frames, def.walker, def.trueColor = path, 6, true, true
    return def, path
  end,
  invalidate = function() end,
}
local controller = factory("single_follower.lua")(controllerMod, {
  selection = selection, sprites = spritesStub, yellowPartner = yellowPartner,
})
assert(controller.install(red), "native controller must install on Red")
Follower.onMapEntered(red, red.overworld)
assert(#red.overworld.npcs == 1, "exactly one follower must spawn")
assert(controller.entity(red).followerSpecies == "BULBASAUR",
  "entity must expose selected species")
assert(controller.entity(red).followerIdentity
  and controller.entity(red).followerSprite == "sheet_BULBASAUR",
  "entity must expose identity and sprite state")

-- Reproduce a scene whose matching show callback was skipped. The live NPC
-- survives, but its renderer membership is gone; refresh must restore it
-- exactly once rather than requiring a full application restart.
for i, entity in ipairs(red.overworld.entities) do
  if entity == controller.entity(red) then table.remove(red.overworld.entities, i) break end
end
assert(controller.entity(red) ~= nil,
  "interrupted hide fixture must preserve the follower NPC")
assert(controller.refresh(red), "refresh must recover an interrupted hide")
local restored = 0
for _, entity in ipairs(red.overworld.entities) do
  if entity == controller.entity(red) then restored = restored + 1 end
end
assert(restored == 1,
  "refresh must restore the first follower to the draw list exactly once")

Follower.setVisible(red.overworld, false)
assert(controller.entity(red) ~= nil,
  "script hide must retain the first follower NPC")
assert(controller.refresh(red),
  "refresh must repair a hide whose owning scene no longer exists")
restored = 0
for _, entity in ipairs(red.overworld.entities) do
  if entity == controller.entity(red) then restored = restored + 1 end
end
assert(restored == 1,
  "interrupted scripted hide must recover without application restart")

-- PikachuFollower may rebuild the renderer from its vanilla placeholder
-- while Ascendant metadata survives.  A refresh must detect the renderer's
-- stale image path instead of trusting followerSprite alone.
controller.entity(red).sprite.def.image = "sheet_PIKACHU_STALE"
controller.refresh(red)
assert(controller.entity(red).sprite.def.image == "sheet_BULBASAUR",
  "refresh must repair stale vanilla renderer even when metadata matches")

red.overworld.player.targetX = 6
Follower.update(red, red.overworld)
local movement = assert(controller.movement(red), "movement state missing")
assert(#movement.history >= 1 and #movement.queue >= 1,
  "committed movement must enter history and FIFO queue")
red.overworld.player.cellX, red.overworld.player.targetX = 6, nil
bulbasaur.species = "IVYSAUR"
red.data.pokemon.IVYSAUR = { dex = 2 }
Follower.update(red, red.overworld)
assert(controller.entity(red).followerSpecies == "IVYSAUR"
  and controller.entity(red).followerSprite == "sheet_IVYSAUR",
  "evolution must refresh species and renderer without reselecting")

red.save.party = {}
Follower.update(red, red.overworld)
assert(Follower.current(red.overworld) == nil,
  "empty party must remove the follower safely")
red.save.party = { bulbasaur }
Follower.update(red, red.overworld)
assert(Follower.current(red.overworld), "withdrawal must restore follower")

controller.restore()
assert(Overworld.interact == originalOverworldInteract,
  "controller restore must restore native Overworld interaction")
local externalGame = {
  save = red.save, data = red.data, overworld = red.overworld,
}
controllerMod.find = function(id)
  if id == "PokePCFollowers_VoxelMerge" then
    return { id = id, exports = {
      activeMon = function() end, select = function() end,
    } }
  end
end
local externalController = factory("single_follower.lua")(controllerMod, {
  selection = selection, sprites = spritesStub, yellowPartner = yellowPartner,
})
assert(externalController.install(externalGame) == false
  and externalController.external == "PokePCFollowers_VoxelMerge",
  "external follower mod must take precedence")

print("PASS follower Phase-2: selection registry lifecycle movement external precedence")
