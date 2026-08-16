-- Guarded real-LÖVE acceptance for persistent PARTY/CUSTOM followers.
-- Run twice per edition under a dedicated follower-phase5 identity. The first
-- pass writes reserved slot 6505; the second loads it and proves reconstruction.

return function(game)
  local U = dofile("tests/drivers/util.lua")
  local GameVersion = require("src.core.GameVersion")
  local Pokemon = require("src.pokemon.Pokemon")
  local Evolution = require("src.pokemon.Evolution")
  local Boxes = require("src.pokemon.Boxes")
  local SaveData = require("src.core.SaveData")
  local Follower = require("src.world.PikachuFollower")
  local PartyMenu = require("src.ui.PartyMenu")

  local version = assert(os.getenv("POKEPORT_VERSION"), "edition required")
  local identity = assert(os.getenv("POKEPORT_IDENTITY"), "identity required")
  assert(identity:find("follower%-phase5"),
    "refusing to write outside follower-phase5 identity")
  assert(GameVersion.get() == version, "wrong ROM cache mounted")
  assert(SaveData.setActiveSlot(version, "slot6505") == "slot6505")

  -- A driver starts at the title-screen skeleton. Explicitly adopt the
  -- reserved slot when it exists so pass two is a real process restart/load.
  local loaded, recovered = SaveData.load()
  if loaded then game:restoreSave(loaded, recovered) end
  U.wait(5)

  local exports = assert(game.mods and game.mods.exports
    and game.mods.exports.kanto_ascendant, "Ascendant exports unavailable")
  local native = assert(exports.singleFollower, "native follower unavailable")
  local config = assert(exports.followerConfig, "follower config unavailable")
  local yellowPartner = assert(exports.yellowPartner, "Yellow adapter unavailable")
  assert(native.active and not native.external, "native follower did not install")

  local schema = assert(game.mods.optionSchemas.kanto_ascendant,
    "Ascendant option schema missing")
  local optionRows = {}
  for _, row in ipairs(schema) do optionRows[row.key] = row end
  assert(optionRows.follower_count and optionRows.follower_count.default == 1,
    "Follower Count option/default missing")
  assert(optionRows.follower_order and optionRows.follower_order.default == "party",
    "Follower Order option/default missing")
  assert((version == "yellow") == (optionRows.yellow_partner_presentation ~= nil),
    "Yellow presentation row leaked or is missing")

  local probe = game.save._followerPhase5Probe
  if probe and probe.stage == 1 then
    assert(config.count() == 6 and config.mode() == "custom",
      "saved count/mode did not reconstruct")
    assert(config.presentation() == probe.presentation,
      "saved Yellow presentation did not reconstruct")
    local rows = native.activeMons(game)
    assert(#rows == 6, "saved CUSTOM chain did not reconstruct")
    for index, species in ipairs(probe.expected) do
      assert(rows[index].mon.species == species,
        ("reload follower %d expected %s, got %s"):format(
          index, species, tostring(rows[index].mon.species)))
    end
    local seen = {}
    for _, row in ipairs(rows) do
      assert(not seen[row.mon], "saved Yellow/custom follower duplicated")
      seen[row.mon] = true
    end
    U.teleport(game, "PALLET_TOWN", 10, 8, "down")
    U.wait(16)
    local entities = native.entities(game)
    assert(#entities == 6, "reload did not rebuild six visible followers")
    local shotDir = os.getenv("SHOT_DIR") or "/tmp/follower-phase5"
    assert(U.shot(game, shotDir .. "/" .. version .. "-reloaded-custom.png"),
      "reload screenshot failed")
    game.save._followerPhase5Probe.stage = 2
    assert(game:writeSave(), "Phase-5 reload save write failed")
    U.log("FOLLOWER PHASE 5 RELOAD PASS", version,
      "count=6 custom stable ids no duplicate")
    love.event.quit(0)
    return
  end

  game.save.flags = game.save.flags or {}
  game.save.flags.EVENT_FOLLOWED_OAK_INTO_LAB = true
  game.save.flags.EVENT_GOT_STARTER = true
  game.save.flags.EVENT_GOT_POKEDEX = true
  game.save.onBike = false
  game.save.repelSteps = 9999
  game.save.player.name = "PHASE5"

  local firstSpecies = version == "red" and "PIKACHU"
    or version == "blue" and "RAICHU" or "GOROCHU"
  local partner = Pokemon.new(game.data, firstSpecies, 30)
  local espeon = Pokemon.new(game.data, "ESPEON", 30)
  local scizor = Pokemon.new(game.data, "SCIZOR", 30)
  local tyranitar = Pokemon.new(game.data, "TYRANITAR", 30)
  local lapras = Pokemon.new(game.data, "LAPRAS", 30)
  local charizard = Pokemon.new(game.data, "CHARIZARD", 30)
  if version == "yellow" then partner[yellowPartner.marker] = true end
  game.save.party = { partner, espeon, scizor, tyranitar, lapras, charizard }
  Boxes.ensure(game.save)

  U.teleport(game, "PALLET_TOWN", 10, 8, "down")
  U.wait(12)
  config.setMode("party")
  for count = 1, 6 do
    config.setCount(count)
    U.wait(3)
    assert(#native.entities(game) == count,
      "PARTY runtime count failed: " .. count)
  end

  -- Exercise the actual party UI: choose ESPEON, open its native submenu,
  -- invoke FOLLOWER, then activate USE CUSTOM + ADD in the ListMenu.
  local partyMenu = PartyMenu.new(game)
  partyMenu.index = 2
  game.stack:push(partyMenu)
  U.tap(game, "a")
  assert(partyMenu.submenu and partyMenu.subItems,
    "party submenu did not open")
  local followerIndex
  for index, item in ipairs(partyMenu.subItems) do
    if item.label == "FOLLOWER" or item.label == "BEGLEITER" then
      followerIndex = index
      break
    end
  end
  assert(followerIndex, "FOLLOWER action missing from real party menu")
  partyMenu.subIndex = followerIndex
  U.tap(game, "a")
  local editor = game.stack:top()
  assert(editor ~= partyMenu and editor.items and #editor.items == 1,
    "compact custom-order editor did not open")
  local shotDir = os.getenv("SHOT_DIR") or "/tmp/follower-phase5"
  assert(U.shot(game, shotDir .. "/" .. version .. "-party-editor.png"),
    "party editor screenshot failed")
  U.tap(game, "a")
  assert(config.mode() == "custom" and config.customIds()[1]
      == espeon[config.monKey],
    "party editor did not select ESPEON for CUSTOM")
  while game.stack:top() and game.stack:top() ~= game.overworld do
    game.stack:pop()
  end

  -- Deliberately differ from battle-party order.
  assert(config.add(tyranitar) and config.add(partner) and config.add(scizor)
      and config.add(lapras) and config.add(charizard),
    "could not complete custom priority")
  config.setCount(6)
  U.wait(6)
  local expected = version == "yellow"
    and { "GOROCHU", "ESPEON", "TYRANITAR", "SCIZOR", "LAPRAS", "CHARIZARD" }
    or { "ESPEON", "TYRANITAR", firstSpecies, "SCIZOR", "LAPRAS", "CHARIZARD" }

  local function assertOrder(wanted, label)
    local rows = native.activeMons(game)
    assert(#rows == #wanted,
      label .. ": wrong count " .. tostring(#rows))
    local seen = {}
    for index, species in ipairs(wanted) do
      assert(rows[index].mon.species == species,
        ("%s #%d expected %s, got %s"):format(
          label, index, species, tostring(rows[index].mon.species)))
      assert(not seen[rows[index].mon], label .. ": duplicate follower")
      seen[rows[index].mon] = true
    end
  end
  assertOrder(expected, "CUSTOM order")
  assert(game.save.party[1] == partner and game.save.party[2] == espeon,
    "CUSTOM reordered the battle party")

  local espeonId = espeon[config.monKey]
  Evolution.apply(game, espeon, "UMBREON", "FOLLOWER_PHASE5_E2E")
  U.wait(4)
  assert(espeon[config.monKey] == espeonId,
    "evolution changed stable custom identity")
  expected[version == "yellow" and 2 or 1] = "UMBREON"
  assertOrder(expected, "after evolution")

  -- Real box helper: unavailable custom member is skipped; withdrawing the
  -- same object restores its previous priority.
  table.remove(game.save.party, 4)
  assert(Boxes.deposit(game.save, tyranitar), "box deposit failed")
  native.refresh(game)
  U.wait(3)
  assert(#native.activeMons(game) == 5, "boxed custom member was not skipped")
  local box = game.save.boxes[game.save.currentBox]
  local withdrawn = table.remove(box, #box)
  assert(withdrawn == tyranitar, "wrong Pokemon withdrawn")
  game.save.party[#game.save.party + 1] = withdrawn
  native.refresh(game)
  U.wait(3)
  assertOrder(expected, "after withdraw")

  -- PARTY follows battle order; CUSTOM restores the independent priority.
  game.save.party = { scizor, tyranitar, espeon, partner, charizard, lapras }
  config.setMode("party")
  U.wait(3)
  local partyExpected = version == "yellow"
    and { "GOROCHU", "SCIZOR", "TYRANITAR", "UMBREON", "CHARIZARD", "LAPRAS" }
    or { "SCIZOR", "TYRANITAR", "UMBREON", firstSpecies, "CHARIZARD", "LAPRAS" }
  assertOrder(partyExpected, "PARTY after reorder")
  config.setMode("custom")
  U.wait(3)
  assertOrder(expected, "CUSTOM restored")

  if version == "yellow" then
    -- KA-INTERNAL: YELLOW-PRESENTATION-001
    partner.species = "RAICHU"
    native.refresh(game)
    U.wait(2)
    config.setPresentation("ascendant_box")
    Follower.talk(game, game.overworld, native.entity(game), function() end)
    assert(game.overworld.emote
        and game.overworld.emote._ascendantRaichuPortrait == true,
      "Ascendant partner box presentation did not activate")
    U.wait(2)
    assert(U.shot(game, shotDir .. "/yellow-raichu-ascendant-box.png"),
      "Ascendant box screenshot failed")
    game.overworld.emote = nil
    config.setPresentation("yellow_center")
    Follower.talk(game, game.overworld, native.entity(game), function() end)
    assert(game.overworld.emote
        and game.overworld.emote._ascendantRaichuPortrait == false,
      "Yellow-centered partner presentation did not activate")
    U.wait(2)
    assert(U.shot(game, shotDir .. "/yellow-raichu-centered-box.png"),
      "Yellow-centered screenshot failed")
    game.overworld.emote = nil
    partner.species = "GOROCHU"
    native.refresh(game)
    U.wait(2)
    assertOrder(expected, "Gorochu restored after presentation QA")
  end

  assert(U.shot(game, shotDir .. "/" .. version .. "-custom-chain.png"),
    "custom-chain screenshot failed")
  game.save._followerPhase5Probe = {
    stage = 1,
    expected = expected,
    presentation = config.presentation(),
  }
  assert(game:writeSave(), "Phase-5 save write failed")
  U.log("FOLLOWER PHASE 5 WRITE PASS", version,
    "party UI custom evolution box count options presentation")
  love.event.quit(0)
end
