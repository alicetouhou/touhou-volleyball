extends Control

var p1device = -2
var p2device = -2

func _input(event: InputEvent) -> void:
	if p1device < -1:
		p1device = event.device
	elif p2device < -1:
		p2device = event.device
