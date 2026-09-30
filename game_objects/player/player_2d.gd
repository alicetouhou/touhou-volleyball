class_name Player2D

extends SyncedRigidBody

const SPEED = 10
const JUMP = int(65536*21.5)
const KICK_POWER = SGFixed.ONE * 20

var input_device = -99
var player_id: int
var _character: CharacterResource

var _last_joy_direction: Vector4i
var _last_jumping = false
var _last_kicking = false
var _last_supering = false

var _direction = Vector4i(0,0,0,0)

const KICK_COOLDOWN_TICKS = 5

var ticks = 0
var jumping_for_ticks = 0
var kicking_for_ticks = 0
var supering_for_ticks = 0
var last_kicked_on_ticked = -10

signal play_kick_animation(hit: bool)

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

func _predict_remote_input(previous_input: Dictionary, ticks_since_real_input: int) -> Dictionary:
	if ticks_since_real_input > 1:
		previous_input.erase("jumping")
		previous_input.erase("kicking")
		previous_input.erase("supering")

	## Input decay
	if previous_input.get("joy_direction"):
		var decay_amount = SGFixed.from_int((4. - ticks_since_real_input) / 4.)
		previous_input["joy_direction"].x = SGFixed.mul(previous_input["joy_direction"].x, decay_amount)
		previous_input["joy_direction"].y = SGFixed.mul(previous_input["joy_direction"].y, decay_amount)

	return previous_input
	
func _integrate_forces():
	super._integrate_forces()
	velocity.x += SPEED * (_direction.y - _direction.x)

func _network_process(input: Dictionary) -> void:
	ticks += 1.
	var joy_direction = input.get("joy_direction", Vector4i.ZERO)

	var jumping = input.get("jumping", false)
	var kicking = input.get("kicking", false)
	var supering = input.get("supering", false)

	if jumping:
		jumping_for_ticks += 1
	else:
		jumping_for_ticks = 0
	if kicking:
		kicking_for_ticks += 1
	else:
		kicking_for_ticks = 0
	if supering:
		supering_for_ticks += 1
	else:
		supering_for_ticks = 0
	
	_direction = joy_direction

	if jumping_for_ticks == 1:
		apply_central_impulse(SGFixed.vector2(0,-JUMP))

	if kicking_for_ticks > 1 and kicking_for_ticks <= 5 and (ticks - last_kicked_on_ticked) > KICK_COOLDOWN_TICKS:
		last_kicked_on_ticked = ticks
		play_kick_animation.emit(false)
		# Make sure the kick area is aware of collisions
		%KickArea.sync_to_physics_engine()
		var bodies = %KickArea.get_overlapping_bodies()
		var ball_index = bodies.find_custom(func(x): return x.is_in_group("ball"))

		if ball_index > 0:
			play_kick_animation.emit(true)
			var ball: Ball2D = bodies[ball_index]
			var hit_direction = ball.fixed_position.direction_to(fixed_position)
			var hit_force_vector = SGFixed.vector2(KICK_POWER * -hit_direction.x + velocity.x,KICK_POWER * -hit_direction.y + velocity.y)
			var ball_rad = 99091
			var hit_distance_vector = SGFixed.vector2(SGFixed.mul(ball_rad,hit_direction.x),SGFixed.mul(ball_rad,hit_direction.y))
			ball.apply_impulse(hit_force_vector,hit_distance_vector)

	super._network_process(input)

func _save_state() -> Dictionary:
	var state = super._save_state()
	state["ticks"] = ticks
	state["jumping_for_ticks"] = jumping_for_ticks
	state["kicking_for_ticks"] = kicking_for_ticks
	state["supering_for_ticks"] = supering_for_ticks
	state["last_kicked_on_ticked"] = last_kicked_on_ticked
	return state

func _load_state(state):
	ticks = state["ticks"]
	jumping_for_ticks = state["jumping_for_ticks"]
	kicking_for_ticks = state["kicking_for_ticks"]
	supering_for_ticks = state["supering_for_ticks"]
	last_kicked_on_ticked = state["last_kicked_on_ticked"]
	super._load_state(state)
