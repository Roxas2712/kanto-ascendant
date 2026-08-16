-- Standalone LÖVE host for assertion-style mod tests against an exact engine
-- checkout.  Unlike a normal game boot this does not need a copied ROM cache
-- marker inside that checkout; Data:load reads POKEPORT_DATA_DIR directly.
function love.load()
  love.filesystem.setIdentity(os.getenv("POKEPORT_IDENTITY")
    or "ka-hevo-standalone-test")
  local engine = assert(os.getenv("GEN1RECOMP_ROOT"),
    "GEN1RECOMP_ROOT is required")
  local test = assert(os.getenv("KA_LUA_TEST"), "KA_LUA_TEST is required")
  package.path = engine .. "/?.lua;" .. engine .. "/?/init.lua;"
    .. package.path
  local chunk, loadWhy = loadfile(test)
  assert(chunk, loadWhy)
  local ok, runWhy = xpcall(chunk, debug.traceback)
  if not ok then
    print("KA LUA TEST FAIL " .. test .. "\n" .. tostring(runWhy))
    love.event.quit(1)
    return
  end
  print("KA LUA TEST PASS " .. test)
  love.event.quit(0)
end
