class_name Ball
extends RigidBody3D
var on_floor: bool = false
var floor: Object
var movement_scale: float = 1.0
var new_movement_scale: float = 1.0
var time: float = 0.0
var time_acceleration: float = 1.0
signal create_fx(fx: PackedScene, pos: Vector3)

var speed_percent = 1.0

func set_speed_percent(p: float):
	linear_velocity = linear_velocity * (p / speed_percent)
	gravity_scale = p
	speed_percent = p

func _integrate_forces(state: PhysicsDirectBodyState3D) -> void:
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
		
	if on_floor and state.linear_velocity.y > 15.:
		create_fx.emit(FXManager.crush_slam, global_position + Vector3(0, -.6, 0))
		
	linear_velocity *= lerp(movement_scale,new_movement_scale,clamp(time,0.0,1.0))
	angular_velocity *= movement_scale

func _process(delta: float) -> void:
	time += delta * time_acceleration

func set_velocity_multiplier(new_speed: float, acceleration: float):
	time = 0
	time_acceleration = acceleration
	new_movement_scale = new_speed
