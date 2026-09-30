class_name Player3D

extends Node3D

## Triggered when a ball is successfull hit.
signal on_hit_ball
## Triggered when a super is successfully activated
signal super_used
## Triggered when the super ability's charge changes
signal super_charge_updated(value: float)
## Ask the game area to have a FX
signal create_fx(fx: PackedScene, pos: Vector3)

func _network_spawn(data):
	set_multiplayer_authority(data["player_id"])

	%Player2d.set_character(data["character"])
	%Player2d.player_id = data["player_id"]
	%Player2d.input_device = data["input_device"]

	%Player2d.fixed_position = data["fixed_position"]
	%Player2d.sync_to_physics_engine()

func _process(_delta: float) -> void:
	position = Globals.map_pos2D_to_pos3D(get_viewport().get_camera_3d(), %Player2d.display_position)
