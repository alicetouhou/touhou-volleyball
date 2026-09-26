class_name Player
extends RigidBody3D

## Triggered when a ball is successfull hit.
signal on_hit_ball
## Triggered when a super is successfully activated
signal super_used
## Triggered when the super ability's charge changes
signal super_charge_updated(value: float)

## Config values
const MOVEMENT_SPEED := 9
const JUMP_POWER := 10

const KICK_TIME_GRACE := .15
const KICK_COOLDOWN := .3

const SUPER_COOLDOWN = .2

## Player's character
@export var character: CharacterResource

@export var player_id: int :
	set(value):
		player_id = value
		%ActionSync.set_multiplayer_authority(value)

## Horizontal movement sign
var direction := 1

var on_floor := false
var can_jump := true

var time_since_kick_pressed := 100.
var time_since_kick := 100.

var super_charge: float = 0:
	set(v):
		super_charge = clamp(v, 0, 3)
		super_charge_updated.emit(super_charge)
	get():
		return super_charge
var can_charge_super = true
var time_since_super = 0.

@onready var Animations = %AnimationTree.get("parameters/playback")

func find_ball():
	var bodies = %KickCollider.get_overlapping_bodies()
	var ball_index = bodies.find_custom(func(x): return x.is_in_group("ball"))
	if ball_index < 0:
		return
	var ball: RigidBody3D = bodies[ball_index]
	return ball

func kick(velocity = 7):
	Animations.travel("kick_miss")
	
	var ball = find_ball()
	if not ball:
		return


	Animations.travel("kick_hit")
	time_since_kick_pressed = 10000
	time_since_kick = 0
	
	on_hit_ball.emit()
	
	var global_position_2D = Vector2(global_position.x, global_position.y)
	var ball_global_position_2D = Vector2(ball.global_position.x, ball.global_position.y)

	var ball_direction = global_position_2D.direction_to(ball_global_position_2D)
	var force = Vector2(velocity, velocity) * (ball_direction)
	ball.linear_velocity = Vector3(force.x, force.y, 0) + linear_velocity
	
	super_charge += ball.linear_velocity.length() / 50.

	return ball

## All clients simulate process, but server will sync later with authority.
func _physics_process(delta: float) -> void:
	# Super
	if %ActionSync.supering and time_since_super > SUPER_COOLDOWN:
		time_since_super = 0
		super_used.emit()

	time_since_super += delta

	# Jumping
	if %ActionSync.jumping and on_floor:
		apply_central_impulse(Vector3(0, JUMP_POWER, 0))

	# Fast falling
	if %ActionSync.direction.y < 0 and not on_floor:
		gravity_scale = 7
	else:
		gravity_scale = 1
	
	# Kicking
	if %ActionSync.kicking:
		time_since_kick_pressed = 0
	if time_since_kick_pressed < KICK_TIME_GRACE and time_since_kick > KICK_COOLDOWN:
		kick()

	time_since_kick_pressed += delta
	time_since_kick += delta
	
	# State reset
	%ActionSync.supering = false
	%ActionSync.jumping = false
	%ActionSync.kicking = false

func _integrate_forces(state: PhysicsDirectBodyState3D) -> void:
	linear_velocity.x = %ActionSync.direction.x * MOVEMENT_SPEED
	
	if sign(linear_velocity).x != direction and not linear_velocity.is_zero_approx():
		direction = sign(linear_velocity).x

		if direction < 0:
			Animations.travel("turn")
			%Turning.play("turn_left")
		if direction > 0:
			Animations.travel("turn")
			%Turning.play("turn_right")
	
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
