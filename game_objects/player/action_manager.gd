extends MultiplayerSynchronizer


## If true, blocks client input.
@export var disabled := false

## Direction is the authoritive direction sent to the server.
@export var direction := Vector2i.ZERO
## Local direction is purely local and is used by the player on our client to reduce percieved delay.
var local_direction := Vector2i.ZERO

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

func _ready():
	set_process(get_multiplayer_authority() == multiplayer.get_unique_id())

## Only runs on client, see _ready.
## TODO: Add multiple inputs.
func _process(_delta: float) -> void:
	if disabled:
		return
	
	local_direction = Vector2.ZERO
	
	if Input.is_action_pressed("left"):
		local_direction.x -= 1
	if Input.is_action_pressed("right"):
		local_direction.x += 1
	if Input.is_action_pressed("up"):
		local_direction.y += 1
	if Input.is_action_pressed("down"):
		local_direction.y -= 1
	direction = local_direction
	
	if Input.is_action_just_pressed("up"):
		jump()
		jump.rpc_id(1)
	if Input.is_action_just_pressed("kick"):
		kick()
		kick.rpc_id(1)
	if Input.is_action_just_pressed("super"):
		trigger_super()
		trigger_super.rpc_id(1)
