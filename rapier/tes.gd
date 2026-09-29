extends Node3D


@onready var manager: StateManager3D = $StateManager3D

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	var space := get_viewport().world_3d.space
	
	print(manager.export_state(space, "RustBincode"))
