class_name Player
extends RigidBody3D

## Triggered when a ball is successfull hit.
signal on_hit_ball
## Triggered when a super is successfully activated
signal super_used
## Triggered when the super ability's charge changes
signal super_charge_updated(value: float)
## Ask the game area to have a FX
signal create_fx(fx: PackedScene, pos: Vector3)

## Config values
const MOVEMENT_SPEED := 9.0
const FAST_FALL_MULT := 14.0
const JUMP_POWER := 10.0
const JUMP_COOLDOWN := 0.1

const SET_ANGLE := PI/3 # radians

const KICK_VELOCITY = 7.
const KICK_TIME_GRACE := .15
const KICK_COOLDOWN := .3

const SUPER_COOLDOWN = .2

## Super hitboxes
@onready var reimu_super_collider = $SuperColliders/ReimuSuper
@onready var marisa_super_collider = $SuperColliders/MarisaSuper

## Sound Effects
@onready var activate_super_sfx: AudioStreamPlayer = $SuperSFX/ActivateSuper
@onready var reimu_super_sfx: AudioStreamPlayer = $SuperSFX/ReimuSuper
@onready var sakuya_super_sfx: AudioStreamPlayer = $SuperSFX/SakuyaSuper
@onready var marisa_super_sfx: AudioStreamPlayer = $SuperSFX/MarisaSuper

## Player's character
@export var character: CharacterResource :
	set(value):
		character = value
		if value and has_node("%Sprite3D"):
			%Sprite3D.texture = value.texture

## VFX Scenes
const DUST_SETTLE_FX = preload("res://resources/effects/dust-settle.tscn")
const POMMEL_POP_FX = preload("res://resources/effects/pommel-pop.tscn")

var input_device: int = -99:
	set(v):
		%ActionSync.input_device = v
	get():
		return input_device
var player_id: int:
	set(value):
		player_id = value
		if value > 0:
			%ActionSync.set_multiplayer_authority(value)
		else:
			%ActionSync.disable_input = true
	get():
		return player_id
var side: int

var movement_scale = 1.
var velocity_multiplier: float = 1.0
var new_velocity_multiplier: float = 1.0
var time: float = 0.0
var time_acceleration: float = 1.0

# Horizontal movement sign
var direction := 1.0

var on_floor := false
var can_jump := true

var time_since_kick_pressed := 100.
var time_since_kick := 100.

var time_since_jump := 100.

var super_charge: float = 0:
	set(v):
		super_charge = clamp(v, 0, 3)
		super_charge_updated.emit(super_charge)
	get():
		return super_charge
var can_charge_super = true
var time_since_super = 0.

@onready var Animations = %AnimationTree.get("parameters/playback")

func find_ball_in_area(area: Area3D) -> Ball:
	var bodies = area.get_overlapping_bodies()
	var ball_index = bodies.find_custom(func(x): return x.is_in_group("ball"))
	if ball_index < 0:
		return
	var ball: Ball = bodies[ball_index]
	return ball
	
func find_ball():
	var bodies = %KickCollider.get_overlapping_bodies()
	var ball_index = bodies.find_custom(func(x): return x.is_in_group("ball"))
	if ball_index < 0:
		return
	var ball: RigidBody3D = bodies[ball_index]
	return ball

func kick(velocity = KICK_VELOCITY, ball: Ball = null):
	Animations.travel("kick_miss")
	%KickCollider.rotation.y = 90 - (90 * %ActionSync.direction.x)
	
	if !ball:
		ball = find_ball()
		if not ball:
			return

	Animations.travel("kick_hit")
	time_since_kick_pressed = 10000
	time_since_kick = 0

	on_hit_ball.emit()
	super_charge += ball.linear_velocity.length() / 75.

	var global_position_2D = Vector2(global_position.x, global_position.y)
	var ball_global_position_2D = Vector2(ball.global_position.x, ball.global_position.y)

	create_fx.emit(FXManager.pummel_pop, ball.position)

	var ball_direction = global_position_2D.direction_to(ball_global_position_2D)
	var force = velocity * (ball_direction)
	
	if %ActionSync.direction.y > 0.0 and acos(ball_direction.dot(Vector2.DOWN) <= SET_ANGLE):
		ball.linear_velocity = Vector3.ZERO
		ball.linear_velocity.y = velocity
	else:
		ball.linear_velocity = Vector3(force.x, force.y, 0.0) + linear_velocity
		if %ActionSync.direction.x != 0 and linear_velocity.x == 0:
			ball.linear_velocity.x += MOVEMENT_SPEED * %ActionSync.direction.x
	
	if %ActionSync.direction.y < 0.0:
		ball.linear_velocity *= 2

	ball.play_kick_sfx()
	
	super_charge += pow(ball.linear_velocity.x,2.) / 5625.

	return ball

# Used to disable input for CPUs and players on a different computer
func disable_input():
	%ActionSync.disable_input = true

@rpc("call_local")
func set_character(character_id: String) -> void:
	character = load("res://resources/characters/%s" % character_id)

## All clients simulate process, but server will sync later with authority.
func _physics_process(delta: float) -> void:
	# Super
	if %ActionSync.supering and time_since_super > SUPER_COOLDOWN:
		time_since_super = 0
		super_used.emit()

	# Jumping
	if %ActionSync.jumping and on_floor and time_since_jump >= JUMP_COOLDOWN:
		time_since_jump = 0
		apply_central_impulse(Vector3(0, JUMP_POWER, 0))
	
	# Fast falling
	if %ActionSync.direction.y < 0 and not on_floor:
		if linear_velocity.y > 0:
			linear_velocity.y = 0
		gravity_scale = 14
	else:
		gravity_scale = 1
	
	# Kicking
	if %ActionSync.kicking:
		time_since_kick_pressed = 0
	if time_since_kick_pressed < KICK_TIME_GRACE and time_since_kick > KICK_COOLDOWN:
		kick()

	time_since_kick_pressed += delta
	time_since_kick += delta
	time_since_super += delta
	time_since_jump += delta
	
	# State reset
	%ActionSync.supering = false
	%ActionSync.jumping = false
	%ActionSync.kicking = false
	
func _process(delta: float) -> void:
	time += delta * time_acceleration

func _integrate_forces(state: PhysicsDirectBodyState3D) -> void:
	if player_id == multiplayer.get_unique_id():
		linear_velocity.x = %ActionSync.local_direction.x * MOVEMENT_SPEED
	else:
		linear_velocity.x = %ActionSync.direction.x * MOVEMENT_SPEED
	
	if sign(linear_velocity).x != direction and not linear_velocity.is_zero_approx():
		direction = sign(linear_velocity).x

		if direction < 0.0:
			Animations.travel("turn")
			%Turning.play("turn_left")
		if direction > 0.0:
			Animations.travel("turn")
			%Turning.play("turn_right")
		
		create_fx.emit(FXManager.dust_settle, position - Vector3(0, .6, 0))
	
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
		
	linear_velocity *= lerp(velocity_multiplier,new_velocity_multiplier,clamp(time,0.0,1.0))
	angular_velocity *= lerp(velocity_multiplier,new_velocity_multiplier,clamp(time,0.0,1.0))

func set_velocity_multiplier(new_speed: float, acceleration: float):
	time = 0
	time_acceleration = acceleration
	new_velocity_multiplier = new_speed
