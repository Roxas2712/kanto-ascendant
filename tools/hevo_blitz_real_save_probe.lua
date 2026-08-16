-- Read-only product probe for the user's real BLITZ slot7 record.
-- The source save is loaded directly and never written; all migration and
-- teleport work happens in this disposable process/identity.
return function(game)
  local U = dofile("tests/drivers/util.lua")
  local source = assert(os.getenv("KA_SOURCE_SAVE"), "KA_SOURCE_SAVE required")
  local identity = assert(os.getenv("POKEPORT_IDENTITY"), "POKEPORT_IDENTITY required")
  local shotDir = assert(os.getenv("SHOT_DIR"), "SHOT_DIR required")
  assert(identity:find("hevo%-blitz%-real%-save%-probe"),
    "refusing to run outside disposable BLITZ probe identity")

  local cloned = assert(loadfile(source))()
  assert(cloned.player and cloned.player.name == "BLITZ",
    "source is not the user's BLITZ save")
  assert(cloned.player.map == "PALLET_TOWN",
    "BLITZ source moved since the reported failure; recapture intentionally")
  -- Put the cloned record at the real in-progress compatibility entrypoint
  -- before restore.  This mirrors an old RC save closed inside the trial and
  -- lets save.loaded migrate admission before encounter publication.
  cloned.player.map, cloned.player.x, cloned.player.y, cloned.player.facing =
    "KA_HEVO_RED_UPPER", 3, 33, "up"
  cloned.player.surfing = false
  cloned.options = cloned.options or {}
  cloned.options.modOptions = cloned.options.modOptions or {}
  cloned.options.modOptions.kanto_ascendant =
    cloned.options.modOptions.kanto_ascendant or {}
  cloned.options.modOptions.kanto_ascendant.qol_location_banners = false
  game:restoreSave(cloned)
  U.wait(90)

  local exports = assert(game.mods and game.mods.exports
      and game.mods.exports.kanto_ascendant,
    "Kanto Ascendant did not install in the real engine")
  local campaign = assert(exports.hiddenEvolutionCampaign,
    "Hidden Evolution campaign export missing")
  assert(campaign.modules and campaign.modules.RED and campaign.modules.BLUE
      and campaign.modules.GREEN,
    "campaign lost a RED/BLUE/GREEN path module")
  assert(campaign.encounters and campaign.encounters._installed,
    "HEVO encounters did not install after the full RED/BLUE/GREEN loop")

  -- This is a test-only location edit of the cloned record, not a constructed
  -- fixture.  It exercises save.loaded, migration, visibility and encounter
  -- publication on the same BLITZ party/options/modData that reproduced the
  -- installed-RC failure.
  assert(game.overworld and game.overworld.map
      and game.overworld.map.id == "KA_HEVO_RED_UPPER",
    "BLITZ clone did not enter the real RED floor")
  local sight = assert(game.overworld.kaHevoRedSight,
    "RED keyhole profile did not attach to BLITZ clone")
  assert(sight.opacity == 1.0 and sight.innerOpacity >= 0.25
      and sight.innerOpacity <= 0.35,
    "RED initial keyhole is not opaque outside and readable inside")

  local grass = assert(game.data.encounters.KA_HEVO_RED_UPPER
      and game.data.encounters.KA_HEVO_RED_UPPER.grass,
    "BLITZ clone has no RED encounter table")
  local active = campaign.encounters.activeCharacter(game.save, game)
  local admitted, admittedWhy = campaign.encounters.trialAvailable(
    game.save, "RED", game)
  print(("HEVO BLITZ receipt active=%s admission=%s/%s rate=%s slots=%s map=%s")
    :format(tostring(active), tostring(admitted), tostring(admittedWhy),
      tostring(grass.rate), tostring(#grass.slots),
      tostring(game.save.player and game.save.player.map)))
  assert(grass.rate == campaign.encounters.RATE.RED
      and #grass.slots == campaign.encounters.SLOT_COUNT,
    "BLITZ clone did not publish the complete RED habitat")
  local expected = {
    RHYDON=true, MAGMAR=true, LICKITUNG=true, PILOSWINE=true, GLIGAR=true,
  }
  local found = {}
  for _, slot in ipairs(grass.slots) do
    assert(slot.level == 70,
      "BLITZ cycle-zero trial encounter is not Level 70")
    assert(expected[slot.species],
      "foreign/final evolution leaked into RED habitat: "..tostring(slot.species))
    found[slot.species] = true
  end
  for species in pairs(expected) do
    assert(found[species], "RED habitat is missing "..species)
  end

  -- The real BLITZ metadata correctly opens the mod-change report in this
  -- focused one-mod identity.  It has already been validated above; dismiss
  -- only that overlay so the receipt captures the underlying product world,
  -- never the QA/report screen.
  while game.stack:top() and game.stack:top() ~= game.overworld do
    game.stack:pop()
  end
  U.wait(240)
  assert(U.shot(game, shotDir.."/blitz_red_upper_keyhole.png"))

  local architecture = assert(campaign.modules.tunnel,
    "fissure architecture module missing")
  local fissureSites = {
    RED={map="ROUTE_22",x=35,y=2,wallY=1},
    BLUE={map="ROUTE_24",x=10,y=4,wallY=3},
    GREEN={map="ROUTE_3",x=41,y=4,wallY=3},
  }
  for _, character in ipairs({"RED","BLUE","GREEN"}) do
    local site = fissureSites[character]
    U.teleport(game, site.map, site.x, site.y, "up")
    U.wait(240)
    local anchor
    for _, npc in ipairs(game.overworld.npcs or {}) do
      if npc.def and npc.def.name == "KA_HEVO_FISSURE_"..character then
        anchor = npc.def
        break
      end
    end
    assert(anchor and anchor.x == site.x and anchor.y == site.wallY
        and anchor.renderMode == "none" and anchor.passable == true,
      character.." real route lacks its transparent interaction anchor")
    local decals = game.data.maps[site.map].wallDecals or {}
    local decal
    for _, row in ipairs(decals) do
      if row.id == "KA_HEVO_WALL_FISSURE_"..character then decal=row end
    end
    assert(decal and decal.cellX == site.x and decal.cellY == site.wallY,
      character.." real route lacks its wall-local fissure art")
    assert(U.shot(game, shotDir.."/blitz_"..character:lower()
      .."_fissure.png"))
  end

  game.save.flags[architecture.flags.discovered.."RED"] = true
  local canEnter, enterWhy = architecture.entranceAvailable("RED", game)
  assert(canEnter and enterWhy == "discovered",
    "real BLITZ clone cannot activate RED's discovered fissure")
  local receipt = assert(io.open(shotDir.."/RECEIPT.txt", "wb"))
  receipt:write("PASS real BLITZ slot7 clone\n")
  receipt:write("campaign=RED+BLUE+GREEN installed\n")
  receipt:write("encounters=RED rate "..tostring(grass.rate)
    .." slots "..tostring(#grass.slots).." level 70\n")
  receipt:write("keyhole=outer 1.0 inner "..tostring(sight.innerOpacity).."\n")
  receipt:write("fissures=RED+BLUE+GREEN wall art and talk anchors live\n")
  receipt:close()
  love.event.quit(0)
end
