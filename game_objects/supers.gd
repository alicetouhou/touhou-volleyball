extends Node

func reimu_super(game: Game):
	var ball = game.get_ball()
	
	ball.apply_central_impulse(ball.linear_velocity.normalized() * 100)
	
