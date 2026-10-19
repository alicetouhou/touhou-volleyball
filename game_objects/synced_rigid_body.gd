class_name SyncedRigidBody

extends SGRigidBody2D

var display_position: Vector2 = Vector2.ZERO
var display_rotation = 0

var SYNCED_is_on_floor_USE_THIS_ONE = false

func _ready() -> void:
	up_direction = SGFixed.vector2(0, -65536)

func _network_spawn(_data):
	clear_forces()
	sync_to_physics_engine()

func _network_preprocess(_input):
	clear_forces()
	sync_to_physics_engine()

func _network_process():
	display_position.x = SGFixed.to_float(fixed_position.x)
	display_position.y = SGFixed.to_float(fixed_position.y)
	move_and_slide()

	if is_on_floor():
		SYNCED_is_on_floor_USE_THIS_ONE = true
	else:
		SYNCED_is_on_floor_USE_THIS_ONE = false
	
	sync_to_physics_engine()

func _interpolate_state(old_state: Dictionary, new_state: Dictionary, weight: float) -> void:
	var sprite_pos_x: int = lerp(old_state["fixed_position_x"], new_state["fixed_position_x"], weight)
	var sprite_pos_y: int = lerp(old_state["fixed_position_y"], new_state["fixed_position_y"], weight)
	display_position.x = SGFixed.to_float(sprite_pos_x)
	display_position.y = SGFixed.to_float(sprite_pos_y)

func _save_state() -> Dictionary:
	return {
		fixed_position_x=fixed_position_x,
		fixed_position_y=fixed_position_y,
		fixed_rotation=fixed_rotation,
		velocity_x=velocity.x,
		velocity_y=velocity.y,
		angular_velocity=angular_velocity,
		gravity_scale=gravity_scale,
		SYNCED_is_on_floor_USE_THIS_ONE=SYNCED_is_on_floor_USE_THIS_ONE,
	}

func _load_state(state: Dictionary):
	fixed_position_x = state["fixed_position_x"]
	fixed_position_y = state["fixed_position_y"]
	fixed_rotation = state["fixed_rotation"]
	velocity.x = state["velocity_x"]
	velocity.y = state["velocity_y"]
	angular_velocity = state["angular_velocity"]
	gravity_scale = state["gravity_scale"]
	SYNCED_is_on_floor_USE_THIS_ONE = state["SYNCED_is_on_floor_USE_THIS_ONE"]

	clear_forces()
	sync_to_physics_engine()
