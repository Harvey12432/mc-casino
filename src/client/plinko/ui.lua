local gameUi=require("client.shared.game_ui")
return {run=function(client) gameUi.run(client,{
  game="plinko",title="CASINO PLINKO",startText="DROP",
  rules="Edge 10x | near-edge 3x | centre 0.3x",
  animate=gameUi.plinkoAnimation,
}) end}
