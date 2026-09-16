-- KASC 6.7 reusable Eevee field-evolution spots.
--
-- This card only owns the two Kanto-world placements.  Evolution authority,
-- permanent package unlocks and the Gen-IV gate stay in hevo_packages.lua.

return function(mod, opts)
  opts = opts or {}
  local packages = assert(opts.packages, "HEVO packages missing")
  local C = { registered = false }

  C.spots = {
    {
      id = "moss_viridian",
      map = "VIRIDIAN_FOREST",
      text = "TEXT_KA_EEVEE_MOSS_VIRIDIAN",
      package = "moss_field",
      object = {
        name = "KA_EEVEE_MOSS_VIRIDIAN",
        sprite = "SPRITE_POKE_BALL",
        x = 10, y = 25,
      },
    },
    {
      id = "ice_seafoam",
      map = "SEAFOAM_ISLANDS_B4F",
      text = "TEXT_KA_EEVEE_ICE_SEAFOAM",
      package = "ice_field",
      object = {
        name = "KA_EEVEE_ICE_SEAFOAM",
        sprite = "SPRITE_POKE_BALL",
        x = 26, y = 2,
      },
    },
  }

  function C.register()
    if C.registered then return false, "already_registered" end
    for _, spot in ipairs(C.spots) do
      assert(packages.registerFieldAltar(spot.map, spot.text,
        spot.package, spot.object))
    end
    C.registered = true
    return true
  end

  return C
end
