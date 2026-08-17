-- Kanto shiny follower routing and safe normal fallback contract.

local root = os.getenv("TRAINER_REMATCH_MOD_DIR") or "."
local function factory(name) return assert(loadfile(root .. "/" .. name))() end
local function read(relative)
  local file = io.open(root .. "/" .. relative, "rb")
  if not file then return nil end
  local bytes = file:read("*a"); file:close(); return bytes
end

local registered
local mod = {
  path = root,
  read = function(_, relative) return read(relative) end,
  content = { sprites = {
    get = function() return registered end,
    register = function(_, _, def) registered = def end,
    patch = function(_, _, def) registered = def end,
  } },
  log = { warn = function() end },
}
local sprites = factory("follower_sprites.lua")(mod, {
  shinySystem = { isShiny = function(mon) return mon.shiny == true end },
})
local pokemon = {}
for dex = 1, 151 do pokemon[("KANTO_%03d"):format(dex)] = { dex = dex } end
local game = { data = { pokemon = pokemon, sprites = {
  SPRITE_PIKACHU = registered,
} } }

for dex = 1, 151 do
  local species = ("KANTO_%03d"):format(dex)
  local def = assert(sprites.definition(game, species))
  assert(def.normalRelative == ("assets/followers_kanto/follower_%03d.png")
    :format(dex))
  assert(def.shinyRelative == ("assets/followers_kanto/shiny/follower_%03d.png")
    :format(dex))
  assert(assert(sprites.resolve(game, { species = species, shiny = true }))
    :match(("followers_kanto/shiny/follower_%03d%%.png$"):format(dex)))
end

local broken = {
  path = root,
  read = function(_, relative)
    if relative == "assets/followers_kanto/shiny/follower_024.png" then
      return nil
    end
    if relative == "assets/followers_kanto/shiny/follower_025.png" then
      return "not a valid walker PNG"
    end
    return read(relative)
  end,
  content = mod.content,
  log = mod.log,
}
registered = nil
local safe = factory("follower_sprites.lua")(broken, {
  shinySystem = { isShiny = function(mon) return mon.shiny == true end },
})
local missingFallback = assert(safe.resolve(game, {
  species = "KANTO_024", shiny = true,
}))
assert(missingFallback:match("followers_kanto/follower_024%.png$"),
  "a missing shiny walker must fall back to its own normal walker")
local fallback = assert(safe.resolve(game, {
  species = "KANTO_025", shiny = true,
}))
assert(fallback:match("followers_kanto/follower_025%.png$"),
  "a corrupt shiny walker must fall back to its own normal walker")

local assets = factory("sprite_assets.lua")(mod)
assets.setKantoSpecies(factory("kanto_species.lua"))
assert(assert(assets.kantoFollower(25, true))
  :match("followers_kanto/shiny/follower_025%.png$"),
  "sprite-assets Kanto shiny lookup is unavailable")
assert(assert(assets.follower("PIKACHU", true))
  :match("followers_kanto/shiny/follower_025%.png$"),
  "canonical sprite-assets follower lookup did not expose Kanto shiny art")
local safeAssets = factory("sprite_assets.lua")(broken)
safeAssets.setKantoSpecies(factory("kanto_species.lua"))
assert(assert(safeAssets.kantoFollower(24, true))
  :match("followers_kanto/follower_024%.png$"),
  "sprite-assets missing-shiny lookup did not fall back to normal")
assert(assert(safeAssets.kantoFollower(25, true))
  :match("followers_kanto/follower_025%.png$"),
  "sprite-assets corrupt-shiny lookup did not fall back to normal")
assert(assert(safeAssets.follower("PIKACHU", true))
  :match("followers_kanto/follower_025%.png$"),
  "canonical corrupt-shiny lookup did not fall back to normal")

print("PASS Kanto shiny follower routing: 151 exact variants plus missing/corrupt normal fallback")
