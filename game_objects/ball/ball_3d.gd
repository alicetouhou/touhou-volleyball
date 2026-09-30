class_name Ball3D

extends Node3D

signal create_fx(fx: PackedScene, pos: Vector3)

func _network_spawn(data):
	%Ball2D.sync_to_physics_engine()

func _process(_delta: float) -> void:
	position = Globals.map_pos2D_to_pos3D(get_viewport().get_camera_3d(), %Ball2D.display_position)
