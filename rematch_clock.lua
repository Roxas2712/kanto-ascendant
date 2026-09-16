-- A trainer deadline and its rolled rest duration prove the earliest possible
-- clock value. Older saves can lack the separately accelerated trainer clock.
-- Recover only that lower bound; never reroll or rewrite any trainer deadline.
local C = {}
local function integer(value)
  value=tonumber(value)
  if not value or value~=value or value==math.huge or value==-math.huge then return nil end
  return math.max(0,math.floor(value))
end
function C.recover(bucket)
  if type(bucket)~='table' then return false end
  local real=integer(bucket.step_clock) or 0
  local saved=integer(bucket.trainer_step_clock)
  local clock=math.max(real,saved or 0)
  if saved==nil then
    for _,trainer in pairs(type(bucket.trainers)=='table' and bucket.trainers or {}) do
      if type(trainer)=='table' then
        local deadline,duration=integer(trainer.readyAt),integer(trainer.lastRest)
        if deadline and duration and duration>0 then
          clock=math.max(clock,deadline-duration)
        end
      end
    end
  end
  if saved==clock then return false end
  bucket.trainer_step_clock=clock
  return true
end
return C
