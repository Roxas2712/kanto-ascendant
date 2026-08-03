-- Crystal's shiny palettes, applied to the player's own imported Gen I art.
-- The source table is data/pokemon/palettes.asm plus each species' shiny.pal
-- from pret/pokecrystal. Crystal stores only the two middle 5-bit colors;
-- white and black are the fixed outer shades. Values below are expanded with
-- the Game Boy convention n << 3 and packed as RRGGBBRRGGBB in National-Dex
-- order. No Pokemon sprite pixels are shipped by this mod.

local STEMS = "bulbasaur,ivysaur,venusaur,charmander,charmeleon,charizard,squirtle,wartortle,blastoise,caterpie,metapod,butterfree,weedle,kakuna,beedrill,pidgey,pidgeotto,pidgeot,rattata,raticate,spearow,fearow,ekans,arbok,pikachu,raichu,sandshrew,sandslash,nidoranf,nidorina,nidoqueen,nidoranm,nidorino,nidoking,clefairy,clefable,vulpix,ninetales,jigglypuff,wigglytuff,zubat,golbat,oddish,gloom,vileplume,paras,parasect,venonat,venomoth,diglett,dugtrio,meowth,persian,psyduck,golduck,mankey,primeape,growlithe,arcanine,poliwag,poliwhirl,poliwrath,abra,kadabra,alakazam,machop,machoke,machamp,bellsprout,weepinbell,victreebel,tentacool,tentacruel,geodude,graveler,golem,ponyta,rapidash,slowpoke,slowbro,magnemite,magneton,farfetchd,doduo,dodrio,seel,dewgong,grimer,muk,shellder,cloyster,gastly,haunter,gengar,onix,drowzee,hypno,krabby,kingler,voltorb,electrode,exeggcute,exeggutor,cubone,marowak,hitmonlee,hitmonchan,lickitung,koffing,weezing,rhyhorn,rhydon,chansey,tangela,kangaskhan,horsea,seadra,goldeen,seaking,staryu,starmie,mr.mime,scyther,jynx,electabuzz,magmar,pinsir,tauros,magikarp,gyarados,lapras,ditto,eevee,vaporeon,jolteon,flareon,porygon,omanyte,omastar,kabuto,kabutops,aerodactyl,snorlax,articuno,zapdos,moltres,dratini,dragonair,dragonite,mewtwo,mew"

local COLORS = "a0e058f85030a0e058f8c04890c858f8b018f8c030f88010f8a878b84868a078a840a87068b84088c8f068b8409098f870a8388080a0d8c030f86088e09868c07000f878b878f800b8d828d038e8a0d82068883888a0684038d8f0e060a09840a89828987028f8a070788810b0b898a08868b8c878d08018f0d000c06808808050c08838a0b868485828909858a050f0f88800a01058a898a0c09810808050584078809020a83008d888e0288808f888f0307850f880f858684090a8f8884078a0b8f8b820c86888f87848b8f868c8409000f868c8409000f8c008b08008d8b0c88888b8f888f848c018f888f848c018d878f0508830e86098387800f8d020409058f8a828688860f8a818407868d89818706808f8a8489080287088f85828b08078f88830a89858206030d89858206030d8f8b060d01090f8e050e048d8a898f85058a0e050683888f098b058a08038b88830808030b8a038a86800c08878988808d040884040e84880d04050f858c0d0408878e0c050a04898e0c050a04898989818a810a87870583040487080583830c8708858486020a0a038a050a8b0e038984898a0b8187060f89898f840986888a0f828a000c08878786838b87060805838c87860983818b89880986860b098a08850d8b058d08800f8a850f890900098a098a03838788090905858a0807060a008e0b800908000f8c008908000a098b0e83828a098a090587080980858505078a048506818c08838a84820a060e05820f88088f02838585048d8400098f800e87860b878a820705838c068d8900050f048c8905068a8a0b0907820a8b048606858a0a0884810e0a0a0884810e0b8c830986048988840c07048b0b0b858784890a87870782088a8286840688088604018f8c0b048e0487080a0c84860b880a0c84860b8b07888785868b0a8a8606088d8c89868980890f000883030808098185818f860c06078f8f858d85020e8e89800f07000a8d890d0b0109080984068f0e848585858f8f858f888980088c000e04800701078f848d8f8c80090a000f870f0c02070b8b848585878f0d870487050c8c000808000c8a040d85028f868f88058f888b0e04860d89898a8607068d8a8f87850c0c8b000787830f08808c048007018d86058c8b89850605858c8e010605878b8c0a070905098a058507850b048b86048a8d8b0584838f898d0f86868b0f89800f82000f85870a80800a898c07058c0a898f8a078f888987098007098a8b078780090c0f83858d0"

local function byte(offset)
  return assert(tonumber(COLORS:sub(offset, offset + 1), 16))
end

return function(ctx)
  local index = 0
  for stem in STEMS:gmatch("[^,]+") do
    index = index + 1
    local offset = (index - 1) * 12 + 1
    local shades = {
      { 248, 248, 248 },
      { byte(offset), byte(offset + 2), byte(offset + 4) },
      { byte(offset + 6), byte(offset + 8), byte(offset + 10) },
      { 0, 0, 0 },
    }
    for _, rel in ipairs({
      "battle/front/" .. stem .. ".png",
      "battle/back/" .. stem .. "b.png",
    }) do
      if ctx.exists(rel) then
        -- Headless Modkit fixtures expose placeholder asset paths without a
        -- LOVE image backend. A failed decode is therefore "not installed",
        -- not a broken gameplay mod.
        local ok, image = pcall(ctx.readImage, rel)
        if ok and image then
          ctx.writeImage(ctx.recolor(image, shades), "shiny/" .. rel)
        end
      end
    end
  end
  assert(index == 151, "expected all 151 Gen I shiny palettes")
end
