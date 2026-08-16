-- Party-icon regression: exact authored entries must be installed for every
-- shipped species, and the runtime hook must preserve per-mon shiny art.

local root = os.getenv("TRAINER_REMATCH_MOD_DIR") or "."
local function factory(name) return assert(loadfile(root .. "/" .. name))() end
local function read(relative)
  local file = io.open(root .. "/" .. relative, "rb")
  if not file then return nil end
  local bytes = file:read("*a"); file:close(); return bytes
end
local function pngSize(bytes)
  if type(bytes) ~= "string" or bytes:sub(1, 8) ~= "\137PNG\r\n\26\n" then
    return nil, nil
  end
  local function u32(at)
    local a, b, c, d = bytes:byte(at, at + 3)
    return a * 16777216 + b * 65536 + c * 256 + d
  end
  return u32(17), u32(21)
end

local current, hook, entries = "animated", nil, {}
local mod = {
  path = root,
  read = function(_, relative) return read(relative) end,
  options = { get = function(_, key)
    if key == "party_icon_style" then return current end
  end },
  content = {
    sprites = { get = function() return nil end,
      register = function() end, patch = function() end },
    icons = { override = function(_, species, value) entries[species] = value end },
  },
  hooks = { wrap = function(_, name, callback)
    assert(name == "pokemon.icon"); hook = callback
  end },
  log = { warn = function() end },
}
local johto = factory("johto_data.lua")
local sprites = factory("follower_sprites.lua")(mod, {
  johtoData = johto,
  shinySystem = { isShiny = function(mon) return mon.shiny == true end },
})
local kanto = factory("kanto_species.lua")
local icons = factory("party_icons.lua")(mod, {
  sprites = sprites, kanto = kanto, johto = johto.order,
})

assert(#kanto == 151 and #johto.order == 100, "roster fixture changed")
assert(icons.registered == 252, "all #001-251 plus Gorochu need exact icons")
for species, entry in pairs(entries) do
  local relative = entry.image:sub(#root + 2)
  local width, height = pngSize(read(relative))
  assert(width == 16 and height == 96,
    species .. " does not have a readable 16x96 six-pose sheet")
end
assert(entries.BULBASAUR.image:match("follower_001%.png$")
  and entries.BULBASAUR.frames == 6, "Bulbasaur exact icon missing")
assert(entries.RAICHU.image:match("follower_026%.png$"),
  "Raichu must use the bundled authored sheet")
assert(entries.CELEBI.image:match("normal/follower_CELEBI%.png$"),
  "Celebi exact icon missing")
assert(entries.GOROCHU.image:match("normal/follower_GOROCHU%.png$"),
  "Gorochu exact icon missing")
assert(type(hook) == "function", "pokemon.icon hook missing")

local data = { pokemon = { BLASTOISE = { dex = 9 }, RAICHU = { dex = 26 },
  CELEBI = { dex = 251 }, GOROCHU = { dex = 1026 } } }
local normal = hook(function(path) return path end, "vanilla", {
  mon = { species = "RAICHU" }, data = data,
})
assert(normal:match("followers_kanto/follower_026%.png$"),
  "runtime hook did not select Raichu")
local shiny = hook(function(path) return path end, "vanilla", {
  mon = { species = "CELEBI", shiny = true }, data = data,
})
assert(shiny:match("shiny/follower_CELEBI%.png$"),
  "runtime hook did not select the individual shiny sheet")
local blastoise = hook(function(path) return path end, "vanilla", {
  mon = { species = "BLASTOISE" }, data = data,
})
assert(blastoise:match("followers_kanto/follower_009%.png$")
    and not blastoise:match("follower_026%.png$"),
  "a Raichu icon lookup contaminated the following Blastoise icon")

current = "original"
assert(icons.restartRequired(), "live style change must request restart")
entries, hook = {}, nil
local originalIcons = factory("party_icons.lua")(mod, {
  sprites = sprites, kanto = kanto, johto = johto.order,
})
assert(originalIcons.registered == 0 and next(entries) == nil,
  "original mode must leave native Gen-I icon classes untouched")
assert(hook(function(path) return path end, "native-mon", {
  mon = { species = "RAICHU" }, data = data,
}) == "native-mon", "original mode hook changed native art")

current = "species"
entries, hook = {}, nil
local migratedIcons = factory("party_icons.lua")(mod, {
  sprites = sprites, kanto = kanto, johto = johto.order,
})
assert(migratedIcons.loadedStyle == "animated"
    and migratedIcons.registered == 252,
  "legacy species value must migrate to animated art")
current = "classic"
assert(migratedIcons.restartRequired(),
  "legacy classic value must normalize to the original-art choice")

print("PASS party icons: exact 252, migration, shiny runtime, original fallback, restart contract")
