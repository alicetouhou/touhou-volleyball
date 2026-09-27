extends MultiplayerSynchronizer


## If true, blocks client input.
@export var disable_input := false
@export var input_device := -99

## Direction is the authoritive direction sent to the server.
@export var direction := Vector2.ZERO
## Local direction is purely local and is used by the player on our client to reduce percieved delay.
var local_direction := Vector2.ZERO

## Simulated on_action_just_pressed via rpc.
## Reset per-client in _physics_process of player.
@export var kicking := false
@export var jumping := false
@export var supering := false

## Input direction strength. Synced with RPC.
var up_strength := 0.0
var down_strength := 0.0
var left_strength := 0.0
var right_strength := 0.0

@rpc("call_local")
func kick() -> void:
	kicking = true

@rpc("call_local")
func jump() -> void:
	jumping = true

@rpc("call_local")
func trigger_super() -> void:
	supering = true

@rpc("call_local")
func sync_strength(d: String, power: float) -> void:
	if d == "left":
		left_strength = power
	if d == "right":
		right_strength = power
	if d == "up":
		up_strength = power
	if d == "down":
		down_strength = power

# The `Input` class does not allow you to check if an input was performed by a specific
# device so we need to use the _input method :(
func _input(event: InputEvent) -> void:
	if input_device > -99 and event.device != input_device:
		return

	if event.is_action_pressed("left") or event.is_action_released("left"):
		sync_strength.rpc("left", event.get_action_strength("left"))
	if event.is_action_pressed("right") or event.is_action_released("right"):
		sync_strength.rpc("right", event.get_action_strength("right"))
	if event.is_action_pressed("up") or event.is_action_released("up"):
		sync_strength.rpc("up", event.get_action_strength("up"))
	if event.is_action_pressed("down") or event.is_action_released("down"):
		sync_strength.rpc("down", event.get_action_strength("down"))

	if event.is_action_pressed("up"):
		jump.rpc()
		jump()
	if event.is_action_pressed("kick"):
		kick.rpc()
		kick()
	if event.is_action_pressed("super"):
		trigger_super.rpc()
		trigger_super()

## Only runs on client, see disabled is set when player is created.
func _process(_delta: float) -> void:
	if disable_input:
		return

	direction = Vector2.ZERO

	direction.x -= left_strength
	direction.x += right_strength
	direction.y += up_strength
	direction.y -= down_strength
	
	local_direction = direction
