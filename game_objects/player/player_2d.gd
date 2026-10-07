class_name Player2D

extends SyncedRigidBody

const SPEED = 14
const JUMP = int(65536*20 + SGFixed.HALF) 
const KICK_POWER = SGFixed.ONE * 30

var input_device = -99
var player_id: int
var _character: CharacterResource

var _last_joy_direction: Vector4i
var _last_jumping = false
var _last_kicking = false
var _last_supering = false

var _direction = Vector4i(0,0,0,0)

const KICK_COOLDOWN_SYNCED_ticks = 30

var SYNCED_ticks := 0
var SYNCED_jumping_for_ticks := 0
var SYNCED_supering_for_ticks := 0

var SYNCED_kicking_for_ticks := 0
var SYNCED_last_kicked_on_tick := -10

var SYNCED_facing_direction = 1

var ball: Ball2D

signal kick(successful: bool)
signal turn(direction: int)

func set_character(character_id: String) -> void:
	_character = load("res://resources/characters/%s" % character_id)

func _ready() -> void:
	up_direction = SGFixed.vector2(0, -65536)

# Only runs on client, disabled_input is set when player is created.
# The `Input` class does not allow you to check if an input was performed by a specific
# device so we need to use the _input method :(
func _input(event: InputEvent) -> void:
	if input_device > -99 and event.device != input_device:
		return

	if event.is_action_pressed("left") or event.is_action_released("left"):
		_last_joy_direction.x = SGFixed.from_float(event.get_action_strength("left"))
	if event.is_action_pressed("right") or event.is_action_released("right"):
		_last_joy_direction.y =  SGFixed.from_float(event.get_action_strength("right"))
	if event.is_action_pressed("up") or event.is_action_released("up"):
		_last_joy_direction.z = SGFixed.from_float(event.get_action_strength("up"))
	if event.is_action_pressed("down") or event.is_action_released("down"):
		_last_joy_direction.w = SGFixed.from_float(event.get_action_strength("down"))

	if event.is_action_released("up"):
		_last_jumping = false
	if event.is_action_released("kick"):
		_last_kicking = false
	if event.is_action_released("super"):
		_last_supering = false
	if event.is_action_pressed("up"):
		_last_jumping = true
	if event.is_action_pressed("kick"):
		_last_kicking = true
	if event.is_action_pressed("super"):
		_last_supering = true

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		_last_joy_direction = Vector4i.ZERO

func _get_local_input() -> Dictionary:
	return {
		joy_direction=_last_joy_direction,
		jumping=_last_jumping,
		kicking=_last_kicking,
		supering=_last_supering,
	}

func _predict_remote_input(previous_input: Dictionary, SYNCED_ticks_since_real_input: int) -> Dictionary:
	var out = previous_input.duplicate()

	if SYNCED_ticks_since_real_input >= 1:
		out["SYNCED_kicking_for_ticks"] = 0

	out["joy_direction"] = Vector4.ZERO

	return out
	
func _integrate_forces():
	velocity.x += SPEED * (_direction.y - _direction.x)
	if sign(velocity.x) != SYNCED_facing_direction and sign(velocity.x) != 0:
		if not SyncManager.is_in_rollback():
			turn.emit(sign(velocity.x))
		SYNCED_facing_direction = sign(velocity.x)
	super._integrate_forces()

func _network_preprocess(input):
	super._network_preprocess(input)
	%KickArea.sync_to_physics_engine()
 
func _network_process(input: Dictionary) -> void:
	SYNCED_ticks += 1
	var joy_direction = input.get("joy_direction", Vector4i.ZERO)

	var jumping = input.get("jumping", false)
	var kicking = input.get("kicking", false)
	var supering = input.get("supering", false)
	
	if joy_direction.w >= 1:
		GRAVITY_SCALE = SGFixed.from_int(7)
	else:
		GRAVITY_SCALE = SGFixed.ONE

	if jumping:
		SYNCED_jumping_for_ticks += 1
	else:
		SYNCED_jumping_for_ticks = 0
	if kicking:
		SYNCED_kicking_for_ticks += 1
	else:
		SYNCED_kicking_for_ticks = 0
	if supering:
		SYNCED_supering_for_ticks += 1
	else:
		SYNCED_supering_for_ticks = 0

	_direction = joy_direction

	if SYNCED_jumping_for_ticks == 1 and SYNCED_is_on_floor_USE_THIS_ONE:
		apply_central_impulse(SGFixed.vector2(0,-JUMP))

	# Make sure the kick area is aware of collisions
	if SYNCED_kicking_for_ticks == 1 and (SYNCED_ticks - SYNCED_last_kicked_on_tick) > KICK_COOLDOWN_SYNCED_ticks:
		if not SyncManager.is_in_rollback():
			kick.emit(false)
		SYNCED_last_kicked_on_tick = SYNCED_ticks
		var bodies = %KickArea.get_overlapping_bodies()
		var ball_index = bodies.find_custom(func(x): return x.is_in_group("ball"))
		if ball_index >= 0:
			if not SyncManager.is_in_rollback():
				kick.emit(true)
			ball = bodies[ball_index]
			var hit_direction = ball.fixed_position.direction_to(fixed_position)
			var hit_force_vector = SGFixed.vector2(-SGFixed.mul(KICK_POWER, hit_direction.x) + linear_velocity.x, -SGFixed.mul(KICK_POWER, hit_direction.y) + linear_velocity.y)
			var ball_rad = 99091
			var hit_distance_vector = SGFixed.vector2(SGFixed.mul(ball_rad,hit_direction.x),SGFixed.mul(ball_rad,hit_direction.y))	
			ball.apply_impulse(hit_force_vector, hit_distance_vector)

func _save_state() -> Dictionary:
	var state = super._save_state()
	state["SYNCED_ticks"] = SYNCED_ticks
	state["SYNCED_jumping_for_ticks"] = SYNCED_jumping_for_ticks
	state["SYNCED_kicking_for_ticks"] = SYNCED_kicking_for_ticks
	state["SYNCED_supering_for_ticks"] = SYNCED_supering_for_ticks
	state["SYNCED_last_kicked_on_tick"] = SYNCED_last_kicked_on_tick
	state["SYNCED_facing_direction"] = SYNCED_facing_direction
	return state

func _load_state(state):
	SYNCED_ticks = state["SYNCED_ticks"]
	SYNCED_jumping_for_ticks = state["SYNCED_jumping_for_ticks"]
	SYNCED_kicking_for_ticks = state["SYNCED_kicking_for_ticks"]
	SYNCED_supering_for_ticks = state["SYNCED_supering_for_ticks"]
	SYNCED_last_kicked_on_tick = state["SYNCED_last_kicked_on_tick"]
	SYNCED_facing_direction = state["SYNCED_facing_direction"]
	super._load_state(state)
	%KickArea.sync_to_physics_engine()
