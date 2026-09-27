extends Node


signal server_started
signal players_updated(players)
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
var players: Array[PlayerPeer]

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

# Local Games are a hosted game with two controllers connected
func local_game() -> Error:
	var server = ENetMultiplayerPeer.new()
	var err = server.create_server(PORT, MAX_PLAYERS)
	if not err:
		server_started.emit()
		multiplayer.peer_connected.connect(peer_connected)
		multiplayer.peer_disconnected.connect(peer_disconnected)
		connected = true
		multiplayer.multiplayer_peer = server

		peer_connected(1, 16)
		peer_connected(2, 0)

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
	players = []

func peer_connected(id: int, input_device: int = -99) -> PlayerPeer:
	if OS.has_feature("dedicated_server") and len(players) == 0:
		$DedicatedServerStart.set_multiplayer_authority(id)
		give_start_permission.rpc_id(id)

	var p = PlayerPeer.new_player(id)
	p.number = len(players) + 1
	p.color = COLORS[len(players)]
	p.input_device = input_device
	if input_device != -99:
		p.local_co_op = true

	if id == 1:
		p.character = (%Characters.selected.resource_path.split("/") as Array).back()
	players.push_back(p)
	on_players_updated.rpc(PlayerPeer.serialize(players))
	return p

func peer_disconnected(id: int) -> void:
	players.erase(get_player_by_id(id))
	on_players_updated.rpc(PlayerPeer.serialize(players))
	
	if len(players) == 0:
		%UI.hide()
		%LobbyOverlay.show()
		$Level.reset()

func get_player_by_id(id: int) -> PlayerPeer:
	for p in players:
		if p.peer_id == id:
			return p
	return null

@rpc("any_peer", "call_local")
func set_player_character(resource_path: String) -> void:
	get_player_by_id(multiplayer.get_remote_sender_id()).character = resource_path
	players_updated.emit(players)

@rpc("call_local")
func on_players_updated(new_players) -> void:
	players = PlayerPeer.parse(new_players)
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
