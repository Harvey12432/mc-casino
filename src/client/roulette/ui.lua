local gameUi=require("client.shared.game_ui")
return {run=function(client) gameUi.run(client,{
  game="roulette",title="CASINO ROULETTE",optionHint="Exact number 0-36",
  rules="Straight 36x | outside bets 2x | zero loses",
  choices={
    {text="RED",value="red",colour=colors.red},
    {text="BLACK",value="black"},
    {text="ODD",value="odd"},{text="EVEN",value="even"},
    {text="1-18",value="low"},{text="19-36",value="high"},
  },
  animate=gameUi.rouletteAnimation,
  options=function(value)
    local number=tonumber(value); return {choice=number or value:lower()}
  end,
}) end}
