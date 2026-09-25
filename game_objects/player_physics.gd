extends RigidBody2D

var direction = 1
const MOVEMENT_SPEED = 2000
const JUMP_POWER = 700

const UP_KICK_POWER = Vector2()
const FORWARD_KICK_POWER = Vector2()
const DOWN_KICK_POWER = Vector2()

func kick():
	var bodies = %Kick.get_overlapping_bodies()
	var ball_index = bodies.find_custom(func(x): return x.is_in_group("ball"))

	if ball_index < 0:
		return

	var ball = bodies[ball_index]

	var ball_angle = global_position.angle_to_point(ball.global_position) + PI / 2
	
	while ball_angle < 0:
		ball_angle += PI
	while ball_angle > PI:
		ball_angle -= PI

	if ball_angle <= PI / 4:
		print("down")
	elif ball_angle <= PI / 4 * 3:
		print("forward")
	elif ball_angle <= PI:
		print("up")




func _physics_process(delta: float) -> void:
	var x = int(Input.is_action_pressed("right")) - int(Input.is_action_pressed("left"))
	
	apply_central_force(Vector2(x, 0)  * MOVEMENT_SPEED)

	if Input.is_action_just_pressed("up"):
		apply_central_impulse(Vector2(0, -JUMP_POWER))


func _input(event: InputEvent) -> void:
	if Input.is_action_just_pressed("kick"):
		kick()
