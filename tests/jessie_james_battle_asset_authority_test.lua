-- Byte authority for the Yellow Jessie/James/Meowth staged surfaces. Paths
-- alone are not approval: provenance and every selected candidate must match
-- the exact SHA-256 contract, including the final native-duo fail-safe.

local root = os.getenv("KANTO_ASCENDANT_MOD_DIR") or "."
package.loaded["src.core.GameVersion"] = {
  get = function() return "yellow" end,
}

local checks = 0
local function eq(actual, expected, message)
  checks = checks + 1
  assert(actual == expected, ("FAIL: %s (got %s, expected %s)")
    :format(message, tostring(actual), tostring(expected)))
end
local function check(value, message)
  checks = checks + 1
  assert(value, "FAIL: " .. message)
end

local PATHS = {
  provenance = "assets/yellow_jessie_james/PROVENANCE.json",
  voxel128 = "assets/yellow_jessie_james/battle/"
    .. "jessie_james_meowth_voxel_front_hd.png",
  voxel64 = "assets/yellow_jessie_james/battle/"
    .. "jessie_james_meowth_voxel_front.png",
  failSafe = "assets/crystal_v15/trainers/normal/jessie_james.png",
}
local bytes = {}
for role, relative in pairs(PATHS) do
  local file = assert(io.open(root .. "/" .. relative, "rb"), relative)
  bytes[relative] = assert(file:read("*a"))
  file:close()
  check(#bytes[relative] > 0, role .. " fixture has bytes")
end

local MISSING = {}
local function fixture(overrides, mutate, sha256)
  overrides = overrides or {}
  local factory = assert(loadfile(root .. "/trainer_voxel_portraits.lua"))()
  local portraits = factory({
    read = function(_, relative)
      local replacement = overrides[relative]
      if replacement == MISSING then return nil, "missing" end
      if replacement ~= nil then return replacement end
      return bytes[relative]
    end,
  }, { sha256 = sha256 })
  local rocket = {
    id = "OPP_ROCKET",
    pic = "/engine/yellow/rocket.png",
    picJessieJames = "/engine/yellow/jessie-james.png",
    parties = { [42] = {} },
  }
  local game = { data = { trainers = { OPP_ROCKET = rocket } } }
  local spec = assert(portraits.specForBattle({
    game = game,
    trainer = rocket,
    oppClass = "OPP_ROCKET",
    partyIndex = 42,
    showEnemyTrainer = true,
  }))
  if mutate then mutate(spec) end
  return portraits, spec
end

local portraits, spec = fixture()
local approved = assert(portraits.resolveJessieJamesAssets(spec))
eq(approved.verified, true, "the complete package is byte-verified")
eq(approved.provenanceSha256,
  "dbb193b6df0bf295b4567f56b90d16922bc85031d140ea96a6ebdcdae66d0892",
  "the exact approved provenance receipt is verified")
eq(#approved.candidates, 3, "all three approved surfaces are available")
for index, role in ipairs({ "voxel128", "voxel64", "exact-duo-failsafe" }) do
  eq(approved.candidates[index].role, role,
    "candidate order preserves " .. role)
  eq(approved.candidates[index].verified, true,
    role .. " carries byte-verification status")
  check(type(approved.candidates[index].sha256) == "string"
      and #approved.candidates[index].sha256 == 64,
    role .. " carries the actual verified SHA-256")
end

portraits, spec = fixture({
  [PATHS.voxel128] = bytes[PATHS.voxel128] .. "tamper",
})
approved = assert(portraits.resolveJessieJamesAssets(spec))
eq(approved.role, "voxel64",
  "same-path 128 tamper skips to the verified 64 surface")
eq(approved.rejected[1], "asset-sha256:voxel128",
  "same-path 128 tamper records its exact rejection")

portraits, spec = fixture({
  [PATHS.voxel128] = bytes[PATHS.voxel128] .. "tamper",
  [PATHS.voxel64] = bytes[PATHS.voxel64] .. "tamper",
})
approved = assert(portraits.resolveJessieJamesAssets(spec))
eq(approved.role, "exact-duo-failsafe",
  "two drifted trio surfaces skip to the verified native duo")

portraits, spec = fixture({
  [PATHS.voxel128] = bytes[PATHS.voxel128] .. "tamper",
  [PATHS.voxel64] = bytes[PATHS.voxel64] .. "tamper",
  [PATHS.failSafe] = bytes[PATHS.failSafe] .. "tamper",
})
local missing, reason = portraits.resolveJessieJamesAssets(spec)
eq(missing, nil, "three drifted surfaces fail closed")
eq(reason, "asset-sha256:voxel128",
  "all-surface tamper reports the first quality-order rejection")

portraits, spec = fixture({
  [PATHS.provenance] = bytes[PATHS.provenance] .. "tamper",
})
missing, reason = portraits.resolveJessieJamesAssets(spec)
eq(missing, nil, "same-path provenance tamper fails closed")
eq(reason, "provenance-sha256", "provenance drift is explicit")

portraits, spec = fixture(nil, function(current)
  current.assetContract.assets.voxel128.sha256 = string.rep("0", 64)
end)
approved = assert(portraits.resolveJessieJamesAssets(spec))
eq(approved.role, "voxel64",
  "a wrong declared 128 hash cannot authorize correct-path bytes")
eq(approved.rejected[1], "asset-contract-sha256:voxel128",
  "wrong declared hash is distinguished from byte drift")

portraits, spec = fixture(nil, function(current)
  current.assetContract.assets.voxel128.sha256 = nil
end)
approved = assert(portraits.resolveJessieJamesAssets(spec))
eq(approved.role, "voxel64",
  "a missing declared 128 hash skips to verified 64")
eq(approved.rejected[1], "asset-sha256-receipt:voxel128",
  "missing declared hash is explicit")

portraits, spec = fixture(nil, function(current)
  current.assetContract.provenance.sha256 = string.rep("0", 64)
end)
missing, reason = portraits.resolveJessieJamesAssets(spec)
eq(missing, nil, "wrong provenance contract hash fails closed")
eq(reason, "provenance-contract", "wrong provenance contract is explicit")

portraits, spec = fixture(nil, nil, function()
  return nil, "sha256-unavailable"
end)
missing, reason = portraits.resolveJessieJamesAssets(spec)
eq(missing, nil, "unavailable hashing never becomes path-only authority")
eq(reason, "sha256-unavailable", "hash capability failure is explicit")

portraits, spec = fixture({ [PATHS.voxel128] = MISSING })
approved = assert(portraits.resolveJessieJamesAssets(spec))
eq(approved.role, "voxel64", "missing 128 safely selects verified 64")

print(("jessie_james_battle_asset_authority_test: PASS (%d checks)")
  :format(checks))
