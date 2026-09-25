class_name FXManager

extends Node3D

const dust_settle = preload("res://resources/effects/dust-settle.tscn")
const hit_sparks = preload("res://resources/effects/hit-sparks.tscn")
const pressure_ring = preload("res://resources/effects/pressure-ring.tscn")

func create(fx: PackedScene, pos: Vector3):
	var f: AnimatedSprite3D = fx.instantiate()
	f.position = pos
	add_child(f)
	
	f.animation_finished.connect(func():
		f.queue_free()
	)
