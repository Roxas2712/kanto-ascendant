-- Field/side conditions own their timeline, not persistent mon stat/item edits.
return function(mod,opts)
  local B=require('src.battle.BattleState')
  local Player=require('src.battle.AnimPlayer')
  local M={CARD_ID='KASC-67-BATTLE-ROOMS',OWNER='kasc.battle-rooms/v1'}
  local defs={TAILWIND={number=366,gen=4,type='FLYING',target=4},
    TRICK_ROOM={number=433,gen=4,type='PSYCHIC_TYPE',target=12},
    WONDER_ROOM={number=472,gen=5,type='PSYCHIC_TYPE',target=12},
    MAGIC_ROOM={number=478,gen=5,type='PSYCHIC_TYPE',target=12}}
  local tr=opts.i18n.text;local activeBattle
  local function copy(v)local r={};for k,x in pairs(v or{})do r[k]=x end;return r end
  local function clone(v)if type(v)~='table'then return v end;local r={};for k,x in pairs(v)do r[k]=clone(x)end;return r end
  local function pack(...)return{n=select('#',...),...}end
  local function integer(v,a,z)return type(v)=='number'and v%1==0 and v>=a and v<=z end
  local function live(w)local p=w and w.mon;return p and integer(p.hp,1,99999)and not w.fainted
    and not(p.egg or p.isEgg or p.is_egg or p.eggSpecies or p.species=='EGG')end
  local function side(b,w)return w==b.player and'player'or w==b.enemy and'enemy'or nil end
  local function native(b,w)
    if not w or not w.mon then return end
    return b.player and b.player.mon==w.mon and b.player or b.enemy and b.enemy.mon==w.mon and b.enemy
  end
  local function state(b,create)
    if create then b.field=b.field or{};b.field.tokens=b.field.tokens or{}
      b.field.tokens[M.OWNER]=b.field.tokens[M.OWNER]or{fields={},tails={}}end
    return b and b.field and b.field.tokens and b.field.tokens[M.OWNER]
  end
  function M.epoch(b)
    local r=b and b.kascGenerationRulesReceipt
    local h=b and b.data and b.data.move_effects and b.data.move_effects.HEAL_EFFECT
    if getmetatable(b)==B and not b.demo and b.kind~='link'and not b.result and r and r.mode~='off'
        and integer(r.activeEpoch,1,7)and h and h.kascBattleRooms67==M.OWNER then return r.activeEpoch end
  end
  function M.profile(b,w,m)
    local epoch=M.epoch(b);local d=m and defs[m.id]
    local e=d and b.data.move_effects[m.effect]
    if not epoch or not d or not live(w)or not side(b,w)or m.backendMoveOwner~=M.OWNER
        or m.backendMoveNumber~=d.number or not e or e.kascBattleRooms67~=M.OWNER then return end
    if epoch<d.gen and not(opts.rules.ownedGiftBattleCompatible
        and opts.rules.ownedGiftBattleCompatible(b.game,w.mon,b.data.pokemon[w.mon.species]))then return end
    return math.max(d.gen,epoch)
  end
  local function duration(id,gen)return id=='TAILWIND'and(gen==4 and 3 or 4)or 5 end
  local function validRow(b,id,row)
    local d=defs[id];local epoch=M.epoch(b);local turn=b.turnCount or 0
    return d and epoch and type(row)=='table'and row.profile==epoch and row.epoch==math.max(epoch,d.gen)
      and integer(row.applied,0,turn)and row.expires==row.applied+duration(id,row.epoch)-1
      and integer(row.lastTurn,row.applied-1,turn)and turn<=row.expires
  end
  function M.active(b,id,w)
    if not M.epoch(b)then return false end
    local s=state(b);if type(s)~='table'or type(s.fields)~='table'or type(s.tails)~='table'then return false end
    local row=id=='TAILWIND'and s.tails and s.tails[side(b,native(b,w))]
      or s.fields and s.fields[id]
    return validRow(b,id,row)and row or false
  end
  function M.speedFactor(b,w)return M.active(b,'TAILWIND',w)and 2 or 1 end
  function M.hasOrderEffect(b)
    return M.active(b,'TRICK_ROOM')or M.active(b,'TAILWIND',b.player)or M.active(b,'TAILWIND',b.enemy)or false
  end
  local function plainSpeed(b,w)
    local choice=mod.exports and mod.exports.pokemonChoiceItems67
    return choice and choice.speed(b,w)or opts.weather.speed(b,w)
  end
  function M.actionSpeed(b,w)
    local speed=math.min(10000,math.max(1,math.floor(plainSpeed(b,w))))
    local trick=M.active(b,'TRICK_ROOM')
    -- IV overrides getActionSpeed with a signed inversion; V--VII use
    -- 10000-speed followed by13bit truncation (>1808 overflow behavior).
    if trick then return trick.epoch==4 and -speed or(10000-speed)%8192 end
    return M.epoch(b)<=4 and speed or speed%8192
  end
  local function priority(m)return m and(m.priority or({QUICK_ATTACK=1,COUNTER=-1})[m.id]or 0)or 0 end
  function M.order(nextOrder,a,am,z,zm,ctx)
    local b=activeBattle
    if not b or not M.hasOrderEffect(b)or a~=b.player or z~=b.enemy
        or priority(am)~=priority(zm)then return nextOrder(a,am,z,zm,ctx)end
    local sa,sz=M.actionSpeed(b,a),M.actionSpeed(b,z)
    if sa~=sz then return sa>sz end
    local first=(ctx.rng or b.rng)(0,1)==0
    if ctx.invertTie then first=not first end
    return first
  end
  function M.scoped(original,b,...)
    local prior=activeBattle;activeBattle=b;local out=pack(pcall(original,b,...));activeBattle=prior
    if not out[1]then error(out[2],0)end;return unpack(out,2,out.n)
  end
  function M.damage(nextDamage,ctx)
    local b=ctx and ctx.battle
    if not b or not M.active(b,'WONDER_ROOM')or not ctx.target or not native(b,ctx.target)then return nextDamage(ctx)end
    -- Swap raw defenses BEFORE SplitSpecial/stages/defensive modifiers.
    -- Download and stat-split/form owners still see the real stored pair.
    local target=ctx.target;local stats=target.curStats
    local special=M.epoch(b)==1 and'special'or'specialDefense'
    if not stats or not integer(stats.defense,1,9999)or not integer(stats[special],1,9999)then return nextDamage(ctx)end
    local out=copy(ctx);out.target=copy(target);out.target.curStats=copy(stats)
    out.target.curStats.defense,out.target.curStats[special]=stats[special],stats.defense
    return nextDamage(out)
  end
  function M.itemSuppressed(b,w,id)
    local actual=b and native(b,w)
    -- Primal form orbs ignore suppression; training-item penalties do NOT
    -- get Klutz's unrelated exemption. Item possession is never removed.
    return id and id~='BLUE_ORB'and id~='RED_ORB'and actual and actual.mon==w.mon
      and M.active(b,'MAGIC_ROOM')~=false or false
  end
  function M.blocksMove(b,w,id)
    return (id=='FLING'or id=='NATURAL_GIFT')and M.active(b,'MAGIC_ROOM')~=false
      and native(b,w)~=nil or false
  end
  function M.cast(ctx)
    local b,w,m=ctx.battle,ctx.user,ctx.move;local gen=M.profile(b,w,m)
    if not gen then return{tr('But, it failed!','Doch es schlug fehl!'),failed=true}end
    local s=state(b,true);local tail=m.id=='TAILWIND';local key=tail and side(b,w)or m.id
    local rows=tail and s.tails or s.fields
    if M.active(b,m.id,w)then
      if tail then return{tr('But, it failed!','Doch es schlug fehl!'),failed=true}end
      rows[key]=nil
      return{tr('%s ended!','%s endet!'):format(m.name)}
    end
    local turn=b.turnCount or 0
    rows[key]={profile=M.epoch(b),epoch=gen,applied=turn,expires=turn+duration(m.id,gen)-1,lastTurn=turn-1}
    return{tr('%s took effect!','%s wirkt jetzt!'):format(m.name)}
  end
  local function rawHeld(b,w)
    local id,err=opts.held(w.mon);if err or not id or id=='BLUE_ORB'or id=='RED_ORB'then return false end
    return b.data.items[id]and id or false
  end
  local function dominant(b,w)
    local best,power
    for _,slot in ipairs(w.curMoves or{})do local m=b:moveDef(slot)
      if m and(slot.pp or 0)>0 and m.category~='status'and(m.power or 0)>0 and(not power or m.power>power)then
        best,power=m.category,m.power
      end
    end
    return best
  end
  function M.noUseful(b,w,t,m)
    if not M.profile(b,w,m)then return false end
    local active=M.active(b,m.id,w)
    if m.id=='TAILWIND'then return active~=false end
    if not live(t)or not side(b,t)then return true end
    if m.id=='TRICK_ROOM'then
      local a,z=plainSpeed(b,w),plainSpeed(b,t)
      return active and a<=z or not active and a>=z
    elseif m.id=='MAGIC_ROOM'then
      local a,z=rawHeld(b,w),rawHeld(b,t)
      local minePenalty=a=='IRON_BALL'or a=='MACHO_BRACE'or a and a:match('^POWER_')~=nil
      local score=(z and 1 or 0)+(minePenalty and 1 or a and -1 or 0)
      return active and score>=0 or not active and score<=0
    end
    local a,z=w.curStats,t.curStats;local special=M.epoch(b)==1 and'special'or'specialDefense'
    if not a or not z or not integer(a.defense,1,9999)or not integer(a[special],1,9999)
        or not integer(z.defense,1,9999)or not integer(z[special],1,9999)then return true end
    local ours,theirs=dominant(b,w),dominant(b,t);local score=0
    if ours=='physical'then score=score+(z.defense-z[special])/math.max(z.defense,z[special])
    elseif ours=='special'then score=score+(z[special]-z.defense)/math.max(z.defense,z[special])end
    if theirs=='physical'then score=score+(a[special]-a.defense)/math.max(a.defense,a[special])
    elseif theirs=='special'then score=score+(a.defense-a[special])/math.max(a.defense,a[special])end
    return active and score>=0 or not active and score<=0
  end
  function M.endTurn(ev)
    local b=ev and ev.battle;local s=state(b);if not s or not M.epoch(b)then return end
    -- CP restore validates before execution; a direct malformed token must
    -- also fail closed rather than compare a foreign/missing expiry value.
    if not M.validateCheckpoint(b)then return end
    local turn=b.turnCount or 0
    for _,list in ipairs({s.fields,s.tails})do for key,row in pairs(list)do
      if type(row)=='table'and row.lastTurn~=turn then
        row.lastTurn=turn
        if turn>=row.expires then
          list[key]=nil;local id=list==s.tails and'TAILWIND'or key
          local move=b.data.moves[id]
          b:sayNext(tr('%s wore off!','%s lässt nach!'):format(move and move.name or id))
        end
      end
    end end
  end
  function M.validateCheckpoint(b)
    local s=state(b);if s==nil then return true end
    if type(s)~='table'or type(s.fields)~='table'or type(s.tails)~='table'or not M.epoch(b)then return false,'invalid_room_container'end
    for key in pairs(s)do if key~='fields'and key~='tails'then return false,'unknown_room_container_field'end end
    for _,tail in ipairs({false,true})do for key,row in pairs(tail and s.tails or s.fields)do
      local id=tail and'TAILWIND'or key
      if tail and key~='player'and key~='enemy'or not tail and(key=='TAILWIND'or not defs[key])
          or not validRow(b,id,row)then return false,'invalid_room_timeline'end
      for field in pairs(row)do if field~='profile'and field~='epoch'and field~='applied'
          and field~='expires'and field~='lastTurn'then return false,'unknown_room_timeline_field'end end
    end end
    return true
  end
  function M.move(original,b,inst,...)
    local m=original(b,inst,...);local d=m and defs[m.id]
    if not d or m.backendMoveOwner~=M.OWNER or not M.epoch(b)then return m end
    local gen=math.max(d.gen,M.epoch(b));local out=copy(m)
    out.priority=(m.id=='TRICK_ROOM'or gen==5 and(m.id=='WONDER_ROOM'or m.id=='MAGIC_ROOM'))and -7 or 0
    if m.id=='TAILWIND'then out.pp=gen<=5 and 30 or 15 end
    return out
  end
  function M.install()
    B._kascBattleRooms67=M
    Player._kascBattleRooms67=M
    if not Player._kascBattleRoomsWrapped67 then local original=Player.start
      Player.start=function(self,id,...)
        local out=pack(original(self,id,...));Player._kascBattleRooms67.position(self,id);return unpack(out,1,out.n)
      end
      Player._kascBattleRoomsWrapped67=true
    end
    if not B._kascBattleRoomsWrapped67 then
      local resolve,move=B.resolveTurn,B.moveDef
      B.resolveTurn=function(...)return B._kascBattleRooms67.scoped(resolve,...)end
      B.moveDef=function(...)return B._kascBattleRooms67.move(move,...)end
      B._kascBattleRoomsWrapped67=true
    end
    local held=opts.heldEffect
    if held and not held._kascBattleRoomsWrapped67 then
      local suppress,blocks=held.suppressed,held.blocksMove
      held.suppressed=function(b,w,id)
        return B._kascBattleRooms67.itemSuppressed(b,w,id)or suppress(b,w,id)
      end
      held.blocksMove=function(b,w,id)
        return B._kascBattleRooms67.blocksMove(b,w,id)or blocks(b,w,id)
      end
      held._kascBattleRoomsWrapped67=true
    end
  end
  function M.position(player,id)
    local anim=player.data and player.data.moveAnims and player.data.moveAnims[id]
    if not defs[id]or not anim or anim.source~=M.OWNER then return end
    for _,step in ipairs(player.steps or{})do local sprites={};for i,s in ipairs(step.sprites or{})do local q=clone(s)
      if q.x>0 and q.x<168 and q.y>0 and q.y<160 and mod.exports.pokemonPartnerHits67.inHud(q)then q.x=0 end
      sprites[i]=q end;step.sprites=sprites end
  end
  for id,d in pairs(defs)do
    local f=assert(opts.facts.move(id,7));local old=assert(mod.content.moves:get(id))
    assert(f.number==d.number and f.generation==d.gen and f.category=='status'and f.alwaysHits
      and f.power==0 and f.target==d.target and f.type==d.type,'battle room source drift '..id)
    assert(not old.backendMoveOwner and old.effect=='KA_GEN_MOVE_UNSUPPORTED_'..id,'foreign room owner '..id)
    local effect='KA_BATTLE_ROOM_67_'..id
    mod.content.move_effects:register(effect,{kind='primary',accuracyChecked=false,kascBattleRooms67=M.OWNER,run=M.cast})
    mod.content.moves:patch(id,{effect=effect,backendMoveOwner=M.OWNER,backendMoveNumber=d.number,
      originGeneration=d.gen,backendLearnsetRevision=old.backendLearnsetRevision or 1,
      category='status',type=d.type,target=d.target,power=0,pp=f.pp,accuracy=100,
      priority=id=='TRICK_ROOM'and -7 or 0,flags=id=='TAILWIND'and{snatch=1}or{mirror=1}})
    local animation={seq={},source=M.OWNER}
    for _,part in ipairs({'FOCUS_ENERGY','LIGHT_SCREEN'})do
      for _,step in ipairs(assert(mod.content.battle_anims:get(part)).seq)do animation.seq[#animation.seq+1]=clone(step)end
    end
    mod.content.battle_anims:patch(id,animation)
    for i=#opts.catalog.unsupportedStatus,1,-1 do if opts.catalog.unsupportedStatus[i]==id then table.remove(opts.catalog.unsupportedStatus,i)end end
  end
  mod.content.move_effects:patch('HEAL_EFFECT',{kascBattleRooms67=M.OWNER})
  mod.hooks:wrap('battle.damage',M.damage,20001)
  mod.hooks:wrap('battle.turn_order',M.order,-7001)
  mod.events:on('battle.turn_ended',M.endTurn,-20000)
  mod.events:on('battle.ended',function(ev)
    local s=state(ev.battle);if s then ev.battle.field.tokens[M.OWNER]=nil end
  end,-20000)
  M.install()
  if opts.supportLog and opts.supportLog.registerSegment then opts.supportLog.registerSegment({segmentId=M.CARD_ID,
    cardId=M.CARD_ID,schema='kasc.optional-feature-card/v1',version='1.0.0',owner=M.OWNER,active=true,
    dependencyStatus='native-side-field-timeline-priority-final-speed-raw-defense-item-effect',
    providerStatus='gen4-7-tailwind-trick-room-gen5-7-wonder-magic-room',
    buildReceiptId='docs/BATTLE_ROOMS_67.md',rollbackReceiptId='docs/BATTLE_ROOMS_67.md'})end
  return M
end
