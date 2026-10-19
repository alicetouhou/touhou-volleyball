class_name Ball2D

extends SyncedRigidBody

var last_on_floor = false

func _network_process(_input):
	if is_on_floor() and not last_on_floor:
		play_land_sound()
	if is_on_floor():
		last_on_floor = true
	else:
		last_on_floor = false

func play_kick_sound(hit_force: SGFixedVector2) -> void:
	if SyncManager.is_in_rollback():
		return
	if hit_force.length() > SGFixed.ONE * 40:
		%BigKickStream.play(0.04)
	else:
		%KickStream.play(0.04)

func _network_postprocess(_input):
	for k in kick_requests:
		apply_impulse(
			SGFixed.vector2(k["force_x"], k["force_y"]),
			SGFixed.vector2(k["direction_x"], k["direction_y"])
		)
	kick_requests = []
	
	super._network_process()

func play_land_sound() -> void:
	if SyncManager.is_in_rollback():
		return
	%LandStream.play(0.04)
