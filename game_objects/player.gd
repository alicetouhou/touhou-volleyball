extends RigidBody2D

const MOVEMENT_SPEED = 2000
const JUMP_POWER = 1000
const KICK_POWER = 2000

func kick():
	var ball = %Kick.get_overlapping_bodies().filter(func(x): return x.is_in_group("ball"))
	print(ball)
	
	if not ball:
		return

func _physics_process(delta: float) -> void:
	var x = int(Input.is_action_pressed("right")) - int(Input.is_action_pressed("left"))
	
	apply_central_force(Vector2(x, 0)  * MOVEMENT_SPEED)

	if Input.is_action_just_pressed("up"):
		apply_central_impulse(Vector2(0, -JUMP_POWER))


func _input(event: InputEvent) -> void:
	if Input.is_action_just_pressed("kick"):
		kick()
