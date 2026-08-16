-- Full SDK/Authority merge proof for the source-bound Johto music.
package.path = "./?.lua;./?/init.lua;" .. package.path

local T = require("tests.modkit")
local Data = require("src.core.Data")
Data:load()
local root = assert(os.getenv("KA_JOHTO_MUSIC_MOD"))
local sdkRoot = root:sub(1, 1) == "/" and "/" or "."
local run = T.sdk.loadMod(root, { data = Data, root = sdkRoot })
T.eq(#run.errors, 0, "Authority loads Johto source music")

local exports = assert(run.loader.exports.kanto_ascendant)
local music = assert(exports.johtoMastersMusic)
T.eq(music.provenance.commit,
  "8e8f7e20052a596371a77022f0392c285e51bbf1",
  "runtime exports the pinned pokecrystal revision")

local indigo = assert(Data.audio.songs.Music_KA_GSC_IndigoPlateau)
local rival = assert(Data.audio.songs.Music_KA_GSC_RivalBattle)
T.eq(#indigo.chip.channels, 4, "Indigo transcription merges four channels")
T.eq(#rival.chip.channels, 3, "Rival transcription merges three channels")
T.check(indigo.file == nil and rival.file == nil,
  "Authority contains no PCM/OGG fallback")

local expected = {}
for _, mapId in ipairs(music.mapIds) do expected[mapId] = true end
local assigned = 0
for mapId, songId in pairs(Data.audio.mapSongs) do
  if songId == music.mapTheme then
    T.check(expected[mapId], "Indigo music is scoped to " .. mapId)
    assigned = assigned + 1
  end
end
T.eq(assigned, 7, "exactly seven Johto hall/passage/finale maps are assigned")

for _, trainerId in ipairs({
    "KA_JOHTO_SILVER", "KA_JOHTO_KRIS", "KA_JOHTO_GOLD",
}) do
  T.eq(Data.trainers[trainerId].battleTheme, music.battleTheme,
    trainerId .. " owns the GSC Rival battle theme")
end
for trainerId, trainer in pairs(Data.trainers) do
  if trainer.battleTheme == music.battleTheme then
    T.check(trainerId == "KA_JOHTO_SILVER"
      or trainerId == "KA_JOHTO_KRIS" or trainerId == "KA_JOHTO_GOLD",
      "Rival battle music leaked to " .. trainerId)
  end
end

T.finish("johto_masters_music_authority_test")
