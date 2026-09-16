-- Green: capable, curious field researcher; competitive without random gags.
local voice='CURIOUS_CAPABLE_COMPETITIVE'
local templates={
  HEAL={{en='{POKEMON}, {MOVE}. Catch your breath.',de='{POKEMON}, {MOVE}. Hol kurz Luft.'},
    {en='We can still turn this around. {POKEMON}, {MOVE}.',de='Das können wir noch drehen. {POKEMON}, {MOVE}.'}},
  PROTECT={{en='I saw that coming. {POKEMON}, {MOVE}.',de='Das habe ich kommen sehen. {POKEMON}, {MOVE}.'},
    {en='Stay ready, {POKEMON}. {MOVE}.',de='Bleib bereit, {POKEMON}. {MOVE}.'}},
  BOOST={{en='Our opening! {POKEMON}, {MOVE}.',de='Unsere Chance! {POKEMON}, {MOVE}.'},
    {en='One step ahead. {POKEMON}, {MOVE}.',de='Einen Schritt voraus. {POKEMON}, {MOVE}.'}},
  CHARGE={{en='Wait for the right moment. {POKEMON}, {MOVE}.',de='Warte auf den richtigen Moment. {POKEMON}, {MOVE}.'},
    {en='Keep your focus, {POKEMON}. {MOVE}.',de='Bleib konzentriert, {POKEMON}. {MOVE}.'}},
  DODGE={{en='Watch their movement. {POKEMON}, {MOVE}.',de='Achte auf die Bewegung. {POKEMON}, {MOVE}.'},
    {en='Not that easily! {POKEMON}, {MOVE}.',de='Nicht so einfach! {POKEMON}, {MOVE}.'}},
  MELEE={{en='Now, before they recover! {POKEMON}, {MOVE}.',de='Jetzt, bevor sie sich fangen! {POKEMON}, {MOVE}.'},
    {en='Close the gap, {POKEMON}. {MOVE}.',de='Geh näher ran, {POKEMON}. {MOVE}.'}},
  RANGED={{en='We have a clear shot. {POKEMON}, {MOVE}.',de='Wir haben freie Bahn. {POKEMON}, {MOVE}.'},
    {en='Keep that distance, {POKEMON}. {MOVE}.',de='Halte diesen Abstand, {POKEMON}. {MOVE}.'}},
  MULTIPHASE={{en='Good position, {POKEMON}. Now {MOVE}.',de='Gute Position, {POKEMON}. Jetzt {MOVE}.'},
    {en='They are watching. Surprise them, {POKEMON}: {MOVE}.',de='Sie passen auf. Überrasch sie, {POKEMON}: {MOVE}.'}},
}
local function make(snapshot,move,phase,variant)
  variant=variant==2 and 2 or 1
  local slug=move.semanticClass:lower()..'.'..phase:lower()
  local suffix=variant==1 and 'a' or 'b';local other=variant==1 and 'b' or 'a'
  local base='life_of_rival.green.command.'..slug..'.'..suffix
  return {id='green.command.'..slug..'.'..suffix,actor='GREEN',voice=voice,phase=phase,
    snapshotId=snapshot.snapshotId,moveId=move.moveId,semanticClass=move.semanticClass,
    localeKeys={en=base..'.en',de=base..'.de'},placeholders={'POKEMON','MOVE'},
    antiRepeat={scope='ACTOR_AGENDA_PHASE_SEMANTIC_CLASS',historySize=4,
      fallbackId='green.command.'..slug..'.'..other}},assert(templates[move.semanticClass])[variant]
end
return {actor='GREEN',voice=voice,make=make,templates=templates}
