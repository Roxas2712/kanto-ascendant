-- A per-use genetic move view. No rerolls, stored stats or saved PP changes.
return function(mod,opts)
  local B=require('src.battle.BattleState')
  local Chart=require('src.battle.TypeChart')
  local M={CARD_ID='KASC-67-HIDDEN-POWER',OWNER='kasc.hidden-power/v1',ID='HIDDEN_POWER'}
  local types={'FIGHTING','FLYING','POISON','GROUND','ROCK','BUG','GHOST','STEEL',
    'FIRE','WATER','GRASS','ELECTRIC','PSYCHIC_TYPE','ICE','DRAGON','DARK'}
  local order={'hp','attack','defense','speed','specialAttack','specialDefense'}
  local frames=setmetatable({},{__mode='k'})
  local function copy(t)local r={};for k,v in pairs(t or{})do r[k]=type(v)=='table'and copy(v)or v end;return r end
  local function pack(...)return{n=select('#',...),...}end
  local function shallow(t)local r={};for k,v in pairs(t or{})do r[k]=v end;return r end
  local function int(v,a,z)return type(v)=='number'and v%1==0 and v>=a and v<=z end
  local function side(b,w)return w==b.player and'player'or w==b.enemy and'enemy'or nil end
  local function party(b,key)return key=='player'and b.game.save.party or b.enemyParty or{b.enemy.mon}end
  local function index(b,w)local key=side(b,w);if not key then return end
    for i,p in ipairs(party(b,key))do if i<=6 and p==w.mon then return i end end
  end
  local function state(b,create)
    if create then b.field=b.field or{};b.field.tokens=b.field.tokens or{};b.field.tokens[M.OWNER]=b.field.tokens[M.OWNER]or{}end
    return b and b.field and b.field.tokens and b.field.tokens[M.OWNER]
  end
  function M.epoch(b)
    local r=b and b.kascGenerationRulesReceipt
    local e=b and b.data and b.data.move_effects and b.data.move_effects.HEAL_EFFECT
    return getmetatable(b)==B and not b.demo and b.kind~='link'and not b.result
      and r and r.mode~='off'and int(r.activeEpoch,1,7)and e and e.kascHiddenPower67==M.OWNER and r.activeEpoch or nil
  end
  function M.genes(game,mon,gen)
    if gen<=2 then local dvs=mon and mon.dvs;local r={}
      for _,key in ipairs({'attack','defense','speed','special'})do
        if not(dvs and int(dvs[key],0,15))then return end;r[key]=dvs[key]
      end;return r
    end
    local genetics=assert(opts.genetics,'Hidden Power needs the existing genetics authority')
    return genetics.ivs(game,mon)or genetics.fromLegacy(mon)
  end
  function M.calculate(genes,gen)
    if not int(gen,2,7)or type(genes)~='table'then return end
    if gen==2 then
      for _,k in ipairs({'attack','defense','speed','special'})do if not int(genes[k],0,15)then return end end
      local a,d,s,c=genes.attack,genes.defense,genes.speed,genes.special
      return types[4*(a%4)+d%4+1],math.floor((5*(math.floor(c/8)+2*math.floor(s/8)
        +4*math.floor(d/8)+8*math.floor(a/8))+c%4)/2+31)
    end
    local t,p,weight=0,0,1
    for _,key in ipairs(order)do local iv=genes[key];if not int(iv,0,31)then return end
      t=t+weight*(iv%2);p=p+weight*(math.floor(iv/2)%2);weight=weight*2
    end
    return types[math.floor(t*15/63)+1],gen>=6 and 60 or math.floor(p*40/63)+30
  end
  local function savedRow(b,w)
    local s=state(b);local row=s and s[side(b,w)];local gen=M.epoch(b)
    local identity=mod.exports.pokemonBattleIdentity67
    if type(row)=='table'and gen and gen<=4 and identity and identity.transformed(w)and row.profile==gen
        and row.species==w.mon.species and row.index==index(b,w)then return row end
  end
  function M.value(b,w)
    local gen=M.epoch(b);if not gen or not w or not w.mon or not side(b,w)or not index(b,w)then return end
    gen=math.max(2,gen)
    local row=savedRow(b,w);local genes=row and row.genes or M.genes(b.game,w.mon,gen)
    return M.calculate(genes,gen)
  end
  function M.transformed(b,w,target)
    local gen=M.epoch(b);if not gen or not side(b,w)or not index(b,w)then return end
    local s=state(b);if s then s[side(b,w)]=nil end
    if gen>4 then return end
    local genes=M.genes(b.game,target.mon,math.max(2,gen));if not genes then return end
    state(b,true)[side(b,w)]={profile=gen,species=w.mon.species,index=index(b,w),genes=copy(genes)}
  end
  function M.project(b,w,move)
    if not move or move.id~=M.ID or move.backendMoveOwner~=M.OWNER then return move end
    if M.epoch(b)==1 and not(w and opts.rules.monMoveAvailable(b.game,w.mon,move.id,1,true))then return move end
    local typ,power=M.value(b,w);if not typ then return move end
    local out=copy(move);out.type=typ;out.power=power
    out.category=M.epoch(b)<=3 and Chart.category(typ)or'special'
    out.kascHiddenPower67=M.OWNER;return out
  end
  function M.move(original,b,inst,...)
    local move=original(b,inst,...);if not move or move.id~=M.ID or not M.epoch(b)then return move end
    local f=frames[b];local user=f and f.inst==inst and f.user
    if not user then for _,w in ipairs({b.player,b.enemy})do
      for _,slot in ipairs(w and w.curMoves or{})do if slot==inst then user=w;break end end
      if user then break end
    end end
    return user and M.project(b,user,move)or move
  end
  function M.scope(original,b,u,t,inst,called,...)
    local prior=frames[b];frames[b]={user=u,inst=inst}
    local out=pack(pcall(original,b,u,t,inst,called,...));frames[b]=prior
    if not out[1]then error(out[2],0)end;return unpack(out,2,out.n)
  end
  function M.damage(nextDamage,ctx)
    if not ctx or not ctx.move or ctx.move.id~=M.ID then return nextDamage(ctx)end
    local out=shallow(ctx)
    out.move=M.project(ctx.battle,ctx.user,ctx.move)
    local parent=mod.exports.pokemonParentalBond67
    if parent then parent.projected(ctx.battle,ctx.user,ctx.target,ctx.move,out.move)end
    return nextDamage(out)
  end
  function M.validateCheckpoint(b)
    if frames[b]then return false,'unsettled_hidden_power'end
    local s=state(b);if s==nil then return true end
    if type(s)~='table'or not M.epoch(b)then return false,'invalid_hidden_power_container'end
    for key,row in pairs(s)do local w=(key=='player'or key=='enemy')and b[key]
      if not w or not savedRow(b,w)or not M.calculate(row.genes,math.max(2,row.profile))then return false,'invalid_hidden_power_transform'end
      for k in pairs(row)do if k~='profile'and k~='species'and k~='index'and k~='genes'then return false,'unknown_hidden_power_field'end end
      local allowed={};for _,k in ipairs(row.profile<=2 and{'attack','defense','speed','special'}or order)do allowed[k]=true end
      for k in pairs(row.genes)do if not allowed[k]then return false,'unknown_hidden_power_gene'end end
    end;return true
  end
  function M.install()
    B._kascHiddenPower67=M
    if not B._kascHiddenPowerWrapped67 then local move,perform=B.moveDef,B.performMove
      B.moveDef=function(...)return B._kascHiddenPower67.move(move,...)end
      B.performMove=function(...)return B._kascHiddenPower67.scope(perform,...)end
      B._kascHiddenPowerWrapped67=true end
  end
  local old=assert(mod.content.moves:get(M.ID));local f=assert(opts.facts.move(M.ID,2))
  assert(f.number==237 and f.generation==2 and f.pp==15 and not old.backendMoveOwner,'Hidden Power authority/owner drift')
  mod.content.moves:patch(M.ID,{backendMoveOwner=M.OWNER,backendMoveNumber=237,
    backendLearnsetRevision=old.backendLearnsetRevision or 1})
  assert(mod.content.battle_anims:get(M.ID),'Hidden Power lacks existing native animation')
  mod.content.move_effects:patch('HEAL_EFFECT',{kascHiddenPower67=M.OWNER})
  -- Genetic type precedes ability/item conversion and physical/special
  -- projection; a converted actual view must not be changed back later.
  mod.hooks:wrap('battle.damage',M.damage,50000)
  mod.events:on('battle.battler_switched',function(ev)local s=state(ev.battle)
    if s and ev.previous and ev.previous.mon~=ev.battler.mon then s[side(ev.battle,ev.battler)]=nil end
  end,8000)
  mod.events:on('battle.ended',function(ev)frames[ev.battle]=nil;if state(ev.battle)then ev.battle.field.tokens[M.OWNER]=nil end end,10100)
  M.install()
  if opts.supportLog and opts.supportLog.registerSegment then opts.supportLog.registerSegment({
    segmentId=M.CARD_ID,cardId=M.CARD_ID,schema='kasc.optional-feature-card/v1',version='1.0.0',owner=M.OWNER,
    active=true,dependencyStatus='existing-authenticated-breeding-genetics-and-native-transform',
    providerStatus='gen2-7-per-use-hidden-power',buildReceiptId='docs/HIDDEN_POWER_67.md',
    rollbackReceiptId='docs/HIDDEN_POWER_67.md'})end
  return M
end
