-- Mandatory exact-package HEVO release lanes.  A packager/orchestrator may
-- consume this table, but a green source-tree/unit run must never be treated
-- as a substitute for these .love + installed-mod receipts.
local mod = assert(os.getenv("KA_HEVO_MOD") or ".")
local full = {
  RED={setup="tools/hidden_evolution_red_input_qa_setup.lua",
    driver="tools/hidden_evolution_red_input_e2e.lua", render="RED_QA_RENDER",
    trace="HEVO RED INPUT PASS", identity="ka-hevo-red-input-package"},
  BLUE={setup="tools/hidden_evolution_blue_pure_qa_setup.lua",
    driver="tools/hidden_evolution_blue_pure_input_qa.lua", render="BLUE_QA_RENDER",
    trace="HEVO BLUE PURE INPUT PASS", identity="ka-hevo-blue-pure-package"},
  GREEN={setup="tools/hidden_evolution_green_input_qa_setup.lua",
    driver="tools/hidden_evolution_green_input_e2e.lua", render="GREEN_QA_RENDER",
    trace="HEVO GREEN INPUT PASS", identity="ka-hevo-green-release-package"},
}
local out = { fullPaths={}, encounters={}, contracts={}, grantsAltars={} }
for _, character in ipairs({"RED","BLUE","GREEN"}) do
  local row=full[character]
  for _, renderer in ipairs({"2d","voxel"}) do
    local required={row.trace,"end-receipt",character,
      "oak-called","legacy-ready"}
    if renderer=="voxel" then
      required[#required+1]="wall-decal-receipt"
    end
    out.fullPaths[#out.fullPaths+1]={
      id=("hevo-full-%s-%s"):format(character:lower(),renderer),
      character=character, renderer=renderer,
      identity=row.identity.."-"..renderer,
      setup=mod.."/"..row.setup, driver=mod.."/"..row.driver,
      env={ [row.render]=renderer },
      required=required,
    }
  end
  for _, renderer in ipairs({"2d","voxel"}) do
    for _, cycle in ipairs({1,7}) do
      out.encounters[#out.encounters+1]={
        id=("hevo-natural-%s-%s-cycle%d"):format(
          character:lower(),renderer,cycle),
        character=character, renderer=renderer, cycle=cycle,
        expectedLevel=cycle==1 and 70 or 100,
        identity=("ka-hevo-encounter-demo-%s-%s-cycle%d"):format(
          character:lower(),renderer,cycle),
        setup=mod.."/tools/hevo_dungeon_encounter_demo_qa_setup.lua",
        driver=mod.."/tools/hevo_dungeon_encounter_demo_capture.lua",
        env={HEVO_ENCOUNTER_DEMO_CHARACTER=character,
          HEVO_ENCOUNTER_RENDERER=renderer,
          HEVO_ENCOUNTER_DEMO_CYCLE=tostring(cycle),
          HEVO_ENCOUNTER_NATURAL_ONLY="1"},
        required={"HEVO NATURAL DUNGEON ENCOUNTER PASS",
          "origin=automatic_initial_map_enter_wave",
          "level="..tostring(cycle==1 and 70 or 100),
          "contact_battle=real_start_battle_script,command_menu"},
      }
    end
  end
end
out.contracts[1]={
  id="hevo-package-contract",
  driver=mod.."/tools/hevo_package_contract_driver.lua",
  required={"HEVO PACKAGE CONTRACT PASS","foreign_trial_negatives=6/6",
    "foreign_trial_matrix=70/70","foreign_shrine_save_recovery=12/12",
    "statues=5/5/5","renderer=world-post-overlay+wall-decals",
    "voxel_wall_decals=adapter","maps=16 music=16 exact_surface=16"},
}
out.grantsAltars[1]={
  id="hevo15-grants-altars",
  identity="ka-hevo15-grants-altars-package",
  driver=mod.."/tests/hevo_15_grants_altars_visual_driver.lua",
  required={"HEVO-15 GRANTS + FIELD ALTARS PASS",
    "progression_setup=STAGED_TRIAL_FINALIZATION_BOUNDARIES",
    "grant_boundary=REAL_LEGACY_DUNGEON_ADAPTER_FINALIZE",
    "manual_package_flag_writes=false",
    "packages=15/15 targets=17/17 first_grants=8/8",
    "grant_reload=15/17/8","physical_altars=3/3",
    "altar_input=A_PRESS+PARTY_MENU+EVOLUTION_STATE",
    "altar_results=MAGNEZONE,GLACEON,LEAFEON","altar_reload=3/3"},
}
return out
