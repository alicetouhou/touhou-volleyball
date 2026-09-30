extends Sprite2D

func _process(delta: float) -> void:
	position.x += 8 * (Input.get_action_strength("right") - Input.get_action_strength("left"))
