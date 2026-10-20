class_name Globals


static var GRAVITY = 32768

static func map_pos2D_to_pos3D(camera: Camera3D, position: Vector2) -> Vector3:
	return camera.project_position(position, camera.position.z)

static func get_game_instance_id() -> int:
	var args = OS.get_cmdline_args()
	var instance_index = args.find("--instance")
	return int(args[instance_index + 1])
 
