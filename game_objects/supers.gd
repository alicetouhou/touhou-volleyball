extends Node

func run(game: Game, player: Player):
	var name = player.character.name
	
	reimu(game, player)

func reimu(game: Game, player: Player):
	var ball = game.get_ball()
	
	ball.apply_central_impulse(ball.linear_velocity.normalized() * 100)
	
