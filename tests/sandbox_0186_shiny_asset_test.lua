-- Exact 0.1.86 contract for transformed shiny assets. The sandbox permits
-- engine Assets.exists and ImageData decoding, but not love.filesystem.

local root = os.getenv("TRAINER_REMATCH_MOD_DIR") or "."
local factory = assert(loadfile(root .. "/shiny_system.lua"))()

local assetState = { exists = {}, readable = {}, probes = {} }
package.loaded["src.render.Assets"] = nil
package.preload["src.render.Assets"] = function()
  return { exists = function(path)
    assetState.probes[#assetState.probes + 1] = { kind = "exists", path = path }
    return assetState.exists[path] == true
  end }
end

local deniedLoveReads = 0
love = setmetatable({
  image = { newImageData = function(path)
    assetState.probes[#assetState.probes + 1] = { kind = "decode", path = path }
    if assetState.readable[path] ~= true then error("decode failed: " .. path) end
    return { path = path }
  end },
}, { __index = function(_, key)
  if key == "filesystem" or key == "system" or key == "thread"
      or key == "event" then
    deniedLoveReads = deniedLoveReads + 1
    error("love." .. key .. " denied", 2)
  end
end })

local listeners = {}
local mod = {
  id = "kanto_ascendant",
  save = {
    get = function(_, _, default) return default end,
    set = function() end,
  },
  options = { get = function(_, key)
    if key == "shiny_effects" then return true end
    return false
  end },
  hooks = { wrap = function() end },
  events = { on = function(_, name, callback) listeners[name] = callback end },
  ui = { insertBefore = function(rows) return rows end },
}

local shiny = factory(mod, {})
local source = "assets/generated/pokemon/front/PIKACHU.png"
local candidate = "save/mod-derived/kanto_ascendant/shiny/"
  .. "pokemon/front/PIKACHU.png"
local function context()
  return { mon = { species = "PIKACHU", shiny = true } }
end

local missing = context()
assert(shiny.spritePath(source, missing) == source and missing.trueColor == nil,
  "missing derived output did not fail closed to original")
assert(assetState.probes[#assetState.probes].kind == "exists",
  "missing output should not be decoded")

assetState.exists[candidate] = true
listeners["assets.transformed"]({ modId = mod.id })
local corrupt = context()
assert(shiny.spritePath(source, corrupt) == source and corrupt.trueColor == nil,
  "corrupt derived output did not fail closed to original")
assert(assetState.probes[#assetState.probes].kind == "decode",
  "existing output was not corruption-probed")

assetState.readable[candidate] = true
listeners["assets.transformed"]({ modId = mod.id })
local valid = context()
assert(shiny.spritePath(source, valid) == candidate and valid.trueColor == true,
  "valid transformed shiny output was not selected")

local probeCount = #assetState.probes
assert(shiny.spritePath(source, context()) == candidate,
  "cached valid transformed path changed")
assert(#assetState.probes == probeCount,
  "derived transform cache did not avoid repeated probes")
assert(deniedLoveReads == 0,
  "shiny resolver touched a denied love facade property")

print("PASS sandbox 0.1.86 shiny output: missing/corrupt fail closed, valid cached")
