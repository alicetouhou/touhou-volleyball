extends Node2D

var syncing = false

var tick_time: float = 1.0 / ProjectSettings.get_setting(
    	"physics/common/physics_ticks_per_second"
	)
var tick: int = 0
var state_history: Dictionary[int, Variant]
var log_tick: int = 20

@onready var input_manager: InputManager = $"../InputManager"
@onready var players = $Players

## Schedule the manager to start tracking.
@rpc("call_local")
func start_tracking(at: float) -> void:
	await get_tree().create_timer(at - Time.get_unix_time_from_system()).timeout
	syncing = true

func start_game() -> void:
	var x = -2
	for peer_id in [1] + (multiplayer.get_peers() as Array):
		$PlayerSpawner.spawn({
			"peer_id": peer_id,
			"x": x,
		})
		x += 5

func spawn_player(data: Dictionary) -> SyncedRigidBody:
	var player = preload("res://networking/simple_player.tscn").instantiate()
	player.name = str(data["peer_id"])
	player.position.x = data["x"]
	return player

func log_hash() -> void:
	target_tick.rpc(tick + 120)

@rpc("any_peer", "call_local")
func target_tick(target: int) -> void:
	log_tick = target


func get_rollback_supporting_nodes():
	return get_tree().get_nodes_in_group("rollback")

func simulate_tick(at: int) -> void:
	input_manager.apply_input_for_tick(at)

	for node in get_rollback_supporting_nodes():
		if node.has_method("_network_process"):
			node._network_process()


func save_state(save_tick):
	var cached_state = {}

	for node in get_rollback_supporting_nodes():
		if node.has_method("_save_state"):
			cached_state[node.get_path()] = node._save_state()
	
	state_history[save_tick] = cached_state


func load_cached_state(load_tick):
	var frame = state_history.get(load_tick, null)

	if frame == null:
		print("No frame found for tick ", load_tick)
		return

	for node in get_rollback_supporting_nodes():
		if node.has_method("_load_state"):
			var state = frame[node.get_path()]
			node._load_state(state)


## Rollback and resimulate to the current tick
func rollback(to: int) -> void:
	get_tree().call_group("rollback", "on_rollback")
	var roll_to := tick

	load_cached_state(to)

	for i in range(to, roll_to + 1):
		simulate_tick(i)

	get_tree().call_group("rollback", "stop_rollback")

	print("Rolled back from %s to %s" % [roll_to, to])

## Cache state, advance tick and apply input for this tick.
func _physics_process(_delta: float) -> void:
	if not syncing:
		return

	save_state(tick)

	input_manager.get_player_input(tick)
	simulate_tick(tick)
	
	if input_manager.rollback:
		input_manager.rollback = false
		rollback(input_manager.rollback_to - 5)
		input_manager.rollback_to = UINT32_MAX
	
	if tick == log_tick:
		print("Tick %s Hash (unknown for now)" % [tick])

	tick += 1


func _ready() -> void:
	$PlayerSpawner.spawn_function = spawn_player
