-- Phase-3 registry contract: every shipped native follower sheet has an
-- explicit, species-authentic definition and configures the engine transport
-- as a six-pose true-colour walker.

local root = os.getenv("TRAINER_REMATCH_MOD_DIR") or "."

local function factory(name)
  return assert(loadfile(root .. "/" .. name))()
end

local function read(relative)
  local file = io.open(root .. "/" .. relative, "rb")
  if not file then return nil end
  local bytes = file:read("*a")
  file:close()
  return bytes
end

local function pngDimensions(relative)
  local bytes = assert(read(relative), "missing " .. relative)
  assert(bytes:sub(1, 8) == "\137PNG\r\n\26\n", relative .. " is not PNG")
  local function u32(offset)
    local a, b, c, d = bytes:byte(offset, offset + 3)
    return ((a * 256 + b) * 256 + c) * 256 + d
  end
  return u32(17), u32(21)
end

local johto = assert(loadfile(root .. "/johto_data.lua"))()
local registered, warnings
registered, warnings = nil, {}
local mod = {
  path = root,
  read = function(_, relative) return read(relative) end,
  content = { sprites = {
    get = function() return registered end,
    register = function(_, _, def) registered = def end,
    patch = function(_, _, def) registered = def end,
  } },
  log = { warn = function(_, fmt, species)
    warnings[#warnings + 1] = fmt:format(species)
  end },
}

local sprites = factory("follower_sprites.lua")(mod, {
  johtoData = johto,
  shinySystem = { isShiny = function(mon) return mon.shiny == true end },
})

assert(registered and registered.frames == 6 and registered.walker
  and registered.trueColor,
  "native follower transport must be a six-pose true-colour walker")
assert(next(sprites.definitions) ~= nil, "registry definitions were not built")

local pokemon, all = {}, {}
-- Species IDs are intentionally synthetic here: Kanto resolution is keyed by
-- canonical dex number, so this independently proves every shipped #001-151
-- resource is covered without relying on a particular engine data fixture.
for dex = 1, 151 do
  local species = ("KANTO_%03d"):format(dex)
  pokemon[species] = { dex = dex }
  all[#all + 1] = species
end
for _, species in ipairs(johto.order) do
  pokemon[species] = { dex = johto.species[species].dex }
  all[#all + 1] = species
end
pokemon.GOROCHU = { dex = 1026 }
all[#all + 1] = "GOROCHU"
local game = { data = { pokemon = pokemon, sprites = {
  SPRITE_PIKACHU = registered,
} } }

local function assertSheet(relative, label)
  local width, height = pngDimensions(relative)
  assert(width == 16 and height == 96,
    ("%s is not a 16x96 six-pose sheet (%dx%d)")
      :format(label, width, height))
end

for dex = 1, 151 do
  local species = ("KANTO_%03d"):format(dex)
  local def = assert(sprites.definition(game, species), "missing " .. species)
  assert(def.frames == 6 and def.width == 16 and def.height == 96
      and def.walker and def.trueColor,
    species .. " definition has incomplete renderer metadata")
  assert(def.normalRelative == ("assets/followers_kanto/follower_%03d.png")
      :format(dex), species .. " points at the wrong Kanto sheet")
  assertSheet(def.normalRelative, species)
  assert(sprites.resolve(game, { species = species }):match(
    ("follower_%03d%%.png$"):format(dex)),
    species .. " did not resolve its own Kanto sheet")
end

local definitionCount = 0
for _ in pairs(sprites.definitions) do definitionCount = definitionCount + 1 end
assert(definitionCount == 101,
  "expected 100 exact Johto definitions plus explicit Gorochu")
for _, species in ipairs(johto.order) do
  local def = assert(sprites.definitions[species], "Johto not registered: " .. species)
  assert(def.source:find("PokeWilds", 1, true), species .. " lost provenance")
  for _, isShiny in ipairs({ false, true }) do
    local relative = isShiny and def.shinyRelative or def.normalRelative
    assertSheet(relative, species)
    local path = assert(sprites.resolve(game, {
      species = species, shiny = isShiny,
    }), species .. " did not resolve")
    assert(path:match("follower_" .. species .. "%.png$"),
      species .. " did not load its own runtime sheet")
  end
end

local gorochu = assert(sprites.definitions.GOROCHU, "Gorochu not registered")
assert(gorochu.source:find("Ascendant", 1, true), "Gorochu provenance missing")
for _, isShiny in ipairs({ false, true }) do
  local relative = isShiny and gorochu.shinyRelative or gorochu.normalRelative
  assertSheet(relative, "GOROCHU")
  assert(assert(sprites.resolve(game, { species = "GOROCHU", shiny = isShiny }))
    :match("follower_GOROCHU%.png$"), "Gorochu did not load dedicated art")
end

-- Raichu is a first-class Kanto definition, not a special Yellow-only path.
pokemon.RAICHU = { dex = 26 }
local raichu = assert(sprites.definition(game, "RAICHU"), "Raichu not defined")
assertSheet(raichu.normalRelative, "RAICHU")
assert(assert(sprites.resolve(game, { species = "RAICHU" }))
  :match("follower_026%.png$"), "Raichu did not load authored Kanto walker")

sprites.register("FUTURE_CUSTOM", {
  normalRelative = "assets/followers_kanto/follower_001.png",
  source = "test custom registration",
})
pokemon.FUTURE_CUSTOM = { dex = 9999 }
assert(assert(sprites.resolve(game, { species = "FUTURE_CUSTOM" }))
  :match("follower_001%.png$"), "future custom registration needs core edits")

local configured, path = sprites.configure(game, { species = "SCIZOR" })
assert(configured and path and configured.frames == 6 and configured.walker
  and configured.trueColor and path:match("follower_SCIZOR%.png$"),
  "configured Johto follower lost renderer metadata")
assert(sprites.resolve(game, { species = "MISSINGNO" }) == nil,
  "missing art must hide rather than substitute another species")
assert(#warnings == 1, "missing art must emit one warning")

local report = sprites.coverage(game, all, false)
assert(#report == 252, "coverage report did not include Kanto, Johto and Gorochu")
for _, entry in ipairs(report) do
  assert(entry.definition and entry.relative and entry.readable,
    "coverage gap for " .. entry.species)
end

print("PASS follower Phase-3 registry: Kanto 151, Johto 100, Raichu, Gorochu, custom registration")
