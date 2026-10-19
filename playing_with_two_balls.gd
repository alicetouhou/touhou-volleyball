extends Node2D

var time_for_frame = 10
var t = 0


func _ready() -> void:
	var impulse = SGFixed.vector2(SGFixed.ONE * 10, -SGFixed.ONE * 10)
	%VisualBall.apply_central_impulse(impulse)
	%TargetBall.apply_central_impulse(impulse)
	
func _process(delta: float) -> void:
	t += 1
	if t != time_for_frame:
		return
	t = 0
	%VisualBall._network_process()
	%TargetBall._network_process()

	var distance_to_target_ball_x = %TargetBall.fixed_position.x - %VisualBall.fixed_position.x
	var distance_to_target_ball_y = %TargetBall.fixed_position.y - %VisualBall.fixed_position.y
	var distance_to_target_ball = SGFixed.vector2(distance_to_target_ball_x, distance_to_target_ball_y).length()

	var d_squared = SGFixed.pow(distance_to_target_ball, 2)
	var G = SGFixed.HALF
	var f_g = SGFixed.div(G, d_squared)

	var gravity_direction = SGFixed.vector2(distance_to_target_ball_x, distance_to_target_ball_y).normalized()


	%VisualBall.apply_central_force(SGFixed.vector2(
		gravity_direction.x * f_g,
		gravity_direction.y * f_g,
	))
