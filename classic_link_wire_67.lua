-- Add only KASC's bounded rules receipt to the native Hello sanitizer.
-- Transport, JSON, all ordinary fields and non-Hello schemas stay native.
return function()
  local A={OWNER='kasc.private-link-wire/v1'}
  local function bounded(value,depth,budget,seen)
    budget.n=budget.n+1
    if budget.n>512 or depth>6 then return nil,false end
    local kind=type(value)
    if kind=='boolean' then return value,true end
    if kind=='number' then
      return value,value==value and value~=math.huge and value~=-math.huge
    end
    if kind=='string' then return value,#value<=256 end
    if kind~='table' or seen[value] then return nil,false end
    seen[value]=true
    local out,count={},0
    for key,child in pairs(value)do
      count=count+1
      if count>64 or type(key)~='string' or #key>64 then return nil,false end
      local v,ok=bounded(child,depth+1,budget,seen)
      if not ok then return nil,false end
      out[key]=v
    end
    seen[value]=nil
    return out,true
  end
  function A.install(wire,receipts)
    if not (wire and type(wire.sanitize)=='function' and receipts
        and type(receipts.compatibleLink)=='function') then return false end
    if wire._kascRulesReceiptOwner==A.OWNER then return true end
    if wire._kascRulesReceiptOwner then return false end
    local original=wire.sanitize
    wire.sanitize=function(message,...)
      local result=original(message,...)
      if type(result)=='table' and result.type=='hello' and type(message)=='table'
          and message.kascGenerationRules~=nil then
        local receipt,ok=bounded(message.kascGenerationRules,0,{n=0},{})
        if ok and receipts.compatibleLink(receipt,receipt) then
          result.kascGenerationRules=receipt
        end
      end
      return result
    end
    wire._kascRulesReceiptOwner=A.OWNER
    return true
  end
  return A
end
