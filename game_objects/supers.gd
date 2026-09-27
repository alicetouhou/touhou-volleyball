extends Node

func run(game: Level, player: Player):
	var character_name = player.character.name
	
	if character_name == "Reimu":
		reimu(game, player)
	if character_name == "Alice":
		alice(game, player)
	if character_name == "Yuyuko":
		yuyuko(game, player)
	if character_name == "Marisa":
		marisa(game, player)

func reimu(game: Level, player: Player):
	if player.super_charge < 1:
		return
	var fx = game.get_fx_manager()
	var ball = player.find_ball()
	if ball:
		player.super_charge -= 1

		var direction: Vector3
		if (ball.position.x-player.position.x) * player.position.x < 0:
			direction = ball.position.direction_to(Vector3(0.,max(player.position.y,5),0))
		else:
			direction = ball.position.direction_to(Vector3(sign(player.position.x)*5.,max(player.position.y,5),0))
		
		ball.apply_central_impulse(direction * 30.)

		ball.create_fx.emit(fx.crit_burst, (ball.global_position + player.global_position) / 2)
		await get_tree().create_timer(0.05).timeout
		ball.create_fx.emit(fx.crit_burst, ball.global_position)
		await get_tree().create_timer(0.05).timeout
		ball.create_fx.emit(fx.crit_burst, ball.global_position)
		await get_tree().create_timer(0.05).timeout
		ball.create_fx.emit(fx.crit_burst, ball.global_position)

func alice(game: Level, player: Player):
	pass

func yuyuko(game: Level, player: Player):
	if player.super_charge < 1:
		return

	player.super_charge -= 1
	player.scale = Vector3(3, 3, 3)
	
	await get_tree().create_timer(3).timeout
	
	player.scale = Vector3(1, 1, 1)
		
func marisa(level: Level, player: Player):
	if player.super_charge < 3:
		return

	player.super_charge -= 3
	
	if (abs(level.ball.position.y - player.position.y) > 10. or player.position.x > level.ball.position.x or player.position.x - level.ball.position.x > 20):
		return
	
	player.movement_scale = 0.
	level.ball.set_velocity_multiplier(0.0, 0.5)
	var fx = level.get_fx_manager()
	
	await get_tree().create_timer(0.2).timeout
	fx.create_at_pos(fx.perfect_burst, player.global_position + Vector3(0.5,0.0,0.0))
	fx.create_at_pos(fx.holy_pillar, player.global_position + Vector3(0.5,0.0,0.0))
	await get_tree().create_timer(0.1).timeout
	
	level.ball.set_velocity_multiplier(1.0, 1.0)
	level.ball.apply_central_impulse(Vector3(40.0,1.0,0.0))
	level.ball.set_collision_mask_value(4, false)
	await get_tree().create_timer(0.5).timeout
	player.movement_scale = 1.
	
	await get_tree().create_timer(1.0).timeout
	level.ball.set_collision_mask_value(4, true)
