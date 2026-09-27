extends MultiplayerSynchronizer


## If true, blocks client input.
@export var disable_input := false
@export var input_device := -99

## Direction is the authoritive direction sent to the server.
@export var direction := Vector2.ZERO
## Local direction is purely local and is used by the player on our client to reduce percieved delay.
var local_direction := Vector2.ZERO
var action_strength := Vector4.ZERO

## Simulated on_action_just_pressed via rpc.
## Reset per-client in _physics_process of player.
@export var kicking := false
@export var jumping := false
@export var supering := false

@rpc("call_local")
func kick() -> void:
	kicking = true

@rpc("call_local")
func jump() -> void:
	jumping = true

@rpc("call_local")
func trigger_super() -> void:
	supering = true

# Only runs on client, disabled_input is set when player is created.
# The `Input` class does not allow you to check if an input was performed by a specific
# device so we need to use the _input method :(
func _input(event: InputEvent) -> void:
	if disable_input:
		return
	if not is_multiplayer_authority():
		return

	if input_device > -99 and event.device != input_device:
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
		jump.rpc()
		jump()
	if event.is_action_pressed("kick"):
		kick.rpc()
		kick()
	if event.is_action_pressed("super"):
		trigger_super.rpc()
		trigger_super()

func _process(_delta: float) -> void:
	if not is_multiplayer_authority():
		return
	
	local_direction = Vector2(
		action_strength.y - action_strength.x,
		action_strength.z - action_strength.w,
	)
	direction = local_direction
