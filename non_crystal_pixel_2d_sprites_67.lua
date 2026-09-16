local function optionalImage(mod,path)
  local optional=mod.exports and mod.exports.optionalPokemonAssets
  return optional and optional.allowPending(path)==true or false
end
-- Static non-Crystal battle art Card for the classic 2D renderer.
--
-- Canonical #252-721 rows are replaced in-place by the maintainer-selected
-- Gen-II-style front/back catalog before this Card is constructed.  Remaining
-- later forms keep the pinned static fallback matrix. Voxel animation, Mega
-- forms, Gorochu and native #001-251 Crystal art remain separate owners.

return function(mod, opts)
  opts = opts or {}
  local P = {
    CARD_ID = "KASC-66-NON-CRYSTAL-PIXEL-2D",
    OWNER = "kasc.non-crystal-static-pixel-2d/v1",
    VERSION = "1.0.0",
    OPTION_KEY = "non_crystal_pixel_2d",
    data = opts.data or {},
    count = 0,
  }

  local function enabled()
    if mod.options and type(mod.options.get) == "function" then
      local ok, value = pcall(mod.options.get, mod.options, P.OPTION_KEY)
      if ok and value == false then return false end
    end
    return true
  end

  local registry = mod.content and mod.content.battle_sprite_scales
  for dex, row in pairs(P.data) do
    assert(tonumber(dex), "2D pixel runtime dex must be numeric")
    assert(type(row) == "table" and type(row.species) == "string",
      "2D pixel row missing species: " .. tostring(dex))
    assert(row.species ~= "GOROCHU" and not row.species:find("MEGA", 1, true),
      "2D pixel Card must not own Mega/Gorochu: " .. row.species)
    for _, key in ipairs({ "front", "frontShiny", "back", "backShiny" }) do
      local path = assert(row[key], "2D pixel path missing: " .. row.species .. "/" .. key)
      assert(mod:read(path) ~= nil or optionalImage(mod,path), "2D pixel PNG missing: " .. path)
      if registry and type(registry.register) == "function" then
        registry:register(("KA_PIXEL2D_%s_%s"):format(tostring(dex), key:upper()), {
          path = mod.path .. "/" .. path,
          scale = tonumber(row.scale) or (7 / 12),
        })
      end
    end
    P.count = P.count + 1
  end
  P.active = enabled()
  P.enabled = enabled

  local support = opts.supportLog
  if support and type(support.registerSegment) == "function" then
    support.registerSegment({
      segmentId=P.CARD_ID, cardId=P.CARD_ID, version=P.VERSION,
      schema="kasc.optional-visual-card/v1", owner=P.OWNER,
      active=P.active, dependencyStatus="pinned-source-reviewed",
      providerStatus=P.active and "canonical-gen2-style-static-front-back"
        or "cold-disabled",
      buildReceiptId="docs/NON_CRYSTAL_SPRITE_SURFACES_67.md",
      rollbackReceiptId="select-non_crystal_pixel_2d-off",
    })
  end
  return P
end
