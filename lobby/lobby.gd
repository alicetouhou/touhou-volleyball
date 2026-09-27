extends Node


signal server_started
signal players_updated(player_dict)
signal server_failed
signal server_connected
signal connection_stopped
signal give_start_authority

const PORT = 34357
const IP_ADDRESS = "127.0.0.1"
const MAX_PLAYERS = 32
const DEFAULT_PLAYER = {"character": "alice_margatroid.tres"}
const COLORS = [Color.RED, Color.BLUE, Color.GREEN, Color.ORANGE]

var connected = false
var players: Dictionary[int, Dictionary] = {}

func host_game() -> Error:
	var server = ENetMultiplayerPeer.new()
	var err = server.create_server(PORT, MAX_PLAYERS)
	if not err:
		server_started.emit()
		multiplayer.peer_connected.connect(peer_connected)
		multiplayer.peer_disconnected.connect(peer_disconnected)
		peer_connected(1)
		connected = true
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
		connected = true
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
	
	connected = false
	
	connection_stopped.emit()
	multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
	players = {}

func peer_connected(id: int) -> void:
	if len(players) == 0:
		$DedicatedServerStart.set_multiplayer_authority(id)
		give_start_permission.rpc_id(id)
	players[id] = DEFAULT_PLAYER.duplicate()
	players[id]["number"] = len(players)
	players[id]["color"] = COLORS[wrap(len(players) - 1, 0, len(COLORS))]
	if id == 1:
		players[id]["character"] = (%Characters.selected.resource_path.split("/") as Array).back()
	on_players_updated.rpc(players)

func peer_disconnected(id: int) -> void:
	players.erase(id)
	on_players_updated.rpc(players)
	
	if len(players) == 0:
		%UI.hide()
		%LobbyOverlay.show()
		$Level.reset()

@rpc("any_peer", "call_local")
func set_player_character(resource_path: String) -> void:
	players[multiplayer.get_remote_sender_id()]["character"] = resource_path
	players_updated.emit(players)

@rpc("call_local")
func on_players_updated(new_player_dict: Dictionary) -> void:
	players = new_player_dict
	players_updated.emit(players)

@rpc("call_local")
func give_start_permission() -> void:
	give_start_authority.emit()

func start_game() -> void:
	if not multiplayer.is_server():
		return
	%UI.show()
	%LobbyOverlay.hide()
	$Level.start_game.rpc_id(1)

func _ready() -> void:
	if OS.has_feature("dedicated_server"):
		print("Starting dedicated server.")
		var server = ENetMultiplayerPeer.new()
		var err = server.create_server(PORT, MAX_PLAYERS)
		if not err:
			server_started.emit()
			multiplayer.peer_connected.connect(peer_connected)
			multiplayer.peer_disconnected.connect(peer_disconnected)
			connected = true
			print("Accepting connections.")
			multiplayer.multiplayer_peer = server
