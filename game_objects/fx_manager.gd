class_name FXManager

extends Node3D

var update_positions = []

const dust_settle = preload("res://resources/effects/dust-settle.tscn")
const hit_sparks = preload("res://resources/effects/hit-sparks.tscn")
const pressure_ring = preload("res://resources/effects/pressure-ring.tscn")
const pummel_pop = preload("res://resources/effects/pommel-pop.tscn")
const spark_spit = preload("res://resources/effects/spark-spit.tscn")

func _process(delta: float) -> void:
	for u in update_positions:
		u[0].position = project_pos_to_viewport(u[1].global_position)

func project_pos_to_viewport(c: Vector3):
	var camera: Camera3D = get_viewport().get_camera_3d()
	return camera.unproject_position(c)

func create_at_pos(fx: PackedScene, pos: Vector3):
	var f: AnimatedSprite2D = fx.instantiate()
	%Viewport.add_child(f)
	f.position = project_pos_to_viewport(pos)
	f.play()
	f.animation_finished.connect(func():
		f.queue_free()
	)

func create_with_parent_3D(fx: PackedScene, parent: Node3D):
	var f: AnimatedSprite2D = fx.instantiate()
	f.position = project_pos_to_viewport(parent.position)
	%Viewport.add_child(f)
	f.play()
	
	var a = [f, parent]
	update_positions.push_back(a)
	await f.animation_finished
	update_positions.pop_at(update_positions.find(a))

	f.queue_free()
