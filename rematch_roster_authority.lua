-- Save/run-scoped deterministic authority for ordinary field-rematch rosters.
--
-- Team construction can run again after an option refresh, reload or retry.
-- Runtime RNG and a provisional active-slot name are not durable identities;
-- resolve the engine's playthrough context before the first construction and
-- seed every recruitment/evolution choice from that stable authority.

local A = { VERSION = 1 }

local function integer(value, fallback, minimum)
  value = math.floor(tonumber(value) or fallback)
  if minimum then value = math.max(minimum, value) end
  return value
end

local function component(value, fallback)
  if value == nil or value == "" then value = fallback end
  value = tostring(value == nil and "unknown" or value)
  return (value:gsub("%%", "%%25"):gsub("|", "%%7C"):gsub("=", "%%3D"))
end

local function activeProfile(edition)
  local ok, SaveData = pcall(require, "src.core.SaveData")
  if not (ok and SaveData and type(SaveData.activeSlot) == "function") then
    return nil
  end
  local resolved, slot = pcall(SaveData.activeSlot, edition)
  return resolved and slot or nil
end

local function storageProfile(game, storage)
  local resolver = storage and storage.context
  if type(resolver) ~= "function" then return nil end
  local ok, resolved = pcall(resolver, storage, game)
  if not (ok and type(resolved) == "table") then return nil end
  local profile = resolved.playthroughId
  if profile == nil or profile == "" then return nil end
  return profile
end

local function ownerBucket(save)
  local modData = type(save and save.modData) == "table" and save.modData or {}
  local bucket = modData.kanto_ascendant
  if type(bucket) ~= "table" then bucket = modData.trainer_rematch end
  return type(bucket) == "table" and bucket or {}
end

function A.authority(game, context)
  context = context or {}
  local save = type(game and game.save) == "table" and game.save or {}
  local player = type(save.player) == "table" and save.player or {}
  local meta = type(save.meta) == "table" and save.meta or {}
  local bucket = ownerBucket(save)
  local ascendant = type(bucket.ascendant) == "table" and bucket.ascendant or {}
  local legacy = type(bucket.legacy_journey) == "table"
    and bucket.legacy_journey or {}
  local edition = context.edition or save.version or "unknown"
  local profile = context.profile or meta.playthroughId or meta.profileId
    or meta.slotId or save.playthroughId or save.profileId
    or storageProfile(game, context.storage)
    or activeProfile(edition) or "native"
  local playerId = context.playerId or player.id or player.trainerId
    or player.trainerID or "no-player-id"
  local runId = context.runId or legacy.runId or "original"
  local cycle = integer(context.cycle or legacy.cycle or ascendant.cycle, 0, 0)
  local rematch = integer(context.rematchNumber, 1, 1)
  return table.concat({
    "ka-rematch-roster-v" .. tostring(A.VERSION),
    "profile=" .. component(profile, "native"),
    "player=" .. component(playerId, "no-player-id"),
    "name=" .. component(player.name, "no-player-name"),
    "rival=" .. component(player.rival, "no-rival-name"),
    "run=" .. component(runId, "original"),
    "cycle=" .. tostring(cycle),
    "edition=" .. component(edition, "unknown"),
    "trainer=" .. component(context.key, "unknown-trainer"),
    "class=" .. component(context.trainerClass, "unknown-class"),
    "rematch=" .. tostring(rematch),
  }, "|")
end

return A
