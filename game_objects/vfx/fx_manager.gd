class_name FXManager

extends Node3D

var update_positions = []

const dust_settle = preload("res://resources/effects/dust-settle.tscn")
const hit_sparks = preload("res://resources/effects/hit-sparks.tscn")
const pressure_ring = preload("res://resources/effects/pressure-ring.tscn")
const pummel_pop = preload("res://resources/effects/pommel-pop.tscn")
const spark_spit = preload("res://resources/effects/spark-spit.tscn")
const crush_slam = preload("res://resources/effects/crush-slam.tscn")
const crit_burst = preload("res://resources/effects/crit-burst.tscn")
const holy_pillar = preload("res://resources/effects/holy-pillar.tscn")
const perfect_burst = preload("res://resources/effects/perfect-burst.tscn")
const evolve_flash = preload("res://resources/effects/evolve-flash.tscn")

func _process(delta: float) -> void:
	for u in update_positions:
		if u[0] == null:
			continue
		if u[1] == null:
			continue
		u[0].position = project_pos_to_viewport(u[1].global_position)

func project_pos_to_viewport(c: Vector3) -> Vector2:
	var camera: Camera3D = get_viewport().get_camera_3d()
	return camera.unproject_position(c)

func create_at_pos(fx: PackedScene, pos: Vector3, reflect = false):
	var f: AnimatedSprite2D = fx.instantiate()
	%Viewport.add_child(f)
	f.position = project_pos_to_viewport(pos)
	if reflect:
		f.scale.y *= -1
	f.play()
	f.animation_finished.connect(func():
		f.queue_free()
	)

func create_at_camera_pos(fx: PackedScene, pos: Vector2, reflect = false):
	var f: AnimatedSprite2D = fx.instantiate()
	%Viewport.add_child(f)
	f.position = pos
	if reflect:
		f.scale.y *= -1
	f.play()
	f.animation_finished.connect(func():
		f.queue_free()
	)
	


func create_particle_at_pos(particle: String, pos: Vector3, reflect = false):
	var f: GPUParticles2D
	if particle == "master_spark_star":
		f = %MasterSparkStar
	if particle == "master_spark_heart":
		f = %MasterSparkHeart
	f.position = project_pos_to_viewport(pos)
	f.emitting = true

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
