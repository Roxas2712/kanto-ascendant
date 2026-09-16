-- kasc.rival.spectator-duel-presentation/v1 -- Red commands

local voice = "TERSE_OBSERVANT_ACTION"
local templates = {
  HEAL={
    {en="{POKEMON}, {MOVE}. Recover first.", de="{POKEMON}, {MOVE}. Erst erholen."},
    {en="Steady, {POKEMON}. Use {MOVE}.", de="Ruhig, {POKEMON}. Setz {MOVE} ein."},
  },
  PROTECT={
    {en="{POKEMON}, {MOVE}. Hold position.", de="{POKEMON}, {MOVE}. Stellung halten."},
    {en="No opening. {POKEMON}, {MOVE}.", de="Keine Lücke. {POKEMON}, {MOVE}."},
  },
  BOOST={
    {en="{POKEMON}, {MOVE}. Build the advantage.", de="{POKEMON}, {MOVE}. Jetzt den Vorteil ausbauen."},
    {en="Prepare first. {POKEMON}, use {MOVE}.", de="Erst vorbereiten. {POKEMON}, setz {MOVE} ein."},
  },
  CHARGE={
    {en="{POKEMON}, {MOVE}. Take your time.", de="{POKEMON}, {MOVE}. Nimm dir die Zeit."},
    {en="Gather strength, {POKEMON}. {MOVE}.", de="Sammle deine Kraft, {POKEMON}. {MOVE}."},
  },
  DODGE={
    {en="Out of the line, {POKEMON}. {MOVE}.", de="Raus aus der Linie, {POKEMON}. {MOVE}."},
    {en="Move now. {POKEMON}, use {MOVE}.", de="Jetzt bewegen. {POKEMON}, setz {MOVE} ein."},
  },
  MELEE={
    {en="Close in, {POKEMON}. {MOVE}.", de="Geh ran, {POKEMON}. {MOVE}."},
    {en="Now, {POKEMON}. Use {MOVE} up close.", de="Jetzt, {POKEMON}. {MOVE} aus der Nähe."},
  },
  RANGED={
    {en="Keep the distance. {POKEMON}, {MOVE}.", de="Abstand halten. {POKEMON}, {MOVE}."},
    {en="From there, {POKEMON}. Use {MOVE}.", de="Von dort, {POKEMON}. Setz {MOVE} ein."},
  },
  MULTIPHASE={
    {en="{POKEMON}, {MOVE}. Up first, then strike.", de="{POKEMON}, {MOVE}. Erst hoch, dann zuschlagen."},
    {en="Leave the ground, {POKEMON}. Finish with {MOVE}.", de="Hoch mit dir, {POKEMON}. Dann mit {MOVE} treffen."},
  },
}

local function make(snapshot, move, phase, variant)
  variant = variant == 2 and 2 or 1
  local semantic = assert(templates[move.semanticClass], "unknown move semantic")
  local slug = move.semanticClass:lower() .. "." .. phase:lower()
  local suffix = variant == 1 and "a" or "b"
  local other = variant == 1 and "b" or "a"
  local base = "life_of_rival.red.command." .. slug .. "." .. suffix
  return {
    id="red.command." .. slug .. "." .. suffix,
    actor="RED", voice=voice, phase=phase,
    snapshotId=snapshot.snapshotId, moveId=move.moveId,
    semanticClass=move.semanticClass,
    localeKeys={ en=base .. ".en", de=base .. ".de" },
    placeholders={ "POKEMON", "MOVE" },
    antiRepeat={ scope="ACTOR_AGENDA_PHASE_SEMANTIC_CLASS", historySize=4,
      fallbackId="red.command." .. slug .. "." .. other },
  }, semantic[variant]
end

return { actor="RED", voice=voice, make=make, templates=templates }
