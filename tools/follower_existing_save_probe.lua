-- Read-only-product probe for a disposable copy of an existing Red save.
-- The shell launcher copies the user's slot into an isolated LÖVE identity;
-- this driver never writes the source identity.

return function(game)
  local U = dofile(assert(os.getenv("KA_TEST_UTIL"), "KA_TEST_UTIL required"))
  local SaveData = require("src.core.SaveData")
  local Follower = require("src.world.PikachuFollower")
  local identity = assert(os.getenv("POKEPORT_IDENTITY"))
  assert(identity:find("follower%-existing%-save%-probe"),
    "refusing to run outside disposable follower probe identity")
  local source = os.getenv("KA_SOURCE_SAVE")
  local loaded
  if source and source ~= "" then
    loaded = assert(loadfile(source))()
  else
    assert(SaveData.setActiveSlot("red", "slot7") == "slot7")
    loaded = assert(SaveData.load("red"), "copied slot7 did not load")
  end
  game:restoreSave(loaded)
  U.wait(10)
  U.teleport(game, "PALLET_TOWN", 5, 6, "down")
  U.wait(30)

  local exports = assert(game.mods.exports.kanto_ascendant)
  local native = assert(exports.singleFollower)
  assert(native.active == true, "native follower controller is inactive")
  assert(native.external == nil,
    "native follower yielded to " .. tostring(native.external))
  assert(game.save.party[1] and game.save.party[1].species == "ALAKAZAM"
      and (tonumber(game.save.party[1].hp) or 0) > 0,
    "copied slot does not have its expected healthy Alakazam lead")
  local selected, slot, source = exports.followerSelection.active(game)
  assert(selected == game.save.party[1] and slot == 1
      and source == "party_first_healthy",
    "existing save did not select its healthy lead")
  local sprite = exports.followerSprites.resolve(game, selected)
  assert(type(sprite) == "string" and sprite ~= "",
    "Alakazam follower sprite did not resolve")
  assert(native.refresh(game), "native follower refresh did not spawn")
  U.wait(12)
  local entity = assert(Follower.current(game.overworld),
    "no follower entity exists after refresh")
  assert(entity.followerSpecies == "ALAKAZAM",
    "spawned follower is not Alakazam")
  local count = 0
  for _, npc in ipairs(game.overworld.npcs or {}) do
    if npc.pikachuFollower then count = count + 1 end
  end
  assert(count == 1, "expected exactly one follower, got " .. tostring(count))
  -- Simulate a scripted hide whose matching show callback was skipped. This
  -- is the long-session failure reported from the installed RC.
  Follower.setVisible(game.overworld, false)
  assert(native.entity(game) == entity,
    "script hide unexpectedly destroyed the follower NPC")
  assert(native.refresh(game),
    "native refresh did not repair the interrupted scripted hide")
  local visible = 0
  for _, candidate in ipairs(game.overworld.entities or {}) do
    if candidate == entity then visible = visible + 1 end
  end
  assert(visible == 1,
    "interrupted scripted hide was not restored exactly once")
  local dir = assert(os.getenv("SHOT_DIR"))
  assert(U.shot(game, dir .. "/existing_slot7_alakazam_follower.png"))
  local file = assert(io.open(dir .. "/driver_result.txt", "wb"))
  file:write("PASS existing slot7 ALKAZAM follower\n")
  file:close()
  love.event.quit(0)
end
