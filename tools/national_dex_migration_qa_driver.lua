-- Renderer-backed UAT for both sides of the 6.0.3 National Dex migration.
-- It mutates only the disposable POKEPORT_IDENTITY and never writes a save.

return function(game)
  local U = dofile("tests/drivers/util.lua")
  local PokedexMenu = require("src.ui.PokedexMenu")
  U.wait(30)

  local exports = assert(game.mods and game.mods.exports
      and game.mods.exports.trainer_rematch,
    "Kanto Ascendant export missing")
  local progress = assert(exports.dexProgress,
    "National Dex progress export missing")
  local early = assert(exports.johtoSignals,
    "Johto Signals export missing")
  local shotDir = assert(os.getenv("SHOT_DIR"), "SHOT_DIR is required")

  local function clear(value)
    for key in pairs(value) do value[key] = nil end
  end

  local function resetDex(version)
    local value = progress.state()
    clear(value)
    value.version = version
    value.certificates = {}
    value.nationalDexUnlocked = false
    value.nationalDexLegacyMigration = nil
    return value
  end

  local function resetSignals()
    local value = early.state()
    clear(value)
    value.mode = early.modes.KANTO_FIRST
    value.modeChosen = false
    value.traces = {}
    value.rarePity = {}
    return value
  end

  game.save.pokedex = game.save.pokedex or { seen = {}, owned = {} }
  game.save.pokedex.seen = game.save.pokedex.seen or {}
  game.save.pokedex.owned = game.save.pokedex.owned or {}

  -- Left branch: an old public save was already active before 6.0.3.
  resetDex(1)
  local active = resetSignals()
  active.receiverRepaired = true
  active.modeChosen = true
  active.mode = early.modes.WANDERWAVES
  active.startPolicy = "waves"
  progress.install(game)
  assert(progress.hasNationalDex() == true,
    "an already-active 6.0.0-6.0.2 save did not auto-upgrade")
  assert(#PokedexMenu.new(game).items == 251,
    "the automatic upgrade did not expose 251 slots")

  game.save.pokedex.seen.CELEBI = true
  local migrated = PokedexMenu.new(game)
  assert(migrated.items[251].value == "CELEBI"
      and migrated.items[251].ball == nil,
    "the migrated Dex does not preserve seen-only discovery")
  migrated.index, migrated.scroll = 251, 244
  game.stack:push(migrated)
  U.wait(30)
  assert(U.shot(game, shotDir .. "/legacy_active_auto_national_dex.png"))
  game.stack:pop()

  -- Right branch: merely starting the old quest must not bypass Driftglass.
  resetDex(1)
  local started = resetSignals()
  started.questStarted = true
  started.capsuleTaken = true
  started.capsuleOpened = true
  started.receiverRepaired = false
  started.startPolicy = "quest"
  progress.install(game)
  assert(progress.hasNationalDex() == false,
    "a merely-started old quest unlocked too early")
  assert(#PokedexMenu.new(game).items == 151,
    "a merely-started old quest exposed Johto slots")

  -- Activating a remote current later cannot reuse the consumed legacy gate.
  started.receiverRepaired = true
  started.modeChosen = true
  started.mode = early.modes.WANDERWAVES
  started.startPolicy = "waves"
  progress.install(game)
  assert(progress.hasNationalDex() == false,
    "a later remote activation reused the legacy auto-upgrade")

  -- Completing the physical Driftglass path still grants it.
  started.startPolicy = "quest"
  local unlocked = progress.reconcileNationalDex(game)
  assert(unlocked == true and progress.hasNationalDex() == true,
    "the completed physical Driftglass path did not unlock")

  -- Fresh 6.0.3 state never has a hidden migration ticket.
  resetDex(2)
  local fresh = resetSignals()
  fresh.receiverRepaired = true
  fresh.modeChosen = true
  fresh.mode = early.modes.WANDERWAVES
  fresh.startPolicy = "waves"
  progress.install(game)
  assert(progress.hasNationalDex() == false,
    "fresh remote onboarding incorrectly unlocked the National Dex")

  U.log("NATIONAL DEX MIGRATION QA PASS",
    os.getenv("POKEPORT_VERSION") or "unknown")
end
