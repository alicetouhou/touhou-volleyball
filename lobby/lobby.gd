extends Node


signal server_started
signal players_updated(player_dict)
signal server_failed
signal server_connected
signal connection_stopped

const PORT = 7000
const IP_ADDRESS = "127.0.0.1"
const MAX_PLAYERS = 4
const DEFAULT_PLAYER = {}

var players: Dictionary[int, Dictionary] = {}

func host_game() -> Error:
	var server = ENetMultiplayerPeer.new()
	var err = server.create_server(PORT, MAX_PLAYERS)
	if not err:
		server_started.emit()
		multiplayer.peer_connected.connect(peer_connected)
		multiplayer.peer_disconnected.connect(peer_disconnected)
		peer_connected(1)
		multiplayer.multiplayer_peer = server
	return err

func join_game() -> Error:
	var target_ip = %IP.text

	if target_ip.is_empty():
		return Error.ERR_CANT_RESOLVE
	
	var client = ENetMultiplayerPeer.new()
	multiplayer.connected_to_server.connect(server_connected.emit)
	multiplayer.connection_failed.connect(server_failed.emit)
	multiplayer.server_disconnected.connect(stop_connection)
	
	var err = client.create_client(target_ip, PORT)
	if not err:
		multiplayer.multiplayer_peer = client
	return err

func stop_connection() -> void:
	# Test signal connections as multiplayer.is_server may be invalid by now.
	if multiplayer.peer_connected.is_connected(peer_connected):
		multiplayer.peer_connected.disconnect(peer_connected)
		multiplayer.peer_disconnected.disconnect(peer_disconnected)
	elif multiplayer.connected_to_server.is_connected(server_connected.emit):
		multiplayer.connected_to_server.disconnect(server_connected.emit)
		multiplayer.connection_failed.disconnect(server_failed.emit)
		multiplayer.server_disconnected.disconnect(stop_connection)
	connection_stopped.emit()
	multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
	players = {}

func peer_connected(id: int) -> void:
	players[id] = DEFAULT_PLAYER.duplicate()
	on_players_updated.rpc(players)

func peer_disconnected(id: int) -> void:
	players.erase(id)
	on_players_updated.rpc(players)

@rpc("call_local")
func on_players_updated(new_player_dict: Dictionary) -> void:
	players = new_player_dict
	players_updated.emit(players)

func start_game() -> void:
	$Level.start_game.rpc()
