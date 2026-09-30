class_name SyncedRigidBody

extends SGCharacterBody2D

@export var MASS: int = 65536

@onready var GRAVITY: SGFixedVector2 = SGFixed.vector2(0.0,Globals.GRAVITY)
@onready var DELTA = 2185


var _forces: Array[SGFixedVector2] = []
var _impulses: Array[SGFixedVector2] = []
var _angular_forces: Array[SGFixedVector2] = []

var linear_velocity: SGFixedVector2 = SGFixed.vector2(0,0)
var angular_velocity: SGFixedVector2

var display_position: Vector2 = Vector2.ZERO

func _ready() -> void:
	up_direction = SGFixed.vector2(0, -65536)

func _network_spawn(_data):
	sync_to_physics_engine()
	
func apply_force(force: SGFixedVector2, position: SGFixedVector2):
	if position.length() > 0:
		var torque = force.cross(position)
		var moi = MASS * SGFixed.pow(position.length(),2)
		var angular_velocity = SGFixed.div(torque,moi)
		_angular_forces.push_back(angular_velocity)
	_forces.push_back(force)

func apply_impulse(force: SGFixedVector2, position: SGFixedVector2):
	if position.length() > 0:
		var torque = force.cross(position)
		var moi = MASS * SGFixed.pow(position.length(),2)
		var angular_velocity = SGFixed.div(torque,moi)
		_angular_forces.push_back(angular_velocity)
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
func rk4(f: Callable,g: Callable,x0: int,y0: int,v0: int,x: int,n: int):	
	var h = SGFixed.div(DELTA,n * SGFixed.ONE)
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
	
func _integrate_forces():
	var integrated_forces: SGFixedVector2 = SGFixed.vector2(0,0)
	for force in _forces:
		linear_velocity.x += force.x
		linear_velocity.y += force.y
	
	var f_x = func(t: int, x: int, v: int):
		return v
	var f_xv = func(t: int, x: int, v: int):
		return integrated_forces.x
	var f_y = func(t: int, x: int, v: int):
		return v
	var f_yv = func(t: int, x: int, v: int):
		return integrated_forces.y
	var x_approximation = rk4(f_x,f_xv,0,0,linear_velocity.x,DELTA,5)
	var y_approximation = rk4(f_y,f_yv,0,0,linear_velocity.y,DELTA,5)
		
	# Clamp linear velocity to avoid ballooning to huge velocities
	linear_velocity.x = clamp(x_approximation,-1966080,1966080)
	linear_velocity.y = clamp(y_approximation,-1966080,1966080)
	
	for impulse in _impulses:
		linear_velocity.x += impulse.x
		linear_velocity.y += impulse.y
	_forces = []
	_impulses = []

func _network_process(_input):
	display_position.x = SGFixed.to_float(fixed_position.x)
	display_position.y = SGFixed.to_float(fixed_position.y)

	velocity.x = 0
	velocity.y = 0
	
	apply_central_force(GRAVITY)
	
	_integrate_forces()
	
	velocity.x += linear_velocity.x
	velocity.y += linear_velocity.y
	
	move_and_slide()
	
func _interpolate_state(old_state: Dictionary, new_state: Dictionary, weight: float) -> void:
	var sprite_pos_x: int = lerp(old_state["fixed_position_x"], new_state["fixed_position_x"], weight)
	var sprite_pos_y: int = lerp(old_state["fixed_position_y"], new_state["fixed_position_y"], weight)
	
	display_position.x = SGFixed.to_float(sprite_pos_x)
	display_position.y = SGFixed.to_float(sprite_pos_y)

func _save_state() -> Dictionary:
	return {
		fixed_position_x=fixed_position_x,
		fixed_position_y=fixed_position_y,
		fixed_rotation=fixed_rotation,
		velocity=velocity,
	}

func _load_state(state: Dictionary):
	fixed_position_x = state["fixed_position_x"]
	fixed_position_y = state["fixed_position_y"]
	fixed_rotation = state["fixed_rotation"]
	velocity = state["velocity"]

	sync_to_physics_engine()
