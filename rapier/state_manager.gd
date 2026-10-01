extends Node3D


var tick_time: float = 1.0 / ProjectSettings.get_setting(
    	"physics/common/physics_ticks_per_second"
	)
var tick: int = 0
var state_history
var log_tick: int = 20

@onready var manager: StateManager3D = $"../StateManager3D"
@onready var input_manager: InputManager = $"../InputManager"
@onready var players = $Players

## Schedule the manager to start tracking.
@rpc("call_local")
func start_tracking(at: float) -> void:
	await get_tree().create_timer(at - Time.get_unix_time_from_system()).timeout
	set_physics_process(true)

func start_game() -> void:
	var x = -2
	for peer_id in [1] + (multiplayer.get_peers() as Array):
		$PlayerSpawner.spawn({
			"peer_id": peer_id,
			"x": x,
		})
		x += 5

func spawn_player(data: Dictionary) -> Node3D:
	var player = preload("res://rapier/simple_player.tscn").instantiate()
	player.name = str(data["peer_id"])
	player.position.x = data["x"]
	return player

func log_hash() -> void:
	target_tick.rpc(tick + 120)

@rpc("any_peer", "call_local")
func target_tick(target: int) -> void:
	log_tick = target

func simulate_tick(at: int) -> void:
	var space := get_viewport().world_3d.space
	input_manager.apply_input_for_tick(at)

	RapierPhysicsServer3D.space_step(space, tick_time)
	RapierPhysicsServer3D.space_flush_queries(space)

## Rollback and resimulate to the current tick
func rollback(to: int) -> void:
	get_tree().call_group("rollback", "on_rollback")

	var space := get_viewport().world_3d.space
	var roll_to := tick

	var index := manager.ordered_cache_tags().find(to)
	if index < 0:
		push_error("Failed to find tick %s in cache! States will diverge." % to)
		return
	
	manager.load_cached_state(space, index)

	for i in range(to, roll_to + 1):
		simulate_tick(i)

	get_tree().call_group("rollback", "stop_rollback")

	print("Rolled back from %s to %s" % [roll_to, to])

## Cache state, advance tick and apply input for this tick.
func _physics_process(_delta: float) -> void:
	var space := get_viewport().world_3d.space
	manager.cache_state(space, tick)

	input_manager.get_player_input(tick)
	simulate_tick(tick)
	
	if input_manager.rollback:
		input_manager.rollback = false
		rollback(input_manager.rollback_to - 5)
		input_manager.rollback_to = UINT32_MAX
	
	if tick == log_tick:
		print("Tick %s hash %s" % [tick, hash(manager.export_state(space, "RustBincode"))])

	tick += 1


func _ready() -> void:
	$PlayerSpawner.spawn_function = spawn_player
	
	set_physics_process(false)
	var space := get_viewport().world_3d.space
	
	PhysicsServer3D.space_set_active(space, false)
