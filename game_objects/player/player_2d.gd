class_name Player2D

extends SyncedRigidBody

const SPEED = 20
const JUMP = 65536*30

var input_device = -99
var player_id: int
var _character: CharacterResource

var _last_joy_direction: Vector4i
var _last_jumping = false
var _last_kicking = false
var _last_supering = false

var ticks = 0

func set_character(character_id: String) -> void:
	_character = load("res://resources/characters/%s" % character_id)

func _ready() -> void:
	up_direction = SGFixed.vector2(0, -65536)

# Only runs on client, disabled_input is set when player is created.
# The `Input` class does not allow you to check if an input was performed by a specific
# device so we need to use the _input method :(
func _input(event: InputEvent) -> void:
	if not is_multiplayer_authority():
		return
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

	if event.is_action_pressed("up"):
		_last_jumping = true
	if event.is_action_pressed("kick"):
		_last_kicking = true
	if event.is_action_pressed("super"):
		_last_supering = true
	if event.is_action_released("up"):
		_last_jumping = false
	if event.is_action_released("kick"):
		_last_kicking = false
	if event.is_action_released("super"):
		_last_supering = false

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

func _predict_remote_input(previous_input: Dictionary, _ticks_since_real_input: int) -> Dictionary:
	previous_input["jumping"] = false
	previous_input["supering"] = false
	previous_input["kicking"] = false
	return previous_input

func _network_process(input: Dictionary) -> void:
	ticks += 1
	var joy_direction = input.get("joy_direction", Vector4i.ZERO)
	var jumping = input.get("jumping", false)
	var kicking = input.get("kicking", false)
	var supering = input.get("supering", false)

	velocity.x = SPEED * (joy_direction.y - joy_direction.x)

	if input.get("jumping", false) and is_on_floor():
		velocity.y = -JUMP

	super._network_process(input)

func _save_state() -> Dictionary:
	var state = super._save_state()
	state["ticks"] = ticks
	return state

func _load_state(state):
	ticks = state["ticks"]
	super._load_state(state)
