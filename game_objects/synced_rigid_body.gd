class_name SyncedRigidBody

extends SGCharacterBody2D

const SPEED = 1_000_000
const GRAVITY = 32768
const JUMP = 65536*15

func _ready() -> void:
	up_direction = SGFixed.vector2(0, -65536)

func _get_local_input():
	var x_motion: int = SGFixed.from_float(Input.get_action_strength("right") - Input.get_action_strength("left"))
	var jumping = Input.is_action_just_pressed("up")
	
	return {
		x_motion=x_motion,
		jumping=jumping,
	}


func _network_process(input):
	velocity.x = input.get("x_motion", 0)
	
	velocity.y += GRAVITY

	if input.get("jumping", false):
		velocity.y = -JUMP

	move_and_slide()
	
func _save_state() -> Dictionary:
	return {
		fixed_position=fixed_position,
		fixed_rotation=fixed_rotation,
		velocity=velocity,
	}
	
func _load_state(state: Dictionary):
	fixed_position = state["fixed_position"]
	fixed_rotation = state["fixed_rotation"]
	velocity = state["velocity"]

	sync_to_physics_engine()
