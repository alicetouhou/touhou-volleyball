extends Node3D

var current_player = 1
var round_playing = false

func _ready() -> void:
	start_round()

func _on_player_3d_create_fx(fx: PackedScene, pos: Vector3) -> void:
	%FxManager.create_at_pos(fx, pos)


func _on_player_3d_on_hit_ball() -> void:
	%FxManager.create_with_parent_3D(FXManager.pressure_ring, %Ball3d)
	%Camera3D.add_trauma(.1)


func _on_ball_3d_create_fx(fx: PackedScene, pos: Vector3) -> void:
	%FxManager.create_at_pos(fx, pos)

func start_round():
	%Ball3d.linear_velocity = Vector3.ZERO
	%Ball3d.process_mode = Node.PROCESS_MODE_DISABLED

	%Ball3d.position = %P1BallSpawnPoint.position
	%Player1.position = %P1SpawnPoint.position
	%Player2.position = %P2SpawnPoint.position
	
	%CountdownTimer.show()

	%CountdownTimer.text = "3"
	await get_tree().create_timer(.75).timeout
	%CountdownTimer.text = "2"
	await get_tree().create_timer(.75).timeout
	%CountdownTimer.text = "1"
	await get_tree().create_timer(.75).timeout

	%CountdownTimer.hide()
	round_playing = true

	%Ball3d.process_mode = Node.PROCESS_MODE_INHERIT

func end_round():
	if not round_playing:
		return
	round_playing = false
	%CountdownTimer.text = "Score!"

	await get_tree().create_timer(.75).timeout

	start_round()

func _on_ball_3d_body_entered(body: Node) -> void:
	if body.is_in_group("ground"):
		end_round()
