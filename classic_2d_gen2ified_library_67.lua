-- Applies the complete canonical #252-721 Gen-2-style image library to the
-- collision-safe runtime rows already registered by KASC. Species that do
-- not exist in the current release remain bundled and ready, but this visual
-- helper never invents Pokemon records or gameplay availability.

return function(runtimeData, sourceData)
  runtimeData, sourceData = runtimeData or {}, sourceData or {}
  local L = {
    CARD_ID = "KASC-66-NON-CRYSTAL-PIXEL-2D",
    OWNER = "kasc.non-crystal-static-pixel-2d/v1",
    SOURCE_OWNER = "jphyper-gen2ified-2d",
    sourceData = sourceData,
    runtimeData = runtimeData,
    sourceCount = 0,
    activeCount = 0,
  }
  for dex, row in pairs(sourceData) do
    assert(tonumber(dex) and tonumber(dex) >= 252 and tonumber(dex) <= 721,
      "Gen2ified source dex outside #252-721: " .. tostring(dex))
    assert(row.provider == L.SOURCE_OWNER,
      "Gen2ified provider mismatch at " .. tostring(dex))
    L.sourceCount = L.sourceCount + 1
  end
  assert(L.sourceCount == 470,
    "Gen2ified source library must contain exact #252-721 coverage")
  for _, row in pairs(runtimeData) do
    local source = sourceData[tostring(row.sourceDex)]
      or sourceData[row.sourceDex]
    -- Nationaldex 718 is shared by multiple forms. The canonical catalog is
    -- 50%, whereas this registered gift species is explicitly the 10% dog.
    if source and row.species ~= "ZYGARDE_10" then
      row.front, row.frontShiny = source.front, source.frontShiny
      row.back, row.backShiny = source.back, source.backShiny
      row.scale, row.provider = source.scale, source.provider
      row.mappingConfidence = source.mappingConfidence
      row.preferPixel2D = true
      L.activeCount = L.activeCount + 1
    end
  end
  return L
end
