class_name SyncedRigidBody

extends SGCharacterBody2D

@export var MASS: int = 65536
@export_range(0,65536) var BOUNCINESS: int = 65536
@export_range(0,65536) var LINEAR_DAMPING: int = 655
@export var BOUNCE_THRESHOLD: int = 150000

@onready var GRAVITY: SGFixedVector2 = SGFixed.vector2(0,Globals.GRAVITY)
@onready var DELTA = 2185


var _forces: Array[SGFixedVector2] = []
var _impulses: Array[SGFixedVector2] = []
var _angular_forces: Array[SGFixedVector2] = []

var _integrated_forces: SGFixedVector2 = SGFixed.vector2(0,0)

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
func rk4(f: Callable,g: Callable,x0: int,y0: int,v0: int,x: int,n: int) -> int:	
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
	
func f_x(t: int, x: int, v: int):
	return v
func f_xv(t: int, x: int, v: int):
	return _integrated_forces.x
func f_y(t: int, x: int, v: int):
	return v
func f_yv(t: int, x: int, v: int):
	return _integrated_forces.y
	
func _integrate_forces():
	for force in _forces:
		_integrated_forces.x += force.x
		_integrated_forces.y += force.y

	#Discrete integral approximation to get new velocity
	var x_approximation = rk4(f_x,f_xv,0,0,linear_velocity.x+_integrated_forces.x,DELTA,1)
	var y_approximation = rk4(f_y,f_yv,0,0,linear_velocity.y+_integrated_forces.y,DELTA,1)
	
	#Bouncing
	if BOUNCINESS > 0 and is_on_floor():
		var d = SGFixed.mul(SGFixed.TWO,SGFixed.vector2(x_approximation,y_approximation).dot(up_direction))
		x_approximation -= SGFixed.mul(SGFixed.mul(d,up_direction.x),BOUNCINESS)
		y_approximation -= SGFixed.mul(SGFixed.mul(d,up_direction.y),BOUNCINESS)
		if abs(y_approximation)<BOUNCE_THRESHOLD:
			y_approximation = 0
	# If on floor and not a bouncy object, remove gravity before adding impulses
	elif is_on_floor():
		y_approximation = 0
		
	#Add impulses now, after integration
	for impulse in _impulses:
		x_approximation += impulse.x
		y_approximation += impulse.y
		
	# Clamp linear velocity to avoid ballooning to huge velocities
	linear_velocity.x = clamp(SGFixed.mul(x_approximation,SGFixed.ONE-LINEAR_DAMPING),-1966080,1966080)
	linear_velocity.y = clamp(SGFixed.mul(y_approximation,SGFixed.ONE-LINEAR_DAMPING),-1966080,1966080)

	_forces = []
	_impulses = []
	
	_integrated_forces = SGFixed.vector2(0,0)

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
		velocity_x=velocity.x,
		velocity_y=velocity.y,
	}

func _load_state(state: Dictionary):
	fixed_position_x = state["fixed_position_x"]
	fixed_position_y = state["fixed_position_y"]
	fixed_rotation = state["fixed_rotation"]
	velocity = SGFixed.vector2(state["velocity_x"], state["velocity_y"])

	# sync_to_physics_engine()
