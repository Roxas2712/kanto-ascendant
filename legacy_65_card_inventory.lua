-- Exhaustive Card/rollback inventory for older 6.5 components selected into
-- the combined 6.7 line. This module is deliberately data-only: it never
-- mutates a save and does not turn core bug fixes into hidden runtime flags.

return function(mod, opts)
  opts = opts or {}
  local I = {
    CARD_ID="KASC-67-LEGACY-65-CARD-INVENTORY",
    OWNER="kasc.governance.legacy-65-card-inventory/v1",
    VERSION="1.0.0",
  }
  local cards = {
    {id="KASC-65-JOHTO-WILDS-REPAIR",owner="kasc.johto-wilds-migration/v1",
      implementation="johto_unleashed.lua",test="tests/legacy_johto_wilds_migration_test.lua",
      boundary="build-gate",rollback="revert-card-commit",save="preserve"},
    {id="KASC-65-LEGACY-BANK-BATCH",owner="kasc.legacy-bank-batch/v1",
      implementation="legacy_journey.lua",test="tests/legacy_journey_test.lua",
      boundary="runtime-option",option="modern_storage_ui",rollback="ui-off",save="preserve"},
    {id="KASC-65-RENDERER-ADMISSION",owner="kasc.renderer-compatibility-boundary/v1",
      implementation="voxel_renderer_compat.lua",test="tests/voxel_renderer_compat_test.lua",
      boundary="build-gate",rollback="remove-package-admission",save="none"},
    {id="KASC-65-EARLY-DIFFICULTY-CURVE",owner="kasc.difficulty.early-curve/v1",
      implementation="difficulty.lua",test="tests/difficulty_early_curve_engine_test.lua",
      boundary="build-gate",rollback="revert-card-commit",save="none"},
    {id="KASC-65-POKEDEX-AREA-GUARD",owner="kasc.pokedex.area-guard/v1",
      implementation="pokedex_area_compat.lua",test="tests/pokedex_area_compat_test.lua",
      boundary="build-gate",rollback="revert-card-commit",save="none"},
    {id="KASC-65-SURPRISE-TRAINER-BALANCE",owner="kasc.wanderer.fairness/v1",
      implementation="surprise_trainers_67.lua",test="tests/surprise_team_fairness_67_test.lua",
      boundary="runtime-option",option="legacy_wanderer_frequency",rollback="select-never",save="preserve"},
    {id="KASC-65-OPTIONS-SCHEMA",owner="kasc.options.full-contract/v1",
      implementation="main.lua",test="tests/options_full_contract_test.lua",
      boundary="build-gate",rollback="revert-card-commit",save="preserve"},
    {id="KASC-65-MODERN-STORAGE",owner="kasc.storage.modern-ui/v1",
      implementation="modern_storage_ui.lua",test="tests/frlg_pc_interface_test.lua",
      boundary="runtime-option",option="modern_storage_ui",rollback="select-off",save="preserve"},
    {id="KASC-66-STARTER-HABITATS",owner="kasc.starter-habitats/v1",
      implementation="starter_habitats.lua",test="tests/starter_habitats_67_test.lua",
      boundary="delegated-card",option="starter_habitats_enabled",rollback="select-off",save="preserve"},
    {id="KASC-65-YELLOW-NGPLUS-RIVAL-ROLE",owner="kasc.yellow-ngplus-rival-role-ownership/v1",
      implementation="rival_teams.lua",test="tests/rival_teams_test.lua",
      boundary="build-gate",rollback="revert-card-commit",save="preserve"},
    {id="KASC-65-YELLOW-CHARM-DISPATCH",owner="kasc.yellow.charm-dispatch/v1",
      implementation="extended_characters.lua",test="tests/charm_dispatch_engine_test.lua",
      boundary="build-gate",rollback="revert-card-commit",save="preserve"},
    {id="KASC-65-OAK-PARCEL-NGPLUS",owner="kasc.legacy-ngplus-progression/v1",
      implementation="legacy_ngplus_progression.lua",test="tests/legacy_ngplus_progression_test.lua",
      boundary="build-gate",rollback="revert-card-commit",save="preserve"},
    {id="KASC-65-OAK-LAB-BANK-CACHE",owner="kasc.legacy-bank-wide-root-cache/v1",
      implementation="modern_storage_ui.lua",test="tests/frlg_pc_interface_test.lua",
      boundary="runtime-option",option="modern_storage_ui",rollback="ui-off",save="preserve"},
  }

  local function copy(value)
    if type(value) ~= "table" then return value end
    local out = {}; for key, child in pairs(value) do out[key]=copy(child) end
    return out
  end
  local function active(row)
    if row.boundary ~= "runtime-option" and row.boundary ~= "delegated-card" then
      return true
    end
    if not (mod.options and type(mod.options.get) == "function") then return true end
    local ok, value = pcall(mod.options.get, mod.options, row.option)
    if not ok or value == nil then return false end
    if row.option == "legacy_wanderer_frequency" then return value ~= "never" end
    return value ~= false and value ~= "off"
  end

  function I.audit(fileExists, optionKeys)
    local report={total=#cards,verified=0,errors={}}
    for _, row in ipairs(cards) do
      local errors={}
      if type(row.id)~="string" or type(row.owner)~="string" then
        errors[#errors+1]="identity"
      end
      if type(fileExists)=="function" then
        if not fileExists(row.implementation) then errors[#errors+1]="implementation" end
        if not fileExists(row.test) then errors[#errors+1]="test" end
      end
      if row.option and type(optionKeys)=="table"
          and optionKeys[row.option]==nil then
        errors[#errors+1]="option"
      end
      if row.save~="none" and row.save~="preserve" then errors[#errors+1]="save" end
      if #errors==0 then report.verified=report.verified+1
      else report.errors[row.id]=errors end
    end
    report.ok=report.verified==report.total
    return report
  end

  if opts.supportLog and type(opts.supportLog.registerSegment)=="function" then
    opts.supportLog.registerSegment({
      segmentId=I.CARD_ID,cardId=I.CARD_ID,version=I.VERSION,
      schema="kasc.card-audit/v1",owner=I.OWNER,active=true,
      dependencyStatus="audited",providerStatus="data-only",
      buildReceiptId="docs/LEGACY_65_CARD_AUDIT_67.md",
      rollbackReceiptId="revert-audit-card-commit",
      pureData=true,
    })
    for _, row in ipairs(cards) do
      -- Delegated Cards register their richer live descriptor themselves;
      -- logging this audit alias first would hide that final provider status.
      if row.boundary~="delegated-card" then
        opts.supportLog.registerSegment({
          segmentId=row.id,cardId=row.id,version=I.VERSION,
          schema="kasc.legacy-component-card/v1",owner=row.owner,
          active=active(row),dependencyStatus="audited",
          providerStatus=row.boundary,buildReceiptId="docs/LEGACY_65_CARD_AUDIT_67.md",
          rollbackReceiptId=row.rollback,
        })
      end
    end
  end
  I.cards=copy(cards)
  return I
end
