local root = assert(os.getenv("KA_HEVO_MOD"), "KA_HEVO_MOD required")
local files = {
  "hidden_evolution_architecture.lua",
  "dramaless_wall_decals_compat.lua",
  "hidden_evolution_campaign.lua",
  "hidden_evolution_red_path.lua",
  "hidden_evolution_story_coordinator.lua",
  "hevo_packages.lua", "apricorn_balls.lua",
  "tools/hevo_blitz_real_save_probe.lua",
  "tools/hevo_package_contract_driver.lua",
  "tools/hevo_package_matrix_manifest.lua",
  "tests/hevo_15_grants_altars_visual_driver.lua",
  "tests/hevo_15_grants_altars_driver_contract_test.lua",
  "tools/hevo_dungeon_encounter_demo_qa_setup.lua",
  "tools/hevo_dungeon_encounter_demo_capture.lua",
  "tools/hevo_map_surface_audit.lua",
  "tools/hidden_evolution_red_input_qa_setup.lua",
  "tools/hidden_evolution_red_input_e2e.lua",
  "tools/hidden_evolution_blue_pure_qa_setup.lua",
  "tools/hidden_evolution_blue_pure_input_qa.lua",
  "tools/hidden_evolution_green_input_qa_setup.lua",
  "tools/hidden_evolution_green_input_e2e.lua",
}
for _, file in ipairs(files) do
  local chunk, why = loadfile(root .. "/" .. file)
  assert(chunk, file .. ": " .. tostring(why))
end
print("HEVO package driver syntax: PASS (" .. #files .. " files)")
