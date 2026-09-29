-- Internal owner-supplied, cooperative preparation. No save adoption or UI.
local M={}
function M.new(clock)
 local self={jobs={},ids={},cursor=1,started=false,clock=clock}
 function self:add(id,step,required)
  if self.started or self.ids[id] or type(step)~='function'then return false end
  self.ids[id]=true;self.jobs[#self.jobs+1]={id=id,step=step,state='pending',required=required==true};return true
 end
 function self:update(game)
  self.started=true
  local job=self.jobs[self.cursor];if not job then return end
  local now=self.clock();self.since=self.since or now;job.since=job.since or now
  if not job.required and now-job.since>=30 then
   job.state='deferred';job.reason='startup-budget-exhausted'
  else
   local ok,ready=pcall(job.step,game)
   if not ok then job.state='failed';job.reason=tostring(ready)
   elseif ready==true then job.state='ready' end
  end
  if job.state~='pending'then job.step=nil;self.cursor=self.cursor+1 end
 end
 function self:ready()return self.cursor>#self.jobs end
 function self:status()
  local jobs={};for _,job in ipairs(self.jobs)do jobs[#jobs+1]={id=job.id,state=job.state,reason=job.reason}end
  return {ready=self:ready(),jobs=jobs}
 end
 return self
end
return M
