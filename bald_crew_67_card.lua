-- Composition root for the one-time Mt. Moon event. Each adapter keeps its
-- existing authority; pending release data never closes the vanilla cave.
return function(mod,opts)
 opts=opts or{}
 local load=assert(opts.load)
 local D=opts.data or load('bald_crew_67_data.lua')
 local M={CARD_ID='KASC-67-BALD-CREW',data=D,registered=false}
 local function ex()return mod.exports end
 local function contract()return opts.contract and opts.contract()or D.rewardContract end
 M.activation=load('bald_crew_67_activation.lua')(mod,{data=D,changed=function(game)
 local s=M.state.status()
  if s and M.invitation then M.invitation.poll(game)end
 end})
 function M.readiness()
  local missing={}
  if not D.ready then missing[#missing+1]='rosters_unapproved'end
  for _,id in ipairs(D.order)do
   local row=D.opponents[id]
   if not(row and row.ready and type(row.team)=='table'and #row.team==6)then
    missing[#missing+1]='roster:'..id
   end
  end
  local final=D.opponents.pandy
  if not(final and final.phaseTwo and final.phaseTwo.ready and type(final.phaseTwo.team)=='table'
    and #final.phaseTwo.team==6 and type(final.developerMegaOverride)=='table'
    and final.developerMegaOverride.enemyActivations==12)then missing[#missing+1]='final_reserve_unapproved'end
  local c=contract()
  if not(c and c.approved==true and type(c.id)=='string'and c.id~='')then
   missing[#missing+1]='rewards_unapproved'
  end
  if not opts.eligible and not M.activation.approved()then
   missing[#missing+1]='activation_unapproved'
  end
  return #missing==0,missing
 end
 function M.eligible(game)
  if not M.registered or not M.readiness()then return false end
  if opts.eligible then return opts.eligible(game)==true end
  return M.activation.eligible(game)
 end
 M.state=load('bald_crew_67.lua')(mod,{data=D,persist=opts.persist})
 M.content=load('bald_crew_67_content.lua')(mod,{data=D,i18n=opts.i18n})
 M.mega=load('bald_crew_67_mega.lua')(mod,{data=D,mega=assert(ex().megaEvolution),
  backend=ex().backendMegaForms67,battleState=opts.battleState,
  dialogue=load('bald_crew_67_dialogue.lua'),i18n=opts.i18n})
 M.battles=load('bald_crew_67_battles.lua')(mod,{data=D,exports=ex,mega=M.mega})
 M.entitlements=load('bald_crew_67_entitlements.lua')(mod,{state=M.state,
  cards=assert(opts.cards),i18n=opts.i18n})
 M.rewards=load('bald_crew_67_rewards.lua')(mod,{state=M.state,contract=contract,
  exports=ex,entitlements=M.entitlements.plan})
 M.rewardUI=load('bald_crew_67_reward_ui.lua')(mod,{state=M.state,rewards=M.rewards,
  contract=contract,i18n=opts.i18n,show=opts.show})
 M.runtime=load('bald_crew_67_runtime.lua')(mod,{data=D,state=M.state,content=M.content,
  dialogue=load('bald_crew_67_dialogue.lua'),i18n=opts.i18n,show=opts.show,
  eligible=M.eligible,newBattle=M.battles.newBattle,claimReward=M.rewardUI.open,
  invited=function()return M.invitation and M.invitation.seen()end})
 M.invitation=load('bald_crew_67_invitation.lua')(mod,{state=M.state,
  eligible=M.eligible,runtime=M.runtime,dialogue=load('bald_crew_67_dialogue.lua'),
  i18n=opts.i18n,show=opts.show})
 function M.register()
  if M.registered then return true end
  if not mod.content.maps:get(D.instance.host)then return false,'missing_stock_map'end
  local ok,why=M.battles.register();if not ok then return false,why end
  ok,why=M.content.register();if not ok then return false,why end
  M.content.bindRuntime(M.runtime)
  M.registered=true
  if opts.hall then opts.hall.setExtraTitleProvider(M.entitlements.withProvider(opts.titles))end
  if opts.supportLog and opts.supportLog.registerSegment then
   local ready=M.readiness()
   opts.supportLog.registerSegment({segmentId=M.CARD_ID,cardId=M.CARD_ID,version='1.0.0',
    schema='kasc.optional-feature-card/v1',owner='kasc.bald-crew/v1',active=ready,
    dependencyStatus=ready and 'local-reviewed'or'pending-release-data',
    providerStatus=ready and 'runtime-loaded'or'cold-disabled',
    buildReceiptId='bald_crew_67_data.lua',rollbackReceiptId='bald_crew_67_runtime.secureSave'})
  end
  return true
 end
 function M.install(game)
  if not M.registered then return false,'content_unregistered'end
  M.mega.install()
  M.activation.install(game)
  M.invitation.install(game)
  return M.runtime.install(game)
 end
 return M
end
