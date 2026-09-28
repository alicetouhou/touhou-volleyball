extends Node

const shanghai = preload("res://game_objects/cpu/shanghai.tscn")

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
	if character_name == "Sakuya":
		sakuya(game, player)

func reimu(game: Level, player: Player):
	if player.super_charge < 1:
		return
	var fx = game.get_fx_manager()
	var ball = game.ball
	if abs(ball.position.x-player.position.x) > 2.0:
		return
		
	player.super_charge -= 1

	player.set_velocity_multiplier(0.1,10.0)
	ball.set_velocity_multiplier(0.1, 10.0)
	await get_tree().create_timer(0.25).timeout


	ball.linear_velocity = Vector3.ZERO
	ball.set_velocity_multiplier(1.0,-1.)
	player.kick(25, ball)

	ball.create_fx.emit(fx.crit_burst, (ball.global_position + player.global_position) / 2)
	fx.create_at_pos(fx.crit_burst, player.global_position)
	game.camera.add_trauma(0.05)

	await get_tree().create_timer(0.05).timeout
	ball.create_fx.emit(fx.crit_burst, ball.global_position)
	await get_tree().create_timer(0.05).timeout
	ball.create_fx.emit(fx.crit_burst, ball.global_position)
	await get_tree().create_timer(0.05).timeout
	ball.create_fx.emit(fx.crit_burst, ball.global_position)
	
	player.set_velocity_multiplier(1.0,1.0)

func alice(game: Level, player: Player):
	if player.super_charge < 1:
		return
	player.super_charge -= 1
	var shanghai_instance = shanghai.instantiate()
	game.players.add_child(shanghai_instance)
	shanghai_instance.global_position = player.global_position + Vector3(-0.5,0.5,0.0)
	shanghai_instance.cpu_init(game.ball, game.players.get_children())
	
	await get_tree().create_timer(6.0).timeout
	if shanghai_instance and not shanghai_instance.is_queued_for_deletion():
		shanghai_instance.queue_free()

func yuyuko(game: Level, player: Player):
	if player.super_charge < 1:
		return
	player.super_charge -= 1
	player.scale = Vector3(3, 3, 3)

	await get_tree().create_timer(3).timeout
	
	player.scale = Vector3(1, 1, 1)
		
func marisa(level: Level, player: Player):
	if (abs(level.ball.position.y - player.position.y) > 5. or abs(player.position.x - level.ball.position.x) > 10):
		return
	if player.super_charge < 3:
		return
	player.super_charge -= 3
	
	var reflect = false
	if player.position.x > level.ball.position.x:
		reflect = true
	
	player.set_velocity_multiplier(0.0,0.5)
	level.ball.set_velocity_multiplier(0.0, 0.5)
	var fx = level.get_fx_manager()
	
	await get_tree().create_timer(0.2).timeout
	fx.create_at_pos(fx.perfect_burst, player.global_position + Vector3(0.0,0.0,0.0))
	fx.create_at_pos(fx.holy_pillar, player.global_position + Vector3(-1.0 if reflect else 1.0,0.0,0.0), reflect)
	level.camera.add_trauma(0.1)
	fx.create_particle_at_pos("master_spark_star", player.global_position, reflect)
	fx.create_particle_at_pos("master_spark_heart", player.global_position, reflect)
	await get_tree().create_timer(0.1).timeout
	
	level.camera.add_trauma(0.3)
	level.ball.set_velocity_multiplier(1.0, 1.0)
	level.ball.apply_central_impulse(Vector3(-40.0 if reflect else 40.0,1.0,0.0))
	level.ball.set_collision_mask_value(4, false)
	
	for i in range(0,5):
		level.ball.create_fx.emit(fx.perfect_burst, level.ball.global_position)
		await get_tree().create_timer(0.05).timeout
	
	await get_tree().create_timer(0.25).timeout
	player.set_velocity_multiplier(1.0,0.2)
	
	await get_tree().create_timer(1.0).timeout
	level.ball.set_collision_mask_value(4, true)

func sakuya(level: Level, player: Player):
	if player.super_charge < 2:
		return
	player.super_charge -= 2
	var fx = level.get_fx_manager()

	level.ball.set_velocity_multiplier(0.2, 0.5)
	fx.create_with_parent_3D(fx.evolve_flash, level.ball)
	await get_tree().create_timer(3.0).timeout
	level.ball.set_velocity_multiplier(1.0, -1)
