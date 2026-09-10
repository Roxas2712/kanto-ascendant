package.path="./?.lua;./?/init.lua;"..package.path

local function registry(seed)
  local rows=seed or {}
  return {get=function(_,id)return rows[id]end,
    register=function(_,id,def)assert(not rows[id],"duplicate "..id);rows[id]=def end,
    rows=rows}
end
local effects=registry()
for _,id in ipairs({"NO_ADDITIONAL_EFFECT","PARALYZE_SIDE_EFFECT1",
    "PARALYZE_SIDE_EFFECT2","FREEZE_SIDE_EFFECT1","BURN_SIDE_EFFECT1",
    "BURN_SIDE_EFFECT2","POISON_SIDE_EFFECT1","POISON_SIDE_EFFECT2",
    "CONFUSION_SIDE_EFFECT","PARALYZE_EFFECT","SLEEP_EFFECT",
    "POISON_EFFECT","CONFUSION_EFFECT","HEAL_EFFECT","ATTACK_TWICE_EFFECT",
    "TWO_TO_FIVE_ATTACKS_EFFECT","OHKO_EFFECT","DRAIN_HP_EFFECT",
    "RECOIL_EFFECT","FLINCH_SIDE_EFFECT1","FLINCH_SIDE_EFFECT2",
    "FLY_EFFECT"}) do
  effects.rows[id]={kind="full"}
end
local aliases={"TACKLE","KARATE_CHOP","GUST","ACID","EARTHQUAKE",
  "ROCK_THROW","PIN_MISSILE","NIGHT_SHADE","HARDEN","EMBER",
  "WATER_GUN","VINE_WHIP","THUNDER_SHOCK","CONFUSION","ICE_BEAM",
  "DRAGON_RAGE","BITE","SWIFT","FLY","DIG","RECOVER",
  "SWORDS_DANCE","AGILITY","AMNESIA","DOUBLE_TEAM"}
local seededMoves={FLAME_WHEEL={id="FLAME_WHEEL"}}
local seededAnims={}
for _,id in ipairs(aliases) do
  seededMoves[id]={id=id,anim={sound=id.."_SOUND"}}
  seededAnims[id]={seq={{subanim=1,duration=1}}}
end
local moves=registry(seededMoves)
local animations=registry(seededAnims)
local hooks={}
local mod={content={moves=moves,move_effects=effects,battle_anims=animations},
  hooks={wrap=function(_,name,callback)
    assert(not hooks[name],"duplicate hook "..name)
    hooks[name]=callback
  end}}
local card=require("generation_move_catalog_67")(mod,{
  data=require("generation_move_catalog_67_data"),
  i18n={text=function(en)return en end},
})
local checks=0
local function ok(v,m)checks=checks+1;assert(v,m)end
local function eq(a,b,m)ok(a==b,(m or "values")..": "..tostring(a).." ~= "..tostring(b))end

do
  local user={mon={hp=30},stages={accuracy=-1}}
  local target={mon={hp=30},stages={evasion=2},curTypes={"GHOST","POISON"}}
  effects.rows.KA_GEN_MOVE_FORESIGHT.run({user=user,target=target,
    displayName=function()return "TEST"end})
  ok(target._kascForesightIdentified,"Foresight marks only the current battler")
  local ctx={user=user,target=target,move={type="NORMAL"}}
  local seen
  hooks["battle.accuracy"](function(adjusted)seen=adjusted end,ctx)
  eq(seen.user.stages.accuracy,0,"Foresight ignores disadvantageous accuracy stages")
  eq(seen.target.stages.evasion,0,"Foresight ignores target evasion stages")
  eq(user.stages.accuracy,-1,"accuracy hook preserves actual user stages")
  eq(target.stages.evasion,2,"accuracy hook preserves actual target stages")
  hooks["battle.damage"](function(adjusted)seen=adjusted end,ctx)
  eq(#seen.target.curTypes,1,"Foresight removes Ghost immunity for this calculation")
  eq(seen.target.curTypes[1],"POISON","other defensive types remain")
  eq(target.curTypes[1],"GHOST","saved/current typing is not rewritten")
  ctx.move.type="PSYCHIC"
  hooks["battle.damage"](function(adjusted)seen=adjusted end,ctx)
  eq(seen,ctx,"unrelated move types use the unchanged damage context")
end

local status=card.status()
eq(status.total,456,"all Gen-II--VI identities are owned")
eq(status.registered+status.preserved,456,"every identity is registered or preserved")
eq(status.preserved,1,"a specific earlier move implementation wins")
eq(card.origin("SKETCH"),2,"first catalog move is Gen II")
eq(card.origin("AERIAL_ACE"),3,"Aerial Ace is Gen III")
eq(card.origin("U_TURN"),4,"U-turn is Gen IV")
eq(card.origin("VOLT_SWITCH"),5,"Volt Switch is Gen V")
eq(card.origin("DAZZLING_GLEAM"),6,"Dazzling Gleam is Gen VI")
ok(not card.available("DAZZLING_GLEAM",5) and card.available("DAZZLING_GLEAM",6),
  "epoch filtering is exact")
eq(moves.rows.DAZZLING_GLEAM.type,"FAIRY","Fairy move type is retained")
eq(moves.rows.DAZZLING_GLEAM.power,80,"canonical power is retained")
eq(moves.rows.QUICK_GUARD.power,0,"status moves remain status moves")
eq(moves.rows.RETURN.power,1,"variable-power attacks stay in the damage pipeline")
eq(moves.rows.BOUNCE.effect,"FLY_EFFECT","Bounce uses two-turn flight")
eq(moves.rows.BOUNCE.anim.sound,"FLY_SOUND","Bounce starts at the user")
ok(animations.rows.BOUNCE~=nil,"Bounce owns a playable Fly animation alias")
eq(moves.rows.DIVE.effect,"FLY_EFFECT","Dive uses two-turn semi-invulnerability")
eq(moves.rows.DIVE.anim.sound,"DIG_SOUND","Dive starts at the user")
eq(moves.rows.ROOST.effect,"HEAL_EFFECT","Roost heals its user")
eq(moves.rows.ROOST.anim.sound,"RECOVER_SOUND","healing animates on the user")
ok(animations.rows.ROOST~=nil,"healing owns a playable Recover animation alias")
eq(status.animations,status.registered,"every registered move owns an animation")
ok(status.unsupportedStatus>0,
  "unique unsupported status mechanics are explicitly audited")
for _,id in ipairs(card.unsupportedStatus) do
  local move=moves.rows[id]
  ok(move and move.effect:find("KA_GEN_MOVE_UNSUPPORTED_",1,true)==1,
    id.." must fail closed instead of becoming a silent no-op")
end

local user,target={},{}
for _,id in ipairs({'CLOSE_COMBAT','SUPERPOWER','LEAF_STORM','OVERHEAT',
    'ANCIENT_POWER','METAL_CLAW','CRUNCH','PLAY_NICE','SWAGGER','FLATTER'})do
  local row=card.byId[id]
  local damaging=row.category~='status'
  local selfTarget=damaging and row.metaCategory==7 or not damaging and row.target==7
  local effect=effects:get(moves:get(id).effect)
  ok(effect and effect.run,'stat effect missing '..id)
  local calls=0
  effect.run({user=user,target=target,rng=function()return 1 end,
    changeStage=function(who,stat,delta,fromEnemy)
      calls=calls+1
      eq(who,selfTarget and user or target,id..' changes correct battler')
      eq(fromEnemy,not selfTarget and delta<0,id..' self-debuff must not trigger Mist gate')
      return {}
    end})
  ok(calls>0,id..' did not execute stat changes')
end
ok(effects:get(moves:get('SWAGGER').effect).accuracyChecked,
  'targeted positive stat move must still check accuracy')

print(("GENERATION MOVE CATALOG 6.7 PASS: %d assertions"):format(checks))
