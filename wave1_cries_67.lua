-- Missing canonical cries only. Existing/native/custom owners stay intact.
return function(mod,opts)
  local species=assert(opts.species)
  local data=assert(opts.data)
  assert(data.schema=='kasc.wave1-cries/v1')
  local C={CARD_ID='KASC-WAVE1-CRIES',registered={},preserved={},pending={}}
  for key,row in pairs(data.entries)do
    local expected=tonumber(key:match('^dex:(%d+)$') or key:match('^form:(%d+)$'))
    assert(expected and row.sourceId==expected,'cry source identity mismatch '..key)
    local id=species.byKey[key]
    local def=id and mod.content.pokemon:get(id)
    if not def then
      C.pending[#C.pending+1]={key=key,reason='species_not_registered'}
    elseif mod.content.cries:get(id) then
      C.preserved[#C.preserved+1]=id
    else
      assert(row.file:match('^assets/wave1_cries_67/') and not row.file:find('..',1,true))
      assert(mod:read(row.file),'missing cry file '..key)
      mod.content.cries:register(id,{file=mod.path..'/'..row.file})
      mod.content.pokemon:patch(id,{cry=id})
      C.registered[#C.registered+1]=id
    end
  end
  return C
end
