class_name SyncedRigidBody

extends SGCharacterBody2D

@onready var GRAVITY = Globals.GRAVITY

func _ready() -> void:
	up_direction = SGFixed.vector2(0, -65536)

func _network_spawn(_data):
	sync_to_physics_engine()

func _network_process(_input):
	velocity.y += GRAVITY
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
