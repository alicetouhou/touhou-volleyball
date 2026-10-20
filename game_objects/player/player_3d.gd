class_name Player3D

extends Node3D

## Show the cool particles on the ball!
signal request_create_ball_hit_visual
signal request_create_dust_trail(direction: int)

@onready var Animations = %AnimationTree.get("parameters/playback")

var player_2d = null
var cpu_player = false

func _network_spawn(data):
	if data["cpu_player"] == true:
		player_2d = %CPUPlayer2D.create_instance()
	else:
		player_2d = %Player2d.create_instance()
	
	player_2d.set_character(data["character"])
	player_2d.player_id = data["player_id"]
	player_2d.input_device = data["input_device"]
	player_2d.fixed_position_x = data["fixed_position_x"]
	player_2d.fixed_position_y = data["fixed_position_y"]
	player_2d.sync_to_physics_engine()

func _process(_delta: float) -> void:
	position = Globals.map_pos2D_to_pos3D(get_viewport().get_camera_3d(), player_2d.display_position)

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
