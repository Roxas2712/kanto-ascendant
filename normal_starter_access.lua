-- Ordinary postgame access shares the roaming rivals' eligibility.
-- Discovery prerequisites still belong to the per-family rumor/trace gate.
-- Open receipts are save-local; no Legacy archive or legend seal is granted.
return function(mod, opts)
  local F = { SAVE_KEY="normal_starter_access" }
  local function state()
    local s=mod.save:get(F.SAVE_KEY)
    if type(s)~="table" then s={opened={}} end
    if type(s.opened)~="table" then s.opened={} end
    return s
  end
  function F.allowed(game)
    return not opts.isNewGamePlus(game) and opts.rivalsEligible(game) == true
  end
  function F.receipts() return state().opened end
  function F.isOpen(id) return F.receipts()[id]~=nil end
  function F.markOpen(game,id,receipt)
    if not F.allowed(game) then return false,"ordinary-postgame-required" end
    local s=state();s.opened[id]=receipt or true;mod.save:set(F.SAVE_KEY,s)
    return true
  end
  return F
end
