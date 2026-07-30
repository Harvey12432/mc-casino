local gameUi=require("client.shared.game_ui")
return {run=function(client) gameUi.run(client,{
  game="horse_racing",title="HORSE RACING",
  rules="Pick the winning horse | winner pays 5x",
  choices={
    {text="#1",value=1},{text="#2",value=2},{text="#3",value=3},
    {text="#4",value=4},{text="#5",value=5},
  },
  animate=gameUi.horseAnimation,
  options=gameUi.numberOption("horse"),startText="RACE",
}) end}
