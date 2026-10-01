extends Resource
class_name InputFrame

## The synchronsied physics tick this input frame was generated on.
@export var tick: int
## The player's map id. This is generated for each server peer at the start of the game,
## which is broadcast to all clients
@export var player_map_id: int
## If true, this InputFrame was just a prediction and may be overwritten by a real [InputFrame]
## when recieved from a peer.
var prediction := false

## The player's flag actions for buttons
@export_flags("jump", "kick", "use_super")
var button_flags := 0
## The players direction action strengths.
var direction: Vector2

## If true, the player is jumping on this frame.
var jumping: bool :
	get:
		return button_flags & 0b001
## If true, the player is kicking on this frame.
var kicking: bool :
	get:
		return button_flags & 0b010
## If true, the player is using their super on this frame.
var supering: bool :
	get:
		return button_flags & 0b100

## Helper to set [member button_flags] using 3 booleans.
func set_button_flags(is_jumping: bool, is_kicking: bool, is_supering: bool) -> void:
	button_flags = int(is_jumping) + int(is_kicking) * 2 + int(is_supering) * 4

## Serialise the input frame to a buffer.
func serialise(to: StreamPeerBuffer) -> void:
	to.put_u16(tick)
	# Flag bits:
	# 0-2: Buttons pressed this frame
	# 3: Packet contains new direction info
	# 4-7: Reserved
	var flags = 0
	flags |= button_flags
	flags |= (1 << 3) if direction == Vector2.ZERO else 0
	to.put_u8(flags)
	to.put_float(direction.angle())

## Deserialise a buffer into an input frame.
func deserialise(serial: StreamPeerBuffer) -> void:
	tick = serial.get_u16()
	var flags = serial.get_8()
	button_flags = flags & 0b111
	
	direction = Vector2.from_angle(serial.get_float())
	if flags & (1 << 3):
		direction = Vector2.ZERO

## Test if two input frames are performing the same action.
func actions_equal(other: InputFrame) -> bool:
	if other.direction != direction:
		return false
	if other.button_flags != button_flags:
		return false
	if other.player_map_id != player_map_id:
		return false
	return true
