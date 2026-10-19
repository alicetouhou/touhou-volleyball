extends Node
class_name InputManager

## Processes local input into [InputFrame]s. Also handles broadcasting this input to remote peers,
## and handling remote input recieved from other peers.
## Triggers rollbacks when an input frame is recieved that does not match the predicted input.

## Map smaller ids to peer ids.[br]
## [bold]note:[/bold] Setting this will clear all acknowledgements 
var player_peer_id_by_mid: Dictionary[int, int] = {0: 1} : set = reverse_peer_id
## The inverse mapping of [member player_peer_id_by_mid].
## Automatically updated when [member player_peer_id_by_mid] is set.
var player_mid_by_peer_id: Dictionary[int, int]
## The predicted or recieved inputs for each tick.
var player_inputs: Dictionary[int, Dictionary] = {}
## Acknowledgement trackers for each peer id.
## Automatically updated when [member player_peer_id_by_mid] is set.
var acknowledged_inputs: Dictionary[int, AcknowledgementTracker] = {}

## Disables input for this client. Mostly used on the server for CPU players.
var disable_input := false
## The player's map id. Automatically updated when [member player_peer_id_by_mid] is set.
var player_map_id := -1

## If true, a rollback is required due to recieved input.
var rollback := false
## The earliest tick that needs to be re-simulated.
var rollback_to: int = UINT32_MAX

## The action strength for left, right, up and down.
var action_strength: Vector4 = Vector4.ZERO
## If true, the player has just jumped. Reset when [method get_player_input] is called.
var jumping := false
## If true, the player has just kicked. Reset when [method get_player_input] is called.
var kicking := false
## If true, the player has just used their super. Reset when [method get_player_input] is called.
var supering := false

var debug_current_tick = 0

## The parent of all player nodes. Player nodes should be named by their remote peer id.
@export var player_root: Node2D

## Recieve an [InputFrame] and compare it with the predicted input.
## If it is incorrect, invalidate our cache and trigger a rollback with the new input.
func player_set_input(input: InputFrame) -> void:
	acknowledged_inputs[player_peer_id_by_mid[input.player_map_id]].tick_recieved(input.tick)
	
	# If this somehow arrives before we predict this tick, firstly something is off.
	# Second, there is no comparison to be done.
	if not player_inputs.get(input.tick) or not player_inputs[input.tick].get(input.player_map_id):
		player_inputs.get_or_add(input.tick, {})
		player_inputs[input.tick][input.player_map_id] = input
		return
	
	var predicted_input: InputFrame = player_inputs[input.tick][input.player_map_id]
	# If we guessed right, no need to change anything
	if predicted_input.actions_equal(input):
		player_inputs[input.tick][input.player_map_id].prediction = false
		return
	
	invalidate_player_cache(input.player_map_id, input.tick)
	player_inputs[input.tick][input.player_map_id] = input
	
	# Guessed wrong, rollback time
	rollback_to = min(input.tick, rollback_to)
	rollback = true

## Remove a player's inputs from the cache.
func invalidate_player_cache(player_mid: int, from: int, to: int = -1) -> void:
	for i in range(from, to if to >= 0 else player_inputs.keys().max()):
		if player_inputs.get(i, {}).has(player_mid) and player_inputs[i][player_mid].prediction:
			player_inputs[i].erase(player_mid)

func broadcast_inputs(latest_tick: int) -> void:
	for peer_id in player_mid_by_peer_id:
		if multiplayer.get_unique_id() == peer_id:
			continue
		send_input_to_peer(peer_id, latest_tick)

## Send packets not acknowledged by a given peer.
func send_input_to_peer(peer_id: int, latest_tick: int) -> void:
	debug_current_tick = latest_tick
	var ack_manager = acknowledged_inputs[peer_id]
	
	var buffer = StreamPeerBuffer.new()
	var unacknowledged = ack_manager.get_unacknowledged_ticks(latest_tick)
	buffer.put_8(len(unacknowledged))
	var input: InputFrame
	for tick in unacknowledged:
		input = player_inputs[tick][player_map_id]
		input.serialise(buffer)
	
	var ack = ack_manager.get_acknowledgement()
	buffer.put_u16(ack[0])
	buffer.put_u8(ack[1])
	buffer.seek(0)
	
	(multiplayer as SceneMultiplayer).send_bytes(
		buffer.data_array, peer_id, MultiplayerPeer.TRANSFER_MODE_UNRELIABLE
	)

## Predict a player's input for a given tick. Uses the most recent tick for that player to help.
func predict_player_input_for_tick(player_mid: int, tick: int) -> InputFrame:
	var player_frame: InputFrame = player_inputs.get(tick, {}).get(player_mid, null)
	if player_frame:
		return player_frame
	
	# No player frame cached, seach backwards for a prediction
	var last_frame: InputFrame
	for i in range(tick - 1, -1, -1):
		last_frame = player_inputs.get(i, {}).get(player_mid)
		if last_frame:
			break
	if not last_frame:
		last_frame = InputFrame.new()

	var predicted_frame := InputFrame.new()
	predicted_frame.player_map_id = player_mid
	predicted_frame.tick = tick
	predicted_frame.prediction = true
	
	predicted_frame.direction = last_frame.direction
	predicted_frame.button_flags = 0
	
	player_inputs.get_or_add(tick, {})[player_mid] = predicted_frame
	
	return predicted_frame

## Update the player nodes with the correct inputs, then broadcast our input to peers.
func apply_input_for_tick(tick: int) -> void:
	for node in player_root.get_children():
		var input := predict_player_input_for_tick(player_mid_by_peer_id[int(node.name)], tick)
		node.direction = input.direction
		node.jumping = input.jumping
		node.kicking = input.kicking
		node.supering = input.supering

## Get the local player input for a given tick.
func get_player_input(tick: int) -> InputFrame:
	if disable_input:
		return
	
	var frame = InputFrame.new()
	frame.tick = tick
	frame.player_map_id = player_map_id
	frame.direction = Vector2i(
		# We can use floats here, because they are converted to ints before
		# being sent through the network.
		SGFixed.from_float(action_strength.y - action_strength.x),
		SGFixed.from_float(action_strength.z - action_strength.w),
	)

	frame.set_button_flags(jumping, kicking, supering)
	
	jumping  = false
	kicking = false
	supering = false

	player_inputs.get_or_add(tick, {})
	player_inputs[tick][player_map_id] = frame
	
	broadcast_inputs(tick)
	
	return frame

## Update the mapping between remote peer ids and shorter ids.
@rpc("call_local")
func set_peer_map(map: Dictionary[int, int]) -> void:
	player_peer_id_by_mid = map

## Run when [member player_peer_id_by_mid] is set. Updates [member player_mid_by_peer_id] and
## [member player_map_id]
func reverse_peer_id(value) -> void:
	player_peer_id_by_mid = value
	for key in player_peer_id_by_mid:
		player_mid_by_peer_id[player_peer_id_by_mid[key]] = key
		acknowledged_inputs[player_peer_id_by_mid[key]] = AcknowledgementTracker.new()
	player_map_id = player_mid_by_peer_id[multiplayer.get_unique_id()]

## When a packet is recieved from a remote peer, read the input and acknowledgements.
## Input is sent to [method player_set_input].
## Acknowledgements are saved in [member acknowledged_inputs].
func packet_recieved(from: int, packet) -> void:
	var buffer := StreamPeerBuffer.new()
	buffer.put_data(packet)
	buffer.seek(0)

	var mid: int = player_mid_by_peer_id.get(from, -1)
	if mid == -1:
		print("Player with mid ", from, " does not exist.")
		return
	
	var inputs := buffer.get_8()
	for _i in inputs:
		var input := InputFrame.new()
		input.player_map_id = mid
		input.deserialise(buffer)
		player_set_input(input)
	
	var latest_tick = buffer.get_u16()
	var previous_bitmap = buffer.get_u8()
	acknowledged_inputs[from].new_acknowledgement(latest_tick, previous_bitmap)

# Only runs on client, disabled_input is set when player is created.
# The `Input` class does not allow you to check if an input was performed by a specific
# device so we need to use the _input method :(
func _input(event: InputEvent) -> void:
	if disable_input:
		return
	
	if event.is_action_pressed("left") or event.is_action_released("left"):
		action_strength.x = event.get_action_strength("left")
	if event.is_action_pressed("right") or event.is_action_released("right"):
		action_strength.y = event.get_action_strength("right")
	if event.is_action_pressed("up") or event.is_action_released("up"):
		action_strength.z = event.get_action_strength("up")
	if event.is_action_pressed("down") or event.is_action_released("down"):
		action_strength.w = event.get_action_strength("down")

	if event.is_action_pressed("up"):
		jumping = true
	if event.is_action_pressed("kick"):
		kicking = true
	if event.is_action_pressed("super"):
		supering = true

func _ready() -> void:
	reverse_peer_id(player_peer_id_by_mid)
	(multiplayer as SceneMultiplayer).peer_packet.connect(packet_recieved)
