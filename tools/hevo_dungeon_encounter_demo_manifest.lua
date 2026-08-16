-- Reproducible, renderer-independent entry points for the cycle-1 Level-70
-- parent-habitat acceptance pass.  Later Legacy Journeys scale by +5 per
-- cycle through the runtime controller; these original-run fixtures remain
-- the authoritative baseline evidence. Coordinates are safe cells immediately beyond
-- each first-floor return warp.  Following routeCells walks only ordinary
-- trial collision and gives Visible Wilds enough reachable space to publish
-- a nearby member of the color's registry-derived parent set.
return {
  GBCFX = 0,
  BASE_CYCLE = 1,
  BASE_LEVEL = 70,
  LEVEL_STEP = 5,
  MAX_LEVEL = 100,
  RED = {
    cycle = 1, expectedLevel = 70,
    slot = "slothevo65encounterred",
    map = "KA_HEVO_RED_UPPER",
    start = { x = 5, y = 33, facing = "right" },
    routeCells = {
      {6,33},{7,33},{8,33},{9,33},{10,33},{11,33},
      {11,32},{11,31},{10,31},{9,31},{8,31},{7,31},
      {7,30},{7,29},
    },
  },
  BLUE = {
    cycle = 1, expectedLevel = 70,
    slot = "slothevo65encounterblue",
    map = "KA_HEVO_BLUE_FROST_THRESHOLD",
    start = { x = 5, y = 29, facing = "right" },
    routeCells = {
      {6,29},{7,29},{8,29},{9,29},{9,28},{8,28},{8,27},
      {8,26},{8,25},{8,24},{8,23},{8,22},{8,21},{8,20},
    },
  },
  GREEN = {
    cycle = 1, expectedLevel = 70,
    slot = "slothevo65encountergreen",
    map = "KA_HEVO_GREEN_THRESHOLD",
    start = { x = 5, y = 38, facing = "up" },
    routeCells = {
      {5,37},{5,36},{5,35},{4,35},{3,35},{3,34},{3,33},
      {4,33},{5,33},{6,33},{7,33},{8,33},{9,33},{10,33},{11,33},
    },
  },
}
