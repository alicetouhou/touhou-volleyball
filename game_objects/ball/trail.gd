extends Line2D

var previous_position = Vector2.ZERO
var ball_radius: float = 0.0
var viewport_size: Vector2 = Vector2.ZERO

func _ready():
	var viewport_size = get_viewport_rect().size
	var ball_radius = SGFixed.to_float(%SGCollisionShape2D.fixed_scale_x)
	previous_position = %Ball2D.global_position
	
func _process(_delta: float) -> void:
	var current_position = %Ball2D.global_position
	var direction = (current_position - previous_position).normalized()
	
	add_point(current_position - ball_radius * direction)
	if points.size() > 30:
		remove_point(0)
	previous_position = current_position
