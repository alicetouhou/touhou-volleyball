class_name Level

extends Node3D


const player_scene = preload("res://game_objects/player/Player3D.tscn")
const cpu_scene = preload("res://game_objects/player/CPUPlayer.tscn")

## The ball node.
var ball: RigidBody3D
## Which side's turn is currently playing (ie who served).
var serving := 0
## If true, the round is currently running.
var round_running := false
## Score [left, right]
var score = [0, 0]

@onready var ball_positions = [%P1BallSpawnPoint.global_position, %P2BallSpawnPoint.global_position]
@onready var player_positions = [%P1SpawnPoint.global_position, %P2SpawnPoint.global_position, %P3SpawnPoint.global_position, %P4SpawnPoint.global_position]
@onready var players = $Players
@onready var camera = %Camera

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
	$BallSpawner.spawn()
	
	# Players
	var connected_players: Array = get_parent().players
	if len(connected_players) % 2 == 1:
		connected_players.push_back(PlayerPeer.new_cpu_player())

	var i = 0
	for peer: PlayerPeer in connected_players:
		var player = $PlayerSpawner.spawn(PlayerPeer.serialize([peer])[0])
		
		var charge_bar = preload("res://game_objects/SuperCharge.tscn").instantiate()
		charge_bar.name = str(peer.peer_id)
		var side = 0
		if i >= floori(len(connected_players) / 2.):
			side = 1
		%ChargeBars.get_child(side).add_child(charge_bar)
		player.super_charge_updated.connect(
			func(value): charge_bar.set_charge.rpc(value)
		)
		
		if peer.peer_id > 0:
			player.set_character.rpc.call_deferred($"/root/Lobby".get_player_by_id(peer.peer_id).character)
		i += 1
	
	get_tree().call_group("cpu", "cpu_init", ball, players.get_children())
	get_tree().call_group("cpu", "update_game_state", false)
	
	start_round()

func reset() -> void:
	var ball_container = $Ball
	for child in ball_container.get_children():
		child.queue_free()
	ball = null

	for child in players.get_children():
		child.queue_free()

func start_round() -> void:
	if not ball:
		return
	
	for i in players.get_child_count():
		var player: Node3D = players.get_child(i)
		player.linear_velocity = Vector3.ZERO
		player.goto.rpc(player_positions[wrap(i, 0, len(player_positions))])
		
	ball.linear_velocity = Vector3.ZERO
	ball.speed_percent = 1.0
	ball.global_position = ball_positions[serving]
	
	await get_tree().create_timer(1).timeout
	if not ball:
		return
	
	round_running = true
	ball.freeze = false
	get_tree().call_group("cpu", "update_game_state", true)

func end_round() -> void:
	if ball.position.x >= 0:
		serving = 0
	else:
		serving = 1
	
	if not round_running:
		return
	
	round_running = false
	get_tree().call_group("cpu", "update_game_state", false)
	
	score[serving] += 1
	%ScoreBoard.text = "%s - %s" % score
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

func player_super_used(player: PlayerPeer) -> void:
	Supers.run(self, players.get_node("%s-%s" % [player.peer_id, player.input_device]))
	
func get_fx_manager():
	return %FxManager

func setup_player(data, peer: PlayerPeer = null) -> Node:
	if not peer:
		peer = PlayerPeer.parse([data])[0]

	var player: Player = (player_scene if peer.peer_id > -1 else cpu_scene).instantiate()
	player.name = "%s-%s" % [peer.peer_id, peer.input_device] if peer.peer_id > -1 else "cpu"

	# Disable input for CPUs and players on other computers
	player.set_multiplayer_authority(peer.peer_id)
	if peer.peer_id < 0 or (player.get_multiplayer_authority() != multiplayer.get_unique_id() and not peer.local_co_op):
		player.disable_input()
	
	if peer.local_co_op:
		player.set_multiplayer_authority(multiplayer.get_unique_id())
	
	player.on_hit_ball.connect(player_hit_ball)
	player.super_used.connect(func(): player_super_used(peer))
	player.create_fx.connect(create_fx)

	player.input_device = peer.input_device

	return player

func setup_ball(_data) -> Node:
	ball = preload("res://game_objects/ball/Ball3D.tscn").instantiate()
	ball.freeze = true
	ball.create_fx.connect(create_fx)
	ball.body_entered.connect(ball_collided)
	
	return ball

func _ready() -> void:
	$PlayerSpawner.spawn_function = setup_player
	$BallSpawner.spawn_function = setup_ball
