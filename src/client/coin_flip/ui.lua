local gameUi=require("client.shared.game_ui")
return {run=function(client) gameUi.run(client,{
  game="coin_flip",title="COIN FLIP",
  rules="Call heads or tails | correct call pays 2x",
  choices={
    {text="HEADS",value="heads",width=10,colour=colors.orange,foreground=colors.black},
    {text="TAILS",value="tails",width=10,colour=colors.lightGray,foreground=colors.black},
  },
  animate=gameUi.coinAnimation,
  options=gameUi.stringOption("choice"),startText="FLIP",
}) end}
