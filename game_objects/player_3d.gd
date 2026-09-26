class_name Player

extends RigidBody3D

@export var player_device = 16
@export var character: CharacterResource
@export var ball: RigidBody3D

var direction = 1
const MOVEMENT_SPEED = 9
const JUMP_POWER = 10

const UP_KICK_POWER = Vector2()
const FORWARD_KICK_POWER = Vector2()
const DOWN_KICK_POWER = Vector2()

var on_floor: bool = false
var floor: Object

const KICK_TIME_ALLOW = .15
var KICK_COOLDOWN = .3
var time_since_kick_pressed = 100
var time_since_kick = 100
var can_jump = true
var can_move = true
const SUPER_COOLDOWN = .2
var time_since_super = 0.

var super_charge: float = 0:
	set(v):
		super_charge = clamp(v, 0, 3)
		super_charge_updated.emit(super_charge)
	get():
		return super_charge

signal create_fx(fx: PackedScene, pos: Vector3)
signal on_hit_ball
signal super_used
signal super_charge_updated(value: float)

var can_charge_super = true
var last_ball_position = 0


@onready var Animations = %AnimationTree.get("parameters/playback")

func find_ball():
	var bodies = %KickHitbox.get_overlapping_bodies()
	var ball_index = bodies.find_custom(func(x): return x.is_in_group("ball"))
	if ball_index < 0:
		return
	var ball: RigidBody3D = bodies[ball_index]
	return ball

func kick(velocity = 7):
	Animations.travel("kick_miss")


	Animations.travel("kick_hit")
	time_since_kick_pressed = 10000
	time_since_kick = 0
	
	on_hit_ball.emit()
	create_fx.emit(FXManager.pummel_pop, (ball.global_position + global_position) / 2)
	create_fx.emit(FXManager.spark_spit, (ball.global_position + global_position) / 2)
	
	var global_position_2D = Vector2(global_position.x, global_position.y)
	var ball_global_position_2D = Vector2(ball.global_position.x, ball.global_position.y)

	var ball_direction = global_position_2D.direction_to(ball_global_position_2D)
	var force = Vector2(velocity, velocity) * (ball_direction)
	ball.linear_velocity = Vector3(force.x, force.y, 0) + linear_velocity
	
	if can_charge_super:
		super_charge += ball.linear_velocity.length() / 50.
		can_charge_super = false

	return ball

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

func is_super_pressed():
	if player_device == 16:
		return Input.is_action_just_pressed("super")
	return Input.is_joy_button_pressed(player_device, JOY_BUTTON_Y)

func _ready() -> void:
	%Sprite3D.texture = character.texture

func _physics_process(delta: float) -> void:
	if is_super_pressed() and time_since_super > SUPER_COOLDOWN:
		time_since_super = 0
		super_used.emit()
	time_since_super += delta
	
	if !can_move:
		return
	
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
	if not is_up_pressed():
		can_jump = true
	if is_up_pressed() and on_floor and can_jump:
		apply_central_impulse(Vector3(0, JUMP_POWER, 0))
		can_jump = false
	# Fast falling
	if is_down_pressed() and not on_floor:
		gravity_scale = 7
	if on_floor:
		gravity_scale = 1

	if is_super_pressed() and time_since_super > SUPER_COOLDOWN:
		time_since_super = 0
		super_used.emit()
	time_since_super += delta

	if sign(ball.position.x) != last_ball_position:
		last_ball_position = sign(ball.position.x)
		can_charge_super = true

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
