local gameUi=require("client.shared.game_ui")
return {run=function(client) gameUi.run(client,{
  game="craps",title="PASS-LINE CRAPS",
  rules="Come-out: 7/11 win, 2/3/12 lose | point pays 2x",
  startText="COME OUT",
  animate=gameUi.diceAnimation,
  actionButtons={
    {text="ROLL DICE",action="roll",width=14,colour=colors.orange,
      foreground=colors.black},
  },
}) end}
