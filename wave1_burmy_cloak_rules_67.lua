-- Pure family rules; the presentation/lifecycle adapter must opt in only
-- after every cloak has both reviewed 2D sides and a MAP/DISCS/ARENA front.
-- National species 412 remains 412: 10034/10035 are cosmetic source-form
-- IDs, not Pokemon IDs and not new entries in the species registry.
-- Behaviour source: pret/pokeplatinum 3f799c5a16398832df84a9c2b6e66836ca553076,
-- res/pokemon/burmy/data.json and BattleSystem_SetBurmyForm.
local R={SCHEMA='kasc.burmy-cloak/v1',FIELD='_kascBurmyCloak67',
  SOURCE_COMMIT='3f799c5a16398832df84a9c2b6e66836ca553076'}
local BURMY='KA_GIFT_NAT_412'
local cloaks={plant=true,sandy=true,trash=true}
local femaleTargets={plant='dex:413',sandy='form:10004',trash='form:10005'}
local terrain={
  grass='plant',tall_grass='plant',very_tall_grass='plant',
  snow='plant',ice='plant',water='plant',pond='plant',sea='plant',
  plain='sandy',sand='sandy',mountain='sandy',cave='sandy',
  distortion_world='sandy',giratina='sandy',
  building='trash',bridge='trash',aaron='trash',bertha='trash',
  flint='trash',lucian='trash',cynthia='trash',battle_tower='trash',
  battle_factory='trash',battle_arcade='trash',battle_castle='trash',
  battle_hall='trash',
}
local function isBurmy(mon)
  return type(mon)=='table' and mon.species==BURMY
    and not mon.isEgg and not mon.egg and not mon.eggSpecies
    and not mon._ascMegaForm and not mon.ascMegaForm
    and not mon.form and not mon.formId
end
function R.read(mon)
  if not isBurmy(mon) then return nil end
  local saved=mon[R.FIELD]
  if saved==nil then return 'plant' end
  if type(saved)=='table' and saved.schema==R.SCHEMA and cloaks[saved.cloak] then
    return saved.cloak
  end
  -- An invalid saved marker is a review case, not permission to reroll it.
  return nil
end
function R.terrainCloak(value)
  -- Callers classify actual world terrain, never the chosen battle renderer
  -- or a localized map name. Missing terrain must not mean "indoors".
  return type(value)=='string' and terrain[value] or nil
end
function R.setAfterParticipation(mon,cloak)
  local previous=R.read(mon)
  if not previous or not cloaks[cloak] or previous==cloak then return false end
  mon[R.FIELD]={schema=R.SCHEMA,cloak=cloak}
  return true
end
function R.evolutionKey(mon,gender,trigger)
  local cloak=R.read(mon)
  local level=mon and mon.level
  local hp=mon and mon.hp
  if not cloak or not trigger or trigger.kind~='levelup'
      or type(level)~='number' or level~=math.floor(level) or level<20 or level>100
      or type(hp)~='number' or hp<=0 or hp~=hp or hp==math.huge then return nil end
  if gender=='FEMALE' then return femaleTargets[cloak] end
  if gender=='MALE' then return 'dex:414' end
  return nil
end
-- A whole-battle ledger, independent of the native EXP participant set:
-- that set is cleared after each defeated opponent and drops fainted mons.
function R.begin(kind,worldTerrain,party,flags)
  flags=flags or {}
  local cloak=R.terrainCloak(worldTerrain)
  if (kind~='wild' and kind~='trainer') or not cloak
      or flags.link or flags.safari or flags.demo or flags.frontier or flags.palPark then
    return nil
  end
  local state={cloak=cloak,members={},participants={},closed=false}
  for _,mon in ipairs(party or {})do
    if R.read(mon) then state.members[mon]=true end
  end
  return state
end
function R.participate(state,battler)
  if not state or state.closed or type(battler)~='table' or battler.isPlayer~=true then return false end
  local mon=battler.mon
  -- Mere party membership, EXP Share, or being the enemy is insufficient.
  if not state.members[mon] or not R.read(mon) then return false end
  state.participants[mon]=true
  return true
end
function R.finish(state,party,skipped)
  if not state or state.closed then return 0 end
  state.closed=true
  local changed=0
  if not skipped then
    for _,mon in ipairs(party or {})do
      if state.participants[mon] and R.setAfterParticipation(mon,state.cloak) then
        changed=changed+1
      end
    end
  end
  -- Do not retain references to an ended battle or a deposited party.
  state.members={};state.participants={}
  return changed
end
return R
