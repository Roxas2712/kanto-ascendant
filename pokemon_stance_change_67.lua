-- Gen VI changes stance before BeforeMove interruptions. Gen VII changes
-- only when the move proceeds, including a called move such as Sleep Talk.
return function(mod,opts)
  local B=require('src.battle.BattleState');local FX=require('src.battle.EffectRegistry')
  local M={CARD_ID='KASC-67-STANCE-CHANGE',OWNER='kasc.stance-change/v1'}
  local forms,identity=opts.forms,opts.identity
  local base,blade='dex:681','form:10026'
  local species=assert(opts.species.byKey[base])
  local frames=setmetatable({},{__mode='k'})
  local function pack(...)return{n=select('#',...),...}end
  assert(forms.registerExternalPair(base,blade,'STANCE_CHANGE',6))
  function M.epoch(b)
    local r=b and b.data and b.data.move_effects and b.data.move_effects.HEAL_EFFECT
    local gen=getmetatable(b)==B and not b.result and r and r.kascStanceChange67==M.OWNER and opts.status.epoch(b)
    return gen and gen>=6 and gen<=7 and gen or nil
  end
  local function eligible(b,w)
    return M.epoch(b)and w and w.mon and (w==b.player or w==b.enemy)
      and w.mon.species==species and w.mon.hp>0 and not identity.transformed(w)
      and not w._ascMegaProfile and not w.mon._ascMegaForm and not w.mon.ascMegaForm
      and opts.abilities.activeAbility(b,w)=='STANCE_CHANGE'
  end
  function M.select(b,w,move)
    if not eligible(b,w)or not move then return false end
    if move.id=='KINGS_SHIELD'then return forms.change(b,w,base,M.epoch(b),false)end
    if move.category=='physical'or move.category=='special'or move.struggle then
      return forms.change(b,w,blade,M.epoch(b),false)
    end
    return false
  end
  function M.entry(ev)
    local b=ev and ev.battle;if not b then return end
    local function start(w)
      if eligible(b,w)and not forms.currentKey(b,w)then forms.change(b,w,base,M.epoch(b),true)end
    end
    if ev.battler then start(ev.battler)else start(b.player);start(b.enemy)end
  end
  function M.interrupt(original,b,w,t,id,...)
    if M.epoch(b)==6 and id then M.select(b,w,b.data.moves[id])end
    return original(b,w,t,id,...)
  end
  function M.context(original,b,w,t,move,slot,...)
    local f=frames[b]
    if M.epoch(b)==7 and f and f.w==w and f.slot==slot then M.select(b,w,move)end
    return original(b,w,t,move,slot,...)
  end
  function M.perform(original,b,w,t,slot,...)
    local prior=frames[b];frames[b]={w=w,slot=slot}
    local out=pack(pcall(original,b,w,t,slot,...));frames[b]=prior
    if not out[1]then error(out[2],0)end
    return unpack(out,2,out.n)
  end
  function M.validateCheckpoint(b)
    return frames[b]==nil,'stance_move_unsettled'
  end
  B._kascStanceChange67=M;FX._kascStanceChange67=M
  if not B._kascStanceWrapped67 then
    local interrupt,perform=B.statusInterrupt,B.performMove
    B.statusInterrupt=function(...)return B._kascStanceChange67.interrupt(interrupt,...)end
    B.performMove=function(...)return B._kascStanceChange67.perform(perform,...)end
    local make=FX.makeCtx
    FX.makeCtx=function(...)return FX._kascStanceChange67.context(make,...)end
    B._kascStanceWrapped67=true
  end
  -- The shared form owner clears outgoing identities first; entry also runs
  -- before Imposter so a copy sees the current native shield stats and art.
  mod.events:on('battle.started',M.entry,-10041)
  mod.events:on('battle.battler_switched',M.entry,-10041)
  mod.content.move_effects:patch('HEAL_EFFECT',{kascStanceChange67=M.OWNER})
  if opts.supportLog and opts.supportLog.registerSegment then
    opts.supportLog.registerSegment({segmentId=M.CARD_ID,cardId=M.CARD_ID,
      schema='kasc.optional-feature-card/v1',version='1.0.0',owner=M.OWNER,active=true,
      dependencyStatus='native-status-move-and-protection',providerStatus='gen6-7-shield-blade',
      buildReceiptId='docs/STANCE_CHANGE_67.md',rollbackReceiptId='docs/STANCE_CHANGE_67.md'})
  end
  return M
end
