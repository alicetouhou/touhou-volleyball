extends SyncedRigidBody

signal turn

var MOVEMENT_SPEED := SGFixed.from_int(9)

var rollback = false

func on_rollback() -> void:
	rollback = true

func stop_rollback() -> void:
	rollback = false

# Input, set by InputManager each tick.
var direction: Vector2i
var jumping: bool
var kicking: bool
var supering: bool

func _integrate_forces():
	var prev_velocity = velocity.x
	velocity.x += SGFixed.mul(MOVEMENT_SPEED, direction.x)
	if sign(velocity.x) != sign(prev_velocity) and sign(velocity.x) != 0:
		turn.emit(sign(velocity.x))
	super._integrate_forces()
