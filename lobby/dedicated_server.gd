extends Node


signal start_game

@export var authority: int :
	set(value):
		authority = value
		set_multiplayer_authority(value)

func start_dedicated_game() -> void:
	server_start_game.rpc_id(1)

@rpc
func server_start_game() -> void:
	if OS.has_feature("dedicated_server") and multiplayer.is_server():
		start_game.emit()
