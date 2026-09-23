-- Kanto Ascendant 6.7 hidden-habitat reveal contract (Access V3.1).
--
-- This module deliberately separates three concerns:
--   * pure validation/resolution of authored entrance definitions;
--   * the persistent TRACE FINDER receipt owned by exploration_device.lua;
--   * a renderer-neutral runtime adapter using only public Gen1Recomp seams.
--
-- Gen1Recomp 0.1.96/0.1.98 do not expose a supported way to add a live
-- walk-on warp.  Guarded mode therefore uses map_scripts.onStep (and onInteract) plus
-- mod.world:warpTo after the receipt.  It is invisible and collision-free
-- before and after discovery.  A future setConditionalWarp adapter can opt
-- into native walk-on behaviour without changing this contract.  Never write
-- map.warpAt here: it is an engine-private cache (and a Gen-2 name collision).

return function(mod, device, opts)
  opts = opts or {}

  local H = {
    MODE_GUARDED = "guarded",
    MODE_LEGACY_DIRECT = "legacy_direct",
    TRANSPORT_INTERACT = "conditional_interact",
    TRANSPORT_NATIVE = "conditional_warp",
    ENGINE_SEAM = "setConditionalWarp",
  }

  local function copy(value, seen)
    if type(value) ~= "table" then return value end
    seen = seen or {}
    if seen[value] then return seen[value] end
    local out = {}
    seen[value] = out
    for key, child in pairs(value) do out[copy(key, seen)] = copy(child, seen) end
    return out
  end

  local function integer(value)
    return type(value) == "number" and value == math.floor(value)
  end

  local function point(value)
    return type(value) == "table" and integer(value.x) and integer(value.y)
  end

  local function cellKey(x, y)
    return tostring(x) .. "," .. tostring(y)
  end

  local function blockKey(x, y)
    return tostring(x) .. ":" .. tostring(y)
  end

  local function editionSet(value)
    local out = {}
    if type(value) ~= "table" then return out end
    for key, child in pairs(value) do
      if type(key) == "number" and type(child) == "string" then
        out[child:lower()] = true
      elseif type(key) == "string" and child == true then
        out[key:lower()] = true
      end
    end
    return out
  end

  local function direction(dx, dy, fallback)
    if dx == 0 and dy == 0 then return fallback or "north" end
    if math.abs(dx) > math.abs(dy) then return dx > 0 and "east" or "west" end
    return dy > 0 and "south" or "north"
  end

  local function patch(bx, by, closed, opened)
    return {
      bx = bx, by = by, from = closed, to = opened,
      fromByEdition = { red = closed, blue = closed, yellow = closed },
    }
  end

  local function entrance(row)
    -- Newer Gen-I engines expose a live, owner-scoped edge exit.  Prefer the
    -- natural walk-off transition there; older supported engines retain the
    -- receipt-gated walk-on handoff without touching private map internals.
    local nativeEdgeWarp = mod and mod.world
      and type(mod.world.addEdgeWarp) == "function"
      and row.eligibility.kind == "starter"
    local def = {
      id = row.id,
      editions = { red = true, blue = true, yellow = true },
      mapId = row.mapId,
      mapIndex = row.mapIndex,
      reveal = row.reveal,
      revealDirection = row.revealDirection,
      sourceMode = row.sourceMode or "LAND",
      path = row.path or {},
      patches = row.patches,
      warp = row.warp,
      handoff = {
        kind = nativeEdgeWarp and H.TRANSPORT_NATIVE
          or H.TRANSPORT_INTERACT,
        interactFrom = row.interactFrom,
        edgeDirection = row.edgeDirection or row.revealDirection,
        destination = row.destination,
      },
      returnToKanto = {
        map = row.mapId, mapIndex = row.mapIndex,
        x = row.returnCell.x, y = row.returnCell.y,
        facing = row.returnCell.facing or row.revealDirection,
        mode = "LAND",
      },
      wilds = {
        reservedRect = row.reservedRect,
        protected = row.protected or {},
      },
      eligibility = row.eligibility,
      role = row.role,
      starter = row.starter,
      progression = row.progression,
      presentation = {
        sound = "Cut", effect = "dust",
        physicalKind = row.physicalKind,
        physical = row.physical,
        motion = row.motion,
        movesExistingObstacle = true,
        introducesGeometry = false,
      },
    }
    return def
  end

  local function starter(family, generation)
    return { kind = "starter", family = family, generation = generation,
      minimumStage = "sighted" }
  end

  local function legend(profile, species)
    return { kind = "profile_legend", profile = profile, species = species,
      requiresProfileSeal = true }
  end

  local rows = {
    entrance({ id="VIRIDIAN_TOP_HIDDEN_HABITAT", mapId="VIRIDIAN_CITY", mapIndex=1,
      reveal={x=8,y=4}, revealDirection="north", path={{x=8,y=3},{x=8,y=2},{x=8,y=1}},
      patches={patch(4,0,0x0f,0x4d),patch(4,1,0x0f,0x4d)}, warp={x=8,y=0},
      interactFrom={x=8,y=1,facing="up"}, returnCell={x=8,y=4,facing="down"},
      destination={map="KA_HABITAT_TURTWIG_PROTOTYPE",mapIndex=2000,x=11,y=17,facing="up"},
      reservedRect={xMin=7,xMax=10,yMin=0,yMax=5}, eligibility=starter("TURTWIG","gen4"),
      starter="TURTWIG", role="STARTER_PRIMARY", physicalKind="ROCK_WALL",
      physical="existing paired root/rock boundary column", motion="ROLLS" }),
    entrance({ id="ROUTE14_SURF_HIDDEN_HABITAT", mapId="ROUTE_14", mapIndex=25,
      -- Reveal from the reachable north side of the native boulder row.
      -- The former water-side point (18,51) was beyond the very barrier
      -- this reveal opens, making the finder direct players into the wall.
      reveal={x=12,y=49}, revealDirection="south", edgeDirection="east", sourceMode="SURF",
      path={{x=12,y=50},{x=12,y=51},{x=13,y=51},{x=14,y=51},
        {x=15,y=51},{x=16,y=51},{x=17,y=51},{x=18,y=51}},
      patches={patch(6,25,0x51,0x53)}, warp={x=19,y=51},
      interactFrom={x=18,y=51,facing="right"}, returnCell={x=17,y=51,facing="left"},
      destination={map="KA_HABITAT_SNIVY_PROTOTYPE",mapIndex=2001,x=13,y=15,facing="up"},
      reservedRect={xMin=11,xMax=19,yMin=48,yMax=53}, eligibility=starter("SNIVY","gen5"),
      starter="SNIVY", role="STARTER_PRIMARY", physicalKind="POSTS",
      physical="two existing round shore posts/boulders over native ground", motion="FOLDS" }),
    entrance({ id="VIRIDIAN_FOREST_ROOT_HABITAT", mapId="VIRIDIAN_FOREST", mapIndex=51,
      reveal={x=11,y=40}, revealDirection="north", patches={patch(5,19,0x02,0x18)},
      warp={x=11,y=39}, interactFrom={x=11,y=40,facing="up"},
      returnCell={x=11,y=40,facing="down"},
      destination={map="KA_HABITAT_CHESPIN_PROTOTYPE",mapIndex=2002,x=11,y=17,facing="up"},
      reservedRect={xMin=10,xMax=12,yMin=38,yMax=41}, eligibility=starter("CHESPIN","gen6"),
      starter="CHESPIN", role="STARTER_PRIMARY", physicalKind="ROOT_WALL",
      physical="interlocked canopy roots/trunks", motion="LIFTS" }),
    entrance({ id="ROUTE15_HIDDEN_HABITAT", mapId="ROUTE_15", mapIndex=26,
      reveal={x=56,y=4}, revealDirection="north", path={{x=56,y=3},{x=56,y=2},{x=56,y=1}},
      patches={patch(28,0,0x13,0x4d),patch(28,1,0x13,0x4d)}, warp={x=56,y=0},
      interactFrom={x=56,y=1,facing="up"}, returnCell={x=56,y=4,facing="down"},
      destination={map="KA_HABITAT_ROWLET_PROTOTYPE",mapIndex=2003,x=11,y=15,facing="up"},
      reservedRect={xMin=55,xMax=58,yMin=0,yMax=5}, eligibility=starter("ROWLET","gen7"),
      starter="ROWLET", role="STARTER_PRIMARY", physicalKind="HEDGE",
      physical="existing stacked hedge/root/rock boundary column", motion="ROLLS" }),
    entrance({ id="MT_MOON_B1F_HIDDEN_HABITAT", mapId="MT_MOON_B1F", mapIndex=60,
      reveal={x=9,y=16}, revealDirection="north", patches={patch(4,7,0x3f,0x19)},
      warp={x=9,y=15}, interactFrom={x=9,y=16,facing="up"}, returnCell={x=9,y=16,facing="down"},
      destination={map="KA_HABITAT_CHIMCHAR_PROTOTYPE",mapIndex=2004,x=12,y=17,facing="up"},
      reservedRect={xMin=8,xMax=10,yMin=14,yMax=17}, eligibility=starter("CHIMCHAR","gen4"),
      starter="CHIMCHAR", role="STARTER_BACKUP", physicalKind="RUBBLE",
      physical="existing rock/rubble seam", motion="RETRACTS" }),
    entrance({ id="ROUTE4_HIDDEN_HABITAT", mapId="ROUTE_4", mapIndex=15,
      reveal={x=36,y=2}, revealDirection="north", path={{x=36,y=1}},
      patches={patch(18,0,0x57,0x4d)}, warp={x=36,y=0},
      interactFrom={x=36,y=1,facing="up"}, returnCell={x=36,y=2,facing="down"},
      destination={map="KA_HABITAT_TEPIG_PROTOTYPE",mapIndex=2006,x=12,y=19,facing="up"},
      reservedRect={xMin=35,xMax=38,yMin=0,yMax=3}, eligibility=starter("TEPIG","gen5"),
      starter="TEPIG", role="STARTER_BACKUP", physicalKind="BOULDER",
      physical="existing north-edge ridge stones", motion="RETRACTS",
      progression={from={map="MT_MOON_B1F",x=24,y=5},to={map="ROUTE_4",x=36,y=2},
        normalLandSteps=17,directedLedgeJumps=0} }),
    entrance({ id="ROUTE6_HIDDEN_HABITAT", mapId="ROUTE_6", mapIndex=17,
      reveal={x=4,y=29}, revealDirection="west",
      path={{x=3,y=29},{x=2,y=29},{x=1,y=29},{x=0,y=29}},
      patches={patch(0,14,0x51,0x0a),patch(1,14,0x63,0x0a)}, warp={x=0,y=28},
      interactFrom={x=0,y=29,facing="up"}, returnCell={x=4,y=29,facing="right"},
      destination={map="KA_HABITAT_PIPLUP_PROTOTYPE",mapIndex=2005,x=12,y=19,facing="up"},
      reservedRect={xMin=0,xMax=5,yMin=27,yMax=31}, eligibility=starter("PIPLUP","gen4"),
      starter="PIPLUP", role="STARTER_BACKUP", physicalKind="LOG",
      physical="existing west-edge boulder/hedge/log boundary", motion="FOLDS" }),
    entrance({ id="ROUTE8_HIDDEN_HABITAT", mapId="ROUTE_8", mapIndex=19,
      reveal={x=54,y=4}, revealDirection="north", path={{x=54,y=3},{x=54,y=2},{x=54,y=1}},
      patches={patch(27,0,0x25,0x74),patch(27,1,0x0f,0x74)}, warp={x=54,y=0},
      interactFrom={x=54,y=1,facing="up"}, returnCell={x=54,y=4,facing="down"},
      destination={map="KA_HABITAT_FENNEKIN_PROTOTYPE",mapIndex=2008,x=10,y=17,facing="up"},
      reservedRect={xMin=53,xMax=55,yMin=0,yMax=5}, eligibility=starter("FENNEKIN","gen6"),
      starter="FENNEKIN", role="STARTER_BACKUP", physicalKind="BOULDER",
      physical="two stacked ridge/boulder rows", motion="RETRACTS" }),
    entrance({ id="ROCK_TUNNEL_1F_SKY_PILLAR_ACCESS", mapId="ROCK_TUNNEL_1F", mapIndex=82,
      reveal={x=37,y=25}, revealDirection="east", path={{x=38,y=25}},
      patches={patch(19,12,0x17,0x01)}, warp={x=39,y=25},
      interactFrom={x=38,y=25,facing="right"}, returnCell={x=37,y=25,facing="left"},
      destination={map="KA_HEVO_RAYQUAZA_CHAMBER",mapIndex=1986,x=8,y=11,facing="up"},
      reservedRect={xMin=36,xMax=39,yMin=23,yMax=27}, eligibility=legend("GREEN","RAYQUAZA"),
      role="LEGEND_RAYQUAZA_BACKUP", physicalKind="ROCK_WALL",
      physical="existing rock-wall seam/plug", motion="SLIDES" }),
    entrance({ id="ROUTE10_HIDDEN_HABITAT", mapId="ROUTE_10", mapIndex=21,
      reveal={x=17,y=62}, revealDirection="east", path={{x=18,y=62}},
      patches={patch(9,31,0x28,0x7a)}, warp={x=19,y=62},
      interactFrom={x=18,y=62,facing="right"}, returnCell={x=17,y=62,facing="left"},
      destination={map="KA_HABITAT_LITTEN_PROTOTYPE",mapIndex=2010,x=12,y=19,facing="up"},
      reservedRect={xMin=16,xMax=19,yMin=60,yMax=64}, eligibility=starter("LITTEN","gen7"),
      starter="LITTEN", role="STARTER_BACKUP", physicalKind="BOULDER",
      physical="existing east cliff stones", motion="RETRACTS" }),
    entrance({ id="CELADON_HIDDEN_HABITAT", mapId="CELADON_CITY", mapIndex=6,
      reveal={x=20,y=34}, revealDirection="south", patches={patch(10,17,0x6f,0x0a)},
      warp={x=20,y=35}, interactFrom={x=20,y=34,facing="down"},
      returnCell={x=20,y=34,facing="up"},
      destination={map="KA_HABITAT_FENNEKIN_PROTOTYPE",mapIndex=2008,x=10,y=17,facing="up"},
      reservedRect={xMin=19,xMax=22,yMin=32,yMax=35}, eligibility=starter("FENNEKIN","gen6"),
      starter="FENNEKIN", role="STARTER_BACKUP", physicalKind="BOULDER",
      physical="existing bottom-edge boulders/hedge", motion="ROLLS" }),
    entrance({ id="ROUTE12_HIDDEN_HABITAT", mapId="ROUTE_12", mapIndex=23,
      reveal={x=2,y=61}, revealDirection="west", path={{x=1,y=61}},
      patches={patch(0,30,0x36,0x6c)}, warp={x=0,y=61},
      interactFrom={x=1,y=61,facing="left"}, returnCell={x=2,y=61,facing="right"},
      destination={map="KA_HABITAT_OSHAWOTT_PROTOTYPE",mapIndex=2007,x=12,y=19,facing="up"},
      reservedRect={xMin=0,xMax=2,yMin=60,yMax=62}, eligibility=starter("OSHAWOTT","gen5"),
      starter="OSHAWOTT", role="STARTER_BACKUP", physicalKind="BOULDER",
      physical="single native lower boundary boulder", motion="RETRACTS" }),
    entrance({ id="FUCHSIA_HIDDEN_HABITAT", mapId="FUCHSIA_CITY", mapIndex=7,
      -- The original reveal point was inside the closed zoo enclosure.
      -- Open a narrow empty edge column from the public path instead.
      reveal={x=34,y=8}, revealDirection="north", path={{x=34,y=7},{x=34,y=6},
        {x=34,y=5},{x=34,y=4},{x=34,y=3},{x=34,y=2},{x=34,y=1}},
      patches={patch(17,0,0x0f,0x01),patch(17,1,0x6f,0x01),patch(17,3,0x77,0x01)}, warp={x=34,y=0},
      interactFrom={x=34,y=1,facing="up"}, returnCell={x=34,y=8,facing="down"},
      destination={map="KA_HABITAT_POPPLIO_PROTOTYPE",mapIndex=2011,x=14,y=19,facing="up"},
      reservedRect={xMin=33,xMax=36,yMin=0,yMax=9}, eligibility=starter("POPPLIO","gen7"),
      starter="POPPLIO", role="STARTER_BACKUP", physicalKind="BOULDER",
      physical="stacked inner/outer boulder/shrub rows", motion="PARTS" }),
    entrance({ id="SEAFOAM_KYOGRE_ACCESS", mapId="SEAFOAM_ISLANDS_1F", mapIndex=192,
      reveal={x=15,y=2}, revealDirection="north", path={{x=15,y=1}},
      patches={patch(7,0,0x2e,0x15)}, warp={x=15,y=0},
      interactFrom={x=15,y=1,facing="up"}, returnCell={x=15,y=2,facing="down"},
      destination={map="KA_HEVO_KYOGRE_CHAMBER",mapIndex=1985,x=8,y=11,facing="up"},
      reservedRect={xMin=14,xMax=16,yMin=0,yMax=3}, eligibility=legend("BLUE","KYOGRE"),
      role="LEGEND_KYOGRE_BACKUP", physicalKind="ICE_PANEL",
      physical="native ice/rock slab", motion="SLIDES" }),
    entrance({ id="ROUTE18_HIDDEN_HABITAT", mapId="ROUTE_18", mapIndex=29,
      reveal={x=36,y=16}, revealDirection="south", patches={patch(18,8,0x52,0x0b)},
      warp={x=36,y=17}, interactFrom={x=36,y=16,facing="down"},
      returnCell={x=36,y=16,facing="up"},
      destination={map="KA_HABITAT_CHIMCHAR_PROTOTYPE",mapIndex=2004,x=12,y=17,facing="up"},
      reservedRect={xMin=35,xMax=38,yMin=14,yMax=17}, eligibility=starter("CHIMCHAR","gen4"),
      starter="CHIMCHAR", role="STARTER_BACKUP", physicalKind="HEDGE",
      physical="existing south-edge hedge/ground stones", motion="FOLDS" }),
    entrance({ id="ROUTE21_HIDDEN_HABITAT", mapId="ROUTE_21", mapIndex=32,
      reveal={x=1,y=25}, revealDirection="west", sourceMode="SURF",
      patches={patch(0,12,0x18,0x43)}, warp={x=0,y=25},
      interactFrom={x=1,y=25,facing="left"}, returnCell={x=4,y=25,facing="right"},
      destination={map="KA_HABITAT_POPPLIO_PROTOTYPE",mapIndex=2011,x=14,y=19,facing="up"},
      reservedRect={xMin=0,xMax=3,yMin=23,yMax=26}, protected={{x=4,y=25}},
      eligibility=starter("POPPLIO","gen7"), starter="POPPLIO", role="STARTER_BACKUP",
      physicalKind="POSTS", physical="existing coastal piling/boulder/log barrier",
      motion="RETRACTS" }),
    entrance({ id="ROUTE25_HIDDEN_HABITAT", mapId="ROUTE_25", mapIndex=36,
      reveal={x=28,y=2}, revealDirection="north", path={{x=28,y=1}},
      patches={patch(14,0,0x57,0x74)}, warp={x=28,y=0},
      interactFrom={x=28,y=1,facing="up"}, returnCell={x=28,y=2,facing="down"},
      destination={map="KA_HABITAT_FROAKIE_PROTOTYPE",mapIndex=2009,x=10,y=17,facing="up"},
      reservedRect={xMin=27,xMax=30,yMin=0,yMax=3}, eligibility=starter("FROAKIE","gen6"),
      starter="FROAKIE", role="STARTER_BACKUP", physicalKind="BOULDER",
      physical="existing top ridge stones", motion="RETRACTS" }),
    entrance({ id="ROUTE23_SKY_PILLAR_ACCESS", mapId="ROUTE_23", mapIndex=34,
      reveal={x=18,y=111}, revealDirection="east", patches={patch(9,55,0x2a,0x01)},
      warp={x=19,y=111}, interactFrom={x=18,y=111,facing="right"},
      returnCell={x=18,y=111,facing="left"},
      destination={map="KA_HEVO_RAYQUAZA_CHAMBER",mapIndex=1986,x=8,y=11,facing="up"},
      reservedRect={xMin=16,xMax=19,yMin=108,yMax=113}, eligibility=legend("GREEN","RAYQUAZA"),
      role="LEGEND_RAYQUAZA_PRIMARY", physicalKind="RUBBLE",
      physical="existing lower parapet boundary stone", motion="RETRACTS" }),
    entrance({ id="VICTORY_ROAD_JIRACHI_ACCESS", mapId="VICTORY_ROAD_1F", mapIndex=108,
      reveal={x=2,y=7}, revealDirection="west", path={{x=1,y=7}},
      patches={patch(0,3,0x7d,0x01)}, warp={x=0,y=7},
      interactFrom={x=1,y=7,facing="left"}, returnCell={x=2,y=7,facing="right"},
      destination={map="KA_HOENN_WISH_CHAMBER",mapIndex=1988,x=8,y=11,facing="up"},
      reservedRect={xMin=0,xMax=4,yMin=5,yMax=9}, eligibility={kind="jirachi_convergence",
        profiles={"RED","BLUE","GREEN"},requiresLegacyPass=true},
      role="JIRACHI_CONVERGENCE", physicalKind="RUBBLE",
      physical="existing rubble wall", motion="SLIDES" }),
    entrance({ id="POWER_PLANT_HIDDEN_HABITAT", mapId="POWER_PLANT", mapIndex=83,
      reveal={x=6,y=2}, revealDirection="north", path={{x=6,y=1}},
      patches={patch(3,0,0x61,0x0e)}, warp={x=6,y=0},
      interactFrom={x=6,y=1,facing="up"}, returnCell={x=6,y=2,facing="down"},
      destination={map="KA_HABITAT_TEPIG_PROTOTYPE",mapIndex=2006,x=12,y=19,facing="up"},
      reservedRect={xMin=5,xMax=8,yMin=0,yMax=4}, eligibility=starter("TEPIG","gen5"),
      starter="TEPIG", role="STARTER_BACKUP", physicalKind="MACHINERY",
      physical="existing machine-panel pair", motion="RETRACTS" }),
  }

  H.ORDER, H.ACCESS = {}, {}
  for _, def in ipairs(rows) do
    H.ORDER[#H.ORDER + 1] = def.mapId
    H.ACCESS[def.mapId] = def
  end
  -- Compatibility alias for the earlier isolated proof API.
  H.PROOF = H.ACCESS
  H.PROOF.ROUTE_14.presentation.solePhysicalGate = false

  local function proofShape(def)
    local parts = {
      tostring(def.mapId), tostring(def.mapIndex),
      tostring(def.reveal and def.reveal.x), tostring(def.reveal and def.reveal.y),
      tostring(def.revealDirection),
      tostring(def.warp and def.warp.x), tostring(def.warp and def.warp.y),
      tostring(def.handoff and def.handoff.kind),
      tostring(def.handoff and def.handoff.edgeDirection),
      tostring(def.handoff and def.handoff.interactFrom
        and def.handoff.interactFrom.x),
      tostring(def.handoff and def.handoff.interactFrom
        and def.handoff.interactFrom.y),
      tostring(def.handoff and def.handoff.interactFrom
        and def.handoff.interactFrom.facing),
      tostring(def.returnToKanto and def.returnToKanto.map),
      tostring(def.returnToKanto and def.returnToKanto.x),
      tostring(def.returnToKanto and def.returnToKanto.y),
      tostring(def.returnToKanto and def.returnToKanto.facing),
      tostring(def.returnToKanto and def.returnToKanto.mapIndex),
      tostring(def.returnToKanto and def.returnToKanto.mode),
      tostring(def.handoff and def.handoff.destination
        and def.handoff.destination.map),
      tostring(def.handoff and def.handoff.destination
        and def.handoff.destination.mapIndex),
      tostring(def.handoff and def.handoff.destination
        and def.handoff.destination.x),
      tostring(def.handoff and def.handoff.destination
        and def.handoff.destination.y),
      tostring(def.sourceMode), tostring(def.role), tostring(def.starter),
      tostring(def.eligibility and def.eligibility.kind),
      tostring(def.eligibility and def.eligibility.family),
      tostring(def.eligibility and def.eligibility.generation),
      tostring(def.eligibility and def.eligibility.profile),
      tostring(def.presentation and def.presentation.physical),
      tostring(def.presentation and def.presentation.physicalKind),
      tostring(def.presentation and def.presentation.motion),
    }
    local rect = def.wilds and def.wilds.reservedRect or {}
    parts[#parts + 1] = table.concat({ tostring(rect.xMin), tostring(rect.xMax),
      tostring(rect.yMin), tostring(rect.yMax) }, ":")
    for _, patch in ipairs(type(def.patches) == "table" and def.patches or {}) do
      parts[#parts + 1] = table.concat({
        tostring(patch.bx), tostring(patch.by),
        tostring(patch.fromByEdition and patch.fromByEdition.red),
        tostring(patch.fromByEdition and patch.fromByEdition.blue),
        tostring(patch.fromByEdition and patch.fromByEdition.yellow),
        tostring(patch.to),
      }, ":")
    end
    return table.concat(parts, "|")
  end

  local acceptedProofShapes = {}
  for _, def in pairs(H.PROOF) do acceptedProofShapes[def.id] = proofShape(def) end

  local allowedObstacle = {}
  for _, value in ipairs({ "LOG", "TREE", "HEDGE", "BOULDER", "RUBBLE",
      "POSTS", "ICE_PANEL", "MACHINERY", "ROOT_WALL", "ROCK_WALL" }) do
    allowedObstacle[value] = true
  end

  local function nonNegativePoint(value)
    return point(value) and value.x >= 0 and value.y >= 0
  end

  local function validRect(rect)
    return type(rect) == "table" and integer(rect.xMin) and integer(rect.xMax)
      and integer(rect.yMin) and integer(rect.yMax) and rect.xMin >= 0
      and rect.yMin >= 0 and rect.xMin <= rect.xMax and rect.yMin <= rect.yMax
  end

  local function inRect(rect, value)
    return nonNegativePoint(value) and value.x >= rect.xMin and value.x <= rect.xMax
      and value.y >= rect.yMin and value.y <= rect.yMax
  end

  function H.validateDefinition(def)
    if type(def) ~= "table" then return false, "definition-not-table" end
    if type(def.id) ~= "string" or def.id == "" then return false, "invalid-id" end
    if type(def.mapId) ~= "string" or def.mapId == "" then return false, "invalid-map" end
    if not integer(def.mapIndex) or def.mapIndex < 0 then return false, "invalid-map-index" end
    if not nonNegativePoint(def.reveal) then return false, "invalid-reveal-point" end
    if not nonNegativePoint(def.warp) then return false, "invalid-warp-point" end
    if def.sourceMode ~= "LAND" and def.sourceMode ~= "SURF" then
      return false, "invalid-source-mode"
    end
    if not editionSet(def.editions).red and not editionSet(def.editions).blue
        and not editionSet(def.editions).yellow then
      return false, "no-supported-edition"
    end
    if type(def.patches) ~= "table" or #def.patches < 1 or #def.patches > 3 then
      return false, "patch-count-must-be-one-to-three"
    end
    local seen = {}
    for _, patch in ipairs(def.patches) do
      local from = patch.fromByEdition
      if not (integer(patch.bx) and patch.bx >= 0 and integer(patch.by)
          and patch.by >= 0 and type(from) == "table"
          and integer(from.red) and from.red >= 0 and from.red <= 255
          and integer(from.blue) and from.blue >= 0 and from.blue <= 255
          and integer(from.yellow) and from.yellow >= 0 and from.yellow <= 255
          and patch.from == from.red and integer(patch.to) and patch.to >= 0
          and patch.to <= 255 and from.red ~= patch.to
          and from.blue ~= patch.to and from.yellow ~= patch.to) then
        return false, "invalid-block-patch"
      end
      local key = blockKey(patch.bx, patch.by)
      if seen[key] then return false, "duplicate-block-patch" end
      seen[key] = true
    end
    local handoff = def.handoff
    if type(handoff) ~= "table" or (handoff.kind ~= H.TRANSPORT_INTERACT
        and handoff.kind ~= H.TRANSPORT_NATIVE) then
      return false, "invalid-handoff"
    end
    if handoff.kind == H.TRANSPORT_INTERACT
        and not nonNegativePoint(handoff.interactFrom) then
      return false, "invalid-interaction-approach"
    end
    if type(handoff.destination) ~= "table"
        or type(handoff.destination.map) ~= "string"
        or handoff.destination.map == ""
        or handoff.destination.map:find("__KA_PROOF_", 1, true) == 1
        or not integer(handoff.destination.mapIndex)
        or handoff.destination.mapIndex < 0
        or not nonNegativePoint(handoff.destination) then
      return false, "invalid-destination"
    end
    local back = def.returnToKanto
    if type(back) ~= "table" or back.map ~= def.mapId
        or back.mapIndex ~= def.mapIndex or back.mode ~= "LAND"
        or not nonNegativePoint(back) then return false, "invalid-safe-return" end
    if type(def.path) ~= "table" or #def.path > 12 then
      return false, "invalid-short-path"
    end
    for _, value in ipairs(def.path) do
      if not nonNegativePoint(value) then return false, "invalid-short-path" end
    end
    local rect = def.wilds and def.wilds.reservedRect
    if not validRect(rect) or not inRect(rect, def.reveal)
        or not inRect(rect, def.warp) then return false, "invalid-wilds-reserve" end
    for _, value in ipairs(def.path) do
      if not inRect(rect, value) then return false, "invalid-wilds-reserve" end
    end
    for _, value in ipairs(def.wilds.protected or {}) do
      if not nonNegativePoint(value) then return false, "invalid-wilds-reserve" end
    end
    local eligibility = def.eligibility
    if type(eligibility) ~= "table" then return false, "invalid-eligibility" end
    if eligibility.kind == "starter" then
      if type(eligibility.family) ~= "string"
          or not tostring(eligibility.generation):match("^gen%d+$")
          or eligibility.minimumStage ~= "sighted" then
        return false, "invalid-starter-eligibility"
      end
    elseif eligibility.kind == "profile_legend" then
      if not ({ RED=true, BLUE=true, GREEN=true })[eligibility.profile]
          or type(eligibility.species) ~= "string"
          or eligibility.requiresProfileSeal ~= true then
        return false, "invalid-legend-eligibility"
      end
    elseif eligibility.kind == "jirachi_convergence" then
      if eligibility.requiresLegacyPass ~= true
          or type(eligibility.profiles) ~= "table"
          or #eligibility.profiles ~= 3 then
        return false, "invalid-jirachi-eligibility"
      end
    else
      return false, "invalid-eligibility"
    end
    if type(def.presentation) ~= "table"
        or def.presentation.movesExistingObstacle ~= true
        or def.presentation.introducesGeometry ~= false
        or not allowedObstacle[def.presentation.physicalKind] then
      return false, "reveal-must-move-existing-obstacle"
    end
    local acceptedShape = acceptedProofShapes[def.id]
    if acceptedShape and proofShape(def) ~= acceptedShape then
      return false, "proof-definition-mismatch"
    end
    return true
  end

  local function snapshotBlock(snapshot, patch)
    local blocks = snapshot and snapshot.blocks
    if type(blocks) ~= "table" then return nil end
    local keyed = blocks[blockKey(patch.bx, patch.by)]
    if keyed ~= nil then return keyed end
    local row = blocks[patch.by]
    if type(row) == "table" then return row[patch.bx] end
    return nil
  end

  -- Resolve without mutation.  Closed state accepts only the exact vanilla
  -- preimage.  Open state accepts each byte independently as FROM or TO so a
  -- crash between two point patches can be repaired, but no third value is
  -- ever overwritten.
  function H.resolve(def, snapshot, opened)
    local valid, why = H.validateDefinition(def)
    if not valid then return { ok = false, reason = why, patches = {}, warps = {} } end
    local edition = type(snapshot and snapshot.edition) == "string"
      and snapshot.edition:lower() or ""
    if not editionSet(def.editions)[edition] then
      return { ok = false, reason = "edition-mismatch", patches = {}, warps = {} }
    end
    if snapshot.mapId ~= def.mapId then
      return { ok = false, reason = "map-mismatch", patches = {}, warps = {} }
    end
    if snapshot.mapIndex ~= def.mapIndex then
      return { ok = false, reason = "map-index-mismatch", patches = {}, warps = {} }
    end
    if snapshot.handoffClear ~= true then
      return { ok = false, reason = "handoff-cell-not-clear", patches = {}, warps = {} }
    end
    local pending = {}
    for _, patch in ipairs(def.patches) do
      local actual = snapshotBlock(snapshot, patch)
      local expected = patch.fromByEdition[edition]
      if opened then
        if actual == expected then
          local nextPatch = copy(patch)
          nextPatch.from = expected
          pending[#pending + 1] = nextPatch
        elseif actual ~= patch.to then
          return { ok = false, reason = "open-preimage-mismatch",
            at = blockKey(patch.bx, patch.by), actual = actual,
            patches = {}, warps = {} }
        end
      elseif actual ~= expected then
        return { ok = false, reason = "closed-preimage-mismatch",
          at = blockKey(patch.bx, patch.by), actual = actual,
          patches = {}, warps = {} }
      end
    end
    return {
      ok = true,
      opened = opened == true,
      patches = opened and pending or {},
      -- A native candidate remains data-visible only after receipt.  The
      -- current supported implementation uses conditional onInteract instead.
      warps = opened and { copy(def.warp) } or {},
      handoff = opened and copy(def.handoff) or nil,
    }
  end

  function H.visibleWarps(def, snapshot, opened)
    local result = H.resolve(def, snapshot, opened)
    return result.ok and result.warps or {}
  end

  function H.reservedCells(def)
    local out, seen = {}, {}
    local wilds = type(def) == "table" and def.wilds or {}
    local rect = wilds.reservedRect
    if validRect(rect) then
      for y = rect.yMin, rect.yMax do
        for x = rect.xMin, rect.xMax do
          local key = cellKey(x, y)
          seen[key] = true
          out[#out + 1] = { x = x, y = y }
        end
      end
    end
    for _, phase in ipairs({ "closed", "open" }) do
      for _, cell in ipairs(type(wilds[phase]) == "table" and wilds[phase] or {}) do
        if point(cell) then
          local key = cellKey(cell.x, cell.y)
          if not seen[key] then
            seen[key] = true
            out[#out + 1] = { x = cell.x, y = cell.y }
          end
        end
      end
    end
    for _, cell in ipairs(type(wilds.protected) == "table" and wilds.protected or {}) do
      if point(cell) then
        local key = cellKey(cell.x, cell.y)
        if not seen[key] then
          seen[key] = true
          out[#out + 1] = { x = cell.x, y = cell.y }
        end
      end
    end
    table.sort(out, function(a, b) return a.y == b.y and a.x < b.x or a.y < b.y end)
    return out
  end

  function H.locate(def, current)
    if type(current) ~= "table" or current.mapId ~= def.mapId
        or not integer(current.x) or not integer(current.y) then return nil end
    local dx, dy = def.reveal.x - current.x, def.reveal.y - current.y
    return {
      distance = math.abs(dx) + math.abs(dy),
      direction = direction(dx, dy, def.revealDirection),
      canOpen = dx == 0 and dy == 0,
    }
  end

  local function mapDefinition(game, mapId)
    if game and game.data and game.data.maps and game.data.maps[mapId] then
      return game.data.maps[mapId]
    end
    if mod and mod.content and mod.content.maps and mod.content.maps.get then
      local value = mod.content.maps:get(mapId)
      if value then return value end
    end
  end

  local function defaultSnapshot(game, def)
    local map = mapDefinition(game, def.mapId)
    if type(map) ~= "table" then return nil, "map-unavailable" end
    if not (mod and mod.world and type(mod.world.current) == "function") then
      return nil, "world-current-unavailable"
    end
    local currentOk, current, currentWhy = pcall(mod.world.current, mod.world)
    if not currentOk then return nil, "world-current-error" end
    if type(current) ~= "table" then
      return nil, currentWhy or "no-active-map"
    end
    if current.mapId ~= def.mapId then return nil, "active-map-mismatch" end
    -- 0.1.98 exposes replacement through mod.world but not the matching
    -- read-only block probe.  Prefer the public seam when present; otherwise
    -- read the already-resolved active Map instance.  This fallback never
    -- writes map tables and is guarded by the same active-map check above.
    local readBlock
    if type(mod.world.blockAt) == "function" then
      readBlock = function(bx, by)
        return mod.world:blockAt(bx, by)
      end
    else
      local liveMap = game and game.overworld and game.overworld.map
      if type(liveMap) ~= "table" or liveMap.id ~= def.mapId
          or type(liveMap.blockAt) ~= "function" then
        return nil, "blockAt-unavailable"
      end
      readBlock = function(bx, by)
        return liveMap:blockAt(bx, by)
      end
    end
    local blocks = {}
    for _, patch in ipairs(def.patches) do
      local readOk, value, readWhy = pcall(readBlock, patch.bx, patch.by)
      if not readOk then return nil, "blockAt-error" end
      if type(value) ~= "number" then
        return nil, readWhy or "blockAt-unavailable"
      end
      blocks[blockKey(patch.bx, patch.by)] = value
    end
    local handoffClear = true
    for _, row in ipairs(map.warps or {}) do
      if row.x == def.warp.x and row.y == def.warp.y then handoffClear = false end
    end
    for _, row in ipairs(map.signs or {}) do
      if row.x == def.warp.x and row.y == def.warp.y then handoffClear = false end
    end
    for _, row in ipairs(map.objects or {}) do
      if row.x == def.warp.x and row.y == def.warp.y then handoffClear = false end
    end
    local hidden = game and game.data and game.data.field
      and game.data.field.hiddenItems and game.data.field.hiddenItems[def.mapId]
    for _, row in ipairs(hidden or {}) do
      if row.x == def.warp.x and row.y == def.warp.y then handoffClear = false end
    end
    return {
      edition = game and game.save and game.save.version
        or game and game.data and game.data.gameVersion,
      mapId = map.id or def.mapId,
      mapIndex = map.index,
      blocks = blocks,
      handoffClear = handoffClear,
    }
  end

  local function defaultCurrent()
    if mod and mod.world and mod.world.current then return mod.world:current() end
  end

  local function mapContainsCell(map, value)
    if type(map) ~= "table" or not nonNegativePoint(value) then return false end
    local width, height = tonumber(map.width), tonumber(map.height)
    if not (integer(width) and integer(height) and width > 0 and height > 0) then
      return false
    end
    return value.x < width * 2 and value.y < height * 2
  end

  local function defaultValidateDestination(game, def)
    local destination = def.handoff.destination
    local map = mapDefinition(game, destination.map)
    if type(map) ~= "table" then return false, "destination-map-unavailable" end
    if map.index ~= destination.mapIndex then
      return false, "destination-map-index-mismatch"
    end
    if not mapContainsCell(map, destination) then
      return false, "destination-cell-out-of-bounds"
    end
    return true
  end

  local function defaultValidateReturn(game, def)
    local back = def.returnToKanto
    local map = mapDefinition(game, back.map)
    if type(map) ~= "table" then return false, "return-map-unavailable" end
    if map.index ~= back.mapIndex then return false, "return-map-index-mismatch" end
    if not mapContainsCell(map, back) then return false, "return-cell-out-of-bounds" end
    return true
  end

  local adapter = opts.adapter or {}
  adapter.snapshot = adapter.snapshot or defaultSnapshot
  adapter.current = adapter.current or defaultCurrent
  adapter.replaceBlock = adapter.replaceBlock or function(_, patch)
    if not (mod and mod.world and mod.world.replaceBlock) then
      return nil, "replaceBlock-unavailable"
    end
    return mod.world:replaceBlock(patch.bx, patch.by, patch.to)
  end
  adapter.warpTo = adapter.warpTo or function(_, destination)
    if not (mod and mod.world and mod.world.warpTo) then
      return nil, "warpTo-unavailable"
    end
    return mod.world:warpTo(destination.map, destination.x, destination.y,
      destination.facing)
  end
  adapter.sound = adapter.sound or function(game, def)
    local key = def.presentation and def.presentation.sound or "Cut"
    local ok, Sound = pcall(require, "src.core.Sound")
    if ok and Sound and Sound.play and game and game.data then
      return Sound.play(game.data, key)
    end
    return false
  end
  adapter.validateDestination = adapter.validateDestination
    or defaultValidateDestination
  adapter.validateReturn = adapter.validateReturn or defaultValidateReturn
  if adapter.setConditionalWarp == nil and mod and mod.world
      and type(mod.world.addEdgeWarp) == "function" then
    local edgeDirection = {
      north = "up", south = "down", west = "left", east = "right",
    }
    adapter.setConditionalWarp = function(_, def, enabled)
      if enabled ~= true then return false, "edge-warp-disable-unsupported" end
      local destination = def.handoff.destination
      return mod.world:addEdgeWarp({
        id = "kasc67:" .. def.id,
        mapId = def.mapId,
        x = def.warp.x,
        y = def.warp.y,
        direction = edgeDirection[def.handoff.edgeDirection or def.revealDirection],
        destination = {
          mapId = destination.map,
          x = destination.x,
          y = destination.y,
          facing = destination.facing,
          arrival = "land",
        },
      })
    end
  end

  local definitions, definitionById = {}, {}
  local registered, interactionsRegistered, installed = false, false, false
  H.audit = { repairs = {}, failures = {}, presentations = {} }

  local durableReceipts = opts.durableReceipts
  local durableReceiptCache

  local function localReceiptIsOpen(id)
    if not (device and type(device.isOpen) == "function") then return false end
    local ok, opened = pcall(device.isOpen, id)
    return ok and opened == true
  end

  local function durableReceiptIsOpen(id)
    if durableReceiptCache == nil and durableReceipts
        and type(durableReceipts.all) == "function" then
      local ok, rows = pcall(durableReceipts.all)
      durableReceiptCache = ok and type(rows) == "table" and rows or false
    end
    if type(durableReceiptCache) == "table" then
      return durableReceiptCache[id] ~= nil
    end
    if not (durableReceipts and type(durableReceipts.isOpen) == "function") then
      return false
    end
    local ok, opened = pcall(durableReceipts.isOpen, id)
    return ok and opened == true
  end

  local function receiptIsOpen(id)
    return localReceiptIsOpen(id) or durableReceiptIsOpen(id)
  end

  local function featureAvailable(game, def)
    if type(opts.featureAvailable) ~= "function" then return true end
    local ok, available = pcall(opts.featureAvailable, game, copy(def))
    return ok and available ~= false
  end

  local function normalStarterAllowed(game, def)
    if not (def and def.eligibility and def.eligibility.kind == "starter"
        and type(opts.normalStarterAllowed) == "function") then return false end
    local ok, allowed = pcall(opts.normalStarterAllowed, game)
    return ok and allowed == true
  end

  local function progressionAllowed(game, def)
    if opts.allowUngatedForTests == true then return true end
    if type(opts.isNewGamePlus) ~= "function" then
      return false, "new-game-plus-gate-unavailable"
    end
    local ngOk, active = pcall(opts.isNewGamePlus, game)
    if (not ngOk or active ~= true) and not normalStarterAllowed(game, def) then
      return false, "new-game-plus-required"
    end
    if type(opts.prerequisite) ~= "function" then
      return false, "prerequisite-gate-unavailable"
    end
    local gateOk, allowed, why = pcall(opts.prerequisite, game, def)
    if not gateOk then return false, "prerequisite-gate-error" end
    if allowed ~= true then return false, why or "prerequisite-not-met" end
    return true
  end

  -- Starter habitat receipts are permanent discoveries and deliberately
  -- remain usable in later Legacy cycles. Guardian routes are different:
  -- their physical obstacle may stay moved, but transport authority belongs
  -- to the active save's exact profile seal and must be checked every time.
  local function requiresLivePrerequisite(def)
    local kind = def and def.eligibility and def.eligibility.kind
    return kind == "profile_legend" or kind == "jirachi_convergence"
  end

  local function transportAllowed(game, def)
    if not requiresLivePrerequisite(def) then return true end
    return progressionAllowed(game, def)
  end

  function H.available(game, def)
    if type(def) ~= "table" then return false, "definition-not-table" end
    if not featureAvailable(game, def) then return false, "feature-disabled" end
    if receiptIsOpen(def.id) then return false, "already-open" end
    return progressionAllowed(game, def)
  end

  -- A starter rumor is the discovery event that creates the `trace` stage;
  -- requiring that stage here would make the first habitat unreachable.
  -- Keep this seam deliberately narrower than `available`: it accepts only a
  -- registered starter definition, an active NG+ run and an unopened durable
  -- receipt.  The ordinary entrance still requires the full prerequisite.
  function H.rumorAvailable(game, def)
    if type(def) ~= "table" or type(def.id) ~= "string" then
      return false, "definition-not-table"
    end
    local canonical = definitionById[def.id]
    if not canonical or canonical.eligibility.kind ~= "starter" then
      return false, "starter-definition-required"
    end
    if not featureAvailable(game, canonical) then
      return false, "feature-disabled"
    end
    if receiptIsOpen(canonical.id) then return false, "already-open" end
    if opts.allowUngatedForTests == true then return true end
    if type(opts.isNewGamePlus) ~= "function" then
      return false, "new-game-plus-gate-unavailable"
    end
    local ok, active = pcall(opts.isNewGamePlus, game)
    if (not ok or active ~= true) and not normalStarterAllowed(game, canonical) then
      return false, "new-game-plus-required"
    end
    return true
  end

  local function record(bucket, def, value)
    H.audit[bucket][#H.audit[bucket] + 1] = {
      id = def.id, value = value,
    }
  end

  local function takeSnapshot(game, def)
    local ok, value, reason = pcall(adapter.snapshot, game, def)
    if not ok then return nil, value end
    return value, reason
  end

  local function present(game, def)
    if type(adapter.present) == "function" then
      local ok, shown = pcall(adapter.present, game, def,
        { renderer = opts.renderer or "unknown" })
      if ok and shown == true then
        record("presentations", def, "animated")
        return true
      end
      record("presentations", def, ok and "animation-unavailable" or "animation-error")
    end
    local ok, played = pcall(adapter.sound, game, def)
    record("presentations", def, ok and played ~= false
      and "sound-fallback" or "silent-fallback")
    return false
  end

  local function applyOpened(game, def)
    local snapshot, snapshotWhy = takeSnapshot(game, def)
    if not snapshot then return false, snapshotWhy or "snapshot-unavailable" end
    local plan = H.resolve(def, snapshot, true)
    if not plan.ok then return false, plan.reason end
    for _, patch in ipairs(plan.patches) do
      local ok, why = adapter.replaceBlock(game, patch, def)
      if ok ~= true then return false, why or "replaceBlock-failed" end
    end
    if def.handoff.kind == H.TRANSPORT_NATIVE then
      local live = transportAllowed(game, def)
      if live == true then
        if type(adapter.setConditionalWarp) ~= "function" then
          return false, H.ENGINE_SEAM .. "-unavailable"
        end
        local ok, why = adapter.setConditionalWarp(game, def, true)
        if ok ~= true then return false, why or "conditional-warp-failed" end
      end
    end
    local after, afterWhy = takeSnapshot(game, def)
    if not after then return false, afterWhy or "post-snapshot-unavailable" end
    local verified = H.resolve(def, after, true)
    if not verified.ok or #verified.patches ~= 0 then
      return false, verified.reason or "block-write-not-observed"
    end
    record("repairs", def, #plan.patches)
    return true
  end

  function H.repair(game, id)
    local def = definitionById[id]
    if not def then return false, "unknown-entrance" end
    if not receiptIsOpen(id) then return false, "not-open" end
    local ok, why = applyOpened(game, def)
    if not ok then record("failures", def, why) end
    return ok, why
  end

  local function canUseGuarded(def)
    if type(adapter.snapshot) ~= "function" or type(adapter.replaceBlock) ~= "function" then
      return false, "required-adapter-unavailable"
    end
    if def.handoff.kind == H.TRANSPORT_NATIVE
        and type(adapter.setConditionalWarp) ~= "function" then
      return false, H.ENGINE_SEAM .. "-unavailable"
    end
    if opts.allowSaveLocalReceipts ~= true
        and not (durableReceipts
          and type(durableReceipts.isOpen) == "function"
          and type(durableReceipts.markOpen) == "function") then
      return false, "durable-receipt-store-unavailable"
    end
    return true
  end

  local function persistReceipt(game, def, receipt)
    if not (device and type(device.markOpen) == "function") then
      return false, "receipt-store-unavailable"
    end
    if durableReceipts and type(durableReceipts.markOpen) == "function" then
      local durableOk, durableStored, durableWhy = pcall(
        durableReceipts.markOpen, def.id, receipt, game)
      if not durableOk or durableStored ~= true then
        return false, durableOk and (durableWhy or "durable-receipt-persist-failed")
          or "durable-receipt-persist-error"
      end
      durableReceiptCache = nil
      if not durableReceiptIsOpen(def.id) then
        return false, "durable-receipt-not-observed"
      end
      if type(durableReceiptCache) == "table" then
        durableReceiptCache[def.id] = copy(receipt)
      end
    elseif opts.allowSaveLocalReceipts ~= true then
      return false, "durable-receipt-store-unavailable"
    end
    local ok, stored = pcall(device.markOpen, def.id, receipt)
    if not ok or stored ~= true then
      return false, ok and "receipt-persist-failed" or "receipt-persist-error"
    end
    if not localReceiptIsOpen(def.id) then return false, "receipt-not-observed" end
    return true
  end

  local prepareHandoff, rollbackHandoff

  function H.open(game, def)
    local mode = opts.mode or H.MODE_GUARDED
    if receiptIsOpen(def.id) then return false, "already-open" end
    local eligible, eligibleWhy = progressionAllowed(game, def)
    if not eligible then return false, eligibleWhy end
    local currentOk, current = pcall(adapter.current, game)
    local location = currentOk and H.locate(def, current) or nil
    if not (location and location.canOpen == true) then
      return false, "not-at-reveal-point"
    end
    local snapshot, snapshotWhy = takeSnapshot(game, def)
    if not snapshot then return false, snapshotWhy or "snapshot-unavailable" end
    local closed = H.resolve(def, snapshot, false)
    if not closed.ok then return false, closed.reason end
    local returnOk, returnWhy = adapter.validateReturn(game, def)
    if returnOk ~= true then return false, returnWhy or "return-validation-failed" end
    local targetOk, targetWhy = adapter.validateDestination(game, def)
    if targetOk ~= true then return false, targetWhy or "destination-validation-failed" end

    if mode == H.MODE_LEGACY_DIRECT then
      -- Explicit old fallback: point-swap and immediate hand-off on SELECT.
      -- It remains deliberately opt-in and never runs through guarded mode.
      -- The receipt is still durable first, so a crash between the simple
      -- swap and warp can be repaired by the shared map.entered controller.
      local receipt = { contract = 1, mode = H.MODE_LEGACY_DIRECT,
        map = def.mapId, mapIndex = def.mapIndex }
      local persisted, persistWhy = persistReceipt(game, def, receipt)
      if not persisted then return false, persistWhy end
      for _, patch in ipairs(def.patches) do
        local ok, why = adapter.replaceBlock(game, patch, def)
        if ok ~= true then return false, why or "replaceBlock-failed", receipt end
      end
      local token, prepareWhy, owned = prepareHandoff(game, def)
      if not token then return false, prepareWhy, receipt end
      local ok, why = adapter.warpTo(game, def.handoff.destination, def)
      if ok ~= true then
        rollbackHandoff(game, def, token, why, owned)
        return false, why or "warpTo-failed", receipt
      end
      return true, receipt
    end

    local supported, why = canUseGuarded(def)
    if not supported then return false, why end
    -- Receipt first: after a crash, map.entered repairs FROM bytes.  Preflight
    -- above ensures the required seams exist before the durable transition.
    local receipt = {
      contract = 1, mode = H.MODE_GUARDED, map = def.mapId,
      mapIndex = def.mapIndex,
    }
    local persisted, persistWhy = persistReceipt(game, def, receipt)
    if not persisted then return false, persistWhy end
    present(game, def)
    local applied, applyWhy = applyOpened(game, def)
    if not applied then
      record("failures", def, applyWhy)
      return false, applyWhy, receipt
    end
    return true, receipt
  end

  -- Optional composition seam for destination packages that own a reversible
  -- return transaction.  Access V3.1 still owns the reveal and transport;
  -- the habitat package records which of its alternate source entrances was
  -- actually used.  The callback runs only after every receipt, live-byte and
  -- destination check has passed, immediately before the public warp call.
  prepareHandoff = function(game, def)
    if type(opts.prepareHandoff) ~= "function" then
      return true, nil, false
    end
    local ok, token, why = pcall(opts.prepareHandoff, game, copy(def))
    if not ok then return nil, "handoff-prepare-error", true end
    if token == nil or token == false then
      return nil, why or "handoff-prepare-rejected", true
    end
    return token, nil, true
  end

  rollbackHandoff = function(game, def, token, reason, owned)
    if not owned or type(opts.rollbackHandoff) ~= "function" then return end
    pcall(opts.rollbackHandoff, game, copy(def), token,
      reason or "handoff-warp-failed")
  end

  local function enterOpened(game, def)
    if not receiptIsOpen(def.id) or not featureAvailable(game, def)
        or transportAllowed(game, def) ~= true then return false end
    if not H.repair(game, def.id)
        or adapter.validateDestination(game, def) ~= true then return false end
    local token, why, owned = prepareHandoff(game, def)
    if not token then
      record("failures", def, why)
      return false
    end
    local ok, warpWhy = adapter.warpTo(game, def.handoff.destination, def)
    if ok ~= true then rollbackHandoff(game, def, token, warpWhy, owned) end
    return ok == true
  end

  function H.step(game, mapId, x, y)
    for _, def in ipairs(definitions) do
      if def.mapId == mapId and def.warp.x == x and def.warp.y == y
          and def.handoff.kind == H.TRANSPORT_INTERACT then
        local current = adapter.current(game)
        if not current or current.mapId ~= mapId
            or current.x ~= x or current.y ~= y then return false end
        return enterOpened(game, def)
      end
    end
    return false
  end

  function H.interact(game, mapId, fx, fy, player)
    for _, def in ipairs(definitions) do
      if def.mapId == mapId and def.warp.x == fx and def.warp.y == fy
          and receiptIsOpen(def.id) then
        if not featureAvailable(game, def) then return false end
        local from = def.handoff.interactFrom
        if player and (player.x ~= from.x or player.y ~= from.y
            or (from.facing and player.facing ~= from.facing)) then
          return false
        end
        return enterOpened(game, def)
      end
    end
    return false
  end

  function H.register(list)
    if registered then return false, "already-registered" end
    if not list then
      list = {}
      for _, mapId in ipairs(H.ORDER) do list[#list + 1] = H.ACCESS[mapId] end
    end
    for _, original in ipairs(list) do
      local def = copy(original)
      local ok, why = H.validateDefinition(def)
      if not ok then return false, why end
      if definitionById[def.id] then return false, "duplicate-id" end
      definitions[#definitions + 1], definitionById[def.id] = def, def
      if device and device.registerEntrance then
        local site = def -- Lua 5.1 closure-local: never capture the loop slot.
        local accepted, deviceWhy = device.registerEntrance({
          id = site.id,
          locate = function(game)
            local current = adapter.current and adapter.current(game) or nil
            return H.locate(site, current)
          end,
          available = function(game)
            local eligible = H.available(game, site)
            if eligible ~= true then return false end
            local snapshot = takeSnapshot(game, site)
            return snapshot ~= nil and H.resolve(site, snapshot, false).ok
          end,
          open = function(game) return H.open(game, site) end,
          openedGuidance = site.id == "ROUTE14_SURF_HIDDEN_HABITAT" and function(game)
            if not receiptIsOpen(site.id) or not featureAvailable(game, site) then return nil end
            local current = adapter.current and adapter.current(game)
            if not current or current.mapId ~= site.mapId then return nil end
            return {
              en = "Go south through the gap, then east along the shore.\fUse SURF and follow the shore east to the habitat.",
              de = "Geh durch die Lücke nach Süden, dann am Ufer nach Osten.\fNutze SURFER und folge dem Ufer nach Osten zum Habitat.",
            }
          end or nil,
        })
        if accepted ~= true then return false, deviceWhy or "device-registration-failed" end
      end
    end
    registered = true
    return true
  end

  -- Engines without owner-scoped edge warps still enter an opened path by
  -- walking onto its exit cell. Keep A as a compatibility shortcut from the
  -- authored approach; both paths enforce the same receipts and live gates.
  function H.registerInteractions()
    if interactionsRegistered then return true, "already-registered" end
    if not (mod and mod.content and mod.content.map_scripts
        and mod.content.map_scripts.register) then
      return false, "map-scripts-unavailable"
    end
    for _, def in ipairs(definitions) do
      local site = def -- each registered hook retains its own site.
      if site.handoff.kind == H.TRANSPORT_INTERACT then
        mod.content.map_scripts:register(site.mapId, {
          priority = 2670,
          onStep = function(game, _, x, y)
            return H.step(game, site.mapId, x, y)
          end,
          onInteract = function(game, ow, fx, fy)
            local player = ow and ow.player and {
              x = ow.player.cellX, y = ow.player.cellY, facing = ow.player.facing,
            }
            return H.interact(game, site.mapId, fx, fy, player)
          end,
        })
      end
    end
    interactionsRegistered = true
    return true
  end

  function H.install(game)
    -- The engine may construct more than one Game in a process (tests,
    -- previews and controlled reloads).  The event callback resolves
    -- event.game first, so repeating installation is a safe idempotent no-op.
    if installed then return true, "already-installed" end
    if opts.allowUngatedForTests ~= true
        and (type(opts.isNewGamePlus) ~= "function"
          or type(opts.prerequisite) ~= "function") then
      return false, "progression-gate-unavailable"
    end
    if opts.allowSaveLocalReceipts ~= true
        and not (durableReceipts
          and type(durableReceipts.isOpen) == "function"
          and type(durableReceipts.markOpen) == "function") then
      return false, "durable-receipt-store-unavailable"
    end
    if not registered then
      local ok, why = H.register()
      if not ok then return false, why end
    end
    local interactionsOk, interactionsWhy = H.registerInteractions()
    if not interactionsOk then return false, interactionsWhy end
    if not (mod and mod.events and mod.events.on) then
      return false, "map-entered-event-unavailable"
    end
    if type(opts.reserveWilds) ~= "function" and opts.allowUnboundWilds ~= true then
      return false, "wilds-reservation-unavailable"
    end
    mod.events:on("map.entered", function(event)
      local mapId = event and (event.mapId or event.map and event.map.id)
      local activeGame = event and event.game or game
      for _, def in ipairs(definitions) do
        if mapId == def.mapId and receiptIsOpen(def.id)
            and featureAvailable(activeGame, def) then
          H.repair(activeGame, def.id)
        end
      end
    end, 2670)
    if type(opts.reserveWilds) == "function" then
      for _, def in ipairs(definitions) do
        opts.reserveWilds(def.mapId, H.reservedCells(def), def.id)
      end
    end
    for _, event in ipairs({"save.loaded", "save.created"}) do
      mod.events:on(event, function() durableReceiptCache = nil end, 2670)
    end
    installed = true
    return true
  end

  function H.definitions()
    return copy(definitions)
  end

  return H
end
