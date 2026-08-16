-- Headless contract for all 42 ordinary/leader/Elite/Oak classes and the
-- exact two public portrait modes plus legacy-FRLG migration. No LÖVE
-- process is required.

local root = os.getenv("TRAINER_REMATCH_MOD_DIR") or "."
local selected = "crystal_hd"
local events = { on = function() end }
local mod = {
  id = "kanto_ascendant", path = root, events = events,
  read = function(_, relative)
    local file = io.open(root .. "/" .. relative, "rb")
    if not file then return nil end
    local body = file:read("*a")
    file:close()
    return body
  end,
  options = { get = function(_, key)
    if key == "trainer_portrait_style" then return selected end
  end },
}
local factory = assert(assert(loadfile(root .. "/frlg_trainer_pack.lua"))())
local pack = factory(mod)

local function check(value, message)
  if not value then error(message, 2) end
end

local ids, trainers = {}, {}
check(table.concat(pack.modes, ",") == "crystal_hd,original",
  "portrait API exposes anything other than HD and edition-original")
check(pack.nativeFrlgAssetsBundled == false,
  "public portrait resolver claims native FRLG assets")
for _, filename in pairs(pack.fronts) do
  local file = io.open(root .. "/assets/characters/frlg_trainers/" .. filename,
    "rb")
  check(file == nil, "official FRLG front remains bundled: " .. filename)
  if file then file:close() end
end
for id in pairs(pack.fronts) do
  ids[#ids + 1] = id
  trainers[id] = { id = id, pic = "engine-original/" .. id .. ".png" }
end
table.sort(ids)
check(#ids == 42, "expected 42 selectable non-rival Kanto classes")
local categoryCounts = { professor = 0, gym = 0, elite_four = 0, normal = 0 }
for _, id in ipairs(ids) do
  local filename = pack.fronts[id]
  local category = filename:find("^leader_") and "gym"
    or filename:find("^elite_four_") and "elite_four"
    or id == "OPP_PROF_OAK" and "professor" or "normal"
  categoryCounts[category] = categoryCounts[category] + 1
end
check(categoryCounts.professor == 1 and categoryCounts.gym == 8
    and categoryCounts.elite_four == 4 and categoryCounts.normal == 29,
  "professor/gym/Elite/normal category coverage drifted")
check(pack.crystalPairAvailable("KA_OAK_BETA"),
  "Oak Legacy finale did not inherit Oak's approved CURRENT pair")

local game = {
  data = { trainers = trainers },
  mods = { modOptions = { kanto_ascendant = {} } },
  save = { options = { modOptions = { kanto_ascendant = {} } } },
}

local checks = 0
for _, style in ipairs({ "crystal_hd", "original" }) do
  selected = style
  game.mods.modOptions.kanto_ascendant.trainer_portrait_style = style
  game.save.options.modOptions.kanto_ascendant.trainer_portrait_style = style
  check(pack.refresh(game), style .. " refresh failed")
  check(pack.selectedStyle(game) == style, style .. " did not persist")
  local reloaded = { save = { options = { modOptions = {
    kanto_ascendant = { trainer_portrait_style = style },
  } } } }
  check(pack.selectedStyle(reloaded) == style,
    style .. " did not survive save/reload resolution")
  for _, id in ipairs(ids) do
    local trainer, front = trainers[id], pack.fronts[id]
    if style == "original" then
      check(trainer.pic == "engine-original/" .. id .. ".png",
        id .. " did not restore exact engine original")
      check(trainer.trueColor ~= true, id .. " original forced true colour")
    else
      local stem = front:gsub("_front_pic%.png$", "")
      local version = id == "OPP_PROF_OAK" and "v1"
        or id == "OPP_LORELEI" and "v3"
        or id == "OPP_BRUNO" and "v3"
        or id == "OPP_AGATHA" and "v3"
        or id == "OPP_LANCE" and "v3" or "v2"
      check(trainer.pic == root .. "/assets/characters/frlg_trainers/"
          .. stem .. "_voxel_front_" .. version .. ".png",
        id .. " did not select approved Crystal HD sibling")
      check(trainer.trueColor == true, id .. " Crystal HD is not true colour")
    end
    check(trainer.ascendantTrainerPortraitRequestedStyle == style,
      id .. " requested-style receipt drifted")
    check(trainer.ascendantTrainerPortraitStyle == style,
      id .. " resolved-style receipt drifted")
    checks = checks + 1
  end
end
check(checks == 84, "42x2 public mode matrix incomplete")

-- Existing RC saves used `ascendant`; migration writes the only new value to
-- both live and save/reload buckets before resolving any picture.
game.mods.modOptions.kanto_ascendant.trainer_portrait_style = "ascendant"
game.save.options.modOptions.kanto_ascendant.trainer_portrait_style = "ascendant"
check(pack.selectedStyle(game) == "crystal_hd", "legacy alias not normalized")
check(game.mods.modOptions.kanto_ascendant.trainer_portrait_style == "crystal_hd",
  "live option bucket not migrated")
check(game.save.options.modOptions.kanto_ascendant.trainer_portrait_style == "crystal_hd",
  "save/reload option bucket not migrated")

local fallback = pack.resolve("OPP_BROCK", pack.fronts.OPP_BROCK,
  "crystal_hd", "engine-original/OPP_BROCK.png", function() return false end)
check(fallback.resolvedStyle == "original"
    and fallback.path == "engine-original/OPP_BROCK.png"
    and fallback.fallbackReason == "missing_crystal_hd_pair",
  "missing Crystal pair did not fail closed to original")
fallback = pack.resolve("OPP_BROCK", pack.fronts.OPP_BROCK,
  "frlg", "engine-original/OPP_BROCK.png", function() return true end)
check(fallback.resolvedStyle == "original"
    and fallback.path == "engine-original/OPP_BROCK.png",
  "legacy FRLG choice did not normalize to engine original")

local brockFront = pack.fronts.OPP_BROCK
pack.fronts.OPP_BROCK = "definitely_missing_front_pic.png"
selected = "crystal_hd"
game.mods.modOptions.kanto_ascendant.trainer_portrait_style = "crystal_hd"
game.save.options.modOptions.kanto_ascendant.trainer_portrait_style = "crystal_hd"
local receiptCount = #pack.fallbackReceipts
check(pack.refresh(game), "missing-Crystal refresh failed")
check(trainers.OPP_BROCK.pic == "engine-original/OPP_BROCK.png"
    and trainers.OPP_BROCK.ascendantTrainerPortraitFallback
      == "missing_crystal_hd_pair"
    and #pack.fallbackReceipts == receiptCount + 1
    and pack.fallbackReceipts[#pack.fallbackReceipts].class == "OPP_BROCK"
    and pack.fallbackReceipts[#pack.fallbackReceipts].resolvedStyle == "original",
  "missing Crystal pair did not emit inspectable original fallback receipt")
selected = "frlg"
game.mods.modOptions.kanto_ascendant.trainer_portrait_style = "frlg"
game.save.options.modOptions.kanto_ascendant.trainer_portrait_style = "frlg"
check(pack.refresh(game), "legacy-FRLG migration refresh failed")
check(pack.selectedStyle(game) == "original"
    and trainers.OPP_BROCK.pic == "engine-original/OPP_BROCK.png",
  "runtime legacy-FRLG migration did not restore engine original")
pack.fronts.OPP_BROCK = brockFront

print("TRAINER PORTRAIT PUBLIC MODES PASS: 42x2 (1 Oak/8 Gym/4 Elite/29 normal) + legacy-FRLG migration + fail-closed receipts")
