local files = {
  "tools/presentation_motion_package_matrix_manifest.lua",
  "tools/presentation_motion_package_composite.lua",
  "tools/blitz_character_presentation_matrix.lua",
  "tests/presentation_motion_package_driver.lua",
}

for _, path in ipairs(files) do
  local chunk, reason = loadfile(path)
  assert(chunk, path .. " failed Lua syntax: " .. tostring(reason))
end

local manifest = assert(loadfile(files[1]))()
assert(manifest.schema == "ka-l02-presentation-motion-package-matrix/v1")
local composite = assert(loadfile(files[2]))()
assert(type(composite.run) == "function")
assert(type(composite.runCharacters) == "function")
assert(type(composite.runCrystalTitleGorochu) == "function")
assert(type(composite.runFollowerWilds) == "function")
assert(type(composite.runBlitzRestore) == "function")
assert(type(composite.runReloadVerify) == "function")
assert(type(composite.aggregate) == "function")
assert(type(composite.writeFailure) == "function")
assert(type(assert(loadfile(files[3]))()) == "function")
assert(type(assert(loadfile(files[4]))()) == "function")

print("Presentation/motion package Lua syntax PASS: 4 bounded harness files")
