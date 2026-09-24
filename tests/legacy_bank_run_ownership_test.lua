-- Data-only synthetic fixtures: no player saves or private support attachments.
local engine = assert(os.getenv('GEN1RECOMP_DIR'), 'GEN1RECOMP_DIR is required')
package.path = engine .. '/?.lua;' .. engine .. '/?/init.lua;' .. package.path
local S = require('src.core.SaveSerializer')
local create = assert(loadfile('legacy_archive.lua'))()
local checks = 0
local function check(v, why) checks = checks + 1; assert(v, why) end
local function clone(v) return assert(S.decode(S.encode(v))) end
local rules = {version=1,preset='standard',seed=42,
 randomizer={enabled=false,wild=true,trainers=true,starters=true,gifts=true,
 static=true,items=false,legendary=false,balanced=true,consistent=true},
 nuzlocke={mode='off',dupes=true,blackout='end',shinyOdds=4096}}
local function fixture(edition)
 local files, writes, fail = {}, 0, false
 local fs={getInfo=function(p)return files[p] and {type='file'}end,
 read=function(p)return files[p]end,write=function(p,b)
  if fail then return false,'simulated write failure' end
  files[p]=b;writes=writes+1;return true
 end,remove=function(p)files[p]=nil;return true end,createDirectory=function()return true end}
 local A=create{fs=fs,serializer=S,edition=edition,modId='kanto_ascendant',directory='test/bank'}
 local old=edition..':7:2'
 local source={version=edition,player={id=7,name='TEST'},meta={playthroughId='synthetic-source'},
 party={},boxes={{}},inventory={},pcItems={},flags={},modData={kanto_ascendant={
 legacy_journey={version=9,cycle=2,runId=old,partnerChosen=true,bankPolicy='open',pact='legacy',pendingRunRules=clone(rules),runRulesLocked=true}}}}
 local rows={}
 for i=1,310 do
  local mon={species='PIKACHU',level=10,exp=1000,moves={{id='THUNDERSHOCK',pp=30}},
   ot='TEST',otId=7,__kaLegacyId=edition..':7:1:MON:'..i}
  rows[i]={id=mon.__kaLegacyId,mon=clone(mon),depositedBy=old,bankSlot=i}
  if i<=212 then
   rows[i].lease=old
   if i<=6 then source.party[#source.party+1]=mon
   else local n=math.ceil((i-6)/20);source.boxes[n]=source.boxes[n]or{};table.insert(source.boxes[n],mon)end
  end
 end
 assert(A.write{version=9,cycle=2,bank=rows,current={runId=old,cycle=2,status='active',
  bankPolicy='open',pact='legacy',partnerChosen=true,runRules=clone(rules)},locker={items={},money=0}})
 local current,committed=A.beginJourney(source,{bankPolicy='open',pact='legacy',itemPolicy='safe',runRules=rules})
 assert(current,committed)
 local fresh={version=edition,player={id=8,name='NEW'},party={},boxes={{}},inventory={},pcItems={},flags={},modData={}}
 return {A=A,source=source,fresh=fresh,old=old,current=current.runId,
  committed=clone(committed),files=files,path='test/bank/'..edition..'.lua',
  writes=function()return writes end,fail=function(v)fail=v end}
end
local function activate(f, corrupt)
 local a=clone(f.committed)
 if corrupt then for i=1,212 do a.bank[i].lease=f.old end end
 assert(f.A.write(a));assert(f.A.seedNewSave(f.fresh));assert(f.A.importHandoff(f.fresh))
 assert(f.A.markRunStarted(f.fresh));assert(f.A.finishHandoff(f.fresh))
 f.fresh.modData.kanto_ascendant.legacy_journey.partnerChosen=true
 -- Simulate the 98 unaffected records already withdrawn in the new run.
 a=assert(f.A.load())
 for i=213,310 do
  a.bank[i].lease=f.current
  local box=math.ceil((i-212)/20);f.fresh.boxes[box]=f.fresh.boxes[box]or{}
  table.insert(f.fresh.boxes[box],clone(a.bank[i].mon))
 end
 assert(f.A.write(a))
end
for _,edition in ipairs{'red','blue','yellow'} do
 local f=fixture(edition);local A=f.A
 check(A.lineageStatus(f.source),'committed source remains valid for retry')
 local before=f.files[f.path];local writes=f.writes()
 check(A.reconcileLeases(f.source),'pending source reconciliation is a successful no-op')
 check(f.files[f.path]==before and f.writes()==writes,'pending source reload must not re-lease archived Pokemon')
 local state=assert(A.beginJourney(f.source));check(state.runId==f.current,'retry keeps the committed journey')
 -- All old-run bank operations must be rejected without writes or mon changes.
 local mon=clone(f.source.party[1]);local encoded=S.encode(mon)
 check(not A.bankAccess(f.source),'source run cannot access destination bank')
 local rows,err=A.availableMons(f.source);check(#rows==0 and err,'source enumeration blocked')
 check(not A.leaseMon(f.source,f.committed.bank[213].id),'source withdrawal blocked')
 check(not A.stageDeposit(f.source,mon),'source deposit blocked')
 check(S.encode(mon)==encoded,'rejected deposit preserves caller mon')
 check(not A.reorderAvailableMon(f.source,f.committed.bank[213].id,1),'source reorder blocked')
 check(not A.releaseLease(f.source,f.committed.bank[1].id),'source lease release blocked')
 check(not A.completeDeposit(f.source,f.committed.bank[1].id),'source deposit completion blocked')
 check(f.files[f.path]==before and f.writes()==writes,'source actions preserve pending archive bytes')
 activate(f,true)
 local broken=assert(A.load());local oldMon=S.encode(broken.bank[1].mon)
 local rows,err=A.availableMons(f.fresh);check(not err and #rows==212,'recover exactly 212 proven previous-run leases')
 local repaired=assert(A.load());check(#repaired.bank==310,'recovery preserves row count')
 check(S.encode(repaired.bank[1].mon)==oldMon,'recovery preserves Pokemon payload')
 for i=1,310 do
  check(repaired.bank[i].lease==(i>212 and f.current or nil),'correct individual ownership')
  check(repaired.bank[i].bankSlot==i,'recovery preserves box layout')
 end
 before=f.files[f.path];writes=f.writes();assert(A.availableMons(f.fresh))
 check(f.files[f.path]==before and f.writes()==writes,'repeat load is idempotent')
 check(not A.reconcileLeases(f.source),'old source cannot reconcile active destination')
 check(f.files[f.path]==before,'old source cannot re-break repaired archive')
 -- A live identity always stays checked out, including when an old lease is repaired.
 broken=clone(repaired);broken.bank[1].lease=f.old
 table.insert(f.fresh.party,clone(broken.bank[1].mon));assert(A.write(broken))
 rows=assert(A.availableMons(f.fresh));check(#rows==211,'live recovered identity is never duplicated')
 check(assert(A.load()).bank[1].lease==f.current,'live identity assigned current run')
 -- Day-Care and sparse Day-Care Plus parents are live save ownership too.
 local daycare=fixture(edition);activate(daycare,true)
 local a=assert(daycare.A.load())
 daycare.fresh.daycare={mon=clone(a.bank[1].mon)}
 daycare.fresh.modData.kanto_ascendant.daycare_plus={parents={
  [2]={mon=clone(a.bank[2].mon)},[4]=clone(a.bank[3].mon)},
  reservedEggs={[3]=clone(a.bank[4].mon)}}
 rows=assert(daycare.A.availableMons(daycare.fresh));check(#rows==208,'Day-Care identities are never made available')
 a=assert(daycare.A.load());for i=1,4 do check(a.bank[i].lease==daycare.current,'Day-Care remains current-owned')end
 -- Withdrawal is one durable transaction, and failed selection must not persist repair.
 local g=fixture(edition);activate(g,true);before=g.files[g.path]
 check(not g.A.leaseMons(g.fresh,{'missing'}),'invalid batch rejected')
 check(g.files[g.path]==before,'invalid batch does not commit recovery')
 local selection={};for i=1,212 do selection[i]=g.committed.bank[i].id end
 local delivered=assert(g.A.leaseMons(g.fresh,selection));check(#delivered==212,'batch path also recovers proven leases')
 for i,m in ipairs(delivered)do local box=5+math.ceil(i/20);g.fresh.boxes[box]=g.fresh.boxes[box]or{};table.insert(g.fresh.boxes[box],m)end
 check(#assert(g.A.availableMons(g.fresh))==0,'withdrawn recovered mons never offered twice')
 -- Provenance must be complete: do not guess about unrelated or unverifiable leases.
 for _,kind in ipairs{'receipt','applied','rollback','source','cycle','depositedBy','missingId','foreign'}do
  local h=fixture(edition);activate(h,true);local a=assert(h.A.load())
  if kind=='receipt' then a.lastTransaction=nil
  elseif kind=='applied' then a.appliedTransactions[h.current]=nil
  elseif kind=='rollback' then a.lastRollback=nil
  elseif kind=='source' then a.lastTransaction.source.runId='foreign'
  elseif kind=='cycle' then a.lastTransaction.targetCycle=99
  elseif kind=='depositedBy' then for i=1,212 do a.bank[i].depositedBy='foreign'end
  elseif kind=='missingId' then a.lastRollback.save.party={};a.lastRollback.save.boxes={}
  elseif kind=='foreign' then for i=1,212 do a.bank[i].lease='foreign'end end
  assert(h.A.write(a));before=h.files[h.path];writes=h.writes()
  rows=assert(h.A.availableMons(h.fresh))
  check(#rows==0,'unproven leases remain untouched: '..kind)
  check(h.files[h.path]==before and h.writes()==writes,'no speculative repair write: '..kind)
 end
 local h=fixture(edition);activate(h,true);before=h.files[h.path];h.fail(true)
 rows,err=h.A.availableMons(h.fresh);check(#rows==0 and err,'repair write failure blocks withdrawal')
 check(h.files[h.path]==before,'failed repair preserves durable source')
 h.fail(false);check(#assert(h.A.availableMons(h.fresh))==212,'repair retries successfully after write failure')
end
print('PASS legacy bank run ownership: '..checks..' assertions')
