extends RigidBody3D

var direction = 1
const MOVEMENT_SPEED = 20
const JUMP_POWER = 7

const UP_KICK_POWER = Vector2()
const FORWARD_KICK_POWER = Vector2()
const DOWN_KICK_POWER = Vector2()

const KICK_TIME_ALLOW = .15
var time_since_kick_pressed = 1000

@onready var Animations = %AnimationTree.get("parameters/playback")

func kick():
	Animations.travel("kick_miss")
	var bodies = %KickHitbox.get_overlapping_bodies()
	var ball_index = bodies.find_custom(func(x): return x.is_in_group("ball"))

	if ball_index < 0:
		return

	Animations.travel("kick_hit")
	time_since_kick_pressed = 10000

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
	pass

func _physics_process(delta: float) -> void:
	var x = int(Input.is_action_pressed("right")) - int(Input.is_action_pressed("left"))

	apply_central_force(Vector3(x, 0, 0)  * MOVEMENT_SPEED)
	
	if sign(x) != direction and x != 0:
		direction = sign(x)
		
		if direction < 0:
			Animations.travel("turn")
			%Turning.play("turn_left")
		if direction > 0:
			Animations.travel("turn")
			%Turning.play("turn_right")

	if Input.is_action_just_pressed("up"):
		apply_central_impulse(Vector3(0, JUMP_POWER, 0))

	if Input.is_action_just_pressed("kick"):
		time_since_kick_pressed = 0

	time_since_kick_pressed += delta
	if time_since_kick_pressed < KICK_TIME_ALLOW:
		kick()
