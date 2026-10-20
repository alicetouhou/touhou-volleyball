extends Sprite3D

func _process(delta: float) -> void:
	position.x += .08 * (Input.get_action_strength("right") - Input.get_action_strength("left"))
