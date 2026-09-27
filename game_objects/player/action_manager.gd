extends MultiplayerSynchronizer


## Client's target for movement (except jumping).
@export var direction = Vector2i.ZERO

## Simulated on_action_just_pressed via rpc.
## Reset per-client in _physics_process of player.
@export var kicking = false
@export var jumping = false
@export var supering = false

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
	direction = Vector2.ZERO
	
	if Input.is_action_pressed("left"):
		direction.x -= 1
	if Input.is_action_pressed("right"):
		direction.x += 1
	if Input.is_action_pressed("up"):
		direction.y += 1
	if Input.is_action_pressed("down"):
		direction.y -= 1
	if Input.is_action_just_pressed("up"):
		jump.rpc()
	if Input.is_action_just_pressed("kick"):
		kick.rpc()
	if Input.is_action_just_pressed("super"):
		trigger_super.rpc()
