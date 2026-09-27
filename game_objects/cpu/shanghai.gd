extends RigidBody3D

var ball: RigidBody3D
var predictions = []
var time = 0
var patrol_point: Vector3

func cpu_init(world_ball: Node3D, _world_players: Array[Node]) -> void:
	ball = world_ball
	patrol_point = position
	
func _ready() -> void:
	gravity_scale = 0.0
	
func _physics_process(delta: float) -> void:
	predictions = predict_ball_locations(delta)
	time += delta
		
func _integrate_forces(state: PhysicsDirectBodyState3D) -> void:
	if len(predictions) == 0:
		return
	
	if position.distance_to(patrol_point) > 5.0:
		linear_velocity = Vector3(0.0,0.0,0.0)
		return
	
	linear_velocity = global_position.direction_to(Vector3(predictions[-1].x,min(predictions[-1].y,3.5),predictions[-1].z)) * 5.
	
	var bodies = $KickArea.get_overlapping_bodies()
	var ball_index = bodies.find_custom(func(x): return x.is_in_group("ball"))
	if ball_index < 0:
		return
	var ball: RigidBody3D = bodies[ball_index]	
	
	ball.linear_velocity = Vector3.ZERO
	ball.apply_impulse(Vector3(0.0,2.0,0.0))
	
func predict_ball_locations(delta: float) -> Array[Vector3]:
	var g = ball.gravity_scale * get_gravity()
	var p = ball.global_position
	var v = ball.linear_velocity
	var t = delta
	var predictions: Array[Vector3] = []
	for i in range(0,15):
		var new_pos = p + v * t + 0.5 * g * t * t
		
		if new_pos.x < -11.5:
			new_pos.x = -(new_pos.x + 11.5) - 11.5
		if new_pos.x > 11.5:
			new_pos.x = -(new_pos.x - 11.5) + 11.5
				
		predictions.push_back(new_pos)
		if new_pos.y > 1.5:
			t += delta
		else:
			return predictions
	return predictions
