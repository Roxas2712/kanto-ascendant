-- Generation router for Kanto Ascendant.
--
-- Red/Blue/Yellow keep the complete Kanto entry. Gold/Silver/Crystal deliberately
-- execute only the shared Bank bridge and the modular Mega capability needed
-- by transferred Ring/Stone receipts: no Kanto story, map, encounter, title,
-- option or save-migration module is read.

local function loadSibling(mod, filename)
  local body, readErr = mod:read(filename)
  assert(type(body) == "string", readErr or ("unable to read " .. filename))
  local chunk, err = loadstring(body, "@" .. mod.path .. "/" .. filename)
  assert(chunk, err or readErr)
  return chunk()
end

return function(mod)
  mod.exports.hdDownloadSupport=loadSibling(mod,'hd_download_support.lua')(
    mod,loadSibling(mod,'hd_download_log.lua'))
  local GameVersion = require("src.core.GameVersion")
  local current = type(GameVersion.get) == "function"
    and GameVersion.get() or GameVersion.current or "red"
  local currentGeneration = type(GameVersion.generation) == "function"
    and GameVersion.generation(current)
    or ((current == "gold" or current == "silver" or current == "crystal")
      and 2 or 1)

  if currentGeneration == 1 then
    loadSibling(mod, "main.lua")(mod)
  end

  local Serializer = require("src.core.SaveSerializer")
  local i18n = loadSibling(mod, "localization.lua")(mod)
  local sha256 = loadSibling(mod, "legacy_bank_sha256.lua")
  local mega = mod.exports and mod.exports.megaEvolution or nil
  if currentGeneration == 2 then
    local makeMega = loadSibling(mod, "mega_evolution.lua")
    local animationData = loadSibling(mod, "mega_animation_data.lua")
    mega = makeMega(mod, {
      i18n = i18n,
      animationData = animationData,
      contentEnabled = true,
      voxelRenderer = { module = function() return nil end },
      postgame = {
        hasHallOfFame = function() return true end,
        state = function() return { masterWins = {}, apexChampion = true } end,
      },
    })
    mod.exports = mod.exports or {}
    mod.exports.megaEvolution = mega
    local nativeMega = loadSibling(mod, "mega_gen2_battle_bridge.lua")(mod, mega, i18n)
    mod.exports.megaGen2BattleBridge = nativeMega
    mod.events:on("game.ready", function(event)
      local game = event and event.game
      if game then nativeMega.install(game) end
    end, 30)
  end
  local crossGenerationItems = { MEGA_RING = true }
  for _, profile in ipairs(mega and mega.forms or {}) do
    if type(profile) == "table" and type(profile.stone) == "string" then
      crossGenerationItems[profile.stone] = true
    end
  end
  local function classifyItem(id)
    return crossGenerationItems[tostring(id or ""):upper()]
      and "crossgen_mega" or "kanto_only"
  end
  local Vault = loadSibling(mod, "legacy_bank_vault.lua")({
    serializer = Serializer,
    sha256 = sha256,
    classifyItem = classifyItem,
    megaProfiles = mega and mega.forms or {},
  })
  local Store = loadSibling(mod, "legacy_bank_store.lua")({
    serializer = Serializer,
    sha256 = sha256,
    vault = Vault,
  })
  local archive = mod.exports and mod.exports.legacyJourney
    and mod.exports.legacyJourney.archive or nil
  if archive and type(archive.bindSha256) == "function" then
    assert(archive.bindSha256(sha256))
  end
  return loadSibling(mod, "legacy_bank_bridge.lua")(mod, {
    serializer = Serializer,
    sha256 = sha256,
    vault = Vault,
    store = Store,
    archive = archive,
    itemRuntime = mega,
    classifyItem = classifyItem,
    edition = function()
      return type(GameVersion.get) == "function"
        and GameVersion.get() or GameVersion.current or current
    end,
    generation = function()
      local active = type(GameVersion.get) == "function"
        and GameVersion.get() or GameVersion.current or current
      return type(GameVersion.generation) == "function"
        and GameVersion.generation(active)
        or ((active == "gold" or active == "silver" or active == "crystal")
          and 2 or 1)
    end,
    i18n = i18n,
  })
end
