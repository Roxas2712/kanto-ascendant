local root = (arg and arg[1]) or "."
local factory = assert(loadfile(root .. "/crystal_walk_assets.lua"))()

local checks = 0
local function check(value, message)
  assert(value, message)
  checks = checks + 1
end

local function imageData(mode)
  mode = mode or "valid"
  local data = {}
  function data:getDimensions()
    if mode == "dimensions" then return 32, 96 end
    return 16, 96
  end
  function data:getPixel(x, y)
    local localY = y % 16
    local alpha = (x >= 2 and x <= 13 and localY >= 2) and 1 or 0
    if mode == "soft-alpha" and x == 2 and y == 2 then alpha = 0.5 end
    if mode == "legacy-soft-alpha" and x == 2 and y == 2 then alpha = 128 end
    if mode == "missing-baseline" and localY == 15 then alpha = 0 end
    if mode == "empty-frame" and math.floor(y / 16) == 3 then alpha = 0 end
    if mode == "opaque-corner" and x == 0 and localY == 0 then alpha = 1 end
    if mode == "legacy-alpha" then alpha = alpha * 255 end
    return 0, 0, 0, alpha
  end
  return data
end

local function api(primaryMode, fallbackMode, calls)
  return {
    newImageData = function(path)
      calls[#calls + 1] = path
      local mode = path:find("fallback_walk_v1", 1, true)
        and fallbackMode or primaryMode
      if mode == "decode" then error("synthetic decode failure") end
      return imageData(mode)
    end,
  }
end

local mod = { path = "/mod/kanto_ascendant" }
local calls = {}
local resolver = factory(mod, { imageApi = api("valid", "valid", calls) })
check(resolver.resolve("RED")
    == "/mod/kanto_ascendant/assets/characters/crystal_chars/red_walk.png",
  "valid Red does not use the new primary walking sheet")
check(resolver.receipts.red.lane == "primary",
  "valid Red does not record the primary lane")
check(#calls == 1, "valid primary unnecessarily decoded the fallback")
resolver.resolve("red")
check(#calls == 1, "walking resolution is not cached per identity")

resolver = factory(mod, { imageApi = api("legacy-alpha", "valid", {}) })
check(resolver.resolve("blue"):match("/blue_walk%.png$") ~= nil
    and resolver.receipts.blue.lane == "primary",
  "legacy 0..255 alpha data rejected a hard-edged primary")

for _, row in ipairs({
  { "dimensions", "bad_dimensions_32x96" },
  { "soft-alpha", "soft_alpha" },
  { "legacy-soft-alpha", "soft_alpha" },
  { "missing-baseline", "missing_baseline_0" },
  { "empty-frame", "empty_frame_3" },
  { "opaque-corner", "opaque_corner_0" },
  { "decode", "decode_failed" },
}) do
  calls = {}
  resolver = factory(mod, { imageApi = api(row[1], "valid", calls) })
  local resolved = resolver.resolve("green")
  check(resolved == "/mod/kanto_ascendant/assets/characters/crystal_chars/"
      .. "fallback_walk_v1/green_walk.png",
    row[1] .. " primary does not route to the packaged fallback")
  check(resolver.receipts.green.lane == "fallback-v1",
    row[1] .. " fallback lane is not inspectable")
  check(resolver.receipts.green.reason == row[2],
    row[1] .. " primary failure reason was lost")
  check(#calls == 2, row[1] .. " did not validate both primary and fallback")
end

resolver = factory(mod, { imageApi = {} })
check(resolver.resolve("blue")
    == "/mod/kanto_ascendant/assets/characters/crystal_chars/blue_walk.png",
  "headless validation incorrectly replaces an otherwise packaged primary")
check(resolver.receipts.blue.lane == "primary-unverified",
  "headless validation status is not explicit")

local previousLove = love
love = { image = { newImageData = function()
  return imageData("dimensions")
end } }
resolver = factory(mod)
check(resolver.resolve("red")
    == "/mod/kanto_ascendant/assets/characters/crystal_chars/red_walk.png",
  "the engine's generic table ImageData stub rejected a packaged primary")
check(resolver.receipts.red.lane == "primary-unverified"
    and resolver.receipts.red.reason == "validation_unavailable",
  "the engine ImageData stub was mistaken for a real decoder")
love = previousLove

resolver = factory(mod, {
  imageApi = api("dimensions", "soft-alpha", {}),
})
local ok, err = pcall(resolver.resolve, "red")
check(not ok and tostring(err):find("bad_dimensions_32x96", 1, true)
    and tostring(err):find("soft_alpha", 1, true),
  "a broken primary and broken fallback did not fail with both reasons")

ok, err = pcall(function()
  factory(mod, { imageApi = api("valid", "valid", {}) }).resolve("yellow")
end)
check(not ok and tostring(err):find("unknown Crystal walking identity", 1, true),
  "unknown identities can enter the three-character walking resolver")

print(("CRYSTAL WALK ASSET RESOLVER PASS: %d checks"):format(checks))
