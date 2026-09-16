-- KASC 6.7 optional feature Card: A Rival's Life.
--
-- The Card is the only composition owner for the optional runtime.  OFF is a
-- cold gate: none of the runtime controllers are loaded, no map/event hooks
-- are registered and no feature save bucket is touched.  The native story
-- rival remains owned by the engine and the existing story scripts.

return function(mod, opts)
  opts = opts or {}
  local load = assert(opts.load, "Life of a Rival Card requires a loader")
  local support = opts.supportLog
  local C = {
    CARD_ID = "KASC-67-LIFE-OF-A-RIVAL",
    OWNER = "kasc.rival.life-of-a-rival/v1",
    VERSION = "1.0.0",
    OPTION_KEY = "life_of_rival",
  }

  local function enabled()
    if type(opts.enabled) == "function" then
      local ok, value = pcall(opts.enabled)
      return ok and value ~= false
    end
    if mod.options and type(mod.options.get) == "function" then
      local ok, value = pcall(mod.options.get, mod.options, C.OPTION_KEY)
      return not ok or value ~= false
    end
    return true
  end

  C.active = enabled()
  C.enabled = function() return C.active end
  if support and type(support.registerSegment) == "function" then
    support.registerSegment({
      segmentId=C.CARD_ID, cardId=C.CARD_ID, version=C.VERSION,
      schema="kasc.optional-feature-card/v1", owner=C.OWNER,
      active=C.active, dependencyStatus="local-reviewed",
      providerStatus=C.active and "runtime-loaded" or "cold-disabled",
      buildReceiptId="docs/LIFE_OF_A_RIVAL_CARD_67.md",
      rollbackReceiptId="revert-card-commit",
    })
  end

  if not C.active then
    C.life = {
      enabled = function() return false end,
      eligible = function() return false end,
      traceFinderQuestHint = function() return nil end,
    }
    C.parallel = {
      enabled = function() return false end,
      isBusy = function() return false end,
    }
    return C
  end

  local lifeOpts=assert(opts.life,'Life of a Rival Card requires runtime dependencies')
  C.hints=load('rival_observation_hints_67.lua')(mod,{
    sources=lifeOpts.observationSources,rules=lifeOpts.generationRules,
    i18n=lifeOpts.i18n,supportLog=support,
  })
  lifeOpts.hints=C.hints
  C.duel=load('rival_duel_scene_67.lua')(mod,{load=load,
    rules=lifeOpts.generationRules,i18n=lifeOpts.i18n})
  lifeOpts.duel=C.duel
  C.life = load("life_of_rival.lua")(mod,lifeOpts)
  local parallelOpts = assert(opts.parallel,
    "Life of a Rival Card requires journey dependencies")
  parallelOpts.base = C.life
  C.parallel = load("rival_parallel_journey.lua")(mod, parallelOpts)
  return C
end
