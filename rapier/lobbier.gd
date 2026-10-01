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
	p.color = COLORS[wrap(len(players), 0, len(COLORS))]
	p.input_device = input_device
	if input_device != -99:
		p.local_co_op = true

	#if id == 1:
	#	p.character = (%Characters.selected.resource_path.split("/") as Array).back()
	players.push_back(p)
	on_players_updated.rpc(PlayerPeer.serialize(players))
	return p

func peer_disconnected(id: int) -> void:
	players.erase(get_player_by_id(id))
	on_players_updated.rpc(PlayerPeer.serialize(players))

func get_player_by_id(id: int) -> PlayerPeer:
	for p in players:
		if p.peer_id == id:
			return p
	return null

@rpc("any_peer", "call_local")
func set_player_character(id: int, resource_path: String) -> void:
	var p = get_player_by_id(id)
	if p:
		p.character = resource_path
	players_updated.emit(players)

@rpc("call_local")
func on_players_updated(new_players) -> void:
	players = PlayerPeer.parse(new_players)
	players_updated.emit(players)

@rpc("call_local")
func give_start_permission() -> void:
	give_start_authority.emit()

## Maps a unique peer id to a 3-bit number used for network communication
func map_peer_ids() -> void:
	var peer_ids = [1] + (multiplayer.get_peers() as Array)
	peer_ids.sort()
	
	var map: Dictionary[int, int] = {}
	for i in len(peer_ids):
		map[i] = peer_ids[i]
	%InputManager.set_peer_map.rpc(map)

func start_game() -> void:
	if not multiplayer.is_server():
		return
	multiplayer.multiplayer_peer.refuse_new_connections = true
	map_peer_ids()
	$Node3D.start_game()
	$Node3D.start_tracking.rpc(Time.get_unix_time_from_system() + 2)

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
