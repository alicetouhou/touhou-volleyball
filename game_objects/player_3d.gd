extends RigidBody3D

@export var player_device = 16

var direction = 1
const MOVEMENT_SPEED = 7
const JUMP_POWER = 7

const UP_KICK_POWER = Vector2()
const FORWARD_KICK_POWER = Vector2()
const DOWN_KICK_POWER = Vector2()

var on_floor: bool = false
var floor: Object

const KICK_TIME_ALLOW = .15
var KICK_COOLDOWN = .1
var time_since_kick_pressed = 100
var time_since_kick = 100
var can_jump = true

signal create_fx(fx: PackedScene, pos: Vector3)
signal on_hit_ball

@onready var Animations = %AnimationTree.get("parameters/playback")

func kick():
	Animations.travel("kick_miss")
	var bodies = %KickHitbox.get_overlapping_bodies()
	var ball_index = bodies.find_custom(func(x): return x.is_in_group("ball"))

	if ball_index < 0:
		return

	Animations.travel("kick_hit")
	time_since_kick_pressed = 10000
	time_since_kick = 0
	
	var ball: RigidBody3D = bodies[ball_index]
	on_hit_ball.emit()
	create_fx.emit(FXManager.pummel_pop, (ball.global_position + global_position) / 2)
	create_fx.emit(FXManager.spark_spit, (ball.global_position + global_position) / 2)
	
	var global_position_2D = Vector2(global_position.x, global_position.y)
	var ball_global_position_2D = Vector2(ball.global_position.x, ball.global_position.y)

	var ball_angle = global_position_2D.angle_to_point(ball_global_position_2D) + PI / 2
	
	while ball_angle < 0:
		ball_angle += PI
	while ball_angle > PI:
		ball_angle -= PI
	
	# Always hit the ball torward the center of the court
	var hit_ball_in_direction = direction

	if is_up_pressed():
		ball.apply_impulse(Vector3(5 * hit_ball_in_direction, 10, 0))
	elif is_down_pressed():
		ball.apply_impulse(Vector3(10 * hit_ball_in_direction, -10, 0))
	else:
		ball.apply_impulse(Vector3(18 * hit_ball_in_direction, 0, 0))

func get_left_right():
	if player_device == 16:
		return Input.get_axis("left", "right")
	return Input.get_joy_axis(player_device, JOY_AXIS_LEFT_X)

func is_up_pressed():
	if player_device == 16:
		return Input.is_action_pressed("up")
	return Input.get_joy_axis(player_device, JOY_AXIS_LEFT_Y) < -.5

func is_down_pressed():
	if player_device == 16:
		return Input.is_action_pressed("down")
	return Input.get_joy_axis(player_device, JOY_AXIS_LEFT_Y) > .5

func is_kick_pressed():
	if player_device == 16:
		return Input.is_action_pressed("kick")
	return Input.is_joy_button_pressed(player_device, JOY_BUTTON_X)

func _physics_process(delta: float) -> void:
	var x = get_left_right()

	apply_central_force(Vector3(x, 0, 0) * MOVEMENT_SPEED)
	
	if sign(x) != direction and x != 0:
		direction = sign(x)

		if on_floor:
			create_fx.emit(FXManager.dust_settle, global_position + Vector3(0, -.6, 0))

		if direction < 0:
			Animations.travel("turn")
			%Turning.play("turn_left")
		if direction > 0:
			Animations.travel("turn")
			%Turning.play("turn_right")

	if is_kick_pressed():
		time_since_kick_pressed = 0
	time_since_kick_pressed += delta
	time_since_kick += delta
	if time_since_kick_pressed < KICK_TIME_ALLOW and time_since_kick > KICK_COOLDOWN:
		kick()

	if not on_floor:
		can_jump = true
	if is_up_pressed() and on_floor and can_jump:
		apply_central_impulse(Vector3(0, JUMP_POWER, 0))
		can_jump = false

func _integrate_forces(state: PhysicsDirectBodyState3D) -> void:
	var input_direction = get_left_right()
	linear_velocity.x = input_direction * MOVEMENT_SPEED
	# https://forum.godotengine.org/t/how-to-check-if-rigid-body-is-on-floor/65679/3
	var i := 0
	on_floor = false
	floor = null
	while i < state.get_contact_count():
		var normal := state.get_contact_local_normal(i)
		#  1.0 would be perfectly straight up
		#  0.0 is a wall
		# -1.0 is a ceiling
		if normal.dot(Vector3.UP) > 0.3: # this can be dialed in
			floor = state.get_contact_collider_object(i)
			on_floor = true
		i += 1
