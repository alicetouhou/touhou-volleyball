extends Node

func run(game: Game, player: Player):
	var name = player.character.name
	
	if name == "Reimu":
		reimu(game, player)
	if name == "Alice":
		alice(game, player)
	if name == "Yuyuko":
		yuyuko(game, player)
	if name == "Marisa":
		marisa(game, player)

func reimu(game: Game, player: Player):
	if player.super_charge < 1:
		return
	var fx = game.get_fx_manager()
	var ball = player.find_ball()
	if ball:
		player.super_charge -= 1

		var direction = -sign(ball.position.x)
		ball.apply_central_impulse(Vector3(15 * direction, 5, 0))

		ball.create_fx.emit(fx.crit_burst, (ball.global_position + player.global_position) / 2)
		await get_tree().create_timer(0.05).timeout
		ball.create_fx.emit(fx.crit_burst, ball.global_position)
		await get_tree().create_timer(0.05).timeout
		ball.create_fx.emit(fx.crit_burst, ball.global_position)
		await get_tree().create_timer(0.05).timeout
		ball.create_fx.emit(fx.crit_burst, ball.global_position)

func alice(game: Game, player: Player):
	pass

func yuyuko(game: Game, player: Player):
	if player.super_charge < 1:
		return

	player.super_charge -= 1
	player.scale = Vector3(3, 3, 3)
	
	await get_tree().create_timer(3).timeout
	
	player.scale = Vector3(1, 1, 1)
		
func marisa(game: Game, player: Player):
	player.can_move = false
	var fx = game.get_fx_manager()
	fx.create_at_pos(fx.perfect_burst, player.global_position + Vector3(0.5,0.0,0.0))
	fx.create_at_pos(fx.holy_pillar, player.global_position + Vector3(0.5,0.0,0.0))
	await get_tree().create_timer(0.3).timeout
	player.can_move = true
