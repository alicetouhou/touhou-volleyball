extends Node3D


## The ball node.
var ball: RigidBody3D
## Which side's turn is currently playing (ie who served).
var serving := 0
## If true, the round is currently running.
var round_running := false

@onready var ball_positions = [%P1BallSpawnPoint.global_position, %P2BallSpawnPoint.global_position]
@onready var player_positions = [%P1SpawnPoint.global_position, %P2SpawnPoint.global_position]
@onready var players = $Players

## Spawn the required nodes and initiate first play on all clients
@rpc("call_local")
func start_game() -> void:
	# Container resets and definitions
	var ball_container = $Ball
	for child in ball_container.get_children():
		child.queue_free()

	for child in players.get_children():
		child.queue_free()
	
	# Ball
	ball = preload("res://game_objects/ball/Ball3D.tscn").instantiate()
	ball.freeze = true
	ball.create_fx.connect(create_fx)
	ball_container.add_child(ball, true)
	
	# Players
	var i = 0
	for peer in PackedInt32Array([1]) + multiplayer.get_peers():
		var player: Player = preload("res://game_objects/player/Player3D.tscn").instantiate()
		
		player.name = str(peer)
		player.player_id = peer
		%ChargeBars.get_child(i).name = str(peer)
		
		player.on_hit_ball.connect(player_hit_ball)
		player.super_used.connect(func(): player_super_used(peer))
		player.super_charge_updated.connect(
			func(value): %ChargeBars.get_node(str(peer)).set_charge(value)
		)
		
		players.add_child(player, true)
		i += 1
	
	start_round()
	
func start_round() -> void:
	for i in players.get_child_count():
		var player: Node3D = players.get_child(i)
		player.linear_velocity = Vector3.ZERO
		player.global_position = player_positions[i]
		
	ball.linear_velocity = Vector3.ZERO
	ball.speed_percent = 1.0
	ball.global_position = ball_positions[serving]
	
	await get_tree().create_timer(1).timeout
	
	round_running = true
	ball.freeze = false

func end_round() -> void:
	if ball.position.x >= 0:
		serving = 0
	else:
		serving = 1
	
	if not round_running:
		return
	
	round_running = false
	
	%Score.show()
	await get_tree().create_timer(.75).timeout
	%Score.hide()
	
	start_round()

func create_fx(fx: PackedScene, pos: Vector3) -> void:
	%FxManager.create_at_pos(fx, pos)

func ball_collided(body: Node) -> void:
	if body.is_in_group("ground"):
		end_round()

func player_hit_ball() -> void:
	%FxManager.create_with_parent_3D(FXManager.pressure_ring, ball)
	%Camera.add_trauma(.1)

func player_super_used(player: int) -> void:
	Supers.run($TouhouVolleyball, players.get_node(str(player)))
