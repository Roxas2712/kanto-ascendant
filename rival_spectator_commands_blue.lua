-- kasc.rival.spectator-duel-presentation/v1 -- Blue commands

local voice = "CONFIDENT_COMPETITIVE_POINTED"
local templates = {
  HEAL={
    {en="{POKEMON}, use {MOVE}. We are not done.", de="{POKEMON}, setz {MOVE} ein. Wir sind noch nicht fertig."},
    {en="Back to form, {POKEMON}. {MOVE}.", de="Wieder fit werden, {POKEMON}. {MOVE}."},
  },
  PROTECT={
    {en="Let it bounce off. {POKEMON}, {MOVE}.", de="Lass es abprallen. {POKEMON}, {MOVE}."},
    {en="Wrong opening! {POKEMON}, use {MOVE}.", de="Falsche Lücke! {POKEMON}, setz {MOVE} ein."},
  },
  BOOST={
    {en="Turn it up, {POKEMON}. {MOVE}.", de="Leg noch zu, {POKEMON}. {MOVE}."},
    {en="Take control. {POKEMON}, use {MOVE}.", de="Übernimm die Kontrolle. {POKEMON}, setz {MOVE} ein."},
  },
  CHARGE={
    {en="Power up, {POKEMON}. {MOVE} will finish this.", de="Kraft sammeln, {POKEMON}. {MOVE} entscheidet das."},
    {en="Make them wait. {POKEMON}, {MOVE}.", de="Lass sie warten. {POKEMON}, {MOVE}."},
  },
  DODGE={
    {en="Too slow! {POKEMON}, move with {MOVE}.", de="Zu langsam! {POKEMON}, raus da mit {MOVE}."},
    {en="Do not be there, {POKEMON}. {MOVE}.", de="Weg da, {POKEMON}. {MOVE}."},
  },
  MELEE={
    {en="Get in there, {POKEMON}. {MOVE}.", de="Geh rein, {POKEMON}. {MOVE}."},
    {en="No room for them. {POKEMON}, use {MOVE}.", de="Lass ihnen keinen Platz. {POKEMON}, setz {MOVE} ein."},
  },
  RANGED={
    {en="Keep them back. {POKEMON}, {MOVE}.", de="Halt sie auf Abstand. {POKEMON}, {MOVE}."},
    {en="Right from there! {POKEMON}, use {MOVE}.", de="Genau von dort! {POKEMON}, setz {MOVE} ein."},
  },
  MULTIPHASE={
    {en="Up you go, {POKEMON}. Then land {MOVE}.", de="Hoch mit dir, {POKEMON}. Dann sitzt {MOVE}."},
    {en="They cannot hit the sky. {POKEMON}, {MOVE}.", de="Da oben treffen sie dich nicht. {POKEMON}, {MOVE}."},
  },
}

local function make(snapshot, move, phase, variant)
  variant = variant == 2 and 2 or 1
  local semantic = assert(templates[move.semanticClass], "unknown move semantic")
  local slug = move.semanticClass:lower() .. "." .. phase:lower()
  local suffix = variant == 1 and "a" or "b"
  local other = variant == 1 and "b" or "a"
  local base = "life_of_rival.blue.command." .. slug .. "." .. suffix
  return {
    id="blue.command." .. slug .. "." .. suffix,
    actor="BLUE", voice=voice, phase=phase,
    snapshotId=snapshot.snapshotId, moveId=move.moveId,
    semanticClass=move.semanticClass,
    localeKeys={ en=base .. ".en", de=base .. ".de" },
    placeholders={ "POKEMON", "MOVE" },
    antiRepeat={ scope="ACTOR_AGENDA_PHASE_SEMANTIC_CLASS", historySize=4,
      fallbackId="blue.command." .. slug .. "." .. other },
  }, semantic[variant]
end

return { actor="BLUE", voice=voice, make=make, templates=templates }
