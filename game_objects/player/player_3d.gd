class_name Player3D

extends RigidBody3D

## Triggered when a ball is successfull hit.
signal on_hit_ball
## Triggered when a super is successfully activated
signal super_used
## Triggered when the super ability's charge changes
signal super_charge_updated(value: float)
## Ask the game area to have a FX
signal create_fx(fx: PackedScene, pos: Vector3)

func set_character(character_id: String) -> void:
	%Player2d.set_character(character_id)

func set_player_id(id):
	set_multiplayer_authority(id)
	%Player2d.player_id = id

func set_input_device(device):
	%Player2d.input_device = device

func set_physics_position(p):
	%Player2d.fixed_position = p

func _on_player_2d_position_changed(pos: Vector2) -> void:
	var camera = get_viewport().get_camera_3d()
	var position_xy = camera.project_position(pos, camera.position.z)
	position = Vector3(position_xy.x, position_xy.y, 0)
