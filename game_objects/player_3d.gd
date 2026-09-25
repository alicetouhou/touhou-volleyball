extends RigidBody3D

var direction = 1
const MOVEMENT_SPEED = 20
const JUMP_POWER = 7

const UP_KICK_POWER = Vector2()
const FORWARD_KICK_POWER = Vector2()
const DOWN_KICK_POWER = Vector2()

@onready var Animations = %AnimationTree.get("parameters/playback/StateMachine")

func kick():
	var bodies = %KickHitbox.get_overlapping_bodies()
	var ball_index = bodies.find_custom(func(x): return x.is_in_group("ball"))
	Animations.travel("kick")

	if ball_index < 0:
		return

	var ball = bodies[ball_index]
	
	var global_position_2D = Vector2(global_position.x, global_position.y)
	var ball_global_position_2D = Vector2(ball.global_position.x, ball.global_position.y)

	var ball_angle = global_position_2D.angle_to_point(ball_global_position_2D) + PI / 2
	
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

func _ready() -> void:
	Animations.travel("idle")

func _physics_process(delta: float) -> void:
	var x = int(Input.is_action_pressed("right")) - int(Input.is_action_pressed("left"))
	
	apply_central_force(Vector3(x, 0, 0)  * MOVEMENT_SPEED)
	
	if sign(x) != direction and x != 0:
		direction = sign(x)
		Animations.travel("turn")

	if Input.is_action_just_pressed("up"):
		apply_central_impulse(Vector3(0, JUMP_POWER, 0))


func _input(event: InputEvent) -> void:
	if Input.is_action_just_pressed("kick"):
		kick()
