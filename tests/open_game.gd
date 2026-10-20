## Start both instances of the game, and connect them if two are opened.

extends Node2D

var lobby

func _ready() -> void:
	lobby = $Lobby.create_instance()
	
	var index = Globals.get_game_instance_id()

	if index == 0:
		host_game()
	if index == 1:
		join_game()

func host_game():
	await get_tree().create_timer(.1).timeout
	lobby.host_game()
	await get_tree().create_timer(.2).timeout
	lobby.start_game()

func join_game():
	await get_tree().create_timer(.2).timeout
	lobby.join_game()
