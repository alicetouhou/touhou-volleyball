extends TextureRect


func set_puck(color: Color, player: int) -> void:
	modulate = color
	$Label.text = "P%s" % player
