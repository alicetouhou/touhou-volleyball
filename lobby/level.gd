class_name Level

extends Node3D


const player_scene = preload("res://game_objects/player/Player3D.tscn")
# const cpu_scene = preload("res://game_objects/player/CPUPlayer.tscn")

## Which side's turn is currently playing (ie who served).
var serving := 0
## If true, the round is currently running.
var round_running := false
## Score [left, right]
var score = [0, 0]

var ball: Ball3D

@onready var ball_positions = [%P1BallSpawnPoint.global_position, %P2BallSpawnPoint.global_position]
@onready var player_positions = [%P1SpawnPoint.global_position, %P2SpawnPoint.global_position, %P3SpawnPoint.global_position, %P4SpawnPoint.global_position]
@onready var players = $Players
@onready var camera = %Camera

## Spawn the required nodes and initiate first play on all clients
func start_game() -> void:
	# Container resets and definitions
	var ball_container = $Ball
	for child in ball_container.get_children():
		child.queue_free()

	for child in players.get_children():
		child.queue_free()
	
	score = [0, 0]

	# Ball
	ball = SyncManager.spawn("ball", $Ball, preload("res://game_objects/ball/Ball3D.tscn"), {
		"fixed_position_x": SGFixed.from_float(ball_positions[0].x),
		"fixed_position_y": SGFixed.from_float(ball_positions[0].y),
	})
	ball.create_fx.connect(create_fx)

	# Players
	var connected_players: Array = get_parent().players
	if len(connected_players) % 2 == 1:
		connected_players.push_back(PlayerPeer.new_cpu_player())

	var i = 0
	for peer: PlayerPeer in connected_players:
		var use_player_scene: PackedScene = player_scene

		var player_name = "%s-%s" % [peer.peer_id, peer.input_device] if peer.peer_id > -1 else "cpu"
		var player: Player3D = SyncManager.spawn(player_name, players, use_player_scene, {
			"player_id": peer.peer_id,
			"fixed_position_x": SGFixed.from_float(player_positions[i].x),
			"fixed_position_y": SGFixed.from_float(player_positions[i].y),
			"input_device": peer.input_device,
			"character": peer.character,
		})
		player.set_multiplayer_authority(peer.peer_id)
		
		player.request_create_dust_trail.connect(func(direction): create_dust_trail(player, direction))
		player.request_create_ball_hit_visual.connect(func(): create_ball_hit_visual(player))

		i += 1

	get_tree().call_group("cpu", "cpu_init", ball, players.get_children())
	get_tree().call_group("cpu", "update_game_state", false)

func create_dust_trail(player: Player3D, direction: int):
	%FxManager.create_at_pos(FXManager.dust_settle, player.position - Vector3(0, .6, 0), direction != 1)

func create_ball_hit_visual(player: Player3D):
	%FxManager.create_at_pos(FXManager.pummel_pop, (player.position + ball.position) / 2.)
	%FxManager.create_with_parent_3D(FXManager.pressure_ring, ball)
	%Camera.add_trauma(.1, .1)

func create_fx(fx: PackedScene, pos: Vector3) -> void:
	%FxManager.create_at_pos(fx, pos)

func get_fx_manager():
	return %FxManager
