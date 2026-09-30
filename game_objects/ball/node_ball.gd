extends Node2D

enum Collision{
	FLOOR,
	NET_SIDE,
	NET_TOP,
	CEILING,
	WALL,
	NONE
}

var velocity: Vector2 = Vector2.ZERO
var gravity: Vector2 = Vector2(0, 9.8)
var frozen: bool = false

const RADIUS = 0.46
const FLOOR = 0
const CEILING = 10
const WALL = -11
const NET_HEIGHT = -2.25

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _physics_process(delta: float) -> void:
	var next = next_pos(global_position, velocity, gravity, delta)
	global_position = next[0]
	velocity = next[1]

func next_pos(p: Vector2, v: Vector2, g: Vector2, delta: float) -> Array[Vector2]:
	var collision: Collision =  Collision.NONE
	var t_net = null
	var t_floor = null
	var t_ceiling = null
	var t_wall = null
	var net_collision
	
	t_floor = (sqrt(pow(v.y,2) + 2 * g.y * (p.y - RADIUS)) - v.y) / g.y
	if t_floor <= delta:
		score() 
	
	t_wall = ((WALL - RADIUS)*sign(v.x) - p.x) / v.x
	if v.x * p.x < 0:
		var t = (-RADIUS - p.x) / v.x
		var y = p.y + v.y * t + 0.5 * g.y * pow(t,2)
		var dx = -p.x
		var dy = NET_HEIGHT - p.y
		
		if abs(p.x) < RADIUS or (y < NET_HEIGHT and y > NET_HEIGHT - RADIUS):
			var results = %QuarticSolver.radical_real(0.25*(pow(g.x,2)+pow(g.y,2)), v.x*g.x+v.y*g.y, g.x*dx, g.y*dy, 2*(v.x*dx+v.y*dy), pow(dx,2)+pow(dy,2)+pow(RADIUS,2))
			if results.size() > 0:
				var min = 1.
				for r in results:
					if r > 0 and r < min:
						min = r
				t_net = min
				net_collision = Collision.NET_TOP
		elif y < NET_HEIGHT:
			t_net = t
			net_collision = Collision.NET_SIDE
	if v.y > 0:
		var ymax = -0.5*pow(v.y,2) / g.y
		if ymax <= CEILING + RADIUS:
			t_ceiling = (sqrt(pow(v.y,2) + 2 * g.y * (CEILING + RADIUS + p.x)) - v.y) / g.y
	
	var t_min = delta
	if t_net and t_net < t_min:
		t_min = t_net
		collision = net_collision
	if t_ceiling < t_min:
		t_min = t_ceiling
		collision = Collision.CEILING
	if t_wall < t_min:
		t_min = t_wall
		collision = Collision.WALL
	
	# Collision
	p += v * t_min + 0.5 * g * pow(t_min,2)
	v += g * t_min
	delta -= t_min
	if collision == Collision.NONE:
		return [p, v]
	if collision == Collision.NET_SIDE or collision == WALL:
		v.x *= -1
	elif collision == Collision.NET_TOP:
		var n = Vector2(0, NET_HEIGHT).direction_to(p)
		v -= 2*v.dot(n)*n
	elif collision == Collision.CEILING:
		v.y *= -1
	return next_pos(p, v, g, delta)

func score():
	pass
