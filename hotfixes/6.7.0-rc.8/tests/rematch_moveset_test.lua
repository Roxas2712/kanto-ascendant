local root=os.getenv('TRAINER_REMATCH_MOD_DIR') or '.'
local factory=assert(loadfile(root..'/rematch_mastery.lua'))()
local moves={}
for _,id in ipairs({'TACKLE','POISON_STING','FUTURE_ATTACK','LATE_ATTACK','UNRELATED_ATTACK'})do moves[id]={id=id,power=40,type='NORMAL',pp=20}end
for _,id in ipairs({'HARDEN','STRING_SHOT','MINIMIZE','REST','RECOVER','SWORDS_DANCE','TRANSFORM'})do moves[id]={id=id,power=0,type='NORMAL',pp=20}end
local pokemon={
 CATERPIE={types={'BUG'},level1Moves={'TACKLE','STRING_SHOT'},learnset={{level=20,move='LATE_ATTACK'}},evolutions={{'LEVEL','METAPOD',7}},tmhm={'UNRELATED_ATTACK'}},
 METAPOD={types={'BUG'},level1Moves={'HARDEN'}},
 WRONG_PARENT={types={'BUG'},level1Moves={'UNRELATED_ATTACK'},evolutions={{'LEVEL','OTHER',5}}},
 TACTICAL={types={'NORMAL'},level1Moves={'TACKLE'},tmhm={'MINIMIZE','REST','RECOVER','SWORDS_DANCE'}},
 SIMPLE={types={'NORMAL'},level1Moves={'TACKLE'}},
 DITTO={types={'NORMAL'},level1Moves={'TRANSFORM'}},
}
local rules={resolve=function()return{activeEpoch=1}end,moveAvailable=function(id)return id~='FUTURE_ATTACK'end,speciesAvailable=function()return true end}
local mastery=factory.create({generationRules=rules})
local game={data={pokemon=pokemon,moves=moves}}
local Stats={calc=function()return {hp=30,attack=10,defense=10,special=10,speed=10}end}
local function run(species,ids,progress)
 local mon={species=species,level=8,hp=30,stats={hp=30},moves={}}
 for _,id in ipairs(ids)do mon.moves[#mon.moves+1]={id=id,pp=20}end
 local b={enemyParty={mon}};b.enemy={mon=mon}
 local report=mastery.apply(game,b,{progress=progress or 0,Stats=Stats})
 local known={};for _,m in ipairs(mon.moves)do assert(not known[m.id]);known[m.id]=true end
 assert(#mon.moves<=4 and b.enemy.curMoves==mon.moves)
 return known,report
end
local known,report=run('METAPOD',{'HARDEN'})
assert(known.TACKLE and known.HARDEN and known.STRING_SHOT,'Metapod cannot attack at first rematch')
assert(not known.LATE_ATTACK and not known.UNRELATED_ATTACK,'invalid inherited move')
assert(report.party[1].sources.TACKLE=='pre-evolution' and report.party[1].movesChanged)
known=run('TACTICAL',{'MINIMIZE','REST','RECOVER','SWORDS_DANCE'},5)
assert(known.TACKLE,'four tactical moves displaced every attack')
known=run('SIMPLE',{'TACKLE','FUTURE_ATTACK'})
assert(known.TACKLE and not known.FUTURE_ATTACK,'unchanged legal subset retained a forbidden move')
known,report=run('SIMPLE',{'TACKLE'})
assert(known.TACKLE and not report.party[1].movesChanged,'unchanged set reported changed')
known=run('DITTO',{'TRANSFORM'})
assert(known.TRANSFORM and not known.TACKLE,'fabricated attack for a species without one')
print('REMATCH_MOVESET_REGRESSION_PASS')
