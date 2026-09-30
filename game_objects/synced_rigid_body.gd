class_name SyncedRigidBody

extends SGCharacterBody2D

@onready var GRAVITY = Globals.GRAVITY

var display_position: Vector2 = Vector2.ZERO

func _ready() -> void:
	up_direction = SGFixed.vector2(0, -65536)

func _network_spawn(_data):
	sync_to_physics_engine()

func _network_process(_input):
	display_position.x = SGFixed.to_float(fixed_position_x)
	display_position.y = SGFixed.to_float(fixed_position_y)

	velocity.y += GRAVITY
	move_and_slide()

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
		velocity=velocity,
	}

func _load_state(state: Dictionary):
	fixed_position = SGFixed.vector2(state["fixed_position_x"], state["fixed_position_y"])
	fixed_rotation = state["fixed_rotation"]
	velocity = state["velocity"]

	sync_to_physics_engine()
