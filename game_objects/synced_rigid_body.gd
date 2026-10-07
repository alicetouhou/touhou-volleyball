class_name SyncedRigidBody

extends SGCharacterBody2D

@export var MASS: int = 65536
@export_range(0,65536) var BOUNCINESS: int = 65536
@export_range(0,65536) var LINEAR_DAMPING: int = 655
@export_range(0,65536) var ANGULAR_DAMPING: int = 655
@export var GRAVITY_SCALE: int = 65536

@onready var GRAVITY: SGFixedVector2 = SGFixed.vector2(0,Globals.GRAVITY)
@onready var DELTA = 2185


var _forces: Array[SGFixedVector2] = []
var _impulses: Array[SGFixedVector2] = []
var _angular_impulses: Array[int] = []

var _integrated_forces: SGFixedVector2 = SGFixed.vector2(0,0)

var SYNCED_is_on_floor_USE_THIS_ONE := false

var linear_velocity: SGFixedVector2 = SGFixed.vector2(0,0)
var SYNCED_angular_velocity: = 0

var display_position: Vector2 = Vector2.ZERO
var display_rotation = 0

func _ready() -> void:
	up_direction = SGFixed.vector2(0, -65536)

func _network_spawn(_data):
	sync_to_physics_engine()
	
func apply_force(force: SGFixedVector2, _position: SGFixedVector2):
	_forces.push_back(force)
	
func apply_angular_impulse(force: SGFixedVector2, force_position: SGFixedVector2):
	var moi = SGFixed.mul(MASS,SGFixed.pow(force_position.length(),2))
	if moi < 100:
		return
	var torque = SGFixed.mul(force_position.y,force.x) - SGFixed.mul(force_position.x,force.y)
	var angular_acceleration = SGFixed.div(torque,moi)
	_angular_impulses.push_back(angular_acceleration)

func apply_impulse(force: SGFixedVector2, force_position: SGFixedVector2):
	if fixed_position.length() > 0:
		apply_angular_impulse(force,force_position)
	_impulses.push_back(force)
	
func apply_central_force(force: SGFixedVector2):
	apply_force(force, SGFixed.vector2(0,0))
	
func apply_central_impulse(force: SGFixedVector2):
	apply_impulse(force, SGFixed.vector2(0,0))
	
# f - derivative of position
# g - derivative of velocity
# x0 - initial x (time)
# y0 - initial position
# v0 - initial velocity
# x - target x (time)
# n - iteration number
func rk4(f: Callable,g: Callable,x0: int,y0: int,v0: int,_x: int,n: int) -> int:
	var h: int = SGFixed.div(DELTA,n * SGFixed.ONE)
	var y = y0
	var v = v0
	for i in range(0,n):
		# Apply runge kutta
		var k1_x = SGFixed.mul(h,f.call(x0,y,v))
		var k1_v = SGFixed.mul(h,g.call(x0,y,v))
		var k2_x = SGFixed.mul(h,f.call(x0+SGFixed.mul(SGFixed.HALF,h),y+SGFixed.mul(SGFixed.HALF,k1_x),v+SGFixed.mul(SGFixed.HALF,k1_v)))
		var k2_v = SGFixed.mul(h,g.call(x0+SGFixed.mul(SGFixed.HALF,h),y+SGFixed.mul(SGFixed.HALF,k1_x),v+SGFixed.mul(SGFixed.HALF,k1_v)))
		var k3_x = SGFixed.mul(h,f.call(x0+SGFixed.mul(SGFixed.HALF,h),y+SGFixed.mul(SGFixed.HALF,k2_x),v+SGFixed.mul(SGFixed.HALF,k2_v)))
		var k3_v = SGFixed.mul(h,g.call(x0+SGFixed.mul(SGFixed.HALF,h),y+SGFixed.mul(SGFixed.HALF,k2_x),v+SGFixed.mul(SGFixed.HALF,k2_v)))
		var k4_x = SGFixed.mul(h,f.call(x0+h,y+k3_x,v+k3_v))
		var k4_v = SGFixed.mul(h,g.call(x0+h,y+k3_x,v+k3_v))
		
		# update next value of y
		y += SGFixed.mul(10923,k1_x + SGFixed.mul(SGFixed.TWO, k2_x) + SGFixed.mul(SGFixed.TWO, k3_x) + k4_x)
		v += SGFixed.mul(10923,k1_v + SGFixed.mul(SGFixed.TWO, k2_v) + SGFixed.mul(SGFixed.TWO, k3_v) + k4_v)
		# update next value of x
		x0 += h
	return v
	
func f_x(_t: int, _x: int, v: int) -> int:
	return v
func f_xv(_t: int, _x: int, _v: int) -> int:
	return _integrated_forces.x
func f_y(_t: int, _x: int, v: int) -> int:
	return v
func f_yv(_t: int, _x: int, _v: int) -> int:
	return _integrated_forces.y
	
func _integrate_forces():
	_integrated_forces = SGFixed.vector2(0,0)

	for force in _forces:
		_integrated_forces.x += force.x
		_integrated_forces.y += force.y

	#Discrete integral approximation to get new velocity
	var x_approximation: int = rk4(f_x,f_xv,0,0,linear_velocity.x+_integrated_forces.x,DELTA,1)
	var y_approximation: int = rk4(f_y,f_yv,0,0,linear_velocity.y+_integrated_forces.y,DELTA,1)

	#Add impulses now, after integration
	for impulse in _impulses:
		x_approximation += impulse.x
		y_approximation += impulse.y

	var SYNCED_angular_velocity_sum = 0
	for impulse in _angular_impulses:
		SYNCED_angular_velocity_sum += impulse
	SYNCED_angular_velocity = clamp(SYNCED_angular_velocity + SYNCED_angular_velocity_sum - SGFixed.mul(SYNCED_angular_velocity + SYNCED_angular_velocity_sum,ANGULAR_DAMPING),-1966080,1966080)

	# Clamp linear velocity to avoid ballooning to huge velocities
	linear_velocity.x = clamp(x_approximation - SGFixed.mul(x_approximation,LINEAR_DAMPING),-1966080,1966080)
	linear_velocity.y = clamp(y_approximation - SGFixed.mul(y_approximation,LINEAR_DAMPING),-1966080,1966080)

func _collide(prev_velocity: SGFixedVector2):
	var force = SGFixed.vector2(0,0)
		
	SYNCED_is_on_floor_USE_THIS_ONE = false
	for c_id in get_slide_count():
		var c: SGKinematicCollision2D = get_slide_collision(c_id)
		var dot_c = prev_velocity.dot(c.normal)
		var UP = SGFixed.vector2(0,SGFixed.ONE)
		var c_up = c.normal.dot(UP)
		var body_up = prev_velocity.normalized().dot(UP)
				
		if c_up <= SGFixed.HALF*-1 and body_up >= SGFixed.HALF:
			SYNCED_is_on_floor_USE_THIS_ONE = true
		
		var d = SGFixed.mul(SGFixed.ONE + BOUNCINESS,dot_c)
		var x_force = SGFixed.mul(d,c.normal.x)
		var y_force = SGFixed.mul(d,c.normal.y)
		force.x += x_force
		force.y += y_force

	return SGFixed.vector2(prev_velocity.x - force.x,prev_velocity.y - force.y)

func _network_preprocess(_input):
	sync_to_physics_engine()

	_forces = []
	_impulses = []
	_angular_impulses = []
	_integrated_forces = SGFixed.vector2(0,0)

func _network_postprocess(_input):
	display_position.x = SGFixed.to_float(fixed_position.x)
	display_position.y = SGFixed.to_float(fixed_position.y)

	velocity.x = 0
	velocity.y = 0

	apply_central_force(SGFixed.vector2(SGFixed.mul(GRAVITY.x,GRAVITY_SCALE),SGFixed.mul(GRAVITY.y,GRAVITY_SCALE)))

	_integrate_forces()
	
	velocity.x += linear_velocity.x
	velocity.y += linear_velocity.y

	fixed_rotation += SGFixed.mul(SYNCED_angular_velocity,DELTA)
	display_rotation = SGFixed.to_float(fixed_rotation)

	move_and_slide()
	linear_velocity = _collide(SGFixed.vector2(linear_velocity.x, linear_velocity.y))
	
	sync_to_physics_engine()

	_integrated_forces = SGFixed.vector2(0,0)
	_forces = []
	_impulses = []
	_angular_impulses = []

func _interpolate_state(old_state: Dictionary, new_state: Dictionary, weight: float) -> void:
	var sprite_pos_x: int = lerp(old_state["fixed_position_x"], new_state["fixed_position_x"], weight)
	var sprite_pos_y: int = lerp(old_state["fixed_position_y"], new_state["fixed_position_y"], weight)

	display_position.x = SGFixed.to_float(sprite_pos_x)
	display_position.y = SGFixed.to_float(sprite_pos_y)

func fixed_vec_arr_to_vec_i_arr(vecs: Array[SGFixedVector2]) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for vec in vecs:
		out.push_back(Vector2i(vec.x, vec.y))
	return out

func vec_i_arr_to_fixed_vec_arr(vecs: Array[Vector2i]) -> Array[SGFixedVector2]:
	var out: Array[SGFixedVector2] = []
	for vec in vecs:
		out.push_back(SGFixed.vector2(vec.x, vec.y))
	return out

func _save_state() -> Dictionary:
	return {
		fixed_position_x=fixed_position_x,
		fixed_position_y=fixed_position_y,
		fixed_rotation=fixed_rotation,
		SYNCED_linear_velocity_x=linear_velocity.x,
		SYNCED_linear_velocity_y=linear_velocity.y,
		velocity_x=velocity.x,
		velocity_y=velocity.y,
		SYNCED_angular_velocity=SYNCED_angular_velocity,
		SYNCED_is_on_floor_USE_THIS_ONE=SYNCED_is_on_floor_USE_THIS_ONE,
	}

func _load_state(state: Dictionary):
	fixed_position_x = state["fixed_position_x"]
	fixed_position_y = state["fixed_position_y"]
	fixed_rotation = state["fixed_rotation"]
	linear_velocity.x = state["SYNCED_linear_velocity_x"]
	linear_velocity.y = state["SYNCED_linear_velocity_y"]
	velocity.x = state["velocity_x"]
	velocity.y = state["velocity_y"]
	SYNCED_angular_velocity = state["SYNCED_angular_velocity"]
	SYNCED_is_on_floor_USE_THIS_ONE = state["SYNCED_is_on_floor_USE_THIS_ONE"]

	sync_to_physics_engine()
