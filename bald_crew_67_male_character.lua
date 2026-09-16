-- Reuse the Crew animation implementation, not the vanilla Youngster identity.
return function(mod,opts)
 local classes={}
 for _,id in ipairs(opts.data.order)do
  local row=opts.data.opponents[id]
  if row.gender~='female'then classes[row.trainerClass]=row.displayName end
 end
 return opts.makeCharacter(mod,{
  spriteId='SPRITE_KA_BALD_CREW_MALE',classId='KA_BALD_CREW_OMEGA_DIAS',
  classes=classes,rel='assets/characters/bald_crew_male_v1/',
  role='bald-crew-male',controller='_kaBaldCrewMaleController',heterochromia=false,
  clock=opts.clock,
 })
end
