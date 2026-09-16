-- Authored crew teams through KASC's existing forced-battle factory.
return function(mod,opts)
 local D=assert(opts.data)
 local M={classes={}}
 local function copy(v)
  if type(v)~='table'then return v end
  local r={};for k,x in pairs(v)do r[k]=copy(x)end;return r
 end
 local function exports()return opts.exports and opts.exports()or mod.exports end
 function M.register()
  local base=mod.content.trainers:get('OPP_YOUNGSTER')
  if not base then return false,'missing_stock_trainers'end
  for _,id in ipairs(D.order)do
   local row=D.opponents[id]
   local class=row.trainerClass or('KA_BALD_CREW_'..id:upper())
   if not M.classes[id]then
    if row.trainerClass then assert(mod.content.trainers:get(class),'authored Crew class missing')
    else
     assert(not mod.content.trainers:get(class),'Crew class already owned: '..class)
     local def=copy(base);def.id=class;def.name=row.displayName;def.parties={};def.baseMoney=0
     mod.content.trainers:register(class,def)
    end
    M.classes[id]=class
   end
  end
  return true
 end
 local function nativeMove(ex,data,id)
  if data.moves[id]then return id end
  local provider=ex.backendGiftSpecies67
  return provider and provider.moveId and provider.moveId(id)or nil
 end
 function M.team(game,row)
  if not row or (D.opponents[row.id]~=row and D.opponents.pandy.phaseTwo~=row)
    or not row.ready or #row.team~=6 then return nil,'roster_unapproved'end
  local ex=exports();local rules=assert(ex.generationRules)
  local epoch=rules.resolve(game).activeEpoch
  local P=require('src.pokemon.Pokemon')
  local out,receipt={}, {epoch=epoch,opponent=row.id,moveChanges={}}
  for i,source in ipairs(row.team)do
   if source.level~=100 then return nil,'boss_level_must_be_100:'..i end
   if type(source.moves)~='table'or #source.moves<1 or #source.moves>4 then return nil,'invalid_moves:'..i end
   local species=source.species
   if not game.data.pokemon[species]then
    species=ex.trainerGenerationPool67 and ex.trainerGenerationPool67.resolve(species)
   end
   if not species or not game.data.pokemon[species]then return nil,'missing_species:'..source.species end
   local mon=P.new(game.data,species,source.level)
   local moves,used={},{}
   local function add(id)
    id=nativeMove(ex,game.data,id)
    -- Maintainer-approved exception: only the real final roster's Rayquaza.
    -- No catalogue, player learnset or ordinary trainer permission is changed.
    local finalAscent=row==D.opponents.pandy and source==row.team[6]
      and source.species=='RAYQUAZA'and id=='DRAGON_ASCENT'
    if id and game.data.moves[id]and not used[id]and (finalAscent or rules.moveAvailable(id,epoch,game.data))then
     used[id]=true;moves[#moves+1]=id;return true
    end
   end
   for _,id in ipairs(source.moves or{})do
    if not add(id)then receipt.moveChanges[#receipt.moveChanges+1]={slot=i,unavailable=id}end
   end
   -- Historical profiles keep the same personal species. Only unavailable
   -- moves are filled from that species' already-projected native learnset.
   for _,move in ipairs(mon.moves or{})do if #moves<#source.moves then add(move.id)end end
   local damaging=false
   for _,id in ipairs(moves)do if (game.data.moves[id].power or 0)>0 then damaging=true end end
   if not damaging or #moves==0 then return nil,'no_damage_move:'..species end
   local slot=copy(source);slot.species=species;slot.moves=moves
   out[i]=slot
  end
  return out,nil,receipt
 end
 local function restoreParty(party,snapshot)
  for i,mon in ipairs(party)do
   for k in pairs(mon)do mon[k]=nil end
   for k,v in pairs(snapshot[i])do mon[k]=copy(v)end
  end
 end
 function M.newBattle(game,row,index)
  if D.order[index]~=row.id then return nil,'opponent_index'end
  local team,why,receipt=M.team(game,row);if not team then return nil,why end
  local reserve,reserveReceipt
  if row.phaseTwo then
   reserve,why,reserveReceipt=M.team(game,row.phaseTwo)
   if not reserve then return nil,why end
  end
  local class=M.classes[row.id]
  if not class or not game.data.trainers[class]then return nil,'trainer_unregistered'end
  local ex=exports();local P=require('src.pokemon.Pokemon')
  local B=require('src.battle.BattleState');local Stats=require('src.pokemon.Stats')
  local party=game.save.party;local saved=copy(party)
  local function rollback()restoreParty(party,saved)end
  local heal=D.blocks[index]==index or row.fullRestoreBefore==true
  local arm
  local ok,battle=pcall(function()
  if heal then for _,mon in ipairs(party)do P.heal(mon)end end
  local battle=ex.postgame.newForcedBattle(game,class,team,'bald_crew',{
   source='bald_crew:'..row.id,preserveAuthoredRoster=true})
  assert(type(battle)=='table'and type(battle.enemyParty)=='table','invalid_battle')
  -- A randomizer may wrap the common factory. Personal submissions own this
  -- roster; reject identity drift instead of silently fighting someone else.
  local function configure(party,roster,owner,epoch)
  for i,slot in ipairs(roster)do
   local mon=party[i]
   assert(mon and mon.species==slot.species,'authored_team_changed:'..i..':'..slot.species..':'..tostring(mon and mon.species))
   mon.level=100 -- Crew bosses never inherit common-factory/player scaling.
   mon.nickname=slot.nickname;mon.shiny=slot.shiny;mon.gender=slot.gender
   mon.dvs=copy(slot.dvs or owner.dvs or mon.dvs)
   mon.statExp=copy(slot.statExp or owner.statExp or mon.statExp)
   mon.item=slot.item;mon.heldItem=slot.item
   mon.ability=slot.ability;mon.abilityId=nil;mon._kascAbility67=nil
   local binding=ex.pokemonAbilityBinding67
   if binding then
    local plan=binding.plan(game,mon,'bald-crew:'..row.id..':'..i,epoch)
    if not plan and epoch>=3 and slot.ability then
     -- A later hidden ability must not become active in an older profile.
     mon.ability=nil;plan=binding.plan(game,mon,'bald-crew:'..row.id..':'..i,epoch)
    end
    if plan then for k,v in pairs(plan)do mon[k]=v end end
   end
   mon.moves={}
   for _,id in ipairs(slot.moves)do mon.moves[#mon.moves+1]={id=id,pp=game.data.moves[id].pp}end
   mon.stats=Stats.calc(game.data.pokemon[mon.species],mon.level,mon.dvs,mon.statExp,mon)
   mon.hp=mon.stats.hp
  end
  end
  configure(battle.enemyParty,team,row,receipt.epoch)
  if reserve then
   local party={}
   for i,slot in ipairs(reserve)do party[i]=P.new(game.data,slot.species,slot.level)end
   configure(party,reserve,row.phaseTwo,reserveReceipt.epoch)
   battle.kaCrewReserveParty=party;battle.kaCrewPhase=1
  end
  battle.enemy=B.makeBattler(game.data,battle.enemyParty[1],false)
  battle.enemyIndex=1;battle.kaBaldCrew=true;battle.kaCrewOpponent=row.id
  battle.kaCrewRulesReceipt=receipt;battle.kaCrewCheckpointHealing=heal
  battle.ascendantNoItems=true;battle.noPrizeMoney=true;battle.enemyAIMods={1,2,3}
  battle.trainer=setmetatable({name=row.displayName},{__index=battle.trainer})
  if opts.mega then
   local why;arm,why=opts.mega.prepare(battle,row)
   assert(arm,why)
  end
  return battle
  end)
  if not ok then rollback();return nil,'battle_factory:'..tostring(battle)end
  return battle,nil,rollback,arm
 end
 return M
end
