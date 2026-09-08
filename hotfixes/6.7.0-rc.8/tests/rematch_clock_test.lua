local root=assert(os.getenv('TRAINER_REMATCH_MOD_DIR'))
local C=assert(loadfile(root..'/rematch_clock.lua'))()
local t={readyAt=5586,lastRest=1000,nextTrainingAt=6586}
local b={step_clock=1200,trainers={A=t}}
assert(t.readyAt-b.step_clock==4386,'baseline missing clock mismatch')
assert(C.recover(b) and b.trainer_step_clock==4586)
assert(t.readyAt-b.trainer_step_clock==1000 and t.readyAt==5586 and t.nextTrainingAt==6586)
assert(b.step_clock==1200 and not C.recover(b),'reload changed timeline')
-- A real saved accelerated clock is authoritative, including completed waits.
for _,clock in ipairs({5000,5586,10000})do
 local exact={step_clock=1200,trainer_step_clock=clock,trainers={A=t}}
 assert(not C.recover(exact) and exact.trainer_step_clock==clock)
end
local old={step_clock=5000,trainers={A={readyAt=5200,lastRest=600}}}
assert(C.recover(old) and old.trainer_step_clock==5000)
local fresh={step_clock=0,trainers={}};assert(C.recover(fresh) and fresh.trainer_step_clock==0)
local malformed={step_clock=100,trainers={a='broken',b={readyAt=math.huge,lastRest=600}}}
assert(C.recover(malformed) and malformed.trainer_step_clock==100)
print('CLOCK PASS: missing clock 4386 -> original 1000 rest; valid clocks/deadlines/real steps unchanged; reload idempotent')
