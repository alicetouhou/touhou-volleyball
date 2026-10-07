class_name Ball2D

extends SyncedRigidBody

var last_on_floor = false

func _network_process(_input):
	if SYNCED_is_on_floor_USE_THIS_ONE and not last_on_floor:
		play_land_sound()
	if SYNCED_is_on_floor_USE_THIS_ONE:
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

func play_land_sound() -> void:
	if SyncManager.is_in_rollback():
		return
	%LandStream.play(0.04)
