-- Minimal real-engine driver for one standalone Lua acceptance test.
--
-- Usage:
--   POKEPORT_DRIVER=/absolute/path/to/this/file \
--   KA_LUA_TEST=/absolute/path/to/test.lua love /path/to/gen1recomp
--
-- Loading the test from the frame driver keeps LÖVE, generated data and the
-- exact engine checkout authoritative while still letting the ordinary
-- assertion-style mod tests run unchanged.
return function()
  local path = assert(os.getenv("KA_LUA_TEST"), "KA_LUA_TEST is required")
  local chunk, loadWhy = loadfile(path)
  assert(chunk, loadWhy)
  local ok, runWhy = xpcall(chunk, debug.traceback)
  if not ok then error(runWhy, 0) end
  print("KA LUA TEST PASS " .. path)
end
