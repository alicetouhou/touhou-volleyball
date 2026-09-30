class_name Player3D

extends Node3D

## Triggered when the super ability's charge changes
signal super_charge_updated(value: float)

## Show the cool particles on the ball!
signal request_create_ball_hit_visual
signal request_create_dust_trail(direction: int)

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

func _on_player_2d_kick(successful: bool) -> void:
	if successful:
		Animations.travel("kick_hit")
		request_create_ball_hit_visual.emit()
	else:
		Animations.travel("kick_miss")

func _on_player_2d_turn(direction: int) -> void:
	if direction == -1 and %Turning.current_animation != "turn_left":
		%Turning.play("turn_left")
		request_create_dust_trail.emit(direction)
	if direction == 1 and %Turning.current_animation != "turn_right":
		%Turning.play("turn_right")
		request_create_dust_trail.emit(direction)
