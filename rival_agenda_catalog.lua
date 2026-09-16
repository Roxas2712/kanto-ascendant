-- kasc.rival.agenda-runtime/v1
--
-- Closed, coordinate-free agenda catalogue. Map coordinates, pathfinding and
-- NPC handles deliberately stay behind the world adapters owned by the engine.

local function agenda(id, actors, mapId, kind, goal, interaction, weight, pity)
  return { descriptor = {
    schema = "rival.agenda-descriptor/v1",
    agendaId = id,
    actorSet = actors,
    eligibleMapIds = { mapId },
    storyRequirements = {
      allOf = { "HALL_OF_FAME_OR_ACTIVE_NG_PLUS" },
      noneOf = { "MAIN_STORY_SCENE_ACTIVE", "BATTLE_ACTIVE" },
    },
    arrival = {
      pointId = id .. "_ENTRY",
      routeId = id .. "_ARRIVAL_ROUTE",
      safe = true,
    },
    goals = {
      {
        goalId = goal,
        kind = kind,
        safeStandpointId = id .. "_STANDPOINT",
      },
    },
    interactionSetId = interaction,
    departure = {
      pointId = id .. "_EXIT",
      routeId = id .. "_DEPARTURE_ROUTE",
      safe = true,
    },
    ["repeat"] = {
      repeatable = true,
      weightBasisPoints = weight,
      cooldownSeconds = 3600,
      immediateRepeatForbidden = true,
    },
    abortPolicy = "SAFE_STANDPOINT_THEN_DEPART",
    resumePolicy = "SAFE_NODE_ONLY",
  }, appearanceClass = "AMBIENT", curatedForPity = pity == true }
end

local rows = {
  agenda("ROUTE_1_TEAM_DRILL_RED", "RED", "ROUTE_1", "TRAIN",
    "CHECK_TURNING_LINE", "TEAM_DRILL", 1100, true),
  agenda("VIRIDIAN_SUPPLIES_BLUE", "BLUE", "VIRIDIAN_CITY",
    "INSPECT_ITEM_ROUTE_OR_GYM", "CHECK_TRAVEL_KIT", "SUPPLY_CHECK", 1000,
    true),
  agenda("ROUTE_2_ENDURANCE_RED", "RED", "ROUTE_2", "TRAIN",
    "FINISH_ENDURANCE_RUN", "ENDURANCE", 1000, true),
  agenda("PEWTER_MUSEUM_BLUE", "BLUE", "PEWTER_CITY", "OBSERVE",
    "COMPARE_FOSSIL_NOTES", "MUSEUM_STUDY", 900, false),
  agenda("ROUTE_5_PATH_RED", "RED", "ROUTE_5", "INSPECT_ITEM_ROUTE_OR_GYM",
    "COMPARE_ROUTE_TIMES", "PATH_COMPARE", 1000, true),
  agenda("VERMILION_HARBOR_BLUE", "BLUE", "VERMILION_CITY", "WAIT",
    "TRAIN_AT_HARBOR", "HARBOR_WAIT", 1000, true),
  agenda("ROUTE_12_REST_RED", "RED", "ROUTE_12", "WAIT",
    "GUARD_TEAM_REST", "TEAM_REST", 900, false),
  agenda("FUCHSIA_TRACKS_BLUE", "BLUE", "FUCHSIA_CITY", "SEARCH",
    "READ_HABITAT_TRACKS", "TRACK_SEARCH", 1000, true),
  agenda("ROUTE_15_REMATCH_RED", "RED", "ROUTE_15", "TRAIN",
    "REHEARSE_OPENINGS", "REMATCH_DRILL", 1000, true),
  agenda("CINNABAR_HEAT_BLUE", "BLUE", "CINNABAR_ISLAND", "TRAIN",
    "ADAPT_TO_HEAT", "HEAT_TRAINING", 900, false),
  agenda("ROUTE_22_LEAGUE_PAIR", "RED_BLUE", "ROUTE_22", "EXPECT_PLAYER",
    "WAIT_FOR_PLAYER", "LEAGUE_PAIR", 650, false),
}

local byId = {}
for _, entry in ipairs(rows) do
  local row = entry.descriptor
  assert(not byId[row.agendaId], "duplicate rival agenda")
  byId[row.agendaId] = row
end

local function copy(value)
  if type(value) ~= "table" then return value end
  local out = {}
  for key, child in pairs(value) do out[key] = copy(child) end
  return out
end

return {
  schema = "kasc.rival.agenda-catalog/v1",
  all = function()
    local out = {}
    for _, entry in ipairs(rows) do out[#out + 1] = copy(entry.descriptor) end
    return out
  end,
  get = function(id) return copy(byId[id]) end,
  schedulerCandidates = function(_, mapId)
    local out = {}
    for _, entry in ipairs(rows) do
      local row = entry.descriptor
      if row.eligibleMapIds[1] == mapId then
        out[#out + 1] = {
          schema = "rival.scheduler-candidate/v1",
          agendaId = row.agendaId,
          actorSet = row.actorSet,
          mapId = mapId,
          appearanceClass = entry.appearanceClass,
          weightBasisPoints = row["repeat"].weightBasisPoints,
          curatedForPity = entry.curatedForPity,
        }
      end
    end
    return out
  end,
}
