class_name Globals


static var GRAVITY = 65536

static func map_pos2D_to_pos3D(camera: Camera3D, position: Vector2) -> Vector3:
	return camera.project_position(position, camera.position.z)
