local root=os.getenv('KANTO_ASCENDANT_MOD_DIR') or '.'
local engine=assert(os.getenv('GEN1RECOMP_DIR'),'GEN1RECOMP_DIR required')
package.path=engine..'/?.lua;'..engine..'/?/init.lua;'..package.path
local S=require('src.core.SaveSerializer')
local syncs=0
local events={};local writes=0;local fail=false;local locked=false
local mod={id='kanto_ascendant',ui={},hooks={wrap=function()end},events={}}
function mod.events:on(id,fn)events[id]=fn end
local catalog=dofile(root..'/backend_national_catalog_67_data.lua')
local facts=dofile(root..'/backend_generation_rules_67.lua'){
  catalog=catalog,data=dofile(root..'/backend_generation_rules_67_data.lua'),
  load=function(p)return dofile(root..'/'..p)end}
local sha=dofile(root..'/legacy_bank_sha256.lua')
local abilities=dofile(root..'/pokemon_ability_binding_67.lua'){
  catalog=catalog,facts=facts,digest=sha}
local game={data={pokemon={}},save={meta={playthroughId='acquisition-fixture'},
  party={{species='BULBASAUR',heldItem='BERRY'}},
  modData={kanto_ascendant={rules={activeEpoch=2,unlockedEpoch=2}}}}}
function game:writeSave()writes=writes+1;return not fail end
local rules={SAVE_KEY='rules',safeBoundary=function()return not locked,'transaction_active'end}
function rules.syncData()syncs=syncs+1 end
function rules.resolve(g)
  local st=g.save.modData.kanto_ascendant.rules
  for _,m in ipairs(g.save.party)do
    if m.species=='TREECKO' and not m.isEgg then st.unlockedEpoch=3 end
  end
  st.activeEpoch=st.unlockedEpoch
end
local U=dofile(root..'/pokemon_equipment_runtime_67.lua')(mod,{
  rules=rules,facts=facts,evidence=dofile(root..'/generation_evidence.lua')(mod,{}),
  abilities=abilities,i18n={text=function(en)return en end},digest=sha,
  makeCore=dofile(root..'/pokemon_equipment_67.lua')})
events['game.ready']({game=game});events['world.stepped']({})
assert(writes==1 and not game.save.party[1]._kascAbility67)
events['world.stepped']({});assert(writes==1,'unchanged walk saves every step')
local egg={species='TREECKO',isEgg=true,eggSpecies='TREECKO'}
game.save.party[2]=egg;events['world.stepped']({})
assert(game.save.modData.kanto_ascendant.rules.activeEpoch==2 and not egg._kascAbility67)
egg.isEgg=nil;egg.eggSpecies=nil
local before=S.encode(game.save);fail=true
assert(select(2,U.checkpoint(game))=='save_failed')
assert(S.encode(game.save)==before,'failed hatch binding committed AUTO evidence')
fail=false;locked=true;local n=writes
assert(not U.checkpoint(game) and writes==n,'battle performed a save')
locked=false;assert(U.checkpoint(game))
assert(game.save.modData.kanto_ascendant.rules.activeEpoch==3)
assert(egg._kascAbility67 and game.save.party[1]._kascAbility67)
assert(game.save.party[1].heldItem=='BERRY' and not egg.heldItem,'hatch/migration rolled items')
n=writes;assert(U.checkpoint(game) and writes==n)
local foreign={species='TREECKO'} -- not in party/boxes/daycare; never acquired
assert(not foreign._kascAbility67)
game.save=assert(S.decode(assert(S.encode(game.save))))
n=writes
local beforeSyncs=syncs
local revision=game.save.modData.kanto_ascendant.pokemon_equipment_67.revision
events['save.loaded']({game=game});assert(U.checkpoint(game))
assert(writes==n,'unchanged reload forced another full save')
assert(game.save.modData.kanto_ascendant.pokemon_equipment_67.revision==revision,
  'unchanged reload invalidated equipment views')
local one,two=game.save.party[1],game.save.party[2]
game.save.party={two,one};assert(U.checkpoint(game))
assert(writes==n,'party switch forced another full save')
game.save.party={one,two};assert(U.checkpoint(game))
assert(writes==n,'switching back forced another full save')
assert(syncs==beforeSyncs,'unchanged reload/switch rebuilt all battle data')
-- Rule-only evidence must still be persisted even without new mon bindings.
game.save.modData.kanto_ascendant.rules.activeEpoch=2
fail=true;local beforeRules=S.encode(game.save)
assert(select(2,U.checkpoint(game))=='save_failed')
assert(S.encode(game.save)==beforeRules,'rule-only save failure lost rollback')
fail=false;assert(U.checkpoint(game))
assert(game.save.modData.kanto_ascendant.rules.activeEpoch==3)
assert(writes==n+2,'rule-only change was not durably retried')
assert(syncs==beforeSyncs+1,'committed rule-only change did not synchronize battle data')
local slot=game.save.party[2]._kascAbility67.slot
assert(slot==egg._kascAbility67.slot,'load changed the inherited identity')
print('equipment acquisition: safe ownership checkpoint, AUTO on hatch, rollback, no rerolls/egg items PASS')
