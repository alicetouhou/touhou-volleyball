extends Node3D

func _on_player_3d_create_fx(fx: PackedScene, pos: Vector3) -> void:
	%FxManager.create_at_pos(fx, pos)


func _on_player_3d_on_hit_ball() -> void:
	%FxManager.create_with_parent_3D(FXManager.pressure_ring, %Ball3d)
	%Camera3D.add_trauma(.1)


func _on_ball_3d_create_fx(fx: PackedScene, pos: Vector3) -> void:
	%FxManager.create_at_pos(fx, pos)
