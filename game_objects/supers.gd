extends Node

func run(game: Game, player: Player):
	var name = player.character.name
	
	reimu(game, player)

func reimu(game: Game, player: Player):
	var fx = game.get_fx_manager()
	var ball = player.kick(50)
	if ball:
		ball.create_fx.emit(fx.crit_burst, (ball.global_position + player.global_position) / 2)
		await get_tree().create_timer(0.05).timeout
		ball.create_fx.emit(fx.crit_burst, ball.global_position)
		await get_tree().create_timer(0.05).timeout
		ball.create_fx.emit(fx.crit_burst, ball.global_position)
		await get_tree().create_timer(0.05).timeout
		ball.create_fx.emit(fx.crit_burst, ball.global_position)
