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

@onready var Animations = %AnimationTree.get("parameters/playback")

func _network_spawn(data):
	%Player2d.set_character(data["character"])
	%Player2d.player_id = data["player_id"]
	%Player2d.input_device = data["input_device"]
	%Player2d.fixed_position_x = data["fixed_position_x"]
	%Player2d.fixed_position_y = data["fixed_position_y"]
	%Player2d.sync_to_physics_engine()

func _process(_delta: float) -> void:
	position = Globals.map_pos2D_to_pos3D(get_viewport().get_camera_3d(), %Player2d.display_position)


func _on_player_2d_play_kick_animation(hit) -> void:
	if hit:
		Animations.travel("kick_hit")
	else:
		Animations.travel("kick_miss")
