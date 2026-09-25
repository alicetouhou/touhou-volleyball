extends Node3D


func _on_player_3d_create_fx(fx: PackedScene, pos: Vector3) -> void:
	%FxManager.create(fx, pos)


func _on_player_3d_on_hit_ball() -> void:
	%Ball3d.play_pressure_ring()
