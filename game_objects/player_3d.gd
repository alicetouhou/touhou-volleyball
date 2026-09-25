extends RigidBody3D

var direction = 1
const MOVEMENT_SPEED = 7
const JUMP_POWER = 7

const UP_KICK_POWER = Vector2()
const FORWARD_KICK_POWER = Vector2()
const DOWN_KICK_POWER = Vector2()
var on_floor: bool = false
var floor: Object

const KICK_TIME_ALLOW = .15
var time_since_kick_pressed = 1000

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
	
	var ball: RigidBody3D = bodies[ball_index]
	on_hit_ball.emit()
	
	var global_position_2D = Vector2(global_position.x, global_position.y)
	var ball_global_position_2D = Vector2(ball.global_position.x, ball.global_position.y)

	var ball_angle = global_position_2D.angle_to_point(ball_global_position_2D) + PI / 2
	
	while ball_angle < 0:
		ball_angle += PI
	while ball_angle > PI:
		ball_angle -= PI

	if ball_angle <= PI / 4:
		ball.apply_impulse(Vector3(5 * direction, 10, 0))
	elif ball_angle <= PI / 4 * 3:
		ball.apply_impulse(Vector3(12 * direction, -2, 0))
	elif ball_angle <= PI:
		ball.apply_impulse(Vector3(5 * direction, -10, 0))

func _ready() -> void:
	pass

func _physics_process(delta: float) -> void:
	var x = int(Input.is_action_pressed("right")) - int(Input.is_action_pressed("left"))

	apply_central_force(Vector3(x, 0, 0)  * MOVEMENT_SPEED)
	
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

	if Input.is_action_just_pressed("kick"):
		time_since_kick_pressed = 0
	time_since_kick_pressed += delta
	if time_since_kick_pressed < KICK_TIME_ALLOW:
		kick()

	if Input.is_action_just_pressed("up") and on_floor:
		apply_central_impulse(Vector3(0, JUMP_POWER, 0))

func _integrate_forces(state: PhysicsDirectBodyState3D) -> void:
	var input_direction = Input.get_vector("left", "right", "up", "down")
	linear_velocity.x = input_direction.x * MOVEMENT_SPEED
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
