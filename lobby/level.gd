class_name Level

extends Node3D


const player_scene = preload("res://game_objects/player/Player3D.tscn")
# const cpu_scene = preload("res://game_objects/player/CPUPlayer.tscn")

## Which side's turn is currently playing (ie who served).
var serving := 0
## If true, the round is currently running.
var round_running := false
## Score [left, right]
var SYNCED_score = [0, 0]
var SYNCED_round_running := false

var ball: Ball3D

@onready var ball_positions = [%P1BallSpawnPoint.global_position, %P2BallSpawnPoint.global_position]
@onready var player_positions = [%P1SpawnPoint.global_position, %P2SpawnPoint.global_position, %P3SpawnPoint.global_position, %P4SpawnPoint.global_position]
@onready var players = $Players
@onready var camera = %Camera
@onready var countdown_timer = $"../UI/Countdown"
@onready var scoreboard = $"../UI/ScoreBoard"

## Spawn the required nodes and initiate first play on all clients
func start_game() -> void:
	# Container resets and definitions
	var ball_container = $Ball
	for child in ball_container.get_children():
		child.queue_free()

	for child in players.get_children():
		child.queue_free()
	
	SYNCED_score = [0, 0]

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

	setup_round()

func _network_process(_input):
	if ball.get_ball_2d().SYNCED_is_on_floor_USE_THIS_ONE:
		if SYNCED_round_running:
			SYNCED_round_running = false
			var winning_player = 1 if ball.get_ball_2d().fixed_position.x > 0 else 0
			SYNCED_score[winning_player] += 1
			%EndRoundTimer.start()
			write_score()

func setup_round():
	countdown_timer.text = "3"
	countdown_timer.show()
	ball.get_ball_2d().SYNCED_freeze = true
	ball.get_ball_2d().linear_velocity = SGFixed.vector2(0, 0)

	ball.get_ball_2d().fixed_position_x = SGFixed.from_float(ball_positions[serving].x)
	ball.get_ball_2d().fixed_position_y = SGFixed.from_float(ball_positions[serving].y)

	%StartGameTimer3.start()
	%StartGameTimer2.start()
	%StartGameTimer1.start()

func start_round():
	countdown_timer.hide()
	SYNCED_round_running = true
	ball.get_ball_2d().SYNCED_freeze = false
	
	# Set up the server for the next round
	serving = (serving + 1) % 2

func reset() -> void:
	print("Reset, this needs to do something btw...")

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

func write_score():
	scoreboard.text = str(SYNCED_score[0]) + " - " + str(SYNCED_score[1])

func _on_start_game_timer_3_timeout() -> void:
	countdown_timer.text = "2"

func _on_start_game_timer_2_timeout() -> void:
	countdown_timer.text = "1"

func _on_start_game_timer_1_timeout() -> void:
	start_round()

func _on_end_round_timer_timeout() -> void:
	setup_round()

func _save_state() -> Dictionary:
	return {
		"SYNCED_score_left": SYNCED_score[0],
		"SYNCED_score_right": SYNCED_score[1],
		"SYNCED_round_running": SYNCED_round_running,
	}

func _load_state(data):
	SYNCED_score = [data.get("SYNCED_score_left", 0), data.get("SYNCED_score_right", 0)]
	SYNCED_round_running = data["SYNCED_round_running"]
