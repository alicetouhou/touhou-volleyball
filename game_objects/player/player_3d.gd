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
const JUMP_POWER := 10.0
const JUMP_COOLDOWN := 5

const SET_ANGLE := PI/4 # radians

const KICK_TICKS_GRACE := 15
const KICK_COOLDOWN := 3

const SUPER_COOLDOWN = 2

## Super hitboxes
@onready var reimu_super_collider = $SuperColliders/ReimuSuper
@onready var marisa_super_collider = $SuperColliders/MarisaSuper

## Player's character
@export var character: CharacterResource :
	set(value):
		character = value
		if value and has_node("%Sprite3D"):
			%Sprite3D.texture = value.texture

## Input
var joy_direction = Vector2.ZERO
var kicking := false
var jumping := false
var supering := false
var ticks := 0

## VFX Scenes
const DUST_SETTLE_FX = preload("res://resources/effects/dust-settle.tscn")
const POMMEL_POP_FX = preload("res://resources/effects/pommel-pop.tscn")

var movement_scale = 1.
var input_device: int = -99:
	set(v):
		input_device = v
	get():
		return input_device

var player_id: int

# Horizontal movement sign
var direction := 1.0

var on_floor := false
var can_jump := true

var ticks_since_kick_pressed := 100
var ticks_since_kick := 100

var ticks_since_jump := 100

var super_charge: float = 0:
	set(v):
		super_charge = clamp(v, 0, 3)
		super_charge_updated.emit(super_charge)
	get():
		return super_charge
var can_charge_super = true
var ticks_since_super = 0.

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

func kick(velocity = 7, ball: Ball = null):
	Animations.travel("kick_miss")
	
	if !ball:
		ball = find_ball()
		if not ball:
			return

	Animations.travel("kick_hit")
	ticks_since_kick_pressed = 10000
	ticks_since_kick = 0

	on_hit_ball.emit()
	super_charge += ball.linear_velocity.length() / 75.

	var global_position_2D = Vector2(global_position.x, global_position.y)
	var ball_global_position_2D = Vector2(ball.global_position.x, ball.global_position.y)

	create_fx.emit(FXManager.pummel_pop, ball.position)

	var ball_direction = global_position_2D.direction_to(ball_global_position_2D)
	var force = velocity * (ball_direction)
	
	if joy_direction.y > 0.0 and acos(ball_direction.dot(Vector2.DOWN) <= SET_ANGLE):
		ball.linear_velocity = Vector3.ZERO
		ball.linear_velocity.y = velocity
	else:
		ball.linear_velocity = Vector3(force.x, force.y, 0.0) + linear_velocity
	
	if joy_direction.y < 0.0:
		ball.linear_velocity *= 2

	ball.play_kick_sfx()
	
	super_charge += pow(ball.linear_velocity.x,2.) / 5625.

	return ball

# Used to disable input for CPUs and players on a different computer
func disable_input():
	pass

func set_character(character_id: String) -> void:
	character = load("res://resources/characters/%s" % character_id)

# Only runs on client, disabled_input is set when player is created.
# The `Input` class does not allow you to check if an input was performed by a specific
# device so we need to use the _input method :(
func _input(event: InputEvent) -> void:
	if not is_multiplayer_authority():
		return
	if input_device > -99 and event.device != input_device:
		return

	if event.is_action_pressed("left") or event.is_action_released("left"):
		joy_direction.x = -event.get_action_strength("left") + event.get_action_strength("right")
	if event.is_action_pressed("right") or event.is_action_released("right"):
		joy_direction.x =  -event.get_action_strength("left") + event.get_action_strength("right")
	if event.is_action_pressed("up") or event.is_action_released("up"):
		joy_direction.y = event.get_action_strength("up") - event.get_action_strength("down")
	if event.is_action_pressed("down") or event.is_action_released("down"):
		joy_direction.y = event.get_action_strength("up") - event.get_action_strength("down")

	if event.is_action_pressed("up"):
		jumping = true
	if event.is_action_pressed("kick"):
		kicking = true
	if event.is_action_pressed("super"):
		supering = true
	if event.is_action_released("up"):
		jumping = false
	if event.is_action_released("kick"):
		kicking = false
	if event.is_action_released("super"):
		supering = false

func _get_local_input() -> Dictionary:
	return {
		joy_direction=joy_direction,
		jumping=jumping,
		kicking=kicking,
		supering=supering,
	}

func _predict_remote_input(previous_input: Dictionary, _ticks_since_real_input: int) -> Dictionary:
	return previous_input

func _network_process(input: Dictionary) -> void:
	ticks += 1
	var joy_direction = input.get("joy_direction", Vector2.ZERO)
	var jumping = input.get("jumping", false)
	var kicking = input.get("kicking", false)
	var supering = input.get("supering", false)

	# Super
	if supering and ticks_since_super > SUPER_COOLDOWN:
		ticks_since_super = 0
		super_used.emit()

	# Moving
	linear_velocity.x = joy_direction.x * MOVEMENT_SPEED

	# Jumping
	if jumping and on_floor and ticks_since_jump >= JUMP_COOLDOWN:
		ticks_since_jump = 0
		apply_central_impulse(Vector3(0, JUMP_POWER, 0))

	# Fast falling
	if joy_direction.y < 0 and not on_floor:
		if linear_velocity.y > 0:
			linear_velocity.y = 0
		gravity_scale = 14
	else:
		gravity_scale = 1
	
	# Kicking
	if kicking:
		ticks_since_kick_pressed = 0
	if ticks_since_kick_pressed < KICK_TICKS_GRACE and ticks_since_kick > KICK_COOLDOWN:
		kick()

	ticks_since_kick_pressed += 1
	ticks_since_kick += 1
	ticks_since_super += 1
	ticks_since_jump += 1

func _integrate_forces(state: PhysicsDirectBodyState3D) -> void:
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

func set_velocity_multiplier(new_speed: float, acceleration: float):
	pass

func _save_state() -> Dictionary:
	return {
		position=position,
		rotation=rotation,
		linear_velocity=linear_velocity,
		angular_velocity=angular_velocity,
		ticks=ticks,
	}

func _load_state(state: Dictionary):
	position = state["position"]
	rotation = state["rotation"]
	linear_velocity = state["linear_velocity"]
	angular_velocity = state["angular_velocity"]
	ticks = state["ticks"]
