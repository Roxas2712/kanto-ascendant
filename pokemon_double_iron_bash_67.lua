-- Panzerfaeuste: two separately resolved native hits, never cached damage.
return function(mod,opts)
  local B=require('src.battle.BattleState')
  local M={CARD_ID='KASC-67-DOUBLE-IRON-BASH',OWNER='kasc.double-iron-bash/v1'}
  local id='DOUBLE_IRON_BASH';local effect='KA_DOUBLE_IRON_BASH_67'
  local row={min=2,max=2,generation=7}
  local function copy(v)if type(v)~='table'then return v end;local r={};for k,x in pairs(v)do r[k]=copy(x)end;return r end
  function M.profile(b,ctx)
    local r=b and b.kascGenerationRulesReceipt;local move=ctx and ctx.move
    local marker=b and b.data and b.data.move_effects and b.data.move_effects[effect]
    if getmetatable(b)~=B or b.demo or b.kind=='link'or b.result or not r or r.mode=='off'
        or r.activeEpoch<1 or r.activeEpoch>7 or not move or move.id~=id
        or move.backendMoveOwner~=M.OWNER or not marker or marker.kascDoubleIronBash67~=M.OWNER then return end
    if r.activeEpoch<7 then
      local u=ctx.user;local rules=mod.exports.generationRules
      if not u or not rules.ownedGiftBattleCompatible(b.game,u.mon,b.data.pokemon[u.mon.species])then return end
    end
    -- The later gift attack retains per-strike damage/crit semantics;
    -- item and ability gates still read the actual battle receipt.
    return row,7
  end
  function M.afterHit(ctx)
    if not M.profile(ctx.battle,ctx)then return end
    local b,t=ctx.battle,ctx.target
    if ctx.user.mon.hp<=0 or t.mon.hp<=0 or t.substituteHP or ctx.brokeSub then return end
    -- First-action state also covers Gen I, whose native flinch sampler
    -- has no later-era acted table. Never carry a late flinch into next turn.
    local first=mod.exports.pokemonFirstAction67
    local state=first and b.field and b.field.tokens and b.field.tokens[first.OWNER]
    local side=t==b.player and'player'or'enemy'
    if state and state[side]and state[side].acted then return end
    for _,message in ipairs(b.data.move_effects.FLINCH_SIDE_EFFECT2.run(ctx)or{})do b:sayNext(message)end
  end
  local f=assert(opts.facts.move(id,7))
  assert(f.number==742 and f.type=='STEEL'and f.category=='physical'and f.power==60
    and f.accuracy==100 and f.pp==5 and f.priority==0 and f.target==10
    and f.meta.min_hits==2 and f.meta.max_hits==2 and f.meta.flinch_chance==30,'Panzerfaeuste source drift')
  assert(not mod.content.moves:get(id),'foreign Double Iron Bash')
  mod.content.move_effects:register(effect,{kind='full',kascDoubleIronBash67=M.OWNER,
    gate=function(ctx)if M.profile(ctx.battle,ctx)then return true end
      return false,opts.i18n.text('But, it failed!','Doch es schlug fehl!')end,
    hitCount=2,afterDamage=M.afterHit})
  mod.content.moves:register(id,{id=id,name=opts.i18n.text(f.names.en,f.names.de),type='STEEL',category='physical',
    power=60,accuracy=100,pp=5,priority=0,target=10,contact=true,punch=true,effect=effect,
    originGeneration=7,backendMoveNumber=742,backendMoveOwner=M.OWNER,backendLearnsetRevision=24,
    anim=copy(assert(mod.content.moves:get('MEGA_PUNCH')).anim)})
  local anim=copy(assert(mod.content.battle_anims:get('MEGA_PUNCH')));anim.source=M.OWNER
  mod.content.battle_anims:register(id,anim)
  local Player=require('src.battle.AnimPlayer')
  function M.position(player,move)
    local r=player.data and player.data.moveAnims and player.data.moveAnims[move]
    if move~=id or not r or r.source~=M.OWNER then return end
    for _,step in ipairs(player.steps or{})do local sprites={};local shift=-16
      -- Keep an entire effect cluster together when its upper tiles approach
      -- the viewport edge. Per-tile clamping would tear the impact star apart.
      for _,s in ipairs(step.sprites or{})do
        if s.x>0 and s.x<168 and s.y>0 and s.y<160 then shift=math.max(shift,16-s.y)end
      end
      for i,s in ipairs(step.sprites or{})do
        local q=copy(s)
        if q.x>0 and q.x<168 and q.y>0 and q.y<160 then q.y=q.y+shift end
        if q.x>0 and q.x<168 and q.y>0 and q.y<160 then
          local x,y=q.x-8,q.y-16
          for _,box in ipairs({{0,0,88,30},{72,56,160,94},{0,98,160,144}})do
            if x<box[3]and x+8>box[1]and y<box[4]and y+8>box[2]then q.x=0;break end
          end
        end
        sprites[i]=q
      end
      step.sprites=sprites
    end
  end
  Player._kascDoubleIronBashAnimation67=M
  if not Player._kascDoubleIronBashAnimationWrapped67 then local start=Player.start
    Player.start=function(self,move,side,...)
      local result=start(self,move,side,...);Player._kascDoubleIronBashAnimation67.position(self,move);return result
    end
    Player._kascDoubleIronBashAnimationWrapped67=true
  end
  if opts.supportLog and opts.supportLog.registerSegment then
    opts.supportLog.registerSegment({segmentId=M.CARD_ID,cardId=M.CARD_ID,schema='kasc.optional-feature-card/v1',
      version='1.0.0',owner=M.OWNER,active=true,dependencyStatus='native-multihit-contact-flinch',
      providerStatus='two-independent-strikes',buildReceiptId='docs/DOUBLE_IRON_BASH_67.md',
      rollbackReceiptId='docs/GEN6_WAVE15_SCOPE_20260909.md'})
  end
  return M
end
