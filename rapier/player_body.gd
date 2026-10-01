extends RapierRigidBody3D


const MOVEMENT_SPEED := 9.0

var rollback = false

func on_rollback() -> void:
	rollback = true

func stop_rollback() -> void:
	rollback = false

var on_floor: bool = false

# Input, set by InputManager each tick.
var direction: Vector2
var jumping: bool
var kicking: bool
var supering: bool

func _integrate_forces(state: PhysicsDirectBodyState3D) -> void:
	#linear_velocity.x = direction.x * MOVEMENT_SPEED
	#if rollback:
	#	print(direction)
	
	# https://forum.godotengine.org/t/how-to-check-if-rigid-body-is-on-floor/65679/3
	var i := 0
	on_floor = false
	while i < state.get_contact_count():
		var normal := state.get_contact_local_normal(i)
		#  1.0 would be perfectly straight up
		#  0.0 is a wall
		# -1.0 is a ceiling
		if normal.dot(Vector3.UP) > 0.3: # this can be dialed in
			on_floor = true
		i += 1
