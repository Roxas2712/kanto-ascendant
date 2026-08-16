-- Kanto Ascendant opponent portrait resolver.
--
-- Public builds deliberately do not bundle Nintendo's native 64x64
-- FireRed/LeafGreen fronts. `FRONTS` remains only as a stable stem map for
-- Kanto Ascendant's independently authored Voxel portrait pairs. The legacy
-- `frlg` option migrates to the edition-original Gen-I picture.

return function(mod)
  local M = {}
  local ROOT = mod.path .. "/assets/characters/frlg_trainers/"
  local FRONTS = {
    OPP_AGATHA = "elite_four_agatha_front_pic.png",
    OPP_BEAUTY = "beauty_front_pic.png",
    OPP_BIKER = "biker_front_pic.png",
    OPP_BIRD_KEEPER = "bird_keeper_front_pic.png",
    OPP_BLACKBELT = "black_belt_front_pic.png",
    OPP_BLAINE = "leader_blaine_front_pic.png",
    OPP_BROCK = "leader_brock_front_pic.png",
    OPP_BRUNO = "elite_four_bruno_front_pic.png",
    OPP_BUG_CATCHER = "bug_catcher_front_pic.png",
    OPP_BURGLAR = "burglar_front_pic.png",
    OPP_CHANNELER = "channeler_front_pic.png",
    OPP_COOLTRAINER_F = "cool_trainer_f_front_pic.png",
    OPP_COOLTRAINER_M = "cool_trainer_m_front_pic.png",
    OPP_CUE_BALL = "cue_ball_front_pic.png",
    OPP_ENGINEER = "engineer_front_pic.png",
    OPP_ERIKA = "leader_erika_front_pic.png",
    OPP_FISHER = "fisherman_front_pic.png",
    OPP_GAMBLER = "gamer_front_pic.png",
    OPP_GENTLEMAN = "gentleman_front_pic.png",
    OPP_GIOVANNI = "leader_giovanni_front_pic.png",
    OPP_HIKER = "hiker_front_pic.png",
    OPP_JR_TRAINER_F = "picnicker_front_pic.png",
    OPP_JR_TRAINER_M = "camper_front_pic.png",
    OPP_JUGGLER = "juggler_front_pic.png",
    OPP_KOGA = "leader_koga_front_pic.png",
    OPP_LANCE = "elite_four_lance_front_pic.png",
    OPP_LASS = "lass_front_pic.png",
    OPP_LORELEI = "elite_four_lorelei_front_pic.png",
    OPP_LT_SURGE = "leader_lt_surge_front_pic.png",
    OPP_MISTY = "leader_misty_front_pic.png",
    OPP_POKEMANIAC = "pokemaniac_front_pic.png",
    OPP_PROF_OAK = "professor_oak_front_pic.png",
    OPP_PSYCHIC_TR = "psychic_m_front_pic.png",
    OPP_ROCKER = "rocker_front_pic.png",
    OPP_ROCKET = "rocket_grunt_m_front_pic.png",
    OPP_SABRINA = "leader_sabrina_front_pic.png",
    OPP_SAILOR = "sailor_front_pic.png",
    OPP_SCIENTIST = "scientist_front_pic.png",
    OPP_SUPER_NERD = "super_nerd_front_pic.png",
    OPP_SWIMMER = "swimmer_m_front_pic.png",
    OPP_TAMER = "tamer_front_pic.png",
    OPP_YOUNGSTER = "youngster_front_pic.png",
  }
  local baselines = {}
  local fallbackReceipts, fallbackReceiptKeys = {}, {}
  local ASCENDANT_LOW = {
    -- Oak's CURRENT pair won the approval; the Elite Four's approved redraws
    -- are V3 because their prior accepted assets already occupied V2.
    OPP_PROF_OAK = "professor_oak_voxel_front_v1.png",
    OPP_AGATHA = "elite_four_agatha_voxel_front_v3.png",
    OPP_BRUNO = "elite_four_bruno_voxel_front_v3.png",
    OPP_LANCE = "elite_four_lance_voxel_front_v3.png",
    OPP_LORELEI = "elite_four_lorelei_voxel_front_v3.png",
  }

  local function normalizeStyle(style)
    -- `ascendant` was the pre-approval RC value.  Treat it as a migration
    -- alias, never as a fourth user-visible mode.
    if style == "ascendant" then return "crystal_hd" end
    if style == "frlg" then return "original" end
    if style == "original" or style == "crystal_hd" then
      return style
    end
    return "crystal_hd"
  end

  local function migrateStyleBuckets(game)
    local containers = {
      game and game.mods,
      game and game.save and game.save.options,
    }
    for _, container in ipairs(containers) do
      local buckets = container and container.modOptions
      local bucket = buckets and buckets[mod.id]
      if type(bucket) == "table"
          and (bucket.trainer_portrait_style == "ascendant"
            or bucket.trainer_portrait_style == "frlg") then
        bucket.trainer_portrait_style = bucket.trainer_portrait_style == "frlg"
          and "original" or "crystal_hd"
      end
    end
  end

  local function selectedStyle(game)
    migrateStyleBuckets(game)
    local saved = game and game.save and game.save.options
      and game.save.options.modOptions
      and game.save.options.modOptions[mod.id]
      and game.save.options.modOptions[mod.id].trainer_portrait_style
    local style = saved
    if style == nil and mod.options and type(mod.options.get) == "function" then
      style = mod.options:get("trainer_portrait_style")
    end
    return normalizeStyle(style)
  end

  local function assetAvailable(path)
    if type(mod.read) == "function" then
      local prefix = tostring(mod.path or "") .. "/"
      local relative = path:sub(1, #prefix) == prefix
        and path:sub(#prefix + 1) or path
      local ok, body = pcall(mod.read, mod, relative)
      if ok then return body ~= nil end
    end
    -- The release gate proves every path statically.  A restricted runtime
    -- without mod:read may still let the engine asset loader resolve the
    -- packaged path (this branch is only for direct-load test doubles).
    return true
  end

  local function ascendantFilenames(id, frontFilename)
    local stem = frontFilename:gsub("_front_pic%.png$", "")
    local low = ASCENDANT_LOW[id] or (stem .. "_voxel_front_v2.png")
    local hd = low:gsub("_voxel_front_", "_voxel_front_hd_")
    return low, hd
  end

  local function recordFallback(id, requestedStyle, requestedPath, reason)
    local key = table.concat({ id, requestedStyle, requestedPath or "", reason }, "|")
    if fallbackReceiptKeys[key] then return end
    fallbackReceiptKeys[key] = true
    fallbackReceipts[#fallbackReceipts + 1] = {
      class = id, requestedStyle = requestedStyle,
      requestedPath = requestedPath, resolvedStyle = "original",
      reason = reason,
    }
  end

  local function resolve(id, frontFilename, style, originalPic, available)
    style = normalizeStyle(style)
    available = available or assetAvailable
    if style == "original" then
      return { path = originalPic, requestedStyle = style,
        resolvedStyle = "original" }
    end
    local low, hd = ascendantFilenames(id, frontFilename)
    local lowPath, hdPath = ROOT .. low, ROOT .. hd
    if available(lowPath) and available(hdPath) then
      return { path = lowPath, hdPath = hdPath, requestedStyle = style,
        resolvedStyle = style }
    end
    return { path = originalPic, requestedStyle = style,
      resolvedStyle = "original", requestedPath = lowPath,
      requestedHdPath = hdPath, fallbackReason = "missing_crystal_hd_pair" }
  end

  function M.refresh(game)
    local trainers = game and game.data and game.data.trainers
    if not trainers then return false end
    local style = selectedStyle(game)
    for id, filename in pairs(FRONTS) do
      local trainer = trainers[id]
      if trainer then
        if baselines[id] == nil then
          baselines[id] = {
            pic = trainer.pic or false,
            trueColor = trainer.trueColor == true,
          }
        end
        local originalPic = baselines[id].pic ~= false and baselines[id].pic or nil
        local resolution = resolve(id, filename, style, originalPic)
        if resolution.resolvedStyle == "original" then
          trainer.pic = resolution.path
          trainer.trueColor = baselines[id].trueColor == true
          trainer.ascendantTrainerPortraitStyle = "original"
        else
          trainer.pic = resolution.path
          trainer.trueColor = true
          trainer.ascendantTrainerPortraitStyle = resolution.resolvedStyle
        end
        trainer.ascendantTrainerPortraitRequestedStyle = style
        trainer.ascendantTrainerPortraitFallback = resolution.fallbackReason
        if resolution.fallbackReason then
          recordFallback(id, style, resolution.requestedPath,
            resolution.fallbackReason)
        end
      end
    end
    -- Oak's Legacy finale uses an isolated zero-money trainer class, but it
    -- is still Professor Oak.  Mirror only the selected presentation fields;
    -- party, rewards and battle identity remain isolated.
    local oak, beta = trainers.OPP_PROF_OAK, trainers.KA_OAK_BETA
    if oak and beta and beta.__kaLegacyOakBeta == true then
      beta.pic, beta.trueColor = oak.pic, oak.trueColor
      beta.ascendantTrainerPortraitStyle = oak.ascendantTrainerPortraitStyle
    end
    return true
  end

  mod.events:on("game.ready", function(ev) M.refresh(ev and ev.game) end)
  mod.events:on("save.loaded", function(ev) M.refresh(ev and ev.game) end)
  mod.events:on("mod.options_changed", function(ev)
    if ev and ev.mod == mod.id
        and (ev.key == "trainer_portrait_style" or ev.key == nil) then
      M.refresh(ev.game)
    end
  end)

  M.fronts = FRONTS
  M.modes = { "crystal_hd", "original" }
  M.selectedStyle = selectedStyle
  M.normalizeStyle = normalizeStyle
  M.resolve = resolve
  M.fallbackReceipts = fallbackReceipts
  M.crystalPairAvailable = function(id)
    if id == "KA_OAK_BETA" then id = "OPP_PROF_OAK" end
    local filename = FRONTS[id]
    if not filename then return false end
    local low, hd = ascendantFilenames(id, filename)
    return assetAvailable(ROOT .. low) and assetAvailable(ROOT .. hd)
  end
  M.nativeFrlgAssetsBundled = false
  return M
end
