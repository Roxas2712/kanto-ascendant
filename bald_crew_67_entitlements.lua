-- Existing Trainer Card collection and title hall remain the only UI owners.
return function(mod,opts)
 local S,C=assert(opts.state),assert(opts.cards)
 local M={cardId='bald_crew_champion',titleId='bald_crew_secret_boss'}
 local function copy(v)
  if type(v)~='table'then return v end
  local r={};for k,x in pairs(v)do r[k]=copy(x)end;return r
 end
 local function tr(en,de)return opts.i18n and opts.i18n.text(en,de)or en end
 function M.plan(game,contract,receipt)
  if contract.card and(contract.card~=M.cardId or not C.byId(M.cardId))then return nil,'card_unregistered'end
  if contract.title and contract.title~=M.titleId then return nil,'title_unregistered'end
  local prior=copy(mod.save:get(C.saveKey))
  return function()
   if contract.card then
    local ok,why=C.award(M.cardId,'bald-crew:'..contract.id,game)
    if not ok then return false,why end
    receipt.card=M.cardId
   end
   if contract.title then receipt.title=M.titleId end
   return true
  end,function()mod.save:set(C.saveKey,prior)end
 end
 function M.titleUnlocked(id)
  local s=S.status();local r=s and s.rewards and s.rewards.receipt
  return id==M.titleId and s and s.phase=='complete'and type(r)=='table'
   and r.schema=='kasc.crew-reward/v1'and r.title==M.titleId or false
 end
 function M.titleName(id)if id==M.titleId then return tr('BALD BUSTER','GLATZENBEZWINGER')end end
 function M.titleHelp(id)
  if id==M.titleId then return tr('Earned by completing the entire Mt. Moon Crew trial, including its secret final boss.',
   'Für den vollständigen Sieg über die Mondberg-Crew einschließlich ihres geheimen Finalbosses.')end
 end
 function M.titleRows()
  if not M.titleUnlocked(M.titleId)then return{}end
  return{{value=M.titleId,label=M.titleName(M.titleId)}}
 end
 function M.catalogRows()
  return{{id=M.titleId,value=M.titleId,label=M.titleName(M.titleId),en='BALD BUSTER',de='GLATZENBEZWINGER',
   unlocked=M.titleUnlocked(M.titleId),source='bald_crew'}}
 end
 function M.withProvider(previous)
  previous=previous or{}
  local out=setmetatable({},{__index=previous})
  for _,key in ipairs({'titleName','titleHelp'})do
   local k=key
   out[k]=function(id)return M[k](id)or previous[k]and previous[k](id)end
  end
  out.titleUnlocked=function(id)
   if id==M.titleId then return M.titleUnlocked(id)end
   return previous.titleUnlocked and previous.titleUnlocked(id)or false
  end
  for _,key in ipairs({'titleRows','catalogRows'})do
   local k=key
   out[k]=function(...)
    local rows=copy(previous[k]and previous[k](...)or{})
    for _,row in ipairs(M[k]())do rows[#rows+1]=row end;return rows
   end
  end
  return out
 end
 return M
end
