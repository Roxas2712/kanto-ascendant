-- Kanto Ascendant 6.7 Discovery Core, Phase 1 composition root.
--
-- This file only binds the pure authorities to the active mod save.  Habitat
-- maps, encounter hooks, sprites, audio, battles and release presentation are
-- intentionally outside Phase 1.

local Module = {}

function Module.create(mod, deps)
  deps = deps or {}
  local State = assert(deps.state, "Discovery Core needs state authority")
  local StarterModule = assert(deps.starters,
    "Discovery Core needs starter authority")
  local Overlay = assert(deps.overlay,
    "Discovery Core needs overlay authority")
  local HoennModule = deps.hoenn
  local Starters = type(StarterModule.create) == "function"
    and StarterModule.create(State) or StarterModule
  local Hoenn = HoennModule and type(HoennModule.create) == "function"
    and HoennModule.create(State, Overlay, deps.hoennData) or HoennModule
  assert(type(Starters.plan) == "function",
    "Discovery Core starter authority is not configured")
  assert(type(Overlay.plan) == "function",
    "Discovery Core overlay authority is invalid")

  return {
    State = State,
    Starters = Starters,
    Overlay = Overlay,
    Hoenn = Hoenn,
    state = State.create(mod),
    schemaVersion = State.SCHEMA_VERSION,
  }
end

return Module
