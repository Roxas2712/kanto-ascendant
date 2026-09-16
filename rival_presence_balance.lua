-- kasc.rival.presence-scheduler/v1
--
-- Product-side copy of the reviewed 6.6 cadence. Keeping the numbers outside
-- the scheduler makes balance-only review possible without touching spawn,
-- dialogue or presentation code.

return {
  schema = "kasc.rival.presence-balance/v1",
  postEncounterGuard = { minSeconds = 900, maxSeconds = 1500,
    minEligibleMapTransitions = 3 },
  -- Four-minute opportunity spacing is the reviewed value that keeps the
  -- deterministic long-run inside both the 25-40 minute P50 and 60-75 minute
  -- P90 windows. Pity still clamps the next check to 75 minutes.
  opportunity = { intervalSeconds = 400, initialBasisPoints = 1000,
    failedIncrementBasisPoints = 500, maximumBasisPoints = 4500 },
  pity = { maxFailedEligibleOpportunities = 10,
    maxEligibleExplorationSeconds = 4500 },
  density = { rollingWindowSeconds = 3600, maxAmbientAppearances = 2 },
  cooldowns = { locationMinSeconds = 2700, locationMaxSeconds = 7200,
    spectatorDuelSeconds = 5400 },
  doubleAppearanceBasisPoints = 1500,
}
