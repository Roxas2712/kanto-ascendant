-- kasc.rival.scripted-events/v1
-- Curated event definitions contain identifiers and dialogue phases only.
-- They contain no raw text, coordinates, teams, rewards or story writes.

local rows = {
  {
    schema="rival.scripted-event/v1",
    eventId="ROUTE22_DOUBLE_PLAN_REVIEW",
    kind="DOUBLE",
    agendaId="ROUTE_22_LEAGUE_PAIR",
    mapId="ROUTE_22",
    actorSet="RED_BLUE",
    exactOnce=false,
    challenger=nil,
    storyRequirements={
      allOf={ "HALL_OF_FAME_OR_ACTIVE_NG_PLUS" },
      noneOf={ "MAIN_STORY_SCENE_ACTIVE", "BATTLE_ACTIVE" },
    },
    dialogue={
      before={ RED="FIRST_TALK", BLUE="FIRST_TALK" },
      after={ RED="FAREWELL", BLUE="FAREWELL" },
    },
  },
  {
    schema="rival.scripted-event/v1",
    eventId="ROUTE22_TRIO_BLUE_CHALLENGE",
    kind="TRIO",
    agendaId="ROUTE_22_LEAGUE_PAIR",
    mapId="ROUTE_22",
    actorSet="RED_BLUE",
    exactOnce=true,
    challenger="BLUE",
    observer="RED",
    storyRequirements={
      allOf={ "CURRENT_RUN_LEAGUE_CLEAR", "BLUE_CHALLENGE_AVAILABLE" },
      noneOf={ "MAIN_STORY_SCENE_ACTIVE", "BATTLE_ACTIVE" },
    },
    dialogue={
      before={ RED="FIRST_TALK", BLUE="PRE_CHALLENGE" },
      declined={ RED="REPEAT_TALK", BLUE="POST_ABORT" },
      playerWin={ RED="POST_WIN", BLUE="POST_WIN" },
      playerLoss={ RED="POST_LOSS", BLUE="POST_LOSS" },
      aborted={ RED="POST_ABORT", BLUE="POST_ABORT" },
      after={ RED="FAREWELL", BLUE="FAREWELL" },
    },
  },
  {
    schema="rival.scripted-event/v1",
    eventId="ROUTE22_TRIO_RED_CHALLENGE",
    kind="TRIO",
    agendaId="ROUTE_22_LEAGUE_PAIR",
    mapId="ROUTE_22",
    actorSet="RED_BLUE",
    exactOnce=true,
    challenger="RED",
    observer="BLUE",
    storyRequirements={
      allOf={ "CURRENT_RUN_LEAGUE_CLEAR", "RED_CHALLENGE_AVAILABLE" },
      noneOf={ "MAIN_STORY_SCENE_ACTIVE", "BATTLE_ACTIVE" },
    },
    dialogue={
      before={ RED="PRE_CHALLENGE", BLUE="FIRST_TALK" },
      declined={ RED="POST_ABORT", BLUE="REPEAT_TALK" },
      playerWin={ RED="POST_WIN", BLUE="POST_WIN" },
      playerLoss={ RED="POST_LOSS", BLUE="POST_LOSS" },
      aborted={ RED="POST_ABORT", BLUE="POST_ABORT" },
      after={ RED="FAREWELL", BLUE="FAREWELL" },
    },
  },
}

local byId = {}
for _, row in ipairs(rows) do
  assert(not byId[row.eventId], "duplicate scripted rival event")
  byId[row.eventId] = row
end

local function copy(value)
  if type(value) ~= "table" then return value end
  local out = {}
  for key, child in pairs(value) do out[key] = copy(child) end
  return out
end

return {
  schema="kasc.rival.scripted-event-catalog/v1",
  all=function() return copy(rows) end,
  get=function(id) return copy(byId[id]) end,
}
