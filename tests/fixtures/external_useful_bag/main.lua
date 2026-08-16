return function(mod)
  mod.content.screens:register("BagMenu", {
    externalUsefulBagTestDouble = true,
    new = function()
      return { externalUsefulBagTestDouble = true }
    end,
  })
end
