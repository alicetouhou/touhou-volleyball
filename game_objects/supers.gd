extends Node

func run(game: Game, player: Player):
	var name = player.character.name
	
	if name == "Reimu":
		reimu(game, player)
	if name == "Alice":
		alice(game, player)
	if name == "Yuyuko":
		yuyuko(game, player)

func reimu(game: Game, player: Player):
	pass

func alice(game: Game, player: Player):
	pass

func yuyuko(game: Game, player: Player):
	pass
